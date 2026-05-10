import { expect, test } from '@playwright/test';
import { login } from './helpers';

test.describe('classes: CRUD lifecycle', () => {
  test('create + list + update + delete a class', async ({ request }) => {
    const auth = await login(request);

    const create = await request.post('/api/v1/classes', {
      headers: auth.authHeader,
      data: { name: 'E2E班', grade: '四年级' },
    });
    expect(create.ok()).toBeTruthy();
    const cls = await create.json();
    expect(cls.id).toBeTruthy();
    expect(cls.name).toBe('E2E班');

    const list = await request.get('/api/v1/classes', { headers: auth.authHeader });
    expect(list.ok()).toBeTruthy();
    const items = await list.json();
    expect(items.find((c: any) => c.id === cls.id)).toBeTruthy();

    const upd = await request.put(`/api/v1/classes/${cls.id}`, {
      headers: auth.authHeader,
      data: { name: 'E2E班-Renamed' },
    });
    expect(upd.ok()).toBeTruthy();
    expect((await upd.json()).name).toBe('E2E班-Renamed');

    const del = await request.delete(`/api/v1/classes/${cls.id}`, {
      headers: auth.authHeader,
    });
    expect(del.ok()).toBeTruthy();

    const after = await request.get('/api/v1/classes', { headers: auth.authHeader });
    const afterItems = await after.json();
    expect(afterItems.find((c: any) => c.id === cls.id)).toBeFalsy();
  });

  test('cross-tenant access is rejected', async ({ request }) => {
    const a = await login(request);
    const b = await login(request);
    const create = await request.post('/api/v1/classes', {
      headers: a.authHeader,
      data: { name: 'A的班', grade: '一年级' },
    });
    const aClassId = (await create.json()).id;

    const bSees = await request.get(`/api/v1/classes/${aClassId}`, {
      headers: b.authHeader,
    });
    expect([403, 404]).toContain(bSees.status());
  });
});
