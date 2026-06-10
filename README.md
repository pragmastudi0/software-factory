# 🏭 Autonomous Software Factory

> Transforma una idea en texto natural en una aplicación web desplegada, testeada y en producción — sin intervención humana. Controlada completamente desde Telegram.

---

## ¿Qué es esto?

Una plataforma de IA que orquesta 9 agentes especializados, genera código real, lo valida, despliega en Vercel y mejora continuamente basándose en feedback — todo de forma autónoma.

Tú escribes una idea. La fábrica entrega una app.

```
Tú:    "Un CRM para inmobiliarias con gestión de propiedades y clientes"
       ↓
Fábrica: PRD → Arquitectura → Código → Deploy → QA → Live ✅
```

---

## Arquitectura

```
Telegram Bot  ←→  n8n (orquestador)
                       │
          ┌────────────┼────────────┐
          ▼            ▼            ▼
      Gemini API   OpenHands    Supabase
      (LLM/IA)   (Code Agent)  (DB/Memoria)
          │            │            │
          └────────────┼────────────┘
                       ▼
                   GitHub → Vercel → App Live
```

**Stack de cada app generada:** React 18 + Vite + TypeScript + Tailwind CSS + Supabase + Vercel + Playwright E2E

---

## Requisitos

| Herramienta | Versión mínima | Notas |
|-------------|----------------|-------|
| Docker | 24+ | Con Docker Compose v2 |
| RAM | 4 GB | 8 GB recomendado |
| VPS / Servidor | Siempre encendido | Para recibir webhooks de Telegram |

**Cuentas necesarias:**

