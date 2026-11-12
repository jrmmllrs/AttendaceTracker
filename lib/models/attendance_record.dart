class AttendanceRecord {
  final int? id;
  final String shiftDate;
  final DateTime timeIn;
  final DateTime timeOut;
  final int breakMinutes;
  final String notes;
  final String? createdAt;
  final String? updatedAt;

  const AttendanceRecord({
    this.id,
    required this.shiftDate,
    required this.timeIn,
    required this.timeOut,
    this.breakMinutes = 0,
    this.notes = '',
    this.createdAt,
    this.updatedAt,
  });

  Duration get grossDuration => timeOut.difference(timeIn);

  Duration get netDuration {
    return grossDuration - Duration(minutes: breakMinutes);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'shift_date': shiftDate,
      'time_in': timeIn.toIso8601String(),
      'time_out': timeOut.toIso8601String(),
      'break_minutes': breakMinutes,
      'notes': notes,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory AttendanceRecord.fromMap(Map<String, dynamic> map) {
    return AttendanceRecord(
      id: map['id'] as int,
      shiftDate: map['shift_date'] as String,
      timeIn: DateTime.parse(map['time_in'] as String),
      timeOut: DateTime.parse(map['time_out'] as String),
      breakMinutes: map['break_minutes'] as int? ?? 0,
      notes: map['notes'] as String? ?? '',
      createdAt: map['created_at'] as String?,
      updatedAt: map['updated_at'] as String?,
    );
  }
}
