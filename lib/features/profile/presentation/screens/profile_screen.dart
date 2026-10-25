import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:priceshield/core/services/auth_service.dart';
import 'package:priceshield/core/services/auth_session.dart';
import 'package:priceshield/core/services/cloudinary_upload_service.dart';
import 'package:priceshield/core/services/priceshield_api_client.dart';
import 'package:priceshield/features/complaints/presentation/screens/complaints_screen.dart';
import 'package:priceshield/features/profile/presentation/screens/edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget { const ProfileScreen({super.key}); @override State<ProfileScreen> createState() => _ProfileScreenState(); }
class _ProfileScreenState extends State<ProfileScreen> {
  bool _loading = true, _uploading = false; int _total = 0, _resolved = 0; String? _photoUrl;
  @override void initState() { super.initState(); _refresh(); }
  Future<void> _refresh() async {
    if (!priceShieldApi.isConfigured) { if (mounted) setState(() => _loading = false); return; }
    try {
      final results = await Future.wait([priceShieldApi.getProfile(), priceShieldApi.listComplaints(limit: 100)]);
      final profile = results[0] as Map<String, dynamic>; final complaints = results[1] as List<Map<String, dynamic>>;
      await AuthSession.updateUser(profile);
      if (mounted) setState(() { _photoUrl = profile['photoUrl']?.toString(); _total = complaints.length; _resolved = complaints.where((item) => item['status'] == 'RESOLVED').length; _loading = false; });
    } on PriceShieldApiException catch (error) { if (error.isUnauthorized) await AuthSession.clear(); if (mounted) setState(() => _loading = false); }
  }
  Future<void> _uploadPhoto() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 75, maxWidth: 512); if (picked == null) return;
    setState(() => _uploading = true);
    try { final upload = await CloudinaryUploadService.uploadFile(file: File(picked.path), isVideo: false); final profile = await priceShieldApi.updateProfile({'photoUrl': upload.secureUrl}); await AuthSession.updateUser(profile); if (mounted) setState(() => _photoUrl = upload.secureUrl); }
    on PriceShieldApiException catch (error) { if (mounted) _message(error.message); }
    finally { if (mounted) setState(() => _uploading = false); }
  }
  void _message(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  @override Widget build(BuildContext context) {
    final user = AuthSession.currentUser.value; final name = user?.displayName.isNotEmpty == true ? user!.displayName : 'User';
    final initials = name.split(RegExp(r'\s+')).where((part) => part.isNotEmpty).take(2).map((part) => part[0]).join().toUpperCase();
    return Scaffold(backgroundColor: const Color(0xFFF4F6FA), appBar: AppBar(title: const Text('Profile'), backgroundColor: const Color(0xFF2BAE9A), foregroundColor: Colors.white), body: RefreshIndicator(onRefresh: _refresh, child: ListView(padding: const EdgeInsets.all(20), children: [
      Center(child: InkWell(onTap: _uploading ? null : _uploadPhoto, borderRadius: BorderRadius.circular(50), child: CircleAvatar(radius: 48, backgroundImage: (_photoUrl ?? user?.photoUrl) != null ? NetworkImage(_photoUrl ?? user!.photoUrl!) : null, child: _uploading ? const CircularProgressIndicator() : ((_photoUrl ?? user?.photoUrl) == null ? Text(initials, style: const TextStyle(fontSize: 26)) : null)))), const SizedBox(height: 12), Center(child: Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold))), Center(child: Text(user?.email ?? '')),
      const SizedBox(height: 24), Card(child: Padding(padding: const EdgeInsets.all(16), child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [_stat('Total', _total), _stat('Resolved', _resolved), _stat('Pending', _total - _resolved)]))), const SizedBox(height: 20),
      Card(child: Column(children: [ListTile(leading: const Icon(Icons.person_outline), title: const Text('Edit Profile'), onTap: () async { await Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen())); if (mounted) _refresh(); }), ListTile(leading: const Icon(Icons.history), title: const Text('Complaint History'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ComplaintsScreen())))])), const SizedBox(height: 20), OutlinedButton.icon(onPressed: _loading ? null : () async { await authService.logout(); }, icon: const Icon(Icons.logout), label: const Text('Logout')),
    ])));
  }
  Widget _stat(String label, int value) => Column(children: [Text('$value', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)), Text(label)]);
}
