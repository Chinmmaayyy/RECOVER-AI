import React, { useState, useEffect } from 'react';
import { BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, LineChart, Line, ReferenceLine } from 'recharts';
import { getPatientPrescriptions, addPrescription, getDoctorNotes, addDoctorNote } from '../services/supabase';

const DEMO_DOCTOR_ID = 'd1000000-0000-0000-0000-000000000aa1';

function PatientDetail({ patient }) {
  const checkIns = [...(patient.check_ins || [])].sort((a, b) => new Date(a.timestamp) - new Date(b.timestamp));
  const bpReadings = [...(patient.bp_readings || [])].sort((a, b) => new Date(a.timestamp) - new Date(b.timestamp));
  const medications = patient.medications || [];
  const alerts = patient.alerts || [];

  const [activeTab, setActiveTab] = useState('overview');
  const [prescriptions, setPrescriptions] = useState([]);
  const [doctorNotes, setDoctorNotes] = useState([]);

  // Prescription form
  const [showRxForm, setShowRxForm] = useState(false);
  const [rxMed, setRxMed] = useState('');
  const [rxDosage, setRxDosage] = useState('');
  const [rxFreq, setRxFreq] = useState('Once daily');
  const [rxDuration, setRxDuration] = useState('');
  const [rxNotes, setRxNotes] = useState('');
  const [savingRx, setSavingRx] = useState(false);

  // Doctor note form
  const [showNoteForm, setShowNoteForm] = useState(false);
  const [noteText, setNoteText] = useState('');
  const [noteType, setNoteType] = useState('observation');
  const [savingNote, setSavingNote] = useState(false);

  useEffect(() => { loadExtras(); }, [patient.id]);

  const loadExtras = async () => {
    const [rxData, notesData] = await Promise.all([
      getPatientPrescriptions(patient.id),
      getDoctorNotes(patient.id),
    ]);
    setPrescriptions(rxData);
    setDoctorNotes(notesData);
  };

  const handleAddRx = async () => {
    if (!rxMed || !rxDosage) return;
    setSavingRx(true);
    try {
      await addPrescription({ patientId: patient.id, doctorId: DEMO_DOCTOR_ID, medication: rxMed, dosage: rxDosage, frequency: rxFreq, duration: rxDuration, notes: rxNotes });
      setShowRxForm(false); setRxMed(''); setRxDosage(''); setRxFreq('Once daily'); setRxDuration(''); setRxNotes('');
      await loadExtras();
    } catch (e) {
      alert('Run this SQL in Supabase first:\n\nCREATE TABLE prescriptions (id uuid DEFAULT gen_random_uuid() PRIMARY KEY, patient_id uuid REFERENCES patients(id), doctor_id uuid, medication text NOT NULL, dosage text, frequency text, duration text, notes text, created_at timestamptz DEFAULT now());\nALTER TABLE prescriptions ENABLE ROW LEVEL SECURITY;\nCREATE POLICY "Allow all" ON prescriptions FOR ALL USING (true);');
    }
    setSavingRx(false);
  };

  const handleAddNote = async () => {
    if (!noteText) return;
    setSavingNote(true);
    try {
      await addDoctorNote({ patientId: patient.id, doctorId: DEMO_DOCTOR_ID, note: noteText, noteType });
      setShowNoteForm(false); setNoteText(''); setNoteType('observation');
      await loadExtras();
    } catch (e) {
      alert('Run this SQL in Supabase first:\n\nCREATE TABLE doctor_notes (id uuid DEFAULT gen_random_uuid() PRIMARY KEY, patient_id uuid REFERENCES patients(id), doctor_id uuid, note text NOT NULL, note_type text DEFAULT \'observation\', created_at timestamptz DEFAULT now());\nALTER TABLE doctor_notes ENABLE ROW LEVEL SECURITY;\nCREATE POLICY "Allow all" ON doctor_notes FOR ALL USING (true);');
    }
    setSavingNote(false);
  };

  const symptomChartData = checkIns.map(ci => ({
    date: new Date(ci.timestamp).toLocaleDateString('en-IN', { day: 'numeric', month: 'short' }),
    severity: severityToNum(ci.symptom_json?.severity),
  }));

  const bpChartData = bpReadings.map(bp => ({
    date: new Date(bp.timestamp).toLocaleDateString('en-IN', { day: 'numeric', month: 'short' }),
    systolic: bp.systolic, diastolic: bp.diastolic,
  }));

  const latestStatus = getLatestStatus(patient);
  const latestBP = bpReadings.length > 0 ? bpReadings[bpReadings.length - 1] : null;
  const redAlerts = alerts.filter(a => a.triage_status === 'red');

  // AI Insights — generated from patient data
  const aiInsights = generateInsights(patient, checkIns, bpReadings, medications);

  const inp = { width: '100%', padding: '9px 12px', borderRadius: 8, border: '1px solid #e2e8f0', fontSize: 13, fontFamily: 'inherit', background: '#f8fafc' };
  const tabBtn = (active) => ({
    padding: '7px 14px', borderRadius: 8, border: 'none', cursor: 'pointer',
    fontSize: 12, fontWeight: 600, fontFamily: 'inherit',
    background: active ? '#0f766e' : '#f1f5f9', color: active ? 'white' : '#64748b',
  });

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>

      {/* ---- HEADER CARD ---- */}
      <div className="card patient-header-card" style={{ padding: 18 }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <div>
            <h2 style={{ fontSize: 20, marginBottom: 2 }}>{patient.name}</h2>
            <div style={{ display: 'flex', gap: 14, fontSize: 13, color: '#64748b', flexWrap: 'wrap' }}>
              <span>{patient.age}y</span>
              <span>{patient.surgery_type || 'N/A'}</span>
              <span>Streak: {patient.streak_score || 0}</span>
              {latestBP && <span style={{ color: latestBP.systolic > 150 ? '#dc2626' : '#64748b' }}>BP: {latestBP.systolic}/{latestBP.diastolic}</span>}
            </div>
          </div>
          <span className={`status-badge ${latestStatus}`} style={{ fontSize: 12, padding: '6px 16px' }}>
            <span style={{ width: 7, height: 7, borderRadius: '50%', background: latestStatus === 'red' ? '#dc2626' : latestStatus === 'yellow' ? '#d97706' : '#16a34a', display: 'inline-block' }} />
            {latestStatus}
          </span>
        </div>

        {/* Quick stat chips */}
        <div style={{ display: 'flex', gap: 8, marginTop: 10, flexWrap: 'wrap' }}>
          <span style={{ padding: '4px 10px', background: 'rgba(15,118,110,0.08)', borderRadius: 6, fontSize: 11, fontWeight: 600, color: '#0f766e' }}>{checkIns.length} check-ins</span>
          <span style={{ padding: '4px 10px', background: 'rgba(59,130,246,0.08)', borderRadius: 6, fontSize: 11, fontWeight: 600, color: '#3b82f6' }}>{bpReadings.length} BP</span>
          {redAlerts.length > 0 && <span style={{ padding: '4px 10px', background: 'rgba(239,68,68,0.08)', borderRadius: 6, fontSize: 11, fontWeight: 600, color: '#dc2626' }}>{redAlerts.length} red</span>}
          <span style={{ padding: '4px 10px', background: 'rgba(245,158,11,0.08)', borderRadius: 6, fontSize: 11, fontWeight: 600, color: '#d97706' }}>{medications.length} meds</span>
          <span style={{ padding: '4px 10px', background: 'rgba(139,92,246,0.08)', borderRadius: 6, fontSize: 11, fontWeight: 600, color: '#7c3aed' }}>{prescriptions.length} Rx</span>
        </div>
      </div>

      {/* ---- TAB BAR ---- */}
      <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap' }}>
        {['overview', 'prescribe', 'notes', 'transcripts'].map(t => (
          <button key={t} style={tabBtn(activeTab === t)} onClick={() => setActiveTab(t)}>
            {t === 'overview' ? 'Overview' : t === 'prescribe' ? 'Prescribe' : t === 'notes' ? 'Notes' : 'Transcripts'}
          </button>
        ))}
      </div>

      {/* ===== OVERVIEW ===== */}
      {activeTab === 'overview' && (
        <>
          {/* AI Insight Card */}
          {aiInsights.length > 0 && (
            <div style={{
              padding: '12px 16px', borderRadius: 12, marginBottom: 4,
              background: latestStatus === 'red' ? '#fef2f2' : latestStatus === 'yellow' ? '#fffbeb' : '#f0fdf4',
              border: `1px solid ${latestStatus === 'red' ? '#fca5a5' : latestStatus === 'yellow' ? '#fde68a' : '#bbf7d0'}`,
            }}>
              <div style={{ fontSize: 10, fontWeight: 700, textTransform: 'uppercase', letterSpacing: '0.5px', color: '#64748b', marginBottom: 6, display: 'flex', alignItems: 'center', gap: 6 }}>
                <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="#64748b" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                  <circle cx="12" cy="12" r="10"/><line x1="12" y1="16" x2="12" y2="12"/><line x1="12" y1="8" x2="12.01" y2="8"/>
                </svg>
                AI Clinical Insights
              </div>
              {aiInsights.map((insight, i) => (
                <div key={i} style={{ fontSize: 13, color: '#334155', lineHeight: 1.5, display: 'flex', gap: 6, marginBottom: i < aiInsights.length - 1 ? 4 : 0 }}>
                  <span>{insight.icon}</span>
                  <span>{insight.text}</span>
                </div>
              ))}
            </div>
          )}

          {/* Charts side by side */}
          <div style={{ display: 'grid', gridTemplateColumns: bpChartData.length > 0 ? '1fr 1fr' : '1fr', gap: 12 }}>
            <div className="card" style={{ padding: 16 }}>
              <h3 style={{ fontSize: 11, marginBottom: 8 }}>7-Day Symptoms</h3>
              <div style={{ height: 160 }}>
                <ResponsiveContainer width="100%" height="100%">
                  <BarChart data={symptomChartData}>
                    <CartesianGrid strokeDasharray="3 3" stroke="#f1f5f9" />
                    <XAxis dataKey="date" tick={{ fontSize: 10, fill: '#94a3b8' }} axisLine={{ stroke: '#e2e8f0' }} />
                    <YAxis domain={[0, 3]} ticks={[0, 1, 2, 3]} tickFormatter={numToSeverity} tick={{ fontSize: 10, fill: '#94a3b8' }} axisLine={{ stroke: '#e2e8f0' }} />
                    <Tooltip formatter={(v) => numToSeverity(v)} contentStyle={{ borderRadius: 8, border: '1px solid #e2e8f0', fontSize: 12 }} />
                    <Bar dataKey="severity" fill="url(#bg2)" radius={[4, 4, 0, 0]} />
                    <defs><linearGradient id="bg2" x1="0" y1="0" x2="0" y2="1"><stop offset="0%" stopColor="#14b8a6" /><stop offset="100%" stopColor="#0f766e" /></linearGradient></defs>
                  </BarChart>
                </ResponsiveContainer>
              </div>
            </div>
            {bpChartData.length > 0 && (
              <div className="card" style={{ padding: 16 }}>
                <h3 style={{ fontSize: 11, marginBottom: 8 }}>Blood Pressure</h3>
                <div style={{ height: 160 }}>
                  <ResponsiveContainer width="100%" height="100%">
                    <LineChart data={bpChartData}>
                      <CartesianGrid strokeDasharray="3 3" stroke="#f1f5f9" />
                      <XAxis dataKey="date" tick={{ fontSize: 10, fill: '#94a3b8' }} axisLine={{ stroke: '#e2e8f0' }} />
                      <YAxis domain={[60, 180]} tick={{ fontSize: 10, fill: '#94a3b8' }} axisLine={{ stroke: '#e2e8f0' }} />
                      <Tooltip contentStyle={{ borderRadius: 8, border: '1px solid #e2e8f0', fontSize: 12 }} />
                      <ReferenceLine y={150} stroke="#ef4444" strokeDasharray="6 4" strokeWidth={1.5} />
                      <Line type="monotone" dataKey="systolic" stroke="#ef4444" strokeWidth={2} dot={{ r: 3 }} name="Sys" />
                      <Line type="monotone" dataKey="diastolic" stroke="#3b82f6" strokeWidth={2} dot={{ r: 3 }} name="Dia" />
                    </LineChart>
                  </ResponsiveContainer>
                </div>
              </div>
            )}
          </div>

          {/* Prescriptions + Medications + Latest Transcripts */}
          {prescriptions.length > 0 && (
            <div className="card" style={{ padding: 16, borderLeft: '4px solid #0f766e' }}>
              <h3 style={{ fontSize: 11, marginBottom: 8, display: 'flex', justifyContent: 'space-between', alignItems: 'center', border: 'none', padding: 0 }}>
                <span>Doctor Prescriptions ({prescriptions.length})</span>
                <button onClick={() => setActiveTab('prescribe')} style={{ fontSize: 11, color: '#0f766e', background: 'none', border: 'none', cursor: 'pointer', fontWeight: 600, fontFamily: 'inherit' }}>View All</button>
              </h3>
              <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
                {prescriptions.slice(0, 4).map(rx => (
                  <div key={rx.id} style={{ padding: '6px 12px', background: '#f0fdfa', borderRadius: 8, border: '1px solid #ccfbf1', fontSize: 12 }}>
                    <span style={{ fontWeight: 600, color: '#0f766e' }}>{rx.medication}</span>
                    <span style={{ color: '#64748b' }}> {rx.dosage} &middot; {rx.frequency}</span>
                  </div>
                ))}
              </div>
            </div>
          )}

          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
            <div className="card" style={{ padding: 16 }}>
              <h3 style={{ fontSize: 11, marginBottom: 8 }}>Pharmacy Medications</h3>
              <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
                {medications.map(m => (
                  <div key={m.id} style={{ display: 'flex', justifyContent: 'space-between', padding: '8px 10px', background: '#f8fafc', borderRadius: 8, border: '1px solid #f1f5f9', fontSize: 13 }}>
                    <span style={{ fontWeight: 600, color: '#1e293b' }}>{m.name}</span>
                    <span style={{ color: '#94a3b8', fontSize: 12 }}>{m.schedule_time}</span>
                  </div>
                ))}
                {medications.length === 0 && <p style={{ fontSize: 12, color: '#94a3b8', textAlign: 'center', padding: 12 }}>None</p>}
              </div>
            </div>
            <div className="card" style={{ padding: 16 }}>
              <h3 style={{ fontSize: 11, marginBottom: 8 }}>Latest Check-Ins</h3>
              <div style={{ display: 'flex', flexDirection: 'column', gap: 6, maxHeight: 200, overflowY: 'auto' }}>
                {[...checkIns].reverse().slice(0, 4).map(ci => (
                  <div key={ci.id} style={{ padding: '8px 10px', background: '#f8fafc', borderRadius: 8, borderLeft: `3px solid ${ci.triage_status === 'red' ? '#ef4444' : ci.triage_status === 'yellow' ? '#f59e0b' : '#22c55e'}`, fontSize: 12 }}>
                    <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 2 }}>
                      <span className={`status-badge ${ci.triage_status}`} style={{ fontSize: 9, padding: '1px 8px' }}>{ci.triage_status}</span>
                      <span style={{ color: '#94a3b8', fontSize: 10 }}>{new Date(ci.timestamp).toLocaleDateString('en-IN', { day: 'numeric', month: 'short' })}</span>
                    </div>
                    <p style={{ color: '#475569', fontStyle: 'italic', lineHeight: 1.4, fontSize: 12 }}>"{(ci.transcript || '').slice(0, 80)}{(ci.transcript || '').length > 80 ? '...' : ''}"</p>
                  </div>
                ))}
                {checkIns.length === 0 && <p style={{ fontSize: 12, color: '#94a3b8', textAlign: 'center', padding: 12 }}>No check-ins</p>}
              </div>
            </div>
          </div>

          {/* Quick action buttons */}
          <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
            <button onClick={() => setActiveTab('prescribe')} style={{ padding: '8px 16px', borderRadius: 8, border: '1px solid #0f766e', background: 'white', color: '#0f766e', fontWeight: 600, fontSize: 12, cursor: 'pointer', fontFamily: 'inherit' }}>
              + Write Prescription
            </button>
            <button onClick={() => setActiveTab('notes')} style={{ padding: '8px 16px', borderRadius: 8, border: '1px solid #3b82f6', background: 'white', color: '#3b82f6', fontWeight: 600, fontSize: 12, cursor: 'pointer', fontFamily: 'inherit' }}>
              + Add Clinical Note
            </button>
            <button onClick={() => setActiveTab('transcripts')} style={{ padding: '8px 16px', borderRadius: 8, border: '1px solid #64748b', background: 'white', color: '#64748b', fontWeight: 600, fontSize: 12, cursor: 'pointer', fontFamily: 'inherit' }}>
              View All Transcripts
            </button>
          </div>
        </>
      )}

      {/* ===== PRESCRIBE ===== */}
      {activeTab === 'prescribe' && (
        <div className="card" style={{ padding: 18 }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 14 }}>
            <h3 style={{ margin: 0, border: 'none', padding: 0 }}>Prescriptions</h3>
            <button onClick={() => setShowRxForm(!showRxForm)} style={{
              padding: '7px 14px', borderRadius: 8, border: 'none', cursor: 'pointer', fontWeight: 600, fontSize: 12, fontFamily: 'inherit',
              background: showRxForm ? '#fee2e2' : '#0f766e', color: showRxForm ? '#dc2626' : 'white',
            }}>
              {showRxForm ? 'Cancel' : '+ New Rx'}
            </button>
          </div>

          {showRxForm && (
            <div style={{ background: '#f0fdfa', borderRadius: 10, padding: 16, marginBottom: 14, border: '1px solid #ccfbf1' }}>
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10 }}>
                <div>
                  <label style={{ fontSize: 11, fontWeight: 600, color: '#475569', display: 'block', marginBottom: 3 }}>Medication *</label>
                  <input value={rxMed} onChange={e => setRxMed(e.target.value)} placeholder="Aspirin" style={inp} />
                </div>
                <div>
                  <label style={{ fontSize: 11, fontWeight: 600, color: '#475569', display: 'block', marginBottom: 3 }}>Dosage *</label>
                  <input value={rxDosage} onChange={e => setRxDosage(e.target.value)} placeholder="75mg" style={inp} />
                </div>
                <div>
                  <label style={{ fontSize: 11, fontWeight: 600, color: '#475569', display: 'block', marginBottom: 3 }}>Frequency</label>
                  <select value={rxFreq} onChange={e => setRxFreq(e.target.value)} style={inp}>
                    <option>Once daily</option><option>Twice daily</option><option>Three times daily</option>
                    <option>Every 8 hours</option><option>As needed (PRN)</option><option>Before meals</option>
                    <option>After meals</option><option>At bedtime</option>
                  </select>
                </div>
                <div>
                  <label style={{ fontSize: 11, fontWeight: 600, color: '#475569', display: 'block', marginBottom: 3 }}>Duration</label>
                  <input value={rxDuration} onChange={e => setRxDuration(e.target.value)} placeholder="30 days" style={inp} />
                </div>
              </div>
              <div style={{ marginTop: 10 }}>
                <label style={{ fontSize: 11, fontWeight: 600, color: '#475569', display: 'block', marginBottom: 3 }}>Notes</label>
                <input value={rxNotes} onChange={e => setRxNotes(e.target.value)} placeholder="Take with food..." style={inp} />
              </div>
              <button onClick={handleAddRx} disabled={savingRx || !rxMed || !rxDosage} style={{
                marginTop: 10, padding: '8px 20px', borderRadius: 8, border: 'none', cursor: 'pointer',
                fontWeight: 600, fontSize: 13, fontFamily: 'inherit',
                background: (!rxMed || !rxDosage) ? '#cbd5e1' : '#0f766e', color: 'white',
              }}>
                {savingRx ? 'Saving...' : 'Save Prescription'}
              </button>
            </div>
          )}

          {/* Rx list in 2-col grid */}
          <div style={{ display: 'grid', gridTemplateColumns: prescriptions.length > 1 ? '1fr 1fr' : '1fr', gap: 10 }}>
            {prescriptions.map(rx => (
              <div key={rx.id} style={{ padding: '12px 14px', background: '#f8fafc', borderRadius: 10, border: '1px solid #e2e8f0', borderLeft: '4px solid #0f766e' }}>
                <div style={{ fontWeight: 700, fontSize: 14, color: '#0f172a' }}>{rx.medication}</div>
                <div style={{ fontSize: 12, color: '#64748b', marginTop: 2 }}>{rx.dosage} &middot; {rx.frequency}</div>
                {rx.duration && <div style={{ fontSize: 11, color: '#94a3b8' }}>{rx.duration}</div>}
                {rx.notes && <div style={{ fontSize: 11, color: '#94a3b8', fontStyle: 'italic', marginTop: 4 }}>{rx.notes}</div>}
                <div style={{ fontSize: 10, color: '#cbd5e1', marginTop: 4 }}>{new Date(rx.created_at).toLocaleDateString('en-IN', { day: 'numeric', month: 'short', year: 'numeric' })}</div>
              </div>
            ))}
          </div>
          {prescriptions.length === 0 && !showRxForm && (
            <p style={{ fontSize: 13, color: '#94a3b8', textAlign: 'center', padding: 24 }}>No prescriptions yet — click "+ New Rx"</p>
          )}

          {/* Current meds reference */}
          {medications.length > 0 && (
            <div style={{ marginTop: 14, padding: 12, background: '#fffbeb', borderRadius: 10, border: '1px solid #fde68a' }}>
              <div style={{ fontSize: 11, fontWeight: 700, color: '#92400e', textTransform: 'uppercase', letterSpacing: '0.5px', marginBottom: 6 }}>Current Pharmacy Meds</div>
              <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
                {medications.map(m => (
                  <span key={m.id} style={{ fontSize: 12, padding: '4px 10px', background: 'white', borderRadius: 6, border: '1px solid #fde68a', color: '#92400e' }}>
                    {m.name} — {m.schedule_time}
                  </span>
                ))}
              </div>
            </div>
          )}
        </div>
      )}

      {/* ===== NOTES ===== */}
      {activeTab === 'notes' && (
        <div className="card" style={{ padding: 18 }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 14 }}>
            <h3 style={{ margin: 0, border: 'none', padding: 0 }}>Doctor Notes</h3>
            <button onClick={() => setShowNoteForm(!showNoteForm)} style={{
              padding: '7px 14px', borderRadius: 8, border: 'none', cursor: 'pointer', fontWeight: 600, fontSize: 12, fontFamily: 'inherit',
              background: showNoteForm ? '#fee2e2' : '#0f766e', color: showNoteForm ? '#dc2626' : 'white',
            }}>
              {showNoteForm ? 'Cancel' : '+ Add Note'}
            </button>
          </div>

          {showNoteForm && (
            <div style={{ background: '#f0fdfa', borderRadius: 10, padding: 16, marginBottom: 14, border: '1px solid #ccfbf1' }}>
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10, marginBottom: 10 }}>
                <div>
                  <label style={{ fontSize: 11, fontWeight: 600, color: '#475569', display: 'block', marginBottom: 3 }}>Type</label>
                  <select value={noteType} onChange={e => setNoteType(e.target.value)} style={inp}>
                    <option value="observation">Observation</option><option value="follow-up">Follow-up Required</option>
                    <option value="concern">Concern</option><option value="improvement">Improvement</option>
                    <option value="instruction">Patient Instruction</option>
                  </select>
                </div>
                <div style={{ display: 'flex', alignItems: 'flex-end' }}>
                  <button onClick={handleAddNote} disabled={savingNote || !noteText} style={{
                    padding: '9px 20px', borderRadius: 8, border: 'none', cursor: 'pointer', width: '100%',
                    fontWeight: 600, fontSize: 13, fontFamily: 'inherit',
                    background: !noteText ? '#cbd5e1' : '#0f766e', color: 'white',
                  }}>
                    {savingNote ? 'Saving...' : 'Save Note'}
                  </button>
                </div>
              </div>
              <textarea value={noteText} onChange={e => setNoteText(e.target.value)} placeholder="Write your clinical note..." rows={3} style={{ ...inp, resize: 'vertical' }} />
            </div>
          )}

          <div style={{ display: 'flex', flexDirection: 'column', gap: 8, maxHeight: 400, overflowY: 'auto' }}>
            {doctorNotes.map(n => {
              const tc = { observation: '#94a3b8', 'follow-up': '#f59e0b', concern: '#ef4444', improvement: '#22c55e', instruction: '#3b82f6' };
              return (
                <div key={n.id} style={{ padding: '12px 14px', background: '#f8fafc', borderRadius: 10, borderLeft: `4px solid ${tc[n.note_type] || '#94a3b8'}` }}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 4 }}>
                    <span style={{ fontSize: 10, fontWeight: 700, textTransform: 'uppercase', color: tc[n.note_type] || '#94a3b8' }}>{n.note_type}</span>
                    <span style={{ fontSize: 10, color: '#cbd5e1' }}>{new Date(n.created_at).toLocaleString('en-IN', { day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' })}</span>
                  </div>
                  <p style={{ fontSize: 13, color: '#334155', lineHeight: 1.5 }}>{n.note}</p>
                </div>
              );
            })}
            {doctorNotes.length === 0 && !showNoteForm && <p style={{ fontSize: 13, color: '#94a3b8', textAlign: 'center', padding: 20 }}>No notes yet</p>}
          </div>
        </div>
      )}

      {/* ===== TRANSCRIPTS ===== */}
      {activeTab === 'transcripts' && (
        <div className="card" style={{ padding: 18 }}>
          <h3>Voice Transcripts ({checkIns.length})</h3>
          <div style={{ display: 'grid', gridTemplateColumns: checkIns.length > 2 ? '1fr 1fr' : '1fr', gap: 10, maxHeight: 500, overflowY: 'auto' }}>
            {[...checkIns].reverse().map(ci => (
              <div key={ci.id} style={{ padding: '10px 12px', background: '#f8fafc', borderRadius: 10, borderLeft: `3px solid ${ci.triage_status === 'red' ? '#ef4444' : ci.triage_status === 'yellow' ? '#f59e0b' : '#22c55e'}` }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 4 }}>
                  <span className={`status-badge ${ci.triage_status}`} style={{ fontSize: 9, padding: '2px 8px' }}>{ci.triage_status}</span>
                  <span style={{ fontSize: 10, color: '#94a3b8' }}>{new Date(ci.timestamp).toLocaleString('en-IN', { day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' })}</span>
                </div>
                <p style={{ fontSize: 12, fontStyle: 'italic', color: '#475569', lineHeight: 1.5 }}>"{ci.transcript}"</p>
                {ci.symptom_json && ci.symptom_json.symptom && ci.symptom_json.symptom !== 'none' && (
                  <span style={{ fontSize: 10, padding: '1px 6px', background: '#fef2f2', borderRadius: 4, color: '#dc2626', marginTop: 4, display: 'inline-block' }}>{ci.symptom_json.symptom}</span>
                )}
              </div>
            ))}
          </div>
          {checkIns.length === 0 && <p style={{ fontSize: 13, color: '#94a3b8', textAlign: 'center', padding: 24 }}>No transcripts</p>}
        </div>
      )}
    </div>
  );
}

