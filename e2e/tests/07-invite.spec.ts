import { expect, test } from '@playwright/test';
import { login, createClass } from './helpers';

test.describe('invite: code create + join + revoke', () => {
  test('owner creates code, second user joins, code is revocable', async ({
    request,
  }) => {
    const owner = await login(request);
    const member = await login(request);
    const classId = await createClass(request, owner, '邀请班', '六年级');

    const codeResp = await request.post(
      `/api/v1/classes/${classId}/invite_code`,
      { headers: owner.authHeader },
    );
    expect(codeResp.ok()).toBeTruthy();
    const code = (await codeResp.json()).invite_code;
    expect(code).toBeTruthy();

    const join = await request.post('/api/v1/classes/join', {
      headers: member.authHeader,
      data: { invite_code: code, subject: '语文' },
    });
    expect(join.ok()).toBeTruthy();

    const memberClasses = await request.get('/api/v1/classes', {
      headers: member.authHeader,
    });
    const list = await memberClasses.json();
    expect(list.find((c: any) => c.id === classId)).toBeTruthy();

    const members = await request.get(`/api/v1/classes/${classId}/members`, {
      headers: owner.authHeader,
    });
    const mList = await members.json();
    expect(mList.length).toBe(2);
    expect(mList.find((m: any) => m.role === 'owner')).toBeTruthy();

    const revoke = await request.delete(
      `/api/v1/classes/${classId}/invite_code`,
      { headers: owner.authHeader },
    );
    expect(revoke.ok()).toBeTruthy();
  });

  test('expired/invalid code returns 404', async ({ request }) => {
    const auth = await login(request);
    const join = await request.post('/api/v1/classes/join', {
      headers: auth.authHeader,
      data: { invite_code: 'definitely-not-a-real-code-xyz', subject: '英语' },
    });
    expect(join.status()).toBe(404);
  });
});
