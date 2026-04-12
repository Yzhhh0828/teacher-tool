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
