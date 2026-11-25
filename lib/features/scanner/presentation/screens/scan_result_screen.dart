import 'package:flutter/material.dart';
import 'package:priceshield/core/services/auth_session.dart';
import 'package:priceshield/core/services/priceshield_api_client.dart';
import 'package:priceshield/core/theme/app_theme.dart';
import 'package:priceshield/core/widgets/app_ui.dart';
import 'package:priceshield/features/complaints/presentation/screens/complaint_screen.dart';
import 'package:priceshield/features/deescalation/models/deescalation_data.dart';
import 'package:priceshield/features/deescalation/presentation/screens/deescalation_screen.dart';
import 'package:priceshield/features/scanner/models/terrain_context.dart';
import 'package:priceshield/features/scanner/services/packaging_compliance_service.dart';

class ScanResultScreen extends StatefulWidget {
  const ScanResultScreen({
    super.key,
    required this.name,
    required this.barcode,
    required this.mrp,
    required this.charged,
    this.complianceResult,
    this.venueType = 'RETAIL',
    this.isStickerFlagged = false,
    this.terrainType = TerrainType.plains,
    this.itemFormType = ItemFormType.sealedPack,
  });

  final String name;
  final String barcode;
  final num mrp;
  final num charged;
  final PackagingComplianceResult? complianceResult;
  final String venueType;
  final bool isStickerFlagged;
  final TerrainType terrainType;
  final ItemFormType itemFormType;

  @override
  State<ScanResultScreen> createState() => _ScanResultScreenState();
}

class _ScanResultScreenState extends State<ScanResultScreen> {
  @override
  void initState() {
    super.initState();
    _recordScan();
  }

