import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:priceshield/features/profile/presentation/screens/profile_screen.dart';
import 'package:priceshield/features/scanner/presentation/screens/scan_details_screen.dart';
import 'package:priceshield/features/scanner/presentation/screens/scanner_screen.dart';
import 'package:priceshield/features/education/presentation/screens/education_screen.dart';
import 'package:priceshield/features/complaints/presentation/screens/complaint_details_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String userName = "";
  String? _profileImageUrl;

  @override
  void initState() {
    super.initState();
    _loadUserName();
  }

  Future<void> _loadUserName() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (mounted && userDoc.exists) {
          setState(() {
            userName = userDoc.data()?['name'] ?? "";
            _profileImageUrl = userDoc.data()?['photo_url']?.toString();
          });
        }
      }
    } catch (e) {
      print("Error loading user name: $e");
    }
  }

  void _openScanner(BuildContext context) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ScannerScreen()),
    );

    if (result != null) {
      final int mrp = result['mrp'];
      final int shopPrice = result['shopPrice'];
      final String productName = result['product_name'] ?? 'Unknown Product';
      final bool overcharged = shopPrice > mrp;
      final uid = FirebaseAuth.instance.currentUser?.uid;

      if (uid != null) {
        await FirebaseFirestore.instance.collection('scans').add({
          'user_id': uid,
          'product_name': productName,
          'charged_price': shopPrice,
          'mrp': mrp,
          'status': overcharged ? 'overcharged' : 'within_mrp',
          'timestamp': FieldValue.serverTimestamp(),
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              overcharged
                  ? "Overcharged ₹${shopPrice - mrp}"
                  : "Within MRP ✅",
            ),
          ),
        );
      }
    }
  }

  void _openComplaintDetails(BuildContext context, String docId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ComplaintDetailsScreen(complaintDocId: docId),
      ),
    );
  }

  // ── Scan details open karo ──
  void _openScanDetails(BuildContext context, Map<String, dynamic> data) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ScanDetailsScreen(scanData: data),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xffF6F7F9),
        elevation: 0,
        title: const Text(
          "PriceShield",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: GestureDetector(
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                );
                _loadUserName();
              },
              child: CircleAvatar(
                backgroundColor: const Color(0xff57C7A7),
                backgroundImage: _profileImageUrl != null
                    ? NetworkImage(_profileImageUrl!)
                    : null,
                child: _profileImageUrl == null
                    ? Text(
                  userName.isEmpty ? "U" : userName[0].toUpperCase(),
                  style: const TextStyle(color: Colors.white),
                )
                    : null,
              ),
            ),
          ),
        ],
      ),
      backgroundColor: const Color(0xffF6F7F9),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                userName.isEmpty ? "Welcome 👋" : "Welcome, $userName 👋",
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),

              // ── SCAN CARD ──
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => _openScanner(context),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xff57C7A7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Container(
                        height: 60,
                        width: 60,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.shield_outlined,
                            color: Colors.white, size: 32),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Check Product Price",
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold)),
                            SizedBox(height: 6),
                            Text("Scan barcode to verify MRP instantly",
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 14)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ── KNOW YOUR RIGHTS ──
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xffFFF1DD),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      height: 40,
                      width: 40,
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.lightbulb_outline,
                          color: Colors.orange),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Know Your Rights",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 15)),
                          SizedBox(height: 4),
                          Text(
                            "Charging above MRP is illegal under Indian consumer protection laws.",
                            style: TextStyle(
                                fontSize: 13, color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── LATEST COMPLAINT ──
              const Text("Your Latest Complaint",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),

              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('complaints')
                    .where('user_id', isEqualTo: uid)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return _dataErrorCard('Your latest complaint could not be loaded.');
                  }
                  final complaints = snapshot.data?.docs.toList() ?? [];
                  complaints.sort((a, b) {
                    final aData = a.data() as Map<String, dynamic>;
                    final bData = b.data() as Map<String, dynamic>;
                    final aDate = (aData['created_at'] ?? aData['purchase_date']) as Timestamp?;
                    final bDate = (bData['created_at'] ?? bData['purchase_date']) as Timestamp?;
                    return (bDate?.millisecondsSinceEpoch ?? 0)
                        .compareTo(aDate?.millisecondsSinceEpoch ?? 0);
                  });
                  if (complaints.isEmpty) {
                    return const Text("No complaints yet");
                  }
                  return _complaintCard(context, complaints.first);
                },
              ),

              const SizedBox(height: 16),

              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('scans')
                    .where('user_id', isEqualTo: uid)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return _dataErrorCard('Your scan summary could not be loaded.');
                  }
                  final count = snapshot.data?.docs.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        return data['status'] == 'overcharged';
                      }).length ??
                      0;
                  return _achievementCard(count);
                },
              ),

              const SizedBox(height: 20),

              // ── INFO CARD ──
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "MRP includes all taxes. Shops cannot legally charge more.",
                            style: TextStyle(fontSize: 14),
                          ),
                          const SizedBox(height: 6),
                          GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                  const ConsumerEducationScreen()),
                            ),
                            child: const Text(
                              "Learn More →",
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.teal,
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── RECENT SCANS ──
              const Text("Recent Scans",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),

              if (uid == null)
                const Text("User not logged in")
              else
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('scans')
                      .where('user_id', isEqualTo: uid)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return _dataErrorCard('Recent scans could not be loaded. Check your connection and try again.');
                    }

                    final allDocs = snapshot.data?.docs ?? [];
                    final sortedDocs = List.of(allDocs)
                      ..sort((a, b) {
                        final aTs =
                        (a.data() as Map<String, dynamic>)['created_at']
                        as Timestamp?;
                        final bTs =
                        (b.data() as Map<String, dynamic>)['created_at']
                        as Timestamp?;
                        if (aTs == null && bTs == null) return 0;
                        if (aTs == null) return -1;
                        if (bTs == null) return 1;
                        return bTs.compareTo(aTs);
                      });

                    final docs = sortedDocs.take(3).toList();

                    if (docs.isEmpty) {
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Column(
                          children: [
                            Icon(Icons.qr_code_scanner_rounded,
                                size: 34, color: Color(0xFFCDD1D9)),
                            SizedBox(height: 10),
                            Text("No scans yet",
                                style: TextStyle(
                                    color: Color(0xFF9098A3),
                                    fontWeight: FontWeight.w500)),
                            SizedBox(height: 4),
                            Text("Scan a product to see it here",
                                style: TextStyle(
                                    color: Color(0xFFBFC4CD), fontSize: 12)),
                          ],
                        ),
                      );
                    }

                    return Column(
                      children: docs.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        return _scanTile(context, data); // context pass kiya
                      }).toList(),
                    );
                  },
                ),

              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _achievementCard(int overchargeCount) {
    final label = overchargeCount == 1 ? '1 overcharge' : '$overchargeCount overcharges';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xffE3F6F1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            height: 40,
            width: 40,
            decoration: BoxDecoration(
              color: Colors.teal.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.emoji_events_outlined, color: Colors.teal),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'You helped detect $label',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Keep protecting consumers!',
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dataErrorCard(String message) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.cloud_off_outlined, color: Colors.redAccent),
            const SizedBox(width: 10),
            Expanded(child: Text(message, style: const TextStyle(color: Colors.redAccent))),
          ],
        ),
      );

  Widget _scanTile(BuildContext context, Map<String, dynamic> data) {
    final productName = data['product_name'] ?? 'Unknown Product';
    final chargedPrice = (data['charged_price'] ?? 0).toDouble();
    final mrp = (data['mrp'] ?? 0).toDouble();
    final timestamp = data['created_at'] as Timestamp?;
    final isOvercharged = chargedPrice > mrp;

    String timeAgo = "";
    if (timestamp != null) {
      final diff = DateTime.now().difference(timestamp.toDate());
      if (diff.inSeconds < 60) timeAgo = "just now";
      else if (diff.inMinutes < 60) timeAgo = "${diff.inMinutes} min ago";
      else if (diff.inHours < 24)
        timeAgo = "${diff.inHours} hour${diff.inHours > 1 ? 's' : ''} ago";
      else if (diff.inDays == 1) timeAgo = "1 day ago";
      else timeAgo = "${diff.inDays} days ago";
    }

    return GestureDetector(
      onTap: () => _openScanDetails(context, data),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFF4F6FA),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.qr_code_scanner_outlined,
                  color: Color(0xFF9098A3), size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(productName,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  if (timeAgo.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(timeAgo,
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF9098A3))),
                  ],
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text("₹${chargedPrice.toStringAsFixed(0)}",
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 5),
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: isOvercharged
                        ? Colors.red.withOpacity(0.12)
                        : Colors.green.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isOvercharged ? "Overcharged" : "Within MRP",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isOvercharged ? Colors.red : Colors.green,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 6),
            const Icon(Icons.arrow_forward_ios_rounded,
                size: 12, color: Color(0xFF9098A3)),
          ],
        ),
      ),
    );
  }

  Widget _complaintCard(BuildContext context, DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final productName = data['product_name'] ?? '';
    final status = data['status'] ?? 'pending';
    final Timestamp? ts =
    data['purchase_date'] is Timestamp ? data['purchase_date'] : null;
    final date = ts != null ? ts.toDate().toString().split(" ")[0] : '';

    return InkWell(
      onTap: () => _openComplaintDetails(context, doc.id),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(productName,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text("Submitted on $date",
                      style: const TextStyle(
                          fontSize: 13, color: Colors.black54)),
                ],
              ),
            ),
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(status,
                  style: const TextStyle(
                      color: Colors.orange, fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }
}
