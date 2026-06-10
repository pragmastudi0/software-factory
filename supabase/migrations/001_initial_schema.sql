-- ═══════════════════════════════════════════════════════════════════
--  001_initial_schema.sql
--  Autonomous Software Factory — Core Schema
--  Run this in Supabase Dashboard > SQL Editor
-- ═══════════════════════════════════════════════════════════════════

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ────────────────────────────────────────────────────────────────────
-- ENUM types
-- ────────────────────────────────────────────────────────────────────

CREATE TYPE project_status AS ENUM (
  'intake',
  'setup',
  'agent_pipeline',
  'code_generation',
  'validation',
  'deploying',
  'qa',
  'live',
  'improving',
  'failed',
  'archived'
);

CREATE TYPE task_status AS ENUM (
  'pending',
  'in_progress',
  'completed',
  'failed',
  'retrying'
);

CREATE TYPE agent_role AS ENUM (
  'product_manager',
  'architect',
  'ux_ui_designer',
  'backend_engineer',
  'frontend_engineer',
  'database_engineer',
  'qa_engineer',
  'devops_engineer',
  'security_auditor'
);

CREATE TYPE deployment_status AS ENUM (
  'pending',
  'building',
  'deployed',
  'failed',
  'cancelled'
);

CREATE TYPE test_result_status AS ENUM (
  'passed',
  'failed',
  'skipped',
  'error'
);

CREATE TYPE feedback_status AS ENUM (
  'new',
  'triaged',
  'in_progress',
  'resolved',
  'wont_fix'
);

-- ────────────────────────────────────────────────────────────────────
-- TABLE: projects
-- ────────────────────────────────────────────────────────────────────

