import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:priceshield/complaint_screen.dart';

class ScanResultScreen extends StatefulWidget {
  final String name;
  final String barcode;
  final int mrp;
  final int charged;

  const ScanResultScreen({
    super.key,
    required this.name,
    required this.barcode,
    required this.mrp,
    required this.charged,
  });

  @override
  State<ScanResultScreen> createState() => _ScanResultScreenState();
}

class _ScanResultScreenState extends State<ScanResultScreen> {
  @override
  void initState() {
    super.initState();
    // ✅ Har scan — chahe overcharged ho ya within MRP — 'scans' mein save hoga
    _saveToScans();
  }

  Future<void> _saveToScans() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final bool overcharged = widget.charged > widget.mrp;

      await FirebaseFirestore.instance.collection('scans').add({
        'user_id': user.uid,
        'user_email': user.email,
        'product_name': widget.name,
        'barcode': widget.barcode,
        'charged_price': widget.charged,
        'mrp': widget.mrp,
        'status': overcharged ? 'overcharged' : 'within_mrp',
        'created_at': Timestamp.now(),
      });

      debugPrint("✅ Scan saved: ${widget.name} | ${overcharged ? 'OVERCHARGED' : 'WITHIN MRP'}");
    } catch (e) {
      debugPrint("❌ Error saving scan: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool overcharged = widget.charged > widget.mrp;

    return Scaffold(
      backgroundColor: const Color(0xffF6F7F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        title: const Text("Scan Result"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [

            /// RESULT CARD
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: overcharged
                    ? Colors.red.withOpacity(0.1)
                    : Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(
                    overcharged ? Icons.error : Icons.check_circle,
                    color: overcharged ? Colors.red : Colors.green,
                    size: 40,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      overcharged
                          ? "Overcharged!\nShop charged more than MRP"
                          : "All Good!\nThis product is within legal MRP",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            /// DETAILS
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  Text("Barcode: ${widget.barcode}",
                      style: const TextStyle(color: Colors.black54)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Legal MRP"),
                      Text("₹${widget.mrp}",
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Charged Price"),
                      Text("₹${widget.charged}",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: overcharged ? Colors.red : Colors.green,
                          )),
                    ],
                  ),
                ],
              ),
            ),

            const Spacer(),

            if (overcharged)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ComplaintScreen(
                          name: widget.name,
                          barcode: widget.barcode,
                          mrp: widget.mrp,
                          charged: widget.charged,
                        ),
                      ),
                    );
                  },
                  child: const Text(
                    "Complaint Now",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}