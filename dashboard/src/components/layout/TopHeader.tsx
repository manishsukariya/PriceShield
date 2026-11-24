import React, { useEffect, useState } from 'react';
import { Search, Sun, Moon, Bell, LogOut, ShieldCheck, User, Cloud, Server } from 'lucide-react';
import { useTheme } from '../../context/ThemeContext';
import { useAuth } from '../../context/AuthContext';
import { Button } from '../ui/button';
import { getBackendTarget, setBackendTarget, BackendTarget } from '../../lib/api';

interface TopHeaderProps {
  onOpenSearch: () => void;
  collapsed: boolean;
}

export const TopHeader: React.FC<TopHeaderProps> = ({ onOpenSearch, collapsed }) => {
  const { theme, toggleTheme } = useTheme();
  const { user, logout } = useAuth();
  const [target, setTarget] = useState<BackendTarget>(getBackendTarget());
  const [isLive, setIsLive] = useState<boolean>(true);

  useEffect(() => {
    const handleConnection = (e: any) => {
      if (typeof e.detail?.isLive === 'boolean') {
        setIsLive(e.detail.isLive);
      }
    };
    const handleTarget = (e: any) => {
      if (e.detail?.target) {
        setTarget(e.detail.target);
      }
    };

    window.addEventListener('priceshield_connection_change', handleConnection);
    window.addEventListener('priceshield_target_change', handleTarget);
    return () => {
      window.removeEventListener('priceshield_connection_change', handleConnection);
      window.removeEventListener('priceshield_target_change', handleTarget);
    };
  }, []);

  const handleSwitchTarget = (newTarget: BackendTarget) => {
    setTarget(newTarget);
    setBackendTarget(newTarget);
  };

  return (
    <header
      className={`h-16 border-b border-slate-200/80 dark:border-slate-800 bg-white/80 dark:bg-[#070D19]/80 backdrop-blur-md sticky top-0 z-20 flex items-center justify-between px-6 transition-all duration-300 ${
        collapsed ? 'ml-20' : 'ml-64'
      }`}
    >
      {/* Left: Global Search trigger */}
      <div className="flex items-center gap-4 flex-1 max-w-md">
        <button
          onClick={onOpenSearch}
          className="w-full flex items-center justify-between px-3.5 py-2 text-xs text-slate-500 dark:text-slate-400 bg-slate-100 dark:bg-[#10233F]/40 border border-slate-200 dark:border-slate-800 rounded-lg hover:border-[#0F9D8A]/50 transition-all duration-150 group"
        >
          <span className="flex items-center gap-2">
            <Search className="w-3.5 h-3.5 text-slate-400 group-hover:text-[#0F9D8A]" />
            <span>Search Barcode, Docket ID, Merchant, City...</span>
          </span>
          <kbd className="hidden sm:inline-flex items-center px-1.5 py-0.5 text-[10px] font-mono text-slate-400 bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded shadow-xs">
            ⌘K
          </kbd>
        </button>
      </div>

      {/* Right Controls */}
      <div className="flex items-center gap-3">
        {/* Backend Target Selector */}
        <div className="hidden md:flex items-center gap-1 p-0.5 rounded-lg bg-slate-100 dark:bg-slate-900 border border-slate-200 dark:border-slate-800 text-[11px] font-medium">
          <button
            type="button"
            onClick={() => handleSwitchTarget('cloud')}
            title="Connect to Render Cloud Production API"
            className={`flex items-center gap-1 px-2.5 py-1 rounded-md transition-all ${
              target === 'cloud'
                ? 'bg-[#0F9D8A] text-white font-bold shadow-xs'
                : 'text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-white'
            }`}
          >
            <Cloud className="w-3 h-3" />
            <span>Render Cloud</span>
          </button>
          <button
            type="button"
            onClick={() => handleSwitchTarget('local')}
            title="Connect to Localhost:3000 API"
            className={`flex items-center gap-1 px-2.5 py-1 rounded-md transition-all ${
              target === 'local'
                ? 'bg-[#10233F] text-white font-bold shadow-xs'
                : 'text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-white'
            }`}
          >
            <Server className="w-3 h-3" />
            <span>Local 3000</span>
          </button>
        </div>

        {/* Live SSE / API Connection Badge */}
        <div
          className={`hidden sm:flex items-center gap-1.5 px-2.5 py-1 rounded-full text-[11px] font-bold border transition-colors ${
            isLive
              ? 'bg-emerald-500/10 border-emerald-500/20 text-emerald-600 dark:text-emerald-400'
              : 'bg-amber-500/10 border-amber-500/20 text-amber-600 dark:text-amber-400'
          }`}
        >
          <span
            className={`w-2 h-2 rounded-full ${
              isLive ? 'bg-emerald-500 animate-pulse' : 'bg-amber-500'
            }`}
          />
          <span>{isLive ? 'Live Sync Active' : 'Connecting...'}</span>
        </div>

        {/* Fast Regulatory Ticker */}
        <div className="hidden xl:flex items-center gap-2 px-3 py-1 rounded-full bg-[#DDF7F1]/80 dark:bg-[#0F9D8A]/10 border border-[#0F9D8A]/20 text-xs text-[#0A6B5E] dark:text-[#57C7A7] font-semibold">
          <ShieldCheck className="w-3.5 h-3.5 text-[#0F9D8A]" />
          <span>Rule 18(2) LM Act Enforcement</span>
        </div>

        {/* Theme Toggle */}
        <Button
          variant="outline"
          size="icon"
          onClick={toggleTheme}
          title={theme === 'dark' ? 'Switch to Light Mode' : 'Switch to Dark Mode'}
          className="rounded-lg h-9 w-9 text-slate-600 dark:text-slate-300"
        >
          {theme === 'dark' ? <Sun className="w-4 h-4 text-amber-400" /> : <Moon className="w-4 h-4 text-slate-600" />}
        </Button>

        {/* Notifications */}
        <div className="relative">
          <Button
            variant="outline"
            size="icon"
            className="rounded-lg h-9 w-9 text-slate-600 dark:text-slate-300 relative"
            title="Notifications"
          >
            <Bell className="w-4 h-4" />
            <span className="absolute top-1.5 right-1.5 w-2 h-2 rounded-full bg-rose-500 animate-pulse" />
          </Button>
        </div>

        {/* Profile Pill */}
        {user ? (
          <div className="flex items-center gap-3 pl-2 border-l border-slate-200 dark:border-slate-800">
            <div className="hidden sm:block text-right">
              <p className="text-xs font-bold text-[#10233F] dark:text-white leading-tight">
                {user.name}
              </p>
              <p className="text-[10px] font-mono text-[#0F9D8A] font-semibold">
                {user.role.replace(/_/g, ' ')}
              </p>
            </div>

            <div className="w-9 h-9 rounded-lg bg-[#10233F] text-white flex items-center justify-center font-bold text-xs shadow-sm overflow-hidden">
              {user.avatarUrl ? (
                <img src={user.avatarUrl} alt={user.name} className="w-full h-full object-cover" />
              ) : (
                <User className="w-4 h-4" />
              )}
            </div>

            <Button
              variant="ghost"
              size="icon"
              onClick={logout}
              title="Sign Out"
              className="text-slate-400 hover:text-rose-600 h-8 w-8"
            >
              <LogOut className="w-4 h-4" />
            </Button>
          </div>
        ) : null}
      </div>
    </header>
  );
};
