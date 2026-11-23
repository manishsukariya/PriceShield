import React, { useEffect, useState } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import {
  ArrowLeft,
  MapPin,
  ShieldCheck,
  Building2,
  User,
  HandCoins,
  FileDown,
  Eye,
  Clock,
  ScanLine,
} from 'lucide-react';
import { Card, CardHeader, CardTitle, CardContent, CardDescription } from '../components/ui/card';
import { Button } from '../components/ui/button';
import { Badge } from '../components/ui/badge';
import { CaseStatusBadge } from '../components/cases/CaseStatusBadge';
import { ConfidenceBadge } from '../components/cases/ConfidenceBadge';
import { EvidenceInspectorModal } from '../components/cases/EvidenceInspectorModal';
import { SettlementActionModal } from '../components/cases/SettlementActionModal';
import { LegalDocketExportModal } from '../components/cases/LegalDocketExportModal';
import { api } from '../lib/api';
import { CaseItem, CaseStatus } from '../types';
import { formatCurrency, formatDateTime } from '../lib/utils';

export const CaseDetailPage: React.FC = () => {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const [caseItem, setCaseItem] = useState<CaseItem | null>(null);
  const [inspectorOpen, setInspectorOpen] = useState(false);
  const [settlementOpen, setSettlementOpen] = useState(false);
  const [docketOpen, setDocketOpen] = useState(false);
  const [notesInput, setNotesInput] = useState('');
  const [isUpdatingStatus, setIsUpdatingStatus] = useState(false);
  const [toastMsg, setToastMsg] = useState<string | null>(null);

  const showToast = (msg: string) => {
    setToastMsg(msg);
    setTimeout(() => setToastMsg(null), 3500);
  };

  const loadCase = async () => {
    if (!id) return;
    const found = await api.getCaseById(id);
    if (found) {
      setCaseItem(found);
      setNotesInput(found.moderatorNotes || '');
    }
  };

  useEffect(() => {
    loadCase();

    const handleUpdate = (e: any) => {
      const updatedCase = e.detail;
      if (updatedCase && (updatedCase.id === id || updatedCase.docketId === id)) {
        setCaseItem(updatedCase);
        if (updatedCase.moderatorNotes) {
          setNotesInput(updatedCase.moderatorNotes);
        }
        showToast(`⚡ Live Update Received: Case status is now ${updatedCase.status}`);
      }
    };

    window.addEventListener('priceshield_case_updated', handleUpdate);
    return () => {
      window.removeEventListener('priceshield_case_updated', handleUpdate);
    };
  }, [id]);

  if (!caseItem) {
    return (
      <div className="py-16 text-center space-y-4">
        <p className="text-slate-400">Loading complaint case details...</p>
        <Button variant="outline" onClick={() => navigate('/cases')}>
          Return to Cases List
        </Button>
      </div>
    );
  }

  const handleStatusChange = async (newStatus: CaseStatus) => {
    setIsUpdatingStatus(true);
    try {
      const updated = await api.updateCaseStatus(caseItem.id, newStatus, notesInput);
      setCaseItem(updated);
      showToast(`Status updated to ${newStatus.replace(/_/g, ' ')} & broadcast live to mobile app!`);
    } catch (err) {
      console.error(err);
      showToast('Error syncing status update');
    } finally {
      setIsUpdatingStatus(false);
    }
  };

  const handleSettlementConfirm = async (refundAmount: number) => {
    const updated = await api.proposeMerchantSettlement(caseItem.id, refundAmount);
    setCaseItem(updated);
    showToast(`Dispatched ₹${refundAmount} 48h settlement offer to merchant!`);
  };

  return (
    <div className="space-y-6 animate-in fade-in duration-300">
      {/* Top Navigation & Status Bar */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
        <div className="flex items-center gap-3">
          <Button
            variant="outline"
            size="icon"
            onClick={() => navigate('/cases')}
            className="rounded-lg h-9 w-9"
          >
            <ArrowLeft className="w-4 h-4" />
          </Button>
          <div>
            <div className="flex items-center gap-2">
              <h1 className="text-xl sm:text-2xl font-black tracking-tight text-[#10233F] dark:text-white font-mono">
                {caseItem.docketId}
              </h1>
              <ConfidenceBadge confidence={caseItem.confidenceLevel} size="md" />
            </div>
            <p className="text-xs text-slate-500 dark:text-slate-400 mt-0.5">
              Incident Logged on {formatDateTime(caseItem.createdAt)} • Ref: {caseItem.id}
            </p>
          </div>
        </div>

        {/* Operational Actions */}
        <div className="flex flex-wrap items-center gap-2.5">
          <Button
            variant="outline"
            size="sm"
            onClick={() => setInspectorOpen(true)}
            className="font-semibold text-xs"
          >
            <Eye className="w-4 h-4 mr-1.5 text-[#0F9D8A]" />
            Evidence Inspector
          </Button>

          <Button
            variant="secondary"
            size="sm"
            onClick={() => setSettlementOpen(true)}
            className="bg-[#0F9D8A] hover:bg-[#0C8373] text-white font-bold text-xs"
          >
            <HandCoins className="w-4 h-4 mr-1.5" />
            Dispatch 48h Settlement
          </Button>

          <Button
            variant="outline"
            size="sm"
            onClick={() => setDocketOpen(true)}
            className="border-purple-300 text-purple-700 dark:text-purple-300 bg-purple-50 dark:bg-purple-950/40 text-xs font-bold"
          >
            <FileDown className="w-4 h-4 mr-1.5" />
            Official Docket
          </Button>
        </div>
      </div>

      {/* Live Toast Notification Banner */}
      {toastMsg && (
        <div className="p-3.5 rounded-xl bg-[#10233F] text-white text-xs font-bold flex items-center justify-between border border-[#0F9D8A] animate-in fade-in slide-in-from-top-2">
          <div className="flex items-center gap-2">
            <ShieldCheck className="w-4 h-4 text-[#0F9D8A]" />
            <span>{toastMsg}</span>
          </div>
          <span className="text-[10px] text-slate-400 font-mono">LIVE UPDATE DISPATCHED</span>
        </div>
      )}

      {/* Overcharge Callout Hero Card */}
      <div className="p-6 rounded-2xl bg-white dark:bg-[#0B1528] border border-slate-200 dark:border-slate-800 shadow-sm grid grid-cols-1 md:grid-cols-4 gap-6">
        <div>
          <span className="text-xs font-semibold text-slate-400 uppercase tracking-wider block mb-1">
            Product Violated
          </span>
          <h3 className="text-base font-bold text-[#10233F] dark:text-white leading-tight">
            {caseItem.productName}
          </h3>
          <p className="text-xs text-slate-500 font-mono mt-0.5">
            GTIN: {caseItem.barcode} • {caseItem.category}
          </p>
        </div>

        <div>
          <span className="text-xs font-semibold text-slate-400 uppercase tracking-wider block mb-1">
            Statutory Pricing
          </span>
          <div className="flex items-baseline gap-2 font-mono">
            <span className="text-xs text-slate-400 line-through">
              MRP {formatCurrency(caseItem.printedMrp)}
            </span>
            <span className="text-lg font-black text-rose-600">
              Charged {formatCurrency(caseItem.chargedPrice)}
            </span>
          </div>
          <p className="text-[11px] text-slate-500 mt-0.5">
            Quantity: {caseItem.quantity} unit(s) • Total: {formatCurrency(caseItem.totalBasketAmount)}
          </p>
        </div>

        <div>
          <span className="text-xs font-semibold text-slate-400 uppercase tracking-wider block mb-1">
            Total Excess Overcharge
          </span>
          <p className="text-2xl font-black text-rose-600 font-mono">
            +{formatCurrency(caseItem.overchargeAmount)}
          </p>
          <span className="inline-block mt-0.5 text-[10px] font-bold text-rose-700 bg-rose-50 dark:bg-rose-950/50 px-2 py-0.5 rounded border border-rose-200 dark:border-rose-900">
            Rule 18(2) Breach
          </span>
        </div>

        <div className="flex flex-col justify-center border-t md:border-t-0 md:border-l border-slate-100 dark:border-slate-800/80 md:pl-6">
          <span className="text-xs font-semibold text-slate-400 uppercase tracking-wider block mb-1.5">
            Adjudication Status
          </span>
          <div className="flex items-center gap-2">
            <CaseStatusBadge status={caseItem.status} size="md" />
          </div>

          <select
            value={caseItem.status}
            disabled={isUpdatingStatus}
            onChange={(e) => handleStatusChange(e.target.value as CaseStatus)}
            className="mt-2.5 h-8 text-xs font-semibold rounded-md border border-slate-200 dark:border-slate-800 bg-slate-50 dark:bg-slate-900 px-2 text-slate-700 dark:text-slate-200 focus:outline-none focus:ring-1 focus:ring-[#0F9D8A]"
          >
            <option value="PENDING">Set: Pending Review</option>
            <option value="INVESTIGATING">Set: Investigating</option>
            <option value="SETTLEMENT_PROPOSED">Set: Settlement Proposed</option>
            <option value="RESOLVED">Set: Mark Resolved / Refunded</option>
            <option value="ESCALATED_LEGAL_METROLOGY">Set: Escalate to LM Dept</option>
            <option value="REJECTED">Set: Reject / Dismiss Case</option>
          </select>
        </div>
      </div>

      {/* Main 2-Column Workspace */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Left Column (2/3): Dispute Timeline & Evidence Gallery */}
        <div className="lg:col-span-2 space-y-6">
          {/* Dispute Timeline */}
          <Card>
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <Clock className="w-4 h-4 text-[#0F9D8A]" />
                Automated Dispute & Audit Trail
              </CardTitle>
              <CardDescription>
                Immutable timeline tracking consumer submission, optical AI verification, conciliation, and regulatory actions
              </CardDescription>
            </CardHeader>
            <CardContent>
              <div className="relative pl-6 space-y-6 before:absolute before:left-2.5 before:top-2 before:bottom-2 before:w-0.5 before:bg-slate-200 dark:before:bg-slate-800">
                {caseItem.timeline.map((event) => (
                  <div key={event.id} className="relative">
                    {/* Timeline Node Icon */}
                    <div className="absolute -left-6 top-1 w-5 h-5 rounded-full bg-white dark:bg-[#0B1528] border-2 border-[#0F9D8A] flex items-center justify-center">
                      <span className="w-1.5 h-1.5 rounded-full bg-[#0F9D8A]" />
                    </div>

                    <div className="p-3.5 rounded-xl border border-slate-100 dark:border-slate-800/80 bg-slate-50/50 dark:bg-slate-900/40">
                      <div className="flex flex-wrap items-center justify-between gap-2 mb-1">
                        <div className="flex items-center gap-2">
                          <span className="text-xs font-bold text-[#10233F] dark:text-white">
                            {event.title}
                          </span>
                          {event.badge && (
                            <Badge variant="brand" size="sm">
                              {event.badge}
                            </Badge>
                          )}
                        </div>
                        <span className="text-[10px] text-slate-400 font-mono">
                          {formatDateTime(event.timestamp)}
                        </span>
                      </div>

                      <p className="text-xs text-slate-600 dark:text-slate-300 leading-relaxed">
                        {event.description}
                      </p>

                      <p className="text-[10px] text-slate-400 font-mono mt-2">
                        Actor: {event.actorName} ({event.actor})
                      </p>
                    </div>
                  </div>
                ))}
              </div>
            </CardContent>
          </Card>

          {/* Evidence Attachments Grid */}
          <Card>
            <CardHeader className="flex flex-row items-center justify-between pb-3">
              <div>
                <CardTitle className="flex items-center gap-2">
                  <ScanLine className="w-4 h-4 text-[#0F9D8A]" />
                  Cryptographic Evidence Vault
                </CardTitle>
                <CardDescription>
                  {caseItem.evidence.length} validated files stored in tamper-evident Cloudinary storage
                </CardDescription>
              </div>
              <Button variant="ghost" size="sm" onClick={() => setInspectorOpen(true)} className="text-xs text-[#0F9D8A]">
                Side-by-Side View
              </Button>
            </CardHeader>
            <CardContent>
              <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 gap-4">
                {caseItem.evidence.map((ev) => (
                  <div
                    key={ev.id}
                    onClick={() => setInspectorOpen(true)}
                    className="group relative rounded-xl border border-slate-200 dark:border-slate-800 overflow-hidden bg-slate-100 dark:bg-slate-950 cursor-pointer shadow-xs hover:border-[#0F9D8A] transition-all"
                  >
                    <div className="aspect-square relative overflow-hidden">
                      <img
                        src={ev.url}
                        alt={ev.role}
                        className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-200"
                      />
                      <div className="absolute top-2 left-2">
                        <Badge variant="secondary" size="sm" className="bg-slate-900/80 text-white border-none backdrop-blur-xs font-mono">
                          {ev.role.replace(/_/g, ' ')}
                        </Badge>
                      </div>
                    </div>
                    <div className="p-2.5 bg-white dark:bg-[#070D19] border-t border-slate-100 dark:border-slate-800 text-[11px]">
                      {ev.ocrDetectedAmount ? (
                        <p className="font-bold text-emerald-600 dark:text-emerald-400">
                          Detected: {formatCurrency(ev.ocrDetectedAmount)}
                        </p>
                      ) : (
                        <p className="text-slate-500 font-mono">Photo Attachment</p>
                      )}
                      <p className="text-[10px] text-slate-400 font-mono truncate mt-0.5">
                        Hash: {ev.sha256Hash?.substring(0, 14) || 'VERIFIED'}...
                      </p>
                    </div>
                  </div>
                ))}
              </div>
            </CardContent>
          </Card>
        </div>

        {/* Right Column (1/3): Merchant Details, Consumer Details & Moderator Console */}
        <div className="space-y-6">
          {/* Merchant Profile Card */}
          <Card>
            <CardHeader className="pb-3">
              <CardTitle className="text-sm flex items-center gap-2">
                <Building2 className="w-4 h-4 text-[#0F9D8A]" />
                Merchant & Premises Profile
              </CardTitle>
            </CardHeader>
            <CardContent className="space-y-3 text-xs">
              <div>
                <span className="text-slate-400 block font-medium">Store / Business Name</span>
                <span className="text-sm font-bold text-slate-800 dark:text-slate-100">
                  {caseItem.merchantName}
                </span>
              </div>

              <div>
                <span className="text-slate-400 block font-medium">Store Address</span>
                <span className="text-slate-700 dark:text-slate-300 leading-tight">
                  {caseItem.storeAddress}
                </span>
              </div>

              {caseItem.merchantVpa && (
                <div>
                  <span className="text-slate-400 block font-medium">UPI Merchant VPA</span>
                  <span className="font-mono font-bold text-[#0F9D8A]">
                    {caseItem.merchantVpa}
                  </span>
                </div>
              )}

              {caseItem.latitude && caseItem.longitude && (
                <div className="pt-2 border-t border-slate-100 dark:border-slate-800">
                  <a
                    href={`https://www.google.com/maps/search/?api=1&query=${caseItem.latitude},${caseItem.longitude}`}
                    target="_blank"
                    rel="noreferrer"
                    className="inline-flex items-center gap-1.5 text-xs text-[#0F9D8A] hover:underline font-semibold"
                  >
                    <MapPin className="w-3.5 h-3.5" />
                    Open Location in Google Maps
                  </a>
                </div>
              )}
            </CardContent>
          </Card>

          {/* Complainant Profile Card */}
          <Card>
            <CardHeader className="pb-3">
              <CardTitle className="text-sm flex items-center gap-2">
                <User className="w-4 h-4 text-[#0F9D8A]" />
                Verified Complainant
              </CardTitle>
            </CardHeader>
            <CardContent className="space-y-2 text-xs">
              <div>
                <span className="text-slate-400 block">Consumer Name</span>
                <span className="font-bold text-slate-800 dark:text-slate-200">
                  {caseItem.consumerName}
                </span>
              </div>
              <div>
                <span className="text-slate-400 block">Email Address</span>
                <span className="font-mono text-slate-700 dark:text-slate-300">
                  {caseItem.consumerEmail}
                </span>
              </div>
              <div>
                <span className="text-slate-400 block">Phone (Masked)</span>
                <span className="font-mono text-slate-700 dark:text-slate-300">
                  {caseItem.consumerPhoneMasked}
                </span>
              </div>
            </CardContent>
          </Card>

          {/* Moderator Notes Box */}
          <Card>
            <CardHeader className="pb-3">
              <CardTitle className="text-sm flex items-center gap-2">
                <ShieldCheck className="w-4 h-4 text-[#0F9D8A]" />
                Operator Notes & Adjudication
              </CardTitle>
            </CardHeader>
            <CardContent className="space-y-3">
              <textarea
                rows={3}
                placeholder="Enter internal moderation notes or merchant response details..."
                value={notesInput}
                onChange={(e) => setNotesInput(e.target.value)}
                className="w-full text-xs p-3 rounded-lg border border-slate-200 dark:border-slate-800 bg-white dark:bg-[#070D19] focus:outline-none focus:ring-1 focus:ring-[#0F9D8A]"
              />
              <Button
                variant="outline"
                size="sm"
                onClick={() => handleStatusChange(caseItem.status)}
                isLoading={isUpdatingStatus}
                className="w-full font-semibold text-xs"
              >
                Save Moderator Note
              </Button>
            </CardContent>
          </Card>
        </div>
      </div>

      {/* Modals */}
      <EvidenceInspectorModal
        isOpen={inspectorOpen}
        onClose={() => setInspectorOpen(false)}
        caseItem={caseItem}
      />
      <SettlementActionModal
        isOpen={settlementOpen}
        onClose={() => setSettlementOpen(false)}
        caseItem={caseItem}
        onConfirm={handleSettlementConfirm}
      />
      <LegalDocketExportModal
        isOpen={docketOpen}
        onClose={() => setDocketOpen(false)}
        caseItem={caseItem}
      />
    </div>
  );
};
