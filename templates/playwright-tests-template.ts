/**
 * Playwright Test Template
 *
 * This file is provided to the QA Agent as a reference pattern for generating
 * complete Playwright test suites. The QA Agent reads this template and produces
 * project-specific tests following these patterns.
 *
 * Key patterns demonstrated:
 * - Auth helper functions (signUp, signIn)
 * - Test data isolation (unique email per test run)
 * - Role-based selectors (getByRole, getByLabel)
 * - Async assertions with timeouts
 * - Performance testing via Navigation Timing API
 * - Console error monitoring
 */

import { test, expect, type Page } from '@playwright/test'

// ── Test data factory — unique per test run to avoid conflicts
const testUser = {
  email: `test-${Date.now()}@example.com`,
  password: 'TestPass123!',
  name: 'Test User',
}

// ── Auth helpers — reuse across suites
async function signUp(page: Page, email: string, password: string, name?: string) {
  await page.goto('/signup')
  if (name) {
    const nameField = page.getByLabel(/name/i)
    if (await nameField.isVisible()) await nameField.fill(name)
  }
  await page.getByLabel(/email/i).fill(email)
  await page.getByLabel(/password/i).first().fill(password)
  await page.getByRole('button', { name: /sign up|create account|register/i }).click()
  await expect(page).not.toHaveURL('/signup', { timeout: 15000 })
}

async function signIn(page: Page, email: string, password: string) {
  await page.goto('/login')
  await page.getByLabel(/email/i).fill(email)
  await page.getByLabel(/password/i).fill(password)
  await page.getByRole('button', { name: /log in|sign in/i }).click()
  await page.waitForURL(/dashboard|home|app|\/(?!login|signup)/, { timeout: 15000 })
}

// ─────────────────────────────────────────────────────────────────────────────
// Navigation Suite
// ─────────────────────────────────────────────────────────────────────────────

test.describe('Navigation', () => {
  test('homepage loads with correct title', async ({ page }) => {
    await page.goto('/')
    await expect(page).toHaveTitle(/.+/) // Must have any title
    await expect(page.getByRole('main')).toBeVisible()
  })

  test('all navigation links are accessible and have href', async ({ page }) => {
    await page.goto('/')
    const nav = page.getByRole('navigation').first()
    await expect(nav).toBeVisible()
    const links = nav.getByRole('link')
    const count = await links.count()
    expect(count).toBeGreaterThan(0)
    for (let i = 0; i < count; i++) {
      const href = await links.nth(i).getAttribute('href')
      expect(href).toBeTruthy()
      expect(href).not.toBe('#') // Avoid dead links
    }
  })

  test('404 page shown for unknown routes', async ({ page }) => {
    await page.goto('/this-route-absolutely-does-not-exist-xyz')
    await expect(page.getByText(/not found|404|page.*not.*found/i)).toBeVisible()
  })
})

// ─────────────────────────────────────────────────────────────────────────────
// Authentication Suite
// ─────────────────────────────────────────────────────────────────────────────

test.describe('Authentication', () => {
  test('user can sign up with valid email and password', async ({ page }) => {
    await signUp(page, testUser.email, testUser.password, testUser.name)
    // Should be redirected away from /signup
    await expect(page).not.toHaveURL('/signup')
  })

  test('invalid login credentials show error', async ({ page }) => {
    await page.goto('/login')
    await page.getByLabel(/email/i).fill('nonexistent@example.com')
    await page.getByLabel(/password/i).fill('wrongpassword123')
    await page.getByRole('button', { name: /log in|sign in/i }).click()
    // Should show an error message — could be alert, toast, or inline
    const errorLocator = page.getByRole('alert').or(page.getByText(/invalid|incorrect|error/i)).first()
    await expect(errorLocator).toBeVisible({ timeout: 5000 })
  })

  test('signup form validates empty fields', async ({ page }) => {
    await page.goto('/signup')
    await page.getByRole('button', { name: /sign up|create account/i }).click()
    // At least one validation error should appear
    const validationError = page.locator('[aria-invalid="true"], .text-red-500, [class*="error"]').first()
    await expect(validationError).toBeVisible({ timeout: 3000 })
  })

  test('user can log out', async ({ page }) => {
    await signIn(page, process.env.TEST_EMAIL || 'test@example.com', process.env.TEST_PASSWORD || 'TestPass123!')
    // Find and click logout — could be in a menu
    const userMenu = page.getByTestId('user-menu').or(page.getByRole('button', { name: /account|profile|user/i })).first()
    if (await userMenu.isVisible()) {
      await userMenu.click()
    }
    await page.getByRole('menuitem', { name: /log out|sign out/i })
      .or(page.getByRole('button', { name: /log out|sign out/i }))
      .first()
      .click()
    await expect(page).toHaveURL(/login|^\/$/, { timeout: 5000 })
  })
})

// ─────────────────────────────────────────────────────────────────────────────
// CRUD Suite — Replace [resource] with actual resource name
// ─────────────────────────────────────────────────────────────────────────────

