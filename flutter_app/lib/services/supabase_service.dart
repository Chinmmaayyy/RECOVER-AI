import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static SupabaseClient get client => Supabase.instance.client;

  // ---- Patient ----

  static Future<Map<String, dynamic>?> getPatientProfile(String patientId) async {
    final response = await client
        .from('patients')
        .select('*, doctor:doctors(*), caregiver:caregivers(*)')
        .eq('id', patientId)
        .single();
    return response;
  }

  static Future<List<Map<String, dynamic>>> getCheckIns(String patientId, {int limit = 7}) async {
    final response = await client
        .from('check_ins')
        .select()
        .eq('patient_id', patientId)
        .order('timestamp', ascending: false)
        .limit(limit);
    return List<Map<String, dynamic>>.from(response);
  }

  static Future<void> submitCheckIn({
    required String patientId,
    required String transcript,
    required Map<String, dynamic> symptomJson,
    required String triageStatus,
  }) async {
    await client.from('check_ins').insert({
      'patient_id': patientId,
      'transcript': transcript,
      'symptom_json': symptomJson,
      'triage_status': triageStatus,
    });
  }

  // ---- BP Readings ----

  static Future<void> submitBPReading({
    required String patientId,
    required int systolic,
    required int diastolic,
    String? photoRef,
  }) async {
    await client.from('bp_readings').insert({
      'patient_id': patientId,
      'systolic': systolic,
      'diastolic': diastolic,
      'photo_ref': photoRef,
    });
  }

  static Future<List<Map<String, dynamic>>> getBPReadings(String patientId, {int limit = 7}) async {
    final response = await client
        .from('bp_readings')
        .select()
        .eq('patient_id', patientId)
        .order('timestamp', ascending: false)
        .limit(limit);
    return List<Map<String, dynamic>>.from(response);
  }

  // ---- Alerts ----

  static Future<void> createAlert({
    required String patientId,
    required String alertType,
    required String triggerReason,
    required String triageStatus,
  }) async {
    await client.from('alerts').insert({
      'patient_id': patientId,
      'alert_type': alertType,
      'trigger_reason': triggerReason,
      'triage_status': triageStatus,
    });
  }

  static Future<List<Map<String, dynamic>>> getAlerts(String patientId) async {
    final response = await client
        .from('alerts')
        .select()
        .eq('patient_id', patientId)
        .order('timestamp', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  // ---- Medications ----

  static Future<List<Map<String, dynamic>>> getMedications(String patientId) async {
    final response = await client
        .from('medications')
        .select()
        .eq('patient_id', patientId);
    return List<Map<String, dynamic>>.from(response);
  }

  /// Fetch doctor-written prescriptions for this patient
  static Future<List<Map<String, dynamic>>> getPrescriptions(String patientId) async {
    try {
      final response = await client
          .from('prescriptions')
          .select()
          .eq('patient_id', patientId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (_) {
      return []; // table may not exist yet
    }
  }

  static Future<void> verifyMedication({
    required String patientId,
    required String medicationId,
    required String method,
  }) async {
    await client.from('med_verification_log').insert({
      'patient_id': patientId,
      'medication_id': medicationId,
      'method': method,
    });
  }

  // ---- Appointments ----

  static Future<Map<String, dynamic>?> getNextAppointment(String patientId) async {
    final response = await client
        .from('appointments')
        .select('*, doctor:doctors(*)')
        .eq('patient_id', patientId)
        .gte('scheduled_at', DateTime.now().toIso8601String())
        .order('scheduled_at')
        .limit(1);
    final list = List<Map<String, dynamic>>.from(response);
    return list.isNotEmpty ? list.first : null;
  }

  // ---- Doctor Dashboard ----

  static Future<List<Map<String, dynamic>>> getDoctorPatients(String doctorEmail) async {
    final doctor = await client
        .from('doctors')
        .select('id')
        .eq('email', doctorEmail)
        .single();

    final response = await client
        .from('patients')
        .select('*, check_ins(*), bp_readings(*), alerts(*)')
        .eq('doctor_id', doctor['id'])
        .order('created_at');
    return List<Map<String, dynamic>>.from(response);
  }

  // ---- Streak ----

  static Future<void> incrementStreak(String patientId) async {
    try {
      await client.rpc('increment_streak', params: {'patient_id_input': patientId});
    } catch (_) {
      // RPC may not exist — fallback to manual increment
      final patient = await client.from('patients').select('streak_score').eq('id', patientId).single();
      final current = (patient['streak_score'] as int?) ?? 0;
      await client.from('patients').update({'streak_score': current + 1}).eq('id', patientId);
    }
  }

  static Future<void> updateStreak(String patientId, int score) async {
    await client.from('patients').update({'streak_score': score}).eq('id', patientId);
  }

  // ---- Real-time subscriptions ----

  static RealtimeChannel subscribeToCheckIns(String patientId, void Function(Map<String, dynamic>) onData) {
    return client
        .channel('check_ins_$patientId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'check_ins',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'patient_id', value: patientId),
          callback: (payload) => onData(payload.newRecord),
        )
        .subscribe();
  }

  static RealtimeChannel subscribeToAlerts(String patientId, void Function(Map<String, dynamic>) onData) {
    return client
        .channel('alerts_$patientId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'alerts',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'patient_id', value: patientId),
          callback: (payload) => onData(payload.newRecord),
        )
        .subscribe();
  }
}
