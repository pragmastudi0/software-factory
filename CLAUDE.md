# Autonomous Software Factory

A fully autonomous AI-powered platform that transforms a natural language app idea into a deployed, tested, production web application — with no human intervention required. **Controlled entirely via Telegram.**

## Architecture Overview

```
Telegram Bot (primary interface)
          │
          ▼
User Idea / Commands
          │
          ▼
┌─────────────────────────────────────────────────────────────────┐
│                    n8n Orchestrator (port 5678)                  │
│                                                                   │
│  00 Telegram Bot ──▶ 01 Idea Intake ──▶ 02 Project Setup        │
│         ▲                                        │               │
│         │                              03 Multi-Agent Pipeline   │
│  11 Notifications                                │               │
│  (called by all)                       04 Code Generation        │
│                                        (OpenHands)               │
│                                                  │               │
│                                        05 Validation Loop        │
│                                                  │               │
│                                        06 Deployment (Vercel)    │
│                                                  │               │
│                                        07 QA Automation          │
│                                        (Playwright)              │
│                                                  │               │
│   10 Continuous ◀── 09 Memory System ◀── 08 Feedback Collection  │
│   Improvement   ──▶ (loop back to 04)                            │
└─────────────────────────────────────────────────────────────────┘
          │                    │                    │
          ▼                    ▼                    ▼
   ┌────────────┐     ┌──────────────┐     ┌─────────────┐
   │  Gemini API│     │    Supabase  │     │  GitHub     │
   │  (primary  │     │  (DB/Memory) │     │  (Repo/CI)  │
   │   LLM)     │     └──────────────┘     └─────────────┘
   └────────────┘
          │
   ┌────────────┐     ┌──────────────┐     ┌─────────────┐
   │ OpenRouter │     │  OpenHands   │     │   Vercel    │
   │  (fallback │     │ (Code Agent) │     │  (Deploy)   │
   │   LLM)     │     │  port 3000   │     └─────────────┘
   └────────────┘     └──────────────┘
```

## Quick Start

### 1. Prerequisites

