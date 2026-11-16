import React from 'react';
import { CaseStatus } from '../../types';
import { Badge } from '../ui/badge';
import {
  Clock,
  Search,
  Bell,
  CheckCircle2,
  XCircle,
  Gavel,
  HandCoins,
} from 'lucide-react';

interface CaseStatusBadgeProps {
  status: CaseStatus;
  size?: 'sm' | 'md';
}

export const CaseStatusBadge: React.FC<CaseStatusBadgeProps> = ({ status, size = 'md' }) => {
  switch (status) {
    case 'PENDING':
      return (
        <Badge variant="secondary" size={size} className="gap-1.5 font-semibold text-slate-700 dark:text-slate-300">
          <Clock className="w-3 h-3 text-slate-500" />
          Pending Review
        </Badge>
      );
    case 'INVESTIGATING':
      return (
        <Badge variant="warning" size={size} className="gap-1.5 font-semibold">
          <Search className="w-3 h-3 text-amber-500" />
          Investigating
        </Badge>
      );
    case 'MERCHANT_NOTIFIED':
      return (
        <Badge variant="brand" size={size} className="gap-1.5 font-semibold">
          <Bell className="w-3 h-3 text-[#0F9D8A]" />
          Merchant Notified
        </Badge>
      );
    case 'SETTLEMENT_PROPOSED':
      return (
        <Badge variant="brand" size={size} className="gap-1.5 font-semibold bg-[#DDF7F1] text-[#0A6B5E] dark:bg-[#0F9D8A]/20">
          <HandCoins className="w-3 h-3 text-[#0F9D8A]" />
          Settlement Proposed
        </Badge>
      );
    case 'RESOLVED':
      return (
        <Badge variant="success" size={size} className="gap-1.5 font-semibold">
          <CheckCircle2 className="w-3 h-3 text-emerald-600" />
          Resolved / Refunded
        </Badge>
      );
    case 'REJECTED':
      return (
        <Badge variant="danger" size={size} className="gap-1.5 font-semibold">
          <XCircle className="w-3 h-3 text-rose-500" />
          Rejected / Dismissed
        </Badge>
      );
    case 'ESCALATED_LEGAL_METROLOGY':
      return (
        <Badge
          variant="outline"
          size={size}
          className="gap-1.5 font-bold border-purple-300 bg-purple-50 text-purple-700 dark:bg-purple-950/40 dark:text-purple-300 dark:border-purple-800"
        >
          <Gavel className="w-3 h-3 text-purple-600" />
          Escalated to LM Dept
        </Badge>
      );
    default:
      return <Badge size={size}>{status}</Badge>;
  }
};
