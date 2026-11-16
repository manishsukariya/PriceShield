import React from 'react';
import { EvidenceConfidence } from '../../types';
import { Badge } from '../ui/badge';
import { ShieldCheck, ShieldAlert, Users, HelpCircle } from 'lucide-react';

interface ConfidenceBadgeProps {
  confidence: EvidenceConfidence;
  size?: 'sm' | 'md';
}

export const ConfidenceBadge: React.FC<ConfidenceBadgeProps> = ({ confidence, size = 'sm' }) => {
  switch (confidence) {
    case 'CORROBORATED':
      return (
        <Badge
          variant="brand"
          size={size}
          className="font-bold border-[#0F9D8A] bg-[#DDF7F1] text-[#0A6B5E] dark:bg-[#0F9D8A]/25 dark:text-[#57C7A7]"
        >
          <Users className="w-3 h-3 text-[#0F9D8A]" />
          Corroborated (Crowd Verified)
        </Badge>
      );
    case 'STRONG':
      return (
        <Badge variant="success" size={size} className="font-bold">
          <ShieldCheck className="w-3 h-3 text-emerald-600" />
          Strong Evidence (Bill/OCR)
        </Badge>
      );
    case 'BASIC':
      return (
        <Badge variant="warning" size={size} className="font-medium">
          <ShieldAlert className="w-3 h-3 text-amber-500" />
          Basic Proof (UPI + Packet)
        </Badge>
      );
    case 'UNVERIFIED':
      return (
        <Badge variant="secondary" size={size} className="font-medium text-slate-500">
          <HelpCircle className="w-3 h-3 text-slate-400" />
          Unverified (Advisory Only)
        </Badge>
      );
    default:
      return <Badge size={size}>{confidence}</Badge>;
  }
};
