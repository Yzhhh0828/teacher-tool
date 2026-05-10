import { defineConfig } from '@playwright/test';

const baseURL = process.env.E2E_API_BASE_URL ?? 'http://127.0.0.1:8000';

/**
 * Playwright runs HTTP-level end-to-end checks against the FastAPI backend.
 * The backend must be reachable at `baseURL`; in CI we spawn it via
 * the `webServer` block below.
 */
export default defineConfig({
  testDir: './tests',
  timeout: 30_000,
  expect: { timeout: 5_000 },
  fullyParallel: false,
  // Single worker keeps verification_store deterministic and avoids phone
  // collisions between worker processes.
  workers: 1,
  retries: process.env.CI ? 1 : 0,
  reporter: process.env.CI ? [['github'], ['html', { open: 'never' }]] : [['list']],
  use: {
    baseURL,
    extraHTTPHeaders: {
      'Content-Type': 'application/json',
    },
    trace: 'retain-on-failure',
  },
  webServer: process.env.E2E_NO_WEBSERVER
    ? undefined
    : {
        command:
          'python -m uvicorn app.main:app --host 127.0.0.1 --port 8000 --app-dir ../backend',
        url: baseURL + '/health',
        timeout: 60_000,
        reuseExistingServer: !process.env.CI,
        env: {
          DEBUG: '1',
          EXPOSE_DEBUG_VERIFICATION_CODE: '1',
          DATABASE_URL: 'sqlite+aiosqlite:///./e2e_playwright.db',
        },
      },
});
