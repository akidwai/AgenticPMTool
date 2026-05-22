# OVERVIEW — HealthForceHub PM

## Product Vision
A self-contained, zero-dependency project management board purpose-built for the HealthForceHub EMR build. Designed to track all development work across the EMR platform and related client integrations — without requiring a separate SaaS PM tool.

## Market Positioning
Internal tool targeting small healthcare/med spa development teams (2–10 people). Competes in daily workflow with Jira and Linear, but lives inside the repo, requires no accounts, and can run fully offline via localStorage.

## Primary Client Context
**Prosper Health & Aesthetics / Prosper Direct Health** — a med spa client requiring:
- Online self-booking widget embedded on Wix site
- Stripe payment collection at booking
- HealthForceHub API integration (providers, availability, appointment creation)
- Twilio A2P SMS confirmations
- HIPAA-compliant patient photo consent and clinical notes

## Active Projects (as of 2026-05-22)
| Project | Status | Owner | Target |
|---|---|---|---|
| EMR Core Platform | Active | Alex Chen | 2026-06-30 |
| Booking Widget Integration | Active | Alex Chen | 2026-04-15 |
| Med Spa UI Redesign | Active | Maria Santos | 2026-07-01 |

## Key EMR Modules
Patient Registration · Appointments · Clinical Notes · Prescriptions · Billing & Claims · Lab Results · Reporting · Admin & Settings · Security & Auth · Integrations

## Competitive Frame
Boulevard, Aesthetic Record, Jane App (med spa tier). Must reach Boulevard-equivalent quality for aesthetics/UX to win that market segment.

## Current Status
Sprint tracking active from 2026-01-05 (2-week sprints). Three parallel active projects. Booking Widget Integration is the most time-critical workstream (Stripe + HFH API + Twilio SMS).
