import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:priceshield/core/services/priceshield_api_client.dart';
import 'package:priceshield/core/theme/app_theme.dart';
import 'package:priceshield/core/widgets/app_ui.dart';
import 'package:priceshield/features/complaints/services/escalation_pack_service.dart';

class ComplaintDetailsScreen extends StatefulWidget {
  const ComplaintDetailsScreen({super.key, required this.complaintId});
  final String complaintId;

  @override
  State<ComplaintDetailsScreen> createState() => _ComplaintDetailsScreenState();
}

class _ComplaintDetailsScreenState extends State<ComplaintDetailsScreen> {
  late Future<Map<String, dynamic>> _complaint =
      priceShieldApi.getComplaint(widget.complaintId);

  Future<void> _reload() async =>
      setState(() => _complaint = priceShieldApi.getComplaint(widget.complaintId));

  Future<void> _confirmWithdraw() async {
    final shouldWithdraw = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Withdraw Complaint?'),
        content: const Text(
          'Are you sure you want to withdraw this complaint? Once withdrawn, investigation on this report will stop.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep Complaint'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: PriceShieldColors.danger,
              foregroundColor: Colors.white,
            ),
            child: const Text('Withdraw'),
          ),
        ],
      ),
    );

    if (shouldWithdraw != true || !mounted) return;

    try {
      await priceShieldApi.withdrawComplaint(widget.complaintId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Complaint withdrawn successfully.'),
            backgroundColor: PriceShieldColors.navy,
          ),
        );
        Navigator.pop(context);
      }
    } on PriceShieldApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.message),
            backgroundColor: PriceShieldColors.danger,
          ),
        );
      }
    }
  }

  void _openFullScreenImage(String imageUrl) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: const Text('Proof Photo'),
            centerTitle: true,
          ),
          body: Center(
            child: InteractiveViewer(
              panEnabled: true,
              boundaryMargin: const EdgeInsets.all(20),
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                loadingBuilder: (ctx, child, progress) {
                  if (progress == null) return child;
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  );
                },
                errorBuilder: (ctx, error, stackTrace) => const Center(
                  child: Text(
                    'Unable to load photo',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: PriceShieldColors.background,
        appBar: AppBar(
          title: const Text('Complaint Details'),
          elevation: 0,
        ),
        body: FutureBuilder<Map<String, dynamic>>(
          future: _complaint,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(
                child: CircularProgressIndicator(color: PriceShieldColors.primary),
              );
            }
            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.all(20),
                child: InlineError(
                  message: 'We could not load your complaint details.',
                  onRetry: _reload,
                ),
              );
            }
            final data = snapshot.data!;
            final rawEvidence = data['evidence'];
            final List evidence = rawEvidence is List ? rawEvidence : const [];
            final rawStatus = data['status']?.toString().toUpperCase() ?? 'PENDING';

            String friendlyStatus = 'Pending Review';
            Color statusColor = PriceShieldColors.warning;
            String statusSubtitle =
                'Your overcharge report is logged and queued for merchant verification.';

            if (rawStatus == 'RESOLVED') {
              friendlyStatus = 'Resolved';
              statusColor = PriceShieldColors.success;
              statusSubtitle =
                  'This case was successfully settled with the merchant or verified.';
            } else if (rawStatus == 'WITHDRAWN') {
              friendlyStatus = 'Withdrawn';
              statusColor = PriceShieldColors.muted;
              statusSubtitle = 'This complaint was withdrawn by you.';
            } else if (rawStatus == 'REJECTED') {
              friendlyStatus = 'Closed';
              statusColor = PriceShieldColors.danger;
              statusSubtitle =
                  'This complaint could not be verified with the provided evidence.';
            }

            final rawDesc = data['description']?.toString().trim();
            final hasDescription = rawDesc != null &&
                rawDesc.isNotEmpty &&
                rawDesc.toLowerCase() != 'nothing' &&
                rawDesc.toLowerCase() != 'none' &&
                rawDesc.toLowerCase() != 'na' &&
                rawDesc.toLowerCase() != 'n/a';

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
              children: [
                // Top Header Card
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: PriceShieldColors.mint,
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: const Icon(
                              Icons.receipt_long_rounded,
                              color: PriceShieldColors.primary,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  data['productName']?.toString() ?? 'Overcharge Report',
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                                const SizedBox(height: 6),
                                StatusPill(
                                  label: friendlyStatus,
                                  color: statusColor,
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
                          color: PriceShieldColors.surface,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline_rounded,
                                size: 18, color: statusColor),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                statusSubtitle,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: PriceShieldColors.muted,
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
                const SizedBox(height: 16),

                // Price Breakdown Card
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Price Information',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          _value('Printed MRP', data['mrp']),
                          _value('Price Charged', data['chargedPrice']),
                          _value('Overcharged', data['overcharge'], PriceShieldColors.danger),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Case Information Card
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Store & Case Information',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                      ),
                      const SizedBox(height: 14),
                      _detail('Barcode', data['barcode']),
                      _detail('Store Address', data['address']),
                      if (hasDescription) _detail('Your Notes', rawDesc),
                      _detail(
                        'Report Date',
                        data['createdAt'] != null
                            ? _formatDate(data['createdAt'].toString())
                            : 'Recent',
                      ),
                    ],
                  ),
                ),

                // Evidence Section
                if (evidence.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Attached Proof',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                            ),
                            const Spacer(),
                            Text(
                              '${evidence.length} file${evidence.length > 1 ? 's' : ''}',
                              style: const TextStyle(
                                color: PriceShieldColors.muted,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ...evidence.whereType<Map>().map((item) {
                          final url = item['url']?.toString() ?? '';
                          final isImage = url.contains('/image/') ||
                              url.endsWith('.jpg') ||
                              url.endsWith('.jpeg') ||
                              url.endsWith('.png') ||
                              url.endsWith('.webp') ||
                              item['mediaType'] == 'IMAGE' ||
                              item['mediaType'] == 'image';

                          if (url.isEmpty) return const SizedBox.shrink();

                          if (isImage) {
                            return GestureDetector(
                              onTap: () => _openFullScreenImage(url),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: PriceShieldColors.border),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ClipRRect(
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(15),
                                      ),
                                      child: Image.network(
                                        url,
                                        height: 190,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                        loadingBuilder: (context, child, progress) {
                                          if (progress == null) return child;
                                          return Container(
                                            height: 190,
                                            color: const Color(0xffF1F4FF),
                                            child: const Center(
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: PriceShieldColors.primary,
                                              ),
                                            ),
                                          );
                                        },
                                        errorBuilder: (context, error, stackTrace) =>
                                            Container(
                                          height: 100,
                                          color: const Color(0xffF8F9FA),
                                          child: const Center(
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(Icons.image_not_supported_outlined,
                                                    color: PriceShieldColors.muted),
                                                SizedBox(width: 8),
                                                Text(
                                                  'Photo proof preview unavailable',
                                                  style: TextStyle(
                                                      color: PriceShieldColors.muted),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 10,
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.verified_outlined,
                                            size: 16,
                                            color: PriceShieldColors.primary,
                                          ),
                                          const SizedBox(width: 8),
                                          const Expanded(
                                            child: Text(
                                              'Receipt / Package Photo Proof',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                          const Text(
                                            'Tap to zoom',
                                            style: TextStyle(
                                              color: PriceShieldColors.primary,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          const Icon(
                                            Icons.fullscreen_rounded,
                                            size: 18,
                                            color: PriceShieldColors.primary,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: PriceShieldColors.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: PriceShieldColors.border),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.videocam_outlined,
                                    color: PriceShieldColors.primary),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Video Proof Attached',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // Responsible Escalation Pack Actions
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
                                  'Generate legal texts for WhatsApp or Consumer Forum',
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
                          onPressed: () async {
                            final notice = EscalationPackService.generateWhatsAppNotice(
                              productName: data['productName']?.toString() ?? 'Product',
                              barcode: data['barcode']?.toString() ?? '',
                              mrp: num.tryParse(data['mrp']?.toString() ?? '0') ?? 0,
                              chargedPrice: num.tryParse(data['chargedPrice']?.toString() ?? '0') ?? 0,
                              merchantName: data['merchantName']?.toString(),
                              storeAddress: data['merchantAddress']?.toString(),
                            );
                            await Clipboard.setData(ClipboardData(text: notice));
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Legal Notice copied to clipboard! Ready to share on WhatsApp or Email.'),
                                  backgroundColor: PriceShieldColors.navy,
                                ),
                              );
                            }
                          },
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
                          onPressed: () async {
                            final docket = EscalationPackService.generateOfficialDocket(
                              docketId: data['id']?.toString() ?? widget.complaintId,
                              productName: data['productName']?.toString() ?? 'Product',
                              barcode: data['barcode']?.toString() ?? '',
                              mrp: num.tryParse(data['mrp']?.toString() ?? '0') ?? 0,
                              chargedPrice: num.tryParse(data['chargedPrice']?.toString() ?? '0') ?? 0,
                              merchantName: data['merchantName']?.toString(),
                              storeAddress: data['merchantAddress']?.toString(),
                              evidenceSummary: data['description']?.toString(),
                            );
                            await Clipboard.setData(ClipboardData(text: docket));
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Official Grievance Docket copied! Ready for NCH 1915 or DCDRC.'),
                                  backgroundColor: PriceShieldColors.navy,
                                ),
                              );
                            }
                          },
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

                // Withdraw Button
                if (rawStatus != 'WITHDRAWN' && rawStatus != 'RESOLVED') ...[
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    onPressed: _confirmWithdraw,
                    icon: const Icon(Icons.undo_rounded),
                    label: const Text('Withdraw Complaint'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: PriceShieldColors.danger,
                      side: const BorderSide(color: PriceShieldColors.danger),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      );

  Widget _value(String label, dynamic value, [Color color = PriceShieldColors.text]) =>
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(color: PriceShieldColors.muted, fontSize: 11),
            ),
            const SizedBox(height: 4),
            Text(
              '\u{20B9}${value ?? 0}',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );

  Widget _detail(String label, dynamic value) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 100,
              child: Text(
                label,
                style: const TextStyle(
                  color: PriceShieldColors.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Expanded(
              child: Text(
                value?.toString().isNotEmpty == true
                    ? value.toString()
                    : 'Not provided',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      );

  String _formatDate(String isoString) {
    try {
      final date = DateTime.parse(isoString).toLocal();
      return '${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return isoString;
    }
  }
}
