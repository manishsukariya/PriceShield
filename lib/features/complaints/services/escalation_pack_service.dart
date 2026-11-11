import 'package:priceshield/features/scanner/services/packaging_compliance_service.dart';

/// Service generating responsible consumer notices and formal dockets for
/// merchant resolution, WhatsApp negotiation, and National Consumer Helpline (NCH 1915).
class EscalationPackService {
  const EscalationPackService._();

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
    String? merchantName,
    String? storeAddress,
    DateTime? date,
    PackagingComplianceResult? complianceResult,
  }) {
    final diff = chargedPrice - mrp;
    final isOvercharged = diff > 0;
    final now = date ?? DateTime.now();
    final dateStr = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
    final targetMerchant = (merchantName != null && merchantName.trim().isNotEmpty)
        ? merchantName.trim()
        : 'Store In-Charge / Merchant';

    final buffer = StringBuffer();
    buffer.writeln('*CONSUMER PRICE QUERY / PACKAGING REMINDER*');
    buffer.writeln('*To:* $targetMerchant');
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
    buffer.writeln('• *Printed MRP:* ₹${mrp.toStringAsFixed(2)}');
    buffer.writeln('• *Price Charged:* ₹${chargedPrice.toStringAsFixed(2)}');
    if (isOvercharged) {
      buffer.writeln('• *Reported Difference Above MRP:* ₹${diff.toStringAsFixed(2)}');
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
        'I kindly request an amicable resolution and a refund of the excess amount of *₹${diff.toStringAsFixed(2)}*, along with an update to your billing records to reflect the statutory MRP.',
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
    String? docketId,
    String? merchantName,
    String? storeAddress,
    DateTime? incidentDate,
    PackagingComplianceResult? complianceResult,
    String? evidenceSummary,
  }) {
    final diff = chargedPrice - mrp;
    final overchargePercent = mrp > 0 ? ((diff / mrp) * 100).toStringAsFixed(1) : '0';
    final timestamp = incidentDate ?? DateTime.now();
    final dateStr =
        '${timestamp.day.toString().padLeft(2, '0')}/${timestamp.month.toString().padLeft(2, '0')}/${timestamp.year}';
    final ref = docketId ?? 'PS-${timestamp.millisecondsSinceEpoch.toRadixString(16).toUpperCase()}';

    final buffer = StringBuffer();
    buffer.writeln('================================================================================');
    buffer.writeln('FORMAL CONSUMER GRIEVANCE DOCKET (USER-PREPARED FACT SHEET)');
    buffer.writeln('National Consumer Helpline (NCH - 1915) | INGRAM Portal | E-Daakhil DCDRC');
    buffer.writeln('Prepared via PriceShield Consumer Assistance Tool');
    buffer.writeln('================================================================================');
    buffer.writeln('Docket Reference : $ref');
    buffer.writeln('Date of Incident : $dateStr');
    buffer.writeln('Relevant Acts    : Legal Metrology Act, 2009 & Consumer Protection Act, 2019');
    buffer.writeln();
    buffer.writeln('1. COMPLAINANT STATEMENT:');
    buffer.writeln('   Based on the information entered, the consumer reports possible pricing above');
    buffer.writeln('   printed MRP and/or a packaging concern that may require official verification.');
    buffer.writeln();
    buffer.writeln('2. RESPONDENT (RETAILER / MERCHANT) DETAILS:');
    buffer.writeln('   Store / Business Name : ${merchantName?.trim().isNotEmpty == true ? merchantName!.trim() : 'Unspecified Retail Store'}');
    buffer.writeln('   Premises Address      : ${storeAddress?.trim().isNotEmpty == true ? storeAddress!.trim() : 'Recorded in device incident notes'}');
    buffer.writeln();
    buffer.writeln('3. COMMODITY & TRANSACTION PARTICULARS:');
    buffer.writeln('   Item Description      : $productName');
    buffer.writeln('   GTIN / Barcode        : $barcode');
    buffer.writeln('   Printed MRP (Entered) : ₹${mrp.toStringAsFixed(2)}');
    buffer.writeln('   Price Demanded/Charged: ₹${chargedPrice.toStringAsFixed(2)}');
    buffer.writeln('   Reported Difference   : ₹${diff.toStringAsFixed(2)} ($overchargePercent% above printed MRP)');
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
    buffer.writeln('   • Barcode and on-device OCR readings logged with device timestamp (user-verified).');
    if (evidenceSummary != null && evidenceSummary.trim().isNotEmpty) {
      buffer.writeln('   • Additional Evidence: ${evidenceSummary.trim()}');
    } else {
      buffer.writeln('   • Photographic package & bill evidence recommended for official submission.');
    }
    buffer.writeln();
    buffer.writeln('6. REQUESTED RESOLUTION:');
    buffer.writeln('   a) Refund verification of reported difference (₹${diff.toStringAsFixed(2)}).');
    buffer.writeln('   b) Inspection and verification by the appropriate Legal Metrology authority if warranted.');
    buffer.writeln('   c) Appropriate action under applicable consumer protection rules.');
    buffer.writeln();
    buffer.writeln('Disclaimer: OCR and catalog entries are user-verified advisory inputs and not legal');
    buffer.writeln('proof. Submit packet/bill photos directly via consumerhelpline.gov.in or 1915.');
    buffer.writeln('================================================================================');

    return buffer.toString().trim();
  }
}
