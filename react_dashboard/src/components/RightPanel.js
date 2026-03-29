import React, { useState } from 'react';
import { supabase } from '../services/supabase';

function RightPanel({ alerts, patients, appointments, onRefresh, onPatientClick }) {
  const [ackingId, setAckingId] = useState(null);

  const pendingAlerts = alerts.filter(a => !a.caregiver_acknowledged);
  const recentActivity = buildRecentActivity(patients);
  const riskSummary = buildRiskSummary(patients, alerts);
  const aiInsights = buildAIInsights(patients, alerts);

  const handleAck = async (alertId) => {
    setAckingId(alertId);
    try {
      await supabase.from('alerts').update({ caregiver_acknowledged: true }).eq('id', alertId);
      if (onRefresh) onRefresh();
    } catch (e) { console.error(e); }
    setAckingId(null);
  };

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>

      {/* ============================================================
          SECTION 1: CRITICAL ALERTS — Most important, top of panel
          ============================================================ */}
      <div style={{
        borderRadius: 14, overflow: 'hidden',
        border: pendingAlerts.length > 0 ? '1.5px solid #fca5a5' : '1px solid #e2e8f0',
        background: 'white',
        boxShadow: pendingAlerts.length > 0 ? '0 4px 20px rgba(239,68,68,0.1)' : '0 1px 3px rgba(0,0,0,0.04)',
      }}>
        {/* Alert header bar */}
        <div style={{
          padding: '10px 16px',
          background: pendingAlerts.length > 0 ? 'linear-gradient(135deg, #dc2626, #b91c1c)' : 'linear-gradient(135deg, #16a34a, #15803d)',
          display: 'flex', justifyContent: 'space-between', alignItems: 'center',
        }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
            <div style={{ width: 8, height: 8, borderRadius: '50%', background: 'white', animation: pendingAlerts.length > 0 ? 'pulse-red 1.5s infinite' : 'none' }} />
            <span style={{ fontSize: 12, fontWeight: 700, color: 'white', textTransform: 'uppercase', letterSpacing: '0.5px' }}>
              {pendingAlerts.length > 0 ? `${pendingAlerts.length} Critical Alert${pendingAlerts.length > 1 ? 's' : ''}` : 'All Clear'}
            </span>
          </div>
          {pendingAlerts.length > 0 && (
            <span style={{ fontSize: 20, fontWeight: 800, color: 'white' }}>{pendingAlerts.length}</span>
          )}
        </div>

        {/* Alert items */}
        <div style={{ padding: pendingAlerts.length > 0 ? '10px 12px' : '12px 16px' }}>
          {pendingAlerts.length === 0 ? (
            <div style={{ textAlign: 'center', padding: '4px 0', color: '#16a34a', fontSize: 13, fontWeight: 500 }}>
              No pending alerts. All patients stable.
            </div>
          ) : (
            <div style={{ display: 'flex', flexDirection: 'column', gap: 8, maxHeight: 220, overflowY: 'auto' }}>
              {pendingAlerts.slice(0, 6).map(alert => (
                <div key={alert.id} style={{
                  padding: '10px 12px', borderRadius: 10,
                  background: '#fef2f2', borderLeft: '4px solid #ef4444',
                  transition: 'all 0.2s ease',
                }}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: 4 }}>
                    <div style={{ flex: 1 }}>
                      <div style={{ fontWeight: 700, fontSize: 13, color: '#991b1b' }}>
                        {alert.patient?.name || 'Patient'}
                      </div>
                      <div style={{ fontSize: 12, color: '#64748b', lineHeight: 1.4, marginTop: 2 }}>
                        {alert.trigger_reason}
                      </div>
                    </div>
                    <span style={{ fontSize: 10, color: '#94a3b8', whiteSpace: 'nowrap', marginLeft: 8 }}>
                      {timeAgo(alert.timestamp)}
                    </span>
                  </div>
                  <div style={{ display: 'flex', gap: 6, marginTop: 6 }}>
                    <button
                      onClick={() => handleAck(alert.id)}
                      disabled={ackingId === alert.id}
                      style={{
                        padding: '4px 12px', borderRadius: 6, border: 'none', cursor: 'pointer',
                        fontSize: 11, fontWeight: 700, fontFamily: 'inherit',
                        background: '#dc2626', color: 'white', transition: 'all 0.15s',
                      }}
                    >
                      {ackingId === alert.id ? '...' : 'Acknowledge'}
                    </button>
                    {onPatientClick && (
                      <button
                        onClick={() => onPatientClick(alert.patient_id)}
                        style={{
                          padding: '4px 12px', borderRadius: 6, border: '1px solid #e2e8f0',
                          cursor: 'pointer', fontSize: 11, fontWeight: 600, fontFamily: 'inherit',
                          background: 'white', color: '#475569', transition: 'all 0.15s',
                        }}
                      >
                        View Patient
                      </button>
                    )}
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>

      {/* ============================================================
          SECTION 2: RISK SUMMARY — Quick decision stats
          ============================================================ */}
      <div className="card" style={{ padding: 14 }}>
        <h3 style={{ margin: 0, border: 'none', padding: 0, marginBottom: 10, fontSize: 11 }}>
          Risk Overview
        </h3>
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 8 }}>
          <div style={{ padding: '10px 12px', borderRadius: 10, background: '#fef2f2', textAlign: 'center' }}>
            <div style={{ fontSize: 22, fontWeight: 800, color: '#dc2626' }}>{riskSummary.critical}</div>
            <div style={{ fontSize: 10, fontWeight: 600, color: '#991b1b', textTransform: 'uppercase', letterSpacing: '0.3px' }}>Critical</div>
          </div>
          <div style={{ padding: '10px 12px', borderRadius: 10, background: '#fffbeb', textAlign: 'center' }}>
            <div style={{ fontSize: 22, fontWeight: 800, color: '#d97706' }}>{riskSummary.warning}</div>
            <div style={{ fontSize: 10, fontWeight: 600, color: '#92400e', textTransform: 'uppercase', letterSpacing: '0.3px' }}>Warning</div>
          </div>
          <div style={{ padding: '10px 12px', borderRadius: 10, background: '#f0fdf4', textAlign: 'center' }}>
            <div style={{ fontSize: 22, fontWeight: 800, color: '#16a34a' }}>{riskSummary.stable}</div>
            <div style={{ fontSize: 10, fontWeight: 600, color: '#166534', textTransform: 'uppercase', letterSpacing: '0.3px' }}>Stable</div>
          </div>
          <div style={{ padding: '10px 12px', borderRadius: 10, background: '#f8fafc', textAlign: 'center' }}>
            <div style={{ fontSize: 22, fontWeight: 800, color: '#64748b' }}>{riskSummary.needsReview}</div>
            <div style={{ fontSize: 10, fontWeight: 600, color: '#475569', textTransform: 'uppercase', letterSpacing: '0.3px' }}>Review</div>
          </div>
        </div>

        {/* Missed meds indicator */}
        {riskSummary.missedMeds > 0 && (
          <div style={{
            marginTop: 10, padding: '8px 12px', borderRadius: 8,
            background: '#fffbeb', border: '1px solid #fde68a',
            display: 'flex', alignItems: 'center', gap: 8,
          }}>
            <span style={{ fontSize: 14 }}>{'\uD83D\uDC8A'}</span>
            <span style={{ fontSize: 12, color: '#92400e', fontWeight: 600 }}>
              {riskSummary.missedMeds} patient{riskSummary.missedMeds > 1 ? 's' : ''} may have missed medications
            </span>
          </div>
        )}
      </div>

      {/* ============================================================
          SECTION 3: AI CLINICAL INSIGHTS
          ============================================================ */}
      {aiInsights.length > 0 && (
        <div style={{
          borderRadius: 14, overflow: 'hidden',
          background: 'linear-gradient(135deg, #f0fdfa 0%, #ecfdf5 50%, #f0fdf4 100%)',
          border: '1px solid #a7f3d0',
        }}>
          <div style={{
            padding: '8px 14px',
            background: 'linear-gradient(135deg, #0f766e, #059669)',
            display: 'flex', alignItems: 'center', gap: 6,
          }}>
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="white" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
              <polygon points="13 2 3 14 12 14 11 22 21 10 12 10 13 2"/>
            </svg>
            <span style={{ fontSize: 11, fontWeight: 700, color: 'white', textTransform: 'uppercase', letterSpacing: '0.5px' }}>
              AI Insights
            </span>
          </div>
          <div style={{ padding: '10px 14px', display: 'flex', flexDirection: 'column', gap: 6 }}>
            {aiInsights.map((insight, i) => (
              <div key={i} style={{
                display: 'flex', gap: 8, alignItems: 'flex-start',
                padding: '6px 10px', borderRadius: 8,
                background: insight.severity === 'high' ? '#fef2f2' : insight.severity === 'medium' ? '#fffbeb' : 'white',
                border: `1px solid ${insight.severity === 'high' ? '#fecaca' : insight.severity === 'medium' ? '#fde68a' : '#e2e8f0'}`,
              }}>
                <span style={{ fontSize: 14, flexShrink: 0 }}>{insight.icon}</span>
                <div style={{ flex: 1 }}>
                  <div style={{ fontSize: 12, fontWeight: 600, color: '#1e293b', lineHeight: 1.4 }}>{insight.title}</div>
                  <div style={{ fontSize: 11, color: '#64748b', lineHeight: 1.3, marginTop: 1 }}>{insight.detail}</div>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* ============================================================
          SECTION 4: RECENT ACTIVITY TIMELINE
          ============================================================ */}
      <div className="card" style={{ padding: 14 }}>
        <h3 style={{ margin: 0, border: 'none', padding: 0, marginBottom: 10, fontSize: 11, display: 'flex', alignItems: 'center', gap: 6 }}>
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="#64748b" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
            <circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/>
          </svg>
          Recent Activity
        </h3>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 4, maxHeight: 280, overflowY: 'auto' }}>
          {recentActivity.slice(0, 12).map((item, i) => (
            <div key={i} style={{
              display: 'flex', gap: 10, alignItems: 'center',
              padding: '7px 8px', borderRadius: 8,
              transition: 'background 0.15s',
            }}
            onMouseEnter={e => e.currentTarget.style.background = '#f8fafc'}
            onMouseLeave={e => e.currentTarget.style.background = 'transparent'}
            >
              {/* Timeline dot + line */}
              <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 2 }}>
                <div style={{
                  width: 8, height: 8, borderRadius: '50%',
                  background: item.dotColor,
                  border: `2px solid ${item.borderColor}`,
                }} />
                {i < Math.min(recentActivity.length - 1, 11) && (
                  <div style={{ width: 2, height: 16, background: '#f1f5f9' }} />
                )}
              </div>
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ fontSize: 12, color: '#1e293b', fontWeight: 500, lineHeight: 1.3 }}>{item.text}</div>
                <div style={{ fontSize: 10, color: '#94a3b8' }}>{item.time}</div>
              </div>
            </div>
          ))}
          {recentActivity.length === 0 && (
            <p style={{ fontSize: 12, color: '#94a3b8', textAlign: 'center', padding: 16 }}>No recent activity</p>
          )}
        </div>
      </div>

      {/* ============================================================
          UPCOMING APPOINTMENTS (compact)
          ============================================================ */}
      {appointments.length > 0 && (
        <div className="card" style={{ padding: 14 }}>
          <h3 style={{ margin: 0, border: 'none', padding: 0, marginBottom: 8, fontSize: 11, display: 'flex', alignItems: 'center', gap: 6 }}>
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="#64748b" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
              <rect x="3" y="4" width="18" height="18" rx="2" ry="2"/><line x1="16" y1="2" x2="16" y2="6"/>
              <line x1="8" y1="2" x2="8" y2="6"/><line x1="3" y1="10" x2="21" y2="10"/>
            </svg>
            Upcoming ({appointments.length})
          </h3>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
            {appointments.slice(0, 3).map(apt => (
              <div key={apt.id} style={{
                padding: '8px 10px', background: '#eff6ff', borderRadius: 8, border: '1px solid #bfdbfe',
                display: 'flex', justifyContent: 'space-between', alignItems: 'center',
              }}>
                <div style={{ fontWeight: 600, fontSize: 13, color: '#1e293b' }}>{apt.patient?.name}</div>
                <div style={{ fontSize: 11, color: '#3b82f6', fontWeight: 600 }}>
                  {new Date(apt.scheduled_at).toLocaleString('en-IN', { day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' })}
                </div>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}

// ======================== UTILITY FUNCTIONS ========================

function buildRiskSummary(patients, alerts) {
  let critical = 0, warning = 0, stable = 0, needsReview = 0, missedMeds = 0;

  patients.forEach(p => {
    const status = getStatus(p);
    if (status === 'red') critical++;
    else if (status === 'yellow') warning++;
    else stable++;

    // Check if patient needs review (no check-in in 2+ days)
    const checkIns = p.check_ins || [];
    if (checkIns.length > 0) {
      const latest = [...checkIns].sort((a, b) => new Date(b.timestamp) - new Date(a.timestamp))[0];
      const daysSince = (Date.now() - new Date(latest.timestamp).getTime()) / 86400000;
      if (daysSince > 2) needsReview++;

      // Check medication adherence
      const recent = checkIns.slice(0, 3);
      const missed = recent.filter(c => c.symptom_json?.medications_taken === false).length;
      if (missed >= 2) missedMeds++;
    } else {
      needsReview++;
    }
  });

  return { critical, warning, stable, needsReview, missedMeds };
}

function buildAIInsights(patients, alerts) {
  const insights = [];

  // BP trending analysis
  patients.forEach(p => {
    const bp = (p.bp_readings || []).sort((a, b) => new Date(a.timestamp) - new Date(b.timestamp));
    if (bp.length >= 3) {
      const recent = bp.slice(-3);
      const first = recent[0].systolic;
      const last = recent[recent.length - 1].systolic;
      if (last > first + 8) {
        insights.push({
          icon: '\u2B06\uFE0F', title: `${p.name}: BP trending up`,
          detail: `${first} \u2192 ${last} systolic over last ${recent.length} readings`,
          severity: last > 150 ? 'high' : 'medium',
        });
      }
    }
  });

  // Consecutive yellow escalation risk
  patients.forEach(p => {
    const ci = [...(p.check_ins || [])].sort((a, b) => new Date(b.timestamp) - new Date(a.timestamp));
    if (ci.length >= 3 && ci.slice(0, 3).every(c => c.triage_status === 'yellow')) {
      insights.push({
        icon: '\u26A0\uFE0F', title: `${p.name}: Escalation risk`,
        detail: '3 consecutive yellow flags. May escalate to red.',
        severity: 'medium',
      });
    }
  });

  // Medication adherence dropping
  patients.forEach(p => {
    const ci = (p.check_ins || []).slice(0, 5);
    const missed = ci.filter(c => c.symptom_json?.medications_taken === false).length;
    if (missed >= 2 && ci.length >= 3) {
      insights.push({
        icon: '\uD83D\uDC8A', title: `${p.name}: Adherence dropping`,
        detail: `Missed meds in ${missed} of last ${ci.length} check-ins`,
        severity: 'medium',
      });
    }
  });

  // Streak achievements (positive)
  patients.forEach(p => {
    if ((p.streak_score || 0) >= 7) {
      insights.push({
        icon: '\uD83D\uDD25', title: `${p.name}: ${p.streak_score}-day streak`,
        detail: 'Excellent engagement. Recovery on track.',
        severity: 'low',
      });
    }
  });

  // Sort: high severity first
  const order = { high: 0, medium: 1, low: 2 };
  insights.sort((a, b) => (order[a.severity] ?? 2) - (order[b.severity] ?? 2));

  return insights.slice(0, 5);
}

function buildRecentActivity(patients) {
  const items = [];

  patients.forEach(p => {
    (p.check_ins || []).forEach(ci => {
      items.push({
        text: `${p.name} checked in`,
        time: timeAgo(ci.timestamp),
        ts: new Date(ci.timestamp),
        dotColor: ci.triage_status === 'red' ? '#dc2626' : ci.triage_status === 'yellow' ? '#d97706' : '#22c55e',
        borderColor: ci.triage_status === 'red' ? '#fca5a5' : ci.triage_status === 'yellow' ? '#fde68a' : '#bbf7d0',
      });
    });

    (p.bp_readings || []).forEach(bp => {
      const isHigh = bp.systolic > 150;
      items.push({
        text: `${p.name} BP: ${bp.systolic}/${bp.diastolic}${isHigh ? ' (HIGH)' : ''}`,
        time: timeAgo(bp.timestamp),
        ts: new Date(bp.timestamp),
        dotColor: isHigh ? '#dc2626' : '#3b82f6',
        borderColor: isHigh ? '#fca5a5' : '#93c5fd',
      });
    });
  });

  items.sort((a, b) => b.ts - a.ts);
  return items;
}

function getStatus(patient) {
  const ci = patient.check_ins || [];
  if (!ci.length) return 'green';
  return [...ci].sort((a, b) => new Date(b.timestamp) - new Date(a.timestamp))[0].triage_status || 'green';
}

function timeAgo(ts) {
  const ms = Date.now() - new Date(ts).getTime();
  const m = Math.floor(ms / 60000);
  const h = Math.floor(ms / 3600000);
  const d = Math.floor(ms / 86400000);
  if (d > 0) return `${d}d ago`;
  if (h > 0) return `${h}h ago`;
  if (m > 0) return `${m}m ago`;
  return 'Just now';
}

export default RightPanel;
