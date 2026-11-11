import 'package:flutter/material.dart';
import 'package:priceshield/features/deescalation/models/deescalation_data.dart';

enum ShowcardLanguage {
  bilingual,
  hindi,
  english,
}

class ShowcardView extends StatelessWidget {
  const ShowcardView({
    super.key,
    required this.data,
    required this.selectedLanguage,
    this.isFullScreen = false,
  });

  final DeescalationData data;
  final ShowcardLanguage selectedLanguage;
  final bool isFullScreen;

  @override
  Widget build(BuildContext context) {
    final showHindi = selectedLanguage == ShowcardLanguage.bilingual ||
        selectedLanguage == ShowcardLanguage.hindi;
    final showEnglish = selectedLanguage == ShowcardLanguage.bilingual ||
        selectedLanguage == ShowcardLanguage.english;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xff0b1320),
        borderRadius: BorderRadius.circular(isFullScreen ? 0 : 20),
        border: Border.all(
          color: const Color(0xfff59e0b),
          width: 2.0,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      padding: EdgeInsets.all(isFullScreen ? 24 : 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header: Regulatory Authority Badge
          _buildAuthorityHeader(),
          const SizedBox(height: 14),

          // Active Product Dispute Box (if data present)
          if (data.mrp != null && data.chargedPrice != null) ...[
            _buildDisputeSnippet(),
            const SizedBox(height: 14),
          ],

          // Legal Metrology Rule 18(2) Section
          _buildRule18Section(showHindi: showHindi, showEnglish: showEnglish),
          const SizedBox(height: 14),

          // Jan Vishwas Act 2023 Section
          _buildJanVishwasSection(showHindi: showHindi, showEnglish: showEnglish),
          const SizedBox(height: 14),

          // Footer Statutory Warning
          _buildStatutoryFooter(showHindi: showHindi, showEnglish: showEnglish),
        ],
      ),
    );
  }

  Widget _buildAuthorityHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xfff59e0b).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xfff59e0b).withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.gavel_rounded, color: Color(0xfff59e0b), size: 20),
          SizedBox(width: 8),
          Flexible(
            child: Text(
              'CONSUMER RIGHTS LAW CARD / उपभोक्ता अधिकार सूचना',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xfff59e0b),
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisputeSnippet() {
    final isOvercharge = data.hasOvercharge;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xff162235),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOvercharge ? const Color(0xffef4444) : const Color(0xff10b981),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isOvercharge ? Icons.report_problem_rounded : Icons.check_circle_rounded,
                color: isOvercharge ? const Color(0xffef4444) : const Color(0xff10b981),
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  data.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _priceTag('Printed MRP', '₹${data.formattedMrp}', Colors.white70),
              _priceTag('Shop Demands', '₹${data.formattedChargedPrice}', const Color(0xfffbbf24)),
              if (isOvercharge)
                _priceTag('Extra Demanded', '+₹${data.formattedOvercharge}', const Color(0xffef4444), isHighlight: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _priceTag(String label, String value, Color valueColor, {bool isHighlight = false}) {
    final fontSize = isFullScreen
        ? (isHighlight ? 18.0 : 15.0)
        : (isHighlight ? 16.0 : 14.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white60,
            fontSize: isFullScreen ? 12 : 11,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontWeight: FontWeight.w900,
            fontSize: fontSize,
          ),
        ),
      ],
    );
  }

  Widget _buildRule18Section({required bool showHindi, required bool showEnglish}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xff141d2e),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xff2d3c52)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.ac_unit_rounded, color: Color(0xff38bdf8), size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'RULE 18(2) — REFRIGERATION / COOLING CHARGES',
                  style: TextStyle(
                    color: Color(0xff38bdf8),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Legal Metrology (Packaged Commodities) Rules, 2011',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 11,
              fontStyle: FontStyle.italic,
            ),
          ),
          const Divider(color: Color(0xff2d3c52), height: 16),

          if (showHindi) ...[
            Text(
              '« पैकेज्ड वस्तुओं पर छपे अधिकतम खुदरा मूल्य (MRP) में सभी टैक्स और फ्रिज/कूलिंग का खर्च पहले से शामिल है। कोई भी दुकानदार ठंडा करने के नाम पर ₹1 भी अधिक नहीं ले सकता। ऐसा करना विधिक अपराध है। »',
              style: TextStyle(
                color: const Color(0xfffef08a),
                fontSize: isFullScreen ? 15 : 13,
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
            if (showEnglish) const SizedBox(height: 8),
          ],

          if (showEnglish) ...[
            Text(
              '"No retail dealer shall sell any commodity packed in excess of the Maximum Retail Price (MRP). Printed MRP includes all taxes and refrigeration / chilling expenses. No extra cooling fee should be charged."',
              style: TextStyle(
                color: Colors.white,
                fontSize: isFullScreen ? 14 : 13,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildJanVishwasSection({required bool showHindi, required bool showEnglish}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xff1f151e),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xffef4444).withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.warning_amber_rounded, color: Color(0xfff87171), size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'PENALTY NOTICE: JAN VISHWAS ACT, 2023',
                  style: TextStyle(
                    color: Color(0xfff87171),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Section 36, Legal Metrology Act (Amended 2023)',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 11,
              fontStyle: FontStyle.italic,
            ),
          ),
          const Divider(color: Color(0xff451a1a), height: 16),

          if (showHindi) ...[
            Text(
              '« एमआरपी से अधिक वसूली की शिकायत जन विश्वास अधिनियम 2023 के तहत संबंधित विभाग को की जा सकती है। बार-बार उल्लंघन साबित होने पर ₹5,00,000 (पाँच लाख रुपये) तक का जुर्माना संभव है। »',
              style: TextStyle(
                color: const Color(0xfffca5a5),
                fontSize: isFullScreen ? 15 : 13,
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
            if (showEnglish) const SizedBox(height: 8),
          ],

          if (showEnglish) ...[
            Text(
              '"Selling commodities above MRP may be reported for inspection by Legal Metrology authorities. Repeat verified violations can attract civil penalties up to ₹5,00,000 under the Jan Vishwas Act."',
              style: TextStyle(
                color: Colors.white,
                fontSize: isFullScreen ? 14 : 13,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatutoryFooter({required bool showHindi, required bool showEnglish}) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xff090f18),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xff1e293b)),
      ),
      child: Row(
        children: [
          const Icon(Icons.shield_outlined, color: Color(0xff10b981), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              showHindi
                  ? 'यह जानकारी उपभोक्ता संरक्षण व विधिक मापविज्ञान नियमों के संदर्भ में जागरूकता हेतु है।'
                  : 'For consumer awareness under Legal Metrology Rules, 2011 & Consumer Affairs guidelines.',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
