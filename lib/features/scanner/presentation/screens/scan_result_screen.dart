import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:priceshield/core/services/auth_session.dart';
import 'package:priceshield/core/services/priceshield_api_client.dart';
import 'package:priceshield/core/theme/app_theme.dart';
import 'package:priceshield/core/widgets/app_ui.dart';
import 'package:priceshield/features/complaints/presentation/screens/complaint_screen.dart';
import 'package:priceshield/features/complaints/services/escalation_pack_service.dart';
import 'package:priceshield/features/deescalation/models/deescalation_data.dart';
import 'package:priceshield/features/deescalation/presentation/screens/deescalation_screen.dart';
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
  });

  final String name;
  final String barcode;
  final num mrp;
  final num charged;
  final PackagingComplianceResult? complianceResult;
  final String venueType;
  final bool isStickerFlagged;

  @override
  State<ScanResultScreen> createState() => _ScanResultScreenState();
}

class _ScanResultScreenState extends State<ScanResultScreen> {
  @override
  void initState() {
    super.initState();
    _recordScan();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.shield_rounded, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '🛡️ +50 ShieldPoints Earned! (Scout Level 1)',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ],
            ),
            backgroundColor: PriceShieldColors.primary,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    });
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

  Future<void> _copyWhatsAppNotice() async {
    final notice = EscalationPackService.generateWhatsAppNotice(
      productName: widget.name,
      barcode: widget.barcode,
      mrp: widget.mrp,
      chargedPrice: widget.charged,
      complianceResult: widget.complianceResult,
    );
    await Clipboard.setData(ClipboardData(text: notice));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Legal Notice copied to clipboard! Ready to share on WhatsApp or Email.'),
          backgroundColor: PriceShieldColors.navy,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _exportOfficialDocket() async {
    final docket = EscalationPackService.generateOfficialDocket(
      productName: widget.name,
      barcode: widget.barcode,
      mrp: widget.mrp,
      chargedPrice: widget.charged,
      complianceResult: widget.complianceResult,
    );
    await Clipboard.setData(ClipboardData(text: docket));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Official Grievance Docket copied! Ready for NCH 1915 or DCDRC.'),
          backgroundColor: PriceShieldColors.navy,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final overcharged = widget.charged > widget.mrp;
    final hasComplianceIssue = widget.complianceResult?.hasViolation == true;
    final difference = widget.charged - widget.mrp;
    final color = overcharged ? PriceShieldColors.danger : PriceShieldColors.success;

    return Scaffold(
      backgroundColor: PriceShieldColors.background,
      appBar: AppBar(title: const Text('Scan result')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          // Shield Scout Points Celebratory Badge
          Center(
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: PriceShieldColors.mint,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: PriceShieldColors.primary.withValues(alpha: 0.3)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.shield_rounded, color: PriceShieldColors.primary, size: 18),
                  SizedBox(width: 6),
                  Text(
                    '🛡️ +50 ShieldPoints Earned! (Scout Level 1)',
                    style: TextStyle(
                      color: PriceShieldColors.navy,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
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
            color: color,
            child: Column(
              children: [
                Icon(
                  overcharged ? Icons.warning_amber_rounded : Icons.verified_rounded,
                  color: Colors.white,
                  size: 44,
                ),
                const SizedBox(height: 12),
                Text(
                  overcharged ? 'Overcharge detected' : 'Price is within MRP',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (overcharged) ...[
                  const SizedBox(height: 6),
                  Text(
                    'You were charged \u{20B9}${difference.toStringAsFixed(2)} extra.',
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                  ),
                ],
              ],
            ),
          ),

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

          // Responsible Escalation Pack Service Actions
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: PriceShieldColors.mint,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.description_outlined,
                        color: PriceShieldColors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Responsible Escalation Pack',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          Text(
                            'Legal texts ready for merchant or consumer forum',
                            style: TextStyle(color: PriceShieldColors.muted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _copyWhatsAppNotice,
                    icon: const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xff25D366)),
                    label: const Text('Copy Legal Notice (WhatsApp/Email)'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: PriceShieldColors.border),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _exportOfficialDocket,
                    icon: const Icon(Icons.assignment_outlined, color: PriceShieldColors.primary),
                    label: const Text('Export Official Grievance Docket'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: PriceShieldColors.border),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Actions when overcharge is detected
          if (overcharged) ...[
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
                    ),
                  ),
                ),
                icon: const Icon(Icons.report_problem_outlined),
                label: const Text('File a formal complaint'),
              ),
            ),
            const SizedBox(height: 12),
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
        ],
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
                        'Never risk your safety arguing with hostile or aggressive shopkeepers. Follow this 3-step silent evidence playbook to hold them legally accountable safely.',
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
                          initialNotes:
                              'Silent evidence report filed via PriceShield Stealth Safe-Exit Mode. Charged ₹${widget.charged} against printed MRP ₹${widget.mrp} (Overcharge: ₹${(widget.charged - widget.mrp).toStringAsFixed(2)}). Merchant UPI proof attached.',
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
