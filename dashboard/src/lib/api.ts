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

export const DEFAULT_CLOUD_URL = 'https://priceshield-r4v5.onrender.com/api/v1';
export const DEFAULT_LOCAL_URL = 'http://localhost:3000/api/v1';

export type BackendTarget = 'cloud' | 'local';

export function getBackendTarget(): BackendTarget {
  if (typeof window !== 'undefined') {
    const stored = localStorage.getItem('priceshield_backend_target');
    if (stored === 'cloud' || stored === 'local') return stored;
    if (window.location.hostname !== 'localhost' && window.location.hostname !== '127.0.0.1') {
      return 'cloud';
    }
  }
  return 'cloud';
}

export function getApiBaseUrl(): string {
  const target = getBackendTarget();
  if (target === 'cloud') return DEFAULT_CLOUD_URL;
  return import.meta.env.VITE_PRICESHIELD_API_URL || DEFAULT_LOCAL_URL;
}

export function setBackendTarget(target: BackendTarget) {
  if (typeof window !== 'undefined') {
    localStorage.setItem('priceshield_backend_target', target);
    initRealtimeEventSource(true);
    window.dispatchEvent(new CustomEvent('priceshield_target_change', { detail: { target } }));
  }
}

const ADMIN_API_KEY =
  import.meta.env.VITE_ADMIN_MODERATION_KEY || 'ps_admin_live_99a8b7c6d5e4';

// In-memory state store for instant interactive operations & fallback
let casesStore: CaseItem[] = [...mockCases];
let productsStore: ProductItem[] = [...mockProducts];
let submissionsStore: CommunitySubmissionItem[] = [...mockSubmissions];
let merchantsStore: MerchantItem[] = [...mockMerchants];

let isBackendLive = false;
let eventSource: EventSource | null = null;

function parseCityAndState(address?: string): { city: string; state: string } {
  if (!address || typeof address !== 'string' || !address.trim()) {
    return { city: 'Local Market', state: 'India' };
  }
  // Strip 6-digit postal pin codes and trim commas
  const clean = address.replace(/\b\d{6}\b/g, '').trim();
  const parts = clean
    .split(',')
    .map((p) => p.trim())
    .filter((p) => p && p.toLowerCase() !== 'india');

  if (parts.length >= 2) {
    return {
      city: parts[parts.length - 2],
      state: parts[parts.length - 1],
    };
  }
  if (parts.length === 1) {
    return { city: parts[0], state: 'India' };
  }
  return { city: 'Local Market', state: 'India' };
}

