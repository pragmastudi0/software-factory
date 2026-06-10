-- ═══════════════════════════════════════════════════════════════════
--  002_rls_policies.sql
--  Row Level Security — Autonomous Software Factory
--
--  Access model:
--  - Factory backend uses SERVICE ROLE KEY → bypasses all RLS
--  - Generated apps use ANON KEY → subject to RLS below
--  - Future factory dashboard uses AUTHENTICATED role
-- ═══════════════════════════════════════════════════════════════════

ALTER TABLE projects        ENABLE ROW LEVEL SECURITY;
ALTER TABLE requirements    ENABLE ROW LEVEL SECURITY;
ALTER TABLE tasks           ENABLE ROW LEVEL SECURITY;
ALTER TABLE agent_outputs   ENABLE ROW LEVEL SECURITY;
ALTER TABLE deployments     ENABLE ROW LEVEL SECURITY;
ALTER TABLE test_results    ENABLE ROW LEVEL SECURITY;
ALTER TABLE feedback        ENABLE ROW LEVEL SECURITY;
ALTER TABLE memory          ENABLE ROW LEVEL SECURITY;
ALTER TABLE error_patterns  ENABLE ROW LEVEL SECURITY;

-- ────────────────────────────────────────────────────────────────────
-- ANON policies — public-facing access for generated apps
-- ────────────────────────────────────────────────────────────────────

-- Generated app frontends can read their own project record (for status display)
CREATE POLICY "anon_read_live_projects"
  ON projects FOR SELECT
  TO anon
  USING (status = 'live');

-- Generated apps can submit user feedback via the feedback widget
CREATE POLICY "anon_insert_feedback"
  ON feedback FOR INSERT
  TO anon
  WITH CHECK (true);

-- Error patterns are non-sensitive — allow anon read for diagnostic displays
CREATE POLICY "anon_read_error_patterns"
  ON error_patterns FOR SELECT
  TO anon
  USING (true);

-- All other tables: deny anon access entirely
CREATE POLICY "deny_anon_requirements"
  ON requirements FOR ALL TO anon USING (false);

CREATE POLICY "deny_anon_tasks"
  ON tasks FOR ALL TO anon USING (false);

CREATE POLICY "deny_anon_agent_outputs"
  ON agent_outputs FOR ALL TO anon USING (false);

CREATE POLICY "deny_anon_deployments"
  ON deployments FOR ALL TO anon USING (false);

CREATE POLICY "deny_anon_test_results"
  ON test_results FOR ALL TO anon USING (false);

CREATE POLICY "deny_anon_memory"
  ON memory FOR ALL TO anon USING (false);

-- ────────────────────────────────────────────────────────────────────
-- AUTHENTICATED policies — factory dashboard (future use)
-- ────────────────────────────────────────────────────────────────────

CREATE POLICY "authenticated_full_access_projects"
  ON projects FOR ALL TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "authenticated_full_access_requirements"
  ON requirements FOR ALL TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "authenticated_full_access_tasks"
  ON tasks FOR ALL TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "authenticated_full_access_agent_outputs"
  ON agent_outputs FOR ALL TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "authenticated_full_access_deployments"
  ON deployments FOR ALL TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "authenticated_full_access_test_results"
  ON test_results FOR ALL TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "authenticated_full_access_feedback"
  ON feedback FOR ALL TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "authenticated_full_access_memory"
  ON memory FOR ALL TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "authenticated_full_access_error_patterns"
  ON error_patterns FOR ALL TO authenticated USING (true) WITH CHECK (true);
