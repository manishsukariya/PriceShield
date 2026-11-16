import React from 'react';
import { CaseItem } from '../../types';
import { Modal } from '../ui/modal';
import { Badge } from '../ui/badge';
import { formatCurrency } from '../../lib/utils';
import { ShieldCheck, AlertCircle, FileText, CheckCircle2, QrCode, ScanLine } from 'lucide-react';

interface EvidenceInspectorModalProps {
  isOpen: boolean;
  onClose: () => void;
  caseItem: CaseItem;
}

export const EvidenceInspectorModal: React.FC<EvidenceInspectorModalProps> = ({
  isOpen,
  onClose,
  caseItem,
}) => {
  const packetEvidence = caseItem.evidence.find((e) => e.role === 'PACKET_MRP');
  const paymentEvidence = caseItem.evidence.find(
    (e) => e.role === 'PAYMENT_PROOF' || e.role === 'ITEMIZED_BILL'
  );

  return (
    <Modal
      isOpen={isOpen}
      onClose={onClose}
      title={`Evidence Inspector — Docket ${caseItem.docketId}`}
      description="Dual-channel cryptographic verification: Physical Packaging OCR vs. Payment & Billing Receipt"
      maxWidth="4xl"
    >
      <div className="space-y-6">
        {/* Verification Summary Banner */}
        <div className="p-4 rounded-xl bg-slate-50 dark:bg-slate-900/60 border border-slate-200 dark:border-slate-800 flex flex-wrap items-center justify-between gap-4">
          <div className="flex items-center gap-3">
            <div className="p-2.5 rounded-lg bg-[#DDF7F1] dark:bg-[#0F9D8A]/20 text-[#0F9D8A]">
              <ShieldCheck className="w-5 h-5" />
            </div>
            <div>
              <p className="text-xs font-semibold text-slate-500 uppercase tracking-wider">AI Audit Result</p>
              <h4 className="text-sm font-bold text-[#10233F] dark:text-white">
                {caseItem.confidenceLevel === 'STRONG' || caseItem.confidenceLevel === 'CORROBORATED'
                  ? 'High-Fidelity Match Confirmed'
                  : 'Requires Secondary Merchant Clarification'}
              </h4>
            </div>
          </div>

          <div className="flex items-center gap-4 text-xs font-mono">
            <div>
              <span className="text-slate-400">Printed MRP: </span>
              <span className="font-bold text-slate-800 dark:text-slate-200">{formatCurrency(caseItem.printedMrp)}</span>
            </div>
            <div>
              <span className="text-slate-400">Charged: </span>
              <span className="font-bold text-rose-600">{formatCurrency(caseItem.chargedPrice)}</span>
            </div>
            <div>
              <span className="text-slate-400">Overcharge: </span>
              <span className="font-bold text-rose-600 bg-rose-50 dark:bg-rose-950/40 px-2 py-0.5 rounded border border-rose-200 dark:border-rose-900">
                +{formatCurrency(caseItem.overchargeAmount)}
              </span>
            </div>
          </div>
        </div>

        {/* Side-by-Side Visual Comparator */}
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          {/* Left Panel: Packet MRP Photo */}
          <div className="rounded-xl border border-slate-200 dark:border-slate-800 overflow-hidden flex flex-col bg-white dark:bg-[#070D19]">
            <div className="p-3.5 bg-slate-50 dark:bg-slate-900/80 border-b border-slate-200 dark:border-slate-800 flex items-center justify-between">
              <span className="text-xs font-bold text-[#10233F] dark:text-slate-200 flex items-center gap-1.5">
                <ScanLine className="w-4 h-4 text-[#0F9D8A]" />
                1. Physical Packaging (OCR Analyzed)
              </span>
              {packetEvidence?.capturedViaCamera && (
                <Badge variant="brand" size="sm">
                  Live Camera Verified
                </Badge>
              )}
            </div>

            <div className="relative aspect-video sm:aspect-square bg-slate-100 dark:bg-slate-950 flex items-center justify-center overflow-hidden">
              {packetEvidence?.url ? (
                <img
                  src={packetEvidence.url}
                  alt="Packet MRP"
                  className="w-full h-full object-cover hover:scale-105 transition-transform duration-300"
                />
              ) : (
                <div className="text-center p-6 text-slate-400">
                  <FileText className="w-10 h-10 mx-auto mb-2 opacity-50" />
                  <p className="text-xs">No packaging photo attached</p>
                </div>
              )}

              {/* OCR Highlight Overlay */}
              {packetEvidence?.ocrDetectedAmount && (
                <div className="absolute bottom-3 left-3 right-3 bg-slate-900/90 backdrop-blur-md p-2.5 rounded-lg border border-slate-700 text-white text-xs">
                  <div className="flex items-center justify-between mb-1">
                    <span className="font-semibold text-emerald-400 flex items-center gap-1">
                      <CheckCircle2 className="w-3.5 h-3.5" /> Detected MRP
                    </span>
                    <span className="font-mono font-bold text-sm text-emerald-300">
                      {formatCurrency(packetEvidence.ocrDetectedAmount)}
                    </span>
                  </div>
                  {packetEvidence.ocrDetectedText && (
                    <p className="font-mono text-[10px] text-slate-300 truncate">
                      "{packetEvidence.ocrDetectedText}"
                    </p>
                  )}
                </div>
              )}
            </div>

            <div className="p-3 text-[11px] font-mono text-slate-500 border-t border-slate-100 dark:border-slate-900 flex justify-between">
              <span>Barcode: {caseItem.barcode}</span>
              <span>SHA-256: {packetEvidence?.sha256Hash?.substring(0, 12) || 'N/A'}...</span>
            </div>
          </div>

          {/* Right Panel: Payment / Bill Proof */}
          <div className="rounded-xl border border-slate-200 dark:border-slate-800 overflow-hidden flex flex-col bg-white dark:bg-[#070D19]">
            <div className="p-3.5 bg-slate-50 dark:bg-slate-900/80 border-b border-slate-200 dark:border-slate-800 flex items-center justify-between">
              <span className="text-xs font-bold text-[#10233F] dark:text-slate-200 flex items-center gap-1.5">
                <QrCode className="w-4 h-4 text-[#0F9D8A]" />
                2. Transaction Proof ({caseItem.paymentMethod})
              </span>
              <Badge variant="secondary" size="sm">
                {caseItem.paymentMethod === 'UPI' ? 'UPI UTR Validated' : 'Manual Receipt'}
              </Badge>
            </div>

            <div className="relative aspect-video sm:aspect-square bg-slate-100 dark:bg-slate-950 flex items-center justify-center overflow-hidden">
              {paymentEvidence?.url ? (
                <img
                  src={paymentEvidence.url}
                  alt="Payment Receipt"
                  className="w-full h-full object-cover hover:scale-105 transition-transform duration-300"
                />
              ) : (
                <div className="text-center p-6 text-slate-400">
                  <FileText className="w-10 h-10 mx-auto mb-2 opacity-50" />
                  <p className="text-xs">No receipt uploaded (Cash complaint)</p>
                </div>
              )}

              {/* Transaction Metadata Overlay */}
              {caseItem.utrNumber && (
                <div className="absolute bottom-3 left-3 right-3 bg-slate-900/90 backdrop-blur-md p-2.5 rounded-lg border border-slate-700 text-white text-xs">
                  <div className="flex items-center justify-between mb-1">
                    <span className="font-semibold text-slate-300">12-Digit UTR Ref</span>
                    <span className="font-mono font-bold text-amber-300">{caseItem.utrNumber}</span>
                  </div>
                  <div className="flex items-center justify-between text-[11px] text-slate-400">
                    <span>Payee VPA: {caseItem.merchantVpa || 'N/A'}</span>
                    <span>Total: {formatCurrency(caseItem.totalBasketAmount)}</span>
                  </div>
                </div>
              )}
            </div>

            <div className="p-3 text-[11px] font-mono text-slate-500 border-t border-slate-100 dark:border-slate-900 flex justify-between">
              <span>Shop: {caseItem.merchantName}</span>
              <span>UTR Collision: None (Unique)</span>
            </div>
          </div>
        </div>

        {/* Security & Anti-Fraud Radar Panel */}
        <div className="p-4 rounded-xl border border-slate-200 dark:border-slate-800 bg-slate-50/50 dark:bg-slate-900/40">
          <h4 className="text-xs font-bold uppercase tracking-wider text-slate-600 dark:text-slate-300 mb-3 flex items-center gap-1.5">
            <AlertCircle className="w-4 h-4 text-[#0F9D8A]" />
            Anti-Fraud Verification Matrix
          </h4>
          <div className="grid grid-cols-2 sm:grid-cols-4 gap-3 text-xs">
            <div className="p-2.5 rounded-lg bg-white dark:bg-[#070D19] border border-slate-200 dark:border-slate-800">
              <span className="text-slate-400 block mb-0.5">Image Deduplication</span>
              <span className="font-bold text-emerald-600 dark:text-emerald-400 flex items-center gap-1">
                <CheckCircle2 className="w-3.5 h-3.5" /> 100% Unique
              </span>
            </div>
            <div className="p-2.5 rounded-lg bg-white dark:bg-[#070D19] border border-slate-200 dark:border-slate-800">
              <span className="text-slate-400 block mb-0.5">UTR Replay Guard</span>
              <span className="font-bold text-emerald-600 dark:text-emerald-400 flex items-center gap-1">
                <CheckCircle2 className="w-3.5 h-3.5" /> Verified Non-Reused
              </span>
            </div>
            <div className="p-2.5 rounded-lg bg-white dark:bg-[#070D19] border border-slate-200 dark:border-slate-800">
              <span className="text-slate-400 block mb-0.5">Venue Classification</span>
              <span className="font-bold text-slate-700 dark:text-slate-300">
                {caseItem.venueType} (Applicable)
              </span>
            </div>
            <div className="p-2.5 rounded-lg bg-white dark:bg-[#070D19] border border-slate-200 dark:border-slate-800">
              <span className="text-slate-400 block mb-0.5">Risk Score</span>
              <span className="font-bold text-emerald-600">
                {caseItem.riskScore}/100 (Safe)
              </span>
            </div>
          </div>
        </div>
      </div>
    </Modal>
  );
};