function getLatestStatus(p) {
  const c = p.check_ins || [];
  if (!c.length) return 'green';
  return [...c].sort((a, b) => new Date(b.timestamp) - new Date(a.timestamp))[0].triage_status || 'green';
}
function severityToNum(s) { return s === 'high' ? 3 : s === 'medium' ? 2 : s === 'low' ? 1 : 0; }
function numToSeverity(n) { return n === 3 ? 'High' : n === 2 ? 'Medium' : n === 1 ? 'Low' : 'None'; }

function generateInsights(patient, checkIns, bpReadings, medications) {
  const insights = [];
  const sorted = [...checkIns].sort((a, b) => new Date(b.timestamp) - new Date(a.timestamp));

  // BP trend analysis
  if (bpReadings.length >= 2) {
    const recent = bpReadings.slice(-3);
    const avgSys = Math.round(recent.reduce((s, r) => s + r.systolic, 0) / recent.length);
    const first = recent[0].systolic;
    const last = recent[recent.length - 1].systolic;
    if (last > first + 5) {
      insights.push({ icon: '\u26a0\ufe0f', text: `BP trending UP (avg ${avgSys} systolic). Consider medication review.` });
    } else if (last < first - 5) {
      insights.push({ icon: '\u2705', text: `BP trending DOWN (avg ${avgSys} systolic). Positive response to treatment.` });
    } else {
      insights.push({ icon: '\ud83d\udfe2', text: `BP stable (avg ${avgSys} systolic over last ${recent.length} readings).` });
    }
    if (avgSys > 150) {
      insights.push({ icon: '\ud83d\udea8', text: `Avg systolic ${avgSys} exceeds 150 threshold. Auto-alert triggered.` });
    }
  }

  // Check-in pattern
  if (sorted.length >= 3) {
    const lastThree = sorted.slice(0, 3).map(c => c.triage_status);
    if (lastThree.every(s => s === 'green')) {
      insights.push({ icon: '\u2705', text: 'Stable for 3 consecutive check-ins. Recovery on track.' });
    } else if (lastThree.every(s => s === 'yellow')) {
      insights.push({ icon: '\u26a0\ufe0f', text: '3 consecutive yellow flags. Escalation risk — consider follow-up call.' });
    } else if (lastThree.filter(s => s === 'red').length >= 2) {
      insights.push({ icon: '\ud83d\udea8', text: 'Multiple red flags recently. Urgent clinical review recommended.' });
    }
  }

  // Medication adherence
  const withMeds = sorted.filter(c => c.symptom_json?.medications_taken === true).length;
  const adherence = sorted.length > 0 ? Math.round((withMeds / sorted.length) * 100) : 100;
  if (adherence < 70 && sorted.length >= 3) {
    insights.push({ icon: '\ud83d\udc8a', text: `Medication adherence at ${adherence}%. May need caregiver follow-up.` });
  }

  // Streak
  const streak = patient.streak_score || 0;
  if (streak >= 7) {
    insights.push({ icon: '\ud83d\udd25', text: `${streak}-day check-in streak. Patient is highly engaged.` });
  } else if (streak === 0 && sorted.length > 0) {
    insights.push({ icon: '\ud83d\udccc', text: 'Streak broken. Check-in engagement may be declining.' });
  }

  return insights;
}

export default PatientDetail;
