import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class ApiConfig {
  static String get baseUrl {
    const envUrl = String.fromEnvironment('API_BASE_URL');
    if (envUrl.isNotEmpty) return envUrl;
    
    // Android emulator runs in a VM, so localhost points to the VM itself.
    // 10.0.2.2 is the special alias to your host loopback interface.
    if (!kIsWeb && Platform.isAndroid) {
      return 'http://10.0.2.2:8000/api/v1';
    }
    return 'http://127.0.0.1:8000/api/v1'; // Also use 127.0.0.1 which is generally safer than localhost in some environments.
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
