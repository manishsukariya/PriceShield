import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:priceshield/core/services/auth_session.dart';
import 'package:priceshield/core/services/cloudinary_upload_service.dart';
import 'package:priceshield/core/services/priceshield_api_client.dart';
import 'package:priceshield/app/navigation/main_navigation.dart';
import 'package:priceshield/features/complaints/services/escalation_pack_service.dart';
import 'package:priceshield/features/deescalation/services/helpline_service.dart';
import 'package:video_player/video_player.dart';

class ComplaintScreen extends StatefulWidget {
  final String name;
  final String barcode;
  final num mrp;
  final num charged;
  final String? initialNotes;

  const ComplaintScreen({
    super.key,
    required this.name,
    required this.barcode,
    required this.mrp,
    required this.charged,
    this.initialNotes,
  });

  @override
  State<ComplaintScreen> createState() => _ComplaintScreenState();
}

class _ComplaintScreenState extends State<ComplaintScreen> {
  final String _submissionId = 'complaint-${DateTime.now().microsecondsSinceEpoch}';
  final TextEditingController addressController = TextEditingController();
  final TextEditingController descController = TextEditingController();
  final TextEditingController utrController = TextEditingController();
  String _paymentMethod = 'UPI / Online';

  DateTime selectedDate = DateTime.now();

  File? mediaFile;         // selected image ya video
  bool isVideo = false;    // image hai ya video
  VideoPlayerController? _videoController;

  bool loading = false;

  double? latitude;
  double? longitude;

  num get extra => widget.charged - widget.mrp;

  @override
  void initState() {
    super.initState();
    if (widget.initialNotes != null && widget.initialNotes!.isNotEmpty) {
      descController.text = widget.initialNotes!;
    }
  }

