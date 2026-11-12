import 'package:priceshield/features/scanner/services/packaging_compliance_service.dart';

/// Service generating responsible consumer notices and formal dockets for
/// merchant resolution, WhatsApp negotiation, and National Consumer Helpline (NCH 1915).
class EscalationPackService {
  const EscalationPackService._();

  static const String verificationPendingWatermark =
      'Reported claim — verification pending';

  /// Returns true only when a logged, non-rejected, non-withdrawn retail overcharge
  /// complaint exists. Premature export before logging a complaint, on dine-in
  /// restaurant venues (SC FHRAI 2017), or on non-overcharged items is blocked.
  static bool canExportLegalNotice({
    required num mrp,
    required num chargedPrice,
    String venueType = 'RETAIL',
    String? complaintStatus,
    bool hasLoggedComplaint = false,
  }) {
    if (!hasLoggedComplaint) return false;
    if (venueType.trim().toUpperCase() == 'RESTAURANT') return false;
    if (chargedPrice <= mrp) return false;
    final normalizedStatus = complaintStatus?.trim().toUpperCase();
    if (normalizedStatus == 'REJECTED' || normalizedStatus == 'WITHDRAWN') {
      return false;
    }
    return true;
  }

  /// Official Grievance Docket export is additionally locked for UNVERIFIED claims
  /// (e.g., cash with no packet MRP / proof), which remain private advisory records.
  static bool canExportOfficialDocket({
    required num mrp,
    required num chargedPrice,
    String venueType = 'RETAIL',
    String? complaintStatus,
    String? confidenceLevel,
    bool hasLoggedComplaint = false,
  }) {
    if (!canExportLegalNotice(
      mrp: mrp,
      chargedPrice: chargedPrice,
      venueType: venueType,
      complaintStatus: complaintStatus,
      hasLoggedComplaint: hasLoggedComplaint,
    )) {
      return false;
    }
    final normalizedConfidence = confidenceLevel?.trim().toUpperCase();
    if (normalizedConfidence == null || normalizedConfidence == 'UNVERIFIED') {
      return false;
    }
    return true;
  }

  static bool _needsVerificationWatermark({
    String? confidenceLevel,
    String? complaintStatus,
  }) {
    final conf = confidenceLevel?.trim().toUpperCase();
    final status = complaintStatus?.trim().toUpperCase();
    if (conf == null || conf == 'UNVERIFIED' || conf == 'BASIC') {
      return true;
    }
    if (status == 'PENDING') {
      return true;
    }
    return false;
  }

