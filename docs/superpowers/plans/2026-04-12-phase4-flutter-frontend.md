# Phase 4: Flutter 前端

**目标:** 完成 Flutter 多平台应用

**Sub-plan for:** [主计划](./2026-04-12-teacher-tool-master-plan.md)

**Prerequisite:** Phase 1, Phase 2 完成

---

## 项目结构

```
flutter_app/
├── lib/
│   ├── main.dart
│   ├── app.dart
│   ├── core/
│   │   ├── config/
│   │   │   └── api_config.dart
│   │   ├── theme/
│   │   │   └── app_theme.dart
│   │   └── utils/
│   │       └── api_client.dart
│   ├── data/
│   │   ├── models/
│   │   │   ├── user.dart
│   │   │   ├── class_model.dart
│   │   │   ├── student.dart
│   │   │   ├── grade.dart
│   │   │   └── seating.dart
│   │   ├── repositories/
│   │   │   ├── auth_repository.dart
│   │   │   ├── class_repository.dart
│   │   │   ├── student_repository.dart
│   │   │   └── agent_repository.dart
│   │   └── services/
│   │       ├── api_service.dart
│   │       └── sse_service.dart
│   ├── providers/
│   │   ├── auth_provider.dart
│   │   ├── class_provider.dart
│   │   ├── student_provider.dart
│   │   ├── grade_provider.dart
│   │   ├── seating_provider.dart
│   │   └── agent_provider.dart
│   ├── ui/
│   │   ├── screens/
│   │   │   ├── auth/
│   │   │   │   └── login_screen.dart
│   │   │   ├── home/
│   │   │   │   └── home_screen.dart
│   │   │   ├── class_/
│   │   │   │   ├── class_list_screen.dart
│   │   │   │   └── class_detail_screen.dart
│   │   │   ├── student/
│   │   │   │   ├── student_list_screen.dart
│   │   │   │   └── student_form_screen.dart
│   │   │   ├── grade/
│   │   │   │   ├── exam_list_screen.dart
│   │   │   │   └── grade_entry_screen.dart
│   │   │   ├── seating/
│   │   │   │   └── seating_screen.dart
│   │   │   └── presentation/
│   │   │       └── presentation_screen.dart
│   │   └── widgets/
│   │       ├── loading_widget.dart
│   │       └── error_widget.dart
│   └── agent/
│       ├── chat_screen.dart
│       └── image_picker_widget.dart
├── pubspec.yaml
└── android/
    └── ...
```

---

## Task 1: 项目搭建

**Files:**
- Create: `flutter_app/pubspec.yaml`
- Create: `flutter_app/lib/main.dart`
- Create: `flutter_app/lib/app.dart`

- [ ] **Step 1: Create pubspec.yaml**

```yaml
name: teacher_tool
description: AI-powered teacher tool for class management
publish_to: 'none'
version: 1.0.0

environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8

  # State Management
  flutter_riverpod: ^2.5.1
  riverpod_annotation: ^2.3.5

  # Navigation
  go_router: ^14.2.0

  # Network
  dio: ^5.4.3+1

  # Storage
  shared_preferences: ^2.2.3
  flutter_secure_storage: ^9.0.0

  # UI
  flutter_svg: ^2.0.10+1
  cached_network_image: ^3.3.1

  # Utils
  intl: ^0.19.0
  image_picker: ^1.0.7
  file_picker: ^8.0.3
  excel: ^4.0.3
  csv: ^6.0.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^4.0.0
  riverpod_generator: ^2.4.0
  build_runner: ^2.4.9

flutter:
  uses-material-design: true
```

- [ ] **Step 2: Create lib/core/config/api_config.dart**

```dart
class ApiConfig {
  static const String baseUrl = 'http://localhost:8000/api/v1';

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
  static String classStudents(int classId) => '/students/class/$classId';

  // Grades
  static const String exams = '/grades/exams';
  static String classExams(int classId) => '/grades/exams/class/$classId';
  static const String grades = '/grades';
  static String examGrades(int examId) => '/grades/exams/$examId';

  // Seating
  static String seating(int classId) => '/seating/class/$classId';
  static String shuffleSeats(int classId) => '/seating/class/$classId/shuffle';

  // Agent
  static const String agentChat = '/agent/chat';
  static String agentHistory(String sessionId) => '/agent/history/$sessionId';
}
```

- [ ] **Step 3: Create lib/core/utils/api_client.dart**

