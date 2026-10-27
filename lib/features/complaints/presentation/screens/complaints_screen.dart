import 'package:flutter/material.dart';
import 'package:priceshield/core/services/priceshield_api_client.dart';
import 'package:priceshield/features/complaints/presentation/screens/complaint_details_screen.dart';
import 'package:priceshield/core/widgets/app_ui.dart';

class ComplaintsScreen extends StatefulWidget {
  const ComplaintsScreen({super.key});
  @override State<ComplaintsScreen> createState() => _ComplaintsScreenState();
}

class _ComplaintsScreenState extends State<ComplaintsScreen> {
  late Future<List<Map<String, dynamic>>> _complaints = priceShieldApi.listComplaints(limit: 100);
  String _filter = 'All';
  Future<void> _refresh() async => setState(() => _complaints = priceShieldApi.listComplaints(limit: 100));

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xffF6F7F9),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: _complaints,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator(color: Color(0xff57C7A7)));
        if (snapshot.hasError) return Padding(padding: const EdgeInsets.all(20), child: InlineError(message: snapshot.error is PriceShieldApiException ? (snapshot.error as PriceShieldApiException).message : 'Could not load complaints.', onRetry: _refresh));
        final all = snapshot.data ?? <Map<String, dynamic>>[];
        final filtered = _filter == 'All' ? all : all.where((item) => item['status']?.toString().toUpperCase() == _filter.toUpperCase()).toList();
        final resolved = all.where((i) => i['status']?.toString().toUpperCase() == 'RESOLVED').length;
        final pending = all.length - resolved;
        return RefreshIndicator(onRefresh: _refresh, child: CustomScrollView(slivers: [
          SliverAppBar(pinned: true, expandedHeight: 178, backgroundColor: const Color(0xff57C7A7), foregroundColor: Colors.white, title: const Text('My Complaints', style: TextStyle(fontWeight: FontWeight.bold)), flexibleSpace: FlexibleSpaceBar(background: SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(20, 76, 20, 16), child: Row(children: [_stat('Total', all.length, Colors.white), const SizedBox(width: 10), _stat('Pending', pending, const Color(0xffffd580)), const SizedBox(width: 10), _stat('Resolved', resolved, const Color(0xff9effd5))]))))),
          SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 10), child: Row(children: ['All', 'PENDING', 'RESOLVED'].map(_chip).toList()))),
          if (filtered.isEmpty) const SliverFillRemaining(child: _EmptyComplaints()) else SliverPadding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 100), sliver: SliverList(delegate: SliverChildBuilderDelegate((context, index) => _card(filtered[index]), childCount: filtered.length))),
        ]));
      },
    ),
  );

  Widget _stat(String label, int value, Color color) => Expanded(child: Container(padding: const EdgeInsets.symmetric(vertical: 10), decoration: BoxDecoration(color: Colors.white.withOpacity(.2), borderRadius: BorderRadius.circular(14)), child: Column(children: [Text('$value', style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.bold)), Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12))])));
  Widget _chip(String label) { final selected = _filter == label; return GestureDetector(onTap: () => setState(() => _filter = label), child: AnimatedContainer(duration: const Duration(milliseconds: 180), margin: const EdgeInsets.only(right: 10), padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8), decoration: BoxDecoration(color: selected ? const Color(0xff0D1B2A) : Colors.white, borderRadius: BorderRadius.circular(20)), child: Text(label[0] + label.substring(1).toLowerCase(), style: TextStyle(color: selected ? Colors.white : const Color(0xff9098A3), fontWeight: FontWeight.w600, fontSize: 13)))); }

  Widget _card(Map<String, dynamic> item) {
    final status = item['status']?.toString() ?? 'PENDING';
    final resolved = status.toUpperCase() == 'RESOLVED';
    return GestureDetector(onTap: () async { await Navigator.push(context, MaterialPageRoute(builder: (_) => ComplaintDetailsScreen(complaintId: item['id'].toString()))); _refresh(); }, child: Container(margin: const EdgeInsets.only(bottom: 14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(.04), blurRadius: 12, offset: const Offset(0, 3))]), child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [Row(children: [Container(width: 46, height: 46, decoration: BoxDecoration(color: const Color(0xffe8f8f5), borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.receipt_long_rounded, color: Color(0xff57C7A7))), const SizedBox(width: 12), Expanded(child: Text(item['productName']?.toString() ?? 'Unknown Product', style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis)), Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: (resolved ? Colors.green : Colors.orange).withOpacity(.12), borderRadius: BorderRadius.circular(20)), child: Text(status, style: TextStyle(color: resolved ? Colors.green : Colors.orange, fontSize: 12, fontWeight: FontWeight.bold))) ]), const Divider(height: 24), Row(children: [_price('MRP', '₹${item['mrp'] ?? 0}'), _price('Charged', '₹${item['chargedPrice'] ?? 0}'), _price('Overcharge', '+₹${item['overcharge'] ?? 0}', Colors.red)])]))));
  }
  Widget _price(String label, String value, [Color color = const Color(0xff1a1a2e)]) => Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 11, color: Color(0xff9098A3))), const SizedBox(height: 3), Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color))]));
}

class _EmptyComplaints extends StatelessWidget {
  const _EmptyComplaints();
  @override Widget build(BuildContext context) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Container(width: 90, height: 90, decoration: BoxDecoration(color: const Color(0xffe8f8f5), borderRadius: BorderRadius.circular(28)), child: const Icon(Icons.receipt_long_outlined, size: 44, color: Color(0xff57C7A7))), const SizedBox(height: 20), const Text('No complaints yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), const SizedBox(height: 8), const Text('Your filed complaints will appear here.\nScan a product and report overcharging.', textAlign: TextAlign.center, style: TextStyle(color: Color(0xff9098A3)))]));
}
