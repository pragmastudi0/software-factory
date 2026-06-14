# 🏭 Autonomous Software Factory

> Transforma una idea en texto natural en una aplicación web desplegada, testeada y en producción — sin intervención humana. Controlada completamente desde Telegram.

---

## ¿Qué es esto?

Una plataforma de IA que corre **100% en tu computadora** con Docker. Orquesta 9 agentes especializados, genera código real, lo valida, despliega en Vercel y mejora continuamente basándose en feedback — todo de forma autónoma.

Tú escribes una idea en Telegram. La fábrica entrega una app.

```
Tú:    "Un CRM para inmobiliarias con gestión de propiedades y clientes"
       ↓
Fábrica: PRD → Arquitectura → Código → Deploy → QA → Live ✅
```

---

## Arquitectura

```
Tu computadora
┌─────────────────────────────────────────────────────────┐
│  Docker Compose                                          │
│                                                          │
│  ┌──────────────┐   ┌──────────────┐   ┌─────────────┐  │
│  │     n8n      │   │  OpenHands   │   │  Postgres   │  │
│  │  :5678       │──▶│  :3000       │   │  (interno)  │  │
│  │ (orquestador)│   │ (code agent) │   └─────────────┘  │
│  └──────┬───────┘   └──────────────┘                    │
└─────────┼───────────────────────────────────────────────┘
          │  (túnel público: ngrok / Cloudflare Tunnel)
          │
          ▼
     Telegram Bot ←── tú, desde tu teléfono
          │
          ▼
   ┌──────┴───────┐
   │  APIs externas│
   │  • Gemini     │
   │  • GitHub     │
   │  • Supabase   │
   │  • Vercel     │
   └───────────────┘
```

**Stack de cada app generada:** React 18 + Vite + TypeScript + Tailwind CSS + Supabase + Vercel + Playwright E2E

---

## Requisitos

### Software (en tu computadora)

