import 'package:flutter/material.dart';
import 'package:priceshield/core/services/auth_session.dart';
import 'package:priceshield/core/services/priceshield_api_client.dart';
import 'package:priceshield/features/education/presentation/screens/education_screen.dart';
import 'package:priceshield/features/scanner/presentation/screens/scan_details_screen.dart';
import 'package:priceshield/features/scanner/presentation/screens/scanner_screen.dart';
import 'package:priceshield/core/widgets/app_ui.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<dynamic>> _content = _loadContent();
  Future<List<dynamic>> _loadContent() async => Future.wait([
    priceShieldApi.listScans(limit: 20), priceShieldApi.listComplaints(limit: 1),
  ]);
  Future<void> _refresh() async => setState(() => _content = _loadContent());
  void _openScanner() => Navigator.push(context, MaterialPageRoute(builder: (_) => const ScannerScreen())).then((_) => _refresh());

  @override
  Widget build(BuildContext context) {
    final name = AuthSession.currentUser.value?.displayName.trim() ?? '';
    return Scaffold(
      backgroundColor: const Color(0xffF6F7F9),
      appBar: AppBar(
        backgroundColor: const Color(0xffF6F7F9), elevation: 0,
        title: const Text('PriceShield', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 22)),
        actions: [Padding(padding: const EdgeInsets.only(right: 16), child: CircleAvatar(backgroundColor: const Color(0xff57C7A7), child: Text(name.isEmpty ? 'U' : name[0].toUpperCase(), style: const TextStyle(color: Colors.white))))],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<dynamic>>(
          future: _content,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator(color: Color(0xff57C7A7)));
            if (snapshot.hasError) return ListView(padding: const EdgeInsets.fromLTRB(20, 120, 20, 100), children: [InlineError(message: 'Could not load your dashboard.', onRetry: _refresh)]);
            final scans = List<Map<String, dynamic>>.from(snapshot.data![0] as List);
            final complaints = List<Map<String, dynamic>>.from(snapshot.data![1] as List);
            return ListView(
              padding: const EdgeInsets.fromLTRB(32, 8, 32, 110),
              children: [
                Text(name.isEmpty ? 'Welcome 👋' : 'Welcome, $name 👋', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                InkWell(onTap: _openScanner, borderRadius: BorderRadius.circular(20), child: Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: const Color(0xff57C7A7), borderRadius: BorderRadius.circular(20)), child: const Row(children: [_IconBox(icon: Icons.shield_outlined), SizedBox(width: 16), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Check Product Price', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)), SizedBox(height: 6), Text('Scan barcode to verify MRP instantly', style: TextStyle(color: Colors.white70, fontSize: 14))]))]))),
                const SizedBox(height: 16), _infoCard(), const SizedBox(height: 24),
                const Text('Your Latest Complaint', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), const SizedBox(height: 12),
                if (complaints.isEmpty) const Text('No complaints yet') else _complaintPreview(complaints.first),
                const SizedBox(height: 16), _achievement(scans), const SizedBox(height: 20), _learnCard(), const SizedBox(height: 24),
                const Text('Recent Scans', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), const SizedBox(height: 12),
                if (scans.isEmpty) _emptyScans() else ...scans.take(3).map(_scanTile),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _infoCard() => Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: const Color(0xfffff1dd), borderRadius: BorderRadius.circular(16)), child: const Row(children: [_IconBox(icon: Icons.lightbulb_outline, color: Colors.orange, background: Color(0x33ff9800), size: 40), SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Know Your Rights', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)), SizedBox(height: 4), Text('Charging above MRP is illegal under Indian consumer protection laws.', style: TextStyle(fontSize: 13, color: Colors.black54))]))]));

  Widget _achievement(List<Map<String, dynamic>> scans) => Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: const Color(0xffe3f6f1), borderRadius: BorderRadius.circular(16)), child: Row(children: [const _IconBox(icon: Icons.emoji_events_outlined, color: Colors.teal, background: Color(0x2233aa99), size: 40), const SizedBox(width: 12), Expanded(child: Text('You have checked ${scans.length} product${scans.length == 1 ? '' : 's'}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)))]));

  Widget _learnCard() => Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.info_outline), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('MRP includes all taxes. Shops cannot legally charge more.', style: TextStyle(fontSize: 14)), const SizedBox(height: 6), GestureDetector(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ConsumerEducationScreen())), child: const Text('Learn More →', style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold, decoration: TextDecoration.underline)))]))]));

  Widget _complaintPreview(Map<String, dynamic> item) => Card(elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), child: ListTile(title: Text(item['productName']?.toString() ?? 'Product'), subtitle: Text('Status: ${item['status'] ?? 'Pending'}'), trailing: Text('₹${item['overcharge'] ?? 0}')));

  Widget _scanTile(Map<String, dynamic> item) => Card(elevation: 0, margin: const EdgeInsets.only(bottom: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), child: ListTile(leading: const CircleAvatar(backgroundColor: Color(0xfff0f3f7), child: Icon(Icons.qr_code_scanner_outlined, color: Color(0xff9098a3))), title: Text(item['productName']?.toString() ?? 'Product', maxLines: 1, overflow: TextOverflow.ellipsis), subtitle: Text('MRP ₹${item['mrp'] ?? 0} · Paid ₹${item['chargedPrice'] ?? 0}'), trailing: Text(item['status'] == 'OVERCHARGED' ? 'Overcharged' : 'Within MRP', style: TextStyle(color: item['status'] == 'OVERCHARGED' ? Colors.red : Colors.teal, fontSize: 12, fontWeight: FontWeight.bold)), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ScanDetailsScreen(scanData: item)))));

  Widget _emptyScans() => Container(padding: const EdgeInsets.symmetric(vertical: 24), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)), child: const Column(children: [Icon(Icons.qr_code_scanner_rounded, size: 34, color: Color(0xffcdd1d9)), SizedBox(height: 10), Text('No scans yet', style: TextStyle(color: Color(0xff9098a3))), SizedBox(height: 4), Text('Scan a product to see it here', style: TextStyle(color: Color(0xffbfc4cd), fontSize: 12))]));
}

class _IconBox extends StatelessWidget {
  const _IconBox({required this.icon, this.color = Colors.white, this.background = const Color(0x33ffffff), this.size = 60});
  final IconData icon; final Color color; final Color background; final double size;
  @override Widget build(BuildContext context) => Container(width: size, height: size, decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(16)), child: Icon(icon, color: color, size: size * .52));
}
