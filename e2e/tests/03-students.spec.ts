import { expect, test } from '@playwright/test';
import { login, createClass } from './helpers';

test.describe('students: bulk import + list + delete', () => {
  test('bulk-import 4 students via the agent tool path', async ({ request }) => {
    const auth = await login(request);
    const classId = await createClass(request, auth, 'Bulk班', '五年级');

    const items = [
      { name: '张三', gender: 'male' },
      { name: '李四', gender: 'female' },
      { name: '王五', gender: 'male' },
      { name: '赵六', gender: 'female' },
    ];
    const invoke = await request.post('/api/v1/agent/tools/invoke', {
      headers: auth.authHeader,
      data: {
        name: 'bulk_create_students',
        arguments: { class_id: classId, items },
        confirmed: true,
      },
    });
    expect(invoke.ok()).toBeTruthy();
    const body = await invoke.json();
    expect(body.result.created).toBe(4);

    const list = await request.get(`/api/v1/students/class/${classId}`, {
      headers: auth.authHeader,
    });
    const students = await list.json();
    expect(students).toHaveLength(4);
  });

  test('single create + delete student', async ({ request }) => {
    const auth = await login(request);
    const classId = await createClass(request, auth);

    const create = await request.post('/api/v1/students', {
      headers: auth.authHeader,
      data: { class_id: classId, name: '单个学生', gender: 'male' },
    });
    expect(create.ok()).toBeTruthy();
    const sid = (await create.json()).id;

    const del = await request.delete(`/api/v1/students/${sid}`, {
      headers: auth.authHeader,
    });
    expect(del.ok()).toBeTruthy();
  });
});