| Herramienta | Versión mínima | Cómo instalar |
|-------------|----------------|---------------|
| Docker Desktop | 24+ | [docs.docker.com](https://docs.docker.com/get-docker/) |
| Docker Compose v2 | incluido en Docker Desktop | — |
| RAM libre | 4 GB | 8 GB recomendado |

### Cuentas necesarias (todas con plan gratuito)

| Servicio | Para qué |
|----------|----------|
| [Google AI Studio](https://aistudio.google.com) | LLM principal (Gemini 2.0 Flash) |
| [GitHub](https://github.com) | Repositorios del código generado |
| [Supabase](https://supabase.com) | Base de datos y memoria de la fábrica |
| [Vercel](https://vercel.com) | Hosting de las apps generadas |
| [OpenRouter](https://openrouter.ai) | LLM de respaldo cuando Gemini falla |
| Telegram | Interfaz de control (gratis) |

---

## Instalación paso a paso

### Paso 1 — Clonar el repositorio

```bash
git clone https://github.com/pragmastudi0/software-factory
cd software-factory
```

---

### Paso 2 — Crear el bot de Telegram

1. Abre Telegram en tu teléfono o escritorio
2. Busca y escribe a **[@BotFather](https://t.me/BotFather)**
3. Envía `/newbot` y sigue las instrucciones (elige nombre y username)
4. Copia el **token** que te da (formato: `1234567890:AAxxxxxxxx...`)
5. Para obtener tu **chat ID**: escribe a **[@userinfobot](https://t.me/userinfobot)** y copia el número que te responde

---

### Paso 3 — Exponer n8n a internet (túnel)

Telegram necesita enviar webhooks a una URL HTTPS pública. Como n8n corre en `localhost:5678`, debes crear un túnel. Tienes dos opciones:

#### Opción A — ngrok (más fácil, URL cambia al reiniciar)

```bash
# 1. Instalar ngrok
# macOS:
brew install ngrok

# Windows (PowerShell como administrador):
winget install ngrok

# Linux:
curl -sSL https://ngrok-agent.s3.amazonaws.com/ngrok.asc | sudo tee /etc/apt/trusted.gpg.d/ngrok.asc > /dev/null
echo "deb https://ngrok-agent.s3.amazonaws.com buster main" | sudo tee /etc/apt/sources.list.d/ngrok.list
sudo apt update && sudo apt install ngrok

# 2. Crear cuenta gratuita en https://ngrok.com y copiar tu authtoken
ngrok config add-authtoken TU_TOKEN_DE_NGROK

# 3. Iniciar el túnel (ejecutar en una terminal aparte, dejar corriendo)
ngrok http 5678
```

ngrok te mostrará algo como:
```
Forwarding  https://abc123.ngrok-free.app -> http://localhost:5678
```

Copia esa URL (`https://abc123.ngrok-free.app`) — la necesitas en el siguiente paso.

> ⚠️ Con ngrok gratuito la URL **cambia cada vez** que reinicias el túnel. Cuando esto pase, actualiza `N8N_WEBHOOK_URL` en `.env` y vuelve a ejecutar `bash scripts/setup.sh` para re-registrar el webhook de Telegram.

#### Opción B — Cloudflare Tunnel (recomendado, URL permanente gratis)

```bash
# 1. Instalar cloudflared
# macOS:
brew install cloudflare/cloudflare/cloudflared

# Windows: descargar desde https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/

# Linux:
wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
sudo dpkg -i cloudflared-linux-amd64.deb

# 2. Iniciar sesión (abre el navegador)
cloudflared tunnel login

# 3. Crear un túnel permanente
cloudflared tunnel create software-factory

# 4. Iniciar el túnel apuntando a n8n
cloudflared tunnel --url http://localhost:5678 run software-factory
```

Cloudflare te asignará una URL como `https://software-factory.tudominio.com`. Esta URL **no cambia** aunque reinicies.

---

### Paso 4 — Configurar variables de entorno

```bash
cp .env.example .env
```

Edita `.env` con tu editor favorito y completa estos valores:

```env
# ── Gemini (LLM principal) ─────────────────────────────────
# Obtener en: https://aistudio.google.com/app/apikey
GEMINI_API_KEY=AIzaSy...
GEMINI_MODEL=gemini-2.0-flash-exp
GEMINI_PRO_MODEL=gemini-1.5-pro-latest

# ── OpenRouter (fallback cuando Gemini falla) ──────────────
# Obtener en: https://openrouter.ai → API Keys
OPENROUTER_API_KEY=sk-or-v1-...

# ── GitHub ─────────────────────────────────────────────────
# Crear en: https://github.com/settings/tokens
# Permisos necesarios: repo, issues, workflows
GITHUB_TOKEN=ghp_...
GITHUB_ORG=tu-usuario-o-organizacion

# ── Supabase ───────────────────────────────────────────────
# Obtener en: https://app.supabase.com → tu proyecto → Settings → API
SUPABASE_URL=https://xxxxxxxxxxxxxx.supabase.co
SUPABASE_SERVICE_ROLE_KEY=eyJhbGc...   # service_role (secreto, no exponer)
SUPABASE_ANON_KEY=eyJhbGc...           # anon (público)

# ── Vercel ─────────────────────────────────────────────────
# Crear en: https://vercel.com/account/tokens
VERCEL_TOKEN=...
VERCEL_TEAM_ID=team_...    # si usas un equipo, sino dejar vacío
VERCEL_ORG_ID=...

# ── n8n (base de datos interna) ────────────────────────────
N8N_DB_POSTGRESDB_PASSWORD=elige_un_password_seguro
N8N_BASIC_AUTH_USER=admin
N8N_BASIC_AUTH_PASSWORD=elige_otro_password_seguro
N8N_ENCRYPTION_KEY=CHANGE_ME_32_CHAR_RANDOM_STRING_HERE  # setup.sh lo genera solo

# ── URL pública de n8n (tu túnel del Paso 3) ───────────────
# ¡IMPORTANTE! Debe terminar con /
N8N_WEBHOOK_URL=https://abc123.ngrok-free.app/

# ── Telegram ───────────────────────────────────────────────
TELEGRAM_BOT_TOKEN=1234567890:AAxxxxxxxxxxxxxxxx
TELEGRAM_ALLOWED_USERS=123456789          # tu chat ID (de @userinfobot)
TELEGRAM_ADMIN_CHAT_ID=123456789          # mismo ID para notificaciones
```

---

### Paso 5 — Ejecutar migraciones en Supabase

Ve al **SQL Editor** de tu proyecto en [app.supabase.com](https://app.supabase.com) y ejecuta los siguientes archivos **en orden**:

1. Copia y pega el contenido de `supabase/migrations/001_initial_schema.sql` → Ejecutar
2. Copia y pega el contenido de `supabase/migrations/002_rls_policies.sql` → Ejecutar
3. Copia y pega el contenido de `supabase/migrations/003_telegram_schema.sql` → Ejecutar

---

### Paso 6 — Iniciar la fábrica

Asegúrate de que el túnel (ngrok o Cloudflare) esté corriendo, luego:

```bash
bash scripts/setup.sh
```

El script hace todo automáticamente:

```
✅ Verifica Docker y dependencias
✅ Valida variables de entorno
✅ Inicia n8n + OpenHands + Postgres (Docker Compose)
✅ Espera que n8n esté healthy
✅ Importa y activa los 12 workflows
✅ Registra el webhook de Telegram con tu URL pública
✅ Verifica OpenHands
✅ Muestra resumen final
```

---

### Paso 7 — Verificar que todo funciona

```bash
# Ver que los 3 contenedores están corriendo
docker compose ps

# Abrir el dashboard de n8n en el navegador
open http://localhost:5678   # macOS
# o navegar manualmente a http://localhost:5678
```

En n8n deberías ver **12 workflows** activos (verde).

Ahora escribe a tu bot en Telegram:

```
/start
```

Si el bot responde con el mensaje de bienvenida, ¡todo está funcionando! 🎉

---

## Uso diario

### Comandos del bot

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

### Crear tu primer proyecto

```
Tú:    /nuevo
Bot:   💡 Nuevo Proyecto
       Describe tu idea de aplicación en detalle...

Tú:    Un sistema de gestión de inventario para restaurantes
       con control de stock, alertas automáticas cuando hay
       poco stock y reportes de consumo en tiempo real

Bot:   ⏳ Creando tu proyecto...
       Recibirás actualizaciones aquí.

       [~5 minutos después]

Bot:   🚀 Proyecto Creado!
       📋 Idea: Un sistema de gestión de inventario...
       🔘 Estado: intake → setup
       El pipeline de 9 agentes iniciará en breve.

       [~15-20 minutos después]

Bot:   💻 Código Generado!
       OpenHands completó la generación. Iniciando validación...

       [~5 minutos después]

Bot:   ✅ Validación Exitosa!
       lint + typecheck + build pasaron. Iniciando deployment...

       [~3 minutos después]

Bot:   🚀 Deploy Exitoso!
       🌐 URL: https://mi-app-abc123.vercel.app
       Iniciando suite de pruebas QA con Playwright...

       [~10 minutos después]

Bot:   🎉 ¡Proyecto en producción!
       ✅ Todos los tests pasaron
       🌐 Tu aplicación está LIVE
```

### Botones de aprobación

Para decisiones importantes, el bot muestra botones interactivos:

```
🚀 Deploy a Producción

📦 Proyecto: Inventario Restaurantes
🔘 Estado actual: validation

¿Confirmas el despliegue a Vercel?

[✅ APROBAR]  [❌ RECHAZAR]  [⏸ POSPONER]
```

Los botones expiran en **24 horas**.

### Solicitar mejoras

Después de que tu app esté live, puedes pedir mejoras:

```
Tú:    /mejorar
Bot:   🔄 Solicitar Mejora — Describe la mejora...

Tú:    Agregar exportación a Excel de los reportes de consumo

Bot:   🔄 Solicitud recibida
       Analizando la mejora con IA. En breve recibirás
       una historia de usuario y estimación de impacto.
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

**Los 9 agentes de IA** (producen JSON estructurado con Gemini):

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

## Servicios locales

| Servicio | URL | Propósito |
|----------|-----|-----------|
| n8n Dashboard | http://localhost:5678 | Ver workflows ejecutar en tiempo real |
| OpenHands UI | http://localhost:3000 | Ver al agente de IA escribir código |
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
| `error_patterns` | Biblioteca de auto-corrección (pre-cargada) |
| `telegram_conversations` | Estado de conversación por usuario |
| `telegram_approvals` | Solicitudes de aprobación (expiran en 24h) |
| `telegram_notification_log` | Auditoría de mensajes enviados |

---

## Solución de problemas

### El bot de Telegram no responde

```bash
# 1. Verificar que el túnel está corriendo
# (la ventana de ngrok o cloudflared debe estar abierta)

# 2. Verificar que el webhook está registrado correctamente
curl https://api.telegram.org/bot{TU_TOKEN}/getWebhookInfo
# Debe mostrar tu URL de ngrok/Cloudflare en el campo "url"

# 3. Si el webhook es incorrecto, re-registrarlo manualmente
curl -X POST https://api.telegram.org/bot{TU_TOKEN}/setWebhook \
  -d "url=https://TU-URL-DEL-TUNEL/webhook/telegram"

# 4. Revisar logs de n8n
docker compose logs n8n | grep -i telegram
```

**Causas comunes:**
- El túnel (ngrok/Cloudflare) no está corriendo → inícialo primero
- `N8N_WEBHOOK_URL` en `.env` apunta a `localhost` → debe ser la URL del túnel
- La URL de ngrok cambió al reiniciar → actualiza `.env` y re-ejecuta `setup.sh`
- `TELEGRAM_ALLOWED_USERS` no tiene tu chat ID → verificar con @userinfobot

### ngrok muestra "Too many connections" o errores

Con el plan gratuito de ngrok solo puedes tener **1 túnel activo** y hay límite de conexiones. Considera usar Cloudflare Tunnel (gratuito y sin límites) o actualizar ngrok.

### Los workflows no se importan en n8n

```bash
# Verificar que todos los JSON son válidos
for f in n8n/workflows/*.json; do
  python3 -m json.tool "$f" > /dev/null && echo "OK: $f" || echo "ERROR: $f"
done

# Ver logs detallados de n8n
docker compose logs n8n
```

### OpenHands no completa las tareas

```bash
docker compose logs openhands
```

**Causas comunes:**
- Cuota de Gemini agotada → configurar `OPENROUTER_API_KEY` como fallback
- Docker socket no montado → verificar `privileged: true` en `docker-compose.yml`
- Poca RAM → OpenHands necesita al menos 2 GB libres; cerrar otras apps

### El deploy en Vercel falla

1. Verificar que `VERCEL_TOKEN` tiene permisos correctos
2. Revisar la tabla `deployments` en Supabase → campo `build_log`
3. Causa más común: faltan `VITE_SUPABASE_URL` y `VITE_SUPABASE_ANON_KEY` en las variables de entorno del proyecto en Vercel

### Comandos útiles

```bash
# Ver todos los logs en tiempo real
docker compose logs -f

# Ver logs solo de n8n
docker compose logs -f n8n

# Ver estado de contenedores
docker compose ps

# Reiniciar un servicio
docker compose restart n8n

# Detener todo (sin borrar datos)
docker compose down

# Detener y borrar volúmenes (⚠️ borra todos los datos de n8n)
docker compose down -v

# Actualizar imágenes Docker
docker compose pull && docker compose up -d
```

---

## Actualizar la URL del túnel (ngrok)

Si reinicias ngrok y la URL cambia, sigue estos pasos:

```bash
# 1. Copia la nueva URL de ngrok (ej: https://xyz789.ngrok-free.app)

# 2. Actualiza N8N_WEBHOOK_URL en .env
# Cambia la línea:
# N8N_WEBHOOK_URL=https://abc123.ngrok-free.app/
# Por:
# N8N_WEBHOOK_URL=https://xyz789.ngrok-free.app/

# 3. Re-ejecutar setup.sh para actualizar el webhook de Telegram
bash scripts/setup.sh
```

---

## Variables de entorno completas

Ver [`.env.example`](.env.example) para la lista completa con descripciones de cada variable.

---

## Licencia

MIT — úsalo, modifícalo, despliégalo como quieras.
