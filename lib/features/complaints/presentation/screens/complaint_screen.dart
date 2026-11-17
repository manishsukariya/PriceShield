import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:priceshield/app/navigation/main_navigation.dart';
import 'package:priceshield/core/services/auth_session.dart';
import 'package:priceshield/core/services/cloudinary_upload_service.dart';
import 'package:priceshield/core/services/priceshield_api_client.dart';
import 'package:priceshield/features/deescalation/services/helpline_service.dart';

class _EvidenceDraft {
  const _EvidenceDraft({
    required this.file,
    required this.isVideo,
    required this.role,
  });

  final File file;
  final bool isVideo;
  final String role;
}

class ComplaintScreen extends StatefulWidget {
  final String name;
  final String barcode;
  final num mrp;
  final num charged;
  final String? initialNotes;
  final String venueType;
  final PriceShieldApiClient? apiClient;

  const ComplaintScreen({
    super.key,
    required this.name,
    required this.barcode,
    required this.mrp,
    required this.charged,
    this.initialNotes,
    this.venueType = 'RETAIL',
    this.apiClient,
  });

  static String predictConfidenceLevel(Iterable<({String role, bool isVideo})> items) {
    final list = items.toList();
    final hasPacketMrp = list.any((item) => item.role == 'PACKET_MRP');
    if (!hasPacketMrp) return 'UNVERIFIED';
    final hasBill = list.any((item) => item.role == 'ITEMIZED_BILL');
    final hasVideo = list.any((item) => item.role == 'VIDEO_PROOF' && item.isVideo);
    if (hasBill || hasVideo) return 'STRONG';
    final hasPayment = list.any((item) => item.role == 'PAYMENT_PROOF');
    if (hasPayment) return 'BASIC';
    return 'UNVERIFIED';
  }

  @override
  State<ComplaintScreen> createState() => _ComplaintScreenState();
}

class _ComplaintScreenState extends State<ComplaintScreen> {
  static const int _maxEvidenceItems = 5;

  final String _submissionId =
      'complaint-${DateTime.now().microsecondsSinceEpoch}';
  final TextEditingController merchantNameController = TextEditingController();
  final TextEditingController merchantVpaController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController descController = TextEditingController();
  final TextEditingController utrController = TextEditingController();
  final TextEditingController totalPaidController = TextEditingController();

  String _paymentMethod = 'UPI';
  int _quantity = 1;
  bool _totalPaidManuallyEdited = false;
  DateTime selectedDate = DateTime.now();

  final List<_EvidenceDraft> _evidenceItems = [];
  bool loading = false;

  double? latitude;
  double? longitude;

  PriceShieldApiClient get _api => widget.apiClient ?? priceShieldApi;
  bool get _isRestaurant => widget.venueType.trim().toUpperCase() == 'RESTAURANT';
  num get unitOvercharge => widget.charged - widget.mrp;
  num get totalOvercharge => unitOvercharge * _quantity;

  String get _predictedConfidence => ComplaintScreen.predictConfidenceLevel(
        _evidenceItems.map((e) => (role: e.role, isVideo: e.isVideo)),
      );

  @override
  void initState() {
    super.initState();
    if (widget.initialNotes != null && widget.initialNotes!.isNotEmpty) {
      descController.text = widget.initialNotes!;
    }
    _syncDefaultTotalPaid();
  }

  void _syncDefaultTotalPaid() {
    if (_totalPaidManuallyEdited) return;
    final total = widget.charged * _quantity;
    totalPaidController.text =
        total == total.roundToDouble() ? total.toStringAsFixed(0) : total.toStringAsFixed(2);
  }

  @override
  void dispose() {
    merchantNameController.dispose();
    merchantVpaController.dispose();
    addressController.dispose();
    descController.dispose();
    utrController.dispose();
    totalPaidController.dispose();
    super.dispose();
  }

