import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DBHelper {
  DBHelper._privateConstructor();
  static final DBHelper instance = DBHelper._privateConstructor();

  static Database? _db;

  Future<Database> get db async => _db ??= await _init();

  Future<void> initDB() async {
    _db ??= await _init();
  }

  Future<Database> _init() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'indoor_navigation.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        // table for future wifi scans
        await db.execute('''
          CREATE TABLE wifi_scans (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            ssid TEXT,
            bssid TEXT,
            rssi INTEGER,
            timestamp INTEGER
          )
        ''');
      },
    );
  }

  Future<int> insertWifiScan(Map<String, dynamic> row) async {
    final database = await db;
    return await database.insert('wifi_scans', row);
  }

  Future<List<Map<String, dynamic>>> getWifiScans() async {
    final database = await db;
    return await database.query('wifi_scans', orderBy: 'timestamp DESC');
  }
}
