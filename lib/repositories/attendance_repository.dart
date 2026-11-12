import 'package:sqflite/sqflite.dart';

import '../database/database_helper.dart';
import '../models/attendance_record.dart';

class AttendanceRepository {
  final DatabaseHelper _helper = DatabaseHelper.instance;

  Future<List<AttendanceRecord>> getAll() async {
    final db = await _helper.database;

    final results = await db.query(
      'attendance_records',
      orderBy: 'shift_date DESC, time_in DESC',
    );

    return results.map(AttendanceRecord.fromMap).toList();
  }

  Future<int> insert(AttendanceRecord record) async {
    final db = await _helper.database;
    final now = DateTime.now().toIso8601String();

    final map = record.toMap()
      ..remove('id')
      ..['created_at'] = now
      ..['updated_at'] = now;

    return db.insert(
      'attendance_records',
      map,
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<int> update(AttendanceRecord record) async {
    final db = await _helper.database;

    final map = record.toMap()
      ..['updated_at'] = DateTime.now().toIso8601String();

    return db.update(
      'attendance_records',
      map,
      where: 'id = ?',
      whereArgs: [record.id],
    );
  }

  Future<int> delete(int id) async {
    final db = await _helper.database;

    return db.delete('attendance_records', where: 'id = ?', whereArgs: [id]);
  }
}
