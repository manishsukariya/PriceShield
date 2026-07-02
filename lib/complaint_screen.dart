import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:priceshield/home_screen.dart';
import 'package:priceshield/main_navigation_bar.dart';
import 'package:video_player/video_player.dart';

import 'complaint_details_screen.dart';

class ComplaintScreen extends StatefulWidget {
  final String name;
  final String barcode;
  final int mrp;
  final int charged;

  const ComplaintScreen({
    super.key,
    required this.name,
    required this.barcode,
    required this.mrp,
    required this.charged,
  });

  @override
  State<ComplaintScreen> createState() => _ComplaintScreenState();
}

class _ComplaintScreenState extends State<ComplaintScreen> {
  final TextEditingController addressController = TextEditingController();
  final TextEditingController descController = TextEditingController();

  DateTime selectedDate = DateTime.now();

  File? mediaFile;         // selected image ya video
  bool isVideo = false;    // image hai ya video
  VideoPlayerController? _videoController;

  bool loading = false;

  double? latitude;
  double? longitude;

  int get extra => widget.charged - widget.mrp;

  @override
  void initState() {
    super.initState();
    _ensureUserLoggedIn();
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _ensureUserLoggedIn() async {
    if (FirebaseAuth.instance.currentUser == null) {
      await FirebaseAuth.instance.signInAnonymously();
    }
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
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) return;

    final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
    latitude = position.latitude;
    longitude = position.longitude;

    List<Placemark> placemarks =
    await placemarkFromCoordinates(latitude!, longitude!);
    Placemark place = placemarks.first;

    setState(() {
      addressController.text =
      "${place.street ?? ""}, "
          "${place.subLocality ?? ""}, "
          "${place.locality ?? ""}, "
          "${place.administrativeArea ?? ""}, "
          "${place.postalCode ?? ""}, "
          "${place.country ?? ""}";
    });
  }

  /// 📤 Submit
  Future<void> submitComplaint() async {
    try {
      setState(() => loading = true);
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        setState(() => loading = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("Please login first")));
        return;
      }

      final complaintData = {
        "user_id": user.uid,
        "user_email": user.email,
        "product_name": widget.name,
        "barcode": widget.barcode,
        "mrp": widget.mrp,
        "charged_price": widget.charged,
        "extra": extra,
        "address": addressController.text,
        "latitude": latitude,
        "longitude": longitude,
        "description": descController.text,
        "purchase_date": selectedDate,
        "status": "pending",
        "created_at": Timestamp.now(),
      };

      await FirebaseFirestore.instance
          .collection("complaints")
          .add(complaintData);

      setState(() => loading = false);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Complaint Submitted Successfully"),
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
      setState(() => loading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
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