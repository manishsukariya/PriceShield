import 'package:flutter/material.dart';
import 'package:priceshield/core/theme/app_theme.dart';
import 'package:priceshield/core/widgets/app_ui.dart';
import 'package:priceshield/features/complaints/presentation/screens/complaint_screen.dart';

class ScanResultScreen extends StatelessWidget {
  const ScanResultScreen({super.key, required this.name, required this.barcode, required this.mrp, required this.charged});
  final String name; final String barcode; final num mrp; final num charged;
  @override
  Widget build(BuildContext context) {
    final overcharged = charged > mrp;
    final difference = charged - mrp;
    final color = overcharged ? PriceShieldColors.danger : PriceShieldColors.success;
    return Scaffold(backgroundColor: PriceShieldColors.background, appBar: AppBar(title: const Text('Scan result')), body: ListView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 32), children: [
      AppCard(color: color, child: Column(children: [Icon(overcharged ? Icons.warning_amber_rounded : Icons.verified_rounded, color: Colors.white, size: 44), const SizedBox(height: 12), Text(overcharged ? 'Overcharge detected' : 'Price is within MRP', style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w800)), if (overcharged) ...[const SizedBox(height: 6), Text('You were charged \u{20B9}${difference.toStringAsFixed(2)} extra.', style: const TextStyle(color: Colors.white, fontSize: 15))]])),
      const SizedBox(height: 16),
      AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(name, style: Theme.of(context).textTheme.titleLarge), const SizedBox(height: 5), Text('Barcode: $barcode', style: const TextStyle(color: PriceShieldColors.muted, fontSize: 12)), const Divider(height: 28), _row('Printed MRP', mrp), _row('Amount charged', charged), _row('Difference', difference, overcharged ? PriceShieldColors.danger : PriceShieldColors.success)])),
      const SizedBox(height: 24),
      if (overcharged)
        SizedBox(
          height: 52,
          child: ElevatedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ComplaintScreen(
                  name: name,
                  barcode: barcode,
                  mrp: mrp.toInt(),
                  charged: charged.toInt(),
                ),
              ),
            ),
            icon: const Icon(Icons.report_problem_outlined),
            label: const Text('File a complaint'),
          ),
        ),
    ]));
  }
  Widget _row(String label, num value, [Color color = PriceShieldColors.text]) => Padding(padding: const EdgeInsets.only(bottom: 14), child: Row(children: [Expanded(child: Text(label, style: const TextStyle(color: PriceShieldColors.muted))), Text('\u{20B9}${value.toStringAsFixed(2)}', style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 16))]));
}
