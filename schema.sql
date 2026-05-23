-- ============================================================
-- HealthForceHub Agentic PM Tool — Supabase Schema
-- Run this in: Supabase Dashboard > SQL Editor
-- ============================================================

-- EXTENSIONS
create extension if not exists "uuid-ossp";
create extension if not exists vector;

-- ============================================================
-- ENUMS
-- ============================================================
create type task_status        as enum ('backlog','feature','ready','inprogress','testing','done');
create type task_priority      as enum ('Low','Medium','High','Critical');
create type task_risk_level    as enum ('low','medium','high','critical');
create type project_status     as enum ('active','hold','completed','archived');
create type member_availability as enum ('active','away','offline');
create type agent_run_status   as enum ('pending','running','success','failed','cancelled');
create type agent_task_status  as enum ('not_requested','queued','running','needs_human','completed','failed');
create type event_action       as enum ('created','updated','deleted','moved','commented','assigned','completed','blocked','unblocked');
create type memory_type        as enum ('fact','decision','preference','context','error');
create type actor_type         as enum ('user','agent','system');
create type trigger_type       as enum ('manual','scheduled','event','chained');

-- ============================================================
-- CORE PM TABLES
-- ============================================================

-- Users (mirrors Supabase auth.users)
create table users (
  id             uuid primary key references auth.users(id) on delete cascade,
  name           text not null,
  email          text unique not null,
  role           text,
  dept           text,
  avatar_color   text        default '#4f8ef7',
  skills         text[],
  notes          text,
  availability   member_availability default 'active',
  created_at     timestamptz default now(),
  updated_at     timestamptz default now()
);

-- Projects
create table projects (
  id          uuid primary key default uuid_generate_v4(),
  name        text not null,
  description text,
  color       text        default '#4f8ef7',
  icon        text        default '🏗️',
  status      project_status default 'active',
  start_date  date,
  end_date    date,
  owner_id    uuid references users(id) on delete set null,
  notes       text,
  embedding   vector(1536),          -- semantic project search
  created_at  timestamptz default now(),
  updated_at  timestamptz default now()
);

-- Sprints (stored, not computed — unlike current HTML app)
create table sprints (
  id          uuid primary key default uuid_generate_v4(),
  project_id  uuid not null references projects(id) on delete cascade,
  number      integer not null,
  label       text not null,
  start_date  date not null,
  end_date    date not null,
  created_at  timestamptz default now(),
  unique (project_id, number)
);

-- Tasks
create table tasks (
  id            uuid primary key default uuid_generate_v4(),
  project_id    uuid references projects(id) on delete cascade,
  sprint_id     uuid references sprints(id) on delete set null,
  title         text not null,
  description   text,
  module        text,
  status        task_status    default 'backlog',
  priority      task_priority  default 'Medium',
  assignee_id   uuid references users(id) on delete set null,
  due_date      date,
  progress      integer        default 0 check (progress between 0 and 100),
  story_points  integer        default 0,
  notes         text,
  embedding     vector(1536),          -- semantic task search + agent retrieval
  created_by    uuid references users(id) on delete set null,
  created_at    timestamptz default now(),
  updated_at    timestamptz default now()
);

-- Task Dependencies (many-to-many: task is blocked by other tasks)
create table task_dependencies (
  task_id       uuid references tasks(id) on delete cascade,
  blocked_by_id uuid references tasks(id) on delete cascade,
  primary key (task_id, blocked_by_id),
  check (task_id <> blocked_by_id)
);

-- Task Comments
create table task_comments (
  id          uuid primary key default uuid_generate_v4(),
  task_id     uuid not null references tasks(id) on delete cascade,
  author_id   uuid references users(id) on delete set null,
  author_name text,                          -- preserved if user is deleted
  content     text not null,
  created_at  timestamptz default now()
);

-- Project Context: stable retrieval-friendly memory for humans and agents
create table project_contexts (
  id                    uuid primary key default uuid_generate_v4(),
  project_id            uuid not null unique references projects(id) on delete cascade,
  summary               text,
  goals                 text[],
  constraints           text[],
  external_dependencies jsonb,
  key_links             jsonb,
  release_target        date,
  launch_notes          text,
  created_at            timestamptz default now(),
  updated_at            timestamptz default now()
);

