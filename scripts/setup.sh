#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════
#  Autonomous Software Factory — Initial Setup Script
#  Usage: bash scripts/setup.sh
# ═══════════════════════════════════════════════════════════════════

set -euo pipefail

# ── Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log()  { echo -e "${GREEN}[SETUP]${NC} $1"; }
info() { echo -e "${BLUE}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
err()  { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$ROOT_DIR"

echo ""
echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     Autonomous Software Factory — Setup                ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

# ── 1. Prerequisites check
log "Checking prerequisites..."
command -v docker >/dev/null 2>&1 || err "Docker is required. Install from https://docs.docker.com/get-docker/"
docker compose version >/dev/null 2>&1 || err "Docker Compose v2 is required (docker compose, not docker-compose)"
command -v curl >/dev/null 2>&1 || err "curl is required."
JQ_AVAILABLE=false
command -v jq >/dev/null 2>&1 && JQ_AVAILABLE=true || warn "jq not found — some validation steps will be skipped."
command -v openssl >/dev/null 2>&1 || warn "openssl not found — you'll need to set N8N_ENCRYPTION_KEY manually."
log "Prerequisites OK."

# ── 2. .env file
if [ ! -f .env ]; then
  log "Creating .env from .env.example..."
  cp .env.example .env
  echo ""
  warn "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  warn "IMPORTANT: Edit .env and fill in ALL required values."
  warn ""
  warn "Required credentials:"
  warn "  • GEMINI_API_KEY       — https://aistudio.google.com/app/apikey"
  warn "  • GITHUB_TOKEN         — https://github.com/settings/tokens"
  warn "  • GITHUB_ORG           — Your GitHub org or username"
  warn "  • SUPABASE_URL         — https://app.supabase.com → Settings → API"
  warn "  • SUPABASE_SERVICE_ROLE_KEY"
  warn "  • SUPABASE_ANON_KEY"
  warn "  • VERCEL_TOKEN         — https://vercel.com/account/tokens"
  warn "  • N8N_BASIC_AUTH_PASSWORD"
  warn "  • N8N_DB_POSTGRESDB_PASSWORD"
  warn "  • N8N_WEBHOOK_URL      — Public URL where n8n is accessible"
  warn "  • TELEGRAM_BOT_TOKEN   — Create bot via @BotFather on Telegram"
  warn "  • TELEGRAM_ALLOWED_USERS — Comma-separated chat IDs (@userinfobot)"
  warn "  • TELEGRAM_ADMIN_CHAT_ID — Your Telegram chat ID for notifications"
  warn "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  read -r -p "Press ENTER after editing .env to continue, or Ctrl+C to abort..." _
fi

# ── 3. Load and validate .env
log "Loading environment variables..."
set -a
source .env
set +a

# Required vars check
REQUIRED_VARS=(
  "GEMINI_API_KEY"
  "GITHUB_TOKEN"
  "GITHUB_ORG"
  "SUPABASE_URL"
  "SUPABASE_SERVICE_ROLE_KEY"
  "SUPABASE_ANON_KEY"
  "VERCEL_TOKEN"
  "N8N_DB_POSTGRESDB_PASSWORD"
  "N8N_BASIC_AUTH_PASSWORD"
  "N8N_WEBHOOK_URL"
)

MISSING_VARS=()
for VAR in "${REQUIRED_VARS[@]}"; do
  VALUE="${!VAR:-}"
  if [ -z "$VALUE" ] || [[ "$VALUE" == *"CHANGE_ME"* ]] || [[ "$VALUE" == *"..."* ]]; then
    MISSING_VARS+=("$VAR")
  fi
done

if [ ${#MISSING_VARS[@]} -gt 0 ]; then
  err "Missing or placeholder values in .env:\\n  ${MISSING_VARS[*]}\\nPlease fill these in and re-run setup.sh"
fi

log "All required environment variables are set."

# ── 4. Auto-generate N8N_ENCRYPTION_KEY if needed
if [ "${N8N_ENCRYPTION_KEY:-}" = "CHANGE_ME_32_CHAR_RANDOM_STRING_HERE" ] || [ -z "${N8N_ENCRYPTION_KEY:-}" ]; then
  if command -v openssl >/dev/null 2>&1; then
    NEW_KEY=$(openssl rand -hex 16)
    # Update .env file
    if [[ "$OSTYPE" == "darwin"* ]]; then
      sed -i '' "s/N8N_ENCRYPTION_KEY=.*/N8N_ENCRYPTION_KEY=${NEW_KEY}/" .env
    else
      sed -i "s/N8N_ENCRYPTION_KEY=.*/N8N_ENCRYPTION_KEY=${NEW_KEY}/" .env
    fi
    export N8N_ENCRYPTION_KEY="$NEW_KEY"
    log "Generated N8N_ENCRYPTION_KEY and saved to .env."
  else
    warn "Cannot auto-generate N8N_ENCRYPTION_KEY — openssl not available."
    warn "Please set N8N_ENCRYPTION_KEY to a random 32-character string in .env."
  fi
fi

# ── 5. Verify Supabase connectivity
log "Verifying Supabase connection..."
SUPABASE_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
  -H "apikey: ${SUPABASE_SERVICE_ROLE_KEY}" \
  -H "Authorization: Bearer ${SUPABASE_SERVICE_ROLE_KEY}" \
  "${SUPABASE_URL}/rest/v1/")

if [ "$SUPABASE_STATUS" -ge 200 ] && [ "$SUPABASE_STATUS" -lt 300 ]; then
  log "Supabase connection OK (HTTP ${SUPABASE_STATUS})."
else
  err "Cannot connect to Supabase (HTTP ${SUPABASE_STATUS}). Check SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY."
fi

# ── 6. Run Supabase migrations
log "Checking database migrations..."

if command -v supabase >/dev/null 2>&1; then
  log "Supabase CLI found. Running migrations..."
  supabase db push --project-ref "$(echo "$SUPABASE_URL" | sed 's/https:\/\/\([^.]*\).*/\1/')" \
    2>/dev/null || {
    warn "supabase db push failed. Please run migrations manually."
  }
else
  echo ""
  warn "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  warn "Supabase CLI not found. Please run migrations manually:"
  warn ""
  warn "1. Go to: ${SUPABASE_URL//.supabase.co*/}/project/*/sql"
  warn "2. Run: supabase/migrations/001_initial_schema.sql"
  warn "3. Run: supabase/migrations/002_rls_policies.sql"
  warn "4. Run: supabase/migrations/003_telegram_schema.sql"
  warn "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  read -r -p "Press ENTER after running migrations to continue, or Ctrl+C to abort..." _
fi

# ── 7. Pull images and start services
log "Pulling Docker images (this may take a few minutes on first run)..."
docker compose pull

log "Starting services..."
docker compose up -d

# ── 8. Wait for n8n health
log "Waiting for n8n to start..."
N8N_PORT="${N8N_PORT:-5678}"
N8N_URL="http://localhost:${N8N_PORT}"
AUTH="${N8N_BASIC_AUTH_USER:-admin}:${N8N_BASIC_AUTH_PASSWORD}"
MAX_WAIT=90
WAITED=0

until curl -s --fail -u "$AUTH" "${N8N_URL}/healthz" >/dev/null 2>&1; do
  if [ $WAITED -ge $MAX_WAIT ]; then
    err "n8n did not start within ${MAX_WAIT}s. Check logs: docker compose logs n8n"
  fi
  printf "."
  sleep 3
  WAITED=$((WAITED + 3))
done
echo ""
log "n8n is healthy."

# ── 9. Import n8n workflows
log "Importing n8n workflows..."
WORKFLOW_DIR="./n8n/workflows"
IMPORTED=0
FAILED=0

for WORKFLOW_FILE in "$WORKFLOW_DIR"/*.json; do
  WORKFLOW_NAME=$(basename "$WORKFLOW_FILE" .json)

  HTTP_RESPONSE=$(curl -s -w "\n%{http_code}" \
    -u "$AUTH" \
    -X POST \
    -H "Content-Type: application/json" \
    -d @"${WORKFLOW_FILE}" \
    "${N8N_URL}/api/v1/workflows" 2>/dev/null)

  HTTP_CODE=$(echo "$HTTP_RESPONSE" | tail -1)
  BODY=$(echo "$HTTP_RESPONSE" | head -1)

  if [ "$HTTP_CODE" -eq 200 ] || [ "$HTTP_CODE" -eq 201 ]; then
    log "  ✓ Imported: ${WORKFLOW_NAME}"
    IMPORTED=$((IMPORTED + 1))

    # Extract workflow ID and activate it
    if $JQ_AVAILABLE; then
      WF_ID=$(echo "$BODY" | jq -r '.id // empty')
      if [ -n "$WF_ID" ]; then
        curl -s -u "$AUTH" \
          -X PATCH \
          -H "Content-Type: application/json" \
          -d '{"active": true}' \
          "${N8N_URL}/api/v1/workflows/${WF_ID}" >/dev/null 2>&1
      fi
    fi
  else
    warn "  ✗ Failed to import ${WORKFLOW_NAME} (HTTP ${HTTP_CODE})"
    FAILED=$((FAILED + 1))
  fi
done

log "Workflows imported: ${IMPORTED}, failed: ${FAILED}."

# ── 9b. Register Telegram webhook
if [ -n "${TELEGRAM_BOT_TOKEN:-}" ] && [[ "${TELEGRAM_BOT_TOKEN}" != *"CHANGE_ME"* ]] && [[ "${TELEGRAM_BOT_TOKEN}" != "1234567890:"* ]]; then
  log "Registering Telegram webhook..."
  TG_WEBHOOK_URL="${N8N_WEBHOOK_URL%/}/webhook/telegram"
  TG_REGISTER_RESP=$(curl -s -X POST \
    "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/setWebhook" \
    -H "Content-Type: application/json" \
    -d "{\"url\": \"${TG_WEBHOOK_URL}\", \"allowed_updates\": [\"message\", \"callback_query\"], \"drop_pending_updates\": true}" 2>/dev/null)

  if echo "$TG_REGISTER_RESP" | grep -q '"ok":true'; then
    log "Telegram webhook registered: ${TG_WEBHOOK_URL}"
  else
    warn "Telegram webhook registration failed: ${TG_REGISTER_RESP}"
    warn "Register manually: https://api.telegram.org/bot\${TELEGRAM_BOT_TOKEN}/setWebhook?url=${TG_WEBHOOK_URL}"
  fi
else
  info "Skipping Telegram webhook registration (TELEGRAM_BOT_TOKEN not configured)."
  info "Set TELEGRAM_BOT_TOKEN in .env and re-run setup.sh to enable Telegram."
fi

# ── 10. Wait for OpenHands
log "Waiting for OpenHands to start..."
OPENHANDS_PORT="${OPENHANDS_PORT:-3000}"
OPENHANDS_URL="http://localhost:${OPENHANDS_PORT}"
MAX_WAIT=120
WAITED=0

until curl -s --fail "${OPENHANDS_URL}/api/options/models" >/dev/null 2>&1 || \
      curl -s --fail "${OPENHANDS_URL}" >/dev/null 2>&1; do
  if [ $WAITED -ge $MAX_WAIT ]; then
    warn "OpenHands did not respond within ${MAX_WAIT}s — it may still be pulling the image."
    warn "Check: docker compose logs openhands"
    break
  fi
  printf "."
  sleep 3
  WAITED=$((WAITED + 3))
done
echo ""

# ── 11. Print summary
echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ✓  Autonomous Software Factory is Ready!              ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "  n8n Dashboard:   ${N8N_URL}"
echo "  OpenHands UI:    ${OPENHANDS_URL}"
echo ""
echo -e "${BLUE}  To build your first app, run:${NC}"
echo ""
echo "  curl -X POST ${N8N_URL}/webhook/intake \\"
echo "    -H 'Content-Type: application/json' \\"
echo "    -d '{\"idea\": \"A todo app with real-time collaboration and user auth\"}'"
echo ""
echo -e "${YELLOW}  Next steps:${NC}"
echo "  1. Run Supabase migration 003_telegram_schema.sql if not done yet"
echo "  2. Open the n8n dashboard and configure credentials for:"
echo "     • GitHub, Supabase, Vercel, Gemini, OpenHands"
echo "  3. Submit your first app idea — via Telegram or curl"
echo ""
if [ -n "${TELEGRAM_BOT_TOKEN:-}" ] && [[ "${TELEGRAM_BOT_TOKEN}" != *"CHANGE_ME"* ]] && [[ "${TELEGRAM_BOT_TOKEN}" != "1234567890:"* ]]; then
  echo -e "${GREEN}  Telegram Bot is configured!${NC}"
  echo "  • Message your bot and type /start to begin"
  echo "  • Use /nuevo to create your first project from Telegram"
  echo ""
else
  echo -e "${YELLOW}  Telegram not configured — set TELEGRAM_BOT_TOKEN in .env${NC}"
  echo "  • Create a bot at https://t.me/BotFather"
  echo "  • Get your chat ID from @userinfobot on Telegram"
  echo ""
fi
echo "  View logs:       docker compose logs -f"
echo "  Stop services:   docker compose down"
echo ""
