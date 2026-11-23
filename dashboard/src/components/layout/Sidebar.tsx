import React from 'react';
import { NavLink } from 'react-router-dom';
import {
  LayoutDashboard,
  FileCheck2,
  Package,
  Layers,
  Store,
  Radio,
  Settings,
  ChevronLeft,
  ChevronRight,
  Shield,
} from 'lucide-react';
import { cn } from '../../lib/utils';

interface SidebarProps {
  collapsed: boolean;
  onToggle: () => void;
}

export const Sidebar: React.FC<SidebarProps> = ({ collapsed, onToggle }) => {
  const navItems = [
    {
      to: '/',
      label: 'Operations Command',
      icon: <LayoutDashboard className="w-4 h-4" />,
      badge: undefined,
    },
    {
      to: '/cases',
      label: 'Complaints & Dockets',
      icon: <FileCheck2 className="w-4 h-4" />,
      badge: undefined,
    },
    {
      to: '/scans',
      label: 'Live Consumer Scans',
      icon: <Radio className="w-4 h-4 text-emerald-500 animate-pulse" />,
      badge: 'LIVE',
      badgeColor: 'bg-emerald-500 text-white font-bold',
    },
    {
      to: '/products',
      label: 'Product Catalog',
      icon: <Package className="w-4 h-4" />,
      badge: undefined,
    },
    {
      to: '/submissions',
      label: 'Community OCR Review',
      icon: <Layers className="w-4 h-4" />,
      badge: '3',
      badgeColor: 'bg-amber-500 text-white',
    },
    {
      to: '/merchants',
      label: 'Merchant Hotspots',
      icon: <Store className="w-4 h-4" />,
      badge: undefined,
    },
    {
      to: '/settings',
      label: 'System & Legal Settings',
      icon: <Settings className="w-4 h-4" />,
      badge: undefined,
    },
  ];

  return (
    <aside
      className={cn(
        'fixed top-0 left-0 z-30 h-screen bg-[#10233F] text-slate-200 transition-all duration-300 ease-in-out border-r border-[#1A335B] flex flex-col',
        collapsed ? 'w-20' : 'w-64'
      )}
    >
      {/* Brand Header */}
      <div className="h-16 px-4 flex items-center justify-between border-b border-[#1A335B]">
        <div className="flex items-center gap-3 overflow-hidden">
          <div className="w-9 h-9 rounded-xl bg-[#0F9D8A] flex items-center justify-center shrink-0 shadow-md">
            <Shield className="w-5 h-5 text-white" />
          </div>
          {!collapsed && (
            <div className="truncate">
              <h1 className="text-base font-black tracking-tight text-white flex items-center gap-1.5 font-sans">
                PriceShield
                <span className="text-[10px] font-bold px-1.5 py-0.5 rounded bg-[#0F9D8A]/30 text-[#57C7A7] border border-[#0F9D8A]/40">
                  OPS
                </span>
              </h1>
              <p className="text-[11px] text-slate-400 truncate">Consumer Protection Console</p>
            </div>
          )}
        </div>

        <button
          onClick={onToggle}
          className="p-1.5 rounded-lg text-slate-400 hover:text-white hover:bg-[#1A335B] transition-colors"
          title={collapsed ? 'Expand Sidebar' : 'Collapse Sidebar'}
        >
          {collapsed ? <ChevronRight className="w-4 h-4" /> : <ChevronLeft className="w-4 h-4" />}
        </button>
      </div>

      {/* Nav List */}
      <div className="flex-1 px-3 py-4 space-y-1.5 overflow-y-auto">
        {!collapsed && (
          <p className="px-3 text-[10px] font-bold uppercase tracking-wider text-slate-400 mb-2">
            Dispute Operations
          </p>
        )}
        {navItems.map((item) => (
          <NavLink
            key={item.to}
            to={item.to}
            end={item.to === '/'}
            className={({ isActive }) =>
              cn(
                'flex items-center gap-3 px-3 py-2.5 rounded-lg text-xs font-semibold transition-all duration-150 group relative',
                isActive
                  ? 'bg-[#0F9D8A] text-white shadow-sm font-bold'
                  : 'text-slate-300 hover:text-white hover:bg-[#1A335B]'
              )
            }
          >
            {({ isActive }) => (
              <>
                <div
                  className={cn(
                    'shrink-0 transition-transform group-hover:scale-110',
                    isActive ? 'text-white' : 'text-slate-400 group-hover:text-slate-200'
                  )}
                >
                  {item.icon}
                </div>
                {!collapsed && <span className="truncate flex-1">{item.label}</span>}
                {!collapsed && item.badge && (
                  <span
                    className={cn(
                      'text-[10px] font-bold px-1.5 py-0.5 rounded-full shrink-0',
                      item.badgeColor || 'bg-slate-700 text-slate-200'
                    )}
                  >
                    {item.badge}
                  </span>
                )}
                {collapsed && (
                  <div className="absolute left-full ml-3 hidden group-hover:flex items-center px-2.5 py-1 bg-slate-900 text-white text-xs rounded-md shadow-lg whitespace-nowrap z-50">
                    {item.label}
                  </div>
                )}
              </>
            )}
          </NavLink>
        ))}
      </div>

      {/* Footer Info Box */}
      {!collapsed ? (
        <div className="p-3 mx-3 mb-4 rounded-xl bg-[#0B192C]/80 border border-[#1A335B] text-xs">
          <div className="flex items-center gap-2 mb-1 text-slate-300">
            <span className="w-2 h-2 rounded-full bg-emerald-400 animate-ping" />
            <span className="font-bold text-[11px] text-white">Dispute Engine Active</span>
          </div>
          <p className="text-[10px] text-slate-400">
            Connected to Render API & Supabase PostgreSQL cluster.
          </p>
        </div>
      ) : (
        <div className="p-3 flex justify-center mb-2">
          <div className="w-2.5 h-2.5 rounded-full bg-emerald-400" title="Engine Online" />
        </div>
      )}
    </aside>
  );
};
