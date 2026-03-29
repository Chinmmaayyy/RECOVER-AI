import React from 'react';

function StatsBar({ stats }) {
  return (
    <div className="stats-bar">
      <div className="stat-card stat-total" style={{ animationDelay: '0s' }}>
        <div className="stat-icon">
          <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="#0f766e" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
            <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/>
            <circle cx="9" cy="7" r="4"/>
            <path d="M23 21v-2a4 4 0 0 0-3-3.87"/>
            <path d="M16 3.13a4 4 0 0 1 0 7.75"/>
          </svg>
        </div>
        <div className="value">{stats.total}</div>
        <div className="label">Total Patients</div>
      </div>

      <div className="stat-card stat-red" style={{ animationDelay: '0.05s' }}>
        <div className="stat-icon">
          <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="#dc2626" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
            <path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"/>
            <line x1="12" y1="9" x2="12" y2="13"/>
            <line x1="12" y1="17" x2="12.01" y2="17"/>
          </svg>
        </div>
        <div className="value">{stats.red}</div>
        <div className="label">Red Alerts</div>
      </div>

      <div className="stat-card stat-yellow" style={{ animationDelay: '0.1s' }}>
        <div className="stat-icon">
          <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="#d97706" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
            <circle cx="12" cy="12" r="10"/>
            <line x1="12" y1="8" x2="12" y2="12"/>
            <line x1="12" y1="16" x2="12.01" y2="16"/>
          </svg>
        </div>
        <div className="value">{stats.yellow}</div>
        <div className="label">Yellow Watch</div>
      </div>

      <div className="stat-card stat-adherence" style={{ animationDelay: '0.15s' }}>
        <div className="stat-icon">
          <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="#16a34a" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
            <path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/>
            <polyline points="22 4 12 14.01 9 11.01"/>
          </svg>
        </div>
        <div className="value">{stats.adherence}%</div>
        <div className="label">Med Adherence</div>
      </div>
    </div>
  );
}

export default StatsBar;
