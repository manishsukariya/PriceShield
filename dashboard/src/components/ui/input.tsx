import React from 'react';
import { cn } from '../../lib/utils';

export interface InputProps extends React.InputHTMLAttributes<HTMLInputElement> {
  icon?: React.ReactNode;
}

export const Input = React.forwardRef<HTMLInputElement, InputProps>(
  ({ className, type = 'text', icon, ...props }, ref) => {
    return (
      <div className="relative flex items-center w-full">
        {icon && (
          <div className="absolute left-3 text-slate-400 pointer-events-none flex items-center justify-center">
            {icon}
          </div>
        )}
        <input
          type={type}
          ref={ref}
          className={cn(
            'flex h-10 w-full rounded-lg border border-slate-200 dark:border-slate-800 bg-white dark:bg-[#070D19] px-3 py-2 text-sm text-slate-900 dark:text-slate-100 placeholder:text-slate-400 focus:outline-none focus:ring-2 focus:ring-[#0F9D8A]/30 focus:border-[#0F9D8A] disabled:cursor-not-allowed disabled:opacity-50 transition-all',
            icon && 'pl-9',
            className
          )}
          {...props}
        />
      </div>
    );
  }
);
Input.displayName = 'Input';
