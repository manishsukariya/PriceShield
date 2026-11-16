import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { Modal } from '../ui/modal';
import { Input } from '../ui/input';
import { Search, FileText, Package, Store, ArrowRight } from 'lucide-react';
import { api } from '../../lib/api';
import { CaseItem, ProductItem, MerchantItem } from '../../types';
import { formatCurrency } from '../../lib/utils';

interface GlobalSearchModalProps {
  isOpen: boolean;
  onClose: () => void;
}

export const GlobalSearchModal: React.FC<GlobalSearchModalProps> = ({ isOpen, onClose }) => {
  const [query, setQuery] = useState('');
  const [cases, setCases] = useState<CaseItem[]>([]);
  const [products, setProducts] = useState<ProductItem[]>([]);
  const [merchants, setMerchants] = useState<MerchantItem[]>([]);
  const navigate = useNavigate();

  useEffect(() => {
    if (!isOpen) {
      setQuery('');
      return;
    }

    const searchAll = async () => {
      if (!query.trim()) {
        setCases([]);
        setProducts([]);
        setMerchants([]);
        return;
      }
      const [c, p, m] = await Promise.all([
        api.getCases({ search: query }),
        api.getProducts(query),
        api.getMerchants(query),
      ]);
      setCases(c.slice(0, 3));
      setProducts(p.slice(0, 3));
      setMerchants(m.slice(0, 3));
    };

    const timer = setTimeout(searchAll, 150);
    return () => clearTimeout(timer);
  }, [query, isOpen]);

  const handleSelectCase = (id: string) => {
    onClose();
    navigate(`/cases/${id}`);
  };

  const handleSelectProduct = () => {
    onClose();
    navigate('/products');
  };

  const handleSelectMerchant = () => {
    onClose();
    navigate('/merchants');
  };

  return (
    <Modal
      isOpen={isOpen}
      onClose={onClose}
      title="Universal Operations Search"
      description="Quick lookup across all consumer complaints, FMCG barcodes, and merchant registries"
      maxWidth="xl"
    >
      <div className="space-y-4">
        <Input
          autoFocus
          placeholder="Search Barcode, Docket PS-..., Merchant, or City..."
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          icon={<Search className="w-4 h-4 text-[#0F9D8A]" />}
          className="h-12 text-base"
        />

        {query.trim() && (
          <div className="space-y-4 max-h-[60vh] overflow-y-auto pr-1">
            {/* Cases Results */}
            {cases.length > 0 && (
              <div>
                <p className="text-[11px] font-bold uppercase tracking-wider text-slate-400 mb-2 flex items-center gap-1.5">
                  <FileText className="w-3.5 h-3.5 text-[#0F9D8A]" />
                  Complaints & Dockets ({cases.length})
                </p>
                <div className="space-y-1.5">
                  {cases.map((c) => (
                    <div
                      key={c.id}
                      onClick={() => handleSelectCase(c.id)}
                      className="p-3 rounded-lg border border-slate-200 dark:border-slate-800 bg-white dark:bg-[#070D19] hover:border-[#0F9D8A] cursor-pointer flex items-center justify-between transition-all group"
                    >
                      <div>
                        <div className="flex items-center gap-2">
                          <span className="font-mono text-xs font-bold text-[#10233F] dark:text-white">
                            {c.docketId}
                          </span>
                          <span className="text-xs text-slate-500">• {c.productName}</span>
                        </div>
                        <p className="text-[11px] text-slate-400 mt-0.5">
                          {c.merchantName} ({c.city}) • Overcharge: {formatCurrency(c.overchargeAmount)}
                        </p>
                      </div>
                      <ArrowRight className="w-4 h-4 text-slate-400 group-hover:text-[#0F9D8A] group-hover:translate-x-1 transition-all" />
                    </div>
                  ))}
                </div>
              </div>
            )}

            {/* Products Results */}
            {products.length > 0 && (
              <div>
                <p className="text-[11px] font-bold uppercase tracking-wider text-slate-400 mb-2 flex items-center gap-1.5">
                  <Package className="w-3.5 h-3.5 text-[#0F9D8A]" />
                  Catalog Products ({products.length})
                </p>
                <div className="space-y-1.5">
                  {products.map((p) => (
                    <div
                      key={p.id}
                      onClick={handleSelectProduct}
                      className="p-3 rounded-lg border border-slate-200 dark:border-slate-800 bg-white dark:bg-[#070D19] hover:border-[#0F9D8A] cursor-pointer flex items-center justify-between transition-all group"
                    >
                      <div>
                        <p className="text-xs font-bold text-[#10233F] dark:text-white">{p.name}</p>
                        <p className="text-[11px] font-mono text-slate-400 mt-0.5">
                          Barcode: {p.barcode} • Printed MRP: {formatCurrency(p.mrp)}
                        </p>
                      </div>
                      <ArrowRight className="w-4 h-4 text-slate-400 group-hover:text-[#0F9D8A] group-hover:translate-x-1 transition-all" />
                    </div>
                  ))}
                </div>
              </div>
            )}

            {/* Merchants Results */}
            {merchants.length > 0 && (
              <div>
                <p className="text-[11px] font-bold uppercase tracking-wider text-slate-400 mb-2 flex items-center gap-1.5">
                  <Store className="w-3.5 h-3.5 text-[#0F9D8A]" />
                  Merchant Watchlist ({merchants.length})
                </p>
                <div className="space-y-1.5">
                  {merchants.map((m) => (
                    <div
                      key={m.id}
                      onClick={handleSelectMerchant}
                      className="p-3 rounded-lg border border-slate-200 dark:border-slate-800 bg-white dark:bg-[#070D19] hover:border-[#0F9D8A] cursor-pointer flex items-center justify-between transition-all group"
                    >
                      <div>
                        <p className="text-xs font-bold text-[#10233F] dark:text-white">{m.storeName}</p>
                        <p className="text-[11px] text-slate-400 mt-0.5">
                          {m.city}, {m.state} • Violations: {m.verifiedViolationsCount}
                        </p>
                      </div>
                      <ArrowRight className="w-4 h-4 text-slate-400 group-hover:text-[#0F9D8A] group-hover:translate-x-1 transition-all" />
                    </div>
                  ))}
                </div>
              </div>
            )}

            {cases.length === 0 && products.length === 0 && merchants.length === 0 && (
              <div className="py-8 text-center text-xs text-slate-400">
                No matching records found for "{query}".
              </div>
            )}
          </div>
        )}

        {!query.trim() && (
          <div className="py-6 text-center text-xs text-slate-400">
            Type a barcode, product name, docket reference, or merchant address to search instantly.
          </div>
        )}
      </div>
    </Modal>
  );
};
