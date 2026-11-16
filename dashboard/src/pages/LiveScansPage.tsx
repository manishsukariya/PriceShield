import React, { useState, useEffect } from 'react';
import { Radio, RefreshCw, Smartphone } from 'lucide-react';
import { Card, CardContent } from '../components/ui/card';
import { Button } from '../components/ui/button';
import { Badge } from '../components/ui/badge';
import { api } from '../lib/api';
import { ScanFeedItem } from '../types';
import { formatCurrency, formatTimeAgo } from '../lib/utils';

export const LiveScansPage: React.FC = () => {
  const [scans, setScans] = useState<ScanFeedItem[]>([]);
  const [isRefreshing, setIsRefreshing] = useState(false);

  const fetchScans = async () => {
    setIsRefreshing(true);
    const data = await api.getLiveScans();
    setScans(data);
    setIsRefreshing(false);
  };

  useEffect(() => {
    fetchScans();
    const interval = setInterval(fetchScans, 8000);
    return () => clearInterval(interval);
  }, []);

  return (
    <div className="space-y-6 animate-in fade-in duration-300">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-black tracking-tight text-[#10233F] dark:text-white font-sans flex items-center gap-2.5">
            <Radio className="w-5 h-5 text-emerald-500 animate-pulse" />
            Live Consumer Scanner Telemetry
          </h1>
          <p className="text-xs sm:text-sm text-slate-500 dark:text-slate-400 mt-1">
            Real-time feed of physical barcode checks from consumers across India.
          </p>
        </div>

        <Button
          variant="outline"
          size="sm"
          onClick={fetchScans}
          isLoading={isRefreshing}
          className="text-xs font-semibold"
        >
          <RefreshCw className="w-3.5 h-3.5 mr-1.5" />
          Refresh Stream
        </Button>
      </div>

      <Card>
        <CardContent className="p-0">
          <div className="overflow-x-auto">
            <table className="w-full text-left text-xs">
              <thead className="bg-slate-50/80 dark:bg-slate-900/60 border-b border-slate-200 dark:border-slate-800 text-slate-500 font-bold uppercase tracking-wider">
                <tr>
                  <th className="py-3.5 px-4">Time</th>
                  <th className="py-3.5 px-4">Product Name</th>
                  <th className="py-3.5 px-4">Barcode / GTIN</th>
                  <th className="py-3.5 px-4">Printed MRP</th>
                  <th className="py-3.5 px-4">Shelf Charged</th>
                  <th className="py-3.5 px-4">Status & Overcharge</th>
                  <th className="py-3.5 px-4">Location / Store</th>
                  <th className="py-3.5 px-4 text-right">Device Platform</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100 dark:divide-slate-800/80 font-medium">
                {scans.map((s) => (
                  <tr key={s.id} className="hover:bg-slate-50/70 dark:hover:bg-slate-900/40 transition-colors">
                    <td className="py-3.5 px-4 text-slate-400 font-mono whitespace-nowrap">
                      {formatTimeAgo(s.timestamp)}
                    </td>

                    <td className="py-3.5 px-4 font-bold text-slate-900 dark:text-white">
                      {s.productName}
                    </td>

                    <td className="py-3.5 px-4 font-mono text-slate-600 dark:text-slate-400">
                      {s.barcode}
                    </td>

                    <td className="py-3.5 px-4 font-mono text-slate-700 dark:text-slate-300">
                      {formatCurrency(s.printedMrp)}
                    </td>

                    <td className="py-3.5 px-4 font-mono font-bold text-slate-800 dark:text-slate-200">
                      {formatCurrency(s.chargedPrice)}
                    </td>

                    <td className="py-3.5 px-4">
                      {s.isOvercharged ? (
                        <Badge variant="danger" size="sm" className="font-bold">
                          +{formatCurrency(s.overcharge)} Overcharge
                        </Badge>
                      ) : (
                        <Badge variant="success" size="sm">
                          Compliant (0%)
                        </Badge>
                      )}
                    </td>

                    <td className="py-3.5 px-4 text-slate-700 dark:text-slate-300">
                      <p className="font-semibold">{s.storeName}</p>
                      <p className="text-[10px] text-slate-400">{s.city}</p>
                    </td>

                    <td className="py-3.5 px-4 text-right font-mono text-slate-400">
                      <span className="inline-flex items-center gap-1 text-[11px] px-2 py-0.5 rounded bg-slate-100 dark:bg-slate-800">
                        <Smartphone className="w-3 h-3 text-[#0F9D8A]" />
                        {s.devicePlatform}
                      </span>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </CardContent>
      </Card>
    </div>
  );
};
