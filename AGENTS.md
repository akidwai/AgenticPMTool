# AGENTS.md - HealthForceHub PM

## What this is
A single-file project management board (`healthforcehub-pm.html`) for tracking the HealthForceHub EMR build and related client integrations. No framework, no build step, no npm.

## Stack
- **Frontend:** Vanilla JS + inline CSS, single HTML file
- **Storage:** localStorage-first with Supabase sync path
- **Backend target:** Supabase PostgREST + Realtime
- **Hosting:** Open directly in browser or via any static file server

## Running locally
```
python serve.py
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
1. **EMR Core Platform** - foundation modules (patient reg, clinical notes, prescriptions)
2. **Booking Widget Integration** - Stripe + HealthForceHub API + Twilio SMS (most urgent)
3. **Med Spa UI Redesign** - premium light-mode UI targeting med spa market

## Team
- Alex Chen - Lead Developer (Full-stack, owns backend API and integrations)
- Maria Santos - UI/UX Designer (owns frontend design, UX flows)
- James Wright - QA Engineer (owns QA checklists, Stripe/SMS testing)

## Preferences
- Keep the app as a single HTML file unless complexity forces a split
- No frameworks, no bundlers - vanilla JS only
- localStorage mode must always work without cloud connectivity
- Do not add auth gates (current team is small and internal)

## Current status
The project board now supports inline owner creation from the project modal: users can create a new team member as an owner and assign them to a new or existing project in one flow. Local development uses `serve.py` for UTF-8/no-cache responses. Critical path remains Booking Widget (HFH API credentials -> middleware server -> Stripe webhook -> Twilio SMS -> QA -> launch).
