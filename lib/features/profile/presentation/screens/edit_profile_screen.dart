import 'package:flutter/material.dart';
import 'package:priceshield/core/services/auth_session.dart';
import 'package:priceshield/core/services/priceshield_api_client.dart';
class EditProfileScreen extends StatefulWidget { const EditProfileScreen({super.key}); @override State<EditProfileScreen> createState() => _EditProfileScreenState(); }
class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _name = TextEditingController(text: AuthSession.currentUser.value?.displayName ?? '');
  late final TextEditingController _mobile = TextEditingController(text: AuthSession.currentUser.value?.mobile ?? ''); bool _saving = false;
  @override void dispose() { _name.dispose(); _mobile.dispose(); super.dispose(); }
  Future<void> _save() async { final changes = <String, dynamic>{}; if (_name.text.trim().isNotEmpty) changes['displayName'] = _name.text.trim(); if (_mobile.text.trim().isNotEmpty) changes['mobile'] = _mobile.text.trim(); if (changes.isEmpty) return; setState(() => _saving = true); try { final user = await priceShieldApi.updateProfile(changes); await AuthSession.updateUser(user); if (mounted) Navigator.pop(context); } on PriceShieldApiException catch (error) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message))); } finally { if (mounted) setState(() => _saving = false); } }
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Edit Profile')), body: Padding(padding: const EdgeInsets.all(20), child: Column(children: [TextField(controller: _name, decoration: const InputDecoration(labelText: 'Full name')), TextField(controller: _mobile, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Mobile number')), const SizedBox(height: 24), FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Saving...' : 'Save changes'))])));
}
