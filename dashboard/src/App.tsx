import React from 'react';
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { ThemeProvider } from './context/ThemeContext';
import { AuthProvider, useAuth } from './context/AuthContext';
import { DashboardLayout } from './components/layout/DashboardLayout';
import { OverviewPage } from './pages/OverviewPage';
import { CasesPage } from './pages/CasesPage';
import { CaseDetailPage } from './pages/CaseDetailPage';
import { ProductsPage } from './pages/ProductsPage';
import { SubmissionsPage } from './pages/SubmissionsPage';
import { MerchantsPage } from './pages/MerchantsPage';
import { LiveScansPage } from './pages/LiveScansPage';
import { PlansBoostPage } from './pages/PlansBoostPage';
import { SettingsPage } from './pages/SettingsPage';
import { LoginPage } from './pages/LoginPage';

// Protected Route Guard
const ProtectedRoute: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const { isAuthenticated } = useAuth();
  if (!isAuthenticated) {
    return <Navigate to="/login" replace />;
  }
  return <>{children}</>;
};

export const App: React.FC = () => {
  return (
    <ThemeProvider>
      <AuthProvider>
        <BrowserRouter>
          <Routes>
            <Route path="/login" element={<LoginPage />} />

            <Route
              path="/"
              element={
                <ProtectedRoute>
                  <DashboardLayout />
                </ProtectedRoute>
              }
            >
              <Route index element={<OverviewPage />} />
              <Route path="cases" element={<CasesPage />} />
              <Route path="cases/:id" element={<CaseDetailPage />} />
              <Route path="plans" element={<PlansBoostPage />} />
              <Route path="products" element={<ProductsPage />} />
              <Route path="submissions" element={<SubmissionsPage />} />
              <Route path="merchants" element={<MerchantsPage />} />
              <Route path="scans" element={<LiveScansPage />} />
              <Route path="settings" element={<SettingsPage />} />
            </Route>

            <Route path="*" element={<Navigate to="/" replace />} />
          </Routes>
        </BrowserRouter>
      </AuthProvider>
    </ThemeProvider>
  );
};
