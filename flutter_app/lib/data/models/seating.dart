class SeatingModel {
  final int id;
  final int classId;
  final int rows;
  final int cols;
  final List<List<int?>> seats; // 2D array of student IDs (null = empty)
  final DateTime updatedAt;

  SeatingModel({
    required this.id,
    required this.classId,
    required this.rows,
    required this.cols,
    required this.seats,
    required this.updatedAt,
  });

  factory SeatingModel.fromJson(Map<String, dynamic> json) {
    // Parse seats from JSON - could be List<dynamic> of lists
    final seatsData = json['seats'] as List<dynamic>;
    final seats = seatsData.map((row) {
      return (row as List<dynamic>).map((id) => id as int?).toList();
    }).toList();

    return SeatingModel(
      id: json['id'],
      classId: json['class_id'],
      rows: json['rows'],
      cols: json['cols'],
      seats: seats,
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  SeatingModel copyWith({
    int? rows,
    int? cols,
    List<List<int?>>? seats,
  }) {
    return SeatingModel(
      id: id,
      classId: classId,
      rows: rows ?? this.rows,
      cols: cols ?? this.cols,
      seats: seats ?? this.seats,
      updatedAt: updatedAt,
    );
  }
}