test.describe('[Resource] CRUD Operations', () => {
  test.beforeEach(async ({ page }) => {
    await signIn(page, process.env.TEST_EMAIL || 'test@example.com', process.env.TEST_PASSWORD || 'TestPass123!')
  })

  test('create a new [resource]', async ({ page }) => {
    // Navigate to the list view
    await page.goto('/[resources]')
    // Find and click the create button
    await page.getByRole('button', { name: /new|create|add/i }).first().click()
    // Fill the primary field
    await page.getByRole('textbox').first().fill(`Test Item ${Date.now()}`)
    // Submit
    await page.getByRole('button', { name: /save|submit|create/i }).click()
    // Verify success
    await expect(page.getByText(/success|created|saved/i).or(page.getByRole('alert'))).toBeVisible({ timeout: 5000 })
  })

  test('list view displays records', async ({ page }) => {
    await page.goto('/[resources]')
    // List, grid, or table should be visible
    const listElement = page
      .getByRole('list')
      .or(page.locator('table'))
      .or(page.locator('[data-testid*="list"], [data-testid*="grid"]'))
      .first()
    await expect(listElement).toBeVisible({ timeout: 5000 })
  })

  test('edit an existing [resource]', async ({ page }) => {
    await page.goto('/[resources]')
    // Click the first item's edit action
    const editButton = page.getByRole('button', { name: /edit/i }).first()
      .or(page.getByRole('link', { name: /edit/i }).first())
    await editButton.click()
    // Modify a field
    const firstField = page.getByRole('textbox').first()
    await firstField.clear()
    await firstField.fill(`Updated ${Date.now()}`)
    await page.getByRole('button', { name: /save|update/i }).click()
    await expect(page.getByText(/success|updated|saved/i)).toBeVisible({ timeout: 5000 })
  })

  test('delete a [resource]', async ({ page }) => {
    await page.goto('/[resources]')
    const deleteButton = page.getByRole('button', { name: /delete|remove/i }).first()
    await deleteButton.click()
    // Handle confirmation dialog
    const confirmButton = page.getByRole('button', { name: /confirm|yes|delete/i })
    if (await confirmButton.isVisible({ timeout: 1000 })) {
      await confirmButton.click()
    }
    await expect(page.getByText(/deleted|removed|success/i)).toBeVisible({ timeout: 5000 })
  })
})

// ─────────────────────────────────────────────────────────────────────────────
// API Health Suite
// ─────────────────────────────────────────────────────────────────────────────

test.describe('API Health', () => {
  test('Supabase REST API responds', async ({ request }) => {
    const supabaseUrl = process.env.VITE_SUPABASE_URL
    const anonKey = process.env.VITE_SUPABASE_ANON_KEY
    if (!supabaseUrl || !anonKey) {
      test.skip(true, 'Supabase env vars not set')
      return
    }
    const response = await request.get(`${supabaseUrl}/rest/v1/`, {
      headers: { apikey: anonKey },
    })
    expect(response.status()).toBeLessThan(500)
  })

  test('app root returns 200', async ({ request }) => {
    const response = await request.get('/')
    expect(response.ok()).toBeTruthy()
  })
})

// ─────────────────────────────────────────────────────────────────────────────
// Performance Suite
// ─────────────────────────────────────────────────────────────────────────────

test.describe('Performance', () => {
  test('homepage loads within performance budget', async ({ page }) => {
    await page.goto('/')
    await page.waitForLoadState('networkidle')

    const timing = await page.evaluate(() => {
      const nav = performance.getEntriesByType('navigation')[0] as PerformanceNavigationTiming
      return {
        domContentLoaded: Math.round(nav.domContentLoadedEventEnd - nav.navigationStart),
        fullyLoaded: Math.round(nav.loadEventEnd - nav.navigationStart),
      }
    })

    // domContentLoaded < 2.5s (LCP proxy)
    expect(timing.domContentLoaded).toBeLessThan(2500)
    // Full load < 4s
    expect(timing.fullyLoaded).toBeLessThan(4000)
  })

  test('no JavaScript errors on homepage', async ({ page }) => {
    const errors: string[] = []
    page.on('console', (msg) => {
      if (msg.type() === 'error') errors.push(msg.text())
    })
    page.on('pageerror', (err) => errors.push(err.message))

    await page.goto('/')
    await page.waitForLoadState('networkidle')
    await page.waitForTimeout(1000) // Let async errors surface

    expect(errors, `Console errors found: ${errors.join(', ')}`).toHaveLength(0)
  })

  test('images have alt text (accessibility)', async ({ page }) => {
    await page.goto('/')
    const images = page.locator('img:not([role="presentation"])')
    const count = await images.count()
    for (let i = 0; i < count; i++) {
      const alt = await images.nth(i).getAttribute('alt')
      expect(alt, `Image at index ${i} is missing alt text`).not.toBeNull()
    }
  })
})
