import 'package:flutter/material.dart';
import 'package:priceshield/core/services/auth_session.dart';
import 'package:priceshield/core/services/priceshield_api_client.dart';
import 'package:priceshield/core/theme/app_theme.dart';
import 'package:priceshield/core/widgets/app_ui.dart';
import 'package:priceshield/features/deescalation/presentation/screens/deescalation_screen.dart';
import 'package:priceshield/features/education/presentation/screens/education_screen.dart';
import 'package:priceshield/features/scanner/presentation/screens/scan_details_screen.dart';
import 'package:priceshield/features/scanner/presentation/screens/scanner_screen.dart';

class _HomeDashboardData {
  const _HomeDashboardData({
    required this.scans,
    required this.complaints,
    this.hasMoreScans = false,
    this.hasMoreComplaints = false,
    this.syncError,
  });

  final List<Map<String, dynamic>> scans;
  final List<Map<String, dynamic>> complaints;
  final bool hasMoreScans;
  final bool hasMoreComplaints;
  final String? syncError;
}

class HomeScreen extends StatefulWidget { const HomeScreen({super.key}); @override State<HomeScreen> createState() => _HomeScreenState(); }

class _HomeScreenState extends State<HomeScreen> {
  late Future<_HomeDashboardData> _content = _loadContent();

  Future<_HomeDashboardData> _loadContent() async {
    if (!AuthSession.isSignedIn) {
      // In Guest Mode, return empty scans & complaints instantly (0ms) without 401 errors.
      return const _HomeDashboardData(scans: [], complaints: []);
    }
    try {
      final results = await Future.wait([
        priceShieldApi.listScansPage(limit: 20),
        priceShieldApi.listComplaintsPage(limit: 20),
      ]);
      final scansPage = results[0];
      final complaintsPage = results[1];
      return _HomeDashboardData(
        scans: scansPage.items,
        complaints: complaintsPage.items,
        hasMoreScans: scansPage.hasMore,
        hasMoreComplaints: complaintsPage.hasMore,
      );
    } on PriceShieldApiException catch (error) {
      return _HomeDashboardData(
        scans: const [],
        complaints: const [],
        syncError: error.message,
      );
    } catch (_) {
      return const _HomeDashboardData(
        scans: [],
        complaints: [],
        syncError: 'Offline or server unavailable. Pull down or tap Retry to sync.',
      );
    }
  }

  Future<void> _refresh() async => setState(() => _content = _loadContent());
  void _openScanner() => Navigator.push(context, MaterialPageRoute(builder: (_) => const ScannerScreen())).then((_) => _refresh());

