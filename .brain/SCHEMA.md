# SCHEMA - HealthForceHub Agentic PM Tool

## Active Compatibility Extension (2026-11-09)
The deployed browser model uses text IDs (`migration_compat.sql`). The UUID design below remains a target/reference, not the active browser contract. Apply `delivery_features.sql` to extend the compatibility database without dropping data.

- `tasks.delivery` JSONB: type (`epic`, `feature`, `story`, `task`), parentId, reviewer member ID, executing agent/status, objective, criteria, files, constraints, verification commands, repository/branch/commit/PR links, evidence array, review request/decision, and approval record.
- Evidence entries: id, type, text, optional HTTP(S) URL, author and createdAt. Screenshots are linked, not uploaded.
- Review statuses: draft, pending, approved, answered, changes_requested. Only implementation approval satisfies the browser completion gate.
- `pm_stakeholders`: text id, profile JSONB, updated_at. Profile contains name, email, role, organization, notes, projectIds array, updatedAt and deleted tombstone.
- Stakeholder RLS follows the existing anonymous internal board model: select, insert and update for browser roles. No browser delete grant is needed for tombstones.
- Hierarchy trigger validates adjacent parent type, project consistency and compatible child relationships. Indexes support parent and review-status lookup.

The SQL has not been applied to the live database in this session. Completion sign-off is a browser workflow rule, not a database-enforced or authenticated approval mechanism. No agent execution service or GitHub status integration is included.

Full DDL: see [schema.sql](../schema.sql). Run in Supabase Dashboard > SQL Editor.

This document reflects the current Supabase-first design direction, not the older Firebase/localStorage-only model.

---

## Design Intent
The schema is designed to support:
- Standard PM state: tasks, projects, users, sprints, comments, dependencies
- Structured execution context for agent-assisted delivery
- Append-only history via events
- Agent runtime tracking via agent runs and tool calls
- Long-lived memory and retrieval via pgvector-backed tables

---

## Extensions Required
| Extension | Purpose |
|---|---|
| `uuid-ossp` | UUID primary key generation |
| `vector` | pgvector semantic search and memory retrieval |

---

## Core PM Tables

### `users`
Mirrors `auth.users` and acts as the ownership / assignment anchor.

Key fields:
- `name`, `email`, `role`, `dept`
- `avatar_color`
- `skills`
- `availability`

---

### `projects`
Top-level workstreams such as EMR Core Platform or Booking Widget Integration.

Key fields:
- `name`, `description`
- `color`, `icon`
- `status`
- `start_date`, `end_date`
- `owner_id`
- `notes`
- `embedding`

---

### `project_contexts`
Structured, retrieval-friendly context for each project.

This is one of the important agentic additions. It stores the stable operating memory that would otherwise be lost in free-form notes or chat history.

Key fields:
- `summary`
- `goals`
- `constraints`
- `external_dependencies`
- `key_links`
- `release_target`
- `launch_notes`

Use this for:
- release constraints
- key API dependencies
- external vendor blockers
- architecture links
- launch readiness notes

---

### `sprints`
Stored sprints, scoped per project.

Key fields:
- `project_id`
- `number`
- `label`
- `start_date`
- `end_date`

The browser app still computes sprints locally today, but the backend schema stores them explicitly for long-term integrity and analytics.

---

### `tasks`
The main task state table.

Key fields:
- `project_id`
- `sprint_id`
- `title`, `description`
- `module`
- `status`
- `priority`
- `assignee_id`
- `due_date`
- `progress`
- `story_points`
- `notes`
- `embedding`

This table stores the current delivery state, not the full agent execution context by itself.

---

### `task_briefs`
Structured execution context attached 1:1 to a task.

This is another major agentic addition. It turns vague work items into agent-usable operating briefs.

Key fields:
- `reviewer_id`
- `definition_of_done`
- `next_action`
- `blocked_reason`
- `repo_url`
- `pr_url`
- `environment`
- `risk_level`
- `agent_status`
- `agent_owner`
- `last_agent_summary`
- `last_agent_run_id`
- `metadata`

Use this for:
- handoff to agents
- handoff back to humans
- operational clarity during blockers
- review routing
- release-risk surfacing

---

