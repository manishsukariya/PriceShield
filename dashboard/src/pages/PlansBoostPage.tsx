import React, { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import {
  Zap,
  Shield,
  Clock,
  CheckCircle2,
  Users,
  CreditCard,
  Building2,
  ArrowUpRight,
  TrendingUp,
  FileCheck,
  Send,
  Plus,
} from 'lucide-react';
import { Card, CardHeader, CardTitle, CardContent, CardDescription } from '../components/ui/card';
import { Button } from '../components/ui/button';
import { Badge } from '../components/ui/badge';
import { Modal } from '../components/ui/modal';
import { Input } from '../components/ui/input';
import { CaseStatusBadge } from '../components/cases/CaseStatusBadge';
import { api } from '../lib/api';
import { CaseItem, ProtectionPlan, PlanStats } from '../types';
import { formatCurrency, formatDateTime } from '../lib/utils';

export const PlansBoostPage: React.FC = () => {
  const navigate = useNavigate();
  const [boostedCases, setBoostedCases] = useState<CaseItem[]>([]);
  const [plans, setPlans] = useState<ProtectionPlan[]>([]);
  const [stats, setStats] = useState<PlanStats | null>(null);
  const [loading, setLoading] = useState(true);

  // Grant modal state
  const [grantModalOpen, setGrantModalOpen] = useState(false);
  const [grantEmail, setGrantEmail] = useState('');
  const [grantPlanId, setGrantPlanId] = useState('priceshield_pro');
  const [granting, setGranting] = useState(false);
  const [feedbackMsg, setFeedbackMsg] = useState<string | null>(null);

  const loadData = async () => {
    try {
      const [cases, fetchedPlans, fetchedStats] = await Promise.all([
        api.getCases(),
        api.getPlans(),
        api.getPlanStats(),
      ]);

      const boosted = cases.filter((c) => c.isBoosted);
      setBoostedCases(boosted);
      setPlans(fetchedPlans);
      setStats(fetchedStats);
    } catch (err) {
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadData();

    const handleCaseUpdate = () => {
      loadData();
    };

    window.addEventListener('priceshield_case_updated', handleCaseUpdate);
    return () => {
      window.removeEventListener('priceshield_case_updated', handleCaseUpdate);
    };
  }, []);

  const handleToggleBoost = async (c: CaseItem) => {
    const nextBoostState = !c.isBoosted;
    await api.boostCase(c.id, nextBoostState);
    loadData();
  };

  const handleResolveFromQueue = async (id: string) => {
    await api.updateCaseStatus(
      id,
      'RESOLVED',
      'Priority resolution completed. Complainant refunded via UPI conciliation.'
    );
    loadData();
  };

  const handleGrantPlan = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!grantEmail.trim()) return;

    setGranting(true);
    try {
      await api.grantUserPlan(grantEmail.trim(), grantPlanId);
      setFeedbackMsg(`Successfully granted ${grantPlanId.replace('_', ' ').toUpperCase()} to ${grantEmail}!`);
      setTimeout(() => {
        setGrantModalOpen(false);
        setFeedbackMsg(null);
        setGrantEmail('');
      }, 1500);
      loadData();
    } catch (_) {
      setFeedbackMsg('Failed to grant plan. Please check credentials.');
    } finally {
      setGranting(false);
    }
  };

  return (
    <div className="space-y-8 animate-in fade-in duration-300">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <div className="flex items-center gap-2.5">
            <div className="w-10 h-10 rounded-xl bg-amber-500/10 border border-amber-500/30 flex items-center justify-center text-amber-500 shadow-sm">
              <Zap className="w-5 h-5 fill-amber-500 text-amber-500" />
            </div>
            <div>
              <h1 className="text-2xl font-black tracking-tight text-[#10233F] dark:text-white font-sans flex items-center gap-2">
                Protection Plans & Priority Boost Operations
                <span className="text-xs px-2 py-0.5 rounded-full bg-amber-500/15 text-amber-600 dark:text-amber-400 border border-amber-500/30 font-bold font-mono">
                  SLA COMMAND
                </span>
              </h1>
              <p className="text-xs text-slate-500 dark:text-slate-400 mt-0.5">
                Manage corporate legal Metrology SLAs, 24h fast-track escalation queue, and consumer protection tiers.
              </p>
            </div>
          </div>
        </div>

        <div className="flex items-center gap-3">
          <Button
            variant="primary"
            size="sm"
            onClick={() => setGrantModalOpen(true)}
            className="bg-[#0F9D8A] hover:bg-[#0C8373] text-white font-bold text-xs"
          >
            <Plus className="w-4 h-4 mr-1.5" />
            Grant Plan / Boost Credits
          </Button>
        </div>
      </div>

      {/* Corporate Operational Metrics */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        <Card className="border-amber-200/60 dark:border-amber-900/40 bg-gradient-to-br from-amber-50/50 to-white dark:from-amber-950/20 dark:to-[#0B1528]">
          <CardContent className="p-5 flex items-center justify-between">
            <div>
              <span className="text-xs font-bold text-amber-700 dark:text-amber-400 uppercase tracking-wider block">
                Active Priority Boosts
              </span>
              <p className="text-3xl font-black text-[#10233F] dark:text-white mt-1 font-mono">
                {boostedCases.length}
              </p>
              <span className="text-[11px] text-amber-600 dark:text-amber-400 font-semibold flex items-center gap-1 mt-1">
                <Zap className="w-3 h-3 fill-amber-500" /> 24h Fast-Track Queue
              </span>
            </div>
            <div className="w-12 h-12 rounded-2xl bg-amber-500/10 flex items-center justify-center text-amber-500">
              <Zap className="w-6 h-6 fill-amber-500" />
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardContent className="p-5 flex items-center justify-between">
            <div>
              <span className="text-xs font-semibold text-slate-400 uppercase tracking-wider block">
                24h SLA Adherence
              </span>
              <p className="text-3xl font-black text-emerald-600 mt-1 font-mono">
                {stats?.slaAdherencePercent ?? 98.4}%
              </p>
              <span className="text-[11px] text-emerald-600 font-semibold flex items-center gap-1 mt-1">
                <CheckCircle2 className="w-3 h-3" /> Target Exceeded
              </span>
            </div>
            <div className="w-12 h-12 rounded-2xl bg-emerald-500/10 flex items-center justify-center text-emerald-500">
              <Clock className="w-6 h-6" />
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardContent className="p-5 flex items-center justify-between">
            <div>
              <span className="text-xs font-semibold text-slate-400 uppercase tracking-wider block">
                Active Subscribed Users
              </span>
              <p className="text-3xl font-black text-[#10233F] dark:text-white mt-1 font-mono">
                {stats?.activeSubscribers ?? 108}
              </p>
              <span className="text-[11px] text-slate-500 font-medium mt-1 block">
                Pro & VIP Shield Guardian Tiers
              </span>
            </div>
            <div className="w-12 h-12 rounded-2xl bg-blue-500/10 flex items-center justify-center text-blue-500">
              <Users className="w-6 h-6" />
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardContent className="p-5 flex items-center justify-between">
            <div>
              <span className="text-xs font-semibold text-slate-400 uppercase tracking-wider block">
                Protection Plan MRR
              </span>
              <p className="text-3xl font-black text-[#0F9D8A] mt-1 font-mono">
                {formatCurrency(stats?.monthlyRecurringRevenueRupees ?? 7492)}
              </p>
              <span className="text-[11px] text-slate-500 font-medium flex items-center gap-1 mt-1">
                <TrendingUp className="w-3 h-3 text-[#0F9D8A]" /> +24% MoM Expansion
              </span>
            </div>
            <div className="w-12 h-12 rounded-2xl bg-[#0F9D8A]/10 flex items-center justify-center text-[#0F9D8A]">
              <CreditCard className="w-6 h-6" />
            </div>
          </CardContent>
        </Card>
      </div>

      {/* SECTION 1: Priority Boost SLA Queue */}
      <Card>
        <CardHeader>
          <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
            <div>
              <CardTitle className="text-base flex items-center gap-2">
                <Zap className="w-5 h-5 text-amber-500 fill-amber-500" />
                Priority Boost Escalation Queue (Active Cases)
              </CardTitle>
              <CardDescription className="text-xs">
                Cases boosted by consumers or operations officers requiring mandatory statutory Legal Notice dispatch within 24 hours.
              </CardDescription>
            </div>
            <Badge variant="outline" className="text-xs font-mono font-bold bg-amber-500/10 text-amber-600 border-amber-300">
              {boostedCases.length} CASES IN QUEUE
            </Badge>
          </div>
        </CardHeader>
        <CardContent className="p-0">
          <div className="overflow-x-auto">
            <table className="w-full text-left text-xs border-collapse">
              <thead>
                <tr className="border-b border-slate-200 dark:border-slate-800 bg-slate-50/50 dark:bg-slate-900/50 text-slate-400 font-semibold uppercase tracking-wider">
                  <th className="py-3 px-4">Docket & Complainant</th>
                  <th className="py-3 px-4">Violated Product</th>
                  <th className="py-3 px-4">Overcharge</th>
                  <th className="py-3 px-4">Store / Merchant</th>
                  <th className="py-3 px-4">SLA Deadline</th>
                  <th className="py-3 px-4">Adjudication Status</th>
                  <th className="py-3 px-4 text-right">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100 dark:divide-slate-800">
                {boostedCases.length === 0 ? (
                  <tr>
                    <td colSpan={7} className="py-12 text-center text-slate-400">
                      <div className="flex flex-col items-center justify-center gap-2">
                        <Zap className="w-8 h-8 text-slate-300 dark:text-slate-600" />
                        <p className="font-semibold text-xs text-slate-600 dark:text-slate-300">No active priority boosted cases in queue.</p>
                        <p className="text-[11px] text-slate-400">All consumer complaints are currently progressing under standard statutory SLA.</p>
                      </div>
                    </td>
                  </tr>
                ) : (
                  boostedCases.map((c) => (
                  <tr
                    key={c.id}
                    className="hover:bg-amber-50/30 dark:hover:bg-amber-950/10 transition-colors cursor-pointer"
                    onClick={() => navigate(`/cases/${c.id}`)}
                  >
                    <td className="py-3 px-4">
                      <div className="flex items-center gap-2">
                        <span className="font-mono font-bold text-amber-700 dark:text-amber-400">
                          {c.docketId}
                        </span>
                        <span className="px-1.5 py-0.5 rounded bg-amber-500/20 text-amber-600 dark:text-amber-300 font-extrabold text-[10px]">
                          ⚡ 24H SLA
                        </span>
                      </div>
                      <span className="text-[11px] text-slate-500 block mt-0.5">
                        {c.consumerName} ({c.consumerPhoneMasked})
                      </span>
                    </td>
                    <td className="py-3 px-4 font-semibold text-slate-800 dark:text-slate-200">
                      {c.productName}
                      <span className="text-[10px] text-slate-400 block font-mono">GTIN: {c.barcode}</span>
                    </td>
                    <td className="py-3 px-4">
                      <span className="font-mono font-black text-rose-600 text-sm">
                        +{formatCurrency(c.overchargeAmount)}
                      </span>
                      <span className="text-[10px] text-slate-400 block">
                        MRP {formatCurrency(c.printedMrp)} → {formatCurrency(c.chargedPrice)}
                      </span>
                    </td>
                    <td className="py-3 px-4">
                      <span className="font-semibold text-slate-700 dark:text-slate-300 block">
                        {c.merchantName}
                      </span>
                      <span className="text-[11px] text-slate-400 font-mono">
                        {c.merchantVpa || c.city}
                      </span>
                    </td>
                    <td className="py-3 px-4 font-mono">
                      <div className="flex items-center gap-1.5 text-amber-600 dark:text-amber-400 font-bold">
                        <Clock className="w-3.5 h-3.5" />
                        18h 42m remaining
                      </div>
                      <div className="w-24 h-1.5 bg-slate-100 dark:bg-slate-800 rounded-full mt-1 overflow-hidden">
                        <div className="w-3/4 h-full bg-amber-500 rounded-full" />
                      </div>
                    </td>
                    <td className="py-3 px-4">
                      <CaseStatusBadge status={c.status} size="sm" />
                    </td>
                    <td className="py-3 px-4 text-right" onClick={(e) => e.stopPropagation()}>
                      <div className="flex items-center justify-end gap-1.5">
                        <Button
                          variant="outline"
                          size="sm"
                          onClick={() => handleResolveFromQueue(c.id)}
                          className="h-7 text-[11px] text-emerald-600 hover:text-emerald-700 hover:bg-emerald-50 border-emerald-300"
                        >
                          Resolve & Refund
                        </Button>
                        <Button
                          variant="ghost"
                          size="sm"
                          onClick={() => handleToggleBoost(c)}
                          className="h-7 text-[11px] text-slate-500 hover:text-rose-600"
                          title="Remove from Priority Boost Queue"
                        >
                          De-escalate
                        </Button>
                      </div>
                    </td>
                  </tr>
                )))}
              </tbody>
            </table>
          </div>
        </CardContent>
      </Card>

      {/* SECTION 2: Available Protection Plans & Configuration */}
      <div>
        <div className="mb-4">
          <h2 className="text-lg font-black tracking-tight text-[#10233F] dark:text-white font-sans flex items-center gap-2">
            <Shield className="w-5 h-5 text-[#0F9D8A]" />
            Corporate & Consumer Protection Plan Tiers
          </h2>
          <p className="text-xs text-slate-500 dark:text-slate-400">
            Real-time configuration of grievance SLAs, monthly boost quotas, and pricing.
          </p>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-3 lg:grid-cols-5 gap-4">
          {plans.map((plan) => (
            <div
              key={plan.id}
              className={`rounded-2xl p-5 border flex flex-col justify-between transition-all ${
                plan.isPopular
                  ? 'border-[#0F9D8A] bg-gradient-to-b from-[#0F9D8A]/5 to-transparent shadow-md'
                  : 'border-slate-200 dark:border-slate-800 bg-white dark:bg-[#0B1528]'
              }`}
            >
              <div>
                <div className="flex items-center justify-between mb-2">
                  <span
                    className={`text-[10px] font-extrabold px-2 py-0.5 rounded-full ${
                      plan.isPopular
                        ? 'bg-[#0F9D8A] text-white'
                        : 'bg-slate-100 dark:bg-slate-800 text-slate-600 dark:text-slate-300'
                    }`}
                  >
                    {plan.badge}
                  </span>
                  <span className="text-[10px] text-slate-400 font-mono">
                    {plan.slaTurnaroundHours}h SLA
                  </span>
                </div>

                <h3 className="text-base font-extrabold text-[#10233F] dark:text-white">
                  {plan.name}
                </h3>
                <div className="mt-2 flex items-baseline gap-1 font-mono">
                  <span className="text-2xl font-black text-[#10233F] dark:text-white">
                    {formatCurrency(plan.price)}
                  </span>
                  <span className="text-xs text-slate-400">/{plan.interval}</span>
                </div>
                <p className="text-xs text-slate-500 mt-2 line-clamp-2 leading-relaxed">
                  {plan.description}
                </p>

                <div className="mt-4 pt-4 border-t border-slate-100 dark:border-slate-800 space-y-2 text-xs">
                  {plan.features.map((feat, idx) => (
                    <div key={idx} className="flex items-start gap-1.5 text-slate-700 dark:text-slate-300">
                      <CheckCircle2 className="w-3.5 h-3.5 text-[#0F9D8A] shrink-0 mt-0.5" />
                      <span className="text-[11px] leading-tight">{feat}</span>
                    </div>
                  ))}
                </div>
              </div>

              <div className="mt-6 pt-4 border-t border-slate-100 dark:border-slate-800">
                <Button
                  variant="outline"
                  size="sm"
                  onClick={() => {
                    setGrantPlanId(plan.id);
                    setGrantModalOpen(true);
                  }}
                  className="w-full text-xs font-bold"
                >
                  Grant to User
                </Button>
              </div>
            </div>
          ))}
        </div>
      </div>

      {/* Grant Plan Modal */}
      <Modal
        isOpen={grantModalOpen}
        onClose={() => setGrantModalOpen(false)}
        title="Grant Protection Plan / Boost Credits"
        description="Assign a priority consumer protection tier or merchant dispute escrow to a specific user."
      >
        <form onSubmit={handleGrantPlan} className="space-y-4">
          <div>
            <label className="text-xs font-bold text-slate-700 dark:text-slate-300 block mb-1">
              User Email Address
            </label>
            <Input
              type="email"
              placeholder="e.g. consumer@example.com"
              value={grantEmail}
              onChange={(e) => setGrantEmail(e.target.value)}
              required
            />
          </div>

          <div>
            <label className="text-xs font-bold text-slate-700 dark:text-slate-300 block mb-1">
              Protection Plan Tier
            </label>
            <select
              value={grantPlanId}
              onChange={(e) => setGrantPlanId(e.target.value)}
              className="w-full h-9 text-xs rounded-lg border border-slate-200 dark:border-slate-800 bg-white dark:bg-[#070D19] px-3 font-semibold text-slate-700 dark:text-slate-200 focus:outline-none focus:ring-1 focus:ring-[#0F9D8A]"
            >
              <option value="priceshield_pro">PriceShield Pro (₹49/mo - 3 Priority Boosts)</option>
              <option value="guardian_pro">Shield Guardian VIP (₹149/mo - Unlimited Boosts)</option>
              <option value="verified_merchant">Verified Retailer Shield (₹499/mo)</option>
              <option value="retail_enterprise">Retail Enterprise Chain (₹2,499/mo)</option>
            </select>
          </div>

          {feedbackMsg && (
            <div className="p-3 rounded-lg bg-emerald-50 dark:bg-emerald-950/30 text-emerald-700 dark:text-emerald-300 text-xs font-bold">
              {feedbackMsg}
            </div>
          )}

          <div className="flex justify-end gap-2 pt-2">
            <Button
              type="button"
              variant="outline"
              size="sm"
              onClick={() => setGrantModalOpen(false)}
            >
              Cancel
            </Button>
            <Button
              type="submit"
              variant="primary"
              size="sm"
              disabled={granting}
              className="bg-[#0F9D8A] hover:bg-[#0C8373] text-white font-bold"
            >
              {granting ? 'Granting Tier...' : 'Confirm Tier Grant'}
            </Button>
          </div>
        </form>
      </Modal>
    </div>
  );
};
