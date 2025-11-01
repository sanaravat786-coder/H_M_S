import React from 'react';
import { Routes, Route, Navigate } from 'react-router-dom';
import { useAuth } from './hooks/useAuth';

import DashboardLayout from './layouts/DashboardLayout';
import AuthLayout from './layouts/AuthLayout';
import ProtectedRoute from './components/ProtectedRoute';

import Dashboard from './pages/Dashboard';
import StudentsPage from './pages/StudentsPage';
import StudentDetailPage from './pages/details/StudentDetailPage';
import RoomsPage from './pages/RoomsPage';
import RoomDetailPage from './pages/details/RoomDetailPage';
import FeesPage from './pages/FeesPage';
import VisitorsPage from './pages/VisitorsPage';
import ComplaintsPage from './pages/ComplaintsPage';
import AnnouncementsPage from './pages/AnnouncementsPage';
import SettingsPage from './pages/SettingsPage';
import LoginPage from './pages/LoginPage';
import SignupPage from './pages/SignupPage';

function App() {
    const { session } = useAuth();

    return (
        <Routes>
            <Route element={<AuthLayout />}>
                <Route path="/login" element={session ? <Navigate to="/" /> : <LoginPage />} />
                <Route path="/signup" element={session ? <Navigate to="/" /> : <SignupPage />} />
            </Route>

            <Route element={<ProtectedRoute />}>
                <Route element={<DashboardLayout />}>
                    <Route path="/" element={<Dashboard />} />
                    <Route path="/students" element={<StudentsPage />} />
                    <Route path="/students/:studentId" element={<StudentDetailPage />} />
                    <Route path="/rooms" element={<RoomsPage />} />
                    <Route path="/rooms/:roomId" element={<RoomDetailPage />} />
                    <Route path="/fees" element={<FeesPage />} />
                    <Route path="/visitors" element={<VisitorsPage />} />
                    <Route path="/complaints" element={<ComplaintsPage />} />
                    <Route path="/announcements" element={<AnnouncementsPage />} />
                    <Route path="/settings" element={<SettingsPage />} />
                </Route>
            </Route>
            
            <Route path="*" element={<Navigate to={session ? "/" : "/login"} />} />
        </Routes>
    );
}

export default App;