  /// Generates a professional, polite, yet firm legal notice ready to send
  /// to a storekeeper or merchant via WhatsApp or Email.
  ///
  /// Cites Rule 18(2) of the Legal Metrology (Packaged Commodities) Rules, 2011
  /// and Section 36(1) of the Legal Metrology Act, 2009.
  static String generateWhatsAppNotice({
    required String productName,
    required String barcode,
    required num mrp,
    required num chargedPrice,
    int quantity = 1,
    num? totalPaid,
    String? paymentMethod,
    String? utrNumber,
    String? merchantName,
    String? merchantVpa,
    String? storeAddress,
    String? confidenceLevel,
    String? complaintStatus,
    String venueType = 'RETAIL',
    DateTime? date,
    PackagingComplianceResult? complianceResult,
  }) {
    final diff = chargedPrice - mrp;
    final totalDiff = diff * quantity;
    final isOvercharged = diff > 0;
    final now = date ?? DateTime.now();
    final dateStr =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
    final targetMerchant = (merchantName != null && merchantName.trim().isNotEmpty)
        ? merchantName.trim()
        : 'Store In-Charge / Merchant';
    final needsWatermark = _needsVerificationWatermark(
      confidenceLevel: confidenceLevel,
      complaintStatus: complaintStatus,
    );

    final buffer = StringBuffer();
    buffer.writeln('*CONSUMER PRICE QUERY / PACKAGING REMINDER*');
    if (needsWatermark) {
      buffer.writeln('*Status:* $verificationPendingWatermark');
    }
    buffer.writeln('*To:* $targetMerchant');
    if (merchantVpa != null && merchantVpa.trim().isNotEmpty) {
      buffer.writeln('*Merchant UPI VPA:* ${merchantVpa.trim()}');
    }
    if (storeAddress != null && storeAddress.trim().isNotEmpty) {
      buffer.writeln('*Location:* ${storeAddress.trim()}');
    }
    buffer.writeln('*Date:* $dateStr');
    buffer.writeln();
    buffer.writeln('*Subject:* Pricing / packaging compliance query regarding *$productName*');
    buffer.writeln();
    buffer.writeln('Dear Sir/Madam,');
    buffer.writeln();
    buffer.writeln('Based on my check of the item purchased / quoted at your store:');
    buffer.writeln('• *Product:* $productName');
    buffer.writeln('• *Barcode:* $barcode');
    if (quantity > 1) {
      buffer.writeln('• *Quantity:* $quantity');
    }
    buffer.writeln('• *Printed MRP (per unit):* ₹${mrp.toStringAsFixed(2)}');
    buffer.writeln('• *Price Charged (per unit):* ₹${chargedPrice.toStringAsFixed(2)}');
    if (totalPaid != null) {
      buffer.writeln('• *Total Paid:* ₹${totalPaid.toStringAsFixed(2)}');
    }
    if (paymentMethod != null && paymentMethod.trim().isNotEmpty) {
      final refPart = (utrNumber != null && utrNumber.trim().isNotEmpty)
          ? ' (UTR/Ref: ${utrNumber.trim()})'
          : '';
      buffer.writeln('• *Payment Mode:* ${paymentMethod.trim()}$refPart');
    }
    if (isOvercharged) {
      buffer.writeln('• *Reported Difference Above MRP:* ₹${diff.toStringAsFixed(2)} per unit'
          '${quantity > 1 ? ' (Total: ₹${totalDiff.toStringAsFixed(2)})' : ''}');
    }
    if (confidenceLevel != null && confidenceLevel.trim().isNotEmpty) {
      buffer.writeln('• *Evidence Tier:* ${confidenceLevel.trim().toUpperCase()}');
    }

    if (complianceResult != null && complianceResult.hasViolation) {
      buffer.writeln();
      buffer.writeln('⚠️ *Packaging Issue Detected:* ${complianceResult.title}');
      buffer.writeln('_${complianceResult.description}_');
    }

    buffer.writeln();
    buffer.writeln('*Legal Metrology Provisions (For Reference):*');
    buffer.writeln(
      'Under *Rule 18(2) of the Legal Metrology (Packaged Commodities) Rules, 2011*, retail dealers should not sell a pre-packaged commodity at a price higher than the Maximum Retail Price (MRP) printed on the package. Section 36(1) of the Legal Metrology Act, 2009 addresses penalties for overcharging subject to verification by the appropriate authority.',
    );

    if (complianceResult != null && complianceResult.hasViolation) {
      buffer.writeln();
      buffer.writeln('*Rule Citation:* ${complianceResult.legalAdvice}');
    }

    buffer.writeln();
    if (isOvercharged) {
      buffer.writeln(
        'I kindly request an amicable resolution and a refund of the excess amount of *₹${totalDiff.toStringAsFixed(2)}*, along with an update to your billing records to reflect the statutory MRP.',
      );
    } else {
      buffer.writeln(
        'I kindly request that you review the packaging compliance of this item to align with statutory retail regulations.',
      );
    }

    buffer.writeln();
    buffer.writeln(
      'I value local merchants and prefer to resolve this directly. Should there be no resolution, this matter may be submitted to the *National Consumer Helpline (NCH: 1915)* or the District Consumer Disputes Redressal Commission.',
    );
    buffer.writeln();
    buffer.writeln('Thank you for your prompt attention.');
    buffer.writeln('— Generated via PriceShield Consumer Protection Network');

    return buffer.toString().trim();
  }