function normalizeBackendComplaint(raw: any): CaseItem {
  let rawStatus = (raw.status || 'PENDING').toUpperCase() as CaseStatus;
  if (Array.isArray(raw.riskFlags)) {
    const stageFlag = raw.riskFlags.find((f: string) => f.startsWith('STAGE_'));
    if (stageFlag) {
      rawStatus = stageFlag.replace('STAGE_', '') as CaseStatus;
    }
  }

  const location = parseCityAndState(raw.address);

  return {
    id: raw.id,
    docketId: `PS-IN-${new Date(raw.createdAt || Date.now()).getFullYear()}-${raw.id.slice(-5).toUpperCase()}`,
    createdAt: raw.createdAt || new Date().toISOString(),
    updatedAt: raw.updatedAt || new Date().toISOString(),
    barcode: raw.barcode || '8901030000000',
    productName: raw.productName || 'Retail Product',
    category: 'Packaged Goods',
    quantity: raw.quantity || 1,
    printedMrp: Number(raw.mrp || 0),
    chargedPrice: Number(raw.chargedPrice || 0),
    overchargeAmount: Number(raw.overcharge || (Number(raw.chargedPrice || 0) - Number(raw.mrp || 0))),
    totalBasketAmount: Number(raw.totalPaid || raw.chargedPrice || 0),
    paymentMethod: raw.paymentMethod || 'UPI',
    utrNumber: raw.utrNumber || undefined,
    merchantName: raw.merchantName || 'Retail Store',
    merchantVpa: raw.merchantVpa || undefined,
    storeAddress: raw.address || 'Market Location',
    city: location.city,
    state: location.state,
    latitude: raw.latitude ? Number(raw.latitude) : undefined,
    longitude: raw.longitude ? Number(raw.longitude) : undefined,
    venueType: raw.venueType || 'RETAIL',
    status: rawStatus,
    confidenceLevel: raw.confidenceLevel || 'BASIC',
    riskScore: raw.riskScore || 10,
    riskFlags: raw.riskFlags || [],
    evidence: (raw.evidence || []).map((e: any, idx: number) => ({
      id: e.id || `ev-${idx}`,
      url: e.url,
      role: e.role || 'OTHER',
      mediaType: e.mediaType || 'IMAGE',
      sha256Hash: e.sha256Hash,
      uploadedAt: e.createdAt || new Date().toISOString(),
    })),
    timeline: [
      {
        id: `tl-1`,
        timestamp: raw.createdAt || new Date().toISOString(),
        actor: 'CONSUMER',
        actorName: raw.user?.displayName || raw.user?.email || 'Complainant',
        title: 'Overcharge Grievance Filed',
        description: `Complainant submitted printed MRP verification and proof of payment.`,
      },
      ...(raw.moderatorNotes
        ? [
            {
              id: `tl-2`,
              timestamp: raw.moderatedAt || raw.updatedAt || new Date().toISOString(),
              actor: 'MODERATOR' as const,
              actorName: 'Adjudication Officer',
              title: 'Moderation Note Added',
              description: raw.moderatorNotes,
              badge: rawStatus,
            },
          ]
        : []),
    ],
    moderatorNotes: raw.moderationNotes || undefined,
    merchantResponse: raw.merchantResponse || undefined,
    consumerName: raw.user?.displayName || (raw.user?.email ? raw.user.email.split('@')[0] : 'Registered Citizen'),
    consumerEmail: raw.user?.email || 'citizen@priceshield.org',
    consumerPhoneMasked: raw.user?.mobile || (raw.utrNumber ? `+91 98••• •${raw.id.slice(-4)}` : '+91 98•••• 4521'),
    description: raw.description || undefined,
    consumerTrustScore: raw.user?.trustScore ?? 85,
  };
}

// Start Server-Sent Events (SSE) listener for live dashboard synchronization
export function initRealtimeEventSource(forceReconnect = false) {
  if (typeof window === 'undefined') return;
  if (eventSource && !forceReconnect) return;

  if (eventSource) {
    try {
      eventSource.close();
    } catch (_) {}
    eventSource = null;
  }

  try {
    const streamUrl = `${getApiBaseUrl()}/complaints/stream?adminKey=${encodeURIComponent(ADMIN_API_KEY)}`;
    eventSource = new EventSource(streamUrl);

    eventSource.onopen = () => {
      isBackendLive = true;
      window.dispatchEvent(new CustomEvent('priceshield_connection_change', { detail: { isLive: true } }));
    };

    eventSource.addEventListener('complaint_updated', (event: MessageEvent) => {
      try {
        const payload = JSON.parse(event.data);
        const complaint = payload.complaint;
        if (!complaint || !complaint.id) return;

        const idx = casesStore.findIndex((c) => c.id === complaint.id);
        const normalized = normalizeBackendComplaint(complaint);

        if (idx !== -1) {
          casesStore[idx] = {
            ...casesStore[idx],
            ...normalized,
            timeline: [
              ...casesStore[idx].timeline,
              {
                id: `tl-${Date.now()}`,
                timestamp: new Date().toISOString(),
                actor: 'MODERATOR',
                actorName: 'PriceShield Live Sync',
                title: `Case Updated: ${normalized.status.replace(/_/g, ' ')}`,
                description: normalized.moderatorNotes || `Live status synchronization dispatched.`,
                badge: normalized.status,
              },
            ],
          };
        } else {
          casesStore = [normalized, ...casesStore];
        }

        window.dispatchEvent(
          new CustomEvent('priceshield_case_updated', {
            detail: casesStore[idx !== -1 ? idx : 0],
          })
        );
      } catch (err) {
        console.warn('[Realtime SSE] Error parsing complaint_updated event', err);
      }
    });

    eventSource.onerror = () => {
      isBackendLive = false;
      window.dispatchEvent(new CustomEvent('priceshield_connection_change', { detail: { isLive: false } }));
    };
  } catch (err) {
    console.warn('[Realtime SSE] Could not initialize EventSource', err);
  }
}

// Auto-start SSE on module evaluation
if (typeof window !== 'undefined') {
  initRealtimeEventSource();
}

