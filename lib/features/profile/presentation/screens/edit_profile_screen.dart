import 'package:flutter/material.dart';
import 'package:priceshield/core/services/auth_session.dart';
import 'package:priceshield/core/services/priceshield_api_client.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});
  @override State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _name = TextEditingController(text: AuthSession.currentUser.value?.displayName ?? '');
  late final TextEditingController _mobile = TextEditingController(text: AuthSession.currentUser.value?.mobile ?? '');
  bool _saving = false;
  @override void dispose() { _name.dispose(); _mobile.dispose(); super.dispose(); }
  Future<void> _save() async {
    final changes = <String, dynamic>{};
    if (_name.text.trim().isNotEmpty) changes['displayName'] = _name.text.trim();
    if (_mobile.text.trim().isNotEmpty) changes['mobile'] = _mobile.text.trim();
    if (changes.isEmpty) return;
    setState(() => _saving = true);
    try { final user = await priceShieldApi.updateProfile(changes); await AuthSession.updateUser(user); if (mounted) Navigator.pop(context); }
    on PriceShieldApiException catch (error) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message))); }
    finally { if (mounted) setState(() => _saving = false); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xffF6F7F9),
    appBar: AppBar(title: const Text('Edit Profile'), backgroundColor: const Color(0xff57C7A7), foregroundColor: Colors.white),
    body: ListView(padding: const EdgeInsets.all(24), children: [
      const Text('Update your details', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8), const Text('Keep your PriceShield profile up to date.', style: TextStyle(color: Colors.black54)),
      const SizedBox(height: 28),
      _field(_name, 'Full name', Icons.person_outline), const SizedBox(height: 16), _field(_mobile, 'Mobile number', Icons.phone_outlined, type: TextInputType.phone),
      const SizedBox(height: 28),
      SizedBox(height: 52, child: ElevatedButton(onPressed: _saving ? null : _save, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xff0D1B2A), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))), child: _saving ? const CircularProgressIndicator(color: Colors.white) : const Text('Save changes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)))),
    ],),
  );
  Widget _field(TextEditingController controller, String label, IconData icon, {TextInputType? type}) => TextField(controller: controller, keyboardType: type, decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon), filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none)));
}
