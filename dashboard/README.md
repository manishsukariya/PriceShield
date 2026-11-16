# PriceShield Admin & Operations Dashboard

Modern, high-performance web dashboard for the **PriceShield Consumer Protection & Anti-Overcharging Platform**. Designed for legal moderators, operations teams, and regulatory enforcement officers to monitor real-time consumer scans, audit tamper-evident evidence, settle retail disputes via the 48-Hour Digital Conciliation Protocol, and curate the master FMCG product catalog.

---

## 🚀 Key Modules & Architecture

### 1. Operations Command Center (`/`)
- **Real-Time KPI Tracking**: Total scans today/month, overcharge violation rate %, consumer restitution amount, and resolution SLA metrics.
- **Visual Analytics**: Daily scan inflow vs. overcharge rate area charts and top offending category distribution (Beverages, Dairy, Snacks).
- **Live Consumer Scanner Telemetry**: Auto-refreshing feed of physical barcode checks from mobile users across India.

### 2. Next-Gen Complaints & Dispute Adjudication (`/cases` & `/cases/:id`)
- **Beyond-NCH Autonomous Conciliation Engine**:
  - **Evidence Inspector**: Side-by-side visual comparator of physical packet packaging OCR vs. transaction receipts (UPI UTR / Itemized Bills).
  - **Cryptographic Tamper-Proofing**: Image SHA-256 collision detection, 12-digit UTR replay guard, and venue classification enforcement.
  - **48-Hour Digital Settlement Protocol (AMCP)**: 1-Click dispatch of WhatsApp/SMS conciliation notices with instant UPI refund deep-links.
  - **Certified Statutory Dockets**: 1-Click generation of formal grievance packets citing Rule 18(2) of Legal Metrology Rules, 2011 and Section 36(1) of Legal Metrology Act, 2009 for E-Daakhil / DCDRC submission.

### 3. FMCG Catalog & Community OCR Review (`/products` & `/submissions`)
- **Master Product Catalog**: Searchable, debounced table of verified FMCG products with instant inline MRP editor and "Add Product" modal.
- **Community Submissions Queue**: Triage unknown products uploaded by mobile app users with on-device OCR packaging scans, with 1-click catalog approval.

### 4. Merchant Watchlist & Hotspots (`/merchants`)
- High-risk store leaderboard with automated Trust Scores (0-100) and Risk Bands (`GREEN`, `AMBER`, `RED`, `CRITICAL` for inspection raids).

---

## 🛠️ Tech Stack
- **Framework**: Vite + React 18 with TypeScript
- **Styling**: Tailwind CSS with custom PriceShield design tokens (`navy-900`, `brand-teal`, `mint`, `slate`)
- **Icons**: Lucide React
- **Data & State**: TanStack-style reactive API client with dual-mode (REST API + Local Mock Store fallback)
- **Charts**: Recharts (Responsive Area & Bar visualizations)
- **Routing**: React Router v6 with Protected Route guards

---

## ⚡ Getting Started

### 1. Installation
\`\`\`bash
cd dashboard
npm install
\`\`\`

### 2. Environment Setup (Optional)
Copy `.env.example` to `.env`:
\`\`\`bash
cp .env.example .env
\`\`\`

### 3. Development Server
\`\`\`bash
npm run dev
\`\`\`
The dashboard will start at `http://localhost:3000`.

### 4. Production Build
\`\`\`bash
npm run build
\`\`\`
Outputs optimized static assets to `dashboard/dist/`.

---

## 🔐 Role-Based Access
- **Super Admin**: Full permissions to edit catalog, adjust risk policies, and resolve disputes.
- **Legal Moderator**: Inspects evidence, dispatches conciliation notices, and prepares statutory dockets.
- **Ops Investigator**: Monitors live scanner feeds and merchant watchlists.
