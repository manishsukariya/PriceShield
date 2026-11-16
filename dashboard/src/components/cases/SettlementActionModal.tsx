import React, { useState } from 'react';
import { CaseItem } from '../../types';
import { Modal } from '../ui/modal';
import { Button } from '../ui/button';
import { Input } from '../ui/input';
import { formatCurrency } from '../../lib/utils';
import { Send, HandCoins, Smartphone, Clock, CheckCircle2 } from 'lucide-react';

interface SettlementActionModalProps {
  isOpen: boolean;
  onClose: () => void;
  caseItem: CaseItem;
  onConfirm: (refundAmount: number) => Promise<void>;
}

export const SettlementActionModal: React.FC<SettlementActionModalProps> = ({
  isOpen,
  onClose,
  caseItem,
  onConfirm,
}) => {
  const [refundAmount, setRefundAmount] = useState<number>(caseItem.overchargeAmount);
  const [isSending, setIsSending] = useState(false);
  const [isSuccess, setIsSuccess] = useState(false);

  const handleSend = async () => {
    setIsSending(true);
    try {
      await onConfirm(refundAmount);
      setIsSuccess(true);
      setTimeout(() => {
        setIsSuccess(false);
        onClose();
      }, 1600);
    } catch (err) {
      console.error(err);
    } finally {
      setIsSending(false);
    }
  };

  const previewMessage = `*OFFICIAL CONCILIATION NOTICE — PRICESHIELD CONSUMER DISPUTE*
Reference Docket: ${caseItem.docketId}
Merchant: ${caseItem.merchantName}

Dear Store In-Charge,
A consumer has reported an overcharge on *${caseItem.productName}* purchased at your store.
• Printed MRP: ₹${caseItem.printedMrp.toFixed(2)}
• Charged Price: ₹${caseItem.chargedPrice.toFixed(2)}
• Statutory Excess: ₹${refundAmount.toFixed(2)}

To prevent regulatory escalation to the Legal Metrology Controller (Rule 18(2) / Sec 36(1)), you may settle this claim directly within 48 Hours:
👉 Tap here to execute 1-Click UPI Refund: https://priceshield.org/conciliate/${caseItem.docketId}?amt=${refundAmount}

Thank you for promoting fair retail compliance in India.`;

  return (
    <Modal
      isOpen={isOpen}
      onClose={onClose}
      title="Autonomous Merchant Conciliation Protocol (AMCP)"
      description="Next-generation dispute resolution: 48-Hour instant settlement before statutory regulatory escalation"
      maxWidth="xl"
    >
      {isSuccess ? (
        <div className="py-10 text-center space-y-3">
          <div className="w-12 h-12 rounded-full bg-emerald-100 dark:bg-emerald-950/60 text-emerald-600 flex items-center justify-center mx-auto">
            <CheckCircle2 className="w-6 h-6" />
          </div>
          <h3 className="text-base font-bold text-[#10233F] dark:text-white">
            Conciliation Notice Dispatched!
          </h3>
          <p className="text-xs text-slate-500 max-w-sm mx-auto">
            Dispatched via WhatsApp Business API & SMS to {caseItem.merchantName}. 48-Hour resolution SLA timer started.
          </p>
        </div>
      ) : (
        <div className="space-y-5">
          {/* Dispute Context */}
          <div className="p-4 rounded-xl bg-slate-50 dark:bg-slate-900 border border-slate-200 dark:border-slate-800 flex items-center justify-between">
            <div>
              <p className="text-xs text-slate-500 font-medium">Merchant / Store</p>
              <h4 className="text-sm font-bold text-[#10233F] dark:text-white">{caseItem.merchantName}</h4>
              <p className="text-xs text-slate-400 font-mono mt-0.5">{caseItem.merchantVpa || caseItem.city}</p>
            </div>

            <div className="text-right">
              <p className="text-xs text-slate-500 font-medium">Proposed Refund</p>
              <p className="text-lg font-black text-emerald-600 font-sans">{formatCurrency(refundAmount)}</p>
            </div>
          </div>

          {/* Refund Amount Input */}
          <div>
            <label className="block text-xs font-bold text-slate-700 dark:text-slate-300 uppercase tracking-wider mb-2">
              Settle Amount (INR ₹)
            </label>
            <Input
              type="number"
              value={refundAmount}
              onChange={(e) => setRefundAmount(parseFloat(e.target.value) || 0)}
              icon={<HandCoins className="w-4 h-4" />}
            />
            <p className="text-[11px] text-slate-400 mt-1">
              Defaults to statutory excess overcharge ({formatCurrency(caseItem.overchargeAmount)}).
            </p>
          </div>

          {/* Live Preview of Dispatched Notice */}
          <div>
            <label className="block text-xs font-bold text-slate-700 dark:text-slate-300 uppercase tracking-wider mb-2 flex items-center gap-1.5">
              <Smartphone className="w-4 h-4 text-[#0F9D8A]" />
              Digital Notice Preview (WhatsApp & SMS)
            </label>
            <div className="p-3.5 rounded-xl bg-emerald-50/50 dark:bg-slate-950 border border-emerald-200/60 dark:border-slate-800 text-xs text-slate-700 dark:text-slate-300 font-mono whitespace-pre-wrap leading-relaxed max-h-48 overflow-y-auto">
              {previewMessage}
            </div>
          </div>

          {/* SLA & Regulatory Warning */}
          <div className="flex items-center gap-2 text-xs text-amber-700 dark:text-amber-400 bg-amber-50 dark:bg-amber-950/40 p-3 rounded-lg border border-amber-200 dark:border-amber-900">
            <Clock className="w-4 h-4 shrink-0" />
            <span>
              If merchant ignores or refuses this offer within 48 Hours, the system automatically unlocks Statutory E-Daakhil / Legal Metrology escalation dockets.
            </span>
          </div>

          {/* Action Buttons */}
          <div className="flex items-center justify-end gap-3 pt-3 border-t border-slate-100 dark:border-slate-800">
            <Button variant="outline" onClick={onClose} disabled={isSending}>
              Cancel
            </Button>
            <Button
              variant="secondary"
              onClick={handleSend}
              isLoading={isSending}
              className="bg-[#0F9D8A] hover:bg-[#0C8373] text-white font-bold"
            >
              <Send className="w-4 h-4 mr-1.5" />
              Dispatch Settlement Notice
            </Button>
          </div>
        </div>
      )}
    </Modal>
  );
};
