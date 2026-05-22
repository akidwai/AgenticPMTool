# ARCHITECTURE — HealthForceHub PM

## Stack Decision: Single HTML File
**Decision:** Entire app lives in one `healthforcehub-pm.html` file — inline CSS, inline JS, no build system.

**Why:** Zero setup friction for a small healthcare dev team. The PM tool should never block work; it needs to open instantly, travel with the project, and require no npm install, no Node version, no bundler. The complexity ceiling for this tool doesn't justify a framework.

**Trade-off accepted:** No component isolation, no TypeScript, no hot reload. Manual discipline required to keep the file organized.

## Persistence: Firebase + localStorage Dual-Mode
**Decision:** Firebase Firestore is the cloud layer; localStorage is the offline fallback. The app auto-detects mode.

**Why:** Teams working locally (or without a Firebase config) get a fully functional tool. When cloud sync is needed (multi-device, multi-person), a Firebase project can be wired in via the UI without changing any code. The `fb-status` indicator in the header shows the current mode.

**Mode switching:** Pasting a Firebase config JSON into the setup modal initializes Firestore listeners. Removing config drops back to localStorage. No data migration tooling — data lives in whichever store was active.

**Firebase collections:** `tasks`, `members`, `projects`, `meta` (sprint config + sprint history docs).

**localStorage keys:**
- `emr-tasks` — serialized task array
- `emr-members` — serialized member array
- `emr-projects` — serialized project array
- `emr-scfg` — sprint config object `{projectStart, sprintLength}`
- `emr-hist` — raw velocity history override text
- `emr-user` — current user name string

## Sprint Engine
**Decision:** Sprints are computed, not stored. Given a `projectStart` date and `sprintLength` (days), all sprint labels are generated at runtime.

**Why:** Avoids a sprints collection that needs to be kept in sync. Changing the project start date regenerates all sprint labels. Task `sprintId` values (`sprint-1`, `sprint-2`, …) remain valid because they're based on sprint number, not date.

**Trade-off:** Historical velocity overrides are stored as raw text (`Alex Chen: 8, 13, 10, 15`) and assigned to the earliest past sprints positionally. If sprint count changes, override assignments can shift.

## Velocity Engine
Velocity is computed per-member per-sprint by summing `storyPoints` of `done` tasks. Past sprints with zero task-derived velocity fall back to the historical override text (for pre-system sprints). Sparkline SVGs are rendered inline as raw SVG strings.

## Rendering
All views (Kanban board, list, stats, team) re-render from the in-memory `tasks`/`members`/`projects` arrays on every state change via `renderAll()`. No virtual DOM, no diffing — full DOM replacement on each call.

**Why acceptable:** The dataset is small (tens to low hundreds of tasks). DOM replacement is instantaneous at this scale.

## Firebase SDK
Loaded from Google CDN (firebase-app-compat, firebase-firestore-compat, firebase-auth-compat, v9.22.2). Compat layer used (not modular) to keep the single-file pattern viable without a bundler.

## No Authentication (Current)
The "Switch Developer" button is a name picker stored in localStorage — not real auth. Firebase Auth is imported but not yet wired to login gates.

**Why:** Internal tool used by a known small team. Auth adds friction with no current security benefit. This should be revisited before any external/client-facing use.
