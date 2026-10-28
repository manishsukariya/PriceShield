import 'package:flutter/material.dart';
import 'package:priceshield/core/services/auth_session.dart';
import 'package:priceshield/core/services/priceshield_api_client.dart';
import 'package:priceshield/core/theme/app_theme.dart';
import 'package:priceshield/core/widgets/app_ui.dart';
import 'package:priceshield/features/education/presentation/screens/education_screen.dart';
import 'package:priceshield/features/scanner/presentation/screens/scan_details_screen.dart';
import 'package:priceshield/features/scanner/presentation/screens/scanner_screen.dart';

class HomeScreen extends StatefulWidget { const HomeScreen({super.key}); @override State<HomeScreen> createState() => _HomeScreenState(); }

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<dynamic>> _content = _loadContent();
  Future<List<dynamic>> _loadContent() => Future.wait([priceShieldApi.listScans(limit: 20), priceShieldApi.listComplaints(limit: 1)]);
  Future<void> _refresh() async => setState(() => _content = _loadContent());
  void _openScanner() => Navigator.push(context, MaterialPageRoute(builder: (_) => const ScannerScreen())).then((_) => _refresh());

  @override Widget build(BuildContext context) {
    final name = AuthSession.currentUser.value?.displayName.trim() ?? '';
    final firstName = name.isEmpty ? 'there' : name.split(RegExp(r'\s+')).first;
    return Scaffold(
      backgroundColor: PriceShieldColors.background,
      appBar: AppBar(titleSpacing: 20, title: const Text('PriceShield'), actions: [Padding(padding: const EdgeInsets.only(right: 20), child: CircleAvatar(backgroundColor: PriceShieldColors.primary, child: Text(name.isEmpty ? 'U' : name[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))))]),
      body: RefreshIndicator(color: PriceShieldColors.primary, onRefresh: _refresh, child: FutureBuilder<List<dynamic>>(future: _content, builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) return const _DashboardSkeleton();
        if (snapshot.hasError) return ListView(padding: const EdgeInsets.fromLTRB(20, 120, 20, 100), children: [InlineError(message: 'We could not load your dashboard.', onRetry: _refresh)]);
        final scans = List<Map<String, dynamic>>.from(snapshot.data![0] as List);
        final complaints = List<Map<String, dynamic>>.from(snapshot.data![1] as List);
        return ListView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 116), children: [
          Text('Hello, $firstName', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text('Stay informed. Pay the right price.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: PriceShieldColors.muted)),
          const SizedBox(height: 20), _scanHero(), const SizedBox(height: 16), _quickSummary(scans, complaints), const SizedBox(height: 24),
          Text('Latest activity', style: Theme.of(context).textTheme.titleLarge), const SizedBox(height: 10),
          if (scans.isEmpty) _emptyScans() else ...scans.take(3).map(_scanTile), const SizedBox(height: 24), _rightsCard(),
        ]);
      })),
    );
  }

  Widget _scanHero() => InkWell(onTap: _openScanner, borderRadius: BorderRadius.circular(22), child: Ink(padding: const EdgeInsets.all(22), decoration: BoxDecoration(color: PriceShieldColors.navy, borderRadius: BorderRadius.circular(22)), child: Row(children: [const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Check a product', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)), SizedBox(height: 8), Text('Scan the barcode to compare the printed MRP.', style: TextStyle(color: Color(0xffC9D5E6), height: 1.35)), SizedBox(height: 18), _ActionLabel()])), Container(width: 58, height: 58, decoration: BoxDecoration(color: PriceShieldColors.primary, borderRadius: BorderRadius.circular(18)), child: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 30))])));
  Widget _quickSummary(List<Map<String, dynamic>> scans, List<Map<String, dynamic>> complaints) => AppCard(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18), child: Row(children: [_metric('Scans', scans.length.toString(), Icons.qr_code_2_rounded), _divider(), _metric('Complaints', complaints.isEmpty ? '0' : complaints.length.toString(), Icons.receipt_long_outlined), _divider(), _metric('Status', complaints.isEmpty ? 'Clear' : 'Active', Icons.verified_outlined)]));
  Widget _metric(String label, String value, IconData icon) => Expanded(child: Column(children: [Icon(icon, color: PriceShieldColors.primary, size: 22), const SizedBox(height: 7), Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)), const SizedBox(height: 2), Text(label, style: const TextStyle(color: PriceShieldColors.muted, fontSize: 12))]));
  Widget _divider() => Container(width: 1, height: 42, color: PriceShieldColors.border);
  Widget _rightsCard() => AppCard(color: const Color(0xfffff7e8), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xffffe7b8), borderRadius: BorderRadius.circular(13)), child: const Icon(Icons.lightbulb_outline_rounded, color: PriceShieldColors.warning)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Know your rights', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)), const SizedBox(height: 5), const Text('MRP includes all taxes. A shop cannot legally charge more.', style: TextStyle(color: PriceShieldColors.muted, height: 1.35)), const SizedBox(height: 8), GestureDetector(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ConsumerEducationScreen())), child: const Text('Learn more', style: TextStyle(color: PriceShieldColors.navy, fontWeight: FontWeight.w800)))]))]));
  Widget _scanTile(Map<String, dynamic> item) {
    final overcharged = item['status']?.toString().toUpperCase() == 'OVERCHARGED';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        padding: EdgeInsets.zero,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          leading: const CircleAvatar(
            backgroundColor: PriceShieldColors.mint,
            child: Icon(Icons.qr_code_2_rounded, color: PriceShieldColors.primary),
          ),
          title: Text(
            item['productName']?.toString() ?? 'Product',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Text('MRP \u20B9${item['mrp'] ?? 0}  |  Paid \u20B9${item['chargedPrice'] ?? 0}'),
          trailing: StatusPill(
            label: overcharged ? 'Overcharged' : 'Within MRP',
            color: overcharged ? PriceShieldColors.danger : PriceShieldColors.success,
          ),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ScanDetailsScreen(scanData: item)),
          ),
        ),
      ),
    );
  }
  Widget _emptyScans() => AppCard(child: Column(children: const [Icon(Icons.qr_code_scanner_rounded, size: 36, color: PriceShieldColors.muted), SizedBox(height: 10), Text('No scans yet', style: TextStyle(fontWeight: FontWeight.w700)), SizedBox(height: 4), Text('Scan a product to start protecting your purchases.', textAlign: TextAlign.center, style: TextStyle(color: PriceShieldColors.muted))]));
}

class _ActionLabel extends StatelessWidget { const _ActionLabel(); @override Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: const [Text('Start scanning', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)), SizedBox(width: 6), Icon(Icons.arrow_forward_rounded, color: PriceShieldColors.mint, size: 18)]); }
class _DashboardSkeleton extends StatelessWidget { const _DashboardSkeleton(); @override Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(20), children: [const SizedBox(height: 22), Container(height: 28, width: 170, decoration: BoxDecoration(color: Color(0xffE8EDF3), borderRadius: BorderRadius.all(Radius.circular(8)))), const SizedBox(height: 12), Container(height: 16, width: 230, decoration: BoxDecoration(color: Color(0xffE8EDF3), borderRadius: BorderRadius.all(Radius.circular(8)))), const SizedBox(height: 24), Container(height: 184, decoration: BoxDecoration(color: Color(0xffE8EDF3), borderRadius: BorderRadius.all(Radius.circular(22)))), const SizedBox(height: 16), Container(height: 94, decoration: BoxDecoration(color: Color(0xffE8EDF3), borderRadius: BorderRadius.all(Radius.circular(18))))]); }
