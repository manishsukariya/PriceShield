import 'package:flutter/material.dart';
import 'package:priceshield/core/services/auth_session.dart';
import 'package:priceshield/core/services/priceshield_api_client.dart';
import 'package:priceshield/core/theme/app_theme.dart';
import 'package:priceshield/core/widgets/app_ui.dart';

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
    if (changes.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter at least one detail to save.'))); return; }
    setState(() => _saving = true);
    try { final user = await priceShieldApi.updateProfile(changes); await AuthSession.updateUser(user); if (mounted) Navigator.pop(context); }
    on PriceShieldApiException catch (error) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message))); }
    finally { if (mounted) setState(() => _saving = false); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: PriceShieldColors.background,
        appBar: AppBar(title: const Text('Edit profile')),
        body: ListView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 32), children: [
          AppCard(color: PriceShieldColors.navy, child: Row(children: [Container(width: 52, height: 52, decoration: BoxDecoration(color: PriceShieldColors.primary, borderRadius: BorderRadius.circular(17)), child: const Icon(Icons.person_outline_rounded, color: Colors.white, size: 28)), const SizedBox(width: 14), const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Your profile', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)), SizedBox(height: 4), Text('Keep your details up to date.', style: TextStyle(color: Color(0xffC9D5E6)))]))])),
          const SizedBox(height: 16),
          AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [_field(_name, 'Full name', Icons.person_outline_rounded), const SizedBox(height: 16), _field(_mobile, 'Mobile number', Icons.phone_outlined, type: TextInputType.phone), const SizedBox(height: 24), SizedBox(height: 52, child: ElevatedButton(onPressed: _saving ? null : _save, child: _saving ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Save changes')))]))
        ]),
      );
  Widget _field(TextEditingController controller, String label, IconData icon, {TextInputType? type}) => TextField(controller: controller, keyboardType: type, textInputAction: TextInputAction.next, decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)));
}
