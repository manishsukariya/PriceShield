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
    buffer.writeln('*INFORMAL DISPUTE NOTICE / STATUTORY REMINDER*');
    buffer.writeln('*To:* $targetMerchant');
    if (storeAddress != null && storeAddress.trim().isNotEmpty) {
      buffer.writeln('*Location:* ${storeAddress.trim()}');
    }
    buffer.writeln('*Date:* $dateStr');
    buffer.writeln();
    buffer.writeln('*Subject:* Pricing / statutory compliance query regarding *$productName*');
    buffer.writeln();
    buffer.writeln('Dear Sir/Madam,');
    buffer.writeln();
    buffer.writeln('I recently purchased / was quoted for the following item at your store:');
    buffer.writeln('• *Product:* $productName');
    buffer.writeln('• *Barcode:* $barcode');
    buffer.writeln('• *Printed MRP:* ₹${mrp.toStringAsFixed(2)}');
    buffer.writeln('• *Price Charged:* ₹${chargedPrice.toStringAsFixed(2)}');
    if (isOvercharged) {
      buffer.writeln('• *Excess Surcharge:* ₹${diff.toStringAsFixed(2)}');
    }

    if (complianceResult != null && complianceResult.hasViolation) {
      buffer.writeln();
      buffer.writeln('⚠️ *Packaging Issue Detected:* ${complianceResult.title}');
      buffer.writeln('_${complianceResult.description}_');
    }

    buffer.writeln();
    buffer.writeln('*Legal Metrology Provisions:*');
    buffer.writeln(
      'Under *Rule 18(2) of the Legal Metrology (Packaged Commodities) Rules, 2011*, no retail dealer or other person shall sell any pre-packaged commodity at a price higher than the Maximum Retail Price (MRP) printed on the package. Furthermore, Section 36(1) of the Legal Metrology Act, 2009 classifies selling above MRP as a statutory offence.',
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
    buffer.writeln('FORMAL CONSUMER GRIEVANCE DOCKET & STATUTORY FACT SHEET');
    buffer.writeln('National Consumer Helpline (NCH - 1915) | INGRAM Portal | E-Daakhil DCDRC');
    buffer.writeln('Generated via PriceShield Consumer Protection Network');
    buffer.writeln('================================================================================');
    buffer.writeln('Docket Reference : $ref');
    buffer.writeln('Date of Incident : $dateStr');
    buffer.writeln('Applicable Acts  : Legal Metrology Act, 2009 & Consumer Protection Act, 2019');
    buffer.writeln();
    buffer.writeln('1. COMPLAINANT STATEMENT:');
    buffer.writeln('   Consumer aggrieved by retail overcharging above statutory printed MRP and/or');
    buffer.writeln('   statutory packaging non-compliance in violation of national consumer regulations.');
    buffer.writeln();
    buffer.writeln('2. RESPONDENT (RETAILER / MERCHANT) DETAILS:');
    buffer.writeln('   Store / Business Name : ${merchantName?.trim().isNotEmpty == true ? merchantName!.trim() : 'Unspecified Retail Store'}');
    buffer.writeln('   Premises Address      : ${storeAddress?.trim().isNotEmpty == true ? storeAddress!.trim() : 'Recorded in digital incident metadata'}');
    buffer.writeln();
    buffer.writeln('3. COMMODITY & TRANSACTION PARTICULARS:');
    buffer.writeln('   Item Description      : $productName');
    buffer.writeln('   GTIN / Barcode        : $barcode');
    buffer.writeln('   Printed Statutory MRP : ₹${mrp.toStringAsFixed(2)}');
    buffer.writeln('   Price Demanded/Charged: ₹${chargedPrice.toStringAsFixed(2)}');
    buffer.writeln('   Illegal Surcharge     : ₹${diff.toStringAsFixed(2)} ($overchargePercent% overcharge)');
    if (complianceResult != null && complianceResult.hasViolation) {
      buffer.writeln('   Packaging Violation   : ${complianceResult.title}');
      buffer.writeln('   Violation Detail      : ${complianceResult.description}');
      if (complianceResult.matchedSnippet != null) {
        buffer.writeln('   Extracted OCR Marker  : "${complianceResult.matchedSnippet}"');
      }
    }
    buffer.writeln();
    buffer.writeln('4. STATUTORY VIOLATIONS & LEGAL CITATIONS:');
    buffer.writeln('   • Rule 18(2), Legal Metrology (Packaged Commodities) Rules, 2011:');
    buffer.writeln('     "No retail dealer or other person including manufacturer, packer, importer');
    buffer.writeln('     shall sell any pre-packaged commodity at a price exceeding the retail sale price."');
    buffer.writeln('   • Section 36(1), Legal Metrology Act, 2009:');
    buffer.writeln('     Prescribes penal liability for selling non-standard or overpriced pre-packaged packages.');
    buffer.writeln('   • Section 2(47), Consumer Protection Act, 2019:');
    buffer.writeln('     Classifies charging prices exceeding printed MRP as an Unfair Trade Practice.');
    if (complianceResult != null && complianceResult.hasViolation) {
      buffer.writeln('   • Additional Compliance Citation:');
      buffer.writeln('     ${complianceResult.legalAdvice}');
    }
    buffer.writeln();
    buffer.writeln('5. DIGITAL EVIDENCE LOGGED:');
    buffer.writeln('   • Barcode and on-device OCR scan verified and logged with cryptographic timestamp.');
    if (evidenceSummary != null && evidenceSummary.trim().isNotEmpty) {
      buffer.writeln('   • Additional Evidence: ${evidenceSummary.trim()}');
    } else {
      buffer.writeln('   • Photographic package evidence preserved for regulatory submission.');
    }
    buffer.writeln();
    buffer.writeln('6. RELIEF & REMEDIES SOUGHT:');
    buffer.writeln('   a) Full refund of unlawful overcharge (₹${diff.toStringAsFixed(2)}).');
    buffer.writeln('   b) Official inspection of respondent merchant POS inventory by Legal Metrology Inspector.');
    buffer.writeln('   c) Imposition of statutory compounding fees/penalties under Section 36 of the Act.');
    buffer.writeln('================================================================================');

    return buffer.toString().trim();
  }
}
