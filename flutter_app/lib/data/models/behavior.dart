class BehaviorCategory {
  final int id;
  final int classId;
  final String name;
  final String icon;
  final double score;
  final bool isPreset;
  final int sortOrder;

  const BehaviorCategory({
    required this.id,
    required this.classId,
    required this.name,
    required this.icon,
    required this.score,
    required this.isPreset,
    required this.sortOrder,
  });

  factory BehaviorCategory.fromJson(Map<String, dynamic> json) {
    return BehaviorCategory(
      id: json['id'],
      classId: json['class_id'],
      name: json['name'],
      icon: json['icon'] ?? 'star',
      score: (json['score'] as num).toDouble(),
      isPreset: json['is_preset'] ?? false,
      sortOrder: json['sort_order'] ?? 0,
    );
  }

  bool get isPositive => score > 0;
}


class BehaviorRecord {
  final int id;
  final int classId;
  final int studentId;
  final int categoryId;
  final int userId;
  final double score;
  final String? note;
  final DateTime createdAt;
  final String? categoryName;
  final String? studentName;

  const BehaviorRecord({
    required this.id,
    required this.classId,
    required this.studentId,
    required this.categoryId,
    required this.userId,
    required this.score,
    this.note,
    required this.createdAt,
    this.categoryName,
    this.studentName,
  });

  factory BehaviorRecord.fromJson(Map<String, dynamic> json) {
    return BehaviorRecord(
      id: json['id'],
      classId: json['class_id'],
      studentId: json['student_id'],
      categoryId: json['category_id'],
      userId: json['user_id'],
      score: (json['score'] as num).toDouble(),
      note: json['note'],
      createdAt: DateTime.parse(json['created_at']),
      categoryName: json['category_name'],
      studentName: json['student_name'],
    );
  }
}


class StudentScore {
  final int studentId;
  final String studentName;
  final double totalScore;
  final int recordCount;

  const StudentScore({
    required this.studentId,
    required this.studentName,
    required this.totalScore,
    required this.recordCount,
  });

  factory StudentScore.fromJson(Map<String, dynamic> json) {
    return StudentScore(
      studentId: json['student_id'],
      studentName: json['student_name'],
      totalScore: (json['total_score'] as num).toDouble(),
      recordCount: json['record_count'],
    );
  }
}
