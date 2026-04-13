class ScheduleModel {
  final int id;
  final int classId;
  final int dayOfWeek;
  final int period;
  final String subject;
  final String? teacherName;
  final String? classroom;

  ScheduleModel({
    required this.id,
    required this.classId,
    required this.dayOfWeek,
    required this.period,
    required this.subject,
    this.teacherName,
    this.classroom,
  });

  factory ScheduleModel.fromJson(Map<String, dynamic> json) {
    return ScheduleModel(
      id: json['id'],
      classId: json['class_id'],
      dayOfWeek: json['day_of_week'],
      period: json['period'],
      subject: json['subject'],
      teacherName: json['teacher_name'],
      classroom: json['classroom'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'class_id': classId,
      'day_of_week': dayOfWeek,
      'period': period,
      'subject': subject,
      'teacher_name': teacherName,
      'classroom': classroom,
    };
  }
}
