# OVERVIEW - HealthForceHub PM

## Implemented Release (2026-11-09)
The single-file app now includes project stakeholders (one person across multiple projects), Project / Epic / Feature / User Story / Task hierarchy with leaf completion rollups, agent briefs with copy action, separate human assignee / executing agent / reviewer, manual repository/branch/commit/PR references, a human review inbox, and completion evidence.

These features work locally. `delivery_features.sql` is an additive migration for the live text-ID compatibility schema and must be applied before shared sync for the new metadata and stakeholders is available. The updated app has not been deployed in this session. Agent execution and GitHub/CI polling remain manual.

## Product Vision
HealthForceHub PM is a repo-native Agentic Project Management tool for a small development team building healthcare and med spa software. It is designed to do more than display tasks: it should preserve project memory, capture change history, and provide structured operating context for both humans and agents.

The UI remains a single-file browser app for low-friction daily use. The long-term system design is Supabase-first, with the browser acting as a local-first workspace that can later sync into a richer backend model.

## Product Positioning
This tool sits between a lightweight kanban board and an internal engineering operating system.

Compared with Jira or Linear:
- It lives inside the repo.
- It can run without a separate SaaS PM account.
- It is tailored to the team's real delivery flow rather than generic ticketing.
- It is being shaped specifically for agent-assisted development.

## What Makes It Agentic
The core design direction is not "task board with cloud sync." It is:
- Structured task context for agents: reviewer, risk, next action, blocked reason, definition of done, environment, repo URL, PR URL
- Append-only activity history via events
- Agent execution history via agent runs
- Stable project memory via project contexts
- Workflow orchestration through backend workflow tables

Agents should be able to answer:
- What changed?
- What is blocked?
- What should happen next?
- What context is stable vs. transient?
- Which work is ready for human review vs. agent execution?

## Current Working Model
- Frontend: single-file HTML app, inline CSS, inline JS
- Runtime mode: local-first in browser storage
- Target backend: Supabase
- Backend design goal: one shared source of truth for tasks, task briefs, project contexts, events, comments, workflows, and agent runs

## Primary Client Context
Prosper Health & Aesthetics / Prosper Direct Health remains the main reference implementation for product needs:
- Online self-booking widget embedded on Wix
- Stripe payment collection at booking
- HealthForceHub API integration for providers, availability, and appointment creation
- Twilio A2P SMS confirmations
- HIPAA-sensitive patient workflows such as photo consent and clinical notes

## Active Projects (as of 2026-05-22)
| Project | Status | Owner | Target |
|---|---|---|---|
| EMR Core Platform | Active | Alex Chen | 2026-06-30 |
| Booking Widget Integration | Active | Alex Chen | 2026-04-15 |
| Med Spa UI Redesign | Active | Maria Santos | 2026-07-01 |

## Key Modules
Patient Registration · Appointments · Clinical Notes · Prescriptions · Billing & Claims · Lab Results · Reporting · Admin & Settings · Security & Auth · Integrations

## Current Design Priorities
1. Keep the app easy to open and use daily.
2. Make task data structurally useful for agents, not just humans.
3. Treat events and agent runs as first-class operational history.
4. Align the local browser model with the Supabase schema so the future sync layer is straightforward.
5. Preserve internal-team speed: no auth gates in the UI for now, no framework, no bundler.

## Current Status
The design has moved away from Firebase. The app is now being documented and shaped as a local-first client with a Supabase backend target. The most important architectural shift is from "board state only" to "board state plus structured memory plus event history plus agent execution history." The team-facing shared version is now published through GitHub Pages, with project-owner creation available directly inside the project modal.
