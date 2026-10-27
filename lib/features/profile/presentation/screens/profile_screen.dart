import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:priceshield/core/services/auth_service.dart';
import 'package:priceshield/core/services/auth_session.dart';
import 'package:priceshield/core/services/cloudinary_upload_service.dart';
import 'package:priceshield/core/services/priceshield_api_client.dart';
import 'package:priceshield/features/complaints/presentation/screens/complaints_screen.dart';
import 'package:priceshield/features/profile/presentation/screens/edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _loading = true, _uploading = false;
  int _total = 0, _resolved = 0;
  String? _photoUrl;

  @override void initState() { super.initState(); _refresh(); }
  Future<void> _refresh() async {
    try {
      final results = await Future.wait([priceShieldApi.getProfile(), priceShieldApi.listComplaints(limit: 100)]);
      final profile = results[0] as Map<String, dynamic>;
      final complaints = results[1] as List<Map<String, dynamic>>;
      await AuthSession.updateUser(profile);
      if (mounted) setState(() { _photoUrl = profile['photoUrl']?.toString(); _total = complaints.length; _resolved = complaints.where((i) => i['status']?.toString().toUpperCase() == 'RESOLVED').length; _loading = false; });
    } on PriceShieldApiException catch (error) {
      if (error.isUnauthorized) await AuthSession.clear();
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _uploadPhoto() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 75, maxWidth: 512);
    if (picked == null) return;
    setState(() => _uploading = true);
    try {
      final upload = await CloudinaryUploadService.uploadFile(file: File(picked.path), isVideo: false);
      final profile = await priceShieldApi.updateProfile({'photoUrl': upload.secureUrl});
      await AuthSession.updateUser(profile);
      if (mounted) setState(() => _photoUrl = upload.secureUrl);
    } on PriceShieldApiException catch (error) { if (mounted) _message(error.message); }
    finally { if (mounted) setState(() => _uploading = false); }
  }

  void _message(String value) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));

  @override
  Widget build(BuildContext context) {
    final user = AuthSession.currentUser.value;
    final name = user?.displayName.isNotEmpty == true ? user!.displayName : 'User';
    final initials = name.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).take(2).map((p) => p[0]).join().toUpperCase();
    final image = _photoUrl ?? user?.photoUrl;
    return Scaffold(
      backgroundColor: const Color(0xffF6F7F9),
      appBar: AppBar(title: const Text('Profile'), backgroundColor: const Color(0xff57C7A7), foregroundColor: Colors.white, elevation: 0),
      body: RefreshIndicator(onRefresh: _refresh, child: ListView(padding: const EdgeInsets.fromLTRB(24, 28, 24, 110), children: [
        Center(child: InkWell(onTap: _uploading ? null : _uploadPhoto, borderRadius: BorderRadius.circular(60), child: CircleAvatar(radius: 54, backgroundColor: const Color(0xff57C7A7), backgroundImage: image == null ? null : NetworkImage(image), child: _uploading ? const CircularProgressIndicator(color: Colors.white) : image == null ? Text(initials, style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold)) : null))),
        const SizedBox(height: 14), Center(child: Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold))),
        const SizedBox(height: 4), Center(child: Text(user?.email ?? '', style: const TextStyle(color: Colors.black54))),
        const SizedBox(height: 24),
        Card(elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)), child: Padding(padding: const EdgeInsets.all(18), child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [_stat('Total', _total), _stat('Resolved', _resolved), _stat('Pending', _total - _resolved)]))),
        const SizedBox(height: 20),
        Card(elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)), child: Column(children: [ListTile(leading: const Icon(Icons.person_outline, color: Color(0xff2BAE9A)), title: const Text('Edit Profile'), trailing: const Icon(Icons.chevron_right), onTap: () async { await Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen())); if (mounted) _refresh(); }), const Divider(height: 1), ListTile(leading: const Icon(Icons.receipt_long_outlined, color: Color(0xff2BAE9A)), title: const Text('Complaint History'), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ComplaintsScreen())))])),
        const SizedBox(height: 20),
        OutlinedButton.icon(onPressed: _loading ? null : () async { await authService.logout(); }, icon: const Icon(Icons.logout), label: const Text('Logout'), style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), foregroundColor: Colors.red, side: const BorderSide(color: Colors.red))),
      ])),
    );
  }

  Widget _stat(String label, int value) => Column(children: [Text('$value', style: const TextStyle(fontSize: 23, fontWeight: FontWeight.bold, color: Color(0xff2BAE9A))), const SizedBox(height: 4), Text(label, style: const TextStyle(color: Colors.black54))]);
}
