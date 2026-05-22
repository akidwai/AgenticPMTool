# SCHEMA — HealthForceHub PM

All data lives in Firebase Firestore (cloud mode) or localStorage (local mode). The in-memory shape is identical regardless of storage backend.

---

## Task
Collection: `tasks` | localStorage key: `emr-tasks`

| Field | Type | Notes |
|---|---|---|
| `id` | string | `uid()` — base36 timestamp + random |
| `title` | string | Required |
| `desc` | string | Optional description |
| `module` | string | One of the 10 EMR modules (see below) |
| `status` | string | `backlog` · `feature` · `ready` · `inprogress` · `testing` · `done` |
| `priority` | string | `Low` · `Medium` · `High` · `Critical` |
| `assignee` | string | Member name (freetext match to `members.name`) |
| `due` | string | ISO date `YYYY-MM-DD` |
| `progress` | number | 0–100 |
| `storyPoints` | number | Fibonacci: 0, 1, 2, 3, 5, 8, 13 |
| `sprintId` | string | `sprint-N` (computed sprint number) or `""` |
| `projectId` | string | References `projects.id` or `""` |
| `notes` | string | Acceptance criteria / internal notes |
| `comments` | array | `[{user, text, date}]` |
| `blockers` | array | Array of task IDs this task is blocked by |
| `blocks` | array | Array of task IDs this task blocks (derived) |

**Valid modules:** Patient Registration · Appointments · Clinical Notes · Prescriptions · Billing & Claims · Lab Results · Reporting · Admin & Settings · Security & Auth · Integrations

---

## Member
Collection: `members` | localStorage key: `emr-members`

| Field | Type | Notes |
|---|---|---|
| `id` | string | `uid()` |
| `name` | string | Used as FK in tasks.assignee |
| `role` | string | Job title |
| `email` | string | |
| `phone` | string | |
| `dept` | string | Engineering · Design · QA / Testing · Product · DevOps · Management · Integrations · Support |
| `status` | string | `active` · `away` · `offline` |
| `skills` | string | Comma-separated skill list |
| `notes` | string | |
| `color` | string | Hex color for avatar background |

---

## Project
Collection: `projects` | localStorage key: `emr-projects`

| Field | Type | Notes |
|---|---|---|
| `id` | string | Manual (`proj-1`, etc.) for seeds; `uid()` for user-created |
| `name` | string | Required |
| `desc` | string | |
| `color` | string | Hex — used for banner and dot accents |
| `icon` | string | Single emoji |
| `status` | string | `active` · `hold` · `completed` · `archived` |
| `start` | string | ISO date |
| `end` | string | ISO date (target) |
| `owner` | string | Member name |
| `notes` | string | Links, resources |

---

## Meta (Firestore only)
Collection: `meta`

| Document | Fields | Notes |
|---|---|---|
| `sprintConfig` | `{projectStart: string, sprintLength: number}` | Mirrors `emr-scfg` localStorage |
| `sprintHistory` | `{histRaw: string}` | Raw velocity override text; mirrors `emr-hist` localStorage |

---

## Sprint (computed — never stored)
Sprints are generated at runtime from `sprintConfig`. Shape returned by `genSprints()`:

| Field | Type | Notes |
|---|---|---|
| `id` | string | `sprint-N` |
| `number` | number | 1-indexed |
| `label` | string | `Sprint N` |
| `startDate` | string | ISO date |
| `endDate` | string | ISO date |

Sprint status (past / current / future) is computed against today's date at render time.

---

## Seed Data (initial state)
On first load (no localStorage data), the app seeds:
- 3 members: Alex Chen, Maria Santos, James Wright
- 3 projects: EMR Core Platform, Booking Widget Integration, Med Spa UI Redesign
- ~30 tasks spanning all modules, with Sprint 4 history pre-populated for velocity charts
