import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _teal = Color(0xFF2BAE9A);
const _tealLight = Color(0xFFE8F8F5);
const _bg = Color(0xFFF4F6FA);
const _cardBg = Colors.white;
const _textDark = Color(0xFF1A1A2E);
const _textGrey = Color(0xFF9098A3);

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  User? get user => FirebaseAuth.instance.currentUser;

  String phoneNumber = "";
  int totalComplaints = 0;
  int resolved = 0;
  int pending = 0;

  bool _uploadingImage = false;
  String? _localImagePath; // locally saved image path

  @override
  void initState() {
    super.initState();
    fetchUserData();
    fetchStats();
    _loadLocalImage();
  }

  // Device se saved image path load karo
  Future<void> _loadLocalImage() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString('profile_image_${user?.uid}');
    if (!mounted) return;
    if (path != null && File(path).existsSync()) {
      setState(() => _localImagePath = path);
    }
  }

  Future<void> fetchUserData() async {
    if (user == null) return;
    final doc = await FirebaseFirestore.instance
        .collection("users")
        .doc(user!.uid)
        .get();
    if (!mounted) return;
    if (doc.exists) {
      setState(() {
        phoneNumber = doc.data()?['mobile'] ?? "";
      });
    }
  }

  Future<void> fetchStats() async {
    if (user == null) return;
    final snapshot = await FirebaseFirestore.instance
        .collection("complaints")
        .where("user_id", isEqualTo: user!.uid)
        .get();
    if (!mounted) return;
    setState(() {
      totalComplaints = snapshot.docs.length;
      resolved = snapshot.docs.where((d) => d['status'] == "resolved").length;
      pending = snapshot.docs.where((d) => d['status'] == "pending").length;
    });
  }

  // ── PROFILE IMAGE PICK & UPLOAD ──
  Future<void> _pickAndUploadImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _imageSourceSheet(),
    );
    if (source == null) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      imageQuality: 75,
      maxWidth: 512,
    );
    if (picked == null) return;

    setState(() => _uploadingImage = true);

    try {
      // Locally image path SharedPreferences mein save karo
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('profile_image_${user?.uid}', picked.path);

      if (mounted) {
        setState(() => _localImagePath = picked.path);
        _showSnack("Profile photo updated!");
      }
    } catch (e) {
      if (mounted) _showSnack("Failed to save image.", isError: true);
    } finally {
      if (mounted) setState(() => _uploadingImage = false);
    }
  }

  Widget _imageSourceSheet() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFDDDDDD),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const Text(
            "Change Profile Photo",
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w700, color: _textDark),
          ),
          const SizedBox(height: 12),
          _sheetOption(
            icon: Icons.photo_library_outlined,
            label: "Choose from Gallery",
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
          const Divider(height: 1, indent: 60, color: Color(0xFFF0F0F0)),
          _sheetOption(
            icon: Icons.camera_alt_outlined,
            label: "Take a Photo",
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
          const SizedBox(height: 8),
          _sheetOption(
            icon: Icons.close_rounded,
            label: "Cancel",
            onTap: () => Navigator.pop(context),
            isCancel: true,
          ),
        ],
      ),
    );
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
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: isCancel ? const Color(0xFFF5F5F5) : _tealLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 18, color: isCancel ? _textGrey : _teal),
            ),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isCancel ? _textGrey : _textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: isError ? Colors.redAccent : _teal,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  _buildStatsCard(),
                  const SizedBox(height: 24),
                  _sectionLabel("Account"),
                  const SizedBox(height: 10),
                  _buildCard([
                    _tile(Icons.person_outline_rounded, "Edit Profile",
                        onTap: () {}),
                    _tile(
                      Icons.phone_outlined,
                      phoneNumber.isEmpty ? "Add Phone Number" : phoneNumber,
                      subtitle: phoneNumber.isEmpty ? null : "Mobile",
                      onTap: () {},
                    ),
                  ]),
                  const SizedBox(height: 20),
                  _sectionLabel("Complaints"),
                  const SizedBox(height: 10),
                  _buildCard([
                    _tile(Icons.history_rounded, "Complaint History",
                        onTap: () {}),
                    _tile(Icons.track_changes_rounded, "Track Status",
                        onTap: () {}),
                  ]),
                  const SizedBox(height: 20),
                  _sectionLabel("More"),
                  const SizedBox(height: 10),
                  _buildCard([
                    _tile(Icons.help_outline_rounded, "Help & Support",
                        onTap: () {}),
                    _tile(Icons.privacy_tip_outlined, "Privacy Policy",
                        onTap: () {}),
                  ]),
                  const SizedBox(height: 28),
                  _buildLogoutButton(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 240,
      pinned: true,
      backgroundColor: _teal,
      elevation: 0,
      title: const Text(
        "Profile",
        style: TextStyle(
            color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          children: [
            Container(color: _teal),
            Positioned.fill(
              child: SafeArea(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 16),

                    // ── TAPPABLE AVATAR ──
                    GestureDetector(
                      onTap: _uploadingImage ? null : _pickAndUploadImage,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                            ),
                            child: CircleAvatar(
                              radius: 44,
                              backgroundColor: _tealLight,
                              backgroundImage: _localImagePath != null
                                  ? FileImage(File(_localImagePath!))
                                  : (user?.photoURL != null
                                  ? NetworkImage(user!.photoURL!)
                                  : null) as ImageProvider?,
                              child: _uploadingImage
                              // uploading indicator
                                  ? const SizedBox(
                                width: 26,
                                height: 26,
                                child: CircularProgressIndicator(
                                  color: _teal,
                                  strokeWidth: 2.5,
                                ),
                              )
                                  : (_localImagePath == null && user?.photoURL == null)
                                  ? Text(
                                _getInitials(),
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  color: _teal,
                                ),
                              )
                                  : null,
                            ),
                          ),

                          // Camera badge
                          if (!_uploadingImage)
                            Positioned(
                              bottom: 2,
                              right: 2,
                              child: Container(
                                width: 26,
                                height: 26,
                                decoration: BoxDecoration(
                                  color: _teal,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: Colors.white, width: 2),
                                ),
                                child: const Icon(
                                  Icons.camera_alt_rounded,
                                  size: 12,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),
                    Text(
                      user?.displayName ?? "User",
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user?.email ?? "",
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.75), fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCard() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          _statCell("Total", totalComplaints, _textDark),
          _verticalDivider(),
          _statCell("Resolved", resolved, _teal),
          _verticalDivider(),
          _statCell("Pending", pending, const Color(0xFFFF8C42)),
        ],
      ),
    );
  }

  Widget _statCell(String label, int value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(value.toString(),
              style: TextStyle(
                  fontSize: 24, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(
                  color: _textGrey, fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _verticalDivider() =>
      Container(width: 1, height: 36, color: const Color(0xFFEEEEEE));

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(label,
          style: const TextStyle(
              color: _textGrey,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8)),
    );
  }

  Widget _buildCard(List<Widget> tiles) {
    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 16,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        children: List.generate(tiles.length, (i) {
          return Column(
            children: [
              tiles[i],
              if (i < tiles.length - 1)
                const Divider(height: 1, indent: 64, color: Color(0xFFF0F0F0)),
            ],
          );
        }),
      ),
    );
  }

  Widget _tile(IconData icon, String label,
      {String? subtitle, required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        splashColor: _teal.withOpacity(0.06),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                    color: _tealLight,
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, size: 18, color: _teal),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: subtitle != null
                    ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(subtitle,
                        style: const TextStyle(
                            fontSize: 11, color: _textGrey)),
                    const SizedBox(height: 2),
                    Text(label,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: _textDark)),
                  ],
                )
                    : Text(label,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: _textDark)),
              ),
              const Icon(Icons.arrow_forward_ios_rounded,
                  size: 13, color: _textGrey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Colors.red.withOpacity(0.35)),
          backgroundColor: Colors.red.withOpacity(0.05),
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        icon: const Icon(Icons.logout_rounded,
            color: Colors.redAccent, size: 18),
        label: const Text("Log Out",
            style: TextStyle(
                color: Colors.redAccent,
                fontSize: 15,
                fontWeight: FontWeight.w600)),
        onPressed: () async {
          await FirebaseAuth.instance.signOut();
        },
      ),
    );
  }

  String _getInitials() {
    final name = (user?.displayName ?? user?.email ?? "").trim();
    if (name.isEmpty) return "?";
    final parts = name.split(" ").where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) {
      return "${parts[0][0]}${parts[1][0]}".toUpperCase();
    }
    return name[0].toUpperCase();
  }
}

class _MenuItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isSubtitle;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isSubtitle = false,
  });
}