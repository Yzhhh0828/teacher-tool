import { expect, test } from '@playwright/test';
import { login, createClass, createStudents } from './helpers';

test.describe('analytics: overview + distribution + compare', () => {
  test('full pipeline: students → exam → grades → analytics endpoints', async ({
    request,
  }) => {
    const auth = await login(request);
    const classId = await createClass(request, auth, '分析班', '六年级');
    const students = await createStudents(request, auth, classId, [
      { name: '王一', gender: 'male' },
      { name: '王二', gender: 'female' },
      { name: '王三', gender: 'male' },
      { name: '王四', gender: 'female' },
    ]);

    const exam = await request.post('/api/v1/grades/exams', {
      headers: auth.authHeader,
      data: { class_id: classId, name: '期中', date: '2026-04-15T08:00:00' },
    });
    expect(exam.ok()).toBeTruthy();
    const examId = (await exam.json()).id;

    const items = students.map((s, i) => ({
      student_id: s.id,
      subject: '数学',
      score: 60 + i * 10,
    }));
    const bulk = await request.post('/api/v1/agent/tools/invoke', {
      headers: auth.authHeader,
      data: {
        name: 'bulk_upsert_grades',
        arguments: { exam_id: examId, items },
        confirmed: true,
      },
    });
    expect(bulk.ok()).toBeTruthy();
    expect((await bulk.json()).result.created).toBe(4);

    const overview = await request.get(
      `/api/v1/analytics/class/${classId}/overview`,
      { headers: auth.authHeader },
    );
    expect(overview.ok()).toBeTruthy();
    const ov = await overview.json();
    expect(ov.student_count).toBe(4);
    expect(ov.exam_count).toBe(1);

    const dist = await request.get(
      `/api/v1/analytics/exam/${examId}/distribution`,
      { headers: auth.authHeader },
    );
    expect(dist.ok()).toBeTruthy();
    const distBody = await dist.json();
    expect(distBody.subjects['数学']).toBeTruthy();
    expect(distBody.subjects['数学'].stats.mean).toBeGreaterThan(0);

    const compare = await request.get(
      `/api/v1/analytics/class/${classId}/compare`,
      { headers: auth.authHeader },
    );
    expect(compare.ok()).toBeTruthy();
    expect((await compare.json()).series.length).toBeGreaterThan(0);
  });
});
