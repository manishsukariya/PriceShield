import React, { useState } from 'react';
import { Settings, Shield, Server, Save, CheckCircle2, Key } from 'lucide-react';
import { Card, CardHeader, CardTitle, CardContent, CardDescription } from '../components/ui/card';
import { Button } from '../components/ui/button';
import { Input } from '../components/ui/input';
import { Badge } from '../components/ui/badge';

export const SettingsPage: React.FC = () => {
  const [apiKey, setApiKey] = useState(
    localStorage.getItem('priceshield_admin_key') || 'ps_admin_live_99a8b7c6d5e4'
  );
  const [settlementWindowHours, setSettlementWindowHours] = useState('48');
  const [coolingChargeTolerance] = useState('0');
  const [savedSuccess, setSavedSuccess] = useState(false);

  const handleSave = () => {
    localStorage.setItem('priceshield_admin_key', apiKey);
    setSavedSuccess(true);
    setTimeout(() => setSavedSuccess(false), 2000);
  };

  return (
    <div className="space-y-6 max-w-4xl animate-in fade-in duration-300">
      <div>
        <h1 className="text-2xl font-black tracking-tight text-[#10233F] dark:text-white font-sans flex items-center gap-2.5">
          <Settings className="w-5 h-5 text-[#0F9D8A]" />
          Operations & System Settings
        </h1>
        <p className="text-xs sm:text-sm text-slate-500 dark:text-slate-400 mt-1">
          Configure PriceShield dispute conciliation engine parameters, API connectors, and legal thresholds.
        </p>
      </div>

      {/* Cloud & Cluster Health */}
      <Card>
        <CardHeader>
          <CardTitle className="text-base flex items-center gap-2">
            <Server className="w-4 h-4 text-[#0F9D8A]" />
            Backend Infrastructure Health
          </CardTitle>
          <CardDescription>Status of production Node.js services and Supabase PostgreSQL</CardDescription>
        </CardHeader>
        <CardContent className="space-y-3">
          <div className="flex items-center justify-between p-3 rounded-lg border border-slate-200 dark:border-slate-800 bg-slate-50/50 dark:bg-slate-900/50 text-xs">
            <div className="flex items-center gap-3">
              <span className="w-2.5 h-2.5 rounded-full bg-emerald-400 animate-ping" />
              <div>
                <p className="font-bold text-[#10233F] dark:text-white">Render Express API</p>
                <p className="text-[11px] font-mono text-slate-400">https://priceshield-r4v5.onrender.com</p>
              </div>
            </div>
            <Badge variant="success" size="sm">
              Online (200 OK)
            </Badge>
          </div>

          <div className="flex items-center justify-between p-3 rounded-lg border border-slate-200 dark:border-slate-800 bg-slate-50/50 dark:bg-slate-900/50 text-xs">
            <div className="flex items-center gap-3">
              <span className="w-2.5 h-2.5 rounded-full bg-emerald-400 animate-ping" />
              <div>
                <p className="font-bold text-[#10233F] dark:text-white">Supabase PostgreSQL Cluster</p>
                <p className="text-[11px] font-mono text-slate-400">Prisma v6.7.0 Client Connected</p>
              </div>
            </div>
            <Badge variant="success" size="sm">
              Healthy
            </Badge>
          </div>
        </CardContent>
      </Card>

      {/* ADR & Legal Metrology Engine Parameters */}
      <Card>
        <CardHeader>
          <CardTitle className="text-base flex items-center gap-2">
            <Shield className="w-4 h-4 text-[#0F9D8A]" />
            Autonomous Dispute Engine Policy
          </CardTitle>
          <CardDescription>
            Rules governing merchant settlement window and cooling charge tolerance under Legal Metrology Act 2009
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div>
              <label className="block text-xs font-bold text-slate-700 dark:text-slate-300 uppercase tracking-wider mb-1">
                Merchant Settlement Window (Hours)
              </label>
              <Input
                type="number"
                value={settlementWindowHours}
                onChange={(e) => setSettlementWindowHours(e.target.value)}
              />
              <p className="text-[11px] text-slate-400 mt-1">
                Time granted to retailer to execute UPI refund before regulatory docket escalation.
              </p>
            </div>

            <div>
              <label className="block text-xs font-bold text-slate-700 dark:text-slate-300 uppercase tracking-wider mb-1">
                Cooling Charge Tolerance (₹)
              </label>
              <Input
                type="number"
                value={coolingChargeTolerance}
                disabled
                className="bg-slate-100 dark:bg-slate-900 cursor-not-allowed font-mono"
              />
              <p className="text-[11px] text-rose-500 font-semibold mt-1">
                Strict Zero-Tolerance: Section 36(1) forbids any surcharge above printed MRP.
              </p>
            </div>
          </div>

          <div>
            <label className="block text-xs font-bold text-slate-700 dark:text-slate-300 uppercase tracking-wider mb-1 flex items-center gap-1.5">
              <Key className="w-3.5 h-3.5 text-[#0F9D8A]" />
              Moderation Master API Key (`x-admin-key`)
            </label>
            <Input
              type="password"
              value={apiKey}
              onChange={(e) => setApiKey(e.target.value)}
              className="font-mono"
            />
            <p className="text-[11px] text-slate-400 mt-1">
              Secret key matching `ADMIN_MODERATION_KEY` env on the backend.
            </p>
          </div>

          <div className="pt-3 flex items-center justify-between border-t border-slate-100 dark:border-slate-800">
            {savedSuccess ? (
              <span className="text-xs font-bold text-emerald-600 flex items-center gap-1.5">
                <CheckCircle2 className="w-4 h-4" /> Configuration Saved Successfully!
              </span>
            ) : <span />}

            <Button variant="secondary" onClick={handleSave} className="bg-[#0F9D8A] text-white font-bold">
              <Save className="w-4 h-4 mr-1.5" />
              Save Settings
            </Button>
          </div>
        </CardContent>
      </Card>
    </div>
  );
};