-- Task Briefs: structured execution context beyond free-form notes
create table task_briefs (
  task_id             uuid primary key references tasks(id) on delete cascade,
  reviewer_id         uuid references users(id) on delete set null,
  definition_of_done  text,
  next_action         text,
  blocked_reason      text,
  repo_url            text,
  pr_url              text,
  environment         text,
  risk_level          task_risk_level default 'medium',
  agent_status        agent_task_status default 'not_requested',
  agent_owner         text,
  last_agent_summary  text,
  last_agent_run_id   uuid,
  metadata            jsonb,
  created_at          timestamptz default now(),
  updated_at          timestamptz default now()
);

-- ============================================================
-- AGENTIC TABLES
-- ============================================================

-- Agent Runs: every agent execution — inputs, outputs, status, cost
create table agent_runs (
  id             uuid primary key default uuid_generate_v4(),
  agent_type     text not null,              -- 'planner','executor','reviewer','reporter','triage'
  trigger        trigger_type default 'manual',
  input          jsonb,
  output         jsonb,
  status         agent_run_status default 'pending',
  error          text,
  tokens_used    integer,
  duration_ms    integer,
  project_id     uuid references projects(id) on delete set null,
  task_id        uuid references tasks(id)   on delete set null,
  user_id        uuid references users(id)   on delete set null,
  parent_run_id  uuid references agent_runs(id) on delete set null,  -- chained agent calls
  metadata       jsonb,
  started_at     timestamptz,
  completed_at   timestamptz,
  created_at     timestamptz default now()
);

-- Agent Memory: long-term semantic memory with vector search
create table agent_memory (
  id             uuid primary key default uuid_generate_v4(),
  agent_type     text,
  scope          text not null,              -- 'global','project','task','user'
  scope_id       uuid,                       -- FK to the scoped entity
  content        text not null,
  embedding      vector(1536),               -- for semantic retrieval
  memory_type    memory_type default 'fact',
  importance     float        default 0.5    check (importance between 0 and 1),
  expires_at     timestamptz,
  source_run_id  uuid references agent_runs(id) on delete set null,
  metadata       jsonb,
  created_at     timestamptz default now(),
  updated_at     timestamptz default now()
);

-- Events: append-only audit trail (never UPDATE or DELETE rows here)
create table events (
  id            uuid primary key default uuid_generate_v4(),
  entity_type   text not null,              -- 'task','project','sprint','member','workflow'
  entity_id     uuid not null,
  action        event_action not null,
  actor_type    actor_type default 'user',
  actor_id      uuid,
  actor_name    text,
  before_state  jsonb,
  after_state   jsonb,
  metadata      jsonb,
  created_at    timestamptz default now()
);

-- Agent Tools: registry of tools agents can call
create table agent_tools (
  id            uuid primary key default uuid_generate_v4(),
  name          text unique not null,
  description   text,
  input_schema  jsonb,                      -- JSON Schema for inputs
  output_schema jsonb,                      -- JSON Schema for outputs
  is_active     boolean default true,
  created_at    timestamptz default now()
);

-- Agent Tool Calls: every tool invocation within a run
create table agent_tool_calls (
  id          uuid primary key default uuid_generate_v4(),
  run_id      uuid not null references agent_runs(id) on delete cascade,
  tool_name   text not null,
  input       jsonb,
  output      jsonb,
  error       text,
  duration_ms integer,
  created_at  timestamptz default now()
);

-- Workflows: multi-step agent pipeline definitions
create table workflows (
  id             uuid primary key default uuid_generate_v4(),
  name           text not null,
  description    text,
  trigger_type   trigger_type default 'manual',
  trigger_config jsonb,                      -- cron expression, event filter, etc.
  steps          jsonb not null,             -- ordered array of {agent_type, prompt_template, tools[]}
  is_active      boolean default true,
  project_id     uuid references projects(id) on delete cascade,
  created_by     uuid references users(id)   on delete set null,
  created_at     timestamptz default now(),
  updated_at     timestamptz default now()
);

