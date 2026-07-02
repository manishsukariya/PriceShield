import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'complaint_screen.dart';

class ScanDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> scanData;

  const ScanDetailsScreen({super.key, required this.scanData});

  @override
  State<ScanDetailsScreen> createState() => _ScanDetailsScreenState();
}

class _ScanDetailsScreenState extends State<ScanDetailsScreen> {
  bool _checkingComplaint = false;

  Future<void> _handleComplaintButton() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final productName = (widget.scanData['product_name'] ?? '').toString().trim();
    final barcode    = (widget.scanData['barcode']       ?? '').toString().trim();
    final mrp        = (widget.scanData['mrp']           ?? 0).toInt();
    final charged    = (widget.scanData['charged_price'] ?? 0).toInt();

    setState(() => _checkingComplaint = true);

    try {
      // ── Firestore mein check karo ──
      final query = await FirebaseFirestore.instance
          .collection('complaints')
          .where('user_id',      isEqualTo: user.uid)
          .where('product_name', isEqualTo: productName)
          .limit(1)
          .get();

      if (!mounted) return;
      setState(() => _checkingComplaint = false);

      if (query.docs.isNotEmpty) {
        // Already complaint hai → dialog dikhao, screen mat kholo
        _showAlreadyComplainedDialog();
      } else {
        // Complaint nahi hui → ComplaintScreen open karo pre-filled data ke saath
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ComplaintScreen(
              name:    productName,
              barcode: barcode,
              mrp:     mrp,
              charged: charged,
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _checkingComplaint = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Something went wrong: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showAlreadyComplainedDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.info_outline_rounded,
                  color: Colors.orange, size: 32),
            ),
            const SizedBox(height: 16),
            const Text(
              "Complaint Already Filed",
              style:
              TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              "You have already filed a complaint for this product. You can track its status from the complaints section.",
              style: TextStyle(fontSize: 13, color: Colors.black54),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xff57C7A7),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: const Text("Got it",
                    style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final productName  = (widget.scanData['product_name']  ?? 'Unknown Product').toString();
    final chargedPrice = (widget.scanData['charged_price'] ?? 0).toDouble();
    final mrp          = (widget.scanData['mrp']           ?? 0).toDouble();
    final isOvercharged = chargedPrice > mrp;
    final diff          = (chargedPrice - mrp).abs();
    final timestamp     = widget.scanData['created_at'] as Timestamp?;

    String formattedDate = "—";
    String formattedTime = "—";
    if (timestamp != null) {
      final dt = timestamp.toDate();
      formattedDate =
      "${dt.day.toString().padLeft(2, '0')} ${_monthName(dt.month)} ${dt.year}";
      formattedTime =
      "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
    }

    return Scaffold(
      backgroundColor: const Color(0xffF6F7F9),

      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Scan Details",
          style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black),
        ),
      ),

      // ── FAB — sirf overcharged hone par dikhega ──
        floatingActionButton: isOvercharged
            ? Padding(
          padding: const EdgeInsets.only(bottom: 45),
          child: SizedBox(
            width: MediaQuery.of(context).size.width * 0.85,
            height: 55,
            child: ElevatedButton.icon(
              onPressed: _checkingComplaint ? null : _handleComplaintButton,
              icon: _checkingComplaint
                  ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
                  : const Icon(Icons.gavel_rounded,
                  color: Colors.white),
              label: Text(
                _checkingComplaint ? "Checking..." : "File a Complaint",
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xff0D1B2A),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        )
            : null,

      floatingActionButtonLocation:
      FloatingActionButtonLocation.centerFloat,

      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
            16, 16, 16, isOvercharged ? 90 : 16), // FAB ke liye bottom space
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── STATUS BANNER ──
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isOvercharged
                    ? const Color(0xffFFF1DD)
                    : const Color(0xffE3F6F1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    height: 50,
                    width: 50,
                    decoration: BoxDecoration(
                      color: isOvercharged
                          ? Colors.orange.withOpacity(0.2)
                          : Colors.teal.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: Icon(
                      isOvercharged
                          ? Icons.warning_amber_rounded
                          : Icons.check_circle_outline_rounded,
                      color: isOvercharged ? Colors.orange : Colors.teal,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isOvercharged ? "OVERCHARGED" : "WITHIN MRP",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isOvercharged
                                ? Colors.orange
                                : Colors.teal,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isOvercharged
                              ? "You were charged ₹${diff.toStringAsFixed(0)} extra"
                              : "Price is within legal MRP",
                          style: const TextStyle(
                              fontSize: 13, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── PRODUCT INFO ──
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle("Product Information"),
                  const SizedBox(height: 16),
                  Text(
                    productName,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _priceColumn(
                          "Charged Price",
                          "₹${chargedPrice.toStringAsFixed(0)}",
                          Colors.red),
                      _priceColumn(
                          "Legal MRP",
                          "₹${mrp.toStringAsFixed(0)}",
                          Colors.green),
                      _priceColumn(
                        isOvercharged ? "Extra Paid" : "You Saved",
                        "₹${diff.toStringAsFixed(0)}",
                        isOvercharged ? Colors.red : Colors.teal,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── SCAN TIME ──
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle("Scan Information"),
                  const SizedBox(height: 16),
                  _infoRow(Icons.calendar_today_outlined, "Date",
                      formattedDate),
                  const SizedBox(height: 12),
                  _infoRow(
                      Icons.access_time_rounded, "Time", formattedTime),
                ],
              ),
            ),

          ],
        ),
      ),
    );
  }

  Widget _card({required Widget child}) => Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
    ),
    child: child,
  );

  Widget _sectionTitle(String t) => Text(t,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold));

  Widget _priceColumn(String label, String value, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style:
              const TextStyle(fontSize: 11, color: Colors.black54)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color)),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.grey, size: 18),
        const SizedBox(width: 10),
        Text("$label: ",
            style:
            const TextStyle(color: Colors.black54, fontSize: 13)),
        Text(value,
            style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 13)),
      ],
    );
  }

  String _monthName(int month) {
    const months = [
      "Jan","Feb","Mar","Apr","May","Jun",
      "Jul","Aug","Sep","Oct","Nov","Dec"
    ];
    return months[month - 1];
  }
}