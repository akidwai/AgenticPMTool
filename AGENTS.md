# AGENTS.md — HealthForceHub PM

## What this is
A single-file project management board (`healthforcehub-pm.html`) for tracking the HealthForceHub EMR build and related client integrations. No framework, no build step, no npm.

## Stack
- **Frontend:** Vanilla JS + inline CSS, single HTML file
- **Storage:** Firebase Firestore (cloud) with localStorage fallback (local/offline)
- **Firebase SDK:** v9.22.2 compat, loaded from Google CDN
- **Hosting:** Open directly in browser or via any static file server

## Running locally
```
python -m http.server 8080
# then open http://localhost:8080/healthforcehub-pm.html
```

## Key files
| Path | Purpose |
|---|---|
| `healthforcehub-pm.html` | Entire application |
| `.brain/OVERVIEW.md` | Product vision, active projects, market context |
| `.brain/ARCHITECTURE.md` | Technical decisions and rationale |
| `.brain/SCHEMA.md` | Data model reference |
| `.brain/BUILD_LOG.md` | Append-only work journal |

## Active projects (2026-05-22)
1. **EMR Core Platform** — foundation modules (patient reg, clinical notes, prescriptions)
2. **Booking Widget Integration** — Stripe + HealthForceHub API + Twilio SMS (most urgent)
3. **Med Spa UI Redesign** — premium light-mode UI targeting med spa market

## Team
- Alex Chen — Lead Developer (Full-stack, owns backend API and integrations)
- Maria Santos — UI/UX Designer (owns frontend design, UX flows)
- James Wright — QA Engineer (owns QA checklists, Stripe/SMS testing)

## Preferences
- Keep the app as a single HTML file unless complexity forces a split
- No frameworks, no bundlers — vanilla JS only
- localStorage mode must always work without Firebase
- Do not add auth gates (current team is small and internal)

## Current status
Sprint tracking live from 2026-01-05 (14-day sprints). Critical path: Booking Widget (HFH API credentials → middleware server → Stripe webhook → Twilio SMS → QA → launch).
