import 'package:flutter/foundation.dart';

/// Geographical and logistical terrain categories.
enum TerrainType {
  /// Standard road-connected plains / city retail (strict printed MRP).
  plains,

  /// Road-connected hill stations (Shimla, Manali, Nainital, Mussoorie)
  /// where commercial supply trucks deliver directly to the market.
  motorableHill,

  /// High altitude or remote trek routes without motorable road access
  /// (Kedarnath, Amarnath, Rohtang top, Valley of Flowers, Spiti passes)
  /// where goods are transported on mules or human porters.
  remoteTrek,
}

/// Product physical preparation state.
enum ItemFormType {
  /// Sealed, packaged, factory-manufactured unit (e.g., unopened water bottle, biscuit pack, sealed Maggi packet).
  sealedPack,

  /// Cooked, prepared, or table-served food (e.g., hot cooked Maggi, boiled tea, prepared paratha).
  cookedDhaba,
}

/// Legal and practical evaluation verdict based on geography and item form.
enum TerrainVerdictType {
  withinMrp,
  cookedExempt,
  illegalPlainsOvercharge,
  illegalHillSurcharge,
  fairPorterageAllowance,
  extortionPriceGouging,
}

@immutable
class TerrainEvaluation {
  const TerrainEvaluation({
    required this.verdictType,
    required this.title,
    required this.subtitle,
    required this.explanation,
    required this.legalAdvice,
    required this.isViolation,
    this.isFairAllowance = false,
    this.isExempt = false,
    required this.difference,
  });

  final TerrainVerdictType verdictType;
  final String title;
  final String subtitle;
  final String explanation;
  final String legalAdvice;
  final bool isViolation;
  final bool isFairAllowance;
  final bool isExempt;
  final num difference;

  static TerrainEvaluation evaluate({
    required num mrp,
    required num charged,
    required TerrainType terrain,
    required ItemFormType itemForm,
  }) {
    final diff = charged - mrp;

    // 1. Cooked Food / Dhaba Service Exemption
    if (itemForm == ItemFormType.cookedDhaba) {
      return TerrainEvaluation(
        verdictType: TerrainVerdictType.cookedExempt,
        title: 'Cooked Food Service (MRP Exempt)',
        subtitle: 'Supreme Court FHRAI 2017: Prepared food is exempt from packaged MRP',
        explanation:
            'Food cooked and served at high altitude dhabas (hot Maggi, tea, meals) requires carried gas cylinders, mountain water, and preparation service. Under Supreme Court rulings, it is a service transaction and is legally exempt from packaged MRP limits.',
        legalAdvice:
            'Sealed packaged items (unopened water bottles, raw packets) are bound by MRP/DM rates, but cooked meals are priced by the restaurant/dhaba operator based on fuel and service expenses.',
        isViolation: false,
        isExempt: true,
        difference: diff,
      );
    }

    // 2. Charged within printed MRP
    if (diff <= 0) {
      return TerrainEvaluation(
        verdictType: TerrainVerdictType.withinMrp,
        title: 'Price is within printed MRP',
        subtitle: 'Fair transaction complying with Legal Metrology Rules',
        explanation:
            'You are being charged at or below the manufacturer’s printed Maximum Retail Price.',
        legalAdvice:
            'Transaction strictly adheres to Rule 18(2) of the Legal Metrology (Packaged Commodities) Rules, 2011.',
        isViolation: false,
        difference: diff,
      );
    }

    // 3. Plains / Standard City Overcharge
    if (terrain == TerrainType.plains) {
      return TerrainEvaluation(
        verdictType: TerrainVerdictType.illegalPlainsOvercharge,
        title: 'Overcharge detected',
        subtitle: 'Excess demand of ₹${diff.toStringAsFixed(2)} above printed MRP',
        explanation:
            'Charging above the printed MRP on sealed packaged goods is a statutory violation. All refrigeration, taxes, and dealer margins are already included in the MRP.',
        legalAdvice:
            'Under Rule 18(2) of the Legal Metrology (Packaged Commodities) Rules, 2011 and Section 36(1) of the Act, overcharging is punishable with compounding fines up to ₹25,000.',
        isViolation: true,
        difference: diff,
      );
    }

    // 4. Motorable Hill Station (Shimla, Manali, Nainital)
    if (terrain == TerrainType.motorableHill) {
      return TerrainEvaluation(
        verdictType: TerrainVerdictType.illegalHillSurcharge,
        title: 'Illegal Hill Station Surcharge',
        subtitle: 'Motorable road access exists — no transport surcharge permitted',
        explanation:
            'Commercial freight trucks and delivery vans supply goods directly to road-connected hill stations (Shimla, Manali, Nainital). Retailers cannot charge extra by claiming "pahad ka bhada". By law, all freight must be borne within the printed MRP.',
        legalAdvice:
            'Rule 18(2) does not permit geographical markups where road logistics exist. If companies require higher prices in hill states, they must print a separate higher MRP on the physical batch.',
        isViolation: true,
        difference: diff,
      );
    }

    // 5. Remote Mountain Trek (Mule / Porter Logistics)
    // In pedestrian pilgrimage and high treks (Kedarnath, Amarnath, Valley of Flowers),
    // local District Magistrates / Shrine Boards publish approved rate lists
    // allowing standard porterage (typically ₹5 to ₹10 extra or up to 25%).
    final isWithinReasonablePorterage = diff <= 10 || diff <= (mrp * 0.25);

    if (isWithinReasonablePorterage) {
      return TerrainEvaluation(
        verdictType: TerrainVerdictType.fairPorterageAllowance,
        title: 'High Altitude Trek (Fair Porterage Allowance)',
        subtitle: 'Extra ₹${diff.toStringAsFixed(0)} within DM / Shrine Board porterage guidelines',
        explanation:
            'On pedestrian trek routes with no motorable roads (Kedarnath, Amarnath, high mountain passes), goods are carried up steep ascents by mules or porters. An extra ₹${diff.toStringAsFixed(0)} is consistent with District Administration approved porterage rate cards.',
        legalAdvice:
            'Local District Administrations issue official Approved Rate Lists (अनुमोदित दर सूची) for remote treks under Disaster & Pilgrim Welfare guidelines. This modest markup covers documented animal/human transport costs.',
        isViolation: false,
        isFairAllowance: true,
        difference: diff,
      );
    }

    // 6. Extortionate Price Gouging on Remote Trek (e.g. ₹20 bottle sold for ₹60–₹100)
    return TerrainEvaluation(
      verdictType: TerrainVerdictType.extortionPriceGouging,
      title: 'Predatory Mountain Price Gouging Alert',
      subtitle: 'Demanding ₹${charged.toStringAsFixed(0)} (₹${diff.toStringAsFixed(0)} extra) on ₹${mrp.toStringAsFixed(0)} sealed pack',
      explanation:
          'While moderate porterage is legitimate, demanding ₹${diff.toStringAsFixed(0)} extra on a sealed item grossly exceeds official District Administration porterage limits and constitutes black marketing in a remote/pilgrim zone.',
      legalAdvice:
          'Violates Essential Commodities Act and District Magistrate Rate Notifications. If in an isolated location, do not confront stall owners; note the stall/tent number or UPI ID, save silently, and file from base camp.',
      isViolation: true,
      difference: diff,
    );
  }
}