  /// Generates a structured formal complaint docket ready to file directly
  /// with the National Consumer Helpline (NCH 1915 / consumerhelpline.gov.in)
  /// or District Consumer Disputes Redressal Commission (DCDRC / E-Daakhil).
  static String generateOfficialDocket({
    required String productName,
    required String barcode,
    required num mrp,
    required num chargedPrice,
    int quantity = 1,
    num? totalPaid,
    String? paymentMethod,
    String? utrNumber,
    String? docketId,
    String? merchantName,
    String? merchantVpa,
    String? storeAddress,
    String? confidenceLevel,
    String? complaintStatus,
    String venueType = 'RETAIL',
    DateTime? incidentDate,
    PackagingComplianceResult? complianceResult,
    String? evidenceSummary,
  }) {
    final diff = chargedPrice - mrp;
    final totalDiff = diff * quantity;
    final overchargePercent = mrp > 0 ? ((diff / mrp) * 100).toStringAsFixed(1) : '0';
    final timestamp = incidentDate ?? DateTime.now();
    final dateStr =
        '${timestamp.day.toString().padLeft(2, '0')}/${timestamp.month.toString().padLeft(2, '0')}/${timestamp.year}';
    final ref = docketId ?? 'PS-${timestamp.millisecondsSinceEpoch.toRadixString(16).toUpperCase()}';
    final conf = confidenceLevel?.trim().toUpperCase();
    final needsWatermark = _needsVerificationWatermark(
      confidenceLevel: confidenceLevel,
      complaintStatus: complaintStatus,
    );

    final buffer = StringBuffer();
    buffer.writeln('================================================================================');
    buffer.writeln('FORMAL CONSUMER GRIEVANCE DOCKET (USER-PREPARED FACT SHEET)');
    if (needsWatermark) {
      buffer.writeln('*** WATERMARK: ${verificationPendingWatermark.toUpperCase()} ***');
    }
    if (conf == 'UNVERIFIED') {
      buffer.writeln('*** PRIVATE ADVISORY RECORD ONLY — UNVERIFIED CLAIM (ATTACH PACKET/BILL PROOF) ***');
    }
    buffer.writeln('National Consumer Helpline (NCH - 1915) | INGRAM Portal | E-Daakhil DCDRC');
    buffer.writeln('Prepared via PriceShield Consumer Assistance Tool');
    buffer.writeln('================================================================================');
    buffer.writeln('Docket Reference : $ref');
    buffer.writeln('Date of Incident : $dateStr');
    buffer.writeln('Venue Context    : ${venueType.trim().toUpperCase()}');
    if (conf != null && conf.isNotEmpty) {
      buffer.writeln('Confidence Tier  : $conf');
    }
    if (complaintStatus != null && complaintStatus.trim().isNotEmpty) {
      buffer.writeln('Case Status      : ${complaintStatus.trim().toUpperCase()}');
    }
    if (needsWatermark) {
      buffer.writeln('Verification Note: $verificationPendingWatermark');
    }
    buffer.writeln('Relevant Acts    : Legal Metrology Act, 2009 & Consumer Protection Act, 2019');
    buffer.writeln();
    buffer.writeln('1. COMPLAINANT STATEMENT:');
    buffer.writeln('   Based on the information entered, the consumer reports possible pricing above');
    buffer.writeln('   printed MRP and/or a packaging concern that may require official verification.');
    buffer.writeln();
    buffer.writeln('2. RESPONDENT (RETAILER / MERCHANT) DETAILS:');
    buffer.writeln('   Store / Business Name : ${merchantName?.trim().isNotEmpty == true ? merchantName!.trim() : 'Unspecified Retail Store'}');
    if (merchantVpa != null && merchantVpa.trim().isNotEmpty) {
      buffer.writeln('   Merchant UPI VPA      : ${merchantVpa.trim()}');
    }
    buffer.writeln('   Premises Address      : ${storeAddress?.trim().isNotEmpty == true ? storeAddress!.trim() : 'Recorded in device incident notes'}');
    buffer.writeln();
    buffer.writeln('3. COMMODITY & TRANSACTION PARTICULARS:');
    buffer.writeln('   Item Description      : $productName');
    buffer.writeln('   GTIN / Barcode        : $barcode');
    buffer.writeln('   Quantity              : $quantity');
    buffer.writeln('   Printed MRP (Unit)    : ₹${mrp.toStringAsFixed(2)}');
    buffer.writeln('   Price Charged (Unit)  : ₹${chargedPrice.toStringAsFixed(2)}');
    if (totalPaid != null) {
      buffer.writeln('   Total Basket Paid     : ₹${totalPaid.toStringAsFixed(2)}');
    }
    if (paymentMethod != null && paymentMethod.trim().isNotEmpty) {
      buffer.writeln('   Payment Method        : ${paymentMethod.trim().toUpperCase()}');
    }
    if (utrNumber != null && utrNumber.trim().isNotEmpty) {
      buffer.writeln('   Transaction / UTR Ref : ${utrNumber.trim().toUpperCase()}');
    }
    buffer.writeln('   Reported Difference   : ₹${diff.toStringAsFixed(2)}/unit ($overchargePercent% above printed MRP)'
        '${quantity > 1 ? ' | Total: ₹${totalDiff.toStringAsFixed(2)}' : ''}');
    if (complianceResult != null && complianceResult.hasViolation) {
      buffer.writeln('   Packaging Flag        : ${complianceResult.title}');
      buffer.writeln('   Flag Detail           : ${complianceResult.description}');
      if (complianceResult.matchedSnippet != null) {
        buffer.writeln('   Extracted OCR Marker  : "${complianceResult.matchedSnippet}"');
      }
    }
    buffer.writeln();
    buffer.writeln('4. RELEVANT REGULATORY REFERENCES (FOR VERIFICATION):');
    buffer.writeln('   • Rule 18(2), Legal Metrology (Packaged Commodities) Rules, 2011:');
    buffer.writeln('     "No retail dealer or other person including manufacturer, packer, importer');
    buffer.writeln('     shall sell any pre-packaged commodity at a price exceeding the retail sale price."');
    buffer.writeln('   • Section 36(1), Legal Metrology Act, 2009:');
    buffer.writeln('     Provides statutory penalties for selling packaged commodities above printed MRP.');
    buffer.writeln('   • Section 2(47), Consumer Protection Act, 2019:');
    buffer.writeln('     Covers unfair trade practices that may be reviewed by consumer commissions.');
    if (complianceResult != null && complianceResult.hasViolation) {
      buffer.writeln('   • Additional Compliance Reference:');
      buffer.writeln('     ${complianceResult.legalAdvice}');
    }
    buffer.writeln();
    buffer.writeln('5. DEVICE EVIDENCE NOTES:');
    buffer.writeln('   • Barcode and on-device readings logged with transaction metadata.');
    if (evidenceSummary != null && evidenceSummary.trim().isNotEmpty) {
      buffer.writeln('   • Attached Evidence: ${evidenceSummary.trim()}');
    } else {
      buffer.writeln('   • Photographic package & bill evidence recommended for official submission.');
    }
    buffer.writeln();
    buffer.writeln('6. REQUESTED RESOLUTION:');
    buffer.writeln('   a) Refund verification of reported difference (₹${totalDiff.toStringAsFixed(2)}).');
    buffer.writeln('   b) Inspection and verification by the appropriate Legal Metrology authority if warranted.');
    buffer.writeln('   c) Appropriate action under applicable consumer protection rules.');
    buffer.writeln();
    buffer.writeln('Disclaimer: User-entered figures and catalog entries are advisory inputs pending');
    buffer.writeln('official verification. Submit packet/bill photos via consumerhelpline.gov.in or 1915.');
    buffer.writeln('================================================================================');

    return buffer.toString().trim();
  }
}
