/// RecoverAI Triage Engine — Dart implementation
/// Deterministic, rule-based classification: green | yellow | red

class TriageResult {
  final String status; // 'green' | 'yellow' | 'red'
  final String reason;

  TriageResult({required this.status, required this.reason});
}

class TriageService {
  static const List<String> redKeywords = [
    'chest tight', 'shortness of breath', "can't breathe",
    'severe pain', 'dizzy', 'bleeding', 'fainted', 'chest heavy',
    'puffy', 'unconscious', 'not breathing', 'heart racing',
    'severe bleeding', 'collapsed'
  ];

  static const List<String> yellowKeywords = [
    'mild pain', 'nausea', 'tired', 'slight fever', 'sore',
    'headache', 'swelling', 'not sleeping', 'loss of appetite',
    'constipation', 'mild discomfort', 'uncomfortable',
    'not feeling good', 'not feeling well', 'not well',
    'feeling bad', 'feeling sick', 'feeling weak', 'feeling low',
    'not good', 'unwell', 'a little pain', 'slight pain',
    'don\'t feel good', 'don\'t feel well', 'body ache',
    'no energy', 'fatigue', 'restless', 'can\'t sleep',
    'stomach ache', 'vomiting', 'cough', 'cold',
    'fever', 'weakness', 'pain', 'burning', 'itching',
  ];

  /// Core triage function
  static TriageResult evaluate({
    required Map<String, dynamic> symptomJson,
    String transcript = '',
    List<Map<String, dynamic>> recentHistory = const [],
  }) {
    final symptom = (symptomJson['symptom'] ?? '').toString().toLowerCase();
    final systolicBp = symptomJson['systolic_bp'] as int?;
    final medicationsTaken = symptomJson['medications_taken'] as bool?;
    // Check both extracted symptom AND full transcript for keyword matching
    final textToCheck = '$symptom | ${transcript.toLowerCase()}';

    // Rule 1: BP override
    if (systolicBp != null && systolicBp > 150) {
      return TriageResult(status: 'red', reason: 'High BP detected: $systolicBp systolic');
    }

    // Rule 2: Red keywords — check full transcript too
    for (final kw in redKeywords) {
      if (textToCheck.contains(kw)) {
        return TriageResult(status: 'red', reason: 'Red keyword detected: "$kw"');
      }
    }

    // Rule 3: Escalation — 3 consecutive yellows → red
    if (recentHistory.length >= 3) {
      final lastThree = recentHistory.take(3).toList();
      if (lastThree.every((c) => c['triage_status'] == 'yellow')) {
        return TriageResult(status: 'red', reason: 'Escalation: 3 consecutive yellow check-ins');
      }
    }

    // Rule 4: Yellow keywords — check full transcript too
    for (final kw in yellowKeywords) {
      if (textToCheck.contains(kw)) {
        return TriageResult(status: 'yellow', reason: 'Yellow keyword detected: "$kw"');
      }
    }

    // Rule 5: Missed medication
    if (medicationsTaken == false) {
      return TriageResult(status: 'yellow', reason: 'Medication not taken');
    }

    return TriageResult(status: 'green', reason: 'No concerns detected');
  }

  /// Regex fallback NLP — extracts symptoms without AI
  static Map<String, dynamic> regexFallbackNLP(String transcript) {
    final lower = transcript.toLowerCase();

    String severity = 'none';
    String symptom = 'none';
    String mood = 'okay';
    bool? medicationsTaken;

    // Check red keywords first
    for (final kw in redKeywords) {
      if (lower.contains(kw)) {
        symptom = kw;
        severity = 'high';
        break;
      }
    }

    // Then yellow keywords
    if (symptom == 'none') {
      for (final kw in yellowKeywords) {
        if (lower.contains(kw)) {
          symptom = kw;
          severity = 'medium';
          break;
        }
      }
    }

    // Mood detection
    if (RegExp(r'good|great|better|fine|well|happy').hasMatch(lower)) {
      mood = 'good';
    } else if (RegExp(r'bad|terrible|awful|worse|scared|anxious').hasMatch(lower)) {
      mood = 'low';
    } else if (RegExp(r'panic|help|emergency|dying').hasMatch(lower)) {
      mood = 'distressed';
    }

    // Medication detection
    if (RegExp(r'took|taken|had my|medicine|pill|tablet').hasMatch(lower)) {
      medicationsTaken = true;
    }
    if (RegExp(r"forgot|missed|didn't take|no medicine|skipped").hasMatch(lower)) {
      medicationsTaken = false;
    }

    return {
      'symptom': symptom,
      'severity': severity,
      'mood': mood,
      'medications_taken': medicationsTaken,
    };
  }
}
