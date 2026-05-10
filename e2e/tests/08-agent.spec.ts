import { expect, test } from '@playwright/test';
import { login, createClass } from './helpers';

test.describe('agent: confirm-required tools + audit log + undo', () => {
  test('write tool requires confirmed=true; audit log records the action', async ({
    request,
  }) => {
    const auth = await login(request);
    const classId = await createClass(request, auth);

    // Without confirmed=true the API should refuse the write and return a
    // "pending_confirmation" envelope instead of executing.
    const noConfirm = await request.post('/api/v1/agent/tools/invoke', {
      headers: auth.authHeader,
      data: {
        name: 'bulk_create_students',
        arguments: {
          class_id: classId,
          items: [{ name: '小明', gender: 'male' }],
        },
      },
    });
    expect(noConfirm.ok()).toBeTruthy();
    const pending = await noConfirm.json();
    expect(pending.status).toBe('pending_confirmation');
    expect(pending.tool).toBe('bulk_create_students');

    // Confirm: no rows have been written yet.
    const before = await request.get(`/api/v1/students/class/${classId}`, {
      headers: auth.authHeader,
    });
    expect((await before.json()).length).toBe(0);

    // Confirmed write succeeds.
    const ok = await request.post('/api/v1/agent/tools/invoke', {
      headers: auth.authHeader,
      data: {
        name: 'bulk_create_students',
        arguments: {
          class_id: classId,
          items: [{ name: '小明', gender: 'male' }],
        },
        confirmed: true,
      },
    });
    expect(ok.ok()).toBeTruthy();

    // Audit log lists the action.
    const actions = await request.get('/api/v1/agent/actions', {
      headers: auth.authHeader,
    });
    expect(actions.ok()).toBeTruthy();
    const items = (await actions.json()).items;
    expect(items.find((a: any) => a.action_type === 'bulk_create_students')).toBeTruthy();
  });

  test('undo of bulk_create_students removes the inserted rows', async ({
    request,
  }) => {
    const auth = await login(request);
    const classId = await createClass(request, auth);

    await request.post('/api/v1/agent/tools/invoke', {
      headers: auth.authHeader,
      data: {
        name: 'bulk_create_students',
        arguments: {
          class_id: classId,
          items: [
            { name: 'U1', gender: 'male' },
            { name: 'U2', gender: 'female' },
          ],
        },
        confirmed: true,
      },
    });

    const before = await request.get(`/api/v1/students/class/${classId}`, {
      headers: auth.authHeader,
    });
    expect((await before.json()).length).toBe(2);

    const actions = await request.get('/api/v1/agent/actions', {
      headers: auth.authHeader,
    });
    const items = (await actions.json()).items;
    const lastBulk = items.find((a: any) => a.action_type === 'bulk_create_students');
    expect(lastBulk).toBeTruthy();

    const undo = await request.post(`/api/v1/agent/actions/${lastBulk.id}/undo`, {
      headers: auth.authHeader,
    });
    expect(undo.ok()).toBeTruthy();

    const after = await request.get(`/api/v1/students/class/${classId}`, {
      headers: auth.authHeader,
    });
    expect((await after.json()).length).toBe(0);
  });
});
