/**
 * RecoverAI Triage Engine
 * SAFETY: This engine never suggests treatments or diagnoses.
 * It only classifies symptoms for human review.
 */

// ──────────────────────────────────────────────────────────────
// RED = Immediate danger / emergency / critical symptoms
// ──────────────────────────────────────────────────────────────
const RED_KEYWORDS = [
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
const YELLOW_KEYWORDS = [
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
  'drowsy', 'sleepy', "can't stay awake",

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
  'not hungry', "can't eat", 'difficulty eating',
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

/**
 * Core triage function
 * @param {Object} symptomJson - Parsed symptom data
 * @param {string} [transcript] - Raw transcript for direct keyword search
 * @param {Array} recentHistory - Last N check-ins from DB
 * @returns {{ status: string, reason: string }}
 */
function triageCheck(symptomJson, transcript = '', recentHistory = []) {
  const { symptom = '', systolic_bp, medications_taken } = symptomJson;
  const textToCheck = `${symptom.toLowerCase()} | ${transcript.toLowerCase()}`;

  // Rule 1: BP override
  if (systolic_bp && systolic_bp > 150) {
    return { status: 'red', reason: `High BP detected: ${systolic_bp} systolic` };
  }

  // Rule 2: Red keywords — check full transcript
  const matchedRed = RED_KEYWORDS.find(kw => textToCheck.includes(kw));
  if (matchedRed) {
    return { status: 'red', reason: `Critical symptom detected: "${matchedRed}"` };
  }

  // Rule 3: Escalation — 3+ consecutive Yellow → Red
  const recentStatuses = recentHistory.slice(-3).map(c => c.triage_status);
  if (recentStatuses.length >= 3 && recentStatuses.every(s => s === 'yellow')) {
    return { status: 'red', reason: 'Escalation: 3 consecutive yellow check-ins' };
  }

  // Rule 4: Yellow keywords — check full transcript
  const matchedYellow = YELLOW_KEYWORDS.find(kw => textToCheck.includes(kw));
  if (matchedYellow) {
    return { status: 'yellow', reason: `Symptom detected: "${matchedYellow}"` };
  }

  // Rule 5: Missed medication
  if (medications_taken === false) {
    return { status: 'yellow', reason: 'Medication not taken' };
  }

  return { status: 'green', reason: 'No concerns detected' };
}

/**
 * NLP system prompt — used by Gemma-2B or any LLM layer
 */
const NLP_SYSTEM_PROMPT = `You are a data collector only. Your job is to extract structured health data from patient speech.
Never suggest treatments, diagnoses, or medications.
Only ask how the patient feels. Never give medical advice.
Respond only with valid JSON: {"symptom": "", "severity": "", "mood": "", "medications_taken": true/false}

Severity levels: "none", "low", "medium", "high"
Mood levels: "good", "okay", "low", "distressed"`;

/**
 * Regex fallback NLP — extracts symptoms without AI
 */
function regexFallbackNLP(transcript) {
  const lower = transcript.toLowerCase();

  let severity = 'none';
  let symptom = 'none';
  let mood = 'okay';
  let medications_taken = null;

  // Check red keywords first
  for (const kw of RED_KEYWORDS) {
    if (lower.includes(kw)) {
      symptom = kw;
      severity = 'high';
      break;
    }
  }

  // Then yellow keywords
  if (symptom === 'none') {
    for (const kw of YELLOW_KEYWORDS) {
      if (lower.includes(kw)) {
        symptom = kw;
        severity = 'medium';
        break;
      }
    }
  }

  // Mood detection
  if (/good|great|better|fine|well|happy|wonderful|excellent/.test(lower)) mood = 'good';
  else if (/bad|terrible|awful|worse|scared|anxious|worried|sad|depressed/.test(lower)) mood = 'low';
  else if (/panic|help|emergency|dying|suicidal|desperate/.test(lower)) mood = 'distressed';

  // Medication detection
  if (/took|taken|had my|medicine|pill|tablet|meds/.test(lower)) medications_taken = true;
  if (/forgot|missed|didn't take|no medicine|skipped|ran out/.test(lower)) medications_taken = false;

  return { symptom, severity, mood, medications_taken };
}

module.exports = { triageCheck, regexFallbackNLP, NLP_SYSTEM_PROMPT, RED_KEYWORDS, YELLOW_KEYWORDS };
