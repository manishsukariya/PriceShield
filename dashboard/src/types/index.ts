export type CaseStatus =
  | 'PENDING'
  | 'INVESTIGATING'
  | 'MERCHANT_NOTIFIED'
  | 'SETTLEMENT_PROPOSED'
  | 'RESOLVED'
  | 'REJECTED'
  | 'ESCALATED_LEGAL_METROLOGY';

export type EvidenceConfidence =
  | 'UNVERIFIED'
  | 'BASIC'
  | 'STRONG'
  | 'CORROBORATED';

export type PaymentMethod = 'UPI' | 'CASH' | 'CARD';
export type VenueType = 'RETAIL' | 'RESTAURANT';

export type EvidenceRole =
  | 'PACKET_MRP'
  | 'PAYMENT_PROOF'
  | 'ITEMIZED_BILL'
  | 'VIDEO_PROOF'
  | 'STOREFRONT'
  | 'OTHER';

export interface EvidenceItem {
  id: string;
  url: string;
  role: EvidenceRole;
  mediaType: 'IMAGE' | 'VIDEO';
  sha256Hash?: string;
  ocrDetectedText?: string;
  ocrDetectedAmount?: number;
  ocrUtr?: string;
  capturedViaCamera?: boolean;
  uploadedAt: string;
}

export interface DisputeTimelineEvent {
  id: string;
  timestamp: string;
  actor: 'CONSUMER' | 'SYSTEM_AI' | 'MERCHANT' | 'MODERATOR' | 'REGULATOR';
  actorName: string;
  title: string;
  description: string;
  badge?: string;
}

export interface CaseItem {
  id: string;
  docketId: string;
  createdAt: string;
  updatedAt: string;
  barcode: string;
  productName: string;
  category: string;
  quantity: number;
  printedMrp: number;
  chargedPrice: number;
  overchargeAmount: number;
  totalBasketAmount: number;
  paymentMethod: PaymentMethod;
  utrNumber?: string;
  merchantName: string;
  merchantVpa?: string;
  storeAddress: string;
  city: string;
  state: string;
  latitude?: number;
  longitude?: number;
  venueType: VenueType;
  status: CaseStatus;
  confidenceLevel: EvidenceConfidence;
  riskScore: number;
  riskFlags: string[];
  evidence: EvidenceItem[];
  timeline: DisputeTimelineEvent[];
  merchantNotifiedAt?: string;
  settlementOfferedAmount?: number;
  settlementStatus?: 'AWAITING_REPLY' | 'ACCEPTED' | 'DECLINED' | 'EXPIRED';
  moderatorNotes?: string;
  merchantResponse?: string;
  consumerName: string;
  consumerEmail: string;
  consumerPhoneMasked: string;
  description?: string;
  consumerTrustScore?: number;
}

export interface ProductItem {
  id: string;
  barcode: string;
  name: string;
  brand: string;
  category: string;
  mrp: number;
  sizeOrWeight?: string;
  imageUrl?: string;
  source: 'ADMIN' | 'OFF' | 'USER_VERIFIED';
  verifiedScansCount: number;
  createdAt: string;
  updatedAt: string;
}

export interface CommunitySubmissionItem {
  id: string;
  barcode: string;
  productName: string;
  brand?: string;
  category?: string;
  userSuggestedMrp: number;
  frontImageUrl?: string;
  backImageUrl?: string;
  detectedOcrMrp?: number;
  detectedOcrText?: string;
  ocrConfidence: number; // 0 to 100
  submittedByEmail: string;
  submittedAt: string;
  status: 'PENDING' | 'APPROVED' | 'REJECTED';
}

export interface MerchantItem {
  id: string;
  storeName: string;
  normalizedName: string;
  merchantVpa?: string;
  address: string;
  city: string;
  state: string;
  latitude: number;
  longitude: number;
  trustScore: number; // 0 - 100
  riskBand: 'GREEN' | 'AMBER' | 'RED' | 'CRITICAL';
  totalComplaintsCount: number;
  verifiedViolationsCount: number;
  settlementRate: number; // percentage
  unresolvedAmount: number;
  lastIncidentAt: string;
  status: 'ACTIVE_SURVEILLANCE' | 'UNDER_REVIEW' | 'FLAGGED_FOR_INSPECTION' | 'COMPLIANT';
}

export interface ScanFeedItem {
  id: string;
  timestamp: string;
  barcode: string;
  productName: string;
  printedMrp: number;
  chargedPrice: number;
  overcharge: number;
  isOvercharged: boolean;
  storeName: string;
  city: string;
  devicePlatform: 'Android' | 'iOS';
}

export interface DashboardMetrics {
  totalScansToday: number;
  totalScansMonth: number;
  scansGrowthPercent: number;
  overchargeIncidentsCount: number;
  overchargeRatePercent: number;
  activeCasesCount: number;
  casesAwaitingReview: number;
  totalOverchargedRupees: number;
  totalRecoveredRupees: number;
  avgResolutionHours: number;
  merchantsWatchlisted: number;
}