  Future<void> _pickEvidenceForRole(String role) async {
    if (_evidenceItems.length >= _maxEvidenceItems) {
      _showSnack('Maximum of $_maxEvidenceItems evidence files allowed.');
      return;
    }

    final picker = ImagePicker();
    if (role == 'VIDEO_PROOF') {
      await showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (sheetCtx) => Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _sheetHandle(),
              const Text(
                'Add Purchase Video Proof',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              _sheetOption(
                icon: Icons.videocam_outlined,
                label: 'Record Video',
                onTap: () async {
                  Navigator.pop(sheetCtx);
                  final picked = await picker.pickVideo(
                    source: ImageSource.camera,
                    maxDuration: const Duration(minutes: 2),
                  );
                  if (picked != null) {
                    _addDraft(File(picked.path), isVideo: true, role: role);
                  }
                },
              ),
              const Divider(height: 1, indent: 60, color: Color(0xFFF0F0F0)),
              _sheetOption(
                icon: Icons.video_library_outlined,
                label: 'Choose Video from Gallery',
                onTap: () async {
                  Navigator.pop(sheetCtx);
                  final picked = await picker.pickVideo(
                    source: ImageSource.gallery,
                    maxDuration: const Duration(minutes: 2),
                  );
                  if (picked != null) {
                    _addDraft(File(picked.path), isVideo: true, role: role);
                  }
                },
              ),
              const SizedBox(height: 8),
              _sheetOption(
                icon: Icons.close_rounded,
                label: 'Cancel',
                onTap: () => Navigator.pop(sheetCtx),
                isCancel: true,
              ),
            ],
          ),
        ),
      );
      return;
    }

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _sheetHandle(),
            Text(
              'Add ${_roleLabel(role)}',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            _sheetOption(
              icon: Icons.camera_alt_outlined,
              label: 'Take a Photo',
              onTap: () async {
                Navigator.pop(sheetCtx);
                final picked = await picker.pickImage(
                  source: ImageSource.camera,
                  imageQuality: 85,
                );
                if (picked != null) {
                  _addDraft(File(picked.path), isVideo: false, role: role);
                }
              },
            ),
            const Divider(height: 1, indent: 60, color: Color(0xFFF0F0F0)),
            _sheetOption(
              icon: Icons.photo_library_outlined,
              label: 'Choose Image from Gallery',
              onTap: () async {
                Navigator.pop(sheetCtx);
                final picked = await picker.pickImage(
                  source: ImageSource.gallery,
                  imageQuality: 85,
                );
                if (picked != null) {
                  _addDraft(File(picked.path), isVideo: false, role: role);
                }
              },
            ),
            const SizedBox(height: 8),
            _sheetOption(
              icon: Icons.close_rounded,
              label: 'Cancel',
              onTap: () => Navigator.pop(sheetCtx),
              isCancel: true,
            ),
          ],
        ),
      ),
    );
  }

  void _addDraft(File file, {required bool isVideo, required String role}) {
    if (_evidenceItems.length >= _maxEvidenceItems) {
      _showSnack('Maximum of $_maxEvidenceItems evidence files allowed.');
      return;
    }
    setState(() {
      _evidenceItems.add(_EvidenceDraft(file: file, isVideo: isVideo, role: role));
    });
  }

  Widget _sheetHandle() => Container(
        width: 40,
        height: 4,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFDDDDDD),
          borderRadius: BorderRadius.circular(10),
        ),
      );

  Widget _sheetOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isCancel = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: isCancel ? const Color(0xFFF5F5F5) : const Color(0xFFE8F8F5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 18,
                color: isCancel ? const Color(0xFF9098A3) : const Color(0xFF2BAE9A),
              ),
            ),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isCancel ? const Color(0xFF9098A3) : const Color(0xFF1A1A2E),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> getLocationAndSet() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          _showSnack('Location permission was not granted. Enter the store address manually.');
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      latitude = position.latitude;
      longitude = position.longitude;
      final placemarks = await placemarkFromCoordinates(latitude!, longitude!);
      if (placemarks.isEmpty || !mounted) return;
      final place = placemarks.first;
      setState(() {
        addressController.text = [
          place.street,
          place.subLocality,
          place.locality,
          place.administrativeArea,
          place.postalCode,
          place.country,
        ].whereType<String>().where((part) => part.trim().isNotEmpty).join(', ');
      });
    } catch (_) {
      if (mounted) {
        _showSnack('Could not detect location. Please type the store address manually.');
      }
    }
  }

  void _showGuestActionSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.shield_outlined, color: Color(0xff2BAE9A), size: 28),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Sign In Required to File',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                'Sign in to submit your structured overcharge report, track verification status, and unlock official grievance dockets.',
                style: TextStyle(fontSize: 13, color: Colors.black54),
              ),
              const SizedBox(height: 18),
              ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                tileColor: const Color(0xffF1F5F9),
                leading: const Icon(Icons.phone_in_talk, color: Color(0xff1E293B)),
                title: const Text(
                  'Call Helpline (1915)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                subtitle: const Text(
                  'Dial National Consumer Helpline directly',
                  style: TextStyle(fontSize: 11),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  HelplineService.callTollFreeHelpline();
                },
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pushNamed(context, '/signin');
                  },
                  child: const Text('Sign In to Submit Officially'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSnack(String msg, {Color color = const Color(0xff1E293B)}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  String? _validateBeforeSubmit() {
    if (_isRestaurant) {
      return 'Formal MRP complaints do not apply to seated dine-in restaurants (SC FHRAI 2017).';
    }
    if (widget.charged <= widget.mrp) {
      return 'Price charged must exceed printed MRP to file an overcharge complaint.';
    }
    final merchantName = merchantNameController.text.trim();
    if (merchantName.length < 2) {
      return 'Please enter the shop or merchant name.';
    }
    final address = addressController.text.trim();
    if (address.length < 5) {
      return 'Please enter the complete shop address.';
    }
    final totalPaid = num.tryParse(totalPaidController.text.trim());
    final expectedMin = widget.charged * _quantity;
    if (totalPaid == null || totalPaid + 0.01 < expectedMin) {
      return 'Total paid must be at least ₹${expectedMin.toStringAsFixed(2)} (charged price × quantity).';
    }
    if (_paymentMethod == 'UPI') {
      final utr = utrController.text.trim().toUpperCase();
      if (!RegExp(r'^[A-Z0-9]{8,35}$').hasMatch(utr) ||
          RegExp(r'^(.)\1+$').hasMatch(utr)) {
        return 'Enter a valid 8–35 character UPI Transaction / UTR reference number.';
      }
      final vpa = merchantVpaController.text.trim().toLowerCase();
      if (vpa.isNotEmpty &&
          !RegExp(r'^[a-z0-9.\-_]{2,100}@[a-z0-9]{2,30}$').hasMatch(vpa)) {
        return 'Enter a valid Merchant UPI VPA (e.g. shop@okaxis) or leave it blank.';
      }
    } else if (_paymentMethod == 'CARD') {
      final utr = utrController.text.trim().toUpperCase();
      if (utr.isNotEmpty &&
          (!RegExp(r'^[A-Z0-9]{8,35}$').hasMatch(utr) ||
              RegExp(r'^(.)\1+$').hasMatch(utr))) {
        return 'Card transaction / RRN reference must be 8–35 alphanumeric characters if provided.';
      }
    }

    final hasPacketMrp = _evidenceItems.any((e) => e.role == 'PACKET_MRP');
    if (_paymentMethod != 'CASH' && !hasPacketMrp) {
      return 'Please attach a Packet MRP photo (or select Cash if filing a private unverified record).';
    }
    if (_evidenceItems.isNotEmpty && !hasPacketMrp) {
      return 'Please include a Packet MRP photo alongside your supporting proof.';
    }

    final now = DateTime.now();
    final earliestAllowed = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 30));
    if (selectedDate.isAfter(now.add(const Duration(minutes: 15)))) {
      return 'Purchase date cannot be in the future.';
    }
    if (selectedDate.isBefore(earliestAllowed)) {
      return 'Purchase date cannot be older than 30 days.';
    }
    return null;
  }

  Future<void> submitComplaint() async {
    final validationError = _validateBeforeSubmit();
    if (validationError != null) {
      _showSnack(validationError);
      return;
    }

    if (!AuthSession.isSignedIn) {
      _showGuestActionSheet();
      return;
    }

    try {
      setState(() => loading = true);

      final uploadedEvidence = <Map<String, dynamic>>[];
      for (final item in _evidenceItems) {
        final uploaded = await CloudinaryUploadService.uploadFile(
          file: item.file,
          isVideo: item.isVideo,
        );
        uploadedEvidence.add({
          'url': uploaded.secureUrl,
          'publicId': uploaded.publicId,
          'resourceType': uploaded.resourceType,
          'mediaType': item.isVideo ? 'VIDEO' : 'IMAGE',
          'role': item.role,
          'sha256Hash': uploaded.sha256Hash,
        });
      }

      if (!_api.isConfigured) {
        throw const PriceShieldApiException(
          'Service is temporarily unavailable. Please try again.',
        );
      }

      final totalPaid = num.parse(totalPaidController.text.trim());
      final utr = utrController.text.trim().toUpperCase();
      final vpa = merchantVpaController.text.trim().toLowerCase();

      await _api.createComplaint(
        venueType: widget.venueType.trim().toUpperCase(),
        barcode: widget.barcode,
        productName: widget.name,
        quantity: _quantity,
        mrp: widget.mrp,
        chargedPrice: widget.charged,
        totalPaid: totalPaid,
        paymentMethod: _paymentMethod,
        utrNumber: _paymentMethod == 'CASH' || utr.isEmpty ? null : utr,
        merchantName: merchantNameController.text.trim(),
        merchantVpa: _paymentMethod == 'UPI' && vpa.isNotEmpty ? vpa : null,
        address: addressController.text.trim(),
        latitude: latitude,
        longitude: longitude,
        description: descController.text.trim().isEmpty ? null : descController.text.trim(),
        purchaseDate: selectedDate,
        evidence: uploadedEvidence.isEmpty ? null : uploadedEvidence,
        clientRequestId: _submissionId,
      );

      if (!mounted) return;
      setState(() => loading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Complaint registered successfully!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainNavigation()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      final raw = e
          .toString()
          .replaceAll('Bad state: ', '')
          .replaceAll('Exception: ', '')
          .replaceAll('StateError: ', '')
          .trim();
      _showSnack(
        raw.isNotEmpty ? raw : 'Could not submit your complaint. Please try again.',
        color: const Color(0xffEF4444),
      );
    }
  }

  Widget _paymentChip(String code, String label, IconData icon) {
    final selected = _paymentMethod == code;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _paymentMethod = code),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? const Color(0xffE8F8F5) : const Color(0xffF8FAFC),
            border: Border.all(
              color: selected ? const Color(0xff2BAE9A) : const Color(0xffE2E8F0),
              width: selected ? 1.5 : 1.0,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 20,
                color: selected ? const Color(0xff2BAE9A) : const Color(0xff64748B),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  color: selected ? const Color(0xff2BAE9A) : const Color(0xff334155),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'PACKET_MRP':
        return 'Packet MRP Photo';
      case 'PAYMENT_PROOF':
        return 'Payment Proof';
      case 'ITEMIZED_BILL':
        return 'Itemized Bill / Receipt';
      case 'VIDEO_PROOF':
        return 'Purchase Video';
      default:
        return 'Other Proof';
    }
  }

  @override
  Widget build(BuildContext context) {
    final confidence = _predictedConfidence;

    return Scaffold(
      backgroundColor: const Color(0xffF7F8FC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xffF7F8FC),
        foregroundColor: Colors.black,
        leading: const BackButton(),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('File Complaint', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 2),
            Text(
              'Structured overcharge report',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (_isRestaurant) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xffFFFBEB),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xffF59E0B), width: 1.4),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.restaurant_rounded, color: Color(0xffB45309)),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Dine-In Restaurant Venue (SC FHRAI 2017): Formal MRP overcharge complaints are disabled for seated dine-in restaurants. If this was a retail store or counter takeaway, go back and choose Retail Shop.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xff78350F),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                children: [
                  _ComplaintStep(number: '1', label: 'Details', active: true),
                  _StepLine(),
                  _ComplaintStep(number: '2', label: 'Payment', active: true),
                  _StepLine(),
                  _ComplaintStep(number: '3', label: 'Evidence'),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // PRODUCT SUMMARY + QUANTITY + TOTAL PAID
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.name,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Barcode: ${widget.barcode}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _priceTile('Printed MRP (unit)', '₹${widget.mrp}', Colors.black87),
                      _priceTile('Charged (unit)', '₹${widget.charged}', Colors.red),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text(
                        'Quantity:',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: _quantity > 1
                            ? () {
                                setState(() {
                                  _quantity -= 1;
                                  _syncDefaultTotalPaid();
                                });
                              }
                            : null,
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      Text(
                        '$_quantity',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        onPressed: _quantity < 999
                            ? () {
                                setState(() {
                                  _quantity += 1;
                                  _syncDefaultTotalPaid();
                                });
                              }
                            : null,
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: totalPaidController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => _totalPaidManuallyEdited = true,
                    decoration: _inputDecoration(
                      'Total Paid / Basket Amount (₹)',
                      prefix: '₹ ',
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'If bought with other groceries, enter the total bill or UPI amount paid.',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Excess paid: ₹${totalOvercharge.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // PURCHASE DATE (bounded to last 30 days)
            _card(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle('Purchase Date'),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () async {
                      final now = DateTime.now();
                      final date = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(now.year, now.month, now.day)
                            .subtract(const Duration(days: 30)),
                        lastDate: now,
                      );
                      if (date != null) {
                        setState(() {
                          selectedDate = DateTime(
                            date.year,
                            date.month,
                            date.day,
                            selectedDate.hour,
                            selectedDate.minute,
                          );
                        });
                      }
                    },
                    child: _inputBox(
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(DateFormat('dd MMM yyyy').format(selectedDate)),
                          const Icon(Icons.calendar_month, color: Color(0xff57C7A7)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // STORE & ADDRESS
            _card(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle('Shop / Merchant Details'),
                  const SizedBox(height: 10),
                  TextField(
                    controller: merchantNameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: _inputDecoration('Shop / Merchant Name (Required)'),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xff57C7A7),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.my_location, color: Colors.white),
                    label: const Text(
                      'Fill Address from GPS (Optional)',
                      style: TextStyle(color: Colors.white),
                    ),
                    onPressed: getLocationAndSet,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: addressController,
                    maxLines: 2,
                    decoration: _inputDecoration('Shop Address (Required)'),
                  ),
                ],
              ),
            ),

            // PAYMENT METHOD & UTR
            _card(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle('Payment Method'),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _paymentChip('UPI', 'UPI / Online', Icons.qr_code_scanner_rounded),
                      const SizedBox(width: 8),
                      _paymentChip('CASH', 'Cash', Icons.payments_outlined),
                      const SizedBox(width: 8),
                      _paymentChip('CARD', 'Card', Icons.credit_card_outlined),
                    ],
                  ),
                  if (_paymentMethod == 'UPI') ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: utrController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: _inputDecoration('UPI Ref / UTR Number (Required)'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: merchantVpaController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: _inputDecoration(
                        'Merchant UPI ID / VPA (optional, e.g. shop@okaxis)',
                      ),
                    ),
                  ] else if (_paymentMethod == 'CARD') ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: utrController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: _inputDecoration('Card Transaction / RRN Ref (optional, 8+ chars)'),
                    ),
                  ] else ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xffFFFBEB),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xffFDE68A)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline, size: 16, color: Color(0xffB45309)),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Cash payments without packet MRP + bill proof are logged as UNVERIFIED private records only and cannot create public store flags or clean legal dockets.',
                              style: TextStyle(fontSize: 11, color: Color(0xff78350F)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // ROLE-TAGGED EVIDENCE + LIVE CONFIDENCE PREVIEW
            _card(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: _sectionTitle('Role-Tagged Evidence')),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: confidence == 'STRONG'
                              ? const Color(0xffDCFCE7)
                              : confidence == 'BASIC'
                                  ? const Color(0xffDBEAFE)
                                  : const Color(0xffFEF3C7),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Tier: $confidence',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: confidence == 'STRONG'
                                ? const Color(0xff166534)
                                : confidence == 'BASIC'
                                    ? const Color(0xff1E40AF)
                                    : const Color(0xff92400E),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    confidence == 'STRONG'
                        ? 'Strong confidence: Packet MRP + itemized bill or purchase video attached.'
                        : confidence == 'BASIC'
                            ? 'Basic confidence: Packet MRP + payment proof attached (watermarked pending verification).'
                            : 'Unverified private record: Attach Packet MRP + Payment Proof (Basic) or Itemized Bill/Video (Strong).',
                    style: const TextStyle(fontSize: 11, color: Color(0xff64748B)),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _evidenceRoleButton(
                        role: 'PACKET_MRP',
                        label: 'Packet MRP',
                        icon: Icons.camera_alt_outlined,
                      ),
                      _evidenceRoleButton(
                        role: 'PAYMENT_PROOF',
                        label: 'Payment Proof',
                        icon: Icons.receipt_outlined,
                      ),
                      _evidenceRoleButton(
                        role: 'ITEMIZED_BILL',
                        label: 'Itemized Bill',
                        icon: Icons.description_outlined,
                      ),
                      _evidenceRoleButton(
                        role: 'VIDEO_PROOF',
                        label: 'Purchase Video',
                        icon: Icons.videocam_outlined,
                      ),
                    ],
                  ),
                  if (_evidenceItems.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    ...List.generate(_evidenceItems.length, (index) {
                      final item = _evidenceItems[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xffF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xffE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              item.isVideo ? Icons.videocam_rounded : Icons.image_outlined,
                              color: const Color(0xff2BAE9A),
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _roleLabel(item.role),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    item.file.path.split(Platform.pathSeparator).last,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => setState(() => _evidenceItems.removeAt(index)),
                              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),

            // DESCRIPTION
            _card(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle('Additional Notes (Optional)'),
                  const SizedBox(height: 10),
                  TextField(
                    controller: descController,
                    maxLines: 3,
                    decoration: _inputDecoration('Describe what happened at the counter'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // SUBMIT BUTTON
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: (loading || _isRestaurant) ? null : submitComplaint,
                child: Ink(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _isRestaurant
                          ? [Colors.grey.shade400, Colors.grey.shade500]
                          : const [Color(0xff57C7A7), Color(0xff2BAE9A)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: loading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            _isRestaurant
                                ? 'Not Applicable for Dine-In'
                                : 'Submit Complaint →',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _evidenceRoleButton({
    required String role,
    required String label,
    required IconData icon,
  }) {
    final hasRole = _evidenceItems.any((e) => e.role == role);
    return ActionChip(
      avatar: Icon(
        hasRole ? Icons.check_circle : icon,
        size: 16,
        color: hasRole ? const Color(0xff166534) : const Color(0xff2BAE9A),
      ),
      label: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      backgroundColor: hasRole ? const Color(0xffDCFCE7) : const Color(0xffF8FAFC),
      side: BorderSide(
        color: hasRole ? const Color(0xff86EFAC) : const Color(0xffE2E8F0),
      ),
      onPressed: () => _pickEvidenceForRole(role),
    );
  }

  Widget _card(Widget child) => Container(
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: child,
      );

  Widget _sectionTitle(String t) => Text(
        t,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
      );

  Widget _priceTile(String t, String v, Color c) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 2),
          Text(v, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: c)),
        ],
      );

  Widget _inputBox(Widget child) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(14),
        ),
        child: child,
      );

  InputDecoration _inputDecoration(String hint, {String? prefix}) => InputDecoration(
        hintText: hint,
        prefixText: prefix,
        filled: true,
        fillColor: const Color(0xffF7F8FC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      );
}

class _ComplaintStep extends StatelessWidget {
  const _ComplaintStep({
    required this.number,
    required this.label,
    this.active = false,
  });

  final String number;
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: active ? const Color(0xff2BAE9A) : const Color(0xffE4E8EF),
              child: Text(
                number,
                style: TextStyle(
                  color: active ? Colors.white : const Color(0xff6B7280),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: active ? FontWeight.bold : FontWeight.normal,
                color: active ? const Color(0xff2BAE9A) : const Color(0xff6B7280),
              ),
            ),
          ],
        ),
      );
}

class _StepLine extends StatelessWidget {
  const _StepLine();

  @override
  Widget build(BuildContext context) =>
      const SizedBox(width: 18, child: Divider(color: Color(0xffD9DEE7)));
}
