-- ============================================================
-- COMPATIBILITY MIGRATION — Run in Supabase SQL Editor
-- Drops UUID-keyed tables, recreates with text IDs to match
-- the app's data structure. All tables are empty so no data loss.
-- ============================================================

-- Drop in reverse-dependency order
DROP TABLE IF EXISTS agent_tool_calls  CASCADE;
DROP TABLE IF EXISTS workflow_runs     CASCADE;
DROP TABLE IF EXISTS workflows         CASCADE;
DROP TABLE IF EXISTS task_comments     CASCADE;
DROP TABLE IF EXISTS task_dependencies CASCADE;
DROP TABLE IF EXISTS agent_memory      CASCADE;
DROP TABLE IF EXISTS agent_runs        CASCADE;
DROP TABLE IF EXISTS tasks             CASCADE;
DROP TABLE IF EXISTS sprints           CASCADE;
DROP TABLE IF EXISTS projects          CASCADE;

-- ── CORE APP TABLES (text IDs matching app uid()) ──────────────

CREATE TABLE projects (
  id          text PRIMARY KEY,
  name        text NOT NULL,
  description text,
  color       text DEFAULT '#4f8ef7',
  icon        text DEFAULT '🏗️',
  status      text DEFAULT 'active',
  start_date  text,
  end_date    text,
  owner       text,
  notes       text,
  created_at  timestamptz DEFAULT now(),
  updated_at  timestamptz DEFAULT now()
);

CREATE TABLE tasks (
  id           text PRIMARY KEY,
  title        text NOT NULL,
  description  text,
  module       text,
  status       text DEFAULT 'backlog',
  priority     text DEFAULT 'Medium',
  assignee     text,
  due_date     text,
  progress     integer DEFAULT 0,
  story_points integer DEFAULT 0,
  sprint_id    text,
  project_id   text REFERENCES projects(id) ON DELETE SET NULL,
  notes        text,
  blocked_by   jsonb DEFAULT '[]',
  comments     jsonb DEFAULT '[]',
  created_at   timestamptz DEFAULT now(),
  updated_at   timestamptz DEFAULT now()
);

CREATE TABLE members (
  id         text PRIMARY KEY,
  name       text NOT NULL,
  role       text,
  email      text,
  phone      text,
  dept       text,
  status     text DEFAULT 'active',
  skills     text,
  notes      text,
  color      text DEFAULT '#4f8ef7',
  created_at timestamptz DEFAULT now()
);

CREATE TABLE sprint_config (
  key   text PRIMARY KEY,
  value text NOT NULL
);

-- ── AGENTIC TABLES (UUID, for future AI features) ─────────────

CREATE TABLE agent_runs (
  id            uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  agent_type    text NOT NULL,
  trigger       text DEFAULT 'manual',
  input         jsonb,
  output        jsonb,
  status        text DEFAULT 'pending',
  error         text,
  tokens_used   integer,
  duration_ms   integer,
  project_id    text,
  task_id       text,
  parent_run_id uuid REFERENCES agent_runs(id) ON DELETE SET NULL,
  metadata      jsonb,
  started_at    timestamptz,
  completed_at  timestamptz,
  created_at    timestamptz DEFAULT now()
);

CREATE TABLE agent_memory (
  id            uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  agent_type    text,
  scope         text NOT NULL,
  scope_id      text,
  content       text NOT NULL,
  embedding     vector(1536),
  memory_type   text DEFAULT 'fact',
  importance    float DEFAULT 0.5,
  expires_at    timestamptz,
  source_run_id uuid REFERENCES agent_runs(id) ON DELETE SET NULL,
  metadata      jsonb,
  created_at    timestamptz DEFAULT now(),
  updated_at    timestamptz DEFAULT now()
);

CREATE TABLE task_comments (
  id          uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  task_id     text REFERENCES tasks(id) ON DELETE CASCADE,
  author_name text,
  content     text NOT NULL,
  created_at  timestamptz DEFAULT now()
);

CREATE TABLE task_dependencies (
  task_id       text REFERENCES tasks(id) ON DELETE CASCADE,
  blocked_by_id text REFERENCES tasks(id) ON DELETE CASCADE,
  PRIMARY KEY (task_id, blocked_by_id)
);

CREATE TABLE workflows (
  id             uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  name           text NOT NULL,
  description    text,
  trigger_type   text DEFAULT 'manual',
  trigger_config jsonb,
  steps          jsonb NOT NULL DEFAULT '[]',
  is_active      boolean DEFAULT true,
  project_id     text,
  created_at     timestamptz DEFAULT now(),
  updated_at     timestamptz DEFAULT now()
);

CREATE TABLE workflow_runs (
  id           uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  workflow_id  uuid REFERENCES workflows(id) ON DELETE SET NULL,
  status       text DEFAULT 'pending',
  current_step integer DEFAULT 0,
  context      jsonb,
  started_at   timestamptz,
  completed_at timestamptz,
  created_at   timestamptz DEFAULT now()
);

CREATE TABLE agent_tool_calls (
  id          uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  run_id      uuid REFERENCES agent_runs(id) ON DELETE CASCADE,
  tool_name   text NOT NULL,
  input       jsonb,
  output      jsonb,
  error       text,
  duration_ms integer,
  created_at  timestamptz DEFAULT now()
);

-- ── INDEXES ───────────────────────────────────────────────────

CREATE INDEX IF NOT EXISTS idx_agent_memory_emb   ON agent_memory USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);
CREATE INDEX IF NOT EXISTS idx_tasks_project      ON tasks (project_id);
CREATE INDEX IF NOT EXISTS idx_tasks_assignee     ON tasks (assignee);
CREATE INDEX IF NOT EXISTS idx_tasks_sprint       ON tasks (sprint_id);
CREATE INDEX IF NOT EXISTS idx_tasks_status       ON tasks (status);
CREATE INDEX IF NOT EXISTS idx_agent_runs_type    ON agent_runs (agent_type, status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_agent_memory_scope ON agent_memory (scope, scope_id, importance DESC);

-- ── DISABLE RLS FOR DEVELOPMENT ───────────────────────────────
-- Re-enable with proper policies when Supabase Auth is added

ALTER TABLE projects          DISABLE ROW LEVEL SECURITY;
ALTER TABLE tasks             DISABLE ROW LEVEL SECURITY;
ALTER TABLE members           DISABLE ROW LEVEL SECURITY;
ALTER TABLE sprint_config     DISABLE ROW LEVEL SECURITY;
ALTER TABLE task_comments     DISABLE ROW LEVEL SECURITY;
ALTER TABLE task_dependencies DISABLE ROW LEVEL SECURITY;
ALTER TABLE agent_runs        DISABLE ROW LEVEL SECURITY;
ALTER TABLE agent_memory      DISABLE ROW LEVEL SECURITY;
ALTER TABLE workflows         DISABLE ROW LEVEL SECURITY;
ALTER TABLE workflow_runs     DISABLE ROW LEVEL SECURITY;
ALTER TABLE events            DISABLE ROW LEVEL SECURITY;

-- ── REALTIME ──────────────────────────────────────────────────

ALTER PUBLICATION supabase_realtime ADD TABLE tasks;
ALTER PUBLICATION supabase_realtime ADD TABLE projects;
ALTER PUBLICATION supabase_realtime ADD TABLE members;
