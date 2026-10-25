import 'package:flutter/material.dart';
import 'package:priceshield/core/services/auth_session.dart';
import 'package:priceshield/core/services/priceshield_api_client.dart';
import 'package:priceshield/features/scanner/presentation/screens/scan_details_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<Map<String, dynamic>>> _scans = priceShieldApi.listScans(limit: 20);

  Future<void> _refresh() async {
    setState(() => _scans = priceShieldApi.listScans(limit: 20));
  }

  @override
  Widget build(BuildContext context) {
    final name = AuthSession.currentUser.value?.displayName ?? '';
    return Scaffold(
      appBar: AppBar(
        title: Text(name.isEmpty ? 'Hello' : 'Hello, $name'),
        backgroundColor: const Color(0xFF2BAE9A),
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _scans,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            final error = snapshot.error;
            final message = error is PriceShieldApiException
                ? error.message
                : 'Could not load scan history.';
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(message, textAlign: TextAlign.center),
              ),
            );
          }

          final scans = snapshot.data ?? const <Map<String, dynamic>>[];
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
              children: [
                const Text(
                  'Recent scans',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                if (scans.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: Center(child: Text('Scan a product to start your history.')),
                  ),
                ...scans.map((scan) => Card(
                      child: ListTile(
                        title: Text(scan['productName']?.toString() ?? 'Product'),
                        subtitle: Text(
                          'MRP ₹${scan['mrp'] ?? 0} · Paid ₹${scan['chargedPrice'] ?? 0}',
                        ),
                        trailing: Text(
                          scan['status'] == 'OVERCHARGED'
                              ? 'Overcharged'
                              : 'Within MRP',
                        ),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ScanDetailsScreen(scanData: scan),
                          ),
                        ),
                      ),
                    )),
              ],
            ),
          );
        },
      ),
    );
  }
}
