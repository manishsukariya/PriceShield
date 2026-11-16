import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import {
  Search,
  Filter,
  Eye,
  HandCoins,
  FileDown,
  ExternalLink,
} from 'lucide-react';
import { Card, CardContent } from '../components/ui/card';
import { Button } from '../components/ui/button';
import { Input } from '../components/ui/input';
import { CaseStatusBadge } from '../components/cases/CaseStatusBadge';
import { ConfidenceBadge } from '../components/cases/ConfidenceBadge';
import { EvidenceInspectorModal } from '../components/cases/EvidenceInspectorModal';
import { SettlementActionModal } from '../components/cases/SettlementActionModal';
import { LegalDocketExportModal } from '../components/cases/LegalDocketExportModal';
import { api } from '../lib/api';
import { CaseItem } from '../types';
import { formatCurrency, formatDate } from '../lib/utils';

export const CasesPage: React.FC = () => {
  const [cases, setCases] = useState<CaseItem[]>([]);
  const [search, setSearch] = useState('');
  const [selectedStatus, setSelectedStatus] = useState<string>('ALL');
  const [selectedConfidence, setSelectedConfidence] = useState<string>('ALL');
  const [activeInspectorCase, setActiveInspectorCase] = useState<CaseItem | null>(null);
  const [activeSettlementCase, setActiveSettlementCase] = useState<CaseItem | null>(null);
  const [activeDocketCase, setActiveDocketCase] = useState<CaseItem | null>(null);
  const navigate = useNavigate();

  const loadCases = async () => {
    const list = await api.getCases({
      status: selectedStatus,
      confidenceLevel: selectedConfidence,
      search,
    });
    setCases(list);
  };

  useEffect(() => {
    loadCases();
  }, [selectedStatus, selectedConfidence, search]);

  const handleSettlementConfirm = async (refundAmount: number) => {
    if (!activeSettlementCase) return;
    await api.proposeMerchantSettlement(activeSettlementCase.id, refundAmount);
    await loadCases();
  };

  const statusFilterTabs = [
    { key: 'ALL', label: 'All Cases' },
    { key: 'PENDING', label: 'Pending Review' },
    { key: 'INVESTIGATING', label: 'Investigating' },
    { key: 'SETTLEMENT_PROPOSED', label: 'Settlement Dispatched' },
    { key: 'RESOLVED', label: 'Resolved' },
    { key: 'ESCALATED_LEGAL_METROLOGY', label: 'Escalated to LM' },
    { key: 'REJECTED', label: 'Rejected' },
  ];

  return (
    <div className="space-y-6 animate-in fade-in duration-300">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-black tracking-tight text-[#10233F] dark:text-white font-sans flex items-center gap-2.5">
            Complaints & Regulatory Dockets
            <span className="text-xs font-bold px-2 py-0.5 rounded-full bg-[#DDF7F1] dark:bg-[#0F9D8A]/20 text-[#0F9D8A]">
              {cases.length} Total
            </span>
          </h1>
          <p className="text-xs sm:text-sm text-slate-500 dark:text-slate-400 mt-1">
            Manage consumer overcharging grievances, cryptographic proof audits, and merchant conciliation.
          </p>
        </div>
      </div>

      {/* Filter Tabs Bar */}
      <div className="flex items-center gap-1.5 overflow-x-auto pb-1 border-b border-slate-200 dark:border-slate-800">
        {statusFilterTabs.map((tab) => (
          <button
            key={tab.key}
            onClick={() => setSelectedStatus(tab.key)}
            className={`px-3.5 py-2 text-xs font-semibold rounded-lg whitespace-nowrap transition-all duration-150 ${
              selectedStatus === tab.key
                ? 'bg-[#10233F] dark:bg-[#0F9D8A] text-white shadow-xs'
                : 'text-slate-600 dark:text-slate-400 hover:bg-slate-100 dark:hover:bg-slate-800'
            }`}
          >
            {tab.label}
          </button>
        ))}
      </div>

      {/* Search & Secondary Filter Row */}
      <Card>
        <CardContent className="p-4">
          <div className="flex flex-col md:flex-row items-center gap-4">
            <div className="flex-1 w-full">
              <Input
                placeholder="Search Docket ID, Product Name, Merchant Name, UTR, or City..."
                value={search}
                onChange={(e) => setSearch(e.target.value)}
                icon={<Search className="w-4 h-4 text-slate-400" />}
              />
            </div>

            <div className="flex items-center gap-3 w-full md:w-auto shrink-0">
              <div className="flex items-center gap-2 text-xs text-slate-500 font-medium shrink-0">
                <Filter className="w-3.5 h-3.5" />
                <span>Evidence Tier:</span>
              </div>
              <select
                value={selectedConfidence}
                onChange={(e) => setSelectedConfidence(e.target.value)}
                className="h-10 text-xs rounded-lg border border-slate-200 dark:border-slate-800 bg-white dark:bg-[#070D19] px-3 font-semibold text-slate-700 dark:text-slate-200 focus:outline-none focus:ring-2 focus:ring-[#0F9D8A]/30"
              >
                <option value="ALL">All Confidence Tiers</option>
                <option value="STRONG">Strong (Bill / OCR Verified)</option>
                <option value="BASIC">Basic (UPI + Packet Photo)</option>
                <option value="CORROBORATED">Corroborated (Crowd Verified)</option>
                <option value="UNVERIFIED">Unverified (Advisory Only)</option>
              </select>
            </div>
          </div>
        </CardContent>
      </Card>

      {/* Main Table Card */}
      <Card>
        <CardContent className="p-0">
          <div className="overflow-x-auto">
            <table className="w-full text-left text-xs">
              <thead className="bg-slate-50/80 dark:bg-slate-900/60 border-b border-slate-200 dark:border-slate-800 text-slate-500 font-bold uppercase tracking-wider">
                <tr>
                  <th className="py-3.5 px-4">Docket ID</th>
                  <th className="py-3.5 px-4">Date</th>
                  <th className="py-3.5 px-4">Product & Category</th>
                  <th className="py-3.5 px-4">MRP vs Charged</th>
                  <th className="py-3.5 px-4">Overcharge</th>
                  <th className="py-3.5 px-4">Merchant & Location</th>
                  <th className="py-3.5 px-4">Evidence Tier</th>
                  <th className="py-3.5 px-4">Status</th>
                  <th className="py-3.5 px-4 text-right">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100 dark:divide-slate-800/80 font-medium">
                {cases.map((c) => (
                  <tr
                    key={c.id}
                    className="hover:bg-slate-50/70 dark:hover:bg-slate-900/40 transition-colors group"
                  >
                    <td className="py-4 px-4 font-mono font-bold text-[#10233F] dark:text-slate-200">
                      <button
                        onClick={() => navigate(`/cases/${c.id}`)}
                        className="hover:text-[#0F9D8A] hover:underline flex items-center gap-1 text-left"
                      >
                        {c.docketId}
                        <ExternalLink className="w-3 h-3 opacity-0 group-hover:opacity-100 transition-opacity" />
                      </button>
                    </td>

                    <td className="py-4 px-4 text-slate-500 whitespace-nowrap">
                      {formatDate(c.createdAt)}
                    </td>

                    <td className="py-4 px-4">
                      <p className="font-bold text-slate-900 dark:text-white max-w-[200px] truncate">
                        {c.productName}
                      </p>
                      <p className="text-[10px] text-slate-400 font-mono">
                        {c.barcode} • {c.category}
                      </p>
                    </td>

                    <td className="py-4 px-4 whitespace-nowrap font-mono">
                      <span className="text-slate-500 line-through mr-1">
                        {formatCurrency(c.printedMrp)}
                      </span>
                      <span className="font-bold text-slate-800 dark:text-slate-200">
                        {formatCurrency(c.chargedPrice)}
                      </span>
                      <span className="text-[10px] text-slate-400 block">
                        qty: {c.quantity} unit(s)
                      </span>
                    </td>

                    <td className="py-4 px-4 whitespace-nowrap">
                      <span className="font-black text-rose-600 dark:text-rose-400 bg-rose-50 dark:bg-rose-950/40 px-2 py-0.5 rounded border border-rose-200 dark:border-rose-900">
                        +{formatCurrency(c.overchargeAmount)}
                      </span>
                    </td>

                    <td className="py-4 px-4">
                      <p className="font-bold text-slate-800 dark:text-slate-200 max-w-[180px] truncate">
                        {c.merchantName}
                      </p>
                      <p className="text-[11px] text-slate-400 max-w-[180px] truncate">
                        {c.city}, {c.state}
                      </p>
                    </td>

                    <td className="py-4 px-4 whitespace-nowrap">
                      <ConfidenceBadge confidence={c.confidenceLevel} size="sm" />
                    </td>

                    <td className="py-4 px-4 whitespace-nowrap">
                      <CaseStatusBadge status={c.status} size="sm" />
                    </td>

                    <td className="py-4 px-4 text-right whitespace-nowrap">
                      <div className="flex items-center justify-end gap-1.5">
                        <Button
                          variant="ghost"
                          size="icon"
                          onClick={() => setActiveInspectorCase(c)}
                          title="Inspect Evidence (OCR vs Receipt)"
                          className="h-8 w-8 text-slate-600 dark:text-slate-300 hover:text-[#0F9D8A]"
                        >
                          <Eye className="w-4 h-4" />
                        </Button>

                        <Button
                          variant="ghost"
                          size="icon"
                          onClick={() => setActiveSettlementCase(c)}
                          title="48-Hour Digital Conciliation"
                          className="h-8 w-8 text-[#0F9D8A] hover:bg-[#DDF7F1]/50 dark:hover:bg-[#0F9D8A]/20"
                        >
                          <HandCoins className="w-4 h-4" />
                        </Button>

                        <Button
                          variant="ghost"
                          size="icon"
                          onClick={() => setActiveDocketCase(c)}
                          title="Export Statutory Legal Docket"
                          className="h-8 w-8 text-purple-600 hover:bg-purple-50 dark:hover:bg-purple-950/40"
                        >
                          <FileDown className="w-4 h-4" />
                        </Button>
                      </div>
                    </td>
                  </tr>
                ))}

                {cases.length === 0 && (
                  <tr>
                    <td colSpan={9} className="py-12 text-center text-slate-400">
                      No complaints found matching the selected filters.
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>
        </CardContent>
      </Card>

      {/* Inspector Modal */}
      {activeInspectorCase && (
        <EvidenceInspectorModal
          isOpen={!!activeInspectorCase}
          onClose={() => setActiveInspectorCase(null)}
          caseItem={activeInspectorCase}
        />
      )}

      {/* Settlement Action Modal */}
      {activeSettlementCase && (
        <SettlementActionModal
          isOpen={!!activeSettlementCase}
          onClose={() => setActiveSettlementCase(null)}
          caseItem={activeSettlementCase}
          onConfirm={handleSettlementConfirm}
        />
      )}

      {/* Legal Docket Export Modal */}
      {activeDocketCase && (
        <LegalDocketExportModal
          isOpen={!!activeDocketCase}
          onClose={() => setActiveDocketCase(null)}
          caseItem={activeDocketCase}
        />
      )}
    </div>
  );
};
