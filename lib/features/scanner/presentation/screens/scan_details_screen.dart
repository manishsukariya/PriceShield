import 'package:flutter/material.dart';
import 'package:priceshield/core/services/priceshield_api_client.dart';
import 'package:priceshield/core/theme/app_theme.dart';
import 'package:priceshield/core/widgets/app_ui.dart';
import 'package:priceshield/features/complaints/presentation/screens/complaint_screen.dart';
import 'package:priceshield/features/deescalation/models/deescalation_data.dart';
import 'package:priceshield/features/deescalation/presentation/screens/deescalation_screen.dart';

class ScanDetailsScreen extends StatelessWidget {
  const ScanDetailsScreen({super.key, required this.scanData});
  final Map<String, dynamic> scanData;
  @override
  Widget build(BuildContext context) {
    final name = scanData['productName']?.toString() ?? scanData['product_name']?.toString() ?? 'Product';
    final barcode = scanData['barcode']?.toString() ?? '';
    final mrp = num.tryParse('${scanData['mrp'] ?? 0}') ?? 0;
    final charged = num.tryParse('${scanData['chargedPrice'] ?? scanData['charged_price'] ?? 0}') ?? 0;
    final overcharged = charged > mrp;
    final color = overcharged ? PriceShieldColors.danger : PriceShieldColors.success;
    return Scaffold(backgroundColor: PriceShieldColors.background, appBar: AppBar(title: const Text('Scan details')), body: ListView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 32), children: [
      AppCard(color: color, child: Column(children: [Icon(overcharged ? Icons.warning_amber_rounded : Icons.verified_rounded, color: Colors.white, size: 42), const SizedBox(height: 10), Text(overcharged ? 'Overcharged' : 'Within MRP', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)), const SizedBox(height: 5), Text(overcharged ? 'Extra charged: \u{20B9}${(charged - mrp).toStringAsFixed(2)}' : 'This purchase is within the printed price.', style: const TextStyle(color: Colors.white))])),
      const SizedBox(height: 16),
      AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(name, style: Theme.of(context).textTheme.titleLarge), const SizedBox(height: 5), Text('Barcode: $barcode', style: const TextStyle(color: PriceShieldColors.muted, fontSize: 12)), const Divider(height: 28), _row('Printed MRP', mrp), _row('Amount charged', charged), _row('Difference', charged - mrp, color)])),
      if (overcharged) ...[
        const SizedBox(height: 22),
        SizedBox(
          height: 52,
          child: ElevatedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DeescalationScreen(
                  initialData: DeescalationData(
                    productName: name,
                    barcode: barcode,
                    mrp: mrp,
                    chargedPrice: charged,
                    shopName: scanData['storeName']?.toString() ??
                        scanData['store_name']?.toString() ??
                        scanData['shopName']?.toString() ??
                        scanData['shop_name']?.toString(),
                    location: scanData['location']?.toString() ??
                        scanData['storeLocation']?.toString() ??
                        scanData['address']?.toString(),
                  ),
                ),
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: PriceShieldColors.navy,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.gavel_rounded, color: Color(0xfff59e0b)),
            label: const Text('De-escalation Co-Pilot & Law Card'),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 50,
          child: OutlinedButton.icon(
            onPressed: () async {
              try {
                final complaints = await priceShieldApi.listComplaints(limit: 100);
                if (complaints.any((item) => item['barcode']?.toString() == barcode && item['status'] != 'WITHDRAWN')) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('You have already submitted an active complaint for this product.'),
                        backgroundColor: PriceShieldColors.navy,
                      ),
                    );
                  }
                  return;
                }
                if (context.mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => ComplaintScreen(name: name, barcode: barcode, mrp: mrp, charged: charged)));
              } on PriceShieldApiException catch (error) {
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
              }
            },
            icon: const Icon(Icons.report_problem_outlined),
            label: const Text('File a formal complaint'),
          ),
        ),
      ]
    ]));
  }
  Widget _row(String label, num value, [Color color = PriceShieldColors.text]) => Padding(padding: const EdgeInsets.only(bottom: 14), child: Row(children: [Expanded(child: Text(label, style: const TextStyle(color: PriceShieldColors.muted))), Text('\u{20B9}${value.toStringAsFixed(2)}', style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w800))]));
}
