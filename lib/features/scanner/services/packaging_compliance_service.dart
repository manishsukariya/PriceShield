import 'package:flutter/foundation.dart';

/// Categories of packaging compliance violations detected from OCR text.
enum PackagingViolationType {
  none,
  multipack,
  freebie,
  outerPackMrp,
  promotionalDiscount,
}

/// Structured outcome of a packaging compliance evaluation.
@immutable
class PackagingComplianceResult {
  const PackagingComplianceResult({
    required this.hasViolation,
    this.violationType = PackagingViolationType.none,
    this.title = '',
    this.description = '',
    this.legalAdvice = '',
    this.matchedSnippet,
  });

  /// True if an on-pack compliance violation or mandatory condition was flagged.
  final bool hasViolation;

  /// The category of packaging violation detected.
  final PackagingViolationType violationType;

  /// Human-friendly alert headline.
  final String title;

  /// Consumer-focused explanation of what was found on the package.
  final String description;

  /// Statutory guidance and citations under Indian Legal Metrology Rules.
  final String legalAdvice;

  /// The exact phrase or text segment extracted from the OCR scan.
  final String? matchedSnippet;

  /// Standard compliant baseline result.
  static const PackagingComplianceResult compliant = PackagingComplianceResult(
    hasViolation: false,
    violationType: PackagingViolationType.none,
    title: 'Packaging Compliant',
    description: 'No packaging violations, loose pack splitting, or bundle anomalies detected.',
    legalAdvice: 'Package declarations conform to standard Legal Metrology guidelines.',
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PackagingComplianceResult &&
          runtimeType == other.runtimeType &&
          hasViolation == other.hasViolation &&
          violationType == other.violationType &&
          title == other.title &&
          description == other.description &&
          legalAdvice == other.legalAdvice &&
          matchedSnippet == other.matchedSnippet;

  @override
  int get hashCode => Object.hash(
        hasViolation,
        violationType,
        title,
        description,
        legalAdvice,
        matchedSnippet,
      );

  @override
  String toString() =>
      'PackagingComplianceResult(hasViolation: $hasViolation, type: $violationType, title: "$title")';
}

/// Service to analyze package OCR text for Legal Metrology violations:
/// - Multipack bundle splitting ('not for individual sale', etc.)
/// - Freebie / sample resale ('free sample', 'not for sale', etc.)
/// - Missing unit MRP ('see outer pack for mrp', etc.)
/// - On-pack promotional discounts ('₹10 off', '20% extra', etc.)
class PackagingComplianceService {
  const PackagingComplianceService._();

  static final List<String> _freebiePhrases = [
    'free sample',
    'not for sale',
    'complimentary pack',
    'complimentary sample',
    'free promotional pack',
    'sample not for sale',
  ];

  static final List<String> _multipackPhrases = [
    'not for individual sale',
    'not for loose sale',
    'part of multipack',
    'part of a multipack',
    'for promotional pack only',
    'promotional pack only',
    'part of multi pack',
    'not for retail sale',
    'sold as a set only',
  ];

  static final List<String> _outerPackMrpPhrases = [
    'see outer pack for mrp',
    'mrp on outer carton',
    'mrp on outer pack',
    'see outer carton for mrp',
    'refer outer pack for mrp',
    'see carton for mrp',
    'for mrp see outer pack',
    'for mrp see outer carton',
  ];

  // Chilled / curved package OCR fuzzy regexes to survive water droplets & label folds:
  // e.g. "not for ind1v1dual sa1e", "free samp1e", "part of multi-pack"
  static final List<RegExp> _fuzzyFreebiePatterns = [
    RegExp(r'free\s*(?:samp[l1i]e|promo(?:tional)?(?:\s*pack)?)', caseSensitive: false),
    RegExp(r'not\s*for\s*sa[l1i]e', caseSensitive: false),
    RegExp(r'complimentary\s*(?:pack|samp[l1i]e)', caseSensitive: false),
    RegExp(r'samp[l1i]e\s*not\s*for\s*sa[l1i]e', caseSensitive: false),
  ];

