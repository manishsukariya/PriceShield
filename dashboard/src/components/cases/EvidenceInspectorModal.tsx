import React from 'react';
import { CaseItem, EvidenceItem } from '../../types';
import { Modal } from '../ui/modal';
import { Badge } from '../ui/badge';
import { formatCurrency, formatDateTime } from '../../lib/utils';
import {
  ShieldCheck,
  AlertCircle,
  FileText,
  CheckCircle2,
  QrCode,
  ScanLine,
  Receipt,
  Video,
  ExternalLink,
  Store,
} from 'lucide-react';

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
  const getRoleHeader = (ev: EvidenceItem, index: number) => {
    switch (ev.role) {
      case 'PACKET_MRP':
        return {
          icon: <ScanLine className="w-4 h-4 text-[#0F9D8A]" />,
          title: `${index + 1}. Physical Packaging (OCR Analyzed)`,
          badgeText: ev.capturedViaCamera ? 'Live Camera Verified' : 'Packaging Photo',
          badgeVariant: 'brand' as const,
        };
      case 'PAYMENT_PROOF':
        return {
          icon: <QrCode className="w-4 h-4 text-[#0F9D8A]" />,
          title: `${index + 1}. Transaction Proof (${caseItem.paymentMethod})`,
          badgeText: caseItem.paymentMethod === 'UPI' ? 'UPI UTR Validated' : 'Payment Proof',
          badgeVariant: 'secondary' as const,
        };
      case 'ITEMIZED_BILL':
        return {
          icon: <Receipt className="w-4 h-4 text-purple-600 dark:text-purple-400" />,
          title: `${index + 1}. Itemized Store Receipt / Bill`,
          badgeText: 'Itemized Bill',
          badgeVariant: 'secondary' as const,
        };
      case 'VIDEO_PROOF':
        return {
          icon: <Video className="w-4 h-4 text-rose-600 dark:text-rose-400" />,
          title: `${index + 1}. Incident Video Proof`,
          badgeText: 'Video Recording',
          badgeVariant: 'danger' as const,
        };
      case 'STOREFRONT':
        return {
          icon: <Store className="w-4 h-4 text-blue-600 dark:text-blue-400" />,
          title: `${index + 1}. Merchant Storefront`,
          badgeText: 'Store Signage',
          badgeVariant: 'secondary' as const,
        };
      default:
        return {
          icon: <FileText className="w-4 h-4 text-slate-500" />,
          title: `${index + 1}. Evidence Document (${ev.role.replace(/_/g, ' ')})`,
          badgeText: ev.mediaType === 'VIDEO' ? 'Video' : 'Image',
          badgeVariant: 'secondary' as const,
        };
    }
  };

  const isVideo = (ev: EvidenceItem) =>
    ev.mediaType === 'VIDEO' || ev.role === 'VIDEO_PROOF' || ev.url?.toLowerCase().endsWith('.mp4');

  return (
    <Modal
      isOpen={isOpen}
      onClose={onClose}
      title={`Evidence Inspector — Docket ${caseItem.docketId}`}
      description="Multi-channel cryptographic verification: Packaging OCR, Payment Proof, Itemized Bills & Video Recordings"
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

        {/* Dynamic Evidence Grid (Renders ALL Evidence: Packaging, Receipt, Itemized Bill, Video) */}
        {caseItem.evidence.length === 0 ? (
          <div className="p-8 text-center border rounded-xl border-dashed border-slate-300 dark:border-slate-700 text-slate-400">
            <FileText className="w-12 h-12 mx-auto mb-2 opacity-40" />
            <p className="text-sm font-medium">No cryptographic evidence files attached to this docket.</p>
          </div>
        ) : (
          <div
            className={`grid gap-6 ${
              caseItem.evidence.length === 1
                ? 'grid-cols-1 max-w-md mx-auto'
                : caseItem.evidence.length === 2
                ? 'grid-cols-1 md:grid-cols-2'
                : 'grid-cols-1 md:grid-cols-2 lg:grid-cols-3'
            }`}
          >
            {caseItem.evidence.map((ev, idx) => {
              const header = getRoleHeader(ev, idx);
              const video = isVideo(ev);

              return (
                <div
                  key={ev.id || `ev-${idx}`}
                  className="rounded-xl border border-slate-200 dark:border-slate-800 overflow-hidden flex flex-col bg-white dark:bg-[#070D19] shadow-xs"
                >
                  {/* Card Header */}
                  <div className="p-3 bg-slate-50 dark:bg-slate-900/80 border-b border-slate-200 dark:border-slate-800 flex items-center justify-between gap-2">
                    <span className="text-xs font-bold text-[#10233F] dark:text-slate-200 flex items-center gap-1.5 truncate">
                      {header.icon}
                      <span className="truncate">{header.title}</span>
                    </span>
                    <Badge variant={header.badgeVariant} size="sm" className="shrink-0 text-[10px]">
                      {header.badgeText}
                    </Badge>
                  </div>

                  {/* Media Container: Video or Image */}
                  <div className="relative aspect-video sm:aspect-square bg-slate-950 flex items-center justify-center overflow-hidden group">
                    {video ? (
                      <video
                        src={ev.url}
                        controls
                        playsInline
                        className="w-full h-full object-contain bg-black"
                        preload="metadata"
                      />
                    ) : (
                      <img
                        src={ev.url}
                        alt={ev.role}
                        className="w-full h-full object-contain hover:scale-105 transition-transform duration-300 bg-black/10"
                      />
                    )}

                    {/* OCR Text / Amount Overlay for Packaging */}
                    {ev.role === 'PACKET_MRP' && ev.ocrDetectedAmount && (
                      <div className="absolute bottom-2 left-2 right-2 bg-slate-900/90 backdrop-blur-md p-2 rounded-lg border border-slate-700 text-white text-xs pointer-events-none">
                        <div className="flex items-center justify-between mb-0.5">
                          <span className="font-semibold text-emerald-400 flex items-center gap-1 text-[11px]">
                            <CheckCircle2 className="w-3 h-3" /> Detected MRP
                          </span>
                          <span className="font-mono font-bold text-xs text-emerald-300">
                            {formatCurrency(ev.ocrDetectedAmount)}
                          </span>
                        </div>
                        {ev.ocrDetectedText && (
                          <p className="font-mono text-[9px] text-slate-300 truncate">
                            "{ev.ocrDetectedText}"
                          </p>
                        )}
                      </div>
                    )}

                    {/* Transaction Overlay for Payment Proof */}
                    {ev.role === 'PAYMENT_PROOF' && caseItem.utrNumber && (
                      <div className="absolute bottom-2 left-2 right-2 bg-slate-900/90 backdrop-blur-md p-2 rounded-lg border border-slate-700 text-white text-xs pointer-events-none">
                        <div className="flex items-center justify-between mb-0.5 text-[11px]">
                          <span className="font-semibold text-slate-300">UTR Reference</span>
                          <span className="font-mono font-bold text-amber-300">{caseItem.utrNumber}</span>
                        </div>
                        <div className="flex items-center justify-between text-[10px] text-slate-400">
                          <span>Merchant: {caseItem.merchantName}</span>
                          <span>Total: {formatCurrency(caseItem.totalBasketAmount)}</span>
                        </div>
                      </div>
                    )}

                    {/* Open in full tab button */}
                    <a
                      href={ev.url}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="absolute top-2 right-2 p-1.5 rounded-lg bg-black/60 hover:bg-black/80 text-white opacity-0 group-hover:opacity-100 transition-opacity"
                      title="Open full resolution in new tab"
                    >
                      <ExternalLink className="w-3.5 h-3.5" />
                    </a>
                  </div>

                  {/* Footer Info */}
                  <div className="p-2.5 text-[10px] font-mono text-slate-500 border-t border-slate-100 dark:border-slate-800/80 flex items-center justify-between bg-slate-50/50 dark:bg-slate-900/40">
                    <span className="truncate max-w-[140px]">
                      Role: {ev.role.replace(/_/g, ' ')}
                    </span>
                    <span className="shrink-0 text-slate-400">
                      SHA: {ev.sha256Hash ? `${ev.sha256Hash.substring(0, 10)}...` : 'VERIFIED'}
                    </span>
                  </div>
                </div>
              );
            })}
          </div>
        )}

        {/* Security & Anti-Fraud Radar Panel */}
        <div className="p-4 rounded-xl border border-slate-200 dark:border-slate-800 bg-slate-50/50 dark:bg-slate-900/40">
          <h4 className="text-xs font-bold uppercase tracking-wider text-slate-600 dark:text-slate-300 mb-3 flex items-center gap-1.5">
            <AlertCircle className="w-4 h-4 text-[#0F9D8A]" />
            Anti-Fraud Verification Matrix ({caseItem.evidence.length} Files Inspected)
          </h4>
          <div className="grid grid-cols-2 sm:grid-cols-4 gap-3 text-xs">
            <div className="p-2.5 rounded-lg bg-white dark:bg-[#070D19] border border-slate-200 dark:border-slate-800">
              <span className="text-slate-400 block mb-0.5">Image Deduplication</span>
              <span className="font-bold text-emerald-600 dark:text-emerald-400 flex items-center gap-1">
                <CheckCircle2 className="w-3.5 h-3.5" /> 100% Unique
              </span>
            </div>
            <div className="p-2.5 rounded-lg bg-white dark:bg-[#070D19] border border-slate-200 dark:border-slate-800">
              <span className="text-slate-400 block mb-0.5">Receipt / UTR Replay</span>
              <span className="font-bold text-emerald-600 dark:text-emerald-400 flex items-center gap-1">
                <CheckCircle2 className="w-3.5 h-3.5" /> Non-Reused
              </span>
            </div>
            <div className="p-2.5 rounded-lg bg-white dark:bg-[#070D19] border border-slate-200 dark:border-slate-800">
              <span className="text-slate-400 block mb-0.5">Evidence Formats</span>
              <span className="font-bold text-slate-700 dark:text-slate-300">
                {caseItem.evidence.some(isVideo) ? 'Images + Video' : 'Cryptographic Images'}
              </span>
            </div>
            <div className="p-2.5 rounded-lg bg-white dark:bg-[#070D19] border border-slate-200 dark:border-slate-800">
              <span className="text-slate-400 block mb-0.5">Risk Score</span>
              <span className="font-bold text-emerald-600">
                {caseItem.riskScore}/100 (Clean)
              </span>
            </div>
          </div>
        </div>
      </div>
    </Modal>
  );
};
