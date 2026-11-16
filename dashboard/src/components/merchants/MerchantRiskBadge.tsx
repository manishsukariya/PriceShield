import React from 'react';
import { Badge } from '../ui/badge';
import { AlertTriangle, AlertOctagon, CheckCircle2, Eye } from 'lucide-react';

interface MerchantRiskBadgeProps {
  riskBand: 'GREEN' | 'AMBER' | 'RED' | 'CRITICAL';
  size?: 'sm' | 'md';
}

export const MerchantRiskBadge: React.FC<MerchantRiskBadgeProps> = ({ riskBand, size = 'sm' }) => {
  switch (riskBand) {
    case 'GREEN':
      return (
        <Badge variant="success" size={size} className="font-bold">
          <CheckCircle2 className="w-3 h-3 text-emerald-600" />
          Compliant
        </Badge>
      );
    case 'AMBER':
      return (
        <Badge variant="warning" size={size} className="font-bold">
          <Eye className="w-3 h-3 text-amber-500" />
          Under Surveillance
        </Badge>
      );
    case 'RED':
      return (
        <Badge variant="danger" size={size} className="font-bold">
          <AlertTriangle className="w-3 h-3 text-rose-500" />
          Repeat Offender
        </Badge>
      );
    case 'CRITICAL':
      return (
        <Badge
          variant="outline"
          size={size}
          className="font-bold border-rose-400 bg-rose-100 text-rose-900 dark:bg-rose-950/60 dark:text-rose-200 dark:border-rose-700 animate-pulse"
        >
          <AlertOctagon className="w-3 h-3 text-rose-600" />
          Critical / Flagged for Raid
        </Badge>
      );
    default:
      return <Badge size={size}>{riskBand}</Badge>;
  }
};
