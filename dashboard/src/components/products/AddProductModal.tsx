import React, { useState } from 'react';
import { ProductItem } from '../../types';
import { Modal } from '../ui/modal';
import { Button } from '../ui/button';
import { Input } from '../ui/input';
import { Tag, Barcode, DollarSign, Package } from 'lucide-react';

interface AddProductModalProps {
  isOpen: boolean;
  onClose: () => void;
  onAdd: (product: Omit<ProductItem, 'id' | 'createdAt' | 'updatedAt' | 'verifiedScansCount'>) => Promise<void>;
}

export const AddProductModal: React.FC<AddProductModalProps> = ({
  isOpen,
  onClose,
  onAdd,
}) => {
  const [barcode, setBarcode] = useState('');
  const [name, setName] = useState('');
  const [brand, setBrand] = useState('');
  const [category, setCategory] = useState('Beverages');
  const [mrp, setMrp] = useState<string>('');
  const [sizeOrWeight, setSizeOrWeight] = useState('');
  const [imageUrl, setImageUrl] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!barcode.trim() || !name.trim() || !mrp) return;

    setIsSubmitting(true);
    try {
      await onAdd({
        barcode: barcode.trim(),
        name: name.trim(),
        brand: brand.trim() || 'General Brand',
        category,
        mrp: parseFloat(mrp),
        sizeOrWeight: sizeOrWeight.trim() || undefined,
        imageUrl: imageUrl.trim() || undefined,
        source: 'ADMIN',
      });
      onClose();
      // Reset form
      setBarcode('');
      setName('');
      setBrand('');
      setMrp('');
      setSizeOrWeight('');
      setImageUrl('');
    } catch (err) {
      console.error(err);
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <Modal
      isOpen={isOpen}
      onClose={onClose}
      title="Add New Catalog Product"
      description="Create a verified FMCG product in the master PriceShield database"
      maxWidth="lg"
    >
      <form onSubmit={handleSubmit} className="space-y-4">
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <div>
            <label className="block text-xs font-bold text-slate-700 dark:text-slate-300 uppercase tracking-wider mb-1">
              Barcode / GTIN *
            </label>
            <Input
              required
              placeholder="e.g. 8901063029279"
              value={barcode}
              onChange={(e) => setBarcode(e.target.value)}
              icon={<Barcode className="w-4 h-4" />}
            />
          </div>

          <div>
            <label className="block text-xs font-bold text-slate-700 dark:text-slate-300 uppercase tracking-wider mb-1">
              Printed MRP (₹) *
            </label>
            <Input
              required
              type="number"
              step="0.01"
              placeholder="e.g. 35.00"
              value={mrp}
              onChange={(e) => setMrp(e.target.value)}
              icon={<DollarSign className="w-4 h-4" />}
            />
          </div>
        </div>

        <div>
          <label className="block text-xs font-bold text-slate-700 dark:text-slate-300 uppercase tracking-wider mb-1">
            Product Full Name *
          </label>
          <Input
            required
            placeholder="e.g. Britannia Bourbon The Original Biscuit"
            value={name}
            onChange={(e) => setName(e.target.value)}
            icon={<Package className="w-4 h-4" />}
          />
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <div>
            <label className="block text-xs font-bold text-slate-700 dark:text-slate-300 uppercase tracking-wider mb-1">
              Brand
            </label>
            <Input
              placeholder="e.g. Britannia"
              value={brand}
              onChange={(e) => setBrand(e.target.value)}
              icon={<Tag className="w-4 h-4" />}
            />
          </div>

          <div>
            <label className="block text-xs font-bold text-slate-700 dark:text-slate-300 uppercase tracking-wider mb-1">
              Category
            </label>
            <select
              value={category}
              onChange={(e) => setCategory(e.target.value)}
              className="flex h-10 w-full rounded-lg border border-slate-200 dark:border-slate-800 bg-white dark:bg-[#070D19] px-3 py-2 text-sm text-slate-900 dark:text-slate-100 focus:outline-none focus:ring-2 focus:ring-[#0F9D8A]/30 focus:border-[#0F9D8A]"
            >
              <option value="Beverages">Beverages / Soft Drinks</option>
              <option value="Biscuits & Snacks">Biscuits & Snacks</option>
              <option value="Dairy">Dairy & Milk Products</option>
              <option value="Instant Foods">Instant & Packaged Foods</option>
              <option value="Personal Care">Personal Care & Hygiene</option>
              <option value="Energy Drinks">Energy Drinks</option>
              <option value="Chocolates & Sweets">Chocolates & Sweets</option>
            </select>
          </div>
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <div>
            <label className="block text-xs font-bold text-slate-700 dark:text-slate-300 uppercase tracking-wider mb-1">
              Net Quantity / Unit Size
            </label>
            <Input
              placeholder="e.g. 150 g, 250 ml"
              value={sizeOrWeight}
              onChange={(e) => setSizeOrWeight(e.target.value)}
            />
          </div>

          <div>
            <label className="block text-xs font-bold text-slate-700 dark:text-slate-300 uppercase tracking-wider mb-1">
              Image URL (Optional)
            </label>
            <Input
              placeholder="https://..."
              value={imageUrl}
              onChange={(e) => setImageUrl(e.target.value)}
            />
          </div>
        </div>

        <div className="flex items-center justify-end gap-3 pt-4 border-t border-slate-100 dark:border-slate-800">
          <Button variant="outline" type="button" onClick={onClose} disabled={isSubmitting}>
            Cancel
          </Button>
          <Button variant="secondary" type="submit" isLoading={isSubmitting}>
            Add to Global Catalog
          </Button>
        </div>
      </form>
    </Modal>
  );
};
