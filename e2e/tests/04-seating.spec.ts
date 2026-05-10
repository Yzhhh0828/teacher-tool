import { expect, test } from '@playwright/test';
import { login, createClass, createStudents } from './helpers';

test.describe('seating: layout lifecycle', () => {
  test('default + named layout + apply + shuffle + delete', async ({ request }) => {
    const auth = await login(request);
    const classId = await createClass(request, auth, '座位班', '六年级');
    const students = await createStudents(request, auth, classId, [
      { name: 'A', gender: 'male' },
      { name: 'B', gender: 'female' },
      { name: 'C', gender: 'male' },
      { name: 'D', gender: 'female' },
    ]);
    const ids = students.map((s) => s.id);

    const def = await request.get(`/api/v1/seating/class/${classId}`, {
      headers: auth.authHeader,
    });
    expect(def.ok()).toBeTruthy();
    const seating = await def.json();
    expect(seating.rows).toBeGreaterThan(0);
    expect(seating.cols).toBeGreaterThan(0);

    const layout = await request.post(`/api/v1/seating/layouts/class/${classId}`, {
      headers: auth.authHeader,
      data: {
        name: '考试',
        rows: 2,
        cols: 2,
        seats: [[ids[0], ids[1]], [ids[2], ids[3]]],
        is_active: false,
      },
    });
    expect(layout.ok()).toBeTruthy();
    const layoutId = (await layout.json()).id;

    const apply = await request.post(`/api/v1/seating/layouts/${layoutId}/apply`, {
      headers: auth.authHeader,
    });
    expect(apply.ok()).toBeTruthy();
    const applied = await apply.json();
    expect(applied.rows).toBe(2);
    expect(applied.cols).toBe(2);

    const shuffle = await request.post(`/api/v1/seating/class/${classId}/shuffle`, {
      headers: auth.authHeader,
    });
    expect(shuffle.ok()).toBeTruthy();
    const flat = (await shuffle.json()).seats.flat().filter((x: number | null) => x !== null);
    expect(flat.sort()).toEqual([...ids].sort());

    const del = await request.delete(`/api/v1/seating/layouts/${layoutId}`, {
      headers: auth.authHeader,
    });
    expect(del.ok()).toBeTruthy();
  });
});