-- Workflow Runs: execution instances of a workflow
create table workflow_runs (
  id            uuid primary key default uuid_generate_v4(),
  workflow_id   uuid references workflows(id) on delete set null,
  status        agent_run_status default 'pending',
  current_step  integer default 0,
  context       jsonb,                       -- shared state passed between steps
  started_at    timestamptz,
  completed_at  timestamptz,
  created_at    timestamptz default now()
);

-- ============================================================
-- INDEXES
-- ============================================================

-- Vector / semantic search (IVFFlat — good up to ~1M rows)
create index tasks_embedding_idx        on tasks        using ivfflat (embedding vector_cosine_ops) with (lists = 100);
create index projects_embedding_idx     on projects     using ivfflat (embedding vector_cosine_ops) with (lists = 100);
create index agent_memory_embedding_idx on agent_memory using ivfflat (embedding vector_cosine_ops) with (lists = 100);

-- Core query patterns
create index on tasks         (project_id, status);
create index on tasks         (assignee_id);
create index on tasks         (sprint_id);
create index on task_dependencies (blocked_by_id);
create index on task_comments (task_id, created_at desc);
create index on project_contexts (project_id);
create index on task_briefs   (agent_status, risk_level);
create index on task_briefs   (reviewer_id);
create index on agent_runs    (agent_type, status, created_at desc);
create index on agent_runs    (project_id, created_at desc);
create index on agent_runs    (task_id, created_at desc);
create index on agent_runs    (parent_run_id);
create index on agent_memory  (scope, scope_id, importance desc);
create index on agent_memory  (expires_at) where expires_at is not null;
create index on events        (entity_type, entity_id, created_at desc);
create index on events        (actor_id, created_at desc);
create index on agent_tool_calls (run_id, created_at desc);
create index on workflow_runs (workflow_id, status);

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================
alter table users          enable row level security;
alter table projects       enable row level security;
alter table sprints        enable row level security;
alter table tasks          enable row level security;
alter table task_dependencies enable row level security;
alter table task_comments  enable row level security;
alter table project_contexts enable row level security;
alter table task_briefs    enable row level security;
alter table agent_tools    enable row level security;
alter table agent_tool_calls enable row level security;
alter table agent_runs     enable row level security;
alter table agent_memory   enable row level security;
alter table events         enable row level security;
alter table workflows      enable row level security;
alter table workflow_runs  enable row level security;

-- Authenticated users can read and write (extend per org/tenant needs)
create policy "auth read"   on users          for select using (auth.role() = 'authenticated');
create policy "auth insert" on users          for insert with check (auth.role() = 'authenticated');
create policy "auth update" on users          for update using (auth.role() = 'authenticated');

create policy "auth read"   on projects       for select using (auth.role() = 'authenticated');
create policy "auth insert" on projects       for insert with check (auth.role() = 'authenticated');
create policy "auth update" on projects       for update using (auth.role() = 'authenticated');

create policy "auth read"   on sprints        for select using (auth.role() = 'authenticated');
create policy "auth insert" on sprints        for insert with check (auth.role() = 'authenticated');
create policy "auth update" on sprints        for update using (auth.role() = 'authenticated');

create policy "auth read"   on tasks          for select using (auth.role() = 'authenticated');
create policy "auth insert" on tasks          for insert with check (auth.role() = 'authenticated');
create policy "auth update" on tasks          for update using (auth.role() = 'authenticated');

create policy "auth read"   on task_dependencies for select using (auth.role() = 'authenticated');
create policy "auth write"  on task_dependencies for all    using (auth.role() = 'authenticated');

create policy "auth read"   on task_comments  for select using (auth.role() = 'authenticated');
create policy "auth insert" on task_comments  for insert with check (auth.role() = 'authenticated');

create policy "auth read"   on project_contexts for select using (auth.role() = 'authenticated');
create policy "auth write"  on project_contexts for all    using (auth.role() = 'authenticated');

