import { APIRequestContext, expect } from '@playwright/test';

/**
 * Generate a unique 11-digit phone. Uses a random base + monotonic counter
 * so parallel Playwright workers don't collide on the same number.
 */
const _phoneBase = 50_000_000 + Math.floor(Math.random() * 40_000_000);
let _phoneSeq = 0;
export function uniquePhone(): string {
  _phoneSeq += 1;
  // 139 + 8 digits = 11 chars. Keep the value within 8 digits.
  const tail = String((_phoneBase + _phoneSeq) % 100_000_000).padStart(8, '0');
  return `139${tail}`;
}

export interface AuthSession {
  phone: string;
  accessToken: string;
  authHeader: { Authorization: string };
}

/**
 * Performs the debug-code auth dance and returns a session.
 * Requires the backend to be started with EXPOSE_DEBUG_VERIFICATION_CODE=1.
 */
export async function login(
  request: APIRequestContext,
  phone: string = uniquePhone(),
): Promise<AuthSession> {
  const sendCode = await request.post('/api/v1/auth/send_code', {
    data: { phone },
  });
  expect(sendCode.ok(), `send_code failed: ${await sendCode.text()}`).toBeTruthy();
  const codeBody = await sendCode.json();
  const code = codeBody.debug_code;
  expect(code, 'debug_code missing — set EXPOSE_DEBUG_VERIFICATION_CODE=1').toBeTruthy();

  const loginResp = await request.post('/api/v1/auth/login', {
    data: { phone, code },
  });
  expect(loginResp.ok(), `login failed: ${await loginResp.text()}`).toBeTruthy();
  const tokens = await loginResp.json();
  return {
    phone,
    accessToken: tokens.access_token,
    authHeader: { Authorization: `Bearer ${tokens.access_token}` },
  };
}

export async function createClass(
  request: APIRequestContext,
  auth: AuthSession,
  name = '测试班',
  grade = '三年级',
): Promise<number> {
  const resp = await request.post('/api/v1/classes', {
    headers: auth.authHeader,
    data: { name, grade },
  });
  expect(resp.ok()).toBeTruthy();
  return (await resp.json()).id;
}

export async function createStudents(
  request: APIRequestContext,
  auth: AuthSession,
  classId: number,
  items: Array<{ name: string; gender: 'male' | 'female' }>,
): Promise<Array<{ id: number; name: string }>> {
  for (const item of items) {
    const r = await request.post('/api/v1/students', {
      headers: auth.authHeader,
      data: { class_id: classId, ...item },
    });
    expect(r.ok()).toBeTruthy();
  }
  const list = await request.get(`/api/v1/students/class/${classId}`, {
    headers: auth.authHeader,
  });
  expect(list.ok()).toBeTruthy();
  return await list.json();
}
