// SAFETY: This engine never suggests treatments or diagnoses.
// It only classifies symptoms for human review.

/// RecoverAI Triage Engine — Dart implementation
/// Deterministic, rule-based classification: green | yellow | red

class TriageResult {
  final String status; // 'green' | 'yellow' | 'red'
  final String reason;

  TriageResult({required this.status, required this.reason});
}

class TriageService {
  // ──────────────────────────────────────────────────────────────
  // RED = Immediate danger / emergency / critical symptoms
  // ──────────────────────────────────────────────────────────────
  static const List<String> redKeywords = [
    // Cardiac / Chest
    'chest tight', 'chest pain', 'chest heavy', 'chest pressure',
    'chest hurts', 'heart attack', 'heart pain', 'heart racing',
    'heart stopped', 'heart beating fast', 'irregular heartbeat',
    'palpitations',

    // Breathing
    'shortness of breath', "can't breathe", 'cannot breathe',
    'hard to breathe', 'difficulty breathing', 'breathing problem',
    'breathing difficulty', 'breathing trouble', 'trouble breathing',
    'struggling to breathe', 'gasping', 'breathless', 'suffocating',
    'choking', 'not breathing', 'stopped breathing', 'wheezing badly',

    // Critical / Emergency
    'dying', 'i think i am dying', 'i am dying', "i'm dying",
    'going to die', 'help me', 'emergency', 'call ambulance',
    'call 911', 'call doctor now', 'need help now', 'please help',
    'unconscious', 'collapsed', 'fainted', 'passed out', 'blackout',
    'black out', 'lost consciousness', 'seizure', 'convulsion', 'fit',

    // Severe symptoms
    'severe pain', 'extreme pain', 'unbearable pain', 'worst pain',
    'intense pain', 'excruciating', 'agony', 'very painful',
    'severe bleeding', 'heavy bleeding', 'blood everywhere',
    'bleeding a lot', 'bleeding heavily', 'coughing blood',
    'vomiting blood', 'blood in stool', 'blood in urine',

    // Neurological
    'stroke', 'paralysis', 'paralyzed', "can't move", 'cannot move',
    'face drooping', 'slurred speech', "can't speak", 'cannot speak',
    'sudden numbness', 'vision loss', 'sudden blindness',
    'worst headache', 'confusion', 'disoriented',

    // Swelling / Fluid
    'puffy', 'swollen legs', 'swollen feet', 'swollen face',
    'swollen badly', 'legs swelling', 'body swelling',

    // Other critical
    'suicidal', 'want to die', 'kill myself', 'end my life',
    'high fever', 'very high fever', 'fever above 103',
    'allergic reaction', 'anaphylaxis', "can't swallow",
    'severe vomiting', 'continuous vomiting',
    'dizzy', 'very dizzy', 'room spinning', 'vertigo',
    'falling', 'keep falling', 'losing balance',
    'wound infected', 'infection spreading', 'sepsis',
    'not responding', 'unresponsive',
  ];

  // ──────────────────────────────────────────────────────────────
  // YELLOW = Concerning / needs monitoring / mild-to-moderate
  // ──────────────────────────────────────────────────────────────
  static const List<String> yellowKeywords = [
    // General discomfort
    'not feeling good', 'not feeling well', 'not well', 'not good',
    'not great', 'not okay', 'not fine', 'feeling bad', 'feeling sick',
    'feeling weak', 'feeling low', 'feeling off', 'feeling strange',
    'feeling weird', 'feeling terrible', 'feeling awful', 'feeling worse',
    'feeling unwell', "don't feel good", "don't feel well",
    'unwell', 'uncomfortable', 'uneasy', 'not comfortable',
    'something is wrong', 'something wrong', 'not right',
    'not normal', 'worried', 'concerned', 'scared', 'anxious',
    'stressed', 'nervous', 'panicking', 'panic',

    // Pain (mild-moderate)
    'mild pain', 'slight pain', 'a little pain', 'some pain',
    'little bit of pain', 'dull pain', 'aching', 'ache',
    'body ache', 'body pain', 'muscle pain', 'joint pain',
    'back pain', 'neck pain', 'shoulder pain', 'arm pain',
    'leg pain', 'knee pain', 'hip pain', 'stomach pain',
    'abdominal pain', 'stomach ache', 'cramps', 'cramping',
    'stiffness', 'stiff', 'soreness', 'sore', 'tender',
    'hurts', 'hurting', 'painful', 'pain',
    'throbbing', 'sharp pain', 'burning pain', 'pinching',

    // Fatigue / Energy
    'tired', 'exhausted', 'fatigued', 'fatigue', 'no energy',
    'low energy', 'drained', 'lethargic', 'sluggish',
    'weak', 'weakness', 'feeling heavy', 'heavy',
    'drowsy', 'sleepy', 'can\'t stay awake',

    // Sleep
    'not sleeping', "can't sleep", 'cannot sleep', 'insomnia',
    'restless', 'disturbed sleep', 'waking up at night',
    'nightmares', 'poor sleep', 'sleep problems',

    // Digestive
    'nausea', 'nauseous', 'queasy', 'feel like vomiting',
    'vomiting', 'threw up', 'throwing up', 'acid reflux',
    'heartburn', 'indigestion', 'bloating', 'bloated',
    'constipation', 'diarrhea', 'loose motion', 'loose stool',
    'loss of appetite', 'no appetite', 'not eating',
    'not hungry', 'can\'t eat', 'difficulty eating',
    'stomach upset', 'gas', 'acidity',

    // Fever / Temperature
    'fever', 'slight fever', 'mild fever', 'low grade fever',
    'temperature', 'chills', 'shivering', 'sweating',
    'night sweats', 'hot flashes', 'feeling hot', 'feeling cold',

    // Respiratory (mild)
    'cough', 'coughing', 'dry cough', 'wet cough',
    'sore throat', 'throat pain', 'runny nose', 'stuffy nose',
    'congestion', 'nasal', 'sneezing', 'cold',
    'mild breathing issue', 'slightly breathless',

    // Skin
    'rash', 'itching', 'itchy', 'burning', 'irritation',
    'skin problem', 'wound', 'cut', 'bruise', 'swelling',
    'minor swelling', 'redness', 'inflammation',

    // Head
    'headache', 'head pain', 'migraine', 'head hurts',
    'lightheaded', 'light headed', 'foggy', 'brain fog',
    'blurry vision', 'blurred vision', 'eye pain',
    'ear pain', 'ear ache', 'ringing in ears',

    // Mood / Mental
    'depressed', 'sad', 'crying', 'hopeless', 'lonely',
    'irritable', 'angry', 'frustrated', 'mood swings',
    'feeling down', 'feeling blue', 'unhappy', 'miserable',
    'no motivation', 'lost interest',

    // Medication
    'missed medicine', 'forgot medicine', 'forgot medication',
    'skipped medicine', 'skipped dose', 'ran out of medicine',
    'side effect', 'side effects', 'medicine reaction',
    'drug reaction', 'allergic to medicine',

    // General
    'swollen', 'numbness', 'tingling', 'pins and needles',
    'difficulty walking', 'trouble walking', 'limping',
    'difficulty standing', 'balance problem',
    'weight gain', 'weight loss', 'dehydrated', 'thirsty',
    'frequent urination', 'difficulty urinating',
    'not recovering', 'getting worse', 'worse than yesterday',
    'no improvement', 'not improving',
    'discomfort', 'mild discomfort', 'moderate pain',
  ];

