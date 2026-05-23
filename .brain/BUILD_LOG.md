# BUILD_LOG — HealthForceHub PM
Append-only. New entries at the bottom. Corrections go in a new dated entry.

---

## 2026-05-22 — Project initialized; .brain/ memory layer created

**Agent:** Claude Sonnet 4.6 (claude-code)

Reviewed the full `healthforcehub-pm.html` source and established the `.brain/` living memory convention for this project.

**Files created:**
- `.brain/OVERVIEW.md` — product vision, market positioning, active project status
- `.brain/ARCHITECTURE.md` — single-file rationale, dual-mode persistence decision, sprint engine, velocity engine, rendering approach
- `.brain/SCHEMA.md` — full data model for tasks, members, projects, meta, and computed sprints
- `.brain/BUILD_LOG.md` — this file
- `AGENTS.md` — high-level handoff for any agent or contributor onboarding cold

**App state at time of snapshot:**
- Single HTML file (~1,400+ lines), no build system, no npm
- Firebase Firestore + localStorage dual-mode persistence
- Three active projects: EMR Core Platform, Booking Widget Integration, Med Spa UI Redesign
- Sprint engine running from 2026-01-05, 14-day sprints
- Seed team: Alex Chen (Lead Dev), Maria Santos (UI/UX), James Wright (QA)
- Most time-critical workstream: Booking Widget Integration (Stripe + HFH API + Twilio SMS)
- Local dev server confirmed running at http://localhost:8080

**No code changes made this session — documentation only.**

---

## 2026-05-22 — Full Supabase schema designed for Agentic PM tool

**Agent:** Claude Sonnet 4.6 (claude-code)

Designed and wrote the full production database schema for migrating from Firebase/localStorage to Supabase (PostgreSQL + pgvector).

**File created:** `schema.sql` — ready to run in Supabase Dashboard > SQL Editor.

**Key architectural decisions:**
- **pgvector on tasks, projects, agent_memory** — enables semantic search and agent context retrieval via cosine similarity
- **Sprints stored (not computed)** — unlike the current HTML app which generates sprints at runtime; stored sprints are safer for historical data integrity
- **`events` table is append-only** — ground truth audit trail; agents and UI both write here, nothing is ever deleted
- **`agent_memory` has `importance` float + `expires_at`** — allows agents to weight retrieval and purge short-term context
- **`agent_runs.parent_run_id` self-FK** — enables chained/nested agent call trees to be reconstructed
- **`workflows` + `workflow_runs`** — separates pipeline definition from execution instances; `context` jsonb is the shared state bus between steps
- **RLS enabled from day 1** — auth.role() = 'authenticated' baseline; ready to extend with org_id for multi-tenancy

**Tables created:** users, projects, sprints, tasks, task_dependencies, task_comments, agent_runs, agent_memory, events, agent_tools, agent_tool_calls, workflows, workflow_runs

**`.brain/SCHEMA.md` fully rewritten** to reflect the new Supabase schema.

---

## 2026-05-22 â€” Agentic design docs updated to match Supabase-first direction

**Agent:** Codex (GPT-5)

Updated the `.brain/` memory layer to reflect the newer design direction now represented in the HTML app and database schema.

**What changed conceptually:**
- Firebase is no longer the active architecture path
- The browser app is now documented as local-first, with Supabase as the target system of record
- The product is framed as an Agentic PM system rather than a standard kanban board with optional sync
- Event history, agent runs, and structured execution context are now treated as first-class design primitives

**Docs updated:**
- `.brain/OVERVIEW.md`
- `.brain/ARCHITECTURE.md`
- `.brain/SCHEMA.md`

**Important design changes captured in docs:**
- `project_contexts` described as stable project memory for humans and agents
- `task_briefs` described as structured execution context attached to tasks
- Local browser storage keys now include `emr-events` and `emr-agent-runs`
- Task model now includes reviewer, risk level, blocked reason, next action, definition of done, environment, repo URL, PR URL, and agent status
- The architecture is now explicitly "state + structured context + append-only history + agent execution records"

**Reason for update:**
The previous brain docs still described a Firebase/localStorage dual-mode board. That no longer matched the current design. The brain layer now reflects the actual intended system shape so future contributors and agents inherit the right mental model.
