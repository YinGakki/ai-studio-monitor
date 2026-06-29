import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

const _kDbName = 'monitor.db';

/// SQLite 数据库助手 - 对应原 db.py
class DatabaseHelper {
  static Database? _db;

  static Future<Database> get() async {
    if (_db != null) return _db!;
    final dbPath = await getDatabasesPath();
    _db = await openDatabase(
      p.join(dbPath, _kDbName),
      version: 1,
      onCreate: (db, v) async {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS accounts (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT UNIQUE,
            profile_dir TEXT,
            proxy TEXT DEFAULT '',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS projects (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            account_name TEXT,
            name TEXT,
            url TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS usage_history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            account_name TEXT,
            project_name TEXT,
            usage_data TEXT,
            check_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP
          )
        ''');
      },
    );
    return _db!;
  }

  // ---- 账号 ----
  static Future<void> addAccount(String name, String profileDir) async {
    final db = await get();
    await db.insert(
      'accounts',
      {'name': name, 'profile_dir': profileDir},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  static Future<List<Map<String, dynamic>>> getAllAccounts() async {
    final db = await get();
    return db.query('accounts', orderBy: 'created_at');
  }

  static Future<void> deleteAccount(String name) async {
    final db = await get();
    await db.delete('usage_history', where: 'account_name = ?', whereArgs: [name]);
    await db.delete('projects', where: 'account_name = ?', whereArgs: [name]);
    await db.delete('accounts', where: 'name = ?', whereArgs: [name]);
  }

  // ---- 项目 ----
  static Future<void> addProject(String accountName, String name, String url) async {
    final db = await get();
    final exist = await db.query('projects',
        where: 'account_name = ? AND url = ?', whereArgs: [accountName, url]);
    if (exist.isNotEmpty) return;
    await db.insert('projects',
        {'account_name': accountName, 'name': name, 'url': url});
  }

  static Future<List<Map<String, dynamic>>> getProjects(String accountName) async {
    final db = await get();
    return db.query('projects',
        where: 'account_name = ?', whereArgs: [accountName], orderBy: 'created_at');
  }

  static Future<List<Map<String, dynamic>>> getAllProjects() async {
    final db = await get();
    return db.query('projects', orderBy: 'account_name, created_at');
  }

  static Future<void> deleteProject(int id) async {
    final db = await get();
    final rows = await db.query('projects', where: 'id = ?', whereArgs: [id]);
    if (rows.isNotEmpty) {
      final acc = rows.first['account_name'] as String;
      final pname = rows.first['name'] as String;
      await db.delete('usage_history',
          where: 'account_name = ? AND project_name = ?',
          whereArgs: [acc, pname]);
    }
    await db.delete('projects', where: 'id = ?', whereArgs: [id]);
  }

  // ---- 用量 ----
  static Future<void> saveUsage(
      String accountName, String projectName, String usageData) async {
    final db = await get();
    final now = DateTime.now().toIso8601String().substring(0, 19).replaceAll('T', ' ');
    await db.insert('usage_history', {
      'account_name': accountName,
      'project_name': projectName,
      'usage_data': usageData,
      'check_time': now,
    });
  }

  static Future<List<Map<String, dynamic>>> getAllLatestUsage() async {
    final db = await get();
    return db.rawQuery('''
      SELECT uh.account_name, uh.project_name, uh.usage_data, uh.check_time
      FROM usage_history uh
      INNER JOIN (
        SELECT account_name, project_name, MAX(check_time) as max_time
        FROM usage_history
        GROUP BY account_name, project_name
      ) latest ON uh.account_name = latest.account_name
               AND uh.project_name = latest.project_name
               AND uh.check_time = latest.max_time
      ORDER BY uh.account_name, uh.project_name
    ''');
  }
}