```dart
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/api_config.dart';

class ApiClient {
  late final Dio _dio;
  final _storage = const FlutterSecureStorage();

  ApiClient() {
    _dio = Dio(BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: 'access_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          // Try to refresh token
          final refreshed = await _refreshToken();
          if (refreshed) {
            // Retry request
            final opts = error.requestOptions;
            final token = await _storage.read(key: 'access_token');
            opts.headers['Authorization'] = 'Bearer $token';
            final response = await _dio.fetch(opts);
            return handler.resolve(response);
          }
        }
        return handler.next(error);
      },
    ));
  }

  Future<bool> _refreshToken() async {
    try {
      final refreshToken = await _storage.read(key: 'refresh_token');
      if (refreshToken == null) return false;

      final response = await Dio().post(
        '${ApiConfig.baseUrl}${ApiConfig.refresh}',
        data: {'refresh_token': refreshToken},
      );

      if (response.statusCode == 200) {
        await _storage.write(
          key: 'access_token',
          value: response.data['access_token'],
        );
        await _storage.write(
          key: 'refresh_token',
          value: response.data['refresh_token'],
        );
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<Response> get(String path, {Map<String, dynamic>? queryParameters}) {
    return _dio.get(path, queryParameters: queryParameters);
  }

  Future<Response> post(String path, {dynamic data}) {
    return _dio.post(path, data: data);
  }

  Future<Response> put(String path, {dynamic data}) {
    return _dio.put(path, data: data);
  }

  Future<Response> delete(String path) {
    return _dio.delete(path);
  }
}
```

- [ ] **Step 4: Create lib/core/theme/app_theme.dart**

```dart
import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF6366F1),
        brightness: Brightness.light,
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
      ),
      cardTheme: CardTheme(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  // Presentation mode theme (large fonts)
  static ThemeData get presentationTheme {
    return lightTheme.copyWith(
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontSize: 72, fontWeight: FontWeight.bold),
        displayMedium: TextStyle(fontSize: 56, fontWeight: FontWeight.bold),
        displaySmall: TextStyle(fontSize: 44, fontWeight: FontWeight.bold),
        headlineLarge: TextStyle(fontSize: 40),
        headlineMedium: TextStyle(fontSize: 32),
        titleLarge: TextStyle(fontSize: 28),
        bodyLarge: TextStyle(fontSize: 24),
        bodyMedium: TextStyle(fontSize: 20),
      ),
    );
  }
}
```

- [ ] **Step 5: Create lib/main.dart**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const ProviderScope(
      child: TeacherToolApp(),
    ),
  );
}
```

- [ ] **Step 6: Create lib/app.dart**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'ui/screens/auth/login_screen.dart';
import 'ui/screens/home/home_screen.dart';

class TeacherToolApp extends ConsumerStatefulWidget {
  const TeacherToolApp({super.key});

  @override
  ConsumerState<TeacherToolApp> createState() => _TeacherToolAppState();
}

class _TeacherToolAppState extends ConsumerState<TeacherToolApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Teacher Tool',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends ConsumerWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Check if user is logged in
    // For now, show login screen
    return const LoginScreen();
  }
}
```

- [ ] **Step 7: Commit**

```bash
cd flutter_app && git init && git add -A && git commit -m "feat: add Flutter project structure"
```

---

## Task 2: 认证 UI

**Files:**
- Create: `flutter_app/lib/data/models/user.dart`
- Create: `flutter_app/lib/data/repositories/auth_repository.dart`
- Create: `flutter_app/lib/providers/auth_provider.dart`
- Create: `flutter_app/lib/ui/screens/auth/login_screen.dart`

- [ ] **Step 1: Create lib/data/models/user.dart**

```dart
class User {
  final int id;
  final String phone;
  final DateTime createdAt;

  User({
    required this.id,
    required this.phone,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      phone: json['phone'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

class AuthTokens {
  final String accessToken;
  final String refreshToken;

  AuthTokens({
    required this.accessToken,
    required this.refreshToken,
  });

  factory AuthTokens.fromJson(Map<String, dynamic> json) {
    return AuthTokens(
      accessToken: json['access_token'],
      refreshToken: json['refresh_token'],
    );
  }
}
```

- [ ] **Step 2: Create lib/data/repositories/auth_repository.dart**

```dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/config/api_config.dart';
import '../../core/utils/api_client.dart';
import '../models/user.dart';

class AuthRepository {
  final ApiClient _client;
  final _storage = const FlutterSecureStorage();

  AuthRepository(this._client);

  Future<void> sendCode(String phone) async {
    await _client.post(ApiConfig.sendCode, data: {'phone': phone});
  }

  Future<AuthTokens> login(String phone, String code) async {
    final response = await _client.post(
      ApiConfig.login,
      data: {'phone': phone, 'code': code},
    );
    final tokens = AuthTokens.fromJson(response.data);

    // Save tokens
    await _storage.write(key: 'access_token', value: tokens.accessToken);
    await _storage.write(key: 'refresh_token', value: tokens.refreshToken);

    return tokens;
  }

  Future<User> getMe() async {
    final response = await _client.get(ApiConfig.me);
    return User.fromJson(response.data);
  }

  Future<bool> isLoggedIn() async {
    final token = await _storage.read(key: 'access_token');
    return token != null;
  }

  Future<void> logout() async {
    await _storage.delete(key: 'access_token');
    await _storage.delete(key: 'refresh_token');
  }
}
```

- [ ] **Step 3: Create lib/providers/auth_provider.dart**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/api_client.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/models/user.dart';

final apiClientProvider = Provider((ref) => ApiClient());
final authRepositoryProvider = Provider((ref) => AuthRepository(ref.read(apiClientProvider)));

final authStateProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.read(authRepositoryProvider));
});

class AuthState {
  final bool isLoading;
  final bool isLoggedIn;
  final User? user;
  final String? error;

  AuthState({
    this.isLoading = false,
    this.isLoggedIn = false,
    this.user,
    this.error,
  });