  Future<void> _recordScan() async {
    if (!priceShieldApi.isConfigured || !AuthSession.isSignedIn) return;
    try {
      await priceShieldApi.createScan(
        barcode: widget.barcode,
        productName: widget.name,
        mrp: widget.mrp,
        chargedPrice: widget.charged,
        clientRequestId: 'scan-${DateTime.now().microsecondsSinceEpoch}-${widget.barcode}',
      );
    } catch (e) {
      debugPrint('Could not persist scan history: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final overcharged = widget.charged > widget.mrp;
    final isRestaurantVenue = widget.venueType.trim().toUpperCase() == 'RESTAURANT';
    final hasComplianceIssue = widget.complianceResult?.hasViolation == true;
    final difference = widget.charged - widget.mrp;

    final terrainEval = TerrainEvaluation.evaluate(
      mrp: widget.mrp,
      charged: widget.charged,
      terrain: widget.terrainType,
      itemForm: widget.itemFormType,
    );

    // Primary card styling based on terrain and legality
    final Color primaryColor;
    final IconData primaryIcon;
    final String primaryTitle;
    final String primarySubtitle;

    switch (terrainEval.verdictType) {
      case TerrainVerdictType.cookedExempt:
        primaryColor = PriceShieldColors.navy;
        primaryIcon = Icons.soup_kitchen_rounded;
        primaryTitle = 'Cooked Dhaba Food (MRP Exempt)';
        primarySubtitle = 'Under SC FHRAI 2017: Service meal is exempt from packaged MRP';
        break;
      case TerrainVerdictType.fairPorterageAllowance:
        primaryColor = const Color(0xff0D9488);
        primaryIcon = Icons.hiking_rounded;
        primaryTitle = 'Fair Mountain Porterage';
        primarySubtitle = 'Extra \u{20B9}${difference.toStringAsFixed(0)} within DM / Shrine Board porterage guidelines';
        break;
      case TerrainVerdictType.illegalHillSurcharge:
        primaryColor = PriceShieldColors.danger;
        primaryIcon = Icons.terrain_rounded;
        primaryTitle = 'Illegal Hill Station Surcharge';
        primarySubtitle = 'Charged \u{20B9}${difference.toStringAsFixed(2)} extra on road-connected hill station';
        break;
      case TerrainVerdictType.extortionPriceGouging:
        primaryColor = const Color(0xff991B1B);
        primaryIcon = Icons.warning_rounded;
        primaryTitle = 'Predatory Mountain Price Gouging';
        primarySubtitle = 'Extortionate demand: \u{20B9}${widget.charged.toStringAsFixed(0)} on \u{20B9}${widget.mrp.toStringAsFixed(0)} pack (+\u{20B9}${difference.toStringAsFixed(0)})';
        break;
      case TerrainVerdictType.withinMrp:
        primaryColor = PriceShieldColors.success;
        primaryIcon = Icons.verified_rounded;
        primaryTitle = 'Price is within MRP';
        primarySubtitle = 'Fair transaction complying with Legal Metrology Rules';
        break;
      case TerrainVerdictType.illegalPlainsOvercharge:
        primaryColor = PriceShieldColors.danger;
        primaryIcon = Icons.warning_amber_rounded;
        primaryTitle = 'Overcharge detected';
        primarySubtitle = 'You were charged \u{20B9}${difference.toStringAsFixed(2)} extra.';
        break;
    }

    return Scaffold(
      backgroundColor: PriceShieldColors.background,
      appBar: AppBar(title: const Text('Scan result')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          // Consumer Advisory Badge
          Center(
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              constraints: const BoxConstraints(maxWidth: 340),
              decoration: BoxDecoration(
                color: PriceShieldColors.mint,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: PriceShieldColors.primary.withValues(alpha: 0.3)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.shield_rounded, color: PriceShieldColors.primary, size: 16),
                  SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Consumer Advisory • Verify packet MRP & save receipt',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: PriceShieldColors.navy,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Dine-in Venue Context Alert Card (SC FHRAI 2017)
          if (widget.venueType == 'RESTAURANT') ...[
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xffFFFBEB),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xffF59E0B), width: 1.2),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.restaurant_rounded, color: Color(0xffB45309), size: 22),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'DINE-IN VENUE CONTEXT (SC FHRAI 2017)',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            color: Color(0xffB45309),
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Under the 2017 Supreme Court judgment, seated restaurants providing table service & ambiance are not restricted to printed MRP. However, if this was an over-the-counter takeaway or retail stall, MRP strictly applies.',
                          style: TextStyle(fontSize: 12, color: Color(0xff78350F), height: 1.35),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Primary Price Status Card
          AppCard(
            color: primaryColor,
            child: Column(
              children: [
                Icon(
                  primaryIcon,
                  color: Colors.white,
                  size: 44,
                ),
                const SizedBox(height: 12),
                Text(
                  primaryTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  primarySubtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ],
            ),
          ),

          // Terrain & Mountain Context Card
          if (widget.terrainType != TerrainType.plains ||
              widget.itemFormType == ItemFormType.cookedDhaba) ...[
            Container(
              margin: const EdgeInsets.only(top: 14),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: terrainEval.isViolation
                    ? const Color(0xffFEF2F2)
                    : (terrainEval.isFairAllowance
                        ? const Color(0xffF0FDFA)
                        : const Color(0xffF8FAFC)),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: terrainEval.isViolation
                      ? const Color(0xffFCA5A5)
                      : (terrainEval.isFairAllowance
                          ? const Color(0xff5EEAD4)
                          : const Color(0xffCBD5E1)),
                  width: 1.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: terrainEval.isViolation
                              ? const Color(0xffFEE2E2)
                              : (terrainEval.isFairAllowance
                                  ? const Color(0xffCCFBF1)
                                  : const Color(0xffE2E8F0)),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          widget.itemFormType == ItemFormType.cookedDhaba
                              ? Icons.soup_kitchen_rounded
                              : (widget.terrainType == TerrainType.remoteTrek
                                  ? Icons.hiking_rounded
                                  : Icons.terrain_rounded),
                          color: terrainEval.isViolation
                              ? const Color(0xffB91C1C)
                              : (terrainEval.isFairAllowance
                                  ? const Color(0xff0F766E)
                                  : PriceShieldColors.navy),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.itemFormType == ItemFormType.cookedDhaba
                                  ? 'DHABA / COOKED FOOD REGULATION'
                                  : (widget.terrainType == TerrainType.remoteTrek
                                      ? 'REMOTE TREK & MULE PORTERAGE CONTEXT'
                                      : 'MOTORABLE HILL STATION LOGISTICS'),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                                color: terrainEval.isViolation
                                    ? const Color(0xffB91C1C)
                                    : (terrainEval.isFairAllowance
                                        ? const Color(0xff0F766E)
                                        : PriceShieldColors.navy),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              terrainEval.title,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: terrainEval.isViolation
                                    ? const Color(0xff991B1B)
                                    : (terrainEval.isFairAllowance
                                        ? const Color(0xff115E59)
                                        : const Color(0xff1E293B)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    terrainEval.explanation,
                    style: TextStyle(
                      fontSize: 13,
                      color: terrainEval.isViolation
                          ? const Color(0xff7F1D1D)
                          : (terrainEval.isFairAllowance
                              ? const Color(0xff134E4A)
                              : const Color(0xff334155)),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: terrainEval.isViolation
                            ? const Color(0xffFECACA)
                            : (terrainEval.isFairAllowance
                                ? const Color(0xff99F6E4)
                                : const Color(0xffE2E8F0)),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.gavel_rounded,
                          size: 16,
                          color: terrainEval.isViolation
                              ? const Color(0xffB91C1C)
                              : (terrainEval.isFairAllowance
                                  ? const Color(0xff0F766E)
                                  : PriceShieldColors.navy),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            terrainEval.legalAdvice,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: terrainEval.isViolation
                                  ? const Color(0xff991B1B)
                                  : (terrainEval.isFairAllowance
                                      ? const Color(0xff115E59)
                                      : const Color(0xff1E293B)),
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Packaging Compliance Alert Card (Prominent, amber border, shield icon, legal advice)
          if (hasComplianceIssue) ...[
            Container(
              margin: const EdgeInsets.only(top: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xffFFFBEB),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xffF59E0B), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xffF59E0B).withValues(alpha: 0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xffFDE68A),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.shield_outlined,
                          color: Color(0xffB45309),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'PACKAGING COMPLIANCE ALERT',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                                color: Color(0xffB45309),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.complianceResult!.title,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Color(0xff78350F),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.complianceResult!.description,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xff92400E),
                      height: 1.4,
                    ),
                  ),
                  if (widget.complianceResult!.matchedSnippet != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xffFCD34D)),
                      ),
                      child: Text(
                        'Package Text: "${widget.complianceResult!.matchedSnippet}"',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xff78350F),
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xffFDE68A)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.gavel_rounded, size: 16, color: Color(0xffB45309)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.complianceResult!.legalAdvice,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Color(0xff78350F),
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Product Details Card
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.name, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 5),
                Text(
                  'Barcode: ${widget.barcode}',
                  style: const TextStyle(color: PriceShieldColors.muted, fontSize: 12),
                ),
                const Divider(height: 28),
                _row('Printed MRP', widget.mrp),
                _row('Amount charged', widget.charged),
                _row(
                  'Difference',
                  difference,
                  overcharged ? PriceShieldColors.danger : PriceShieldColors.success,
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Gated Legal Notice & Grievance Docket Info Card (prevents premature public accusation)
          AppCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (isRestaurantVenue || terrainEval.isExempt || terrainEval.isFairAllowance)
                        ? const Color(0xffFEF3C7)
                        : (!terrainEval.isViolation
                            ? PriceShieldColors.mint
                            : PriceShieldColors.mint),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.lock_outline_rounded,
                    color: (isRestaurantVenue || terrainEval.isExempt || terrainEval.isFairAllowance)
                        ? const Color(0xffB45309)
                        : PriceShieldColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isRestaurantVenue
                            ? 'Formal MRP Docket Not Applicable (Dine-In)'
                            : (terrainEval.isExempt
                                ? 'Formal MRP Docket Not Applicable (Cooked Meal)'
                                : (terrainEval.isFairAllowance
                                    ? 'No Legal Violation (Fair Porterage Allowance)'
                                    : (!overcharged
                                        ? 'Legal Docket Locked (Within MRP)'
                                        : 'Legal Notice & Docket Locked Until Logged'))),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isRestaurantVenue
                            ? 'Under SC FHRAI (2017), seated restaurants providing table service & ambiance are not restricted to printed MRP. However, if this was an over-the-counter takeaway or retail stall, MRP strictly applies.'
                            : (terrainEval.isExempt
                                ? 'Under SC FHRAI (2017), cooked food and hot beverages served at high altitude dhabas are exempt from packaged MRP limits.'
                                : (terrainEval.isFairAllowance
                                    ? 'Charge is within official District Administration approved porterage rate guidelines for non-motorable mule trails.'
                                    : (!overcharged
                                        ? 'No overcharge above printed MRP was detected. Official grievance dockets are only available after logging a retail overcharge complaint.'
                                        : 'To prevent unverified accusations, Legal Notice and Official Grievance Docket export unlock after you log a formal complaint with Packet MRP and transaction proof.'))),
                        style: const TextStyle(
                          color: PriceShieldColors.muted,
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Actions when overcharge / violation is detected
          if (terrainEval.isViolation && !isRestaurantVenue) ...[
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DeescalationScreen(
                      initialData: DeescalationData(
                        productName: widget.name,
                        barcode: widget.barcode,
                        mrp: widget.mrp,
                        chargedPrice: widget.charged,
                      ),
                    ),
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: PriceShieldColors.navy,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.gavel_rounded, color: Color(0xfff59e0b)),
                label: const Text('De-escalation Co-Pilot & Law Card'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 50,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ComplaintScreen(
                      name: widget.name,
                      barcode: widget.barcode,
                      mrp: widget.mrp,
                      charged: widget.charged,
                      venueType: widget.terrainType == TerrainType.remoteTrek
                          ? 'HIGH_ALTITUDE_TREK'
                          : widget.venueType,
                      initialNotes: widget.terrainType == TerrainType.remoteTrek
                          ? 'Mountain trek overcharge recorded. Charged ₹${widget.charged} vs printed MRP ₹${widget.mrp} (Overcharge: ₹${difference.toStringAsFixed(2)}). District Magistrate Approved Rate List violation reported.'
                          : null,
                    ),
                  ),
                ),
                icon: const Icon(Icons.report_problem_outlined),
                label: const Text('File a formal complaint'),
              ),
            ),
            const SizedBox(height: 12),
            if (widget.terrainType == TerrainType.remoteTrek) ...[
              SizedBox(
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: () => _openMountainSafeExitSheet(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xff065F46),
                    side: const BorderSide(color: Color(0xff34D399), width: 1.5),
                    backgroundColor: const Color(0xffECFDF5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.hiking_rounded, color: Color(0xff059669)),
                  label: const Text(
                    '🏔️ Mountain Safe-Exit ("Pehle Suraksha, Baad Me Ghero")',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
              ),
            ] else ...[
              SizedBox(
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: () => _openStealthSafeExitSheet(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xff4338CA),
                    side: const BorderSide(color: Color(0xffA5B4FC), width: 1.5),
                    backgroundColor: const Color(0xffEEF2FF),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.security_rounded, color: Color(0xff4F46E5)),
                  label: const Text(
                    '🛡️ Stealth Safe-Exit ("Lado Mat, Baad Me Ghero")',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
              ),
            ],
          ] else if (terrainEval.isFairAllowance) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xffF0FDFA),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xff99F6E4)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.thumb_up_alt_rounded, color: Color(0xff0D9488), size: 22),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Fair Mountain Porterage: This markup is within District Magistrate approved porterage allowances for mule transport.',
                      style: TextStyle(fontSize: 12, color: Color(0xff115E59), fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (terrainEval.isExempt) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xffF1F5F9),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xffCBD5E1)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: Color(0xff475569), size: 22),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Prepared Food Exemption: Under Supreme Court jurisprudence, hot meals and dhaba cooking are priced by the establishment.',
                      style: TextStyle(fontSize: 12, color: Color(0xff334155), fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _openMountainSafeExitSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xffECFDF5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xffA7F3D0)),
                    ),
                    child: const Icon(Icons.terrain_rounded, color: Color(0xff059669), size: 26),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Mountain Safe-Exit Mode',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xff064E3B),
                          ),
                        ),
                        Text(
                          '“Pehle Suraksha, Baad Me Ghero” • Life & Safety First',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xff047857),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xffFEF3C7),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xffFCD34D)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Color(0xffB45309), size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'On cliffside trails, high altitudes, and remote passes, arguing with stall owners risks personal safety, hypothermia, or getting stranded. Follow this 4-step safe protocol.',
                        style: TextStyle(fontSize: 12, color: Color(0xff78350F), height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _buildStealthStep(
                stepNum: '1',
                title: 'Prioritize Physical Survival & Stay Calm',
                desc:
                    'Pay the demanded amount quietly and stay hydrated. Never engage in heated arguments on steep mountain trails or in extreme weather.',
                icon: Icons.favorite_rounded,
              ),
              const SizedBox(height: 12),
              _buildStealthStep(
                stepNum: '2',
                title: 'Note Tent/Stall ID or UPI QR Code',
                desc:
                    'Silently snap a photo of the stall number, tent banner, or merchant UPI QR stand. UPI merchant VPA permanently proves the shopkeeper’s identity.',
                icon: Icons.qr_code_scanner_rounded,
              ),
              const SizedBox(height: 12),
              _buildStealthStep(
                stepNum: '3',
                title: 'Queue Offline on Local Device Storage',
                desc:
                    'High mountain routes usually have zero mobile signal. PriceShield saves this scan locally with timestamp and offline GPS coordinates.',
                icon: Icons.cloud_off_rounded,
              ),
              const SizedBox(height: 12),
              _buildStealthStep(
                stepNum: '4',
                title: 'File at Base Camp / Roadhead',
                desc:
                    'When you return to base camp with mobile network, submit this report directly to the District Magistrate (DM), Shrine Board, or NCH 1915.',
                icon: Icons.assignment_turned_in_rounded,
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ComplaintScreen(
                          name: widget.name,
                          barcode: widget.barcode,
                          mrp: widget.mrp,
                          charged: widget.charged,
                          venueType: 'HIGH_ALTITUDE_TREK',
                          initialNotes:
                              'Mountain trek price gouging documented via PriceShield Mountain Safe-Exit Protocol. Charged ₹${widget.charged} vs printed MRP ₹${widget.mrp} (Porterage markup ₹${(widget.charged - widget.mrp).toStringAsFixed(2)}). Official District Magistrate Approved Rate List violation reported from base camp.',
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff059669),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save Offline & File from Base Camp', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(sheetContext),
                  child: const Text('Close / I Am Safe on the Trail', style: TextStyle(color: PriceShieldColors.muted)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openStealthSafeExitSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xffEEF2FF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xffC7D2FE)),
                    ),
                    child: const Icon(Icons.shield_rounded, color: Color(0xff4F46E5), size: 26),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Stealth Safe-Exit Mode',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xff1E1B4B),
                          ),
                        ),
                        Text(
                          '“Lado Mat, Baad Me Ghero” • Safety #1',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xff4338CA),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xffFEF3C7),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xffFCD34D)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Color(0xffB45309), size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Never risk your safety arguing with hostile or aggressive shopkeepers. Follow this 3-step silent evidence checklist to document the incident safely for verification and reporting.',
                        style: TextStyle(fontSize: 12, color: Color(0xff78350F), height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _buildStealthStep(
                stepNum: '1',
                title: 'Pay Digitally via UPI & Keep Digital Proof',
                desc:
                    'Pay the requested amount quietly via UPI (GPay/PhonePe/Paytm). The UPI transaction ID records the merchant’s registered business name, VPA, and timestamp.',
                icon: Icons.qr_code_scanner_rounded,
              ),
              const SizedBox(height: 12),
              _buildStealthStep(
                stepNum: '2',
                title: 'Leave Calmly Without Argument',
                desc:
                    'Take your item and leave the counter quietly. Your safety is paramount; never escalate at an isolated or crowded shop.',
                icon: Icons.directions_walk_rounded,
              ),
              const SizedBox(height: 12),
              _buildStealthStep(
                stepNum: '3',
                title: 'File Formal Complaint from Home',
                desc:
                    'Submit the transaction evidence directly to the National Consumer Helpline (NCH 1915) or state Legal Metrology Department from the safety of home.',
                icon: Icons.assignment_turned_in_rounded,
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ComplaintScreen(
                          name: widget.name,
                          barcode: widget.barcode,
                          mrp: widget.mrp,
                          charged: widget.charged,
                          venueType: widget.venueType,
                          initialNotes:
                              'Silent evidence report prepared via PriceShield Stealth Safe-Exit Mode. Charged ₹${widget.charged} against printed MRP ₹${widget.mrp} (Reported difference: ₹${(widget.charged - widget.mrp).toStringAsFixed(2)}). Attach UPI receipt / photo evidence below.',
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff4F46E5),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.file_upload_outlined),
                  label: const Text('Save Evidence & File Complaint from Home', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(sheetContext),
                  child: const Text('Close / I Am Safe Now', style: TextStyle(color: PriceShieldColors.muted)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStealthStep({
    required String stepNum,
    required String title,
    required String desc,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xffF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xffE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: const Color(0xffEEF2FF),
            child: Text(
              stepNum,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xff4F46E5)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xff1E293B)),
                ),
                const SizedBox(height: 3),
                Text(
                  desc,
                  style: const TextStyle(fontSize: 12, color: Color(0xff64748B), height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, num value, [Color color = PriceShieldColors.text]) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(
          children: [
            Expanded(child: Text(label, style: const TextStyle(color: PriceShieldColors.muted))),
            Text(
              '\u{20B9}${value.toStringAsFixed(2)}',
              style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 16),
            ),
          ],
        ),
      );
}
