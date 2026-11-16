import React, { useState, useEffect } from 'react';
import {
  Package,
  Search,
  Plus,
  Edit2,
  Check,
} from 'lucide-react';
import { Card, CardContent } from '../components/ui/card';
import { Button } from '../components/ui/button';
import { Input } from '../components/ui/input';
import { Badge } from '../components/ui/badge';
import { Modal } from '../components/ui/modal';
import { AddProductModal } from '../components/products/AddProductModal';
import { api } from '../lib/api';
import { ProductItem } from '../types';
import { formatCurrency, formatDate } from '../lib/utils';

export const ProductsPage: React.FC = () => {
  const [products, setProducts] = useState<ProductItem[]>([]);
  const [search, setSearch] = useState('');
  const [selectedCategory, setSelectedCategory] = useState('ALL');
  const [isAddModalOpen, setIsAddModalOpen] = useState(false);
  const [editingProduct, setEditingProduct] = useState<ProductItem | null>(null);
  const [editMrpInput, setEditMrpInput] = useState('');

  const loadProducts = async () => {
    const list = await api.getProducts(search, selectedCategory);
    setProducts(list);
  };

  useEffect(() => {
    loadProducts();
  }, [search, selectedCategory]);

  const handleAddProduct = async (data: any) => {
    await api.addProduct(data);
    await loadProducts();
  };

  const handleSaveMrp = async () => {
    if (!editingProduct || !editMrpInput) return;
    await api.updateProductMrp(editingProduct.id, parseFloat(editMrpInput));
    setEditingProduct(null);
    await loadProducts();
  };

  const categories = [
    'ALL',
    'Beverages',
    'Biscuits & Snacks',
    'Dairy',
    'Instant Foods',
    'Energy Drinks',
  ];

  return (
    <div className="space-y-6 animate-in fade-in duration-300">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-black tracking-tight text-[#10233F] dark:text-white font-sans flex items-center gap-2.5">
            Master FMCG Product Catalog
            <span className="text-xs font-bold px-2 py-0.5 rounded-full bg-[#DDF7F1] dark:bg-[#0F9D8A]/20 text-[#0F9D8A]">
              {products.length} Products
            </span>
          </h1>
          <p className="text-xs sm:text-sm text-slate-500 dark:text-slate-400 mt-1">
            Statutory printed MRP database synced across mobile scanner and Supabase PostgreSQL.
          </p>
        </div>

        <Button
          variant="secondary"
          onClick={() => setIsAddModalOpen(true)}
          className="bg-[#0F9D8A] hover:bg-[#0C8373] text-white font-bold"
        >
          <Plus className="w-4 h-4 mr-1.5" />
          Add Product to Catalog
        </Button>
      </div>

      {/* Filter & Search Bar */}
      <Card>
        <CardContent className="p-4">
          <div className="flex flex-col md:flex-row items-center gap-4">
            <div className="flex-1 w-full">
              <Input
                placeholder="Search by Barcode / GTIN, Product Title, or Brand..."
                value={search}
                onChange={(e) => setSearch(e.target.value)}
                icon={<Search className="w-4 h-4 text-slate-400" />}
              />
            </div>

            <div className="flex items-center gap-2 overflow-x-auto w-full md:w-auto shrink-0 pb-1 md:pb-0">
              {categories.map((cat) => (
                <button
                  key={cat}
                  onClick={() => setSelectedCategory(cat)}
                  className={`px-3 py-1.5 text-xs font-semibold rounded-lg whitespace-nowrap transition-all ${
                    selectedCategory === cat
                      ? 'bg-[#10233F] dark:bg-[#0F9D8A] text-white'
                      : 'text-slate-600 dark:text-slate-400 hover:bg-slate-100 dark:hover:bg-slate-800'
                  }`}
                >
                  {cat}
                </button>
              ))}
            </div>
          </div>
        </CardContent>
      </Card>

      {/* Catalog Table Card */}
      <Card>
        <CardContent className="p-0">
          <div className="overflow-x-auto">
            <table className="w-full text-left text-xs">
              <thead className="bg-slate-50/80 dark:bg-slate-900/60 border-b border-slate-200 dark:border-slate-800 text-slate-500 font-bold uppercase tracking-wider">
                <tr>
                  <th className="py-3.5 px-4">Item</th>
                  <th className="py-3.5 px-4">Barcode / GTIN</th>
                  <th className="py-3.5 px-4">Brand & Category</th>
                  <th className="py-3.5 px-4">Printed MRP</th>
                  <th className="py-3.5 px-4">Net Quantity</th>
                  <th className="py-3.5 px-4">Source</th>
                  <th className="py-3.5 px-4">Scans Count</th>
                  <th className="py-3.5 px-4 text-right">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100 dark:divide-slate-800/80 font-medium">
                {products.map((p) => (
                  <tr key={p.id} className="hover:bg-slate-50/70 dark:hover:bg-slate-900/40 transition-colors">
                    <td className="py-3.5 px-4">
                      <div className="flex items-center gap-3">
                        <div className="w-10 h-10 rounded-lg bg-slate-100 dark:bg-slate-800 overflow-hidden shrink-0 border border-slate-200 dark:border-slate-700">
                          {p.imageUrl ? (
                            <img src={p.imageUrl} alt={p.name} className="w-full h-full object-cover" />
                          ) : (
                            <div className="w-full h-full flex items-center justify-center text-slate-400">
                              <Package className="w-5 h-5" />
                            </div>
                          )}
                        </div>
                        <div>
                          <p className="font-bold text-slate-900 dark:text-white max-w-[220px] truncate">
                            {p.name}
                          </p>
                          <p className="text-[10px] text-slate-400 font-mono">
                            Added: {formatDate(p.createdAt)}
                          </p>
                        </div>
                      </div>
                    </td>

                    <td className="py-3.5 px-4 font-mono font-bold text-slate-800 dark:text-slate-200">
                      {p.barcode}
                    </td>

                    <td className="py-3.5 px-4">
                      <p className="font-bold text-slate-800 dark:text-slate-200">{p.brand}</p>
                      <p className="text-[11px] text-slate-400">{p.category}</p>
                    </td>

                    <td className="py-3.5 px-4 whitespace-nowrap">
                      <span className="text-sm font-black font-mono text-[#0F9D8A]">
                        {formatCurrency(p.mrp)}
                      </span>
                    </td>

                    <td className="py-3.5 px-4 text-slate-600 dark:text-slate-400">
                      {p.sizeOrWeight || 'Standard'}
                    </td>

                    <td className="py-3.5 px-4">
                      <Badge variant={p.source === 'ADMIN' ? 'brand' : 'secondary'} size="sm">
                        {p.source === 'ADMIN' ? 'Verified Catalog' : p.source === 'OFF' ? 'Open Food Facts' : 'Community OCR'}
                      </Badge>
                    </td>

                    <td className="py-3.5 px-4 font-mono text-slate-600 dark:text-slate-400">
                      {p.verifiedScansCount.toLocaleString('en-IN')}
                    </td>

                    <td className="py-3.5 px-4 text-right">
                      <Button
                        variant="ghost"
                        size="sm"
                        onClick={() => {
                          setEditingProduct(p);
                          setEditMrpInput(p.mrp.toString());
                        }}
                        className="h-8 text-xs font-semibold text-slate-600 dark:text-slate-300 hover:text-[#0F9D8A]"
                      >
                        <Edit2 className="w-3.5 h-3.5 mr-1" />
                        Edit MRP
                      </Button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </CardContent>
      </Card>

      {/* Add Product Modal */}
      <AddProductModal
        isOpen={isAddModalOpen}
        onClose={() => setIsAddModalOpen(false)}
        onAdd={handleAddProduct}
      />

      {/* Quick Edit MRP Modal */}
      {editingProduct && (
        <Modal
          isOpen={!!editingProduct}
          onClose={() => setEditingProduct(null)}
          title={`Edit MRP — ${editingProduct.name}`}
          description="Update the statutory printed price for all consumer scanner checks"
          maxWidth="sm"
        >
          <div className="space-y-4">
            <div>
              <label className="block text-xs font-bold text-slate-700 dark:text-slate-300 uppercase tracking-wider mb-1">
                New Printed MRP (₹)
              </label>
              <Input
                type="number"
                step="0.01"
                value={editMrpInput}
                onChange={(e) => setEditMrpInput(e.target.value)}
              />
            </div>

            <div className="flex items-center justify-end gap-2 pt-3 border-t border-slate-100 dark:border-slate-800">
              <Button variant="outline" size="sm" onClick={() => setEditingProduct(null)}>
                Cancel
              </Button>
              <Button variant="secondary" size="sm" onClick={handleSaveMrp}>
                <Check className="w-4 h-4 mr-1" />
                Update Catalog MRP
              </Button>
            </div>
          </div>
        </Modal>
      )}
    </div>
  );
};
