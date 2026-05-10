class Student {
  final int id;
  final int classId;
  final String name;
  final String gender;
  final String? phone;
  final String? parentPhone;
  final String? remarks;
  final DateTime createdAt;

  // Extended fields
  final String? studentNo;
  final String? birthday;
  final String? parentName;
  final String? address;
  final String? homePhone;
  final String? hobbies;
  final String? health;
  final String? emergencyContact;
  final String? description;

  Student({
    required this.id,
    required this.classId,
    required this.name,
    required this.gender,
    this.phone,
    this.parentPhone,
    this.remarks,
    required this.createdAt,
    this.studentNo,
    this.birthday,
    this.parentName,
    this.address,
    this.homePhone,
    this.hobbies,
    this.health,
    this.emergencyContact,
    this.description,
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
      studentNo: json['student_no'],
      birthday: json['birthday'],
      parentName: json['parent_name'],
      address: json['address'],
      homePhone: json['home_phone'],
      hobbies: json['hobbies'],
      health: json['health'],
      emergencyContact: json['emergency_contact'],
      description: json['description'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'gender': gender,
      if (phone != null) 'phone': phone,
      if (parentPhone != null) 'parent_phone': parentPhone,
      if (remarks != null) 'remarks': remarks,
      if (studentNo != null) 'student_no': studentNo,
      if (birthday != null) 'birthday': birthday,
      if (parentName != null) 'parent_name': parentName,
      if (address != null) 'address': address,
      if (homePhone != null) 'home_phone': homePhone,
      if (hobbies != null) 'hobbies': hobbies,
      if (health != null) 'health': health,
      if (emergencyContact != null) 'emergency_contact': emergencyContact,
      if (description != null) 'description': description,
    };
  }
}