export const api = {
  getBackendStatus(): { isLive: boolean; apiUrl: string } {
    return { isLive: isBackendLive, apiUrl: getApiBaseUrl() };
  },

  // --- METRICS ---
  async getMetrics(): Promise<DashboardMetrics> {
    try {
      const res = await fetch(`${getApiBaseUrl()}/admin/metrics`, {
        headers: { 'x-admin-key': ADMIN_API_KEY },
      });
      if (res.ok) {
        const json = await res.json();
        if (json.data) {
          isBackendLive = true;
          return {
            ...mockDashboardMetrics,
            ...json.data,
          };
        }
      }
    } catch (_) {}

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
    // Attempt backend fetch
    try {
      const query = new URLSearchParams({ status: 'ALL', limit: '100' });
      const res = await fetch(`${getApiBaseUrl()}/admin/complaints?${query}`, {
        headers: { 'x-admin-key': ADMIN_API_KEY },
      });
      if (res.ok) {
        const json = await res.json();
        const serverItems = Array.isArray(json.data) ? json.data : (json.data?.items ?? []);
        if (Array.isArray(serverItems) && serverItems.length > 0) {
          isBackendLive = true;
          const normalizedServerCases = serverItems.map(normalizeBackendComplaint);

          // Merge: keep server cases, append unique mock cases for rich mock dockets
          const serverIds = new Set(normalizedServerCases.map((c) => c.id));
          const mockOnly = mockCases.filter((m) => !serverIds.has(m.id));
          casesStore = [...normalizedServerCases, ...mockOnly];
        }
      }
    } catch (_) {
      // Fallback to local store
    }

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
    if (found) return found;

    // Try fetching directly from backend
    try {
      const res = await fetch(`${getApiBaseUrl()}/admin/complaints?status=ALL&limit=100`, {
        headers: { 'x-admin-key': ADMIN_API_KEY },
      });
      if (res.ok) {
        const json = await res.json();
        const serverItems = Array.isArray(json.data) ? json.data : (json.data?.items ?? []);
        const raw = serverItems.find((s: any) => s.id === id);
        if (raw) {
          const item = normalizeBackendComplaint(raw);
          casesStore = [item, ...casesStore];
          return item;
        }
      }
    } catch (_) {}

    return null;
  },

  async updateCaseStatus(
    id: string,
    status: CaseStatus,
    notes?: string,
    merchantResponse?: string
  ): Promise<CaseItem> {
    // Send to backend
    try {
      await fetch(`${getApiBaseUrl()}/admin/complaints/${id}`, {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          'x-admin-key': ADMIN_API_KEY,
        },
        body: JSON.stringify({ status, moderationNotes: notes, merchantResponse }),
      });
    } catch (err) {
      console.warn('Backend patch failed, updated local store', err);
    }

    const index = casesStore.findIndex((c) => c.id === id);
    if (index === -1) throw new Error('Case not found');

    const updated: CaseItem = {
      ...casesStore[index],
      status,
      updatedAt: new Date().toISOString(),
      moderatorNotes: notes || casesStore[index].moderatorNotes,
      merchantResponse: merchantResponse || casesStore[index].merchantResponse,
      timeline: [
        ...casesStore[index].timeline,
        {
          id: `tl-${Date.now()}`,
          timestamp: new Date().toISOString(),
          actor: 'MODERATOR',
          actorName: 'Adjudication Desk Officer',
          title: `Status Changed to ${status.replace(/_/g, ' ')}`,
          description: notes || `Case status updated by operations officer.`,
          badge: status,
        },
      ],
    };

    casesStore[index] = updated;
    window.dispatchEvent(new CustomEvent('priceshield_case_updated', { detail: updated }));
    return updated;
  },

  async proposeMerchantSettlement(id: string, amount: number): Promise<CaseItem> {
    try {
      await fetch(`${getApiBaseUrl()}/admin/complaints/${id}`, {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          'x-admin-key': ADMIN_API_KEY,
        },
        body: JSON.stringify({
          status: 'SETTLEMENT_PROPOSED',
          settlementOfferedAmount: amount,
          moderationNotes: `Autonomous Conciliation: Dispatched 48h instant UPI refund conciliation offer for ₹${amount.toFixed(2)}.`,
        }),
      });
    } catch (err) {
      console.warn('Backend settlement patch failed, updated local store', err);
    }

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
    window.dispatchEvent(new CustomEvent('priceshield_case_updated', { detail: updated }));
    return updated;
  },

  // --- PRODUCTS CATALOG ---
  async getProducts(search?: string, category?: string): Promise<ProductItem[]> {
    try {
      const q = new URLSearchParams({ limit: '100' });
      if (search && search.trim()) q.set('search', search.trim());
      const res = await fetch(`${getApiBaseUrl()}/admin/products?${q}`, {
        headers: { 'x-admin-key': ADMIN_API_KEY },
      });
      if (res.ok) {
        const json = await res.json();
        const serverItems = Array.isArray(json.data) ? json.data : (json.data?.items ?? []);
        if (Array.isArray(serverItems) && serverItems.length > 0) {
          const mapped: ProductItem[] = serverItems.map((p: any) => ({
            id: p.id,
            barcode: p.barcode,
            name: p.name,
            brand: 'Verified Brand',
            category: 'Packaged Goods',
            mrp: Number(p.mrp || 0),
            source: 'ADMIN',
            verifiedScansCount: 1,
            createdAt: p.createdAt || new Date().toISOString(),
            updatedAt: p.updatedAt || new Date().toISOString(),
          }));
          const serverBarcodes = new Set(mapped.map((m) => m.barcode));
          const mockFiltered = mockProducts.filter((m) => !serverBarcodes.has(m.barcode));
          productsStore = [...mapped, ...mockFiltered];
        }
      }
    } catch (_) {}

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
    try {
      await fetch(`${getApiBaseUrl()}/admin/products`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-admin-key': ADMIN_API_KEY,
        },
        body: JSON.stringify({
          barcode: product.barcode,
          name: product.name,
          mrp: product.mrp,
        }),
      });
    } catch (_) {}

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
    try {
      await fetch(`${getApiBaseUrl()}/admin/products/${id}`, {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          'x-admin-key': ADMIN_API_KEY,
        },
        body: JSON.stringify({ mrp: newMrp }),
      });
    } catch (_) {}

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
    try {
      const q = new URLSearchParams({ status: status || 'ALL', limit: '100' });
      const res = await fetch(`${getApiBaseUrl()}/admin/product-submissions?${q}`, {
        headers: { 'x-admin-key': ADMIN_API_KEY },
      });
      if (res.ok) {
        const json = await res.json();
        const serverItems = Array.isArray(json.data) ? json.data : (json.data?.items ?? []);
        if (Array.isArray(serverItems) && serverItems.length > 0) {
          const mapped: CommunitySubmissionItem[] = serverItems.map((s: any) => ({
            id: s.id,
            barcode: s.barcode,
            productName: s.productName || `Product ${s.barcode}`,
            brand: 'Community Verified',
            category: 'Packaged Goods',
            userSuggestedMrp: Number(s.printedMrp || 0),
            detectedOcrMrp: s.printedMrp ? Number(s.printedMrp) : undefined,
            detectedOcrText: s.ocrText,
            frontImageUrl: s.frontImageUrl,
            backImageUrl: s.backImageUrl,
            submittedByEmail: 'consumer@priceshield.org',
            submittedAt: s.createdAt || new Date().toISOString(),
            status: s.status,
            ocrConfidence: 94,
          }));
          const serverIds = new Set(mapped.map((m) => m.id));
          const mockOnly = mockSubmissions.filter((m) => !serverIds.has(m.id));
          submissionsStore = [...mapped, ...mockOnly];
        }
      }
    } catch (_) {}

    let list = [...submissionsStore];
    if (status && status !== 'ALL') {
      list = list.filter((s) => s.status === status);
    }
    return list;
  },

  async reviewSubmission(id: string, action: 'APPROVE' | 'REJECT', finalMrp?: number): Promise<CommunitySubmissionItem> {
    try {
      await fetch(`${getApiBaseUrl()}/admin/product-submissions/${id}`, {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          'x-admin-key': ADMIN_API_KEY,
        },
        body: JSON.stringify({
          status: action === 'APPROVE' ? 'REVIEWED' : 'REJECTED',
          ...(finalMrp ? { printedMrp: finalMrp } : {}),
        }),
      });
    } catch (_) {}

    const index = submissionsStore.findIndex((s) => s.id === id);
    if (index === -1) throw new Error('Submission not found');

    const sub = submissionsStore[index];
    const newStatus = action === 'APPROVE' ? 'APPROVED' : 'REJECTED';

    submissionsStore[index] = {
      ...sub,
      status: newStatus,
    };

    if (action === 'APPROVE') {
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
