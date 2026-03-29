import React, { useState, useEffect, useCallback } from 'react';
import { useNavigate } from 'react-router-dom';
import { supabase, getDoctorPatients, getRedAlerts, getUpcomingAppointments, subscribeToCheckIns, subscribeToAlerts } from '../services/supabase';
import StatsBar from '../components/StatsBar';
import PatientList from '../components/PatientList';
import PatientDetail from '../components/PatientDetail';
import RedAlertLog from '../components/RedAlertLog';
import PreVisitCard from '../components/PreVisitCard';
import RightPanel from '../components/RightPanel';

const DEMO_DOCTOR_ID = 'd1000000-0000-0000-0000-000000000aa1';

function DoctorDashboard() {
  const navigate = useNavigate();
  const [patients, setPatients] = useState([]);
  const [selectedPatient, setSelectedPatient] = useState(null);
  const [redAlerts, setRedAlerts] = useState([]);
  const [appointments, setAppointments] = useState([]);
  const [allAppointments, setAllAppointments] = useState([]);
  const [loading, setLoading] = useState(true);
  const [activeNav, setActiveNav] = useState('dashboard');
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false);
  const [mobileDetailOpen, setMobileDetailOpen] = useState(false);

  // Schedule: new appointment form
  const [showAddAppt, setShowAddAppt] = useState(false);
  const [apptPatientId, setApptPatientId] = useState('');
  const [apptDate, setApptDate] = useState('');
  const [apptNote, setApptNote] = useState('');
  const [savingAppt, setSavingAppt] = useState(false);

  const loadData = useCallback(async () => {
    try {
      const [patientsData, alertsData, appointmentsData] = await Promise.all([
        getDoctorPatients(DEMO_DOCTOR_ID),
        getRedAlerts(DEMO_DOCTOR_ID),
        getUpcomingAppointments(DEMO_DOCTOR_ID),
      ]);

      // Also fetch ALL appointments (past + future) for schedule view
      const { data: allAppts } = await supabase
        .from('appointments')
        .select('*, patient:patients(name, surgery_type)')
        .eq('doctor_id', DEMO_DOCTOR_ID)
        .order('scheduled_at', { ascending: false });

      const statusOrder = { red: 0, yellow: 1, green: 2 };
      const sorted = patientsData.sort((a, b) => {
        const aStatus = getLatestStatus(a);
        const bStatus = getLatestStatus(b);
        return (statusOrder[aStatus] ?? 2) - (statusOrder[bStatus] ?? 2);
      });

      setPatients(sorted);
      setRedAlerts(alertsData);
      setAppointments(appointmentsData);
      setAllAppointments(allAppts || []);
      setLoading(false);
    } catch (err) {
      console.error('Failed to load dashboard data:', err);
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    loadData();
    const checkInSub = subscribeToCheckIns(() => loadData());
    const alertSub = subscribeToAlerts(() => loadData());
    return () => {
      checkInSub.unsubscribe();
      alertSub.unsubscribe();
    };
  }, [loadData]);

  const handleSelectPatient = (patient) => {
    setSelectedPatient(patient);
    setMobileDetailOpen(true);
  };

  const handleLogout = () => {
    navigate('/login');
  };

  const handleAddAppointment = async () => {
    if (!apptPatientId || !apptDate) return;
    setSavingAppt(true);
    try {
      await supabase.from('appointments').insert({
        patient_id: apptPatientId,
        doctor_id: DEMO_DOCTOR_ID,
        scheduled_at: new Date(apptDate).toISOString(),
        pre_visit_note: apptNote || null,
      });
      setShowAddAppt(false);
      setApptPatientId('');
      setApptDate('');
      setApptNote('');
      await loadData();
    } catch (e) {
      console.error('Failed to add appointment:', e);
    }
    setSavingAppt(false);
  };

  if (loading) {
    return (
      <div className="loading-screen">
        <div className="spinner" />
        <p style={{ color: '#64748b', fontSize: 15, fontWeight: 500 }}>Loading dashboard...</p>
      </div>
    );
  }

  const stats = computeStats(patients);

  const renderContent = () => {
    switch (activeNav) {

      // ===================== PATIENTS VIEW =====================
      case 'patients':
        return (
          <>
            <StatsBar stats={stats} />
            <div className="main-content">
              <div className="card">
                <h3>
                  <span style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#64748b" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                      <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/>
                      <path d="M23 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/>
                    </svg>
                    All Patients ({patients.length})
                  </span>
                </h3>
                <PatientList patients={patients} selectedId={selectedPatient?.id} onSelect={handleSelectPatient} />
              </div>
              <div>
                {selectedPatient ? (
                  <PatientDetail patient={selectedPatient} />
                ) : (
                  <div className="card">
                    <div className="empty-state" style={{ padding: 40 }}>
                      <div className="empty-icon">
                        <svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="#94a3b8" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                          <path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/>
                        </svg>
                      </div>
                      <p style={{ fontSize: 15 }}>Select a patient</p>
                    </div>
                  </div>
                )}
              </div>
            </div>
          </>
        );

      // ===================== ALERTS VIEW =====================
      case 'alerts':
        return (
          <div style={{ maxWidth: 900 }}>
            <StatsBar stats={stats} />
            <div className="card">
              <h3>
                <span style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                  <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#dc2626" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                    <path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"/>
                    <line x1="12" y1="9" x2="12" y2="13"/><line x1="12" y1="17" x2="12.01" y2="17"/>
                  </svg>
                  All Red Alerts ({redAlerts.length})
                </span>
              </h3>
              <RedAlertLog
                alerts={redAlerts}
                onRefresh={loadData}
                onPatientClick={(patientId) => {
                  const p = patients.find(pt => pt.id === patientId);
                  if (p) { handleSelectPatient(p); setActiveNav('patients'); }
                }}
              />
            </div>
          </div>
        );

      // ===================== SCHEDULE VIEW =====================
      case 'schedule':
        return (
          <div style={{ maxWidth: 900 }}>
            {/* Add Appointment Button */}
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 20 }}>
              <h2 style={{ fontSize: 18 }}>Appointment Schedule</h2>
              <button
                onClick={() => setShowAddAppt(!showAddAppt)}
                style={{
                  padding: '10px 20px', borderRadius: 10, border: 'none', cursor: 'pointer', fontWeight: 600, fontSize: 14, fontFamily: 'inherit',
                  background: 'linear-gradient(135deg, #0f766e, #14b8a6)', color: 'white',
                  display: 'flex', alignItems: 'center', gap: 8,
                }}
              >
                <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="white" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
                  <line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/>
                </svg>
                Add Appointment
              </button>
            </div>

            {/* Add Appointment Form */}
            {showAddAppt && (
              <div className="card" style={{ marginBottom: 20 }}>
                <h3>New Appointment</h3>
                <div style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
                  <div>
                    <label style={{ fontSize: 13, fontWeight: 600, color: '#475569', display: 'block', marginBottom: 6 }}>Patient</label>
                    <select
                      value={apptPatientId}
                      onChange={e => setApptPatientId(e.target.value)}
                      style={{ width: '100%', padding: '10px 14px', borderRadius: 10, border: '1px solid #e2e8f0', fontSize: 14, fontFamily: 'inherit', background: '#f8fafc' }}
                    >
                      <option value="">Select patient...</option>
                      {patients.map(p => (
                        <option key={p.id} value={p.id}>{p.name} — {p.surgery_type}</option>
                      ))}
                    </select>
                  </div>
                  <div>
                    <label style={{ fontSize: 13, fontWeight: 600, color: '#475569', display: 'block', marginBottom: 6 }}>Date & Time</label>
                    <input
                      type="datetime-local"
                      value={apptDate}
                      onChange={e => setApptDate(e.target.value)}
                      style={{ width: '100%', padding: '10px 14px', borderRadius: 10, border: '1px solid #e2e8f0', fontSize: 14, fontFamily: 'inherit', background: '#f8fafc' }}
                    />
                  </div>
                  <div>
                    <label style={{ fontSize: 13, fontWeight: 600, color: '#475569', display: 'block', marginBottom: 6 }}>Pre-visit Note (optional)</label>
                    <textarea
                      value={apptNote}
                      onChange={e => setApptNote(e.target.value)}
                      placeholder="Any notes for this appointment..."
                      rows={3}
                      style={{ width: '100%', padding: '10px 14px', borderRadius: 10, border: '1px solid #e2e8f0', fontSize: 14, fontFamily: 'inherit', background: '#f8fafc', resize: 'vertical' }}
                    />
                  </div>
                  <div style={{ display: 'flex', gap: 12 }}>
                    <button
                      onClick={handleAddAppointment}
                      disabled={savingAppt || !apptPatientId || !apptDate}
                      style={{
                        padding: '10px 24px', borderRadius: 10, border: 'none', cursor: 'pointer', fontWeight: 600, fontSize: 14, fontFamily: 'inherit',
                        background: (!apptPatientId || !apptDate) ? '#cbd5e1' : '#0f766e', color: 'white',
                      }}
                    >
                      {savingAppt ? 'Saving...' : 'Save Appointment'}
                    </button>
                    <button
                      onClick={() => setShowAddAppt(false)}
                      style={{ padding: '10px 24px', borderRadius: 10, border: '1px solid #e2e8f0', background: 'white', cursor: 'pointer', fontWeight: 600, fontSize: 14, fontFamily: 'inherit', color: '#64748b' }}
                    >
                      Cancel
                    </button>
                  </div>
                </div>
              </div>
            )}

            {/* Upcoming Appointments */}
            <div className="card" style={{ marginBottom: 20 }}>
              <h3>
                <span style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                  <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#1d4ed8" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                    <rect x="3" y="4" width="18" height="18" rx="2" ry="2"/><line x1="16" y1="2" x2="16" y2="6"/>
                    <line x1="8" y1="2" x2="8" y2="6"/><line x1="3" y1="10" x2="21" y2="10"/>
                  </svg>
                  Upcoming ({appointments.length})
                </span>
              </h3>
              {appointments.length > 0 ? (
                appointments.map(apt => <PreVisitCard key={apt.id} appointment={apt} />)
              ) : (
                <div className="empty-state" style={{ padding: 40 }}>
                  <p style={{ fontSize: 15 }}>No upcoming appointments</p>
                  <p style={{ fontSize: 13, color: '#cbd5e1', marginTop: 4 }}>Click "Add Appointment" to schedule one</p>
                </div>
              )}
            </div>

            {/* Past Appointments */}
            {allAppointments.filter(a => new Date(a.scheduled_at) < new Date()).length > 0 && (
              <div className="card">
                <h3>Past Appointments</h3>
                <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
                  {allAppointments
                    .filter(a => new Date(a.scheduled_at) < new Date())
                    .slice(0, 10)
                    .map(apt => (
                      <div key={apt.id} style={{
                        display: 'flex', justifyContent: 'space-between', alignItems: 'center',
                        padding: '12px 16px', background: '#f8fafc', borderRadius: 10, border: '1px solid #f1f5f9',
                      }}>
                        <div>
                          <div style={{ fontWeight: 600, fontSize: 14, color: '#1e293b' }}>{apt.patient?.name || 'Patient'}</div>
                          <div style={{ fontSize: 12, color: '#94a3b8' }}>{apt.patient?.surgery_type}</div>
                        </div>
                        <div style={{ textAlign: 'right' }}>
                          <div style={{ fontSize: 13, fontWeight: 600, color: '#64748b' }}>
                            {new Date(apt.scheduled_at).toLocaleString('en-IN', { day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' })}
                          </div>
                          <div style={{ fontSize: 11, color: '#94a3b8' }}>Completed</div>
                        </div>
                      </div>
                    ))}
                </div>
              </div>
            )}
          </div>
        );

      // ===================== ANALYTICS VIEW =====================
      case 'analytics':
        return (
          <div style={{ maxWidth: 900 }}>
            <div className="card">
              <h3>Analytics Overview</h3>
              <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 16, marginTop: 16 }}>
                <div style={{ padding: 20, background: '#f0fdf4', borderRadius: 12, textAlign: 'center' }}>
                  <div style={{ fontSize: 32, fontWeight: 700, color: '#16a34a' }}>{stats.total}</div>
                  <div style={{ fontSize: 13, color: '#64748b', marginTop: 4 }}>Active Patients</div>
                </div>
                <div style={{ padding: 20, background: '#fef2f2', borderRadius: 12, textAlign: 'center' }}>
                  <div style={{ fontSize: 32, fontWeight: 700, color: '#dc2626' }}>{stats.red}</div>
                  <div style={{ fontSize: 13, color: '#64748b', marginTop: 4 }}>Critical Alerts</div>
                </div>
                <div style={{ padding: 20, background: '#fffbeb', borderRadius: 12, textAlign: 'center' }}>
                  <div style={{ fontSize: 32, fontWeight: 700, color: '#d97706' }}>{stats.yellow}</div>
                  <div style={{ fontSize: 13, color: '#64748b', marginTop: 4 }}>Under Watch</div>
                </div>
                <div style={{ padding: 20, background: '#f0fdfa', borderRadius: 12, textAlign: 'center' }}>
                  <div style={{ fontSize: 32, fontWeight: 700, color: '#0f766e' }}>{stats.adherence}%</div>
                  <div style={{ fontSize: 13, color: '#64748b', marginTop: 4 }}>Med Adherence</div>
                </div>
              </div>
            </div>
          </div>
        );

      // ===================== DASHBOARD VIEW (default) =====================
      case 'dashboard':
      default:
        return (
          <>
            <StatsBar stats={stats} />

            {appointments
              .filter(a => isWithin24Hours(a.scheduled_at))
              .map(apt => (
                <PreVisitCard key={apt.id} appointment={apt} />
              ))}

            <div className="three-col-layout">
              {/* LEFT: Patient List */}
              <div className="col-left">
                <div className="card" style={{ padding: 14 }}>
                  <h3 style={{ fontSize: 11, marginBottom: 10 }}>
                    <span style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                      <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="#64748b" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                        <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/>
                      </svg>
                      Patients ({patients.length})
                    </span>
                  </h3>
                  <PatientList patients={patients} selectedId={selectedPatient?.id} onSelect={handleSelectPatient} />
                </div>
              </div>

              {/* CENTER: Patient Detail */}
              <div className="col-center">
                {selectedPatient ? (
                  <PatientDetail patient={selectedPatient} />
                ) : (
                  <div className="card">
                    <div className="empty-state">
                      <div className="empty-icon">
                        <svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="#94a3b8" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                          <path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/>
                        </svg>
                      </div>
                      <p style={{ fontSize: 15 }}>Select a patient to view details</p>
                      <p style={{ fontSize: 13, color: '#cbd5e1', marginTop: 4 }}>Click any patient from the list</p>
                    </div>
                  </div>
                )}
              </div>

              {/* RIGHT: Alerts + Activity + AI */}
              <div className="col-right">
                <RightPanel
                  alerts={redAlerts}
                  patients={patients}
                  appointments={appointments}
                  onRefresh={loadData}
                  onPatientClick={(patientId) => {
                    const p = patients.find(pt => pt.id === patientId);
                    if (p) handleSelectPatient(p);
                  }}
                />
              </div>
            </div>
          </>
        );
    }
  };

  const navTitle = {
    dashboard: 'Dashboard',
    patients: 'Patients',
    alerts: 'Alerts',
    schedule: 'Schedule',
    analytics: 'Analytics',
  };

  return (
    <div className="app-layout">
      {mobileMenuOpen && (
        <div className="mobile-overlay" onClick={() => setMobileMenuOpen(false)} />
      )}

      {/* Sidebar */}
      <aside className={`sidebar ${mobileMenuOpen ? 'sidebar-open' : ''}`}>
        <div className="sidebar-brand">
          <h1>RecoverAI</h1>
          <p>Clinical Platform</p>
        </div>
        <nav className="sidebar-nav">
          {[
            { key: 'dashboard', label: 'Dashboard', icon: <><rect x="3" y="3" width="7" height="7"/><rect x="14" y="3" width="7" height="7"/><rect x="14" y="14" width="7" height="7"/><rect x="3" y="14" width="7" height="7"/></> },
            { key: 'patients', label: 'Patients', icon: <><path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M23 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/></> },
            { key: 'alerts', label: 'Alerts', icon: <><path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9"/><path d="M13.73 21a2 2 0 0 1-3.46 0"/></> },
            { key: 'schedule', label: 'Schedule', icon: <><rect x="3" y="4" width="18" height="18" rx="2" ry="2"/><line x1="16" y1="2" x2="16" y2="6"/><line x1="8" y1="2" x2="8" y2="6"/><line x1="3" y1="10" x2="21" y2="10"/></> },
            { key: 'analytics', label: 'Analytics', icon: <><line x1="18" y1="20" x2="18" y2="10"/><line x1="12" y1="20" x2="12" y2="4"/><line x1="6" y1="20" x2="6" y2="14"/></> },
          ].map(item => (
            <button
              key={item.key}
              className={`sidebar-nav-item ${activeNav === item.key ? 'active' : ''}`}
              onClick={() => { setActiveNav(item.key); setMobileMenuOpen(false); }}
            >
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                {item.icon}
              </svg>
              <span>{item.label}</span>
            </button>
          ))}
        </nav>

        {/* LOGOUT BUTTON in sidebar */}
        <div className="sidebar-logout">
          <button className="sidebar-nav-item logout-btn" onClick={handleLogout}>
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
              <path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"/>
              <polyline points="16 17 21 12 16 7"/>
              <line x1="21" y1="12" x2="9" y2="12"/>
            </svg>
            <span>Logout</span>
          </button>
        </div>

        <div className="sidebar-footer">
          v1.0 &middot; RecoverAI
        </div>
      </aside>

      {/* Main Area */}
      <div className="dashboard">
        <header className="top-header">
          <div className="top-header-left">
            <button className="mobile-menu-btn" onClick={() => setMobileMenuOpen(!mobileMenuOpen)}>
              <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                <line x1="3" y1="12" x2="21" y2="12"/><line x1="3" y1="6" x2="21" y2="6"/><line x1="3" y1="18" x2="21" y2="18"/>
              </svg>
            </button>
            <h2>{navTitle[activeNav] || 'Dashboard'}</h2>
            <span className="date-display">
              {new Date().toLocaleDateString('en-IN', { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' })}
            </span>
          </div>
          <div className="top-header-right">
            <button className="notification-btn" onClick={() => setActiveNav('alerts')}>
              <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                <path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9"/><path d="M13.73 21a2 2 0 0 1-3.46 0"/>
              </svg>
              {redAlerts.length > 0 && <span className="badge">{redAlerts.length}</span>}
            </button>
            <button className="refresh-btn" onClick={loadData} title="Refresh data">
              <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                <polyline points="23 4 23 10 17 10"/><path d="M20.49 15a9 9 0 1 1-2.12-9.36L23 10"/>
              </svg>
            </button>
            <div className="doctor-avatar">
              <div className="avatar-circle">DC</div>
              <div className="avatar-info">
                <span className="name">Dr. Chen</span>
                <span className="role">Cardiothoracic</span>
              </div>
            </div>
          </div>
        </header>

        <div className="dashboard-body">
          {renderContent()}
        </div>
      </div>

      {/* Mobile Patient Detail Slide-over */}
      {mobileDetailOpen && selectedPatient && (
        <div className="mobile-detail-overlay">
          <div className="mobile-detail-panel">
            <div className="mobile-detail-header">
              <button onClick={() => setMobileDetailOpen(false)} className="mobile-back-btn">
                <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                  <polyline points="15 18 9 12 15 6"/>
                </svg>
                Back
              </button>
            </div>
            <PatientDetail patient={selectedPatient} />
          </div>
        </div>
      )}
    </div>
  );
}

function getLatestStatus(patient) {
  const checkIns = patient.check_ins || [];
  if (checkIns.length === 0) return 'green';
  const sorted = [...checkIns].sort((a, b) => new Date(b.timestamp) - new Date(a.timestamp));
  return sorted[0].triage_status || 'green';
}

function computeStats(patients) {
  let red = 0, yellow = 0, green = 0;
  let totalMedAdherence = 0;
  patients.forEach(p => {
    const status = getLatestStatus(p);
    if (status === 'red') red++;
    else if (status === 'yellow') yellow++;
    else green++;
    const checkIns = p.check_ins || [];
    const withMeds = checkIns.filter(c => c.symptom_json?.medications_taken === true).length;
    totalMedAdherence += checkIns.length > 0 ? (withMeds / checkIns.length) * 100 : 100;
  });
  return {
    total: patients.length, red, yellow,
    adherence: patients.length > 0 ? Math.round(totalMedAdherence / patients.length) : 0,
  };
}

function isWithin24Hours(dateStr) {
  const diff = new Date(dateStr) - new Date();
  return diff > 0 && diff < 86400000;
}

export default DoctorDashboard;
