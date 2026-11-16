import React, { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import {
  Scan,
  AlertTriangle,
  FileCheck2,
  Clock,
  CheckCircle2,
  Store,
  ArrowRight,
  Radio,
  Zap,
} from 'lucide-react';
import { StatCard } from '../components/ui/stat-card';
import { Card, CardHeader, CardTitle, CardContent, CardDescription } from '../components/ui/card';
import { Button } from '../components/ui/button';
import { Badge } from '../components/ui/badge';
import { api } from '../lib/api';
import { DashboardMetrics, ScanFeedItem, CaseItem } from '../types';
import { formatCurrency, formatTimeAgo } from '../lib/utils';
import { CaseStatusBadge } from '../components/cases/CaseStatusBadge';
import { ConfidenceBadge } from '../components/cases/ConfidenceBadge';
import {
  AreaChart,
  Area,
  BarChart,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
} from 'recharts';

export const OverviewPage: React.FC = () => {
  const [metrics, setMetrics] = useState<DashboardMetrics | null>(null);
  const [liveScans, setLiveScans] = useState<ScanFeedItem[]>([]);
  const [recentCases, setRecentCases] = useState<CaseItem[]>([]);
  const navigate = useNavigate();

  useEffect(() => {
    const loadData = async () => {
      const [m, scans, cases] = await Promise.all([
        api.getMetrics(),
        api.getLiveScans(),
        api.getCases(),
      ]);
      setMetrics(m);
      setLiveScans(scans);
      setRecentCases(cases.slice(0, 4));
    };
    loadData();

    // Polling simulation for live scans
    const interval = setInterval(async () => {
      const scans = await api.getLiveScans();
      setLiveScans(scans);
    }, 12000);
    return () => clearInterval(interval);
  }, []);

  const chartData = [
    { day: 'Mon', scans: 920, violations: 74 },
    { day: 'Tue', scans: 1150, violations: 88 },
    { day: 'Wed', scans: 1040, violations: 69 },
    { day: 'Thu', scans: 1320, violations: 110 },
    { day: 'Fri', scans: 1480, violations: 135 },
    { day: 'Sat', scans: 1820, violations: 172 },
    { day: 'Sun', scans: 1650, violations: 145 },
  ];

  const categoryData = [
    { category: 'Beverages / Drinks', incidents: 142 },
    { category: 'Dairy & Milk', incidents: 86 },
    { category: 'Snacks & Chips', incidents: 48 },
    { category: 'Instant Foods', incidents: 24 },
    { category: 'Personal Care', incidents: 12 },
  ];

  return (
    <div className="space-y-8 animate-in fade-in duration-300">
      {/* Top Banner / Hero Bar */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 p-6 rounded-2xl bg-gradient-to-r from-[#10233F] via-[#1A335B] to-[#0B192C] text-white shadow-premium">
        <div>
          <div className="flex items-center gap-2 mb-2">
            <span className="px-2 py-0.5 rounded-full text-[10px] font-bold bg-[#0F9D8A] text-white tracking-wider uppercase">
              Operational Command Center
            </span>
            <span className="flex items-center gap-1.5 text-xs text-emerald-400 font-mono">
              <span className="w-2 h-2 rounded-full bg-emerald-400 animate-ping" />
              Live Stream Active
            </span>
          </div>
          <h1 className="text-2xl sm:text-3xl font-black tracking-tight text-white font-sans">
            PriceShield Intelligence & Enforcement
          </h1>
          <p className="text-xs sm:text-sm text-slate-300 max-w-2xl mt-1">
            Autonomous Consumer Dispute Resolution (ADR) & statutory Legal Metrology monitoring across retail FMCG markets.
          </p>
        </div>

        <div className="flex items-center gap-3 shrink-0">
          <Button
            variant="secondary"
            onClick={() => navigate('/cases')}
            className="bg-[#0F9D8A] hover:bg-[#0C8373] text-white font-bold shadow-md"
          >
            <Zap className="w-4 h-4 mr-1.5" />
            Review 14 Pending Cases
          </Button>
          <Button
            variant="outline"
            onClick={() => navigate('/merchants')}
            className="border-slate-600 text-white bg-white/10 hover:bg-white/20"
          >
            <Store className="w-4 h-4 mr-1.5" />
            Merchant Hotspots
          </Button>
        </div>
      </div>

      {/* KPI Cards Grid */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-5">
        <StatCard
          title="Scans Today"
          value={metrics ? metrics.totalScansToday.toLocaleString('en-IN') : '1,420'}
          subtitle={`38,450 this month`}
          trend={{ value: 18.4, isPositive: true }}
          icon={<Scan className="w-5 h-5" />}
          variant="brand"
        />

        <StatCard
          title="Overcharges Flagged"
          value={metrics ? `${metrics.overchargeRatePercent}%` : '8.1%'}
          subtitle="312 incidents verified"
          trend={{ value: 2.1, isPositive: false }}
          icon={<AlertTriangle className="w-5 h-5" />}
          variant="danger"
        />

        <StatCard
          title="Consumer Restitution"
          value={metrics ? formatCurrency(metrics.totalRecoveredRupees) : '₹1,21,500'}
          subtitle="Recovered through 48h settlement"
          trend={{ value: 34.2, isPositive: true }}
          icon={<CheckCircle2 className="w-5 h-5" />}
          variant="brand"
        />

        <StatCard
          title="Resolution SLA"
          value={metrics ? `${metrics.avgResolutionHours}h` : '28.5h'}
          subtitle="vs. 45-day NCH average"
          trend={{ value: 14.5, isPositive: true }}
          icon={<Clock className="w-5 h-5" />}
          variant="default"
        />
      </div>

      {/* Visual Analytics Grid */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Scans & Overcharges Area Chart */}
        <Card className="lg:col-span-2">
          <CardHeader className="flex flex-row items-center justify-between pb-4">
            <div>
              <CardTitle>Daily Scan Inflow vs. Overcharge Violations</CardTitle>
              <CardDescription>7-day trajectory of consumer scans and detected pricing violations</CardDescription>
            </div>
            <div className="flex items-center gap-3 text-xs">
              <span className="flex items-center gap-1.5 text-slate-500 font-medium">
                <span className="w-3 h-3 rounded-full bg-[#10233F] dark:bg-slate-400 inline-block" /> Scans
              </span>
              <span className="flex items-center gap-1.5 text-slate-500 font-medium">
                <span className="w-3 h-3 rounded-full bg-[#0F9D8A] inline-block" /> Overcharges
              </span>
            </div>
          </CardHeader>
          <CardContent className="h-72">
            <ResponsiveContainer width="100%" height="100%">
              <AreaChart data={chartData} margin={{ top: 10, right: 10, left: -20, bottom: 0 }}>
                <defs>
                  <linearGradient id="scansGrad" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="5%" stopColor="#10233F" stopOpacity={0.2} />
                    <stop offset="95%" stopColor="#10233F" stopOpacity={0} />
                  </linearGradient>
                  <linearGradient id="violationsGrad" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="5%" stopColor="#0F9D8A" stopOpacity={0.4} />
                    <stop offset="95%" stopColor="#0F9D8A" stopOpacity={0} />
                  </linearGradient>
                </defs>
                <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="#E2E8F0" opacity={0.6} />
                <XAxis dataKey="day" tick={{ fontSize: 12, fill: '#64748B' }} axisLine={false} tickLine={false} />
                <YAxis tick={{ fontSize: 12, fill: '#64748B' }} axisLine={false} tickLine={false} />
                <Tooltip
                  contentStyle={{
                    backgroundColor: '#0F172A',
                    borderRadius: '8px',
                    border: 'none',
                    color: '#fff',
                    fontSize: '12px',
                  }}
                />
                <Area type="monotone" dataKey="scans" stroke="#10233F" strokeWidth={2} fillOpacity={1} fill="url(#scansGrad)" />
                <Area type="monotone" dataKey="violations" stroke="#0F9D8A" strokeWidth={2} fillOpacity={1} fill="url(#violationsGrad)" />
              </AreaChart>
            </ResponsiveContainer>
          </CardContent>
        </Card>

        {/* Top Offending Categories Bar Chart */}
        <Card>
          <CardHeader>
            <CardTitle>Top Overcharged Categories</CardTitle>
            <CardDescription>Highest frequency of cooling & shelf surcharges</CardDescription>
          </CardHeader>
          <CardContent className="h-72">
            <ResponsiveContainer width="100%" height="100%">
              <BarChart data={categoryData} layout="vertical" margin={{ top: 10, right: 20, left: 30, bottom: 0 }}>
                <CartesianGrid strokeDasharray="3 3" horizontal={false} stroke="#E2E8F0" opacity={0.6} />
                <XAxis type="number" tick={{ fontSize: 11, fill: '#64748B' }} axisLine={false} tickLine={false} />
                <YAxis dataKey="category" type="category" tick={{ fontSize: 11, fill: '#64748B' }} width={90} axisLine={false} tickLine={false} />
                <Tooltip
                  formatter={(val: number) => [`${val} Incidents`, 'Violations']}
                  contentStyle={{
                    backgroundColor: '#0F172A',
                    borderRadius: '8px',
                    border: 'none',
                    color: '#fff',
                    fontSize: '12px',
                  }}
                />
                <Bar dataKey="incidents" fill="#0F9D8A" radius={[0, 6, 6, 0]} />
              </BarChart>
            </ResponsiveContainer>
          </CardContent>
        </Card>
      </div>

      {/* Operations Bottom Grid: Live Scanner Ticker & Recent Verified Dockets */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Live Scanner Stream */}
        <Card className="lg:col-span-1">
          <CardHeader className="flex flex-row items-center justify-between pb-3">
            <div>
              <CardTitle className="flex items-center gap-2">
                <Radio className="w-4 h-4 text-emerald-500 animate-pulse" />
                Live Consumer Ticker
              </CardTitle>
              <CardDescription>Streaming scans from Android & iOS apps</CardDescription>
            </div>
            <Button variant="ghost" size="sm" onClick={() => navigate('/scans')} className="text-xs text-[#0F9D8A]">
              View All
            </Button>
          </CardHeader>
          <CardContent className="space-y-3">
            {liveScans.slice(0, 5).map((scan) => (
              <div
                key={scan.id}
                className="p-3 rounded-lg border border-slate-100 dark:border-slate-800/80 bg-slate-50/50 dark:bg-slate-900/40 hover:bg-white dark:hover:bg-[#070D19] transition-all flex items-start justify-between gap-3 text-xs"
              >
                <div>
                  <p className="font-bold text-[#10233F] dark:text-white leading-tight">
                    {scan.productName}
                  </p>
                  <p className="text-[11px] text-slate-500 dark:text-slate-400 mt-0.5">
                    {scan.storeName} ({scan.city})
                  </p>
                  <p className="text-[10px] text-slate-400 font-mono mt-1">
                    {formatTimeAgo(scan.timestamp)} via {scan.devicePlatform}
                  </p>
                </div>

                <div className="text-right shrink-0">
                  {scan.isOvercharged ? (
                    <Badge variant="danger" size="sm" className="font-bold">
                      +{formatCurrency(scan.overcharge)}
                    </Badge>
                  ) : (
                    <Badge variant="success" size="sm">
                      Within MRP
                    </Badge>
                  )}
                  <p className="text-[11px] font-mono text-slate-500 mt-1">
                    ₹{scan.chargedPrice.toFixed(0)} / ₹{scan.printedMrp.toFixed(0)}
                  </p>
                </div>
              </div>
            ))}
          </CardContent>
        </Card>

        {/* Priority Action Cases Table */}
        <Card className="lg:col-span-2">
          <CardHeader className="flex flex-row items-center justify-between pb-3">
            <div>
              <CardTitle className="flex items-center gap-2">
                <FileCheck2 className="w-4 h-4 text-[#0F9D8A]" />
                Priority Cases Requiring Action
              </CardTitle>
              <CardDescription>Verified complaints awaiting settlement dispatch or legal filing</CardDescription>
            </div>
            <Button variant="ghost" size="sm" onClick={() => navigate('/cases')} className="text-xs text-[#0F9D8A]">
              Full Queue ({recentCases.length}) <ArrowRight className="w-3.5 h-3.5 ml-1" />
            </Button>
          </CardHeader>
          <CardContent>
            <div className="overflow-x-auto">
              <table className="w-full text-left text-xs">
                <thead>
                  <tr className="border-b border-slate-100 dark:border-slate-800 text-slate-400 uppercase tracking-wider font-semibold">
                    <th className="pb-3">Docket ID</th>
                    <th className="pb-3">Product / Store</th>
                    <th className="pb-3">Overcharge</th>
                    <th className="pb-3">Evidence Tier</th>
                    <th className="pb-3">Status</th>
                    <th className="pb-3 text-right">Action</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-100 dark:divide-slate-800/60 font-medium">
                  {recentCases.map((c) => (
                    <tr key={c.id} className="hover:bg-slate-50/80 dark:hover:bg-slate-900/50 transition-colors">
                      <td className="py-3 font-mono font-bold text-[#10233F] dark:text-slate-200">
                        {c.docketId}
                      </td>
                      <td className="py-3">
                        <p className="font-bold text-slate-900 dark:text-white truncate max-w-[180px]">
                          {c.productName}
                        </p>
                        <p className="text-[11px] text-slate-400 truncate max-w-[180px]">
                          {c.merchantName} ({c.city})
                        </p>
                      </td>
                      <td className="py-3">
                        <span className="font-bold text-rose-600 dark:text-rose-400">
                          +{formatCurrency(c.overchargeAmount)}
                        </span>
                        <span className="text-[10px] text-slate-400 block font-mono">
                          {c.quantity} unit(s)
                        </span>
                      </td>
                      <td className="py-3">
                        <ConfidenceBadge confidence={c.confidenceLevel} size="sm" />
                      </td>
                      <td className="py-3">
                        <CaseStatusBadge status={c.status} size="sm" />
                      </td>
                      <td className="py-3 text-right">
                        <Button
                          variant="outline"
                          size="sm"
                          onClick={() => navigate(`/cases/${c.id}`)}
                          className="h-7 text-xs font-semibold"
                        >
                          Inspect Case
                        </Button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </CardContent>
        </Card>
      </div>
    </div>
  );
};