### `task_dependencies`
Many-to-many dependency map.

Meaning:
- `task_id` is blocked by `blocked_by_id`

This is the normalized backend version of the browser app's `blockedBy` array.

---

### `task_comments`
Human or system-authored task commentary.

Key fields:
- `task_id`
- `author_id`
- `author_name`
- `content`
- `created_at`

Task comments are distinct from events. Comments capture discussion; events capture the system timeline.

---

## Agentic Tables

### `agent_runs`
Every agent execution instance.

Key fields:
- `agent_type`
- `trigger`
- `input`, `output`
- `status`
- `error`
- `tokens_used`
- `duration_ms`
- `project_id`
- `task_id`
- `user_id`
- `parent_run_id`
- `metadata`
- `started_at`, `completed_at`

Use this for:
- run history
- debugging failures
- reconstructing multi-step chains
- cost and duration analysis

---

### `agent_tool_calls`
Every tool invocation within an agent run.

Key fields:
- `run_id`
- `tool_name`
- `input`
- `output`
- `error`
- `duration_ms`

This gives you observability inside a run, not just around it.

---

### `agent_memory`
Long-lived semantic memory.

Key fields:
- `agent_type`
- `scope`, `scope_id`
- `content`
- `embedding`
- `memory_type`
- `importance`
- `expires_at`
- `source_run_id`
- `metadata`

Use this for:
- facts
- decisions
- preferences
- project context
- recoverable error learnings

---

### `events`
Append-only operational timeline.

This is one of the most important tables in the whole design.

Key fields:
- `entity_type`
- `entity_id`
- `action`
- `actor_type`
- `actor_id`
- `actor_name`
- `before_state`
- `after_state`
- `metadata`
- `created_at`

Use this for:
- task history
- project history
- auditability
- replay/migration
- "what changed?" queries for agents

The schema now includes trigger support so inserts/updates/deletes on key tables can automatically produce event records.

---

### `agent_tools`
Registry of tools agents are allowed to call.

Key fields:
- `name`
- `description`
- `input_schema`
- `output_schema`
- `is_active`

---

### `workflows`
Workflow definitions for multi-step agent pipelines.

Key fields:
- `name`
- `description`
- `trigger_type`
- `trigger_config`
- `steps`
- `is_active`
- `project_id`
- `created_by`

Use this for operating playbooks such as:
- blocked task escalation
- ready-for-QA pipeline
- sprint summary generation
- release readiness checks

---

### `workflow_runs`
Execution records for workflows.

Key fields:
- `workflow_id`
- `status`
- `current_step`
- `context`
- `started_at`
- `completed_at`

The `context` field acts as the shared state bus across workflow steps.

---

## Index Strategy
Important indexes include:
- IVFFlat indexes on `tasks.embedding`, `projects.embedding`, `agent_memory.embedding`
- filtering indexes on `tasks(project_id, status)`, `tasks(assignee_id)`, `tasks(sprint_id)`
- dependency lookup on `task_dependencies(blocked_by_id)`
- task brief routing on `task_briefs(agent_status, risk_level)`
- timeline lookup on `events(entity_type, entity_id, created_at desc)`
- run tracing on `agent_runs(task_id, created_at desc)` and `agent_tool_calls(run_id, created_at desc)`

---

## RLS Summary
RLS is enabled broadly, including:
- `users`
- `projects`
- `sprints`
- `tasks`
- `task_dependencies`
- `task_comments`
- `project_contexts`
- `task_briefs`
- `agent_tools`
- `agent_tool_calls`
- `agent_runs`
- `agent_memory`
- `events`
- `workflows`
- `workflow_runs`

Current baseline:
- authenticated users can read/write most operational tables
- `events` are read-only for authenticated users in the current policy model

This is a good internal-team starting point and can be tightened later for tenant isolation.

---

## Browser App Alignment
The current HTML app is not fully Supabase-backed yet, but it is now conceptually aligned:
- local tasks already include fields like reviewer, risk level, next action, blocked reason, environment, repo URL, PR URL, and agent status
- local event logging mirrors the future `events` table
- local queued agent work mirrors the future `agent_runs` table

That alignment is intentional. It should make the next integration layer much simpler.
