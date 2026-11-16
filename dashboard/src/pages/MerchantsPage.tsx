import React, { useState, useEffect } from 'react';
import {
  Search,
  MapPin,
} from 'lucide-react';
import { Card, CardContent } from '../components/ui/card';
import { Input } from '../components/ui/input';
import { MerchantRiskBadge } from '../components/merchants/MerchantRiskBadge';
import { api } from '../lib/api';
import { MerchantItem } from '../types';
import { formatTimeAgo } from '../lib/utils';

export const MerchantsPage: React.FC = () => {
  const [merchants, setMerchants] = useState<MerchantItem[]>([]);
  const [search, setSearch] = useState('');
  const [selectedRisk, setSelectedRisk] = useState('ALL');

  useEffect(() => {
    const loadData = async () => {
      const list = await api.getMerchants(search, selectedRisk);
      setMerchants(list);
    };
    loadData();
  }, [search, selectedRisk]);

  return (
    <div className="space-y-6 animate-in fade-in duration-300">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-black tracking-tight text-[#10233F] dark:text-white font-sans flex items-center gap-2.5">
            Merchant Watchlist & Compliance Hotspots
            <span className="text-xs font-bold px-2 py-0.5 rounded-full bg-rose-100 text-rose-800 dark:bg-rose-950/60 dark:text-rose-300">
              {merchants.length} Monitored
            </span>
          </h1>
          <p className="text-xs sm:text-sm text-slate-500 dark:text-slate-400 mt-1">
            Store trust scoring, repeat violation tracking, and automated surveillance for Legal Metrology authorities.
          </p>
        </div>
      </div>

      {/* Filter Row */}
      <Card>
        <CardContent className="p-4">
          <div className="flex flex-col sm:flex-row items-center gap-4">
            <div className="flex-1 w-full">
              <Input
                placeholder="Search Store Name, UPI VPA, City, or Address..."
                value={search}
                onChange={(e) => setSearch(e.target.value)}
                icon={<Search className="w-4 h-4 text-slate-400" />}
              />
            </div>

            <div className="flex items-center gap-2 shrink-0 w-full sm:w-auto">
              <span className="text-xs text-slate-500 font-medium shrink-0">Risk Band:</span>
              <select
                value={selectedRisk}
                onChange={(e) => setSelectedRisk(e.target.value)}
                className="h-10 text-xs rounded-lg border border-slate-200 dark:border-slate-800 bg-white dark:bg-[#070D19] px-3 font-semibold text-slate-700 dark:text-slate-200 focus:outline-none focus:ring-2 focus:ring-[#0F9D8A]/30"
              >
                <option value="ALL">All Risk Bands</option>
                <option value="CRITICAL">Critical (Raid Priority)</option>
                <option value="RED">Red (Repeat Offender)</option>
                <option value="AMBER">Amber (Under Surveillance)</option>
                <option value="GREEN">Green (Compliant)</option>
              </select>
            </div>
          </div>
        </CardContent>
      </Card>

      {/* Merchant Table Card */}
      <Card>
        <CardContent className="p-0">
          <div className="overflow-x-auto">
            <table className="w-full text-left text-xs">
              <thead className="bg-slate-50/80 dark:bg-slate-900/60 border-b border-slate-200 dark:border-slate-800 text-slate-500 font-bold uppercase tracking-wider">
                <tr>
                  <th className="py-3.5 px-4">Store & Location</th>
                  <th className="py-3.5 px-4">UPI VPA Identifier</th>
                  <th className="py-3.5 px-4">Trust Score</th>
                  <th className="py-3.5 px-4">Risk Classification</th>
                  <th className="py-3.5 px-4">Total Incidents</th>
                  <th className="py-3.5 px-4">Verified Violations</th>
                  <th className="py-3.5 px-4">Settlement Rate</th>
                  <th className="py-3.5 px-4 text-right">Inspection Action</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100 dark:divide-slate-800/80 font-medium">
                {merchants.map((m) => (
                  <tr key={m.id} className="hover:bg-slate-50/70 dark:hover:bg-slate-900/40 transition-colors">
                    <td className="py-4 px-4">
                      <div>
                        <p className="font-bold text-slate-900 dark:text-white max-w-[220px] truncate">
                          {m.storeName}
                        </p>
                        <p className="text-[11px] text-slate-400 max-w-[220px] truncate mt-0.5">
                          {m.address}
                        </p>
                        <p className="text-[10px] text-slate-400 font-mono">
                          Last Violation: {formatTimeAgo(m.lastIncidentAt)}
                        </p>
                      </div>
                    </td>

                    <td className="py-4 px-4 font-mono font-bold text-[#0F9D8A]">
                      {m.merchantVpa || 'Unregistered VPA'}
                    </td>

                    <td className="py-4 px-4">
                      <div className="flex items-center gap-2">
                        <div className="w-16 h-2 rounded-full bg-slate-200 dark:bg-slate-800 overflow-hidden">
                          <div
                            className={`h-full rounded-full ${
                              m.trustScore >= 70
                                ? 'bg-emerald-500'
                                : m.trustScore >= 45
                                ? 'bg-amber-500'
                                : 'bg-rose-500'
                            }`}
                            style={{ width: `${m.trustScore}%` }}
                          />
                        </div>
                        <span className="font-mono font-bold text-xs">{m.trustScore}/100</span>
                      </div>
                    </td>

                    <td className="py-4 px-4">
                      <MerchantRiskBadge riskBand={m.riskBand} size="sm" />
                    </td>

                    <td className="py-4 px-4 font-mono font-bold">
                      {m.totalComplaintsCount}
                    </td>

                    <td className="py-4 px-4 font-mono text-rose-600 dark:text-rose-400 font-bold">
                      {m.verifiedViolationsCount}
                    </td>

                    <td className="py-4 px-4 font-mono">
                      <span className={m.settlementRate > 50 ? 'text-emerald-600 font-bold' : 'text-slate-500'}>
                        {m.settlementRate}%
                      </span>
                    </td>

                    <td className="py-4 px-4 text-right">
                      <a
                        href={`https://www.google.com/maps/search/?api=1&query=${m.latitude},${m.longitude}`}
                        target="_blank"
                        rel="noreferrer"
                        className="inline-flex items-center gap-1 text-xs text-[#0F9D8A] hover:underline font-semibold"
                      >
                        <MapPin className="w-3.5 h-3.5" />
                        Locate Store
                      </a>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </CardContent>
      </Card>
    </div>
  );
};
