import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:url_launcher/url_launcher.dart';
import 'triage_service.dart';

class OfflineService {
  static Database? _db;
  static const _secureStorage = FlutterSecureStorage();

  static Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  static Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'recoverai_offline.db');

    return openDatabase(path, version: 1, onCreate: (db, version) async {
      await db.execute('''
        CREATE TABLE patient_cache (
          id TEXT PRIMARY KEY,
          data TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE checkin_cache (
          id TEXT PRIMARY KEY,
          patient_id TEXT NOT NULL,
          transcript TEXT,
          symptom_json TEXT,
          triage_status TEXT,
          timestamp TEXT NOT NULL,
          synced INTEGER DEFAULT 0
        )
      ''');
    });
  }

  /// Cache patient profile locally
  static Future<void> cachePatientProfile(String patientId, Map<String, dynamic> data) async {
    final db = await database;
    await db.insert(
      'patient_cache',
      {
        'id': patientId,
        'data': jsonEncode(data),
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get cached patient profile
  static Future<Map<String, dynamic>?> getCachedProfile(String patientId) async {
    final db = await database;
    final result = await db.query('patient_cache', where: 'id = ?', whereArgs: [patientId]);
    if (result.isEmpty) return null;
    return jsonDecode(result.first['data'] as String) as Map<String, dynamic>;
  }

  /// Cache a check-in locally (for offline submission)
  static Future<void> cacheCheckIn({
    required String patientId,
    required String transcript,
    required Map<String, dynamic> symptomJson,
    required String triageStatus,
  }) async {
    final db = await database;
    await db.insert('checkin_cache', {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'patient_id': patientId,
      'transcript': transcript,
      'symptom_json': jsonEncode(symptomJson),
      'triage_status': triageStatus,
      'timestamp': DateTime.now().toIso8601String(),
      'synced': 0,
    });
  }

  /// Get unsynced check-ins for batch upload when online
  static Future<List<Map<String, dynamic>>> getUnsyncedCheckIns() async {
    final db = await database;
    return db.query('checkin_cache', where: 'synced = 0');
  }

  /// Mark check-ins as synced
  static Future<void> markSynced(String id) async {
    final db = await database;
    await db.update('checkin_cache', {'synced': 1}, where: 'id = ?', whereArgs: [id]);
  }

  /// Get recent cached check-ins for offline triage
  static Future<List<Map<String, dynamic>>> getRecentCachedCheckIns(String patientId, {int limit = 3}) async {
    final db = await database;
    return db.query(
      'checkin_cache',
      where: 'patient_id = ?',
      whereArgs: [patientId],
      orderBy: 'timestamp DESC',
      limit: limit,
    );
  }

  /// Offline Red Alert — send SMS via device
  static Future<void> sendEmergencySMS({
    required String caregiverPhone,
    required String patientName,
    required String reason,
  }) async {
    final message = 'URGENT: $patientName\'s RecoverAI has flagged a critical symptom: $reason. Please check in immediately.';
    final uri = Uri(scheme: 'sms', path: caregiverPhone, queryParameters: {'body': message});
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  /// Run full offline triage flow
  static Future<TriageResult> offlineTriage({
    required String patientId,
    required String transcript,
    String? caregiverPhone,
    String? patientName,
  }) async {
    // Extract symptoms using regex fallback (no network needed)
    final symptomJson = TriageService.regexFallbackNLP(transcript);

    // Get recent cached history
    final recentHistory = await getRecentCachedCheckIns(patientId);

    // Run triage
    final result = TriageService.evaluate(
      symptomJson: symptomJson,
      recentHistory: recentHistory,
    );

    // Cache the check-in
    await cacheCheckIn(
      patientId: patientId,
      transcript: transcript,
      symptomJson: symptomJson,
      triageStatus: result.status,
    );

    // If RED and offline — trigger SMS via device
    if (result.status == 'red' && caregiverPhone != null && patientName != null) {
      await sendEmergencySMS(
        caregiverPhone: caregiverPhone,
        patientName: patientName,
        reason: result.reason,
      );
    }

    return result;
  }

  /// Store encrypted sensitive data
  static Future<void> storeSecure(String key, String value) async {
    await _secureStorage.write(key: key, value: value);
  }

  static Future<String?> readSecure(String key) async {
    return _secureStorage.read(key: key);
  }
}
