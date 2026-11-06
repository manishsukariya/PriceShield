/// Represents dispute and product information used by the
/// De-escalation Co-Pilot & Legal Rights Showcard.
class DeescalationData {
  const DeescalationData({
    this.productName,
    this.barcode,
    this.mrp,
    this.chargedPrice,
    this.shopName,
    this.location,
    this.notes,
  });

  final String? productName;
  final String? barcode;
  final num? mrp;
  final num? chargedPrice;
  final String? shopName;
  final String? location;
  final String? notes;

  /// Default mock dispute if user opens Co-Pilot without scanning a product first.
  static const DeescalationData generic = DeescalationData(
    productName: 'Chilled Packaged Item (Cold Drink / Milk / Ice Cream)',
    mrp: 40,
    chargedPrice: 50,
  );

  bool get hasOvercharge =>
      mrp != null && chargedPrice != null && chargedPrice! > mrp!;

  num get overchargeAmount {
    if (mrp != null && chargedPrice != null && chargedPrice! > mrp!) {
      return chargedPrice! - mrp!;
    }
    return 0;
  }

  static String formatCurrency(num value) {
    if (value % 1 == 0) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(2);
  }

  String get formattedMrp => mrp != null ? formatCurrency(mrp!) : '';

  String get formattedChargedPrice =>
      chargedPrice != null ? formatCurrency(chargedPrice!) : '';

  String get formattedOvercharge => formatCurrency(overchargeAmount);

  String get displayName =>
      (productName == null || productName!.trim().isEmpty)
          ? 'Packaged Commodity'
          : productName!.trim();

  DeescalationData copyWith({
    String? productName,
    String? barcode,
    num? mrp,
    num? chargedPrice,
    String? shopName,
    String? location,
    String? notes,
  }) {
    return DeescalationData(
      productName: productName ?? this.productName,
      barcode: barcode ?? this.barcode,
      mrp: mrp ?? this.mrp,
      chargedPrice: chargedPrice ?? this.chargedPrice,
      shopName: shopName ?? this.shopName,
      location: location ?? this.location,
      notes: notes ?? this.notes,
    );
  }
}
