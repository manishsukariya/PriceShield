import 'package:flutter/material.dart';
import 'package:priceshield/core/theme/app_theme.dart';
import 'package:priceshield/features/deescalation/models/deescalation_data.dart';
import 'package:priceshield/features/deescalation/presentation/screens/fullscreen_showcard_screen.dart';
import 'package:priceshield/features/deescalation/presentation/widgets/audio_voice_player.dart';
import 'package:priceshield/features/deescalation/presentation/widgets/helpline_card.dart';
import 'package:priceshield/features/deescalation/presentation/widgets/showcard_view.dart';
import 'package:priceshield/features/deescalation/services/deescalation_voice_service.dart';

class DeescalationScreen extends StatefulWidget {
  const DeescalationScreen({
    super.key,
    this.initialData,
  });

  final DeescalationData? initialData;

  @override
  State<DeescalationScreen> createState() => _DeescalationScreenState();
}

class _DeescalationScreenState extends State<DeescalationScreen> {
  late DeescalationData _data = widget.initialData ?? DeescalationData.generic;
  late final DeescalationVoiceService _voiceService = DeescalationVoiceService();
  ShowcardLanguage _cardLanguage = ShowcardLanguage.bilingual;
  bool _initializedArgs = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initializedArgs) {
      _initializedArgs = true;
      if (widget.initialData == null) {
        final args = ModalRoute.of(context)?.settings.arguments;
        if (args is DeescalationData) {
          _data = args;
        }
      }
    }
  }

  @override
  void dispose() {
    _voiceService.dispose();
    super.dispose();
  }

  void _openFullScreenShowcard() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FullscreenShowcardScreen(
          data: _data,
          initialLanguage: _cardLanguage,
          voiceService: _voiceService,
        ),
      ),
    );
  }

  void _showCustomizeDialog() {
    final nameCtrl = TextEditingController(text: _data.productName ?? '');
    final mrpCtrl = TextEditingController(text: _data.formattedMrp);
    final chargedCtrl = TextEditingController(text: _data.formattedChargedPrice);
    final shopCtrl = TextEditingController(text: _data.shopName ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Dispute Figures',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: PriceShieldColors.navy,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Item Name (e.g. Sprite 750ml)'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: mrpCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Printed MRP', prefixText: '₹ '),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: chargedCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Shop Demanded', prefixText: '₹ '),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: shopCtrl,
                decoration: const InputDecoration(labelText: 'Shop / Vendor Name (Optional)'),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  final mrp = num.tryParse(mrpCtrl.text.trim());
                  final charged = num.tryParse(chargedCtrl.text.trim());
                  if (mrp != null && mrp <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Printed MRP must be greater than 0')),
                    );
                    return;
                  }
                  if (charged != null && charged < 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Demanded price cannot be negative')),
                    );
                    return;
                  }
                  setState(() {
                    _data = _data.copyWith(
                      productName: nameCtrl.text.trim().isEmpty ? null : nameCtrl.text.trim(),
                      mrp: mrp,
                      chargedPrice: charged,
                      shopName: shopCtrl.text.trim().isEmpty ? null : shopCtrl.text.trim(),
                    );
                  });
                  Navigator.pop(ctx);
                },
                child: const Text('Update Showcard & Dispute Report'),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PriceShieldColors.background,
      appBar: AppBar(
        title: const Text('De-escalation Co-Pilot'),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'Customize dispute figures',
            onPressed: _showCustomizeDialog,
          ),
          IconButton(
            icon: const Icon(Icons.fullscreen_rounded),
            tooltip: 'Full-Screen Showcard Mode',
            onPressed: _openFullScreenShowcard,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Context Banner
            _buildIntroBanner(),
            const SizedBox(height: 16),

            // Section 1: Full-Screen Authoritative Law Card
            _buildShowcardSectionHeader(),
            const SizedBox(height: 8),
            ShowcardView(
              data: _data,
              selectedLanguage: _cardLanguage,
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _openFullScreenShowcard,
                icon: const Icon(Icons.fullscreen_rounded, size: 20),
                label: const Text('Open Full-Screen for Vendor'),
              ),
            ),
            const SizedBox(height: 16),

            // Section 2: 15-Second Audio Voice-Out
            AudioVoicePlayer(voiceService: _voiceService),
            const SizedBox(height: 20),

            // Section 3: 1-Tap WhatsApp Consumer Helpline
            HelplineCard(data: _data),
            const SizedBox(height: 20),

            // Section 4: De-escalation Strategy Guide
            _buildTipsCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildIntroBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PriceShieldColors.navy,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.shield_rounded, color: Color(0xff57c7a7), size: 24),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Cooling Charge De-escalator',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Vendors often argue: "Fridge electricity costs money; take it or leave it." Defuse the argument without confrontation using official law cards, recorded voice-out, and the WhatsApp helpline.',
            style: TextStyle(
              color: Color(0xffc9d5e6),
              fontSize: 13,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShowcardSectionHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Authoritative Law Card',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 16,
            color: PriceShieldColors.navy,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: PriceShieldColors.border),
          ),
          child: Row(
            children: [
              _pillTab('Dual', ShowcardLanguage.bilingual),
              _pillTab('हिंदी', ShowcardLanguage.hindi),
              _pillTab('Eng', ShowcardLanguage.english),
            ],
          ),
        ),
      ],
    );
  }

  Widget _pillTab(String label, ShowcardLanguage lang) {
    final isSelected = _cardLanguage == lang;
    return InkWell(
      onTap: () => setState(() => _cardLanguage = lang),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? PriceShieldColors.navy : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? Colors.white : PriceShieldColors.muted,
          ),
        ),
      ),
    );
  }

  Widget _buildTipsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xfff8fafc),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PriceShieldColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Row(
            children: [
              Icon(Icons.lightbulb_outline_rounded,
                  color: Color(0xffd97706), size: 18),
              SizedBox(width: 8),
              Text(
                'De-escalation Golden Rules',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: PriceShieldColors.navy,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            '1. Stay polite and calm — let the law card or audio voice-out do the talking.\n'
            '2. Do not argue about store electricity bills; Rule 18(2) already factors all cooling into the manufacturer\'s MRP.\n'
            '3. If the vendor refuses to comply, take a photo of the printed MRP and tap the WhatsApp Helpline to register an official report.',
            style: TextStyle(
              fontSize: 12,
              color: PriceShieldColors.muted,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
