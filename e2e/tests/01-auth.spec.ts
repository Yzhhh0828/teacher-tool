import { expect, test } from '@playwright/test';
import { uniquePhone, login } from './helpers';

test.describe('auth: send_code + login + me', () => {
  test('full happy path returns tokens and a /me payload', async ({ request }) => {
    const session = await login(request);
    expect(session.accessToken).toBeTruthy();

    const me = await request.get('/api/v1/auth/me', {
      headers: session.authHeader,
    });
    expect(me.ok()).toBeTruthy();
    const body = await me.json();
    expect(body.phone).toBe(session.phone);
  });

  test('login with wrong code returns 400', async ({ request }) => {
    const phone = uniquePhone();
    const sc = await request.post('/api/v1/auth/send_code', { data: { phone } });
    expect(sc.ok()).toBeTruthy();
    const r = await request.post('/api/v1/auth/login', {
      data: { phone, code: '000000' },
    });
    expect(r.status()).toBe(400);
  });

  test('/me without token returns 401', async ({ request }) => {
    const r = await request.get('/api/v1/auth/me');
    expect([401, 403]).toContain(r.status());
  });
});
