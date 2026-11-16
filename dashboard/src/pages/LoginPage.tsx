import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { Shield, Lock, Mail, ArrowRight, UserCheck } from 'lucide-react';
import { Button } from '../components/ui/button';
import { Input } from '../components/ui/input';
import { useAuth, UserRole } from '../context/AuthContext';

export const LoginPage: React.FC = () => {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const { login } = useAuth();
  const navigate = useNavigate();

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!email) return;
    setIsLoading(true);
    await login(email, 'SUPER_ADMIN');
    setIsLoading(false);
    navigate('/');
  };

  const handleQuickLogin = async (role: UserRole, demoEmail: string) => {
    setIsLoading(true);
    await login(demoEmail, role);
    setIsLoading(false);
    navigate('/');
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-[#0B192C] via-[#10233F] to-[#070D19] flex items-center justify-center p-4">
      <div className="w-full max-w-md bg-white dark:bg-[#0B1528] rounded-2xl border border-slate-200 dark:border-slate-800 shadow-2xl p-8 space-y-6">
        {/* Brand Header */}
        <div className="text-center space-y-2">
          <div className="w-12 h-12 rounded-2xl bg-[#0F9D8A] text-white flex items-center justify-center mx-auto shadow-md">
            <Shield className="w-7 h-7" />
          </div>
          <h1 className="text-2xl font-black text-[#10233F] dark:text-white tracking-tight font-sans">
            PriceShield Console
          </h1>
          <p className="text-xs text-slate-500 dark:text-slate-400">
            Operations & Autonomous Dispute Resolution Command
          </p>
        </div>

        {/* Login Form */}
        <form onSubmit={handleLogin} className="space-y-4">
          <div>
            <label className="block text-xs font-bold text-slate-700 dark:text-slate-300 uppercase tracking-wider mb-1">
              Operator Email
            </label>
            <Input
              required
              type="email"
              placeholder="moderator@priceshield.org"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              icon={<Mail className="w-4 h-4 text-slate-400" />}
            />
          </div>

          <div>
            <label className="block text-xs font-bold text-slate-700 dark:text-slate-300 uppercase tracking-wider mb-1">
              Password
            </label>
            <Input
              required
              type="password"
              placeholder="••••••••••••"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              icon={<Lock className="w-4 h-4 text-slate-400" />}
            />
          </div>

          <Button
            type="submit"
            variant="secondary"
            isLoading={isLoading}
            className="w-full bg-[#0F9D8A] hover:bg-[#0C8373] text-white font-bold h-11"
          >
            Access Console <ArrowRight className="w-4 h-4 ml-1.5" />
          </Button>
        </form>

        {/* 1-Click Role Login for Operations Testing */}
        <div className="pt-4 border-t border-slate-100 dark:border-slate-800 space-y-2">
          <p className="text-[11px] font-bold text-slate-400 uppercase tracking-wider text-center">
            Quick 1-Click Role Login (Demo & Audit)
          </p>
          <div className="grid grid-cols-2 gap-2">
            <Button
              variant="outline"
              size="sm"
              onClick={() => handleQuickLogin('SUPER_ADMIN', 'admin@priceshield.org')}
              className="text-xs font-bold text-[#10233F] dark:text-slate-200"
            >
              <UserCheck className="w-3.5 h-3.5 mr-1 text-[#0F9D8A]" />
              Super Admin
            </Button>
            <Button
              variant="outline"
              size="sm"
              onClick={() => handleQuickLogin('LEGAL_MODERATOR', 'legal@priceshield.org')}
              className="text-xs font-bold text-[#10233F] dark:text-slate-200"
            >
              <UserCheck className="w-3.5 h-3.5 mr-1 text-purple-500" />
              Legal Moderator
            </Button>
          </div>
        </div>
      </div>
    </div>
  );
};
