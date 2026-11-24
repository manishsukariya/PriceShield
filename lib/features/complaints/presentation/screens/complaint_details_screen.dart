import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:priceshield/core/services/cloudinary_upload_service.dart';
import 'package:priceshield/core/services/priceshield_api_client.dart';
import 'package:priceshield/core/services/realtime_complaint_service.dart';
import 'package:priceshield/core/theme/app_theme.dart';
import 'package:priceshield/core/widgets/app_ui.dart';
import 'package:priceshield/features/complaints/services/escalation_pack_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

class ComplaintDetailsScreen extends StatefulWidget {
  const ComplaintDetailsScreen({
    super.key,
    required this.complaintId,
    this.apiClient,
  });

  final String complaintId;
  final PriceShieldApiClient? apiClient;

  @override
  State<ComplaintDetailsScreen> createState() => _ComplaintDetailsScreenState();
}

class _ComplaintDetailsScreenState extends State<ComplaintDetailsScreen> {
  PriceShieldApiClient get _api => widget.apiClient ?? priceShieldApi;
  late Future<Map<String, dynamic>> _complaint;
  Map<String, dynamic>? _liveComplaint;
  bool _uploadingEvidence = false;
  StreamSubscription<Map<String, dynamic>>? _realtimeSub;

  @override
  void initState() {
    super.initState();
    _complaint = _api.getComplaint(widget.complaintId);
    RealtimeComplaintService.instance.start();
    _realtimeSub = RealtimeComplaintService.instance.stream.listen((event) {
      final targetId = event['complaintId']?.toString();
      if (targetId == widget.complaintId && mounted) {
        final newStatus = event['status']?.toString();
        if (newStatus != null) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.bolt_rounded, color: Color(0xffFBBF24), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Live Update: Status set to ${newStatus.replaceAll('_', ' ')}'),
                  ),
                ],
              ),
              backgroundColor: PriceShieldColors.navy,
              duration: const Duration(seconds: 4),
            ),
          );
        }
        final rawComplaint = event['complaint'];
        if (rawComplaint is Map) {
          setState(() {
            _liveComplaint = Map<String, dynamic>.from(rawComplaint);
            _complaint = Future.value(_liveComplaint!);
          });
        } else {
          _reload();
        }
      }
    });
  }

  @override
  void dispose() {
    _realtimeSub?.cancel();
    RealtimeComplaintService.instance.stop();
    super.dispose();
  }

  Future<void> _reload() async =>
      setState(() {
        _liveComplaint = null;
        _complaint = _api.getComplaint(widget.complaintId);
      });

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
      await _api.withdrawComplaint(widget.complaintId);
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

  Future<void> _pickAndUploadMoreEvidence() async {
    final selectedRole = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Select Evidence Type to Attach',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined, color: PriceShieldColors.primary),
              title: const Text('Packet MRP Photo'),
              onTap: () => Navigator.pop(ctx, 'PACKET_MRP'),
            ),
            ListTile(
              leading: const Icon(Icons.receipt_outlined, color: PriceShieldColors.primary),
              title: const Text('Payment Proof (UPI / Card)'),
              onTap: () => Navigator.pop(ctx, 'PAYMENT_PROOF'),
            ),
            ListTile(
              leading: const Icon(Icons.description_outlined, color: PriceShieldColors.primary),
              title: const Text('Itemized Bill / Receipt'),
              onTap: () => Navigator.pop(ctx, 'ITEMIZED_BILL'),
            ),
            ListTile(
              leading: const Icon(Icons.videocam_outlined, color: PriceShieldColors.primary),
              title: const Text('Purchase Video'),
              onTap: () => Navigator.pop(ctx, 'VIDEO_PROOF'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (selectedRole == null || !mounted) return;

    final isVideo = selectedRole == 'VIDEO_PROOF';
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                isVideo ? 'Select Video Source' : 'Select Photo Source',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: Icon(
                isVideo ? Icons.videocam_outlined : Icons.camera_alt_outlined,
                color: PriceShieldColors.primary,
              ),
              title: Text(isVideo ? 'Record Video' : 'Take a Photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: Icon(
                isVideo ? Icons.video_library_outlined : Icons.photo_library_outlined,
                color: PriceShieldColors.primary,
              ),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    final picker = ImagePicker();
    final picked = isVideo
        ? await picker.pickVideo(source: source, maxDuration: const Duration(minutes: 2))
        : await picker.pickImage(source: source, imageQuality: 85);
    if (picked == null || !mounted) return;

    setState(() => _uploadingEvidence = true);
    try {
      final uploaded = await CloudinaryUploadService.uploadFile(
        file: File(picked.path),
        isVideo: isVideo,
      );
      await _api.addComplaintEvidence(widget.complaintId, {
        'url': uploaded.secureUrl,
        'publicId': uploaded.publicId,
        'resourceType': uploaded.resourceType,
        'mediaType': isVideo ? 'VIDEO' : 'IMAGE',
        'role': selectedRole,
        'sha256Hash': uploaded.sha256Hash,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Evidence attached and verification tier updated!'),
            backgroundColor: PriceShieldColors.success,
          ),
        );
        await _reload();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('StateError: ', '')),
            backgroundColor: PriceShieldColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingEvidence = false);
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

  void _openFullScreenVideo(String videoUrl, String title) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FullScreenVideoViewer(
          videoUrl: videoUrl,
          title: title,
        ),
      ),
    );
  }

  Color _confidenceColor(String level) {
    switch (level) {
      case 'CORROBORATED':
        return const Color(0xff0F766E);
      case 'STRONG':
        return PriceShieldColors.success;
      case 'BASIC':
        return const Color(0xff2563EB);
      default:
        return PriceShieldColors.warning;
    }
  }

  String _roleLabel(String? role) {
    switch (role?.toUpperCase()) {
      case 'PACKET_MRP':
        return 'Packet MRP Photo';
      case 'PAYMENT_PROOF':
        return 'Payment Proof';
      case 'ITEMIZED_BILL':
        return 'Itemized Bill / Receipt';
      case 'VIDEO_PROOF':
        return 'Purchase Video';
      default:
        return 'Supporting Proof';
    }
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
            final data = _liveComplaint ?? snapshot.data;
            if (data == null) {
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
              return const SizedBox.shrink();
            }
            final rawEvidence = data['evidence'];
            final List evidence = rawEvidence is List ? rawEvidence : const [];
            String effectiveStatus = data['status']?.toString().toUpperCase() ?? 'PENDING';
            final rawFlags = data['riskFlags'];
            if (rawFlags is List && effectiveStatus == 'PENDING') {
              for (final flag in rawFlags) {
                if (flag is String && flag.startsWith('STAGE_')) {
                  effectiveStatus = flag.substring(6);
                  break;
                }
              }
            }
            final rawStatus = effectiveStatus;
            final confidenceLevel =
                data['confidenceLevel']?.toString().toUpperCase() ?? 'UNVERIFIED';
            final venueType =
                data['venueType']?.toString().toUpperCase() ?? 'RETAIL';
            final mrp = num.tryParse(data['mrp']?.toString() ?? '0') ?? 0;
            final chargedPrice =
                num.tryParse(data['chargedPrice']?.toString() ?? '0') ?? 0;
            final quantity = int.tryParse(data['quantity']?.toString() ?? '1') ?? 1;
            final totalPaid = num.tryParse(data['totalPaid']?.toString() ?? '');
            final paymentMethod = data['paymentMethod']?.toString();
            final utrNumber = data['utrNumber']?.toString();
            final merchantName = data['merchantName']?.toString();
            final merchantVpa = data['merchantVpa']?.toString();
            final moderationNotes = data['moderationNotes']?.toString();
            final merchantResponse = data['merchantResponse']?.toString();
            final purchaseDate = DateTime.tryParse(data['purchaseDate']?.toString() ?? '');

            String friendlyStatus = 'Pending Review';
            Color statusColor = PriceShieldColors.warning;
            String statusSubtitle =
                'Your overcharge report is logged and queued for verification.';

            if (rawStatus == 'RESOLVED') {
              friendlyStatus = 'Resolved';
              statusColor = PriceShieldColors.success;
              statusSubtitle =
                  'This case was verified and marked resolved.';
            } else if (rawStatus == 'WITHDRAWN') {
              friendlyStatus = 'Withdrawn';
              statusColor = PriceShieldColors.muted;
              statusSubtitle = 'This complaint was withdrawn by you.';
            } else if (rawStatus == 'REJECTED') {
              friendlyStatus = 'Rejected';
              statusColor = PriceShieldColors.danger;
              statusSubtitle =
                  'This complaint could not be verified with the provided evidence.';
            } else if (rawStatus == 'INVESTIGATING') {
              friendlyStatus = 'Under Investigation';
              statusColor = const Color(0xff2563EB);
              statusSubtitle =
                  'PriceShield operations desk is actively investigating this store.';
            } else if (rawStatus == 'SETTLEMENT_PROPOSED') {
              friendlyStatus = 'Settlement Offered';
              statusColor = const Color(0xff0F9D8A);
              statusSubtitle =
                  'A 48h instant refund conciliation offer was sent to the merchant.';
            } else if (rawStatus == 'ESCALATED_LEGAL_METROLOGY') {
              friendlyStatus = 'Escalated to LM Dept';
              statusColor = const Color(0xff8B5CF6);
              statusSubtitle =
                  'Docket forwarded to Department of Legal Metrology for inspection.';
            }

            final showVerificationPendingWatermark =
                confidenceLevel == 'UNVERIFIED' ||
                    confidenceLevel == 'BASIC' ||
                    rawStatus == 'PENDING';

            final canExportNotice = EscalationPackService.canExportLegalNotice(
              mrp: mrp,
              chargedPrice: chargedPrice,
              venueType: venueType,
              complaintStatus: rawStatus,
              hasLoggedComplaint: true,
            );
            final canExportDocket = EscalationPackService.canExportOfficialDocket(
              mrp: mrp,
              chargedPrice: chargedPrice,
              venueType: venueType,
              complaintStatus: rawStatus,
              confidenceLevel: confidenceLevel,
              hasLoggedComplaint: true,
            );

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
                Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xffE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: PriceShieldColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.shield_outlined, color: PriceShieldColors.primary, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Official Legal Metrology Grievance',
                              style: TextStyle(
                                color: PriceShieldColors.primary,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Tracked under Section 18(2) & 36(1) of Legal Metrology Act, 2009.',
                              style: TextStyle(color: PriceShieldColors.muted, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

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
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  children: [
                                    StatusPill(
                                      label: friendlyStatus,
                                      color: statusColor,
                                    ),
                                    StatusPill(
                                      label: confidenceLevel,
                                      color: _confidenceColor(confidenceLevel),
                                    ),
                                  ],
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
                            Icon(Icons.info_outline_rounded, size: 18, color: statusColor),
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
                      if (showVerificationPendingWatermark && rawStatus != 'WITHDRAWN' && rawStatus != 'REJECTED') ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                          decoration: BoxDecoration(
                            color: const Color(0xffFFFBEB),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xffFCD34D)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.verified_user_outlined, size: 16, color: Color(0xffB45309)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  confidenceLevel == 'UNVERIFIED'
                                      ? '${EscalationPackService.verificationPendingWatermark} • Private advisory record only (attach Packet MRP & payment/bill proof).'
                                      : EscalationPackService.verificationPendingWatermark,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xff92400E),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (confidenceLevel == 'CORROBORATED' &&
                          rawStatus != 'REJECTED' &&
                          rawStatus != 'WITHDRAWN') ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                          decoration: BoxDecoration(
                            color: const Color(0xffF0FDFA),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xff99F6E4)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.hub_outlined, size: 16, color: Color(0xff0F766E)),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Store-level risk signal: Multiple independent reports logged for this merchant (pending official verification).',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xff115E59),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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
                        'Price & Transaction Breakdown',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          _value('Printed MRP', data['mrp']),
                          _value('Charged/Unit', data['chargedPrice']),
                          _value('Overcharge/Unit', data['overcharge'], PriceShieldColors.danger),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          _plainValue('Quantity', '$quantity'),
                          _value('Total Paid', totalPaid ?? (chargedPrice * quantity)),
                          _plainValue('Payment', paymentMethod ?? 'N/A'),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Store & Verification Metadata Card
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Store & Verification Details',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                      ),
                      const SizedBox(height: 14),
                      _detail('Merchant', merchantName),
                      if (merchantVpa != null && merchantVpa.isNotEmpty)
                        _detail('Merchant VPA', merchantVpa),
                      if (utrNumber != null && utrNumber.isNotEmpty)
                        _detail('UTR / Ref No.', utrNumber),
                      _detail('Barcode', data['barcode']),
                      _detail('Venue Type', venueType),
                      _detail('Store Address', data['address']),
                      if (hasDescription) _detail('Your Notes', rawDesc),
                      if (purchaseDate != null)
                        _detail('Purchase Date', _formatDate(purchaseDate.toIso8601String())),
                      _detail(
                        'Filed On',
                        data['createdAt'] != null
                            ? _formatDate(data['createdAt'].toString())
                            : 'Recent',
                      ),
                      if (moderationNotes != null && moderationNotes.trim().isNotEmpty)
                        _detail('Review Notes', moderationNotes),
                      if (merchantResponse != null && merchantResponse.trim().isNotEmpty)
                        _detail('Merchant Note', merchantResponse),
                    ],
                  ),
                ),

                // Evidence Section
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
                            '${evidence.length}/5 files',
                            style: const TextStyle(
                              color: PriceShieldColors.muted,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (evidence.isEmpty)
                        const Text(
                          'No photos or videos attached yet.',
                          style: TextStyle(color: PriceShieldColors.muted, fontSize: 13),
                        ),
                      ...evidence.whereType<Map>().map((item) {
                        final url = item['url']?.toString() ?? '';
                        final role = item['role']?.toString();
                        final mediaType = item['mediaType']?.toString().toUpperCase() ?? '';
                        final isVideo = role == 'VIDEO_PROOF' ||
                            mediaType == 'VIDEO' ||
                            url.contains('/video/') ||
                            url.endsWith('.mp4') ||
                            url.endsWith('.mov') ||
                            url.endsWith('.mkv') ||
                            url.endsWith('.webm');
                        final isImage = !isVideo &&
                            (url.contains('/image/') ||
                                url.endsWith('.jpg') ||
                                url.endsWith('.jpeg') ||
                                url.endsWith('.png') ||
                                url.endsWith('.webp') ||
                                mediaType == 'IMAGE');

                        if (url.isEmpty) return const SizedBox.shrink();

                        if (isVideo) {
                          return GestureDetector(
                            onTap: () => _openFullScreenVideo(url, _roleLabel(role)),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: PriceShieldColors.border),
                                color: PriceShieldColors.surface,
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    height: 180,
                                    width: double.infinity,
                                    decoration: const BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          Color(0xff0B192C),
                                          Color(0xff1E293B),
                                        ],
                                      ),
                                    ),
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        Icon(
                                          Icons.videocam_rounded,
                                          size: 80,
                                          color: Colors.white.withValues(alpha: 0.08),
                                        ),
                                        Container(
                                          width: 60,
                                          height: 60,
                                          decoration: BoxDecoration(
                                            color: PriceShieldColors.primary.withValues(alpha: 0.92),
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: PriceShieldColors.primary.withValues(alpha: 0.4),
                                                blurRadius: 16,
                                                spreadRadius: 2,
                                              ),
                                            ],
                                          ),
                                          child: const Icon(
                                            Icons.play_arrow_rounded,
                                            color: Colors.white,
                                            size: 38,
                                          ),
                                        ),
                                        Positioned(
                                          top: 10,
                                          right: 10,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.black.withValues(alpha: 0.65),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.play_circle_outline_rounded, color: Colors.white, size: 13),
                                                SizedBox(width: 4),
                                                Text(
                                                  'VIDEO PROOF',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w700,
                                                    letterSpacing: 0.5,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
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
                                          Icons.videocam_outlined,
                                          size: 16,
                                          color: PriceShieldColors.primary,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            _roleLabel(role),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                        const Row(
                                          children: [
                                            Icon(
                                              Icons.play_circle_fill_rounded,
                                              color: PriceShieldColors.primary,
                                              size: 14,
                                            ),
                                            SizedBox(width: 4),
                                            Text(
                                              'Tap to play',
                                              style: TextStyle(
                                                color: PriceShieldColors.primary,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

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
                                      errorBuilder: (context, error, stackTrace) =>
                                          Container(
                                        height: 100,
                                        color: const Color(0xffF8F9FA),
                                        child: const Center(
                                          child: Text(
                                            'Photo proof preview unavailable',
                                            style: TextStyle(color: PriceShieldColors.muted),
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
                                        Expanded(
                                          child: Text(
                                            _roleLabel(role),
                                            style: const TextStyle(
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
                          child: Row(
                            children: [
                              const Icon(Icons.attachment_rounded, color: PriceShieldColors.primary),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _roleLabel(role),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                                onPressed: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
                              ),
                            ],
                          ),
                        );
                      }),
                      if (rawStatus == 'PENDING' && evidence.length < 5) ...[
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _uploadingEvidence ? null : _pickAndUploadMoreEvidence,
                            icon: _uploadingEvidence
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.add_a_photo_outlined),
                            label: Text(
                              _uploadingEvidence
                                  ? 'Uploading Proof...'
                                  : 'Add Supporting Proof',
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Responsible Escalation Pack Actions (Gated)
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
                                  'Generate structured texts for merchant or NCH 1915',
                                  style: TextStyle(color: PriceShieldColors.muted, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      if (!canExportNotice)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xffFEF2F2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xffFECACA)),
                          ),
                          child: const Text(
                            'Legal Notice and Official Grievance Docket export are unavailable for rejected, withdrawn, dine-in restaurant, or non-overcharged cases.',
                            style: TextStyle(fontSize: 12, color: Color(0xff991B1B)),
                          ),
                        )
                      else ...[
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final notice = EscalationPackService.generateWhatsAppNotice(
                                productName: data['productName']?.toString() ?? 'Product',
                                barcode: data['barcode']?.toString() ?? '',
                                mrp: mrp,
                                chargedPrice: chargedPrice,
                                quantity: quantity,
                                totalPaid: totalPaid,
                                paymentMethod: paymentMethod,
                                utrNumber: utrNumber,
                                merchantName: merchantName,
                                merchantVpa: merchantVpa,
                                storeAddress: (data['address'] ?? data['merchantAddress'])?.toString(),
                                confidenceLevel: confidenceLevel,
                                complaintStatus: rawStatus,
                                venueType: venueType,
                                date: purchaseDate,
                              );
                              await Clipboard.setData(ClipboardData(text: notice));
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Legal Notice copied to clipboard!'),
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
                        if (!canExportDocket)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xffFFFBEB),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xffFDE68A)),
                            ),
                            child: const Text(
                              'Official Grievance Docket locked: This is a private UNVERIFIED record. Attach a Packet MRP photo + Payment Proof or Itemized Bill to unlock docket export.',
                              style: TextStyle(fontSize: 12, color: Color(0xff92400E)),
                            ),
                          )
                        else
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final evidenceLabels = evidence
                                    .whereType<Map>()
                                    .map((e) => _roleLabel(e['role']?.toString()))
                                    .toSet()
                                    .join(', ');
                                final docket = EscalationPackService.generateOfficialDocket(
                                  docketId: data['id']?.toString() ?? widget.complaintId,
                                  productName: data['productName']?.toString() ?? 'Product',
                                  barcode: data['barcode']?.toString() ?? '',
                                  mrp: mrp,
                                  chargedPrice: chargedPrice,
                                  quantity: quantity,
                                  totalPaid: totalPaid,
                                  paymentMethod: paymentMethod,
                                  utrNumber: utrNumber,
                                  merchantName: merchantName,
                                  merchantVpa: merchantVpa,
                                  storeAddress: (data['address'] ?? data['merchantAddress'])?.toString(),
                                  confidenceLevel: confidenceLevel,
                                  complaintStatus: rawStatus,
                                  venueType: venueType,
                                  incidentDate: purchaseDate,
                                  evidenceSummary: evidenceLabels.isNotEmpty
                                      ? '$evidenceLabels (${evidence.length} file(s))'
                                      : data['description']?.toString(),
                                );
                                await Clipboard.setData(ClipboardData(text: docket));
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Official Grievance Docket copied!'),
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
                fontSize: 15,
              ),
            ),
          ],
        ),
      );

  Widget _plainValue(String label, String value) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(color: PriceShieldColors.muted, fontSize: 11),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                color: PriceShieldColors.text,
                fontWeight: FontWeight.w700,
                fontSize: 14,
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
              width: 105,
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

