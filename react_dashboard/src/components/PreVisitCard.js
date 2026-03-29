import React from 'react';

function PreVisitCard({ appointment, patients }) {
  const patient = appointment.patient || {};
  const scheduledAt = new Date(appointment.scheduled_at);
  const isPast = scheduledAt < new Date();
  const isToday = scheduledAt.toDateString() === new Date().toDateString();

  // Auto-generate summary from patient data if not provided
  const autoSummary = appointment.pre_visit_note || generateAutoSummary(appointment);

  return (
    <div className="card pre-visit-card" style={{ marginBottom: 20, opacity: isPast ? 0.7 : 1 }}>
      <h3>
        <span style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#1d4ed8" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
            <rect x="3" y="4" width="18" height="18" rx="2" ry="2"/>
            <line x1="16" y1="2" x2="16" y2="6"/>
            <line x1="8" y1="2" x2="8" y2="6"/>
            <line x1="3" y1="10" x2="21" y2="10"/>
          </svg>
          {isPast ? 'Past Appointment' : isToday ? 'Today\'s Appointment' : 'Upcoming Appointment'}
        </span>
      </h3>

      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 16, flexWrap: 'wrap', gap: 12 }}>
        <div>
          <h2 style={{ fontSize: 20, margin: 0, color: '#0f172a' }}>{patient.name || 'Patient'}</h2>
          <p style={{ color: '#64748b', fontSize: 14, marginTop: 2 }}>{patient.surgery_type}</p>
        </div>
        <div style={{
          textAlign: 'right', background: 'white', padding: '10px 16px',
          borderRadius: 12, border: `1px solid ${isToday ? '#f59e0b' : '#bfdbfe'}`,
        }}>
          <div style={{ fontSize: 16, fontWeight: 700, color: isToday ? '#d97706' : '#1d4ed8' }}>
            {scheduledAt.toLocaleString('en-IN', { hour: '2-digit', minute: '2-digit', day: 'numeric', month: 'short' })}
          </div>
          <div style={{ fontSize: 11, color: '#94a3b8', fontWeight: 600, textTransform: 'uppercase', letterSpacing: '0.5px' }}>
            {isPast ? 'Completed' : isToday ? 'Today' : 'Upcoming'}
          </div>
        </div>
      </div>

      {/* Auto-generated summary */}
      <div className="pre-visit-inner" style={{ marginBottom: appointment.patient_question ? 12 : 0 }}>
        <div className="pre-visit-label">
          {appointment.pre_visit_note ? 'Doctor\'s Note' : 'Auto-Generated Pre-Visit Brief'}
        </div>
        <p style={{ fontSize: 14, color: '#334155', lineHeight: 1.7 }}>{autoSummary}</p>
      </div>

      {appointment.patient_question && (
        <div className="pre-visit-inner" style={{ marginTop: 12 }}>
          <div className="pre-visit-label">Patient's Question</div>
          <p style={{ fontSize: 14, fontStyle: 'italic', color: '#475569', lineHeight: 1.6 }}>"{appointment.patient_question}"</p>
        </div>
      )}

      {/* Action buttons for doctors */}
      {!isPast && (
        <div style={{ display: 'flex', gap: 10, marginTop: 14, flexWrap: 'wrap' }}>
          <span style={{
            padding: '6px 14px', borderRadius: 8, fontSize: 12, fontWeight: 600,
            background: '#dcfce7', color: '#166534', cursor: 'default',
          }}>
            Review patient history before visit
          </span>
        </div>
      )}
    </div>
  );
}

function generateAutoSummary(appointment) {
  const patient = appointment.patient || {};
  const name = patient.name || 'Patient';
  const surgery = patient.surgery_type || 'surgery';

  return `Patient ${name}, ${surgery} recovery. ` +
    `Please review their latest check-in transcripts, BP readings, and medication adherence before this visit. ` +
    `Click on their name in the Patient List to see the full 7-day trend.`;
}

export default PreVisitCard;
