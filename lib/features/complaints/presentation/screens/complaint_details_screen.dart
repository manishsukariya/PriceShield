import 'package:flutter/material.dart';
import 'package:priceshield/core/services/priceshield_api_client.dart';
import 'package:priceshield/core/theme/app_theme.dart';
import 'package:priceshield/core/widgets/app_ui.dart';

class ComplaintDetailsScreen extends StatefulWidget {
  const ComplaintDetailsScreen({super.key, required this.complaintId});
  final String complaintId;
  @override State<ComplaintDetailsScreen> createState() => _ComplaintDetailsScreenState();
}

class _ComplaintDetailsScreenState extends State<ComplaintDetailsScreen> {
  late Future<Map<String, dynamic>> _complaint = priceShieldApi.getComplaint(widget.complaintId);

  Future<void> _reload() async => setState(() => _complaint = priceShieldApi.getComplaint(widget.complaintId));
  Future<void> _withdraw() async { try { await priceShieldApi.withdrawComplaint(widget.complaintId); if (mounted) Navigator.pop(context); } on PriceShieldApiException catch (error) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message))); } }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: PriceShieldColors.background,
        appBar: AppBar(title: const Text('Complaint details')),
        body: FutureBuilder<Map<String, dynamic>>(
          future: _complaint,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator(color: PriceShieldColors.primary));
            if (snapshot.hasError) return Padding(padding: const EdgeInsets.all(20), child: InlineError(message: 'We could not load this complaint.', onRetry: _reload));
            final data = snapshot.data!;
            final evidence = data['evidence'] is List ? data['evidence'] as List : const [];
            final status = data['status']?.toString() ?? 'PENDING';
            return ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 32), children: [
              AppCard(child: Row(children: [Container(width: 48, height: 48, decoration: BoxDecoration(color: PriceShieldColors.mint, borderRadius: BorderRadius.circular(15)), child: const Icon(Icons.receipt_long_rounded, color: PriceShieldColors.primary)), const SizedBox(width: 12), Expanded(child: Text(data['productName']?.toString() ?? 'Product complaint', style: Theme.of(context).textTheme.titleLarge)), StatusPill(label: status.replaceAll('_', ' '), color: status == 'RESOLVED' ? PriceShieldColors.success : PriceShieldColors.warning)])),
              const SizedBox(height: 16),
              AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Price information', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)), const SizedBox(height: 16), Row(children: [_value('Printed MRP', data['mrp']), _value('Charged', data['chargedPrice']), _value('Overcharge', data['overcharge'], PriceShieldColors.danger)])])),
              const SizedBox(height: 16),
              AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Case information', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)), const SizedBox(height: 12), _detail('Barcode', data['barcode']), _detail('Address', data['address']), if (data['description'] != null) _detail('Description', data['description'])])),
              if (evidence.isNotEmpty) ...[const SizedBox(height: 16), AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Evidence', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)), const SizedBox(height: 8), ...evidence.whereType<Map>().map((item) => ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.attachment_rounded, color: PriceShieldColors.primary), title: Text(item['url']?.toString() ?? 'Uploaded evidence', maxLines: 1, overflow: TextOverflow.ellipsis)))]))],
              if (status != 'WITHDRAWN' && status != 'RESOLVED') ...[const SizedBox(height: 22), OutlinedButton.icon(onPressed: _withdraw, icon: const Icon(Icons.undo_rounded), label: const Text('Withdraw complaint'), style: OutlinedButton.styleFrom(foregroundColor: PriceShieldColors.danger, side: const BorderSide(color: PriceShieldColors.danger)))]
            ]);
          },
        ),
      );

  Widget _value(String label, dynamic value, [Color color = PriceShieldColors.text]) => Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(color: PriceShieldColors.muted, fontSize: 11)), const SizedBox(height: 4), Text('\u{20B9}${value ?? 0}', style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 15))]));
  Widget _detail(String label, dynamic value) => Padding(padding: const EdgeInsets.only(bottom: 10), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 92, child: Text(label, style: const TextStyle(color: PriceShieldColors.muted, fontSize: 12))), Expanded(child: Text(value?.toString().isNotEmpty == true ? value.toString() : 'Not provided', style: const TextStyle(fontWeight: FontWeight.w600)))]));
}
