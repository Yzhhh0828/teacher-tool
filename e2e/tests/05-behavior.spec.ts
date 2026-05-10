import { expect, test } from '@playwright/test';
import { login, createClass, createStudents } from './helpers';

test.describe('behavior: categories + records + leaderboard', () => {
  test('preset categories seeded; positive + negative records aggregate', async ({
    request,
  }) => {
    const auth = await login(request);
    const classId = await createClass(request, auth, '行为班', '二年级');
    const students = await createStudents(request, auth, classId, [
      { name: 'Alice', gender: 'female' },
      { name: 'Bob', gender: 'male' },
    ]);

    const cats = await request.get(
      `/api/v1/behavior/categories/class/${classId}`,
      { headers: auth.authHeader },
    );
    expect(cats.ok()).toBeTruthy();
    const list = await cats.json();
    expect(list.length).toBeGreaterThanOrEqual(4);
    const pos = list.find((c: any) => c.score > 0);
    const neg = list.find((c: any) => c.score < 0);
    expect(pos).toBeTruthy();
    expect(neg).toBeTruthy();

    for (let i = 0; i < 2; i++) {
      const r = await request.post(
        `/api/v1/behavior/records/class/${classId}`,
        {
          headers: auth.authHeader,
          data: { student_ids: [students[0].id], category_id: pos.id },
        },
      );
      expect(r.ok()).toBeTruthy();
    }
    const r2 = await request.post(
      `/api/v1/behavior/records/class/${classId}`,
      {
        headers: auth.authHeader,
        data: { student_ids: [students[1].id], category_id: neg.id },
      },
    );
    expect(r2.ok()).toBeTruthy();

    const stats = await request.get(`/api/v1/behavior/stats/class/${classId}`, {
      headers: auth.authHeader,
    });
    expect(stats.ok()).toBeTruthy();
    const rows: any[] = await stats.json();
    const byId = Object.fromEntries(rows.map((r) => [r.student_id, r]));
    expect(byId[students[0].id].total_score).toBe(pos.score * 2);
    expect(byId[students[1].id].total_score).toBe(neg.score);
  });

  test('custom category create + delete', async ({ request }) => {
    const auth = await login(request);
    const classId = await createClass(request, auth);

    const create = await request.post(
      `/api/v1/behavior/categories/class/${classId}`,
      {
        headers: auth.authHeader,
        data: { name: '专心听讲', icon: 'star', score: 2.5, sort_order: 99 },
      },
    );
    expect(create.ok()).toBeTruthy();
    const cat = await create.json();
    expect(cat.score).toBe(2.5);

    const del = await request.delete(`/api/v1/behavior/categories/${cat.id}`, {
      headers: auth.authHeader,
    });
    expect(del.ok()).toBeTruthy();
  });
});
