class Exam {
  final int id;
  final int classId;
  final String name;
  final DateTime date;
  final DateTime createdAt;

  Exam({
    required this.id,
    required this.classId,
    required this.name,
    required this.date,
    required this.createdAt,
  });

  factory Exam.fromJson(Map<String, dynamic> json) {
    return Exam(
      id: json['id'],
      classId: json['class_id'],
      name: json['name'],
      date: DateTime.parse(json['date']),
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'date': date.toIso8601String(),
    };
  }
}

class Grade {
  final int id;
  final int examId;
  final int studentId;
  final String subject;
  final double score;
  final String? remarks;
  final DateTime createdAt;
  // For UI display
  final String? studentName;

  Grade({
    required this.id,
    required this.examId,
    required this.studentId,
    required this.subject,
    required this.score,
    this.remarks,
    required this.createdAt,
    this.studentName,
  });

  factory Grade.fromJson(Map<String, dynamic> json) {
    return Grade(
      id: json['id'],
      examId: json['exam_id'],
      studentId: json['student_id'],
      subject: json['subject'],
      score: (json['score'] as num).toDouble(),
      remarks: json['remarks'],
      createdAt: DateTime.parse(json['created_at']),
      studentName: json['student_name'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'student_id': studentId,
      'subject': subject,
      'score': score,
      'remarks': remarks,
    };
  }
}
