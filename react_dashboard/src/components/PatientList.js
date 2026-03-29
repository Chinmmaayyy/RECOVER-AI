import React from 'react';

function PatientList({ patients, selectedId, onSelect, onCallPatient }) {
  if (patients.length === 0) {
    return (
      <div className="empty-state" style={{ padding: 40 }}>
        <p>No patients assigned</p>
      </div>
    );
  }

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
      {patients.map(patient => {
        const status = getLatestStatus(patient);
        const lastBP = getLatestBP(patient);
        const lastCheckIn = getLatestCheckInTime(patient);
        const isSelected = selectedId === patient.id;
        const isUrgent = status === 'red';
        const alerts = (patient.alerts || []).filter(a => a.triage_status === 'red' && !a.caregiver_acknowledged);

        return (
          <div
            key={patient.id}
            onClick={() => onSelect(patient)}
            className={`patient-row ${isSelected ? 'selected' : ''} ${isUrgent ? 'urgent' : ''}`}
            style={{
              display: 'flex', alignItems: 'center', gap: 12,
              padding: '12px 14px', borderRadius: 12, cursor: 'pointer',
              background: isSelected ? '#f0fdfa' : isUrgent ? '#fef2f2' : 'white',
              border: `1.5px solid ${isSelected ? '#14b8a6' : isUrgent ? '#fca5a5' : '#f1f5f9'}`,
              transition: 'all 0.2s ease',
              position: 'relative',
            }}
          >
            {/* Urgency indicator bar */}
            <div style={{
              position: 'absolute', left: 0, top: 8, bottom: 8, width: 4, borderRadius: 4,
              background: status === 'red' ? '#dc2626' : status === 'yellow' ? '#d97706' : '#22c55e',
            }} />

            {/* Avatar with status ring */}
            <div style={{ position: 'relative', flexShrink: 0, marginLeft: 6 }}>
              <div style={{
                width: 40, height: 40, borderRadius: 12,
                background: status === 'red' ? '#fef2f2' : status === 'yellow' ? '#fffbeb' : '#f0fdf4',
                display: 'flex', alignItems: 'center', justifyContent: 'center',
                fontWeight: 700, fontSize: 16,
                color: status === 'red' ? '#dc2626' : status === 'yellow' ? '#d97706' : '#16a34a',
                border: `2px solid ${status === 'red' ? '#fca5a5' : status === 'yellow' ? '#fde68a' : '#bbf7d0'}`,
              }}>
                {patient.name?.[0] || 'P'}
              </div>
              {alerts.length > 0 && (
                <div style={{
                  position: 'absolute', top: -4, right: -4,
                  width: 16, height: 16, borderRadius: '50%',
                  background: '#dc2626', border: '2px solid white',
                  display: 'flex', alignItems: 'center', justifyContent: 'center',
                  fontSize: 9, fontWeight: 700, color: 'white',
                }}>
                  {alerts.length}
                </div>
              )}
            </div>

            {/* Patient info */}
            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                <span style={{ fontWeight: 600, fontSize: 14, color: '#0f172a' }}>{patient.name}</span>
                <span className={`status-badge ${status}`} style={{ fontSize: 9, padding: '2px 8px' }}>
                  {status.toUpperCase()}
                </span>
              </div>
              <div style={{ display: 'flex', gap: 10, marginTop: 3, fontSize: 12, color: '#94a3b8', flexWrap: 'wrap' }}>
                <span>{patient.surgery_type || 'N/A'}</span>
                <span>BP: {lastBP}</span>
                <span>{lastCheckIn}</span>
                {(patient.streak_score || 0) > 0 && (
                  <span style={{ color: '#d97706', fontWeight: 600 }}>
                    {'\uD83D\uDD25'} {patient.streak_score}
                  </span>
                )}
              </div>
            </div>

            {/* Quick actions */}
            <div style={{ display: 'flex', gap: 4, flexShrink: 0 }} onClick={e => e.stopPropagation()}>
              {patient.phone && (
                <button
                  title={`Call ${patient.name}`}
                  onClick={(e) => {
                    e.stopPropagation();
                    window.open(`tel:${patient.phone}`);
                  }}
                  style={{
                    width: 32, height: 32, borderRadius: 8, border: '1px solid #e2e8f0',
                    background: '#f8fafc', cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center',
                    color: '#0f766e', transition: 'all 0.2s',
                  }}
                >
                  <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                    <path d="M22 16.92v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07 19.5 19.5 0 0 1-6-6 19.79 19.79 0 0 1-3.07-8.67A2 2 0 0 1 4.11 2h3a2 2 0 0 1 2 1.72c.127.96.362 1.903.7 2.81a2 2 0 0 1-.45 2.11L8.09 9.91a16 16 0 0 0 6 6l1.27-1.27a2 2 0 0 1 2.11-.45c.907.338 1.85.573 2.81.7A2 2 0 0 1 22 16.92z"/>
                  </svg>
                </button>
              )}
              <div style={{
                width: 32, height: 32, borderRadius: 8, display: 'flex', alignItems: 'center', justifyContent: 'center',
                background: isUrgent ? '#dc2626' : '#f1f5f9', color: isUrgent ? 'white' : '#94a3b8',
              }}>
                <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                  <polyline points="9 18 15 12 9 6"/>
                </svg>
              </div>
            </div>
          </div>
        );
      })}
    </div>
  );
}

function getLatestStatus(patient) {
  const checkIns = patient.check_ins || [];
  if (checkIns.length === 0) return 'green';
  const sorted = [...checkIns].sort((a, b) => new Date(b.timestamp) - new Date(a.timestamp));
  return sorted[0].triage_status || 'green';
}

function getLatestBP(patient) {
  const readings = patient.bp_readings || [];
  if (readings.length === 0) return '\u2014';
  const sorted = [...readings].sort((a, b) => new Date(b.timestamp) - new Date(a.timestamp));
  return `${sorted[0].systolic}/${sorted[0].diastolic}`;
}

function getLatestCheckInTime(patient) {
  const checkIns = patient.check_ins || [];
  if (checkIns.length === 0) return 'Never';
  const sorted = [...checkIns].sort((a, b) => new Date(b.timestamp) - new Date(a.timestamp));
  return timeAgo(sorted[0].timestamp);
}

function timeAgo(timestamp) {
  const diffMs = new Date() - new Date(timestamp);
  const mins = Math.floor(diffMs / 60000);
  const hrs = Math.floor(diffMs / 3600000);
  const days = Math.floor(diffMs / 86400000);
  if (days > 0) return `${days}d ago`;
  if (hrs > 0) return `${hrs}h ago`;
  if (mins > 0) return `${mins}m ago`;
  return 'Just now';
}

export default PatientList;
