import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;

class ApiConfig {
  static String get baseUrl {
    const envUrl = String.fromEnvironment('API_BASE_URL');
    if (envUrl.isNotEmpty) return envUrl;

    if (kIsWeb) {
      // When the Flutter web app is being served by the backend itself
      // (e.g. uvicorn on :8000), a relative path is correct. When running the
      // Flutter web-server for hot reload (commonly :8080), the backend lives
      // on a different port; route to it explicitly.
      final origin = Uri.base;
      final samePort = origin.port == 8000 || origin.port == 0;
      if (samePort) return '/api/v1';
      return '${origin.scheme}://${origin.host}:8000/api/v1';
    }

    // Android emulator uses 10.0.2.2 to reach host loopback
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000/api/v1';
    }
    return 'http://127.0.0.1:8000/api/v1';
  }

  // Auth
  static const String sendCode = '/auth/send_code';
  static const String login = '/auth/login';
  static const String refresh = '/auth/refresh';
  static const String me = '/auth/me';

  // Classes
  static const String classes = '/classes';
  static String classDetail(int id) => '/classes/$id';
  static String createInviteCode(int id) => '/classes/$id/invite_code';
  static const String joinClass = '/classes/join';

  // Students
  static const String students = '/students';
  static String student(int id) => '/students/$id';
  static String classStudents(int classId) => '/students/class/$classId';

  // Grades
  static const String exams = '/grades/exams';
  static String classExams(int classId) => '/grades/exams/class/$classId';
  static const String grades = '/grades';
  static String examGrades(int examId) => '/grades/exams/$examId';

  // Seating
  static String seating(int classId) => '/seating/class/$classId';
  static String shuffleSeats(int classId) => '/seating/class/$classId/shuffle';
  static String seatingLayouts(int classId) => '/seating/layouts/class/$classId';
  static String seatingLayout(int layoutId) => '/seating/layouts/$layoutId';
  static String applyLayout(int layoutId) => '/seating/layouts/$layoutId/apply';

  // Schedules
  static const String schedules = '/schedules';
  static String classSchedules(int classId) => '/schedules/class/$classId';
  static String schedule(int scheduleId) => '/schedules/$scheduleId';

  // Agent
  static const String agentChat = '/agent/chat';
  static String agentHistory(String sessionId) => '/agent/history/$sessionId';
  static const String agentTools = '/agent/tools';
  static const String agentToolsInvoke = '/agent/tools/invoke';
  static const String agentProviders = '/agent/providers';

  // Analytics
  static String analyticsClassOverview(int classId) => '/analytics/class/$classId/overview';
  static String analyticsExamDistribution(int examId) => '/analytics/exam/$examId/distribution';
  static String analyticsStudentTrend(int studentId) => '/analytics/student/$studentId/trend';
  static String analyticsClassCompare(int classId) => '/analytics/class/$classId/compare';

  // Classroom front-stage
  static String classroomPick(int classId) => '/classroom/$classId/pick';
  static String classroomGroups(int classId) => '/classroom/$classId/groups';
  static String classroomEvents(int classId) => '/classroom/$classId/events';

  // Behavior tracking
  static String behaviorCategories(int classId) => '/behavior/categories/class/$classId';
  static String behaviorRecords(int classId) => '/behavior/records/class/$classId';
  static String behaviorStats(int classId) => '/behavior/stats/class/$classId';

  // Members management
  static String classMembers(int classId) => '/classes/$classId/members';
  static String classMember(int classId, int memberId) => '/classes/$classId/members/$memberId';
  static String revokeInviteCode(int classId) => '/classes/$classId/invite_code';
}
