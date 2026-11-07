import 'package:flutter/material.dart';
import 'package:priceshield/core/services/auth_session.dart';
import 'package:priceshield/core/services/priceshield_api_client.dart';
import 'package:priceshield/core/theme/app_theme.dart';
import 'package:priceshield/core/widgets/app_ui.dart';
import 'package:priceshield/features/complaints/presentation/screens/complaint_details_screen.dart';

class ComplaintsScreen extends StatefulWidget {
  const ComplaintsScreen({super.key});
  @override State<ComplaintsScreen> createState() => _ComplaintsScreenState();
}

class _ComplaintsScreenState extends State<ComplaintsScreen> {
  late Future<List<Map<String, dynamic>>> _complaints = AuthSession.isSignedIn
      ? priceShieldApi.listComplaints(limit: 100)
      : Future.value(<Map<String, dynamic>>[]);
  String _filter = 'ALL';

  Future<void> _refresh() async {
    if (!AuthSession.isSignedIn) return;
    setState(() => _complaints = priceShieldApi.listComplaints(limit: 100));
  }

  @override
  Widget build(BuildContext context) {
    if (!AuthSession.isSignedIn) {
      return Scaffold(
        backgroundColor: PriceShieldColors.background,
        appBar: AppBar(title: const Text('Complaints')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: PriceShieldColors.mint,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.receipt_long_outlined,
                    size: 40,
                    color: PriceShieldColors.primary,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Complaints History',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Sign in to your PriceShield account to track and manage your formal grievances across devices.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: PriceShieldColors.muted, fontSize: 14),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pushNamed(context, '/signin'),
                    child: const Text('Sign In to View Complaints', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
        backgroundColor: PriceShieldColors.background,
        appBar: AppBar(title: const Text('Complaints')),
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: _complaints,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) return const _ComplaintsSkeleton();
            if (snapshot.hasError) {
              final message = snapshot.error is PriceShieldApiException ? (snapshot.error as PriceShieldApiException).message : 'We could not load your complaints.';
              return ListView(padding: const EdgeInsets.all(20), children: [InlineError(message: message, onRetry: _refresh)]);
            }
            final all = snapshot.data ?? <Map<String, dynamic>>[];
            final filtered = _filter == 'ALL' ? all : all.where((item) => _status(item) == _filter).toList();
            final resolved = all.where((item) => _status(item) == 'RESOLVED').length;
            final active = all.length - resolved;
            return RefreshIndicator(
              color: PriceShieldColors.primary,
              onRefresh: _refresh,
              child: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 116), children: [
                _summary(all.length, active, resolved),
                const SizedBox(height: 22),
                Text('Track your reports', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 10),
                _filters(),
                const SizedBox(height: 14),
                if (filtered.isEmpty) const _EmptyComplaints() else ...filtered.map(_complaintCard),
              ]),
            );
          },
        ),
      );
  }

  String _status(Map<String, dynamic> item) => item['status']?.toString().toUpperCase() ?? 'PENDING';

  Widget _summary(int total, int active, int resolved) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: PriceShieldColors.navy, borderRadius: BorderRadius.circular(22)),
        child: Row(children: [_metric('Total', total), _separator(), _metric('Active', active), _separator(), _metric('Resolved', resolved)]),
      );

  Widget _metric(String label, int value) => Expanded(child: Column(children: [Text('$value', style: const TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.w800)), const SizedBox(height: 4), Text(label, style: const TextStyle(color: Color(0xffC9D5E6), fontSize: 12))]));
  Widget _separator() => Container(width: 1, height: 42, color: Colors.white24);

  Widget _filters() => SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: ['ALL', 'PENDING', 'RESOLVED'].map((value) { final selected = _filter == value; return Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: Text(value[0] + value.substring(1).toLowerCase()), selected: selected, onSelected: (_) => setState(() => _filter = value), selectedColor: PriceShieldColors.navy, labelStyle: TextStyle(color: selected ? Colors.white : PriceShieldColors.muted, fontWeight: FontWeight.w700), backgroundColor: Colors.white, side: const BorderSide(color: PriceShieldColors.border))); }).toList()));

  Widget _complaintCard(Map<String, dynamic> item) {
    final status = _status(item);
    final resolved = status == 'RESOLVED';
    final statusColor = resolved ? PriceShieldColors.success : PriceShieldColors.warning;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        padding: EdgeInsets.zero,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () async {
            await Navigator.push(context, MaterialPageRoute(builder: (_) => ComplaintDetailsScreen(complaintId: item['id'].toString())));
            if (mounted) _refresh();
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(width: 44, height: 44, decoration: BoxDecoration(color: PriceShieldColors.mint, borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.receipt_long_rounded, color: PriceShieldColors.primary)),
                  const SizedBox(width: 12),
                  Expanded(child: Text(item['productName']?.toString() ?? 'Product complaint', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
                  StatusPill(label: _friendlyStatus(status), color: statusColor),
                ]),
                const SizedBox(height: 16),
                Row(children: [_amount('MRP', item['mrp']), _amount('Charged', item['chargedPrice']), _amount('Overcharge', item['overcharge'], PriceShieldColors.danger)]),
                const SizedBox(height: 14),
                const Row(children: [Expanded(child: Text('View case details', style: TextStyle(color: PriceShieldColors.primary, fontWeight: FontWeight.w700))), Icon(Icons.arrow_forward_rounded, color: PriceShieldColors.primary, size: 18)]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _friendlyStatus(String status) => status == 'UNDER_REVIEW' ? 'Under review' : status[0] + status.substring(1).toLowerCase();
  Widget _amount(String label, dynamic value, [Color color = PriceShieldColors.text]) => Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(color: PriceShieldColors.muted, fontSize: 11)), const SizedBox(height: 4), Text('\u{20B9}${value ?? 0}', style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 14))]));
}

class _EmptyComplaints extends StatelessWidget {
  const _EmptyComplaints();
  @override Widget build(BuildContext context) => AppCard(child: Column(children: const [Icon(Icons.receipt_long_outlined, size: 42, color: PriceShieldColors.primary), SizedBox(height: 12), Text('No complaints in this view', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)), SizedBox(height: 6), Text('Your submitted reports and their progress will appear here.', textAlign: TextAlign.center, style: TextStyle(color: PriceShieldColors.muted, height: 1.35))]));
}

class _ComplaintsSkeleton extends StatelessWidget {
  const _ComplaintsSkeleton();
  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 12),
          Container(height: 116, decoration: BoxDecoration(color: const Color(0xffE8EDF3), borderRadius: BorderRadius.circular(22))),
          const SizedBox(height: 24),
          Container(height: 22, width: 150, decoration: BoxDecoration(color: const Color(0xffE8EDF3), borderRadius: BorderRadius.circular(8))),
          const SizedBox(height: 16),
          ...List.generate(3, (_) => _skeletonCard()),
        ],
      );

  Widget _skeletonCard() => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Container(
          height: 152,
          decoration: BoxDecoration(
            color: const Color(0xffE8EDF3),
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      );
}
