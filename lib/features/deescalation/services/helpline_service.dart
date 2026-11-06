import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:priceshield/features/deescalation/models/deescalation_data.dart';

class HelplineLaunchResult {
  const HelplineLaunchResult({
    required this.success,
    required this.message,
    this.copiedToClipboard = false,
  });

  final bool success;
  final String message;
  final bool copiedToClipboard;
}

class HelplineService {
  static const String whatsappNumber = '918800001915';
  static const String whatsappDisplayNumber = '+91 8800001915';
  static const String tollFreeNumber = '1915';
  static const String tollFreeAlt = '1800114000';
  static const String portalUrl = 'https://consumerhelpline.gov.in';

  /// Pre-drafts a formal complaint formatted for the National Consumer Helpline.
  static String buildComplaintMessage(DeescalationData data) {
    final nowStr = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());
    final hasOvercharge = data.hasOvercharge;

    final buffer = StringBuffer();
    buffer.writeln('📋 *NATIONAL CONSUMER HELPLINE (NCH) DISPUTE REPORT*');
    buffer.writeln('------------------------------------------');
    buffer.writeln('🚨 *VIOLATION:* Charging above MRP (Refrigeration / Chilling Surcharge)');
    buffer.writeln('⚖️ *LEGAL PROVISIONS VIOLATED:*');
    buffer.writeln('1. *Rule 18(2), Legal Metrology (Packaged Commodities) Rules, 2011*');
    buffer.writeln('   - MRP is inclusive of all taxes and refrigeration expenses.');
    buffer.writeln('   - No retailer can charge over the printed MRP for chilling or any other service.');
    buffer.writeln('2. *Jan Vishwas (Amendment of Provisions) Act, 2023*');
    buffer.writeln('   - Overcharging attracts statutory inspection and escalating civil compounding penalties up to ₹5,00,000 for repeat offenses.');
    buffer.writeln('------------------------------------------');
    buffer.writeln('📦 *PRODUCT DETAILS:*');
    buffer.writeln('• Item: ${data.displayName}');
    if (data.barcode != null && data.barcode!.isNotEmpty) {
      buffer.writeln('• Barcode: ${data.barcode}');
    }
    if (data.mrp != null) {
      buffer.writeln('• Printed MRP: ₹${data.formattedMrp}');
    }
    if (data.chargedPrice != null) {
      buffer.writeln('• Demanded Price: ₹${data.formattedChargedPrice}');
    }
    if (hasOvercharge) {
      buffer.writeln('• Excess Surcharge: ₹${data.formattedOvercharge} (Illegal)');
    }
    if (data.shopName != null && data.shopName!.trim().isNotEmpty) {
      buffer.writeln('• Shop / Vendor: ${data.shopName!.trim()}');
    }
    if (data.location != null && data.location!.trim().isNotEmpty) {
      buffer.writeln('• Location: ${data.location!.trim()}');
    }
    buffer.writeln('• Incident Timestamp: $nowStr');
    buffer.writeln('------------------------------------------');
    buffer.writeln('Please register this complaint for statutory action and regulatory verification under the Department of Consumer Affairs.');

    return buffer.toString();
  }

  /// Opens the National Consumer Helpline WhatsApp assistant with pre-drafted dispute.
  static Future<HelplineLaunchResult> openWhatsAppHelpline(DeescalationData data) async {
    final text = buildComplaintMessage(data);
    final encoded = Uri.encodeComponent(text);

    // Primary: universal WhatsApp web/app link
    final waUri = Uri.parse('https://wa.me/$whatsappNumber?text=$encoded');

    bool launched = false;
    try {
      launched = await launchUrl(
        waUri,
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      launched = false;
    }

    if (!launched) {
      try {
        launched = await launchUrl(
          waUri,
          mode: LaunchMode.platformDefault,
        );
      } catch (_) {
        launched = false;
      }
    }

    if (!launched) {
      final nativeUri = Uri.parse('whatsapp://send?phone=$whatsappNumber&text=$encoded');
      try {
        launched = await launchUrl(
          nativeUri,
          mode: LaunchMode.externalApplication,
        );
      } catch (_) {
        launched = false;
      }
    }

    if (launched) {
      return const HelplineLaunchResult(
        success: true,
        message: 'Opened National Consumer Helpline WhatsApp assistant.',
      );
    }

    // Graceful fallback if WhatsApp cannot be opened:
    // Copy pre-drafted text to user's clipboard
    await Clipboard.setData(ClipboardData(text: text));
    return const HelplineLaunchResult(
      success: false,
      message: 'Could not launch WhatsApp. Complaint text copied to clipboard.',
      copiedToClipboard: true,
    );
  }

  /// Calls the official National Consumer Helpline toll-free number (1915).
  static Future<bool> callTollFreeHelpline() async {
    final uri = Uri.parse('tel:$tollFreeNumber');
    try {
      return await launchUrl(uri);
    } catch (_) {
      return false;
    }
  }
}
