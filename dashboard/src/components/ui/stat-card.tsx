import React from 'react';
import { cn } from '../../lib/utils';
import { TrendingUp, TrendingDown } from 'lucide-react';

interface StatCardProps {
  title: string;
  value: string | number;
  subtitle?: string;
  trend?: {
    value: number;
    isPositive: boolean;
    label?: string;
  };
  icon: React.ReactNode;
  variant?: 'default' | 'brand' | 'warning' | 'danger';
  className?: string;
}

export const StatCard: React.FC<StatCardProps> = ({
  title,
  value,
  subtitle,
  trend,
  icon,
  variant = 'default',
  className,
}) => {
  const iconVariants = {
    default: 'bg-slate-100 text-[#10233F] dark:bg-slate-800 dark:text-slate-200',
    brand: 'bg-[#DDF7F1] text-[#0F9D8A] dark:bg-[#0F9D8A]/20 dark:text-[#57C7A7]',
    warning: 'bg-amber-50 text-amber-600 dark:bg-amber-950/40 dark:text-amber-400',
    danger: 'bg-rose-50 text-rose-600 dark:bg-rose-950/40 dark:text-rose-400',
  };

  return (
    <div
      className={cn(
        'relative overflow-hidden bg-white dark:bg-[#0B1528] rounded-xl border border-slate-200/90 dark:border-slate-800/80 p-5 shadow-[0_1px_3px_0_rgba(0,0,0,0.03)] hover:shadow-md transition-all duration-200',
        className
      )}
    >
      <div className="flex items-center justify-between">
        <p className="text-xs font-semibold uppercase tracking-wider text-slate-500 dark:text-slate-400">
          {title}
        </p>
        <div className={cn('p-2.5 rounded-lg flex items-center justify-center', iconVariants[variant])}>
          {icon}
        </div>
      </div>

      <div className="mt-3 flex items-baseline gap-2">
        <h3 className="text-2xl font-black text-[#10233F] dark:text-white tracking-tight font-sans">
          {value}
        </h3>
        {trend && (
          <span
            className={cn(
              'inline-flex items-center text-xs font-bold px-1.5 py-0.5 rounded',
              trend.isPositive
                ? 'text-emerald-700 bg-emerald-50 dark:text-emerald-300 dark:bg-emerald-950/40'
                : 'text-rose-700 bg-rose-50 dark:text-rose-300 dark:bg-rose-950/40'
            )}
          >
            {trend.isPositive ? <TrendingUp className="w-3 h-3 mr-0.5" /> : <TrendingDown className="w-3 h-3 mr-0.5" />}
            {Math.abs(trend.value)}%
          </span>
        )}
      </div>

      {subtitle && (
        <p className="mt-1 text-xs text-slate-500 dark:text-slate-400">
          {subtitle}
        </p>
      )}
    </div>
  );
};