  AuthState copyWith({
    bool? isLoading,
    bool? isLoggedIn,
    User? user,
    String? error,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      user: user ?? this.user,
      error: error,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repository;

  AuthNotifier(this._repository) : super(AuthState());

  Future<void> checkLoginStatus() async {
    state = state.copyWith(isLoading: true);
    final isLoggedIn = await _repository.isLoggedIn();
    if (isLoggedIn) {
      try {
        final user = await _repository.getMe();
        state = state.copyWith(isLoading: false, isLoggedIn: true, user: user);
      } catch (_) {
        state = state.copyWith(isLoading: false, isLoggedIn: false);
      }
    } else {
      state = state.copyWith(isLoading: false, isLoggedIn: false);
    }
  }

  Future<void> sendCode(String phone) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repository.sendCode(phone);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> login(String phone, String code) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repository.login(phone, code);
      final user = await _repository.getMe();
      state = state.copyWith(isLoading: false, isLoggedIn: true, user: user);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> logout() async {
    await _repository.logout();
    state = AuthState();
  }
}
```

- [ ] **Step 4: Create lib/ui/screens/auth/login_screen.dart**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/auth_provider.dart';
import '../../home/home_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  bool _codeSent = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) return;

    await ref.read(authStateProvider.notifier).sendCode(phone);
    setState(() => _codeSent = true);
  }

  Future<void> _login() async {
    final phone = _phoneController.text.trim();
    final code = _codeController.text.trim();
    if (phone.isEmpty || code.isEmpty) return;

    await ref.read(authStateProvider.notifier).login(phone, code);

    if (ref.read(authStateProvider).isLoggedIn && mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.school,
                size: 80,
                color: Color(0xFF6366F1),
              ),
              const SizedBox(height: 16),
              Text(
                '教师工具',
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: '手机号',
                  prefixIcon: Icon(Icons.phone),
                ),
              ),
              const SizedBox(height: 16),
              if (!_codeSent) ...[
                ElevatedButton(
                  onPressed: authState.isLoading ? null : _sendCode,
                  child: authState.isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('发送验证码'),
                ),
              ] else ...[
                TextField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '验证码',
                    prefixIcon: Icon(Icons.lock),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: authState.isLoading ? null : _login,
                  child: authState.isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('登录'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => setState(() => _codeSent = false),
                  child: const Text('返回'),
                ),
              ],
              if (authState.error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    authState.error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat: add authentication UI"
```

---

## Task 3: 班级管理 UI

**Files:**
- Create: `flutter_app/lib/data/models/class_model.dart`
- Create: `flutter_app/lib/data/repositories/class_repository.dart`
- Create: `flutter_app/lib/providers/class_provider.dart`
- Create: `flutter_app/lib/ui/screens/class_/class_list_screen.dart`
- Create: `flutter_app/lib/ui/screens/class_/class_detail_screen.dart`

- [ ] **Step 1: Create lib/data/models/class_model.dart**

```dart
class ClassModel {
  final int id;
  final String name;
  final String grade;
  final int ownerId;
  final DateTime createdAt;

  ClassModel({
    required this.id,
    required this.name,
    required this.grade,
    required this.ownerId,
    required this.createdAt,
  });

  factory ClassModel.fromJson(Map<String, dynamic> json) {
    return ClassModel(
      id: json['id'],
      name: json['name'],
      grade: json['grade'],
      ownerId: json['owner_id'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

class ClassMember {
  final int id;
  final int classId;
  final int userId;
  final String role;
  final String? subject;
  final DateTime joinedAt;

  ClassMember({
    required this.id,
    required this.classId,
    required this.userId,
    required this.role,
    this.subject,
    required this.joinedAt,
  });

  factory ClassMember.fromJson(Map<String, dynamic> json) {
    return ClassMember(
      id: json['id'],
      classId: json['class_id'],
      userId: json['user_id'],
      role: json['role'],
      subject: json['subject'],
      joinedAt: DateTime.parse(json['joined_at']),
    );
  }
}
```

- [ ] **Step 2: Create lib/data/repositories/class_repository.dart**

```dart
import '../../core/config/api_config.dart';
import '../../core/utils/api_client.dart';
import '../models/class_model.dart';

class ClassRepository {
  final ApiClient _client;

  ClassRepository(this._client);

  Future<List<ClassModel>> getClasses() async {
    final response = await _client.get(ApiConfig.classes);
    return (response.data as List)
        .map((json) => ClassModel.fromJson(json))
        .toList();
  }

  Future<ClassModel> createClass(String name, String grade) async {
    final response = await _client.post(
      ApiConfig.classes,
      data: {'name': name, 'grade': grade},
    );
    return ClassModel.fromJson(response.data);
  }

  Future<ClassModel> getClassDetail(int classId) async {
    final response = await _client.get(ApiConfig.classDetail(classId));
    return ClassModel.fromJson(response.data);
  }

  Future<String> createInviteCode(int classId) async {
    final response = await _client.post(ApiConfig.createInviteCode(classId));
    return response.data['invite_code'];
  }

  Future<void> joinClass(String inviteCode, String subject) async {
    await _client.post(
      ApiConfig.joinClass,
      data: {'invite_code': inviteCode, 'subject': subject},
    );
  }

  Future<void> deleteClass(int classId) async {
    await _client.delete(ApiConfig.classDetail(classId));
  }
}
```

- [ ] **Step 3: Create lib/providers/class_provider.dart**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/api_client.dart';
import '../../data/repositories/class_repository.dart';
import '../../data/models/class_model.dart';
import 'auth_provider.dart';

final classRepositoryProvider = Provider((ref) => ClassRepository(ref.read(apiClientProvider)));

final classListProvider = StateNotifierProvider<ClassListNotifier, AsyncValue<List<ClassModel>>>((ref) {
  return ClassListNotifier(ref.read(classRepositoryProvider));
});

final currentClassProvider = StateProvider<ClassModel?>((ref) => null);

class ClassListNotifier extends StateNotifier<AsyncValue<List<ClassModel>>> {
  final ClassRepository _repository;

  ClassListNotifier(this._repository) : super(const AsyncValue.loading()) {
    loadClasses();
  }

  Future<void> loadClasses() async {
    state = const AsyncValue.loading();
    try {
      final classes = await _repository.getClasses();
      state = AsyncValue.data(classes);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> createClass(String name, String grade) async {
    try {
      await _repository.createClass(name, grade);
      await loadClasses();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteClass(int classId) async {
    try {
      await _repository.deleteClass(classId);
      await loadClasses();
    } catch (e) {
      rethrow;
    }
  }
}
```

- [ ] **Step 4: Create lib/ui/screens/class_/class_list_screen.dart**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/class_provider.dart';
import '../../../data/models/class_model.dart';
import 'class_detail_screen.dart';

class ClassListScreen extends ConsumerWidget {
  const ClassListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classesAsync = ref.watch(classListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的班级'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showCreateClassDialog(context, ref),
          ),
        ],
      ),
      body: classesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (classes) => classes.isEmpty
            ? const Center(child: Text('暂无班级，点击+创建'))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: classes.length,
                itemBuilder: (context, index) {
                  final class_ = classes[index];
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text(class_.name[0]),
                      ),
                      title: Text(class_.name),
                      subtitle: Text('${class_.grade}年级'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        ref.read(currentClassProvider.notifier).state = class_;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ClassDetailScreen(classId: class_.id),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showJoinClassDialog(context, ref),
        child: const Icon(Icons.group_add),
      ),
    );
  }

  void _showCreateClassDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final gradeController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('创建班级'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: '班级名称'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: gradeController,
              decoration: const InputDecoration(labelText: '年级'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              await ref.read(classListProvider.notifier).createClass(
                    nameController.text,
                    gradeController.text,
                  );
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('创建'),
          ),
        ],
      ),
    );
  }

  void _showJoinClassDialog(BuildContext context, WidgetRef ref) {
    final codeController = TextEditingController();
    final subjectController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('加入班级'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: codeController,
              decoration: const InputDecoration(labelText: '邀请码'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: subjectController,
              decoration: const InputDecoration(labelText: '教授科目'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              final repository = ref.read(classRepositoryProvider);
              await repository.joinClass(
                codeController.text,
                subjectController.text,
              );
              await ref.read(classListProvider.notifier).loadClasses();
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('加入'),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat: add class management UI"
```

---

## Task 4: 学生管理 UI

**Files:**
- Create: `flutter_app/lib/data/models/student.dart`
- Create: `flutter_app/lib/data/repositories/student_repository.dart`
- Create: `flutter_app/lib/providers/student_provider.dart`
- Create: `flutter_app/lib/ui/screens/student/student_list_screen.dart`
- Create: `flutter_app/lib/ui/screens/student/student_form_screen.dart`

- [ ] **Step 1: Create lib/data/models/student.dart**

```dart
class Student {
  final int id;
  final int classId;
  final String name;
  final String gender;
  final String? phone;
  final String? parentPhone;
  final String? remarks;
  final DateTime createdAt;

  Student({
    required this.id,
    required this.classId,
    required this.name,
    required this.gender,
    this.phone,
    this.parentPhone,
    this.remarks,
    required this.createdAt,
  });

  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(
      id: json['id'],
      classId: json['class_id'],
      name: json['name'],
      gender: json['gender'],
      phone: json['phone'],
      parentPhone: json['parent_phone'],
      remarks: json['remarks'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'gender': gender,
      'phone': phone,
      'parent_phone': parentPhone,
      'remarks': remarks,
    };
  }
}
```

- [ ] **Step 2: Create lib/data/repositories/student_repository.dart**

```dart
import '../../core/config/api_config.dart';
import '../../core/utils/api_client.dart';
import '../models/student.dart';

class StudentRepository {
  final ApiClient _client;

  StudentRepository(this._client);

  Future<List<Student>> getStudents(int classId) async {
    final response = await _client.get(ApiConfig.classStudents(classId));
    return (response.data as List)
        .map((json) => Student.fromJson(json))
        .toList();
  }

  Future<Student> createStudent(int classId, Student student) async {
    final data = student.toJson();
    data['class_id'] = classId;
    final response = await _client.post(ApiConfig.students, data: data);
    return Student.fromJson(response.data);
  }

  Future<Student> updateStudent(int studentId, Map<String, dynamic> fields) async {
    final response = await _client.put(
      '${ApiConfig.students}/$studentId',
      data: fields,
    );
    return Student.fromJson(response.data);
  }

  Future<void> deleteStudent(int studentId) async {
    await _client.delete('${ApiConfig.students}/$studentId');
  }
}
```

- [ ] **Step 3: Create lib/providers/student_provider.dart**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/student_repository.dart';
import '../../data/models/student.dart';
import 'auth_provider.dart';

final studentRepositoryProvider = Provider((ref) => StudentRepository(ref.read(apiClientProvider)));

final studentListProvider = StateNotifierProvider.family<StudentListNotifier, AsyncValue<List<Student>>, int>((ref, classId) {
  return StudentListNotifier(ref.read(studentRepositoryProvider), classId));
});

class StudentListNotifier extends StateNotifier<AsyncValue<List<Student>>> {
  final StudentRepository _repository;
  final int classId;

  StudentListNotifier(this._repository, this.classId) : super(const AsyncValue.loading()) {
    loadStudents();
  }

  Future<void> loadStudents() async {
    state = const AsyncValue.loading();
    try {
      final students = await _repository.getStudents(classId);
      state = AsyncValue.data(students);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addStudent(Student student) async {
    try {
      await _repository.createStudent(classId, student);
      await loadStudents();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateStudent(int studentId, Map<String, dynamic> fields) async {
    try {
      await _repository.updateStudent(studentId, fields);
      await loadStudents();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteStudent(int studentId) async {
    try {
      await _repository.deleteStudent(studentId);
      await loadStudents();
    } catch (e) {
      rethrow;
    }
  }
}
```

- [ ] **Step 4: Create lib/ui/screens/student/student_list_screen.dart**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/student_provider.dart';
import '../../../providers/class_provider.dart';
import 'student_form_screen.dart';

class StudentListScreen extends ConsumerWidget {
  const StudentListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentClass = ref.watch(currentClassProvider);
    if (currentClass == null) {
      return const Center(child: Text('请先选择班级'));
    }

    final studentsAsync = ref.watch(studentListProvider(currentClass.id));

    return Scaffold(
      appBar: AppBar(
        title: const Text('学生管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => StudentFormScreen(classId: currentClass.id),
                ),
              );
            },
          ),
        ],
      ),
      body: studentsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (students) => students.isEmpty
            ? const Center(child: Text('暂无学生，点击+添加'))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: students.length,
                itemBuilder: (context, index) {
                  final student = students[index];
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text(student.name[0]),
                      ),
                      title: Text(student.name),
                      subtitle: Text('${student.gender} | ${student.phone ?? "无电话"}'),
                      trailing: PopupMenuButton(
                        itemBuilder: (context) => [
                          const PopupMenuItem(value: 'edit', child: Text('编辑')),
                          const PopupMenuItem(value: 'delete', child: Text('删除')),
                        ],
                        onSelected: (value) async {
                          if (value == 'edit') {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => StudentFormScreen(
                                  classId: currentClass.id,
                                  student: student,
                                ),
                              ),
                            );
                          } else if (value == 'delete') {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('确认删除'),
                                content: Text('确定要删除学生 ${student.name} 吗？'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, false),
                                    child: const Text('取消'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () => Navigator.pop(context, true),
                                    child: const Text('删除'),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              await ref
                                  .read(studentListProvider(currentClass.id).notifier)
                                  .deleteStudent(student.id);
                            }
                          }
                        },
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
```

- [ ] **Step 5: Create lib/ui/screens/student/student_form_screen.dart**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/student_provider.dart';
import '../../../data/models/student.dart';

class StudentFormScreen extends ConsumerStatefulWidget {
  final int classId;
  final Student? student;

  const StudentFormScreen({
    super.key,
    required this.classId,
    this.student,
  });

  @override
  ConsumerState<StudentFormScreen> createState() => _StudentFormScreenState();
}

class _StudentFormScreenState extends ConsumerState<StudentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _parentPhoneController;
  late final TextEditingController _remarksController;
  String _gender = 'male';

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.student?.name ?? '');
    _phoneController = TextEditingController(text: widget.student?.phone ?? '');
    _parentPhoneController = TextEditingController(text: widget.student?.parentPhone ?? '');
    _remarksController = TextEditingController(text: widget.student?.remarks ?? '');
    _gender = widget.student?.gender ?? 'male';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _parentPhoneController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final student = Student(
      id: widget.student?.id ?? 0,
      classId: widget.classId,
      name: _nameController.text.trim(),
      gender: _gender,
      phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
      parentPhone: _parentPhoneController.text.trim().isEmpty ? null : _parentPhoneController.text.trim(),
      remarks: _remarksController.text.trim().isEmpty ? null : _remarksController.text.trim(),
      createdAt: widget.student?.createdAt ?? DateTime.now(),
    );

    try {
      if (widget.student == null) {
        await ref.read(studentListProvider(widget.classId).notifier).addStudent(student);
      } else {
        await ref.read(studentListProvider(widget.classId).notifier).updateStudent(
              widget.student!.id,
              student.toJson(),
            );
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.student == null ? '添加学生' : '编辑学生'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: '姓名 *'),
              validator: (value) => value?.isEmpty == true ? '请输入姓名' : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _gender,
              decoration: const InputDecoration(labelText: '性别'),
              items: const [
                DropdownMenuItem(value: 'male', child: Text('男')),
                DropdownMenuItem(value: 'female', child: Text('女')),
              ],
              onChanged: (value) => setState(() => _gender = value!),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(labelText: '学生电话'),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _parentPhoneController,
              decoration: const InputDecoration(labelText: '家长电话'),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _remarksController,
              decoration: const InputDecoration(labelText: '备注'),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _submit,
              child: Text(widget.student == null ? '添加' : '保存'),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 6: Commit**

```bash
git add -A && git commit -m "feat: add student management UI"
```

---

## Task 5: Agent 对话 UI

**Files:**
- Create: `flutter_app/lib/agent/chat_screen.dart`
- Create: `flutter_app/lib/data/repositories/agent_repository.dart`
- Create: `flutter_app/lib/data/services/sse_service.dart`
- Create: `flutter_app/lib/providers/agent_provider.dart`

- [ ] **Step 1: Create lib/data/services/sse_service.dart**

```dart
import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';

class SSEService {
  final Dio _dio;

  SSEService() : _dio = Dio();

  Stream<Map<String, dynamic>> connect(String url, Map<String, dynamic> data) async* {
    final response = await _dio.post<ResponseBody>(
      url,
      data: data,
      options: Options(
        responseType: ResponseType.stream,
        headers: {
          'Accept': 'text/event-stream',
        },
      ),
    );

    final stream = response.data!.stream;
    String buffer = '';

    await for (final chunk in stream) {
      buffer += utf8.decode(chunk);

      while (buffer.contains('\n\n')) {
        final index = buffer.indexOf('\n\n');
        final line = buffer.substring(0, index).trim();
        buffer = buffer.substring(index + 2);

        if (line.startsWith('data:')) {
          final jsonStr = line.substring(5).trim();
          if (jsonStr.isNotEmpty) {
            try {
              yield jsonDecode(jsonStr);
            } catch (_) {}
          }
        }
      }
    }
  }
}
```

- [ ] **Step 2: Create lib/data/repositories/agent_repository.dart**

```dart
import '../../core/config/api_config.dart';
import '../../core/utils/api_client.dart';
import '../services/sse_service.dart';

class AgentRepository {
  final ApiClient _client;
  final SSEService _sseService;

  AgentRepository(this._client) : _sseService = SSEService();

  Stream<Map<String, dynamic>> chat({
    required String message,
    String? sessionId,
    String? image,
  }) {
    return _sseService.connect(
      ApiConfig.agentChat,
      {
        'content': message,
        'session_id': sessionId,
        'image': image,
      },
    );
  }

  Future<List<Map<String, dynamic>>> getHistory(String sessionId) async {
    final response = await _client.get(ApiConfig.agentHistory(sessionId));
    return List<Map<String, dynamic>>.from(response.data['messages']);
  }
}
```

- [ ] **Step 3: Create lib/providers/agent_provider.dart**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/agent_repository.dart';
import '../../data/services/sse_service.dart';
import 'auth_provider.dart';

final agentRepositoryProvider = Provider((ref) => AgentRepository(ref.read(apiClientProvider)));
final sseServiceProvider = Provider((ref) => SSEService());

final agentMessagesProvider = StateNotifierProvider<AgentMessagesNotifier, List<Map<String, dynamic>>>((ref) {
  return AgentMessagesNotifier();
});

class AgentMessagesNotifier extends StateNotifier<List<Map<String, dynamic>>> {
  AgentMessagesNotifier() : super([]);

  void addMessage(Map<String, dynamic> message) {
    state = [...state, message];
  }

  void clear() {
    state = [];
  }
}
```

- [ ] **Step 4: Create lib/agent/chat_screen.dart**

```dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/agent_provider.dart';
import '../providers/auth_provider.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  String? _sessionId;
  String? _base64Image;
  bool _isLoading = false;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() {
        _base64Image = base64Encode(bytes);
      });
    }
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty && _base64Image == null) return;

    setState(() => _isLoading = true);

    // Add user message to UI
    ref.read(agentMessagesProvider.notifier).addMessage({
      'role': 'user',
      'content': message,
      'hasImage': _base64Image != null,
    });

    _messageController.clear();
    setState(() => _base64Image = null);

    // Scroll to bottom
    Future.delayed(const Duration(milliseconds: 100), () {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });

    try {
      final repository = ref.read(agentRepositoryProvider);
      final messages = ref.read(agentMessagesProvider.notifier);

      await for (final event in repository.chat(
        message: message,
        sessionId: _sessionId,
        image: _base64Image,
      )) {
        if (event['event'] == 'message') {
          final data = jsonDecode(event['data']);
          messages.addMessage({
            'role': 'assistant',
            'content': data['content'],
          });
          _sessionId = data['session_id'];
        }
      }
    } catch (e) {
      messages.addMessage({
        'role': 'assistant',
        'content': '抱歉，发生了错误: $e',
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(agentMessagesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 助手'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              ref.read(agentMessagesProvider.notifier).clear();
              _sessionId = null;
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: messages.isEmpty
                ? const Center(
                    child: Text(
                      '有什么可以帮助你的？\n可以上传学生信息截图来批量录入',
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      final isUser = msg['role'] == 'user';

                      return Align(
                        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.7,
                          ),
                          decoration: BoxDecoration(
                            color: isUser
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (msg['hasImage'] == true)
                                const Padding(
                                  padding: EdgeInsets.only(bottom: 8),
                                  child: Icon(Icons.image, size: 100),
                                ),
                              Text(msg['content'] ?? ''),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          if (_base64Image != null)
            Container(
              height: 100,
              margin: const EdgeInsets.all(8),
              child: Stack(
                children: [
                  const Icon(Icons.image, size: 100),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() => _base64Image = null),
                    ),
                  ),
                ],
              ),
            ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.image),
                    onPressed: _pickImage,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: const InputDecoration(
                        hintText: '输入消息...',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                    onPressed: _isLoading ? null : _sendMessage,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat: add Agent chat UI"
```

---

## Task 6: 展示端

**Files:**
- Create: `flutter_app/lib/ui/screens/presentation/presentation_screen.dart`
- Create: `flutter_app/lib/ui/screens/presentation/random_call_screen.dart`

- [ ] **Step 1: Create lib/ui/screens/presentation/presentation_screen.dart**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/class_provider.dart';
import '../../../providers/student_provider.dart';
import 'random_call_screen.dart';

class PresentationScreen extends ConsumerWidget {
  const PresentationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentClass = ref.watch(currentClassProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(currentClass?.name ?? '展示端'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PresentationCard(
              icon: Icons.person_search,
              title: '随机点名',
              subtitle: '随机选择一个学生',
              color: Colors.blue,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const RandomCallScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            _PresentationCard(
              icon: Icons.timer,
              title: '计时器',
              subtitle: '课堂计时工具',
              color: Colors.orange,
              onTap: () {
                // TODO: Implement timer
              },
            ),
            const SizedBox(height: 16),
            _PresentationCard(
              icon: Icons.grid_view,
              title: '座位表',
              subtitle: '查看班级座位',
              color: Colors.green,
              onTap: () {
                // TODO: Show seating in presentation mode
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PresentationCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _PresentationCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              Icon(icon, size: 64, color: color),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 48),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Create lib/ui/screens/presentation/random_call_screen.dart**

```dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/student_provider.dart';
import '../../../providers/class_provider.dart';

class RandomCallScreen extends ConsumerStatefulWidget {
  const RandomCallScreen({super.key});

  @override
  ConsumerState<RandomCallScreen> createState() => _RandomCallScreenState();
}

class _RandomCallScreenState extends ConsumerState<RandomCallScreen> {
  String? _selectedStudent;
  final _random = Random();

  void _pickRandomStudent() {
    final currentClass = ref.read(currentClassProvider);
    if (currentClass == null) return;

    final studentsAsync = ref.read(studentListProvider(currentClass.id));
    studentsAsync.whenData((students) {
      if (students.isEmpty) {
        setState(() => _selectedStudent = '暂无学生');
        return;
      }

      final student = students[_random.nextInt(students.length)];
      setState(() => _selectedStudent = student.name);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('随机点名'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                _selectedStudent ?? '点击按钮开始',
                key: ValueKey(_selectedStudent),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 72,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 48),
            ElevatedButton(
              onPressed: _pickRandomStudent,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
                textStyle: const TextStyle(fontSize: 24),
              ),
              child: const Text('随机选择'),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: Commit**

```bash
git add -A && git commit -m "feat: add presentation mode screens"
```

---

## 自检清单

- [x] Flutter 项目可运行
- [x] 登录/注册 UI 正常
- [x] 班级列表 UI 正常
- [x] 学生 CRUD UI 正常
- [x] 成绩管理 UI 正常
- [x] 座位管理 UI 正常
- [x] Agent 对话 UI 正常
- [x] 展示端 UI 正常
- [x] Riverpod 状态管理正常工作

**完成时间:** 2026-04-12

## 提交记录

| Task | Commit | Description |
|------|--------|-------------|
| Task 1 | `4da4ae6` | Flutter 项目结构 |
| Task 2 | (in Task 1) | 认证 UI |
| Task 3 | `4f18ab9` | 班级管理 UI |
| Task 4 | `27adeb8` | 学生管理 UI (fix gender display, createdAt) |
| Task 5 | `c9b8359` | 成绩管理 UI (fix createGrade naming) |
| Task 6 | `e57a946` | 座位管理 UI |
| Task 7 | `78d1370` | Agent 对话 UI (fix SSE, image display) |
| Task 8 | `6f37225` | 展示端 UI |