  @override
  void dispose() {
    addressController.dispose();
    descController.dispose();
    utrController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  // ── MEDIA PICKER: bottom sheet with 3 options ──
  Future<void> pickMedia() async {
    final picker = ImagePicker();

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // drag handle
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFDDDDDD),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const Text(
              "Add Proof",
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),

            // Camera
            _sheetOption(
              icon: Icons.camera_alt_outlined,
              label: "Take a Photo",
              onTap: () async {
                Navigator.pop(context);
                final picked = await picker.pickImage(
                  source: ImageSource.camera,
                  imageQuality: 80,
                );
                if (picked != null) _setImage(File(picked.path));
              },
            ),

            const Divider(height: 1, indent: 60, color: Color(0xFFF0F0F0)),

            // Gallery - Image
            _sheetOption(
              icon: Icons.photo_library_outlined,
              label: "Choose Image from Gallery",
              onTap: () async {
                Navigator.pop(context);
                final picked = await picker.pickImage(
                  source: ImageSource.gallery,
                  imageQuality: 80,
                );
                if (picked != null) _setImage(File(picked.path));
              },
            ),

            const Divider(height: 1, indent: 60, color: Color(0xFFF0F0F0)),

            // Gallery - Video
            _sheetOption(
              icon: Icons.videocam_outlined,
              label: "Choose Video from Gallery",
              onTap: () async {
                Navigator.pop(context);
                final picked = await picker.pickVideo(
                  source: ImageSource.gallery,
                  maxDuration: const Duration(minutes: 2),
                );
                if (picked != null) _setVideo(File(picked.path));
              },
            ),

            const SizedBox(height: 8),

            // Cancel
            _sheetOption(
              icon: Icons.close_rounded,
              label: "Cancel",
              onTap: () => Navigator.pop(context),
              isCancel: true,
            ),
          ],
        ),
      ),
    );
  }

  void _setImage(File file) {
    _videoController?.dispose();
    _videoController = null;
    setState(() {
      mediaFile = file;
      isVideo = false;
    });
  }

  void _setVideo(File file) async {
    _videoController?.dispose();
    _videoController = VideoPlayerController.file(file);
    await _videoController!.initialize();
    setState(() {
      mediaFile = file;
      isVideo = true;
    });
  }

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
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: isCancel
                    ? const Color(0xFFF5F5F5)
                    : const Color(0xFFE8F8F5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 18,
                  color: isCancel
                      ? const Color(0xFF9098A3)
                      : const Color(0xFF2BAE9A)),
            ),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isCancel
                    ? const Color(0xFF9098A3)
                    : const Color(0xFF1A1A2E),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 📍 Get Location
  Future<void> getLocationAndSet() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Location permission was not granted. Enter the store address manually.'),
          ));
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      latitude = position.latitude;
      longitude = position.longitude;
      final placemarks = await placemarkFromCoordinates(latitude!, longitude!);
      if (placemarks.isEmpty) return;
      final place = placemarks.first;
      if (!mounted) return;
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not detect location. Please type the store address manually.'),
          backgroundColor: Color(0xff1E293B),
        ));
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
              Row(
                children: const [
                  Icon(Icons.shield_outlined, color: Color(0xff2BAE9A), size: 28),
                  SizedBox(width: 10),
                  Text(
                    'Guest Mode Action',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                'To file an official complaint in your profile, sign in. Or resolve instantly as a guest using our legal escalation tools:',
                style: TextStyle(fontSize: 13, color: Colors.black54),
              ),
              const SizedBox(height: 18),
              ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                tileColor: const Color(0xffE8F8F5),
                leading: const Icon(Icons.share, color: Color(0xff2BAE9A)),
                title: const Text('Send WhatsApp Notice to Shopkeeper', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('Pre-drafted legal notice with Rule 18(2) citation', style: TextStyle(fontSize: 11)),
                onTap: () {
                  Navigator.pop(ctx);
                  final notice = EscalationPackService.generateWhatsAppNotice(
                    productName: widget.name,
                    barcode: widget.barcode,
                    mrp: widget.mrp,
                    chargedPrice: widget.charged,
                    storeAddress: addressController.text.trim(),
                  );
                  Clipboard.setData(ClipboardData(text: notice));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('WhatsApp Legal Notice copied to clipboard! Paste it to the merchant.'),
                      backgroundColor: Color(0xff2BAE9A),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
              ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                tileColor: const Color(0xffF1F5F9),
                leading: const Icon(Icons.phone_in_talk, color: Color(0xff1E293B)),
                title: const Text('Call Helpline (1915)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('Dial National Consumer Helpline directly', style: TextStyle(fontSize: 11)),
                onTap: () {
                  Navigator.pop(ctx);
                  HelplineService.callTollFreeHelpline();
                },
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
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

  Widget _paymentChip(String label, IconData icon) {
    final selected = _paymentMethod == label;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _paymentMethod = label),
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

  /// 📤 Submit
  Future<void> submitComplaint() async {
    if (addressController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please enter the store address before submitting.'),
        backgroundColor: Color(0xff1E293B),
      ));
      return;
    }

    if (!AuthSession.isSignedIn) {
      _showGuestActionSheet();
      return;
    }

    try {
      setState(() => loading = true);
      final evidence = mediaFile == null
          ? null
          : await CloudinaryUploadService.uploadFile(
              file: mediaFile!,
              isVideo: isVideo,
            );

      if (!priceShieldApi.isConfigured) {
        throw const PriceShieldApiException('Service is temporarily unavailable. Please try again.');
      }

      final paymentNote = 'Payment Method: $_paymentMethod' +
          (utrController.text.trim().isNotEmpty ? ' (Ref: ${utrController.text.trim()})' : '');
      final fullDesc = descController.text.trim().isEmpty
          ? paymentNote
          : '$paymentNote\n\n${descController.text.trim()}';

      await priceShieldApi.createComplaint(
            barcode: widget.barcode,
            productName: widget.name,
            mrp: widget.mrp,
            chargedPrice: widget.charged,
            address: addressController.text.trim(),
            latitude: latitude,
            longitude: longitude,
            description: fullDesc,
            purchaseDate: selectedDate,
            evidence: evidence == null
                ? null
                : [
                    {
                      'url': evidence.secureUrl,
                      'publicId': evidence.publicId,
                      'resourceType': evidence.resourceType,
                      'mediaType': isVideo ? 'video' : 'image',
                    },
                  ],
            clientRequestId: _submissionId,
          );

      setState(() => loading = false);
      if (!mounted) return;

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
      final raw = e.toString()
          .replaceAll('Bad state: ', '')
          .replaceAll('Exception: ', '')
          .replaceAll('StateError: ', '')
          .trim();
      final friendlyMsg = raw.isNotEmpty
          ? raw
          : 'Could not submit your complaint. Please try again.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(friendlyMsg),
          backgroundColor: const Color(0xffEF4444),
          action: SnackBarAction(
            label: 'Copy Notice',
            textColor: Colors.white,
            onPressed: () {
              final notice = EscalationPackService.generateWhatsAppNotice(
                productName: widget.name,
                barcode: widget.barcode,
                mrp: widget.mrp,
                chargedPrice: widget.charged,
                storeAddress: addressController.text.trim(),
              );
              Clipboard.setData(ClipboardData(text: notice));
            },
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF7F8FC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xffF7F8FC),
        foregroundColor: Colors.black,
        leading: const BackButton(),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text("File Complaint",
                style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 2),
            Text("Report product overcharging",
                style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
              child: const Row(children: [
                _ComplaintStep(number: '1', label: 'Details', active: true),
                _StepLine(),
                _ComplaintStep(number: '2', label: 'Evidence'),
                _StepLine(),
                _ComplaintStep(number: '3', label: 'Review'),
              ]),
            ),
            const SizedBox(height: 14),

            /// PRODUCT SUMMARY
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.name,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text("Barcode: ${widget.barcode}",
                      style:
                      const TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _priceTile("Legal MRP", "₹${widget.mrp}", Colors.black87),
                      _priceTile("Charged", "₹${widget.charged}", Colors.red),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      "You paid ₹$extra extra",
                      style: const TextStyle(
                          color: Colors.red, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            /// PURCHASE DATE
            _card(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle("Purchase Date"),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2023),
                        lastDate: DateTime.now(),
                      );
                      if (date != null) setState(() => selectedDate = date);
                    },
                    child: _inputBox(
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(DateFormat("dd MMM yyyy").format(selectedDate)),
                          const Icon(Icons.calendar_month,
                              color: Color(0xff57C7A7)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            /// ADDRESS
            _card(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle("Shop Address"),
                  const SizedBox(height: 6),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xff57C7A7),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.my_location, color: Colors.white),
                    label: const Text("Use Current Location",
                        style: TextStyle(color: Colors.white)),
                    onPressed: getLocationAndSet,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: addressController,
                    decoration: _inputDecoration("Enter address manually"),
                  ),
                ],
              ),
            ),

            /// DESCRIPTION
            _card(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle("Describe Issue & provide store details"),
                  const SizedBox(height: 10),
                  TextField(
                    controller: descController,
                    maxLines: 4,
                    decoration: _inputDecoration("Write details here"),
                  ),
                ],
              ),
            ),

            /// PAYMENT METHOD & PROOF
            _card(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle("Payment Method (Proof of Price Charged)"),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _paymentChip('UPI / Online', Icons.qr_code_scanner_rounded),
                      const SizedBox(width: 8),
                      _paymentChip('Cash', Icons.payments_outlined),
                      const SizedBox(width: 8),
                      _paymentChip('Card', Icons.credit_card_outlined),
                    ],
                  ),
                  if (_paymentMethod == 'UPI / Online') ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: utrController,
                      decoration: _inputDecoration("UPI Ref / UTR No. (optional)"),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xffEFF6FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.info_outline, size: 16, color: Color(0xff2563EB)),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Tip: Upload a screenshot of your UPI payment below for verified price proof.',
                              style: TextStyle(fontSize: 11, color: Color(0xff1E40AF)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            /// PROOF (IMAGE / VIDEO)
            _card(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _sectionTitle("Add Proof"),
                      if (mediaFile != null)
                        GestureDetector(
                          onTap: () {
                            _videoController?.dispose();
                            _videoController = null;
                            setState(() {
                              mediaFile = null;
                              isVideo = false;
                            });
                          },
                          child: const Text(
                            "Remove",
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.red,
                                fontWeight: FontWeight.w500),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: pickMedia,
                    child: Container(
                      height: 150,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: mediaFile != null
                              ? const Color(0xff57C7A7)
                              : Colors.grey.shade300,
                          width: mediaFile != null ? 1.5 : 1,
                        ),
                        color: const Color(0xffF7F8FC),
                      ),
                      child: mediaFile == null
                      // ── Empty state ──
                          ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.add_photo_alternate_outlined,
                              size: 36, color: Color(0xff57C7A7)),
                          SizedBox(height: 8),
                          Text("Tap to add photo or video",
                              style: TextStyle(
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w500)),
                          SizedBox(height: 4),
                          Text("Camera · Gallery · Video",
                              style: TextStyle(
                                  color: Color(0xFFBFC4CD),
                                  fontSize: 12)),
                        ],
                      )
                          : isVideo
                      // ── Video preview ──
                          ? Stack(
                        alignment: Alignment.center,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(15),
                            child: _videoController != null &&
                                _videoController!
                                    .value.isInitialized
                                ? AspectRatio(
                              aspectRatio: _videoController!
                                  .value.aspectRatio,
                              child: VideoPlayer(
                                  _videoController!),
                            )
                                : Container(
                                color: Colors.black12),
                          ),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.black45,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                                Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 28),
                          ),
                          Positioned(
                            bottom: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius:
                                BorderRadius.circular(8),
                              ),
                              child: const Text("VIDEO",
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      )
                      // ── Image preview ──
                          : ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: Image.file(
                          mediaFile!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            /// SUBMIT BUTTON
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: loading ? null : submitComplaint,
                child: Ink(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xff57C7A7), Color(0xff2BAE9A)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: loading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                      "Submit Complaint →",
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
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

  Widget _card(Widget child) => Container(
    margin: const EdgeInsets.only(bottom: 24),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
    ),
    child: child,
  );

  Widget _sectionTitle(String t) => Text(
    t,
    style:
    const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
  );

  Widget _priceTile(String t, String v, Color c) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(t, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      const SizedBox(height: 2),
      Text(v,
          style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.bold, color: c)),
    ],
  );

  Widget _inputBox(Widget child) => Container(
    padding:
    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    decoration: BoxDecoration(
      border: Border.all(color: Colors.grey.shade300),
      borderRadius: BorderRadius.circular(14),
    ),
    child: child,
  );

  InputDecoration _inputDecoration(String hint) => InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: const Color(0xffF7F8FC),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    ),
  );
}

class _ComplaintStep extends StatelessWidget {
  const _ComplaintStep({required this.number, required this.label, this.active = false});
  final String number;
  final String label;
  final bool active;
  @override
  Widget build(BuildContext context) => Expanded(child: Column(children: [CircleAvatar(radius: 14, backgroundColor: active ? const Color(0xff2BAE9A) : const Color(0xffE4E8EF), child: Text(number, style: TextStyle(color: active ? Colors.white : const Color(0xff6B7280), fontSize: 12, fontWeight: FontWeight.bold))), const SizedBox(height: 5), Text(label, style: TextStyle(fontSize: 11, fontWeight: active ? FontWeight.bold : FontWeight.normal, color: active ? const Color(0xff2BAE9A) : const Color(0xff6B7280)))]));
}

class _StepLine extends StatelessWidget {
  const _StepLine();
  @override
  Widget build(BuildContext context) => const SizedBox(width: 18, child: Divider(color: Color(0xffD9DEE7)));
}
