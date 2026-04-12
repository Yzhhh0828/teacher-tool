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
