import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'complaint_details_screen.dart';

class nav_complaint_show extends StatefulWidget {
  const nav_complaint_show({super.key});

  @override
  State<nav_complaint_show> createState() => _nav_complaint_showState();
}

class _nav_complaint_showState extends State<nav_complaint_show> {
  final user = FirebaseAuth.instance.currentUser;
  String _selectedFilter = "All";
  final List<String> _filters = ["All", "Pending", "Resolved"];

  // ── Colours (matches app theme) ──────────────────────────────────────────
  static const _teal      = Color(0xFF57C7A7);
  static const _tealDark  = Color(0xFF2BAE9A);
  static const _bg        = Color(0xFFF6F7F9);
  static const _cardBg    = Colors.white;
  static const _textDark  = Color(0xFF1A1A2E);
  static const _textGrey  = Color(0xFF9098A3);

  // ── Status helpers ────────────────────────────────────────────────────────
  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'resolved': return Colors.green;
      case 'rejected': return Colors.red;
      default:         return Colors.orange;
    }
  }

  Color _statusBg(String status) {
    switch (status.toLowerCase()) {
      case 'resolved': return Colors.green.withOpacity(0.12);
      case 'rejected': return Colors.red.withOpacity(0.12);
      default:         return Colors.orange.withOpacity(0.12);
    }
  }

  IconData _statusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'resolved': return Icons.check_circle_outline_rounded;
      case 'rejected': return Icons.cancel_outlined;
      default:         return Icons.access_time_rounded;
    }
  }

  String _timeAgo(Timestamp? ts) {
    if (ts == null) return "";
    final diff = DateTime.now().difference(ts.toDate());
    if (diff.inSeconds < 60)  return "just now";
    if (diff.inMinutes < 60)  return "${diff.inMinutes} min ago";
    if (diff.inHours < 24)    return "${diff.inHours}h ago";
    if (diff.inDays == 1)     return "Yesterday";
    if (diff.inDays < 30)     return "${diff.inDays} days ago";
    return ts.toDate().toString().split(" ")[0];
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text("Please login to view complaints")),
      );
    }

    return Scaffold(
      backgroundColor: _bg,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('complaints')
            .where('user_id', isEqualTo: user!.uid)
            .orderBy('created_at', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: _teal),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                "Something went wrong\n${snapshot.error}",
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          final allDocs = snapshot.data?.docs ?? [];

          // ── Count stats ──
          final total    = allDocs.length;
          final resolved = allDocs.where((d) => (d['status'] ?? '') == 'resolved').length;
          final pending  = allDocs.where((d) => (d['status'] ?? '') == 'pending').length;

          // ── Apply filter ──
          final filtered = _selectedFilter == "All"
              ? allDocs
              : allDocs.where((d) =>
          (d['status'] ?? '').toString().toLowerCase() ==
              _selectedFilter.toLowerCase()).toList();

          return CustomScrollView(
            slivers: [
              // ── App Bar ──────────────────────────────────────────────────
              SliverAppBar(
                pinned: true,
                expandedHeight: 180,
                backgroundColor: _teal,
                elevation: 0,
                title: const Text(
                  "My Complaints",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    color: _teal,
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 56, 20, 16),
                        child: Row(
                          children: [
                            _statPill("Total",    total,    Colors.white,          Colors.white.withOpacity(0.25)),
                            const SizedBox(width: 10),
                            _statPill("Pending",  pending,  const Color(0xFFFFD580), Colors.white.withOpacity(0.2)),
                            const SizedBox(width: 10),
                            _statPill("Resolved", resolved, const Color(0xFF9EFFD5), Colors.white.withOpacity(0.2)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // ── Filter chips ─────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: _filters.map((f) => _filterChip(f)).toList(),
                  ),
                ),
              ),

              // ── List or Empty ─────────────────────────────────────────────
              filtered.isEmpty
                  ? SliverFillRemaining(child: _emptyState())
                  : SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                        (context, i) => _complaintCard(filtered[i]),
                    childCount: filtered.length,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Stat pill in header ───────────────────────────────────────────────────
  Widget _statPill(String label, int value, Color valueColor, Color bg) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(
              "$value",
              style: TextStyle(
                color: valueColor,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.85),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Filter chip ───────────────────────────────────────────────────────────
  Widget _filterChip(String label) {
    final selected = _selectedFilter == label;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF0D1B2A) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: selected
              ? [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 8, offset: const Offset(0, 3))]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFF9098A3),
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  // ── Complaint card ────────────────────────────────────────────────────────
  Widget _complaintCard(DocumentSnapshot doc) {
    final data       = doc.data() as Map<String, dynamic>;
    final product    = data['product_name'] ?? 'Unknown Product';
    final status     = (data['status'] ?? 'pending').toString();
    final mrp        = (data['mrp'] is num)       ? (data['mrp'] as num).toInt()           : 0;
    final charged    = (data['charged_price'] is num) ? (data['charged_price'] as num).toInt() : 0;
    final extra      = (data['extra'] is num)     ? (data['extra'] as num).toInt()          : 0;
    final address    = data['address'] ?? '';
    final createdTs  = data['created_at'] is Timestamp ? data['created_at'] as Timestamp : null;
    final timeAgo    = _timeAgo(createdTs);

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ComplaintDetailsScreen(complaintDocId: doc.id),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // ── Top row ─────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon box
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F8F5),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.receipt_long_rounded,
                        color: _teal, size: 22),
                  ),
                  const SizedBox(width: 12),
                  // Product + time
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: _textDark,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (timeAgo.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            timeAgo,
                            style: const TextStyle(
                                fontSize: 12, color: _textGrey),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _statusBg(status),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_statusIcon(status),
                            color: _statusColor(status), size: 13),
                        const SizedBox(width: 4),
                        Text(
                          status[0].toUpperCase() + status.substring(1),
                          style: TextStyle(
                            color: _statusColor(status),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Divider ──────────────────────────────────────────────────────
            const Divider(height: 1, color: Color(0xFFF0F0F0)),

            // ── Price row ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Row(
                children: [
                  _priceCell("MRP",        "₹$mrp",     _textGrey),
                  _verticalDivider(),
                  _priceCell("Charged",    "₹$charged", Colors.red),
                  _verticalDivider(),
                  _priceCell("Overcharge", "+₹$extra",  Colors.red),
                  const Spacer(),
                  // Address chip
                  if (address.isNotEmpty)
                    Flexible(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.location_on_outlined,
                              size: 14, color: _textGrey),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              address.split(",").first.trim(),
                              style: const TextStyle(
                                  fontSize: 12, color: _textGrey),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _priceCell(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.only(right: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 11, color: _textGrey)),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: valueColor)),
        ],
      ),
    );
  }

  Widget _verticalDivider() => Container(
    width: 1,
    height: 28,
    margin: const EdgeInsets.only(right: 14),
    color: const Color(0xFFEEEEEE),
  );

  // ── Empty state ───────────────────────────────────────────────────────────
  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F8F5),
              borderRadius: BorderRadius.circular(28),
            ),
            child: const Icon(Icons.receipt_long_outlined,
                size: 44, color: _teal),
          ),
          const SizedBox(height: 20),
          const Text(
            "No complaints yet",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _textDark,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Your filed complaints will appear here.\nScan a product and report overcharging.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: _textGrey),
          ),
        ],
      ),
    );
  }
}