CREATE TABLE projects (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name                  TEXT NOT NULL,
  slug                  TEXT UNIQUE NOT NULL,
  raw_idea              TEXT NOT NULL,
  status                project_status NOT NULL DEFAULT 'intake',
  github_repo_url       TEXT,
  github_repo_name      TEXT,
  vercel_project_id     TEXT,
  vercel_deployment_url TEXT,
  tech_stack            JSONB DEFAULT '{}',
  current_iteration     INTEGER NOT NULL DEFAULT 1,
  n8n_execution_id      TEXT,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_projects_status ON projects(status);
CREATE INDEX idx_projects_slug ON projects(slug);

-- ────────────────────────────────────────────────────────────────────
-- TABLE: requirements
-- ────────────────────────────────────────────────────────────────────

CREATE TABLE requirements (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id    UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  version       INTEGER NOT NULL DEFAULT 1,
  prd_content   TEXT NOT NULL,
  user_stories  JSONB DEFAULT '[]',
  objectives    JSONB DEFAULT '[]',
  risks         JSONB DEFAULT '[]',
  roadmap       JSONB DEFAULT '[]',
  tech_stack    JSONB DEFAULT '{}',
  is_current    BOOLEAN NOT NULL DEFAULT TRUE,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_requirements_project ON requirements(project_id, version);
CREATE UNIQUE INDEX idx_requirements_current ON requirements(project_id) WHERE is_current = TRUE;

-- ────────────────────────────────────────────────────────────────────
-- TABLE: tasks
-- ────────────────────────────────────────────────────────────────────

CREATE TABLE tasks (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id          UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  requirement_id      UUID REFERENCES requirements(id),
  parent_task_id      UUID REFERENCES tasks(id),
  assigned_agent      agent_role NOT NULL,
  title               TEXT NOT NULL,
  description         TEXT NOT NULL,
  context             JSONB DEFAULT '{}',
  github_issue_number INTEGER,
  github_branch       TEXT,
  status              task_status NOT NULL DEFAULT 'pending',
  priority            SMALLINT NOT NULL DEFAULT 5,
  retry_count         SMALLINT NOT NULL DEFAULT 0,
  max_retries         SMALLINT NOT NULL DEFAULT 3,
  started_at          TIMESTAMPTZ,
  completed_at        TIMESTAMPTZ,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_tasks_project ON tasks(project_id);
CREATE INDEX idx_tasks_status ON tasks(status);
CREATE INDEX idx_tasks_agent ON tasks(assigned_agent);

-- ────────────────────────────────────────────────────────────────────
-- TABLE: agent_outputs
-- ────────────────────────────────────────────────────────────────────

CREATE TABLE agent_outputs (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  task_id         UUID NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
  project_id      UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  agent_role      agent_role NOT NULL,
  iteration       INTEGER NOT NULL DEFAULT 1,
  raw_output      TEXT NOT NULL,
  structured_data JSONB DEFAULT '{}',
  token_count     INTEGER,
  model_used      TEXT,
  latency_ms      INTEGER,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_agent_outputs_task ON agent_outputs(task_id);
CREATE INDEX idx_agent_outputs_project ON agent_outputs(project_id);

-- ────────────────────────────────────────────────────────────────────
-- TABLE: deployments
-- ────────────────────────────────────────────────────────────────────

CREATE TABLE deployments (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id            UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  iteration             INTEGER NOT NULL DEFAULT 1,
  vercel_deployment_id  TEXT,
  deployment_url        TEXT,
  git_commit_sha        TEXT,
  git_branch            TEXT,
  status                deployment_status NOT NULL DEFAULT 'pending',
  build_log             TEXT,
  deploy_duration_ms    INTEGER,
  deployed_at           TIMESTAMPTZ,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_deployments_project ON deployments(project_id);
CREATE INDEX idx_deployments_status ON deployments(status);

-- ────────────────────────────────────────────────────────────────────
-- TABLE: test_results
-- ────────────────────────────────────────────────────────────────────

CREATE TABLE test_results (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id            UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  deployment_id         UUID REFERENCES deployments(id),
  iteration             INTEGER NOT NULL DEFAULT 1,
  test_suite            TEXT NOT NULL,
  test_name             TEXT NOT NULL,
  status                test_result_status NOT NULL,
  error_message         TEXT,
  stack_trace           TEXT,
  screenshot_url        TEXT,
  duration_ms           INTEGER,
  github_issue_number   INTEGER,
  auto_fix_attempted    BOOLEAN DEFAULT FALSE,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_test_results_project ON test_results(project_id);
CREATE INDEX idx_test_results_deployment ON test_results(deployment_id);
CREATE INDEX idx_test_results_status ON test_results(status);

-- ────────────────────────────────────────────────────────────────────
-- TABLE: feedback
-- ────────────────────────────────────────────────────────────────────

CREATE TABLE feedback (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id          UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  source              TEXT NOT NULL DEFAULT 'user',
  content             TEXT NOT NULL,
  sentiment           TEXT,
  priority            SMALLINT DEFAULT 5,
  status              feedback_status NOT NULL DEFAULT 'new',
  github_issue_number INTEGER,
  task_id             UUID REFERENCES tasks(id),
  metadata            JSONB DEFAULT '{}',
  created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_feedback_project ON feedback(project_id);
CREATE INDEX idx_feedback_status ON feedback(status);

-- ────────────────────────────────────────────────────────────────────
-- TABLE: memory
-- ────────────────────────────────────────────────────────────────────

CREATE TABLE memory (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id  UUID REFERENCES projects(id) ON DELETE CASCADE,
  memory_type TEXT NOT NULL,
  key         TEXT NOT NULL,
  value       TEXT NOT NULL,
  tags        TEXT[] DEFAULT '{}',
  importance  SMALLINT DEFAULT 5,
  expires_at  TIMESTAMPTZ,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_memory_project ON memory(project_id);
CREATE INDEX idx_memory_type_key ON memory(memory_type, key);
CREATE INDEX idx_memory_tags ON memory USING GIN(tags);

-- ────────────────────────────────────────────────────────────────────
-- TABLE: error_patterns
-- ────────────────────────────────────────────────────────────────────

CREATE TABLE error_patterns (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  category      TEXT NOT NULL,
  pattern       TEXT NOT NULL,
  error_summary TEXT NOT NULL,
  solution      TEXT NOT NULL,
  fix_prompt    TEXT,
  success_count INTEGER NOT NULL DEFAULT 0,
  failure_count INTEGER NOT NULL DEFAULT 0,
  last_used_at  TIMESTAMPTZ,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_error_patterns_category ON error_patterns(category);

-- Seed common error patterns
INSERT INTO error_patterns (category, pattern, error_summary, solution, fix_prompt) VALUES
(
  'build',
  'Cannot find module',
  'Missing npm dependency',
  'Add the missing package to package.json dependencies and run npm install',
  'The build failed because a module could not be found. Identify the missing package, add it to package.json, run npm install, and fix all import paths.'
),
(
  'typecheck',
  'Type .* is not assignable to type',
  'TypeScript type mismatch',
  'Fix the type annotation to match the actual value type, or add proper generics',
  'Fix the TypeScript type error. Do not use "any" unless absolutely necessary. Prefer proper typing with interfaces or type aliases.'
),
(
  'lint',
  'no-unused-vars',
  'Unused variable declared in code',
  'Remove the unused variable or prefix with underscore if intentionally unused',
  'Remove the unused variable. If it is a function parameter that must stay, prefix it with an underscore.'
),
(
  'deploy',
  'Build failed with exit code',
  'Vercel build failure — check build log for root cause',
  'Analyze the Vercel build log, identify the failing command, fix the root cause',
  'The Vercel deployment failed during build. Analyze the build log carefully, identify the first error, fix the root cause in the source code, and ensure npm run build passes locally before re-deploying.'
),
(
  'typecheck',
  'Property .* does not exist on type',
  'Accessing undefined property on a TypeScript type',
  'Add the missing property to the interface or use optional chaining',
  'The TypeScript compiler cannot find this property on the type. Either add it to the interface definition, or use optional chaining (?.) if it may not exist.'
),
(
  'build',
  'SyntaxError',
  'JavaScript/TypeScript syntax error',
  'Fix the syntax error at the indicated file and line number',
  'There is a syntax error in the code. Find the file and line number indicated in the error message and fix the syntax.'
);

-- ────────────────────────────────────────────────────────────────────
-- updated_at triggers
-- ────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_projects_updated_at
  BEFORE UPDATE ON projects FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trg_tasks_updated_at
  BEFORE UPDATE ON tasks FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trg_deployments_updated_at
  BEFORE UPDATE ON deployments FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trg_feedback_updated_at
  BEFORE UPDATE ON feedback FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trg_memory_updated_at
  BEFORE UPDATE ON memory FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trg_error_patterns_updated_at
  BEFORE UPDATE ON error_patterns FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
