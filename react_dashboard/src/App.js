import React from 'react';
import { Routes, Route, Navigate } from 'react-router-dom';
import DoctorDashboard from './pages/DoctorDashboard';
import LoginPage from './pages/LoginPage';

function App() {
  return (
    <Routes>
      <Route path="/login" element={<LoginPage />} />
      <Route path="/dashboard" element={<DoctorDashboard />} />
      <Route path="*" element={<Navigate to="/login" replace />} />
    </Routes>
  );
}

export default App;