  static final List<RegExp> _fuzzyMultipackPatterns = [
    RegExp(r'not\s*for\s*(?:indiv[i1l]dual|ind[i1l]v[i1l]dual|loose|retail)\s*sa[l1i]e', caseSensitive: false),
    RegExp(r'part\s*of\s*(?:a\s*)?multi[\s\-]*pack', caseSensitive: false),
    RegExp(r'(?:for\s*)?promo(?:tional)?\s*pack\s*only', caseSensitive: false),
    RegExp(r'sold\s*as\s*(?:a\s*)?set\s*only', caseSensitive: false),
  ];

  static final List<RegExp> _fuzzyOuterPackPatterns = [
    RegExp(r'see\s*outer\s*(?:pack|carton)\s*for\s*(?:mrp|price)', caseSensitive: false),
    RegExp(r'(?:mrp|price)\s*on\s*outer\s*(?:pack|carton)', caseSensitive: false),
    RegExp(r'refer\s*outer\s*(?:pack|carton)', caseSensitive: false),
    RegExp(r'for\s*(?:mrp|price)\s*see\s*outer\s*(?:pack|carton)', caseSensitive: false),
  ];

  static final RegExp _promotionalDiscountRegex = RegExp(
    r'(?:₹|rs\.?)\s*\d+\s*off|\d+%\s*extra|\d+%\s*off',
    caseSensitive: false,
  );