class FullScreenVideoViewer extends StatefulWidget {
  const FullScreenVideoViewer({
    super.key,
    required this.videoUrl,
    required this.title,
  });

  final String videoUrl;
  final String title;

  @override
  State<FullScreenVideoViewer> createState() => _FullScreenVideoViewerState();
}

class _FullScreenVideoViewerState extends State<FullScreenVideoViewer> {
  late VideoPlayerController _controller;
  bool _initialized = false;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _initController();
  }

  Future<void> _initController() async {
    try {
      final uri = Uri.parse(widget.videoUrl);
      _controller = VideoPlayerController.networkUrl(uri);
      await _controller.initialize();
      if (mounted) {
        setState(() {
          _initialized = true;
        });
        _controller.play();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  void dispose() {
    if (_initialized) {
      _controller.dispose();
    }
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> _launchInBrowser() async {
    try {
      final uri = Uri.parse(widget.videoUrl);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          widget.title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Open in Browser',
            icon: const Icon(Icons.open_in_new_rounded, color: Colors.white),
            onPressed: _launchInBrowser,
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: _hasError
              ? Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        color: Colors.redAccent,
                        size: 48,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Unable to play video in app',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _errorMessage,
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: PriceShieldColors.primary,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _launchInBrowser,
                        icon: const Icon(Icons.open_in_browser_rounded),
                        label: const Text('Open External Player'),
                      ),
                    ],
                  ),
                )
              : !_initialized
                  ? const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: PriceShieldColors.primary),
                        SizedBox(height: 16),
                        Text(
                          'Loading video proof...',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Center(
                            child: AspectRatio(
                              aspectRatio: _controller.value.aspectRatio > 0
                                  ? _controller.value.aspectRatio
                                  : 16 / 9,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  VideoPlayer(_controller),
                                  GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () {
                                      setState(() {
                                        _controller.value.isPlaying
                                            ? _controller.pause()
                                            : _controller.play();
                                      });
                                    },
                                    child: AnimatedOpacity(
                                      opacity: _controller.value.isPlaying ? 0.0 : 0.85,
                                      duration: const Duration(milliseconds: 200),
                                      child: Container(
                                        width: 72,
                                        height: 72,
                                        decoration: const BoxDecoration(
                                          color: Colors.black54,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          _controller.value.isPlaying
                                              ? Icons.pause_rounded
                                              : Icons.play_arrow_rounded,
                                          color: Colors.white,
                                          size: 48,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        ValueListenableBuilder(
                          valueListenable: _controller,
                          builder: (context, VideoPlayerValue value, child) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              color: const Color(0xff111827),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  VideoProgressIndicator(
                                    _controller,
                                    allowScrubbing: true,
                                    colors: const VideoProgressColors(
                                      playedColor: PriceShieldColors.primary,
                                      bufferedColor: Colors.white24,
                                      backgroundColor: Colors.white10,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: Icon(
                                          value.isPlaying
                                              ? Icons.pause_rounded
                                              : Icons.play_arrow_rounded,
                                          color: Colors.white,
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            value.isPlaying
                                                ? _controller.pause()
                                                : _controller.play();
                                          });
                                        },
                                      ),
                                      Text(
                                        '${_formatDuration(value.position)} / ${_formatDuration(value.duration)}',
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const Spacer(),
                                      IconButton(
                                        tooltip: 'Replay from start',
                                        icon: const Icon(
                                          Icons.replay_rounded,
                                          color: Colors.white70,
                                          size: 20,
                                        ),
                                        onPressed: () {
                                          _controller.seekTo(Duration.zero);
                                          _controller.play();
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
        ),
      ),
    );
  }
}
