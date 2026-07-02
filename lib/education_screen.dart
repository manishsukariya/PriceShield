import 'package:flutter/material.dart';

class ConsumerEducationScreen extends StatelessWidget {
  const ConsumerEducationScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
          "Consumer Education",
          style: TextStyle(color: Colors.black),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            /// ---------- TOP GREEN CARD ----------
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xff57C7A7),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Icon(Icons.menu_book, color: Colors.white, size: 36),
                  SizedBox(height: 16),
                  Text(
                    "Know Your Rights",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    "Understanding consumer protection laws empowers you to fight unfair pricing and protect others.",
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            _infoCard(
              Icons.balance,
              Colors.green,
              "Legal Metrology Act",
              "Under the Legal Metrology Act 2009, retailers must sell products at or below the MRP printed on packaging.",
            ),

            _infoCard(
              Icons.shield_outlined,
              Colors.orange,
              "Consumer Protection",
              "You have the right to be protected against unfair trade practices. Overcharging violates your consumer rights.",
            ),

            _infoCard(
              Icons.error_outline,
              Colors.red,
              "What is MRP?",
              "Maximum Retail Price includes all taxes (GST, VAT, etc). No additional charges can be added on top of MRP.",
            ),

            _infoCard(
              Icons.description_outlined,
              Colors.blueGrey,
              "Filing Complaints",
              "You can file complaints with local consumer forums or legal metrology departments for violations.",
            ),

            const SizedBox(height: 20),

            /// ---------- FAQ ----------
            const Text(
              "Frequently Asked Questions",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 12),

            _faq(
              "Can shops charge for plastic bags separately?",
              "Yes, plastic bags can be charged separately as they are not part of the product MRP.",
            ),

            _faq(
              "What if there's no MRP on the product?",
              "It's illegal to sell pre-packaged products without MRP. You can report such cases to legal metrology.",
            ),

            _faq(
              "Are discounts below MRP allowed?",
              "Yes, retailers can sell products below MRP. MRP is the maximum ceiling, not the minimum.",
            ),

            const SizedBox(height: 24),

            /// ---------- HELPLINE ----------
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xffE3F6F1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: const [
                  Icon(Icons.call, color: Colors.teal),
                  SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "National Consumer Helpline",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 6),
                      Text(
                        "1800-11-4000\nMon–Sat | 9:30 AM – 5:30 PM",
                        style: TextStyle(color: Colors.black54),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ---------- WIDGETS ----------
  static Widget _infoCard(
      IconData icon, Color color, String title, String desc) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.15),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 6),
                Text(desc,
                    style:
                    const TextStyle(fontSize: 13, color: Colors.black54)),
              ],
            ),
          )
        ],
      ),
    );
  }

  static Widget _faq(String q, String a) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(q,
              style:
              const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 6),
          Text(a,
              style:
              const TextStyle(fontSize: 13, color: Colors.black54)),
        ],
      ),
    );
  }
}
