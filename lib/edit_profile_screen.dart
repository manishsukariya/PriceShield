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

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final User? user = FirebaseAuth.instance.currentUser;

  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();

  late TextEditingController _nameController;
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isSaving = false;

  // ── LOCAL PHOTO ──
  String? _photoPath;

  bool get _nameChanged =>
      _nameController.text.trim() != (user?.displayName ?? "");

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: user?.displayName ?? "");
    _loadPhoto();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // ── LOAD saved photo path from SharedPreferences ──
  Future<void> _loadPhoto() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString("profile_photo_path");
    if (!mounted) return;
    setState(() => _photoPath = path);
  }

  // ── PICK photo from gallery ──
  Future<void> _pickPhoto() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
    );
    if (image == null) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("profile_photo_path", image.path);

    if (!mounted) return;
    setState(() => _photoPath = image.path);
    _showSnack("Profile photo updated!");
  }

  // ── REMOVE photo ──
  Future<void> _removePhoto() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove("profile_photo_path");

    if (!mounted) return;
    setState(() => _photoPath = null);
    _showSnack("Profile photo removed.");
  }

  // ── TAP avatar → show options if photo exists, else pick ──
  Future<void> _onAvatarTap() async {
    if (_photoPath != null) {
      await showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (_) => _photoOptionsSheet(),
      );
    } else {
      await _pickPhoto();
    }
  }

  // ── BOTTOM SHEET: Change / Remove ──
  Widget _photoOptionsSheet() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          // drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFDDDDDD),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            "Profile Photo",
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w700, color: _textDark),
          ),
          const SizedBox(height: 8),
          // ── Change ──
          ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _tealLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.photo_library_outlined,
                  color: _teal, size: 20),
            ),
            title: const Text("Change Photo",
                style:
                TextStyle(fontWeight: FontWeight.w600, color: _textDark)),
            subtitle: const Text("Choose from gallery",
                style: TextStyle(fontSize: 12, color: _textGrey)),
            onTap: () async {
              Navigator.pop(context);
              await _pickPhoto();
            },
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          // ── Remove ──
          ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.delete_outline_rounded,
                  color: Colors.redAccent, size: 20),
            ),
            title: const Text("Remove Photo",
                style: TextStyle(
                    fontWeight: FontWeight.w600, color: Colors.redAccent)),
            subtitle: const Text("Reset to initials avatar",
                style: TextStyle(fontSize: 12, color: _textGrey)),
            onTap: () async {
              Navigator.pop(context);
              await _removePhoto();
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ── RE-AUTHENTICATE ──
  Future<bool> _reauthenticate(String currentPassword) async {
    try {
      final credential = EmailAuthProvider.credential(
        email: user!.email!,
        password: currentPassword,
      );
      await user!.reauthenticateWithCredential(credential);
      return true;
    } on FirebaseAuthException catch (e) {
      _showSnack(
        e.code == 'wrong-password'
            ? "Current password is incorrect."
            : "Authentication failed. Please try again.",
        isError: true,
      );
      return false;
    }
  }

  // ── SAVE NAME ──
  Future<void> _saveName() async {
    final newName = _nameController.text.trim();
    if (newName.isEmpty) return;

    setState(() => _isSaving = true);
    try {
      await user!.updateDisplayName(newName);
      await FirebaseFirestore.instance
          .collection("users")
          .doc(user!.uid)
          .set({"name": newName}, SetOptions(merge: true));
      await user!.reload();
      _showSnack("Name updated successfully!");
    } catch (e) {
      _showSnack("Failed to update name.", isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── SAVE PASSWORD ──
  Future<void> _savePassword() async {
    final current = _currentPasswordController.text;
    final newPass = _newPasswordController.text;
    final confirm = _confirmPasswordController.text;

    if (current.isEmpty || newPass.isEmpty || confirm.isEmpty) {
      _showSnack("Please fill all password fields.", isError: true);
      return;
    }
    if (newPass != confirm) {
      _showSnack("New passwords do not match.", isError: true);
      return;
    }
    if (newPass.length < 6) {
      _showSnack("Password must be at least 6 characters.", isError: true);
      return;
    }

    setState(() => _isSaving = true);
    final ok = await _reauthenticate(current);
    if (!ok) {
      setState(() => _isSaving = false);
      return;
    }
    try {
      await user!.updatePassword(newPass);
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      _showSnack("Password updated successfully!");
    } on FirebaseAuthException catch (e) {
      _showSnack(e.message ?? "Failed to update password.", isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
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
      appBar: AppBar(
        backgroundColor: _teal,
        elevation: 0,
        title: const Text("Edit Profile",
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 18)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildAvatarSection(),
            const SizedBox(height: 28),
            _sectionLabel("Your Information"),
            const SizedBox(height: 10),
            _buildReadOnlyCard(),
            const SizedBox(height: 28),
            _sectionLabel("Change Name"),
            const SizedBox(height: 10),
            _buildNameCard(),
            const SizedBox(height: 28),
            _sectionLabel("Change Password"),
            const SizedBox(height: 10),
            _buildPasswordCard(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ── AVATAR SECTION ──
  Widget _buildAvatarSection() {
    return Center(
      child: Column(
        children: [
          GestureDetector(
            onTap: _onAvatarTap,
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                // Teal ring
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: _teal,
                  ),
                  child: CircleAvatar(
                    radius: 52,
                    backgroundColor: _tealLight,
                    // Priority: local file > Firebase photoURL > initials
                    backgroundImage: _photoPath != null
                        ? FileImage(File(_photoPath!))
                        : (user?.photoURL != null
                        ? NetworkImage(user!.photoURL!) as ImageProvider
                        : null),
                    child: (_photoPath == null && user?.photoURL == null)
                        ? Text(
                      _getInitials(),
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: _teal,
                      ),
                    )
                        : null,
                  ),
                ),

                // Camera / edit badge
                Positioned(
                  bottom: 2,
                  right: 2,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      // Red badge if photo exists (signals "editable/removable")
                      color: _photoPath != null ? Colors.redAccent : _teal,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2.5),
                    ),
                    child: Icon(
                      _photoPath != null
                          ? Icons.edit_outlined
                          : Icons.camera_alt_outlined,
                      color: Colors.white,
                      size: 15,
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
                fontSize: 18, fontWeight: FontWeight.w700, color: _textDark),
          ),
          const SizedBox(height: 4),
          Text(
            _photoPath != null
                ? "Tap to change or remove photo"
                : "Tap avatar to add a profile photo",
            style: const TextStyle(fontSize: 12, color: _textGrey),
          ),
        ],
      ),
    );
  }

  // ── READ ONLY CARD ──
  Widget _buildReadOnlyCard() {
    return _card(
      child: Column(
        children: [
          _readOnlyTile(
              Icons.email_outlined, "Email Address", user?.email ?? "—"),
          const Divider(height: 1, indent: 60, color: Color(0xFFF0F0F0)),
          _readOnlyTile(
              Icons.phone_outlined, "Mobile Number", "Not editable here"),
        ],
      ),
    );
  }

  Widget _readOnlyTile(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 18, color: _textGrey),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style:
                    const TextStyle(fontSize: 11, color: _textGrey)),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: _textGrey)),
              ],
            ),
          ),
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F0F0),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text("View only",
                style: TextStyle(fontSize: 10, color: _textGrey)),
          ),
        ],
      ),
    );
  }

  // ── NAME CARD ──
  Widget _buildNameCard() {
    return _card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _inputField(
              controller: _nameController,
              label: "Full Name",
              icon: Icons.person_outline_rounded,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? "Name cannot be empty"
                  : null,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            _actionButton(
                "Save Name", _isSaving || !_nameChanged ? null : _saveName),
          ],
        ),
      ),
    );
  }

  // ── PASSWORD CARD ──
  Widget _buildPasswordCard() {
    return _card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _inputField(
              controller: _currentPasswordController,
              label: "Current Password",
              icon: Icons.lock_outline_rounded,
              obscure: _obscureCurrent,
              toggleObscure: () =>
                  setState(() => _obscureCurrent = !_obscureCurrent),
            ),
            const SizedBox(height: 14),
            _inputField(
              controller: _newPasswordController,
              label: "New Password",
              icon: Icons.lock_reset_rounded,
              obscure: _obscureNew,
              toggleObscure: () => setState(() => _obscureNew = !_obscureNew),
              validator: (v) => (v != null && v.isNotEmpty && v.length < 6)
                  ? "Min 6 characters"
                  : null,
            ),
            const SizedBox(height: 14),
            _inputField(
              controller: _confirmPasswordController,
              label: "Confirm New Password",
              icon: Icons.check_circle_outline_rounded,
              obscure: _obscureConfirm,
              toggleObscure: () =>
                  setState(() => _obscureConfirm = !_obscureConfirm),
              validator: (v) =>
              (v != _newPasswordController.text && v!.isNotEmpty)
                  ? "Passwords do not match"
                  : null,
            ),
            const SizedBox(height: 16),
            _actionButton(
                "Update Password", _isSaving ? null : _savePassword),
          ],
        ),
      ),
    );
  }

  // ── HELPERS ──

  Widget _actionButton(String label, VoidCallback? onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: _teal,
          disabledBackgroundColor: _teal.withOpacity(0.4),
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        child: _isSaving
            ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
                color: Colors.white, strokeWidth: 2))
            : Text(label,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 15)),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
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
      child: child,
    );
  }

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        label,
        style: const TextStyle(
          color: _textGrey,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscure = false,
    VoidCallback? toggleObscure,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      validator: validator,
      onChanged: onChanged,
      style: const TextStyle(
          fontSize: 14, fontWeight: FontWeight.w500, color: _textDark),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: _textGrey, fontSize: 13),
        prefixIcon: Padding(
          padding: const EdgeInsets.all(10),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _tealLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: _teal),
          ),
        ),
        suffixIcon: toggleObscure != null
            ? IconButton(
          onPressed: toggleObscure,
          icon: Icon(
            obscure
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            color: _textGrey,
            size: 18,
          ),
        )
            : null,
        filled: true,
        fillColor: const Color(0xFFF8F9FB),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFEEEEEE)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFEEEEEE)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _teal, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1),
        ),
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  String _getInitials() {
    final name = (user?.displayName ?? user?.email ?? "").trim();
    if (name.isEmpty) return "?";
    final parts = name.split(" ").where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) return "${parts[0][0]}${parts[1][0]}".toUpperCase();
    return name[0].toUpperCase();
  }
}