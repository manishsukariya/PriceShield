import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:priceshield/core/theme/app_theme.dart';
import 'package:priceshield/features/deescalation/models/deescalation_data.dart';
import 'package:priceshield/features/deescalation/services/helpline_service.dart';

class HelplineCard extends StatelessWidget {
  const HelplineCard({
    super.key,
    required this.data,
  });

  final DeescalationData data;

  Future<void> _handleWhatsAppLaunch(BuildContext context) async {
    final result = await HelplineService.openWhatsAppHelpline(data);
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        backgroundColor: result.success
            ? PriceShieldColors.success
            : (result.copiedToClipboard
                ? PriceShieldColors.warning
                : PriceShieldColors.danger),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _handleCopyReport(BuildContext context) async {
    final report = HelplineService.buildComplaintMessage(data);
    await Clipboard.setData(ClipboardData(text: report));
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Dispute report copied to clipboard.'),
        backgroundColor: PriceShieldColors.success,
      ),
    );
  }

  Future<void> _handleCallHelpline(BuildContext context) async {
    final success = await HelplineService.callTollFreeHelpline();
    if (!success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open phone dialer for 1915.'),
          backgroundColor: PriceShieldColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: PriceShieldColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0D1B2A),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xff25D366).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.chat_bubble_outline_rounded,
                  color: Color(0xff128C7E),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      '1-Tap WhatsApp Helpline',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: PriceShieldColors.navy,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'National Consumer Helpline: +91 8800001915',
                      style: TextStyle(
                        color: PriceShieldColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xfff0fdf4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xffbbf7d0)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Icon(Icons.verified_outlined,
                    color: Color(0xff16a34a), size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Opens WhatsApp with pre-drafted legal citations (Rule 18(2) & Jan Vishwas Act) and dispute amounts ready to send to the Ministry.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xff14532d),
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Primary WhatsApp Button
          SizedBox(
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () => _handleWhatsAppLaunch(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xff25D366),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              icon: const Icon(Icons.send_rounded, size: 20),
              label: const Text(
                'Open WhatsApp Complaint (+91 8800001915)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Secondary Action Buttons: Copy / Call 1915
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _handleCopyReport(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: const Text(
                    'Copy Report',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _handleCallHelpline(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.call_outlined, size: 16),
                  label: const Text(
                    'Call 1915',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
