import React, { useState } from 'react';
import { supabase } from '../services/supabase';

function RedAlertLog({ alerts, onPatientClick, onRefresh }) {
  const [filter, setFilter] = useState('all'); // all | pending | acknowledged
  const [ackingId, setAckingId] = useState(null);

  const filtered = alerts.filter(a => {
    if (filter === 'pending') return !a.caregiver_acknowledged;
    if (filter === 'acknowledged') return a.caregiver_acknowledged;
    return true;
  });

  const pendingCount = alerts.filter(a => !a.caregiver_acknowledged).length;

  const handleAcknowledge = async (alertId) => {
    setAckingId(alertId);
    try {
      await supabase.from('alerts').update({ caregiver_acknowledged: true }).eq('id', alertId);
      if (onRefresh) onRefresh();
    } catch (e) {
      console.error('Failed to acknowledge:', e);
    }
    setAckingId(null);
  };

  if (alerts.length === 0) {
    return (
      <div className="empty-state" style={{ padding: 32 }}>
        <div className="empty-icon">
          <svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="#16a34a" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
            <path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/>
            <polyline points="22 4 12 14.01 9 11.01"/>
          </svg>
        </div>
        <p style={{ color: '#16a34a', fontWeight: 600 }}>All clear &mdash; no red alerts</p>
      </div>
    );
  }

  const filterBtn = (key, label) => (
    <button
      onClick={() => setFilter(key)}
      style={{
        padding: '5px 12px', borderRadius: 6, border: 'none', cursor: 'pointer',
        fontSize: 11, fontWeight: 600, fontFamily: 'inherit',
        background: filter === key ? '#0f172a' : '#f1f5f9',
        color: filter === key ? 'white' : '#64748b',
        transition: 'all 0.15s',
      }}
    >
      {label}
    </button>
  );

  return (
    <div>
      {/* Filter bar */}
      <div style={{ display: 'flex', gap: 6, marginBottom: 12, alignItems: 'center' }}>
        {filterBtn('all', `All (${alerts.length})`)}
        {filterBtn('pending', `Pending (${pendingCount})`)}
        {filterBtn('acknowledged', `Ack'd (${alerts.length - pendingCount})`)}
      </div>

      <div style={{ display: 'flex', flexDirection: 'column', gap: 8, maxHeight: 400, overflowY: 'auto' }}>
        {filtered.map((alert, idx) => {
          const isPending = !alert.caregiver_acknowledged;
          const isAcking = ackingId === alert.id;

          return (
            <div
              key={alert.id}
              style={{
                display: 'flex', alignItems: 'flex-start', gap: 12,
                padding: '12px 14px',
                background: isPending ? 'linear-gradient(135deg, #fff5f5, #fef2f2)' : '#f8fafc',
                borderRadius: 12,
                borderLeft: `4px solid ${isPending ? '#ef4444' : '#22c55e'}`,
                opacity: isPending ? 1 : 0.75,
                animation: `fadeInUp 0.3s ease-out ${idx * 0.03}s both`,
              }}
            >
              {/* Icon */}
              <div style={{
                width: 36, height: 36, borderRadius: 10, flexShrink: 0,
                background: isPending ? 'rgba(239,68,68,0.1)' : 'rgba(34,197,94,0.1)',
                display: 'flex', alignItems: 'center', justifyContent: 'center',
              }}>
                <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke={isPending ? '#dc2626' : '#16a34a'} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                  {isPending ? (
                    <>
                      <path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"/>
                      <line x1="12" y1="9" x2="12" y2="13"/><line x1="12" y1="17" x2="12.01" y2="17"/>
                    </>
                  ) : (
                    <>
                      <path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/>
                      <polyline points="22 4 12 14.01 9 11.01"/>
                    </>
                  )}
                </svg>
              </div>

              {/* Content */}
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 3 }}>
                  <span style={{ fontWeight: 600, fontSize: 13, color: '#1e293b' }}>
                    {alert.patient?.name || 'Patient'}
                  </span>
                  <span style={{ fontSize: 11, color: '#94a3b8' }}>
                    {new Date(alert.timestamp).toLocaleString('en-IN', { day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' })}
                  </span>
                </div>
                <div style={{ fontSize: 12, color: '#64748b', lineHeight: 1.4, marginBottom: 6 }}>
                  {alert.trigger_reason}
                </div>

                {/* Action buttons */}
                {isPending && (
                  <div style={{ display: 'flex', gap: 6 }}>
                    <button
                      onClick={() => handleAcknowledge(alert.id)}
                      disabled={isAcking}
                      style={{
                        padding: '4px 10px', borderRadius: 6, border: 'none', cursor: 'pointer',
                        fontSize: 11, fontWeight: 600, fontFamily: 'inherit',
                        background: '#0f766e', color: 'white',
                      }}
                    >
                      {isAcking ? '...' : 'Acknowledge'}
                    </button>
                    {onPatientClick && (
                      <button
                        onClick={() => onPatientClick(alert.patient_id)}
                        style={{
                          padding: '4px 10px', borderRadius: 6, border: '1px solid #e2e8f0',
                          cursor: 'pointer', fontSize: 11, fontWeight: 600, fontFamily: 'inherit',
                          background: 'white', color: '#475569',
                        }}
                      >
                        View Patient
                      </button>
                    )}
                  </div>
                )}
                {!isPending && (
                  <span style={{ fontSize: 10, fontWeight: 600, color: '#16a34a', textTransform: 'uppercase' }}>
                    Acknowledged
                  </span>
                )}
              </div>
            </div>
          );
        })}
        {filtered.length === 0 && (
          <p style={{ textAlign: 'center', color: '#94a3b8', fontSize: 13, padding: 20 }}>
            No {filter} alerts
          </p>
        )}
      </div>
    </div>
  );
}

export default RedAlertLog;
