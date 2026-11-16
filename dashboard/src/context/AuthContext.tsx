import React, { createContext, useContext, useState, useEffect } from 'react';

export type UserRole = 'SUPER_ADMIN' | 'LEGAL_MODERATOR' | 'OPS_INVESTIGATOR';

export interface AdminUser {
  id: string;
  name: string;
  email: string;
  role: UserRole;
  avatarUrl?: string;
}

interface AuthContextType {
  user: AdminUser | null;
  isAuthenticated: boolean;
  login: (email: string, role?: UserRole) => Promise<boolean>;
  logout: () => void;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

const DEFAULT_ADMIN: AdminUser = {
  id: 'usr-admin-01',
  name: 'Manish Sukariya',
  email: 'admin@priceshield.org',
  role: 'SUPER_ADMIN',
  avatarUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=200&q=80',
};

export const AuthProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [user, setUser] = useState<AdminUser | null>(() => {
    const saved = localStorage.getItem('priceshield_admin_session');
    if (saved) {
      try {
        return JSON.parse(saved);
      } catch {
        return DEFAULT_ADMIN;
      }
    }
    return DEFAULT_ADMIN; // Default logged in for immediate operations productivity
  });

  useEffect(() => {
    if (user) {
      localStorage.setItem('priceshield_admin_session', JSON.stringify(user));
    } else {
      localStorage.removeItem('priceshield_admin_session');
    }
  }, [user]);

  const login = async (email: string, role: UserRole = 'LEGAL_MODERATOR') => {
    const newUser: AdminUser = {
      id: `usr-${Date.now()}`,
      name: email.split('@')[0].replace('.', ' ').toUpperCase(),
      email,
      role,
      avatarUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=200&q=80',
    };
    setUser(newUser);
    return true;
  };

  const logout = () => {
    setUser(null);
  };

  return (
    <AuthContext.Provider
      value={{
        user,
        isAuthenticated: !!user,
        login,
        logout,
      }}
    >
      {children}
    </AuthContext.Provider>
  );
};

export const useAuth = () => {
  const context = useContext(AuthContext);
  if (!context) throw new Error('useAuth must be used within an AuthProvider');
  return context;
};