- Docker + Docker Compose v2
- A VPS or always-on machine (4GB RAM minimum, 8GB recommended)
- Accounts/API keys for: Google AI Studio, GitHub, Supabase, Vercel, OpenRouter
- A Telegram Bot (create via [@BotFather](https://t.me/BotFather))

### 2. Create Your Telegram Bot

1. Open Telegram and message [@BotFather](https://t.me/BotFather)
2. Type `/newbot` and follow the prompts
3. Copy the token (format: `1234567890:AAxxxxxxxx...`)
4. Get your chat ID by messaging [@userinfobot](https://t.me/userinfobot)
5. Set these in your `.env`:
   ```
   TELEGRAM_BOT_TOKEN=your_token_here
   TELEGRAM_ALLOWED_USERS=your_chat_id
   TELEGRAM_ADMIN_CHAT_ID=your_chat_id
   ```

### 3. Setup

```bash
git clone https://github.com/pragmastudi0/software-factory
cd software-factory
bash scripts/setup.sh
```

The setup script will:
- Check prerequisites
- Create `.env` from `.env.example`
- Validate all required environment variables
- Run Supabase database migrations (including Telegram tables)
- Start n8n + OpenHands + Postgres via Docker Compose
- Import and activate all 12 n8n workflows
- Register the Telegram webhook automatically

### 4. Start Using Telegram

Message your bot on Telegram:

```
/start
```

You'll see a welcome message with active projects and all available commands.

```
/nuevo
```

Then describe your app idea in plain text — the factory does the rest.

### 5. Available Bot Commands

| Command | Description |
|---------|-------------|
| `/start` | Welcome + list active projects |
| `/nuevo` | Create a new project (prompts for idea) |
| `/estado` | Current status of a project |
| `/roadmap` | AI-generated roadmap and tech stack |
| `/deploy` | Trigger deployment with approval button |
| `/qa` | Run Playwright test suite |
| `/errores` | Show recent test failures |
| `/mejorar` | Request a new feature or improvement |
| `/feedback` | Submit feedback for the improvement loop |
| `/costos` | Token usage and estimated API cost |
| `/agentes` | Recent agent activity log |

### 6. Approval Buttons

When the factory needs your decision, Telegram shows inline buttons:

```
🚀 Deploy a Producción

📦 Proyecto: CRM Inmobiliario
🔘 Estado actual: qa

¿Confirmas el despliegue a Vercel?

[✅ APROBAR]  [❌ RECHAZAR]  [⏸ POSPONER]
```

These appear for: deployments, structural code changes, large refactors.

### 7. Submit via HTTP (alternative)

```bash
curl -X POST http://localhost:5678/webhook/intake \
  -H "Content-Type: application/json" \
  -d '{"idea": "A project management tool for freelancers with time tracking and invoice generation"}'
```

---

## Services

| Service | URL | Purpose |
|---------|-----|---------|
| n8n | http://localhost:5678 | Workflow orchestration dashboard |
| OpenHands | http://localhost:3000 | Code agent UI — watch it code |
| Supabase | https://app.supabase.com | Database, auth, edge functions (remote) |
| Vercel | https://vercel.com/dashboard | Deployments (remote) |

---

## The 12-Workflow Pipeline

| # | Workflow | What Happens |
|---|----------|-------------|
| 0 | `00_telegram_bot` | **Primary UI**: receives all Telegram updates, routes commands, processes approvals |
| 1 | `01_idea_intake` | User idea → Gemini generates full PRD; notifies Telegram |
| 2 | `02_project_setup` | GitHub repo + branches + milestones + issues |
| 3 | `03_multi_agent_pipeline` | 9 specialized AI agents produce complete specs; notifies Telegram |
| 4 | `04_code_generation` | OpenHands writes all code and pushes to GitHub; notifies Telegram |
| 5 | `05_validation_loop` | Build/lint/typecheck; auto-fix up to 3 times; notifies pass/fail |
| 6 | `06_deployment` | Vercel deployment with status tracking; notifies with live URL |
| 7 | `07_qa_automation` | Playwright E2E tests; auto-fix loop; notifies project live |
| 8 | `08_feedback_collection` | Collects feedback, analyzes sentiment/priority |
| 9 | `09_memory_system` | Stores all context for future iterations |
| 10 | `10_continuous_improvement` | Daily: feedback → plan → code → deploy (infinite); notifies Telegram |
| 11 | `11_telegram_notifications` | **Utility**: called by all workflows to send formatted Telegram messages |

---

## The 9 AI Agents

| Agent | System Prompt | Produces |
|-------|---------------|---------|
| Product Manager | `agents/product-manager.md` | PRD, user stories, roadmap |
| Architect | `agents/architect.md` | Component tree, API contracts, DB schema |
| UX/UI Designer | `agents/ux-ui-designer.md` | Design system, layouts, user flows |
| Backend Engineer | `agents/backend-engineer.md` | Edge functions, auth flows, Supabase ops |
| Frontend Engineer | `agents/frontend-engineer.md` | All React components, pages, hooks, configs |
| Database Engineer | `agents/database-engineer.md` | SQL migrations, RLS policies, indexes |
| QA Engineer | `agents/qa-engineer.md` | Playwright test suite (5 test files) |
| DevOps Engineer | `agents/devops-engineer.md` | vercel.json, GitHub Actions CI, build config |
| Security Auditor | `agents/security-auditor.md` | OWASP audit, Supabase security checklist |

All agents output **structured JSON** using Gemini's `responseMimeType: "application/json"` — no markdown, no ambiguity, directly parseable.

---

## Generated App Tech Stack

Every app built by the factory uses this exact stack:

- **Frontend**: React 18 + Vite + TypeScript (strict) + Tailwind CSS
- **Backend**: Supabase Edge Functions (Deno/TypeScript)
- **Database**: Supabase (PostgreSQL 15) with RLS on all tables
- **Auth**: Supabase Auth (email/password)
- **Hosting**: Vercel (frontend) + Supabase (backend/DB)
- **Testing**: Playwright E2E (navigation, auth, CRUD, API, performance)
- **CI**: GitHub Actions (lint + typecheck + build on every push)

---

## Database Schema (Factory DB in Supabase)

| Table | Purpose |
|-------|---------|
| `projects` | Master registry with status tracking |
| `requirements` | PRD versions (supports multiple iterations) |
| `tasks` | Per-agent work assignments |
| `agent_outputs` | All LLM responses with token counts |
| `deployments` | Vercel deployment history |
| `test_results` | Playwright test results per deployment |
| `feedback` | User + system feedback with sentiment |
| `memory` | Cross-session key/value context store |
| `error_patterns` | Auto-fix library (seeded with 6 common errors) |
| `telegram_conversations` | Per-user bot state machine (idle/awaiting_idea/etc.) |
| `telegram_approvals` | Approval requests with callback_data, status, expiry |
| `telegram_notification_log` | Audit trail of all Telegram messages sent |

Migrations:
- `supabase/migrations/001_initial_schema.sql` — core schema
- `supabase/migrations/002_rls_policies.sql` — row level security
- `supabase/migrations/003_telegram_schema.sql` — Telegram tables

---

## Key Design Decisions

### Why n8n instead of custom code?
n8n provides visual workflow debugging, automatic retry policies, execution history, and webhook management — all without writing infrastructure code. Workflows are inspectable and modifiable by non-developers.

### Why OpenHands instead of direct LLM code generation?
OpenHands provides a sandboxed execution environment where the agent can actually **run** `npm install`, **execute** `npm run build`, **see** the errors, and **fix** them — iteratively. A raw LLM can only generate code; it can't verify it compiles.

### Why Gemini 2.0 Flash as primary LLM?
1M token context window handles entire codebases in a single call. The Flash variant balances capability vs. cost for high-volume factory usage (9 agents × N projects = many API calls).

### Why OpenRouter as fallback?
Free-tier models on OpenRouter prevent complete outages when Gemini quota is exhausted. The factory degrades gracefully rather than stopping.

### Why separate Postgres for n8n?
n8n's execution metadata (logs, run history) is high-volume and noisy. Keeping it in a local Postgres instance prevents it from polluting the project's Supabase database and incurring Supabase read/write costs.

### Why fire-and-forget sub-workflow calls?
Code generation and QA can take 20-30 minutes. n8n has execution timeouts. By calling sub-workflows with `waitForSubWorkflow: false`, each phase is tracked via Supabase status rather than n8n's execution thread — allowing unlimited run time.

---

## Environment Variables

See `.env.example` for the complete list with descriptions.

### Critical variables (system won't work without these)

| Variable | Where to get it |
|----------|----------------|
| `GEMINI_API_KEY` | https://aistudio.google.com/app/apikey |
| `GITHUB_TOKEN` | https://github.com/settings/tokens (scopes: repo, issues, workflows) |
| `GITHUB_ORG` | Your GitHub organization or username |
| `SUPABASE_URL` | Supabase project → Settings → API |
| `SUPABASE_SERVICE_ROLE_KEY` | Supabase project → Settings → API |
| `SUPABASE_ANON_KEY` | Supabase project → Settings → API |
| `VERCEL_TOKEN` | https://vercel.com/account/tokens |
| `N8N_WEBHOOK_URL` | Public URL where n8n is accessible (e.g. https://n8n.yourdomain.com/) |

---

## Troubleshooting

### n8n workflows not importing
Check `docker compose logs n8n`. Common causes:
- Postgres not yet healthy when n8n starts → wait 30s and re-run `setup.sh`
- Workflow JSON syntax error → validate with `cat n8n/workflows/*.json | jq .`

### OpenHands not completing tasks
Check `docker compose logs openhands`. Common causes:
- Missing Docker socket mount → ensure `privileged: true` and `/var/run/docker.sock` mounted
- Gemini API quota exceeded → check OpenRouter fallback is configured
- OpenHands image not pulled → run `docker compose pull openhands`

### Vercel deployment failing
1. Verify `VERCEL_TOKEN` has correct permissions
2. Check `GITHUB_ORG/GITHUB_TOKEN` can access the repo
3. Look at the `deployments` table in Supabase for `build_log`
4. The most common cause: missing `VITE_SUPABASE_URL` / `VITE_SUPABASE_ANON_KEY` as Vercel project environment variables

### Build errors keep looping
The validation loop retries up to `FACTORY_MAX_CODE_FIX_RETRIES` (default: 3) times.
If it's still failing:
1. Check the `error_patterns` table in Supabase — add new patterns for recurring errors
2. Look at the n8n execution log for the exact error message
3. You can manually fix the code in GitHub and push — the next iteration will pick it up

### High Gemini API costs
- Switch `GEMINI_PRO_MODEL` from `gemini-1.5-pro-latest` to `gemini-1.5-flash-latest` for PRD generation
- All agent calls already use `gemini-2.0-flash-exp` (cheaper than Pro)
- Set `FACTORY_AGENT_TIMEOUT_SECONDS=120` to fail faster on slow responses
- Use `/costos` in Telegram to monitor token usage in real-time

### Telegram bot not responding
1. Verify webhook is registered: `curl https://api.telegram.org/bot{TOKEN}/getWebhookInfo`
2. Check n8n can receive the webhook: `N8N_WEBHOOK_URL` must be publicly accessible (not localhost)
3. Re-register the webhook: `curl -X POST https://api.telegram.org/bot{TOKEN}/setWebhook -d '{"url":"https://your-n8n/webhook/telegram"}'`
4. Check `TELEGRAM_ALLOWED_USERS` contains your exact Telegram chat ID (get it from @userinfobot)
5. Check n8n logs: `docker compose logs n8n | grep telegram`

### Approval buttons not working
- Buttons expire after 24 hours — request a new approval with `/deploy`
- Check the `telegram_approvals` table in Supabase for `status` field
- The approval callback_data format is: `{action}:{type}:{entity_id}:{chat_id}:{timestamp}`

### Telegram messages not arriving
- Verify `TELEGRAM_ADMIN_CHAT_ID` is set to your correct chat ID
- Notifications are sent to `TELEGRAM_ADMIN_CHAT_ID` only — add multiple IDs to `TELEGRAM_ALLOWED_USERS` for multi-user access
- Check the `telegram_notification_log` table in Supabase for recent messages

---

## File Structure

```
software-factory/
├── docker-compose.yml              # n8n + OpenHands + Postgres containers
├── .env.example                    # All env vars with descriptions
├── .env                            # Your values (gitignored)
├── CLAUDE.md                       # This file
├── scripts/
│   └── setup.sh                    # One-command setup
├── supabase/
│   └── migrations/
│       ├── 001_initial_schema.sql  # 9 tables, ENUMs, triggers
│       ├── 002_rls_policies.sql    # Row Level Security
│       └── 003_telegram_schema.sql # Telegram conversations, approvals, notification log
├── n8n/
│   ├── workflows/                  # 12 workflow JSON files (00–11)
│   └── credentials/
│       └── README.md               # Manual credential setup instructions
├── agents/                         # 9 agent system prompts (Markdown)
│   ├── product-manager.md
│   ├── architect.md
│   ├── ux-ui-designer.md
│   ├── backend-engineer.md
│   ├── frontend-engineer.md
│   ├── database-engineer.md
│   ├── qa-engineer.md
│   ├── devops-engineer.md
│   └── security-auditor.md
├── templates/                      # Reference templates
│   ├── prd-template.md
│   ├── architecture-template.md
│   └── playwright-tests-template.ts
└── openHands/
    └── task-payload-schema.json    # OpenHands API payload schema
```