| Servicio | Costo | Para qué |
|----------|-------|----------|
| [Google AI Studio](https://aistudio.google.com) | Gratis | LLM principal (Gemini 2.0 Flash) |
| [GitHub](https://github.com) | Gratis | Repositorios de código |
| [Supabase](https://supabase.com) | Gratis | Base de datos y memoria |
| [Vercel](https://vercel.com) | Gratis | Deploy de apps |
| [OpenRouter](https://openrouter.ai) | Gratis | LLM de respaldo |
| Telegram | Gratis | Interfaz de control |

---

## Instalación

### 1. Clonar el repositorio

```bash
git clone https://github.com/pragmastudi0/software-factory
cd software-factory
```

### 2. Crear el bot de Telegram

1. Abre Telegram y escribe a [@BotFather](https://t.me/BotFather)
2. Ejecuta `/newbot` y sigue las instrucciones
3. Copia el token (formato: `1234567890:AAxxxxxxxx...`)
4. Obtén tu chat ID escribiendo a [@userinfobot](https://t.me/userinfobot)

### 3. Configurar variables de entorno

```bash
cp .env.example .env
nano .env   # o el editor de tu preferencia
```

Variables **obligatorias**:

```env
# ── Gemini (LLM principal)
GEMINI_API_KEY=AIzaSy...           # https://aistudio.google.com/app/apikey

# ── GitHub
GITHUB_TOKEN=ghp_...               # https://github.com/settings/tokens
GITHUB_ORG=tu-org-o-usuario

# ── Supabase
SUPABASE_URL=https://xxxxxx.supabase.co
SUPABASE_SERVICE_ROLE_KEY=eyJh...
SUPABASE_ANON_KEY=eyJh...

# ── Vercel
VERCEL_TOKEN=...                   # https://vercel.com/account/tokens

# ── n8n
N8N_DB_POSTGRESDB_PASSWORD=password_seguro
N8N_BASIC_AUTH_PASSWORD=password_admin
N8N_WEBHOOK_URL=https://tu-dominio.com/   # URL pública donde n8n es accesible

# ── Telegram
TELEGRAM_BOT_TOKEN=1234567890:AAxxxxxxxx
TELEGRAM_ALLOWED_USERS=123456789          # Tu chat ID (separar por comas para varios)
TELEGRAM_ADMIN_CHAT_ID=123456789          # Chat ID que recibe notificaciones
```

### 4. Ejecutar migraciones en Supabase

Ve al [SQL Editor de Supabase](https://app.supabase.com) y ejecuta en orden:

```
supabase/migrations/001_initial_schema.sql
supabase/migrations/002_rls_policies.sql
supabase/migrations/003_telegram_schema.sql
```

### 5. Iniciar la fábrica

```bash
bash scripts/setup.sh
```

El script automáticamente:
- Verifica prerequisites
- Valida todas las variables de entorno
- Inicia n8n + OpenHands + Postgres con Docker Compose
- Importa y activa los 12 workflows
- Registra el webhook de Telegram

---

## Uso

### Desde Telegram (interfaz principal)

Escribe a tu bot y usa estos comandos:

| Comando | Descripción |
|---------|-------------|
| `/start` | Bienvenida y lista de proyectos activos |
| `/nuevo` | Crear un nuevo proyecto |
| `/estado` | Estado actual de un proyecto |
| `/roadmap` | Roadmap generado por IA |
| `/deploy` | Desplegar a producción (con botón de aprobación) |
| `/qa` | Ejecutar suite de pruebas Playwright |
| `/errores` | Ver errores pendientes de QA |
| `/mejorar` | Solicitar nueva funcionalidad |
| `/feedback` | Enviar feedback para el ciclo de mejora |
| `/costos` | Consumo de tokens y costo estimado |
| `/agentes` | Actividad reciente de los 9 agentes |

**Crear un proyecto:**

```
Tú:    /nuevo
Bot:   💡 Nuevo Proyecto — Describe tu idea...

Tú:    Un sistema de gestión de inventario para restaurantes
       con control de stock, alertas y reportes en tiempo real

Bot:   ⏳ Creando tu proyecto...
       [15 min después]
       🚀 Proyecto Creado! ¿Confirmas el despliegue?
       [✅ APROBAR] [❌ RECHAZAR] [⏸ POSPONER]
```

**Botones de aprobación:**

Para decisiones importantes (deploy, cambios estructurales, refactorizaciones), el bot muestra botones interactivos. Los botones expiran en 24 horas.

### Desde HTTP (alternativa)

```bash
# Crear proyecto
curl -X POST http://localhost:5678/webhook/intake \
  -H "Content-Type: application/json" \
  -d '{"idea": "Una app de gestión de tareas con tiempo real y autenticación"}'

# Enviar feedback
curl -X POST http://localhost:5678/webhook/feedback \
  -H "Content-Type: application/json" \
  -d '{
    "project_id": "uuid-del-proyecto",
    "content": "El botón de crear tarea es muy pequeño en móvil"
  }'
```

---

## El pipeline de 12 workflows

```
[00] Telegram Bot ──▶ [01] Idea Intake ──▶ [02] Project Setup
                                                    │
                                          [03] Multi-Agent Pipeline
                                          (9 agentes en paralelo)
                                                    │
                                          [04] Code Generation
                                          (OpenHands escribe código)
                                                    │
                                          [05] Validation Loop
                                          (lint + typecheck + build)
                                                    │
                                          [06] Deployment (Vercel)
                                                    │
                                          [07] QA Automation
                                          (Playwright E2E)
                                                    │
[10] Mejora Continua ◀── [09] Memory ◀── [08] Feedback Collection
(cron diario 02:00 UTC)
         │
         └──▶ [04] Code Generation (bucle infinito de mejora)

[11] Telegram Notifications  ←── llamado por todos los workflows
```

**Los 9 agentes de IA** (cada uno produce JSON estructurado):

| Agente | Produce |
|--------|---------|
| Product Manager | PRD, user stories, roadmap |
| Architect | Estructura de directorios, contratos API, schema DB |
| UX/UI Designer | Design system, layouts, flujos de usuario |
| Backend Engineer | Edge Functions en TypeScript, auth flows |
| Frontend Engineer | Componentes React, páginas, hooks, configs |
| Database Engineer | Migraciones SQL, políticas RLS, índices |
| QA Engineer | Suite Playwright (5 archivos de tests) |
| DevOps Engineer | vercel.json, GitHub Actions CI |
| Security Auditor | OWASP Top 10, checklist de seguridad Supabase |

---

## Servicios

| Servicio | URL | Propósito |
|----------|-----|-----------|
| n8n Dashboard | http://localhost:5678 | Orquestación — ver workflows ejecutar |
| OpenHands UI | http://localhost:3000 | Ver al agente escribir código |
| Supabase | https://app.supabase.com | Base de datos y memoria |
| Vercel | https://vercel.com/dashboard | Apps desplegadas |

---

## Base de datos (Supabase)

| Tabla | Propósito |
|-------|-----------|
| `projects` | Registro maestro con seguimiento de estado |
| `requirements` | Versiones del PRD |
| `tasks` | Asignaciones por agente |
| `agent_outputs` | Respuestas LLM con conteo de tokens |
| `deployments` | Historial de deploys en Vercel |
| `test_results` | Resultados de Playwright por deploy |
| `feedback` | Feedback con análisis de sentimiento |
| `memory` | Contexto entre sesiones (clave/valor) |
| `error_patterns` | Biblioteca de auto-corrección |
| `telegram_conversations` | Estado de conversación por usuario |
| `telegram_approvals` | Solicitudes de aprobación con expiración |
| `telegram_notification_log` | Auditoría de mensajes enviados |

---

## Solución de problemas

### El bot de Telegram no responde

```bash
# Verificar que el webhook está registrado
curl https://api.telegram.org/bot{TU_TOKEN}/getWebhookInfo

# Re-registrar el webhook manualmente
curl -X POST https://api.telegram.org/bot{TU_TOKEN}/setWebhook \
  -d "url=https://tu-dominio.com/webhook/telegram"

# Revisar logs de n8n
docker compose logs n8n | grep -i telegram
```

Causas comunes:
- `N8N_WEBHOOK_URL` apunta a `localhost` → debe ser una URL pública accesible desde internet
- `TELEGRAM_ALLOWED_USERS` no contiene tu chat ID → verificar con @userinfobot

### Los workflows no se importan

```bash
# Verificar que el JSON es válido
cat n8n/workflows/*.json | python3 -m json.tool > /dev/null && echo "OK"

# Ver logs de n8n
docker compose logs n8n
```

### OpenHands no termina las tareas

```bash
docker compose logs openhands
```

Causas comunes:
- Quota de Gemini agotada → verificar que `OPENROUTER_API_KEY` está configurado como fallback
- Docker socket no montado → verificar `privileged: true` en `docker-compose.yml`

### El deploy en Vercel falla

1. Verificar que `VERCEL_TOKEN` tiene permisos correctos
2. Revisar la tabla `deployments` en Supabase para ver el `build_log`
3. Causa más común: faltan `VITE_SUPABASE_URL` y `VITE_SUPABASE_ANON_KEY` como variables de entorno en el proyecto de Vercel

### Comandos útiles

```bash
# Ver todos los logs
docker compose logs -f

# Reiniciar un servicio
docker compose restart n8n

# Ver estado de contenedores
docker compose ps

# Detener todo
docker compose down

# Detener y eliminar volúmenes (⚠️ borra datos de n8n)
docker compose down -v
```

---

## Variables de entorno completas

Ver [`.env.example`](.env.example) para la lista completa con descripciones.

---

## Licencia

MIT — úsalo, modifícalo, despliégalo como quieras.