  // ──────────────────────────────────────────────────────────────
  // GREEN triggers — positive words that confirm "all good"
  // Used to avoid false yellows when patient says "I'm fine"
  // ──────────────────────────────────────────────────────────────
  static const List<String> _greenPhrases = [
    'feeling good', 'feeling great', 'feeling fine', 'feeling better',
    'feeling wonderful', 'feeling excellent', 'feeling amazing',
    'doing good', 'doing great', 'doing fine', 'doing well',
    'doing better', 'doing okay', 'all good', 'no problem',
    'no issues', 'no complaints', 'no pain', 'no concerns',
    'i am fine', "i'm fine", 'i am good', "i'm good",
    'i am well', "i'm well", 'i am okay', "i'm okay",
    'i feel fine', 'i feel good', 'i feel great',
    'much better', 'recovered', 'improving', 'getting better',
    'everything is fine', 'perfectly fine', 'absolutely fine',
    'took all my medicine', 'took my medicine', 'took my meds',
    'no worries', 'healthy', 'strong', 'normal',
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

    // Rule 2: Red keywords — check full transcript
    for (final kw in redKeywords) {
      if (textToCheck.contains(kw)) {
        return TriageResult(status: 'red', reason: 'Critical symptom detected: "$kw"');
      }
    }

    // Rule 3: Escalation — 3 consecutive yellows → red
    if (recentHistory.length >= 3) {
      final lastThree = recentHistory.take(3).toList();
      if (lastThree.every((c) => c['triage_status'] == 'yellow')) {
        return TriageResult(status: 'red', reason: 'Escalation: 3 consecutive yellow check-ins');
      }
    }

    // Rule 4: Check if patient explicitly says they're fine
    // (avoids false yellow when they say "I feel fine, no pain")
    bool explicitlyGreen = false;
    for (final phrase in _greenPhrases) {
      if (textToCheck.contains(phrase)) {
        explicitlyGreen = true;
        break;
      }
    }

    // Rule 5: Yellow keywords — check full transcript
    for (final kw in yellowKeywords) {
      if (textToCheck.contains(kw)) {
        // If patient said "no pain" or "i'm fine", don't trigger yellow on "pain"
        if (explicitlyGreen && _isNegated(textToCheck, kw)) {
          continue;
        }
        return TriageResult(status: 'yellow', reason: 'Symptom detected: "$kw"');
      }
    }

    // Rule 6: Missed medication
    if (medicationsTaken == false) {
      return TriageResult(status: 'yellow', reason: 'Medication not taken');
    }

    return TriageResult(status: 'green', reason: 'No concerns detected');
  }

  /// Check if a keyword is negated in context (e.g., "no pain", "not hurting")
  static bool _isNegated(String text, String keyword) {
    final negations = ['no $keyword', 'not $keyword', 'without $keyword',
      'don\'t have $keyword', 'no more $keyword', 'zero $keyword'];
    for (final neg in negations) {
      if (text.contains(neg)) return true;
    }
    return false;
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
    if (RegExp(r'good|great|better|fine|well|happy|wonderful|excellent|amazing').hasMatch(lower)) {
      mood = 'good';
    } else if (RegExp(r'bad|terrible|awful|worse|scared|anxious|worried|sad|depressed|miserable').hasMatch(lower)) {
      mood = 'low';
    } else if (RegExp(r'panic|help|emergency|dying|suicidal|desperate').hasMatch(lower)) {
      mood = 'distressed';
    }

    // Medication detection
    if (RegExp(r'took|taken|had my|medicine|pill|tablet|meds').hasMatch(lower)) {
      medicationsTaken = true;
    }
    if (RegExp(r"forgot|missed|didn't take|no medicine|skipped|ran out").hasMatch(lower)) {
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