create policy "auth read"   on task_briefs    for select using (auth.role() = 'authenticated');
create policy "auth write"  on task_briefs    for all    using (auth.role() = 'authenticated');

create policy "auth read"   on agent_tools    for select using (auth.role() = 'authenticated');
create policy "auth write"  on agent_tools    for all    using (auth.role() = 'authenticated');

create policy "auth read"   on agent_tool_calls for select using (auth.role() = 'authenticated');
create policy "auth insert" on agent_tool_calls for insert with check (auth.role() = 'authenticated');

create policy "auth read"   on agent_runs     for select using (auth.role() = 'authenticated');
create policy "auth insert" on agent_runs     for insert with check (auth.role() = 'authenticated');
create policy "auth update" on agent_runs     for update using (auth.role() = 'authenticated');

create policy "auth read"   on agent_memory   for select using (auth.role() = 'authenticated');
create policy "auth write"  on agent_memory   for all    using (auth.role() = 'authenticated');

-- Events are read-only for users; agents insert via service role
create policy "auth read"   on events         for select using (auth.role() = 'authenticated');

create policy "auth read"   on workflows      for select using (auth.role() = 'authenticated');
create policy "auth write"  on workflows      for all    using (auth.role() = 'authenticated');

create policy "auth read"   on workflow_runs  for select using (auth.role() = 'authenticated');
create policy "auth insert" on workflow_runs  for insert with check (auth.role() = 'authenticated');
create policy "auth update" on workflow_runs  for update using (auth.role() = 'authenticated');

-- ============================================================
-- UPDATED_AT TRIGGER (auto-maintain updated_at columns)
-- ============================================================
create or replace function set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

create or replace function log_entity_event()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  entity_name text := tg_argv[0];
  action_name event_action;
  entity_uuid uuid;
begin
  if tg_op = 'INSERT' then
    action_name := 'created';
    entity_uuid := new.id;
  elsif tg_op = 'UPDATE' then
    action_name := 'updated';
    entity_uuid := new.id;
  else
    action_name := 'deleted';
    entity_uuid := old.id;
  end if;

  insert into events (
    entity_type,
    entity_id,
    action,
    actor_type,
    actor_id,
    before_state,
    after_state,
    metadata
  )
  values (
    entity_name,
    entity_uuid,
    action_name,
    'user',
    auth.uid(),
    case when tg_op in ('UPDATE','DELETE') then to_jsonb(old) else null end,
    case when tg_op in ('INSERT','UPDATE') then to_jsonb(new) else null end,
    jsonb_build_object('source_table', tg_table_name)
  );

  return case when tg_op = 'DELETE' then old else new end;
end;
$$;

create or replace function log_task_comment_event()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into events (
    entity_type,
    entity_id,
    action,
    actor_type,
    actor_id,
    actor_name,
    after_state,
    metadata
  )
  values (
    'task',
    new.task_id,
    'commented',
    'user',
    auth.uid(),
    new.author_name,
    to_jsonb(new),
    jsonb_build_object('comment_id', new.id)
  );

  return new;
end;
$$;

create trigger set_updated_at before update on users          for each row execute function set_updated_at();
create trigger set_updated_at before update on projects       for each row execute function set_updated_at();
create trigger set_updated_at before update on tasks          for each row execute function set_updated_at();
create trigger set_updated_at before update on project_contexts for each row execute function set_updated_at();
create trigger set_updated_at before update on task_briefs    for each row execute function set_updated_at();
create trigger set_updated_at before update on agent_memory   for each row execute function set_updated_at();
create trigger set_updated_at before update on workflows      for each row execute function set_updated_at();

alter table task_briefs
  add constraint task_briefs_last_agent_run_fk
  foreign key (last_agent_run_id) references agent_runs(id) on delete set null;

create trigger log_project_events
after insert or update or delete on projects
for each row execute function log_entity_event('project');

create trigger log_task_events
after insert or update or delete on tasks
for each row execute function log_entity_event('task');

create trigger log_task_comment_events
after insert on task_comments
for each row execute function log_task_comment_event();