  @override Widget build(BuildContext context) {
    final user = AuthSession.currentUser.value;
    final name = user?.displayName.trim() ?? '';
    final isGuest = !AuthSession.isSignedIn;
    final firstName = isGuest
        ? 'Scout'
        : (name.isEmpty ? 'there' : name.split(RegExp(r'\s+')).first);
    final avatarLetter = isGuest ? 'S' : (name.isEmpty ? 'U' : name[0].toUpperCase());

    return Scaffold(
      backgroundColor: PriceShieldColors.background,
      appBar: AppBar(
        titleSpacing: 20,
        title: const Text('PriceShield'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: CircleAvatar(
              backgroundColor: PriceShieldColors.primary,
              child: Text(
                avatarLetter,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: PriceShieldColors.primary,
        onRefresh: _refresh,
        child: FutureBuilder<_HomeDashboardData>(
          future: _content,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) return const _DashboardSkeleton();
            final data = snapshot.data ?? const _HomeDashboardData(scans: [], complaints: []);
            final scans = data.scans;
            final complaints = data.complaints;

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 116),
              children: [
                Text('Hello, $firstName', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 4),
                Text(
                  isGuest
                      ? 'Shield Scout Guest Mode. Scan any product to verify MRP.'
                      : 'Stay informed. Pay the right price.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: PriceShieldColors.muted),
                ),
                const SizedBox(height: 20),
                _scanHero(),
                const SizedBox(height: 16),
                _quickSummary(
                  scans,
                  complaints,
                  hasMoreScans: data.hasMoreScans,
                  hasMoreComplaints: data.hasMoreComplaints,
                ),
                const SizedBox(height: 16),
                _copilotCard(),
                const SizedBox(height: 24),
                Text('Latest activity', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 10),
                if (data.syncError != null && !isGuest) ...[
                  _syncNotice(data.syncError!),
                  const SizedBox(height: 10),
                ],
                if (scans.isEmpty) _emptyScans() else ...scans.take(3).map(_scanTile),
                const SizedBox(height: 24),
                _rightsCard(),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _scanHero() => InkWell(onTap: _openScanner, borderRadius: BorderRadius.circular(22), child: Ink(padding: const EdgeInsets.all(22), decoration: BoxDecoration(color: PriceShieldColors.navy, borderRadius: BorderRadius.circular(22)), child: Row(children: [const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Check a product', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)), SizedBox(height: 8), Text('Scan the barcode to compare the printed MRP.', style: TextStyle(color: Color(0xffC9D5E6), height: 1.35)), SizedBox(height: 18), _ActionLabel()])), Container(width: 58, height: 58, decoration: BoxDecoration(color: PriceShieldColors.primary, borderRadius: BorderRadius.circular(18)), child: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 30))])));
  Widget _quickSummary(
    List<Map<String, dynamic>> scans,
    List<Map<String, dynamic>> complaints, {
    bool hasMoreScans = false,
    bool hasMoreComplaints = false,
  }) {
    final isGuest = !AuthSession.isSignedIn;
    final scansLabel = isGuest
        ? 'Guest'
        : '${scans.length}${hasMoreScans ? '+' : ''}';
    final complaintsLabel = isGuest
        ? '0'
        : '${complaints.length}${hasMoreComplaints ? '+' : ''}';
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      child: Row(
        children: [
          _metric('Scans', scansLabel, Icons.qr_code_2_rounded),
          _divider(),
          _metric('Complaints', complaintsLabel, Icons.receipt_long_outlined),
          _divider(),
          _metric('Status', isGuest ? 'Ready' : (complaints.isEmpty ? 'Clear' : 'Active'), Icons.verified_outlined),
        ],
      ),
    );
  }
  Widget _syncNotice(String message) => AppCard(
        color: const Color(0xffFFF7ED),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            const Icon(Icons.cloud_off_rounded, color: PriceShieldColors.warning, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Color(0xff92400E), fontSize: 12),
              ),
            ),
            TextButton(
              onPressed: _refresh,
              child: const Text('Retry', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
  Widget _metric(String label, String value, IconData icon) => Expanded(child: Column(children: [Icon(icon, color: PriceShieldColors.primary, size: 22), const SizedBox(height: 7), Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)), const SizedBox(height: 2), Text(label, style: const TextStyle(color: PriceShieldColors.muted, fontSize: 12))]));
  Widget _divider() => Container(width: 1, height: 42, color: PriceShieldColors.border);
  Widget _copilotCard() => AppCard(
        color: const Color(0xff0b1320),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xfff59e0b).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.gavel_rounded, color: Color(0xfff59e0b), size: 20),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Cooling Charge Dispute?',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xfff59e0b),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'CO-PILOT',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w900,
                      fontSize: 10,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              'Rule 18(2) prohibits \u20B95\u2013\u20B910 fridge cooling charges. Defuse the argument with our bilingual law card, 15s audio voice-out, and 1-tap WhatsApp helpline.',
              style: TextStyle(color: Color(0xffc9d5e6), fontSize: 13, height: 1.35),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 44,
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DeescalationScreen()),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: PriceShieldColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.shield_outlined, size: 18),
                label: const Text('Open De-escalation Showcard', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      );
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
