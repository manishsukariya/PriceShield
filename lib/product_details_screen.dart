import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'scan_result_screen.dart';

class ProductDetailsScreen extends StatefulWidget {
  final String barcode;
  const ProductDetailsScreen({super.key, required this.barcode});

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  String name = "";
  int mrp = 0;
  bool loading = true;

  final priceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchProduct();
  }

  Future<void> _fetchProduct() async {
    final doc = await FirebaseFirestore.instance
        .collection('products')
        .doc(widget.barcode)
        .get();

    if (doc.exists) {
      name = doc['name'];
      mrp = doc['mrp'];
    } else {
      name = "Unknown Product";
    }

    setState(() => loading = false);
  }

  void _checkPrice() {
    final charged = int.tryParse(priceController.text) ?? 0;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ScanResultScreen(
          name: name,
          barcode: widget.barcode,
          mrp: mrp,
          charged: charged,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xffF6F7F9),
      appBar: AppBar(
        backgroundColor: const Color(0xffF6F7F9),
        elevation: 0,
        foregroundColor: Colors.black,
        title: const Text("Product Details"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [

            /// PRODUCT CARD
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(Icons.qr_code,
                      size: 40, color: Color(0xff57C7A7)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        Text("Barcode: ${widget.barcode}",
                            style: const TextStyle(
                                fontSize: 12, color: Colors.black54)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            /// MRP CARD
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xffE3F6F1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Legal MRP",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Text("₹$mrp",
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Color(0xff57C7A7))),
                ],
              ),
            ),

            const SizedBox(height: 20),

            /// INPUT PRICE
            TextField(
              controller: priceController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: "Enter charged price",
                prefixText: "₹ ",
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),

            const Spacer(),

            /// BUTTON
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xff57C7A7),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _checkPrice,
                child: const Text("Check "),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
