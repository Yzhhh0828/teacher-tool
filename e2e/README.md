# Playwright API E2E Tests

HTTP-level end-to-end tests against the FastAPI backend. Uses
Playwright's `request` fixture so no browser is launched — fast and
hermetic.

## Run locally

```bash
# 1) install once
cd e2e
npm install

# 2) start the backend in a separate terminal (debug mode!)
cd ../backend
DEBUG=1 EXPOSE_DEBUG_VERIFICATION_CODE=1 \
  python -m uvicorn app.main:app --host 127.0.0.1 --port 8000

# 3) run the suite
cd ../e2e
E2E_NO_WEBSERVER=1 npm test
```

If `E2E_NO_WEBSERVER` is unset, Playwright will spawn the backend
itself (the command is configured in `playwright.config.ts`).

## Specs

| File | Coverage |
| --- | --- |
| `01-auth.spec.ts` | send_code → login → /me; wrong code; missing token |
| `02-classes.spec.ts` | CRUD + cross-tenant isolation |
| `03-students.spec.ts` | bulk create via agent + single CRUD |
| `04-seating.spec.ts` | default layout, named layout, apply, shuffle, delete |
| `05-behavior.spec.ts` | preset categories + records + leaderboard + custom category |
| `06-analytics.spec.ts` | overview + distribution + compare |
| `07-invite.spec.ts` | create code, join, revoke, invalid code |
| `08-agent.spec.ts` | confirm-required write, audit log, undo |

All specs depend on the backend running with `EXPOSE_DEBUG_VERIFICATION_CODE=1`
so they can fetch a debug verification code instead of waiting for SMS.
