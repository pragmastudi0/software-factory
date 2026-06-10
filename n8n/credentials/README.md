# n8n Credential Setup

After running `setup.sh`, open the n8n dashboard and configure the following credentials manually under **Settings → Credentials**.

> **Security note**: Never commit credential values to git. The `.env` file holds secrets for the Docker environment; these are separate credentials registered in n8n's encrypted credential store.

## Required Credentials

### 1. Gemini API (HTTP Header Auth)

- **Name**: `Gemini API`
- **Header Name**: `x-goog-api-key`
- **Header Value**: your `GEMINI_API_KEY`

### 2. GitHub

- **Name**: `GitHub Token`
- **Type**: GitHub API
- **Personal Access Token**: your `GITHUB_TOKEN`

### 3. Supabase (HTTP Header Auth)

Create two credentials:

**Supabase Service Role** (for factory writes):
- **Name**: `Supabase Service Role`
- **Header Name**: `apikey`
- **Header Value**: your `SUPABASE_SERVICE_ROLE_KEY`

**Supabase Anon** (for generated apps):
- **Name**: `Supabase Anon`
- **Header Name**: `apikey`
- **Header Value**: your `SUPABASE_ANON_KEY`

### 4. Vercel (HTTP Header Auth)

- **Name**: `Vercel Token`
- **Header Name**: `Authorization`
- **Header Value**: `Bearer <your VERCEL_TOKEN>`

### 5. OpenHands (HTTP Header Auth)

- **Name**: `OpenHands API`
- **Header Name**: `Authorization`
- **Header Value**: `Bearer <your OPENHANDS_API_KEY>`

### 6. OpenRouter (HTTP Header Auth)

- **Name**: `OpenRouter API`
- **Header Name**: `Authorization`
- **Header Value**: `Bearer <your OPENROUTER_API_KEY>`

---

## Using Credentials in Workflows

All n8n workflow HTTP Request nodes in this factory use environment variables
(`$env.SUPABASE_SERVICE_ROLE_KEY`, etc.) directly in node parameters rather than
n8n's credential objects. This keeps workflows portable and avoids credential ID
mismatches when importing.

The credentials registered above are available as fallbacks and for manual testing
in the n8n UI.
