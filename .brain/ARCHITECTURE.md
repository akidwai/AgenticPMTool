# ARCHITECTURE - HealthForceHub PM

## Stack Decision: Single HTML File
Decision:
The operational UI stays in one `healthforcehub-pm.html` file with inline CSS and inline JavaScript.

Why:
- Zero setup friction for the internal team
- Opens immediately from disk or a static server
- No npm, bundler, or framework maintenance burden
- Fits the current scale of the product

Accepted trade-off:
- Manual organization discipline is required
- No component isolation
- No type system inside the browser app
- Large-file maintenance gets harder as features grow

## Persistence Strategy: Local-First, Supabase-Target
Decision:
The browser app currently operates local-first using `localStorage`, but the system-of-record design is Supabase.

Why:
- The team can keep using the PM tool immediately while the backend settles
- Data model changes can be tested locally without blocking frontend work
- The local browser model now mirrors the direction of the Supabase schema more closely than the older Firebase design did

Current local keys:
- `emr-tasks`
- `emr-members`
- `emr-projects`
- `emr-scfg`
- `emr-hist`
- `emr-user`
- `emr-events`
- `emr-agent-runs`

Planned Supabase mapping:
- local tasks -> `tasks` + `task_briefs`
- local projects -> `projects` + `project_contexts`
- local comments -> `task_comments`
- local events -> `events`
- local agent queue / history -> `agent_runs`

## Data Model Direction
Decision:
The product should store more than board state. It should store execution context, operating memory, and historical change data.

That means the architecture is built around four layers:
1. Current state
   Tasks, projects, members, sprint assignments, statuses
2. Structured execution context
   Reviewer, next action, blocked reason, definition of done, risk level, environment, repo/PR links, agent status
3. Append-only history
   Events for create/update/move/comment/delete and future workflow transitions
4. Agent execution record
   Agent runs, tool calls, and workflow runs

## Browser App Runtime Model
All views still render from in-memory arrays and re-render via `renderAll()`.

Why this is still acceptable:
- Task volume is small
- Single internal team
- Simplicity is worth more than frontend abstraction right now

Important change from older design:
The browser app now includes agent-aware task fields, local event logging, and local agent run tracking. It is no longer just a kanban surface.

## Sprint Model
Current browser behavior:
- Sprints are still computed from a start date and fixed sprint length
- Historical velocity overrides remain stored as raw text

Backend target:
- Supabase stores `sprints` explicitly

Why the split exists:
- Computed sprints are fast and lightweight in the current HTML app
- Stored sprints are safer for analytics, auditability, and long-term historical integrity

## Event-Centric Design
Decision:
Events are a first-class system concept, not an optional audit trail.

Why:
- Agents need timelines, not only snapshots
- Product operations benefit from append-only history
- Blockers, moves, comments, and workflow changes become queryable later in Supabase

Current browser behavior:
- The app records local events for task/member/project changes and agent queueing

Backend target:
- Supabase `events` becomes the durable timeline and replay source

## Agentic Design Assumptions
The PM system assumes future agent participation in planning and delivery, including:
- Planning or triage runs
- Execution-oriented runs
- Review or QA-oriented runs
- Workflow-triggered runs

A task therefore needs separate human-delivery and agent-delivery signals.

Examples:
- Task status may be `inprogress`
- Agent status may independently be `queued`, `running`, `needs_human`, or `failed`

## Security / Auth Position
Current UI:
- Still internal-use oriented
- "Switch Developer" remains a lightweight local identity picker
- No auth gate has been added in the browser app

Backend position:
- Supabase schema is prepared for authenticated use and row-level security
- The data model is ready for stronger auth later
- The UI intentionally avoids friction until the team actually needs it

## Near-Term Integration Path
1. Keep local-first browser usage working.
2. Add Supabase read/write adapters for tasks, task briefs, events, and agent runs.
3. Replay local events into Supabase.
4. Gradually move analytics and history views to backend-backed data.
5. Preserve the single-file UI unless the codebase becomes meaningfully harder to maintain than a split version.
