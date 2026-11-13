-- Additive migration for the deployed text-ID compatibility schema.
-- Apply in Supabase SQL Editor. No existing rows or tables are removed.
begin;

alter table public.tasks add column if not exists delivery jsonb not null default '{}';
-- The payload is extensible, but must remain a JSON object.
do $$ begin
  if not exists (select 1 from pg_constraint where conname='tasks_delivery_object'
    and conrelid='public.tasks'::regclass) then
    alter table public.tasks add constraint tasks_delivery_object check (jsonb_typeof(delivery)='object');
  end if;
end $$;

create table if not exists public.pm_stakeholders (
  id text primary key,
  profile jsonb not null,
  updated_at timestamptz not null default now(),
  constraint stakeholder_profile_object check (jsonb_typeof(profile) = 'object'),
  constraint stakeholder_name_required check (length(trim(profile->>'name')) > 0),
  constraint stakeholder_projects_array check (jsonb_typeof(profile->'projectIds') = 'array')
);

alter table public.pm_stakeholders enable row level security;
-- Matches the existing internal board's anonymous collaboration policy.
-- Names in the review UI are coordination labels, not authenticated signatures.
drop policy if exists "board read stakeholders" on public.pm_stakeholders;
drop policy if exists "board insert stakeholders" on public.pm_stakeholders;
drop policy if exists "board update stakeholders" on public.pm_stakeholders;
create policy "board read stakeholders" on public.pm_stakeholders
  for select to anon, authenticated using (true);
create policy "board insert stakeholders" on public.pm_stakeholders
  for insert to anon, authenticated with check (true);
create policy "board update stakeholders" on public.pm_stakeholders
  for update to anon, authenticated using (true) with check (true);
grant select, insert, update on public.pm_stakeholders to anon, authenticated;

create or replace function public.validate_work_hierarchy()
returns trigger language plpgsql set search_path = public as $$
declare
  kind text := coalesce(new.delivery->>'type', 'task');
  parent_id text := nullif(new.delivery->>'parentId', '');
  parent_row public.tasks;
  child_row public.tasks;
  expected_parent text;
begin
  if kind not in ('epic','feature','story','task') then
    raise exception 'Invalid work item type';
  end if;
  if kind <> 'task' and new.project_id is null then
    raise exception 'Epic, feature and story require a project';
  end if;
  expected_parent := case kind when 'feature' then 'epic' when 'story' then 'feature' when 'task' then 'story' end;
  if parent_id is not null then
    select * into parent_row from public.tasks where id = parent_id;
    if not found or parent_id = new.id or expected_parent is null
       or parent_row.project_id is distinct from new.project_id
       or coalesce(parent_row.delivery->>'type','task') <> expected_parent then
      raise exception 'Parent must be preceding work level in the same project';
    end if;
  end if;
  for child_row in select * from public.tasks where delivery->>'parentId' = new.id loop
    if child_row.project_id is distinct from new.project_id
       or kind is distinct from (case child_row.delivery->>'type'
         when 'feature' then 'epic' when 'story' then 'feature' when 'task' then 'story' end) then
      raise exception 'Move children before changing parent type or project';
    end if;
  end loop;
  return new;
end;
$$;
drop trigger if exists validate_work_hierarchy on public.tasks;
create trigger validate_work_hierarchy before insert or update on public.tasks
  for each row execute function public.validate_work_hierarchy();
create index if not exists tasks_delivery_parent on public.tasks ((delivery->>'parentId'));
create index if not exists tasks_delivery_review on public.tasks ((delivery->>'reviewStatus'));
notify pgrst, 'reload schema';
commit;
