import {
  CaseItem,
  CaseStatus,
  ProductItem,
  CommunitySubmissionItem,
  MerchantItem,
  ScanFeedItem,
  DashboardMetrics,
} from '../types';
import {
  mockCases,
  mockProducts,
  mockSubmissions,
  mockMerchants,
  mockScansFeed,
  mockDashboardMetrics,
} from './mockData';

const API_BASE_URL = import.meta.env.VITE_PRICESHIELD_API_URL || 'https://priceshield-r4v5.onrender.com/api/v1';
const ADMIN_API_KEY = import.meta.env.VITE_ADMIN_MODERATION_KEY || '';

// In-memory state store for interactive operations
let casesStore: CaseItem[] = [...mockCases];
let productsStore: ProductItem[] = [...mockProducts];
let submissionsStore: CommunitySubmissionItem[] = [...mockSubmissions];
let merchantsStore: MerchantItem[] = [...mockMerchants];

export const api = {
  // --- METRICS ---
  async getMetrics(): Promise<DashboardMetrics> {
    const activeCases = casesStore.filter((c) => c.status !== 'RESOLVED' && c.status !== 'REJECTED').length;
    const awaitingReview = casesStore.filter((c) => c.status === 'PENDING' || c.status === 'INVESTIGATING').length;

    return {
      ...mockDashboardMetrics,
      activeCasesCount: activeCases,
      casesAwaitingReview: awaitingReview,
      totalScansToday: mockDashboardMetrics.totalScansToday + Math.floor(Math.random() * 5),
    };
  },

  // --- LIVE SCANS ---
  async getLiveScans(): Promise<ScanFeedItem[]> {
    return [...mockScansFeed];
  },

  // --- COMPLAINTS / CASES ---
  async getCases(filters?: {
    status?: string;
    confidenceLevel?: string;
    search?: string;
    venueType?: string;
  }): Promise<CaseItem[]> {
    let list = [...casesStore];

    if (filters?.status && filters.status !== 'ALL') {
      list = list.filter((c) => c.status === filters.status);
    }
    if (filters?.confidenceLevel && filters.confidenceLevel !== 'ALL') {
      list = list.filter((c) => c.confidenceLevel === filters.confidenceLevel);
    }
    if (filters?.venueType && filters.venueType !== 'ALL') {
      list = list.filter((c) => c.venueType === filters.venueType);
    }
    if (filters?.search && filters.search.trim()) {
      const q = filters.search.toLowerCase().trim();
      list = list.filter(
        (c) =>
          c.productName.toLowerCase().includes(q) ||
          c.docketId.toLowerCase().includes(q) ||
          c.merchantName.toLowerCase().includes(q) ||
          c.barcode.includes(q) ||
          c.city.toLowerCase().includes(q) ||
          (c.utrNumber && c.utrNumber.includes(q))
      );
    }

    return list;
  },

  async getCaseById(id: string): Promise<CaseItem | null> {
    const found = casesStore.find((c) => c.id === id || c.docketId === id);
    return found || null;
  },

  async updateCaseStatus(
    id: string,
    status: CaseStatus,
    notes?: string,
    merchantResponse?: string
  ): Promise<CaseItem> {
    // Try backend if live credentials exist
    if (ADMIN_API_KEY && API_BASE_URL) {
      try {
        await fetch(`${API_BASE_URL}/admin/complaints/${id}`, {
          method: 'PATCH',
          headers: {
            'Content-Type': 'application/json',
            'x-admin-key': ADMIN_API_KEY,
          },
          body: JSON.stringify({ status, moderationNotes: notes, merchantResponse }),
        });
      } catch (err) {
        console.warn('Backend sync failed, falling back to local store update', err);
      }
    }

    const index = casesStore.findIndex((c) => c.id === id);
    if (index === -1) throw new Error('Case not found');

    const updated: CaseItem = {
      ...casesStore[index],
      status,
      updatedAt: new Date().toISOString(),
      moderatorNotes: notes || casesStore[index].moderatorNotes,
      timeline: [
        ...casesStore[index].timeline,
        {
          id: `tl-${Date.now()}`,
          timestamp: new Date().toISOString(),
          actor: 'MODERATOR',
          actorName: 'Dashboard Ops Moderator',
          title: `Status Changed to ${status.replace(/_/g, ' ')}`,
          description: notes || `Case updated by operations team.`,
          badge: status,
        },
      ],
    };

    casesStore[index] = updated;
    return updated;
  },

  async proposeMerchantSettlement(id: string, amount: number): Promise<CaseItem> {
    const index = casesStore.findIndex((c) => c.id === id);
    if (index === -1) throw new Error('Case not found');

    const updated: CaseItem = {
      ...casesStore[index],
      status: 'SETTLEMENT_PROPOSED',
      settlementOfferedAmount: amount,
      settlementStatus: 'AWAITING_REPLY',
      merchantNotifiedAt: new Date().toISOString(),
      timeline: [
        ...casesStore[index].timeline,
        {
          id: `tl-${Date.now()}`,
          timestamp: new Date().toISOString(),
          actor: 'SYSTEM_AI',
          actorName: 'Autonomous Conciliation Engine',
          title: 'Settlement Link Dispatched',
          description: `Dispatched 48h instant UPI refund conciliation link for ₹${amount.toFixed(2)} to merchant ${casesStore[index].merchantName}.`,
          badge: 'SETTLEMENT OFFERED',
        },
      ],
    };

    casesStore[index] = updated;
    return updated;
  },

  // --- PRODUCTS CATALOG ---
  async getProducts(search?: string, category?: string): Promise<ProductItem[]> {
    let list = [...productsStore];
    if (category && category !== 'ALL') {
      list = list.filter((p) => p.category === category);
    }
    if (search && search.trim()) {
      const q = search.toLowerCase().trim();
      list = list.filter(
        (p) =>
          p.name.toLowerCase().includes(q) ||
          p.barcode.includes(q) ||
          p.brand.toLowerCase().includes(q)
      );
    }
    return list;
  },

  async addProduct(product: Omit<ProductItem, 'id' | 'createdAt' | 'updatedAt' | 'verifiedScansCount'>): Promise<ProductItem> {
    const created: ProductItem = {
      ...product,
      id: `prod-${Date.now()}`,
      verifiedScansCount: 0,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    };
    productsStore = [created, ...productsStore];
    return created;
  },

  async updateProductMrp(id: string, newMrp: number): Promise<ProductItem> {
    const index = productsStore.findIndex((p) => p.id === id);
    if (index === -1) throw new Error('Product not found');

    const updated: ProductItem = {
      ...productsStore[index],
      mrp: newMrp,
      updatedAt: new Date().toISOString(),
    };
    productsStore[index] = updated;
    return updated;
  },

  // --- COMMUNITY SUBMISSIONS ---
  async getSubmissions(status?: string): Promise<CommunitySubmissionItem[]> {
    let list = [...submissionsStore];
    if (status && status !== 'ALL') {
      list = list.filter((s) => s.status === status);
    }
    return list;
  },

  async reviewSubmission(id: string, action: 'APPROVE' | 'REJECT', finalMrp?: number): Promise<CommunitySubmissionItem> {
    const index = submissionsStore.findIndex((s) => s.id === id);
    if (index === -1) throw new Error('Submission not found');

    const sub = submissionsStore[index];
    const newStatus = action === 'APPROVE' ? 'APPROVED' : 'REJECTED';

    submissionsStore[index] = {
      ...sub,
      status: newStatus,
    };

    if (action === 'APPROVE') {
      // Automatically upsert into products catalog
      await this.addProduct({
        barcode: sub.barcode,
        name: sub.productName,
        brand: sub.brand || 'General FMCG',
        category: sub.category || 'Packaged Goods',
        mrp: finalMrp ?? sub.userSuggestedMrp,
        imageUrl: sub.frontImageUrl,
        source: 'USER_VERIFIED',
      });
    }

    return submissionsStore[index];
  },

  // --- MERCHANTS ---
  async getMerchants(search?: string, riskBand?: string): Promise<MerchantItem[]> {
    let list = [...merchantsStore];
    if (riskBand && riskBand !== 'ALL') {
      list = list.filter((m) => m.riskBand === riskBand);
    }
    if (search && search.trim()) {
      const q = search.toLowerCase().trim();
      list = list.filter(
        (m) =>
          m.storeName.toLowerCase().includes(q) ||
          m.city.toLowerCase().includes(q) ||
          (m.merchantVpa && m.merchantVpa.toLowerCase().includes(q))
      );
    }
    return list;
  },
};
