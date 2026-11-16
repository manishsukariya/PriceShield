import React, { useState, useEffect } from 'react';
import {
  CheckCircle2,
  XCircle,
} from 'lucide-react';
import { Card } from '../components/ui/card';
import { Button } from '../components/ui/button';
import { Badge } from '../components/ui/badge';
import { Modal } from '../components/ui/modal';
import { Input } from '../components/ui/input';
import { api } from '../lib/api';
import { CommunitySubmissionItem } from '../types';
import { formatCurrency } from '../lib/utils';

export const SubmissionsPage: React.FC = () => {
  const [submissions, setSubmissions] = useState<CommunitySubmissionItem[]>([]);
  const [selectedSub, setSelectedSub] = useState<CommunitySubmissionItem | null>(null);
  const [approvedMrp, setApprovedMrp] = useState<string>('');
  const [isProcessing, setIsProcessing] = useState(false);

  const loadSubmissions = async () => {
    const list = await api.getSubmissions();
    setSubmissions(list);
  };

  useEffect(() => {
    loadSubmissions();
  }, []);

  const handleReview = async (id: string, action: 'APPROVE' | 'REJECT') => {
    setIsProcessing(true);
    try {
      const finalPrice = approvedMrp ? parseFloat(approvedMrp) : undefined;
      await api.reviewSubmission(id, action, finalPrice);
      setSelectedSub(null);
      await loadSubmissions();
    } catch (err) {
      console.error(err);
    } finally {
      setIsProcessing(false);
    }
  };

  const pendingSubmissions = submissions.filter((s) => s.status === 'PENDING');

  return (
    <div className="space-y-6 animate-in fade-in duration-300">
      {/* Header */}
      <div>
        <h1 className="text-2xl font-black tracking-tight text-[#10233F] dark:text-white font-sans flex items-center gap-2.5">
          Community OCR Submissions Queue
          <span className="text-xs font-bold px-2 py-0.5 rounded-full bg-amber-100 text-amber-800 dark:bg-amber-950/60 dark:text-amber-300">
            {pendingSubmissions.length} Awaiting Verification
          </span>
        </h1>
        <p className="text-xs sm:text-sm text-slate-500 dark:text-slate-400 mt-1">
          Crowdsourced FMCG products submitted by PriceShield mobile users with on-device OCR packaging scans.
        </p>
      </div>

      {/* Pending Review Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        {pendingSubmissions.map((sub) => (
          <Card key={sub.id} className="overflow-hidden flex flex-col justify-between hover:shadow-md transition-shadow">
            <div>
              {/* Image Preview Banner */}
              <div className="relative aspect-video bg-slate-100 dark:bg-slate-900 overflow-hidden border-b border-slate-100 dark:border-slate-800">
                {sub.frontImageUrl ? (
                  <img src={sub.frontImageUrl} alt={sub.productName} className="w-full h-full object-cover" />
                ) : (
                  <div className="w-full h-full flex items-center justify-center text-slate-400 text-xs">
                    No Front Image
                  </div>
                )}

                <div className="absolute top-2 right-2">
                  <Badge variant="brand" size="sm" className="bg-[#10233F]/90 text-white border-none backdrop-blur-xs">
                    OCR Confidence {sub.ocrConfidence}%
                  </Badge>
                </div>

                {sub.detectedOcrMrp && (
                  <div className="absolute bottom-2 left-2 right-2 p-2 rounded-lg bg-slate-950/85 backdrop-blur-sm border border-slate-700 text-white text-xs flex items-center justify-between">
                    <span className="text-[11px] text-slate-300 font-mono">AI Extracted MRP:</span>
                    <span className="font-mono font-bold text-emerald-400">
                      {formatCurrency(sub.detectedOcrMrp)}
                    </span>
                  </div>
                )}
              </div>

              {/* Body */}
              <div className="p-4 space-y-3">
                <div>
                  <h3 className="font-bold text-sm text-[#10233F] dark:text-white leading-tight">
                    {sub.productName}
                  </h3>
                  <p className="text-[11px] text-slate-400 font-mono mt-0.5">
                    Barcode: {sub.barcode} • {sub.category || 'General FMCG'}
                  </p>
                </div>

                <div className="p-2.5 rounded-lg bg-slate-50 dark:bg-slate-900 border border-slate-100 dark:border-slate-800 text-xs space-y-1">
                  <div className="flex justify-between">
                    <span className="text-slate-400">User Suggested:</span>
                    <span className="font-bold font-mono text-slate-800 dark:text-slate-200">
                      {formatCurrency(sub.userSuggestedMrp)}
                    </span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-slate-400">Submitted By:</span>
                    <span className="font-mono text-[11px] text-slate-600 dark:text-slate-400 truncate max-w-[140px]">
                      {sub.submittedByEmail}
                    </span>
                  </div>
                </div>

                {sub.detectedOcrText && (
                  <div className="text-[10px] font-mono p-2 rounded bg-slate-100 dark:bg-slate-950 text-slate-500 line-clamp-2">
                    "{sub.detectedOcrText}"
                  </div>
                )}
              </div>
            </div>

            {/* Actions */}
            <div className="p-4 border-t border-slate-100 dark:border-slate-800/80 bg-slate-50/50 dark:bg-slate-900/30 flex items-center gap-2">
              <Button
                variant="outline"
                size="sm"
                onClick={() => handleReview(sub.id, 'REJECT')}
                className="flex-1 text-xs text-rose-600 hover:bg-rose-50"
              >
                <XCircle className="w-3.5 h-3.5 mr-1" />
                Reject
              </Button>

              <Button
                variant="secondary"
                size="sm"
                onClick={() => {
                  setSelectedSub(sub);
                  setApprovedMrp(sub.detectedOcrMrp?.toString() || sub.userSuggestedMrp.toString());
                }}
                className="flex-1 text-xs bg-[#0F9D8A] hover:bg-[#0C8373] text-white font-bold"
              >
                <CheckCircle2 className="w-3.5 h-3.5 mr-1" />
                Approve & Add
              </Button>
            </div>
          </Card>
        ))}

        {pendingSubmissions.length === 0 && (
          <div className="col-span-full py-16 text-center text-slate-400">
            <CheckCircle2 className="w-10 h-10 mx-auto mb-2 text-emerald-500 opacity-60" />
            <p className="text-sm font-semibold">Queue Clear!</p>
            <p className="text-xs mt-1">All user-submitted products have been reviewed.</p>
          </div>
        )}
      </div>

      {/* Approval Confirmation Modal */}
      {selectedSub && (
        <Modal
          isOpen={!!selectedSub}
          onClose={() => setSelectedSub(null)}
          title="Approve & Publish to Global Catalog"
          description="Confirm product details and statutory MRP before saving to Supabase"
          maxWidth="md"
        >
          <div className="space-y-4">
            <div>
              <p className="text-xs text-slate-400 font-medium">Product Title</p>
              <h4 className="text-sm font-bold text-[#10233F] dark:text-white">{selectedSub.productName}</h4>
              <p className="text-xs font-mono text-slate-500">Barcode: {selectedSub.barcode}</p>
            </div>

            <div>
              <label className="block text-xs font-bold text-slate-700 dark:text-slate-300 uppercase tracking-wider mb-1">
                Approved Statutory MRP (₹)
              </label>
              <Input
                type="number"
                step="0.01"
                value={approvedMrp}
                onChange={(e) => setApprovedMrp(e.target.value)}
              />
              <p className="text-[11px] text-slate-400 mt-1">
                Cross-verified against detected OCR packaging reading.
              </p>
            </div>

            <div className="flex items-center justify-end gap-2 pt-3 border-t border-slate-100 dark:border-slate-800">
              <Button variant="outline" size="sm" onClick={() => setSelectedSub(null)}>
                Cancel
              </Button>
              <Button
                variant="secondary"
                size="sm"
                isLoading={isProcessing}
                onClick={() => handleReview(selectedSub.id, 'APPROVE')}
                className="bg-[#0F9D8A] text-white font-bold"
              >
                Confirm & Sync Catalog
              </Button>
            </div>
          </div>
        </Modal>
      )}
    </div>
  );
};
