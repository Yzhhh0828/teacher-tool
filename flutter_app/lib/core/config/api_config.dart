import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;

class ApiConfig {
  static String get baseUrl {
    const envUrl = String.fromEnvironment('API_BASE_URL');
    if (envUrl.isNotEmpty) return envUrl;

    // Web: served from same origin as backend — use relative path
    if (kIsWeb) return '/api/v1';

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

  // Schedules
  static const String schedules = '/schedules';
  static String classSchedules(int classId) => '/schedules/class/$classId';
  static String schedule(int scheduleId) => '/schedules/$scheduleId';

  // Agent
  static const String agentChat = '/agent/chat';
  static String agentHistory(String sessionId) => '/agent/history/$sessionId';
}