  /// Analyzes raw or normalized OCR text extracted from package imagery.
  static PackagingComplianceResult analyze(String? ocrText) {
    if (ocrText == null || ocrText.trim().isEmpty) {
      return PackagingComplianceResult.compliant;
    }

    final normalized = ocrText.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

    // 1. Check for Freebie / Sample Resale Violations (Exact & Fuzzy OCR)
    for (final phrase in _freebiePhrases) {
      if (normalized.contains(phrase)) {
        final snippet = _findExactSnippet(ocrText, phrase) ?? phrase;
        return PackagingComplianceResult(
          hasViolation: true,
          violationType: PackagingViolationType.freebie,
          title: 'Free Sample / Promotional Item Resale Alert',
          description:
              'This unit is marked as a free sample or complimentary pack ("$snippet"). Charging for it is strictly prohibited.',
          legalAdvice:
              'Under Rule 18 of the Legal Metrology (Packaged Commodities) Rules, 2011 and Section 2(47) of the Consumer Protection Act, 2019, commercial resale of items marked "Not for Sale" or "Free Sample" is a punishable offence.',
          matchedSnippet: snippet,
        );
      }
    }
    for (final pattern in _fuzzyFreebiePatterns) {
      final match = pattern.firstMatch(ocrText);
      if (match != null) {
        final snippet = match.group(0)!;
        return PackagingComplianceResult(
          hasViolation: true,
          violationType: PackagingViolationType.freebie,
          title: 'Free Sample / Promotional Item Resale Alert',
          description:
              'This unit is marked as a free sample or complimentary pack ("$snippet"). Charging for it is strictly prohibited.',
          legalAdvice:
              'Under Rule 18 of the Legal Metrology (Packaged Commodities) Rules, 2011 and Section 2(47) of the Consumer Protection Act, 2019, commercial resale of items marked "Not for Sale" or "Free Sample" is a punishable offence.',
          matchedSnippet: snippet,
        );
      }
    }

    // 2. Check for Multipack Splitting Violations (Exact & Fuzzy OCR)
    for (final phrase in _multipackPhrases) {
      if (normalized.contains(phrase)) {
        final snippet = _findExactSnippet(ocrText, phrase) ?? phrase;
        return PackagingComplianceResult(
          hasViolation: true,
          violationType: PackagingViolationType.multipack,
          title: 'Multipack Splitting Violation Detected',
          description:
              'This item is marked as part of a multipack ("$snippet") and cannot be unbundled or sold loose as an individual unit.',
          legalAdvice:
              'Under Rule 24 and Rule 18(2) of the Legal Metrology (Packaged Commodities) Rules, 2011, breaking multipacks and retailing individual units without standalone statutory declarations and an independent MRP is illegal.',
          matchedSnippet: snippet,
        );
      }
    }
    for (final pattern in _fuzzyMultipackPatterns) {
      final match = pattern.firstMatch(ocrText);
      if (match != null) {
        final snippet = match.group(0)!;
        return PackagingComplianceResult(
          hasViolation: true,
          violationType: PackagingViolationType.multipack,
          title: 'Multipack Splitting Violation Detected',
          description:
              'This item is marked as part of a multipack ("$snippet") and cannot be unbundled or sold loose as an individual unit.',
          legalAdvice:
              'Under Rule 24 and Rule 18(2) of the Legal Metrology (Packaged Commodities) Rules, 2011, breaking multipacks and retailing individual units without standalone statutory declarations and an independent MRP is illegal.',
          matchedSnippet: snippet,
        );
      }
    }

    // 3. Check for Missing Unit MRP / Outer Pack Required (Exact & Fuzzy OCR)
    for (final phrase in _outerPackMrpPhrases) {
      if (normalized.contains(phrase)) {
        final snippet = _findExactSnippet(ocrText, phrase) ?? phrase;
        return PackagingComplianceResult(
          hasViolation: true,
          violationType: PackagingViolationType.outerPackMrp,
          title: 'Missing Unit MRP (Outer Pack Required)',
          description:
              'The inner package states "$snippet". Retailer must verify and declare the official outer carton price before charging.',
          legalAdvice:
              'Rule 6 of the Legal Metrology (Packaged Commodities) Rules, 2011 mandates clear MRP declaration on consumer packages. Retailers cannot arbitrarily set an unverified price for inner packaging.',
          matchedSnippet: snippet,
        );
      }
    }
    for (final pattern in _fuzzyOuterPackPatterns) {
      final match = pattern.firstMatch(ocrText);
      if (match != null) {
        final snippet = match.group(0)!;
        return PackagingComplianceResult(
          hasViolation: true,
          violationType: PackagingViolationType.outerPackMrp,
          title: 'Missing Unit MRP (Outer Pack Required)',
          description:
              'The inner package states "$snippet". Retailer must verify and declare the official outer carton price before charging.',
          legalAdvice:
              'Rule 6 of the Legal Metrology (Packaged Commodities) Rules, 2011 mandates clear MRP declaration on consumer packages. Retailers cannot arbitrarily set an unverified price for inner packaging.',
          matchedSnippet: snippet,
        );
      }
    }

    // 4. Check for Promotional Discount / Extra Volume regex
    final promoMatch = _promotionalDiscountRegex.firstMatch(ocrText);
    if (promoMatch != null) {
      final snippet = promoMatch.group(0)!;
      return PackagingComplianceResult(
        hasViolation: true,
        violationType: PackagingViolationType.promotionalDiscount,
        title: 'Promotional Pack Discount Discrepancy',
        description:
            'Package features an on-pack promotional offer ("$snippet") that must be honored at billing.',
        legalAdvice:
            'When an on-pack discount or promotional rebate is printed by the manufacturer, charging the original full price constitutes an unlawful overcharge under Rule 18(2) of Legal Metrology Rules, 2011.',
        matchedSnippet: snippet,
      );
    }

    return PackagingComplianceResult.compliant;
  }

  /// Extracts the original casing snippet from the unnormalized OCR text.
  static String? _findExactSnippet(String originalText, String phrase) {
    try {
      final escaped = RegExp.escape(phrase).replaceAll(r'\ ', r'\s+');
      final match = RegExp(escaped, caseSensitive: false).firstMatch(originalText);
      return match?.group(0);
    } catch (_) {
      return phrase;
    }
  }
}
