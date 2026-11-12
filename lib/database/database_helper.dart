import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  DatabaseHelper._();

  static final DatabaseHelper instance = DatabaseHelper._();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;

    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'timetrack.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE attendance_records (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            shift_date TEXT NOT NULL,
            time_in TEXT NOT NULL,
            time_out TEXT NOT NULL,
            break_minutes INTEGER NOT NULL DEFAULT 0,
            notes TEXT NOT NULL DEFAULT '',
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE INDEX idx_attendance_shift_date
          ON attendance_records(shift_date)
        ''');
      },
    );
  }
}
