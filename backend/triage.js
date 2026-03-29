/**
 * RecoverAI Triage Engine
 * Deterministic, rule-based classification: green | yellow | red
 * AI never makes clinical decisions — only this engine does.
 */

const RED_KEYWORDS = [
  'chest tight', 'shortness of breath', "can't breathe",
  'severe pain', 'dizzy', 'bleeding', 'fainted', 'chest heavy',
  'puffy', 'unconscious', 'not breathing', 'heart racing',
  'severe bleeding', 'collapsed'
];

const YELLOW_KEYWORDS = [
  'mild pain', 'nausea', 'tired', 'slight fever', 'sore',
  'headache', 'swelling', 'not sleeping', 'loss of appetite',
  'constipation', 'mild discomfort'
];

/**
 * Core triage function
 * @param {Object} symptomJson - Parsed symptom data from NLP
 * @param {string} symptomJson.symptom - Symptom description
 * @param {string} symptomJson.severity - "low" | "medium" | "high"
 * @param {number} [symptomJson.systolic_bp] - Optional BP reading
 * @param {boolean} [symptomJson.medications_taken] - Med adherence
 * @param {Array} recentHistory - Last N check-ins from DB
 * @returns {{ status: string, reason: string }}
 */
function triageCheck(symptomJson, recentHistory = []) {
  const { symptom = '', severity, systolic_bp, medications_taken } = symptomJson;
  const symptomLower = symptom.toLowerCase();

  // Rule 1: BP override — always Red if systolic > 150
  if (systolic_bp && systolic_bp > 150) {
    return { status: 'red', reason: `High BP detected: ${systolic_bp} systolic` };
  }

  // Rule 2: Red keywords in symptom string
  const matchedRed = RED_KEYWORDS.find(kw => symptomLower.includes(kw));
  if (matchedRed) {
    return { status: 'red', reason: `Red keyword detected: "${matchedRed}"` };
  }

  // Rule 3: Escalation — 3+ consecutive Yellow check-ins → Red
  const recentStatuses = recentHistory.slice(-3).map(c => c.triage_status);
  if (recentStatuses.length >= 3 && recentStatuses.every(s => s === 'yellow')) {
    return { status: 'red', reason: 'Escalation: 3 consecutive yellow check-ins' };
  }

  // Rule 4: Yellow keywords
  const matchedYellow = YELLOW_KEYWORDS.find(kw => symptomLower.includes(kw));
  if (matchedYellow) {
    return { status: 'yellow', reason: `Yellow keyword detected: "${matchedYellow}"` };
  }

  // Rule 5: Missed medication → Yellow
  if (medications_taken === false) {
    return { status: 'yellow', reason: 'Medication not taken' };
  }

  // Default: Green
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
  if (/good|great|better|fine|well|happy/.test(lower)) mood = 'good';
  else if (/bad|terrible|awful|worse|scared|anxious/.test(lower)) mood = 'low';
  else if (/panic|help|emergency|dying/.test(lower)) mood = 'distressed';

  // Medication detection
  if (/took|taken|had my|medicine|pill|tablet/.test(lower)) medications_taken = true;
  if (/forgot|missed|didn't take|no medicine|skipped/.test(lower)) medications_taken = false;

  return { symptom, severity, mood, medications_taken };
}

module.exports = { triageCheck, regexFallbackNLP, NLP_SYSTEM_PROMPT, RED_KEYWORDS, YELLOW_KEYWORDS };
