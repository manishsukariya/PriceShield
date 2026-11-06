import 'package:flutter/material.dart';
import 'package:priceshield/core/theme/app_theme.dart';
import 'package:priceshield/core/widgets/app_ui.dart';
import 'package:priceshield/features/deescalation/presentation/screens/deescalation_screen.dart';

class ConsumerEducationScreen extends StatelessWidget {
  const ConsumerEducationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PriceShieldColors.background,
      appBar: AppBar(
        backgroundColor: PriceShieldColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: PriceShieldColors.text),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Consumer education",
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            /// ---------- TOP GREEN CARD ----------
            AppCard(
              color: PriceShieldColors.navy,
              padding: const EdgeInsets.all(20),
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

            const SizedBox(height: 16),

            /// ---------- DE-ESCALATION CO-PILOT BANNER ----------
            AppCard(
              color: const Color(0xff0b1320),
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xfff59e0b).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.gavel_rounded,
                            color: Color(0xfff59e0b), size: 22),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          "De-escalation Co-Pilot",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xfff59e0b),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          "NEW",
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "Facing cooling charge disputes? Rule 18(2) specifies MRP includes refrigeration expenses. Use our Full-Screen Authoritative Law Card, 15-second audio voice-out, and 1-tap WhatsApp helpline (+91 8800001915).",
                    style: TextStyle(
                      color: Color(0xffc9d5e6),
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 44,
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const DeescalationScreen(),
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: PriceShieldColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.shield_outlined, size: 18),
                      label: const Text(
                        "Open Law Showcard & Voice-Out",
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ),
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
              "A separate charge is not automatically illegal, but the price and bag details must be clearly disclosed before purchase. A surprise charge at the counter, or a mandatory charge without prior notice, may be an unfair trade practice. Keep the bill and report the details.",
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
  static Widget _infoCard(IconData icon, Color color, String title, String desc) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: AppCard(
          child: Row(children: [
            CircleAvatar(backgroundColor: color.withOpacity(.15), child: Icon(icon, color: color)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)), const SizedBox(height: 6), Text(desc, style: const TextStyle(fontSize: 13, color: PriceShieldColors.muted, height: 1.35))])),
          ]),
        ),
      );

  static Widget _faq(String question, String answer) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(question, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)), const SizedBox(height: 6), Text(answer, style: const TextStyle(fontSize: 13, color: PriceShieldColors.muted, height: 1.35))])),
      );
}
