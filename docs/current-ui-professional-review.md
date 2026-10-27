# PriceShield current UI review

## Overall assessment

PriceShield has a clear consumer-protection purpose and a recognizable visual direction: mint green for trust, dark navy for important actions, rounded cards, and a simple three-item navigation bar. It is a good prototype foundation.

Compared with polished consumer apps such as payments, shopping, and delivery products, the main gap is product maturity rather than color or decoration. Corporate apps make the next action obvious, keep every state understandable, handle failure inside the screen, and use one consistent design system across every flow.

Current UI maturity: **good prototype, not yet production-polished**.

## What is already working well

- The primary action, scanning a product, is easy to find.
- Home, complaints, and profile are separated into familiar navigation areas.
- Registration includes verification, resend protection, and password recovery.
- Complaint evidence supports image/video selection and Cloudinary upload.
- The app communicates the consumer-rights purpose clearly.
- Empty states such as “No scans yet” and “No complaints yet” are present.
- The current UI uses the live REST backend and does not reintroduce Firestore business data.

## Main corporate-level gaps

### 1. No central design system

Colors, spacing, typography, border radii, button heights, and shadows are repeated as inline values. This creates small differences between screens and makes future redesign expensive.

Create one theme with:

- semantic colors: primary, surface, background, success, warning, danger, muted text;
- typography styles for display, heading, body, label, and caption;
- spacing tokens such as 4, 8, 12, 16, 24, and 32;
- shared buttons, text fields, cards, status chips, loading indicators, and error panels;
- light and dark theme support from the same tokens.

### 2. Loading and error states are too generic

Several screens use a centered spinner or a short snackbar. A corporate app keeps the screen structure visible while loading, uses skeleton placeholders for lists, and gives a clear recovery action when a request fails.

Improve states to include:

- skeleton cards for dashboard, complaints, and profile;
- inline error panels with “Try again”;
- offline state with cached content where safe;
- a clear “server is waking up” message for Render cold starts;
- success confirmations after scan save, complaint submission, and profile update.

### 3. Home needs a stronger information hierarchy

The current home contains several cards, but the user’s most important decision is not always clear. The first screen should answer: “What can I do now?”, “What did I recently detect?”, and “What needs attention?”.

Recommended order:

1. greeting and account status;
2. primary scan action;
3. latest scan result or a useful empty state;
4. open complaint status;
5. recent activity;
6. rights education.

Avoid hard-coded achievement claims. Show real counts from the backend, and explain what each count means.

### 4. Scanner flow needs guidance and trust signals

The camera screen should include a visible scan frame, lighting guidance, a manual barcode entry fallback, and a clear permission explanation. After detection, show a short progress state while product information is fetched.

The result screen should make the decision immediate:

- MRP;
- amount charged;
- exact overcharge amount;
- clear “Within MRP” or “Overcharged” status;
- next action: “Save scan” or “File complaint”.

Use accessible color plus text and icons. Red/green alone is not sufficient.

### 5. Complaint creation is powerful but needs a guided step flow

The complaint screen contains many fields and media actions. It should be divided into steps:

1. product and price;
2. purchase details;
3. shop/location;
4. evidence;
5. review and submit.

Show a progress indicator, field-level validation, upload progress, file size/type limits, retry for failed uploads, and a review summary before submission. Keep entered data when the user navigates back.

### 6. Complaint history needs clearer status language

Use a consistent status model: Draft, Submitted, Under review, More information needed, Resolved, Rejected, Withdrawn. Each status needs a short explanation and a next action.

The details screen should show a timeline with submission date, evidence, review updates, and the latest action available to the user.

### 7. Authentication screens need production polish

Current screens have a strong visual identity, but should add:

- password visibility toggle;
- password strength guidance;
- email keyboard and autofill hints;
- validation below each field instead of only a snackbar;
- disabled state with progress text;
- verification screen actions for “Open email app”, “I verified”, and “Resend”;
- clear handling for an existing but unverified email;
- accessible labels and minimum 48dp touch targets.

Do not expose provider names or technical error codes to users.

### 8. Profile needs account and privacy controls

Add a clear account section with:

- verified email badge;
- edit profile;
- profile photo upload progress and retry;
- complaint history;
- notification preferences;
- privacy policy and terms;
- delete-account request flow;
- sign out confirmation.

Profile photos should show a placeholder, upload state, failed-upload retry, and a crop/compression step.

## Accessibility and responsive design

Before release, verify:

- text scales to at least 200% without clipping;
- contrast meets WCAG AA for text and controls;
- every icon-only button has a semantic label;
- focus order works with TalkBack;
- errors are announced and shown next to the relevant field;
- landscape, small phones, and large phones do not overflow;
- content is not hidden behind the bottom navigation or scan button;
- touch targets are at least 48dp.

## Copy and trust improvements

Use short, calm, user-facing language. Examples:

- “A verification link was sent to your email.”
- “We’re waking up the service. This may take a few seconds.”
- “Your scan was saved.”
- “We couldn’t upload the evidence. Try again.”
- “The shop charged ₹20 above the printed MRP.”

Avoid raw exceptions, provider names, database terms, and messages such as “unexpected error” without a recovery action.

## Recommended priority roadmap

### P0 — release blockers

- Add a shared theme and shared components.
- Fix all overflow and text encoding issues, including broken rupee symbols.
- Add field-level validation and accessible labels.
- Add skeleton/loading/error/retry states to every network screen.
- Make Render cold-start handling clear and resilient.
- Verify scan, complaint, profile, and authentication flows on a clean release APK.

### P1 — professional product quality

- Redesign complaint creation as a guided step flow.
- Add complaint status timeline and meaningful status explanations.
- Add scanner overlay, manual barcode fallback, and permission education.
- Add profile photo crop, progress, retry, and privacy/account settings.
- Add analytics for scan completion, complaint submission, and verification drop-off without recording sensitive values.

### P2 — differentiation

- Saved product watchlist and repeat scans.
- Price history per product and location.
- Nearby consumer-help resources.
- Export/share a complaint summary.
- Multi-language Hindi/English support.
- Offline scan draft that synchronizes when the network returns.

## Definition of a professional release

The UI is ready for a serious beta when a new user can register, verify, scan, understand the price result, submit evidence, track a complaint, recover from an offline/error state, and complete the same flow using TalkBack without developer assistance.

The next best implementation phase is P0: centralize the design system and standardize loading, validation, error, and success states before adding new features.
