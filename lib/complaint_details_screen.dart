import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ComplaintDetailsScreen extends StatefulWidget {
  final String complaintDocId;

  const ComplaintDetailsScreen({
    super.key,
    required this.complaintDocId,
  });

  @override
  State<ComplaintDetailsScreen> createState() =>
      _ComplaintDetailsScreenState();
}

class _ComplaintDetailsScreenState
    extends State<ComplaintDetailsScreen> {

  final user = FirebaseAuth.instance.currentUser;

  Future<DocumentSnapshot<Map<String, dynamic>>> fetchComplaint() {
    return FirebaseFirestore.instance
        .collection("complaints")
        .doc(widget.complaintDocId)
        .get();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: fetchComplaint(),
      builder: (context, snapshot) {

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Scaffold(
            body: Center(child: Text("Complaint not found")),
          );
        }

        final data = snapshot.data!.data();

        if (data == null) {
          return const Scaffold(
            body: Center(child: Text("No data available")),
          );
        }

        /// 🔐 Ensure user logged in
        if (user == null) {
          return const Scaffold(
            body: Center(child: Text("Please login first")),
          );
        }

        /// 🔐 Security check (only own complaint)
        if (data["user_email"] != user!.email)
        {
          return const Scaffold(
            body: Center(child: Text("Unauthorized Access")),
          );
        }

        /// 🔥 SAFE DATA EXTRACTION

        String productName = data["product_name"] ?? "";

        int chargedPrice =
        (data["charged_price"] is num)
            ? (data["charged_price"] as num).toInt()
            : 0;

        int legalMrp =
        (data["mrp"] is num)
            ? (data["mrp"] as num).toInt()
            : 0;

        int overcharge =
        (data["extra"] is num)
            ? (data["extra"] as num).toInt()
            : 0;

        String shopLocation = data["address"] ?? "";

        Timestamp? purchaseTimestamp =
        data["purchase_date"] is Timestamp
            ? data["purchase_date"]
            : null;

        String formattedDate = purchaseTimestamp != null
            ? purchaseTimestamp.toDate().toString().split(" ")[0]
            : "No date";

        String status = (data["status"] ?? "pending").toString();

        String complaintId = widget.complaintDocId;

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
              "Complaint Details",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),

          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                /// STATUS CARD
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xffFFF1DD),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Container(
                        height: 50,
                        width: 50,
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: const Icon(
                          Icons.access_time,
                          color: Colors.orange,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              status.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Complaint ID: $complaintId",
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                /// PRODUCT INFO CARD
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      const Text(
                        "Product Information",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 20),

                      Text(
                        productName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 12),

                      Row(
                        children: [
                          _priceColumn(
                            "Charged Price",
                            "₹$chargedPrice",
                            Colors.red,
                          ),
                          const SizedBox(width: 20),
                          _priceColumn(
                            "Legal MRP",
                            "₹$legalMrp",
                            Colors.green,
                          ),
                          const SizedBox(width: 20),
                          _priceColumn(
                            "Overcharge",
                            "+₹$overcharge",
                            Colors.red,
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined,
                              color: Colors.grey),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(shopLocation),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      Row(
                        children: [
                          const Icon(Icons.calendar_today_outlined,
                              color: Colors.grey),
                          const SizedBox(width: 8),
                          Text(formattedDate),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                /// WITHDRAW BUTTON
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _withdrawComplaint(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.red,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      "Withdraw Complaint",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _priceColumn(String label, String value, Color valueColor) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _withdrawComplaint(BuildContext context) async {
    await FirebaseFirestore.instance
        .collection("complaints")
        .doc(widget.complaintDocId)
        .delete();

    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Complaint withdrawn successfully"),
        backgroundColor: Colors.red,
      ),
    );
  }
}
