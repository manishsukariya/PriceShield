import 'package:flutter/material.dart';
import 'package:priceshield/core/theme/app_theme.dart';
import 'package:priceshield/features/deescalation/models/deescalation_data.dart';
import 'package:priceshield/features/deescalation/presentation/widgets/showcard_view.dart';
import 'package:priceshield/features/deescalation/services/deescalation_voice_service.dart';

class FullscreenShowcardScreen extends StatefulWidget {
  const FullscreenShowcardScreen({
    super.key,
    required this.data,
    this.initialLanguage = ShowcardLanguage.bilingual,
    this.voiceService,
  });

  final DeescalationData data;
  final ShowcardLanguage initialLanguage;
  final DeescalationVoiceService? voiceService;

  @override
  State<FullscreenShowcardScreen> createState() => _FullscreenShowcardScreenState();
}

class _FullscreenShowcardScreenState extends State<FullscreenShowcardScreen> {
  late ShowcardLanguage _language = widget.initialLanguage;
  late final DeescalationVoiceService _voiceService;
  late final bool _ownsVoiceService;

  @override
  void initState() {
    super.initState();
    if (widget.voiceService != null) {
      _voiceService = widget.voiceService!;
      _ownsVoiceService = false;
    } else {
      _voiceService = DeescalationVoiceService();
      _ownsVoiceService = true;
    }
  }

  @override
  void dispose() {
    if (_ownsVoiceService) {
      _voiceService.dispose();
    }
    super.dispose();
  }

  Future<void> _triggerVoiceOut(bool isPlaying) async {
    if (isPlaying) {
      await _voiceService.stop();
    } else {
      final voiceLang = _language == ShowcardLanguage.english
          ? VoiceLanguage.english
          : VoiceLanguage.hindi;
      final ok = await _voiceService.play(language: voiceLang);
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not play audio. Check volume / TTS settings.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff060a12),
      appBar: AppBar(
        backgroundColor: const Color(0xff0b1320),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Show to Vendor (दुकानदार को दिखाएं)',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        actions: [
          PopupMenuButton<ShowcardLanguage>(
            icon: const Icon(Icons.language_rounded, color: Color(0xfff59e0b)),
            tooltip: 'Change Language',
            initialValue: _language,
            onSelected: (lang) => setState(() => _language = lang),
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: ShowcardLanguage.bilingual,
                child: Text('Bilingual (दोनों भाषाएँ)'),
              ),
              PopupMenuItem(
                value: ShowcardLanguage.hindi,
                child: Text('हिंदी (Hindi Only)'),
              ),
              PopupMenuItem(
                value: ShowcardLanguage.english,
                child: Text('English Only'),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded),
            tooltip: 'Close Full-Screen',
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      bottomNavigationBar: ValueListenableBuilder<VoicePlaybackState>(
        valueListenable: _voiceService.stateNotifier,
        builder: (context, playbackState, _) {
          final isPlaying = playbackState == VoicePlaybackState.playing;
          return ValueListenableBuilder<int>(
            valueListenable: _voiceService.remainingSecondsNotifier,
            builder: (context, remainingSec, _) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  color: Color(0xff0b1320),
                  border: Border(
                    top: BorderSide(color: Color(0xff1e293b), width: 1.5),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: SizedBox(
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: () => _triggerVoiceOut(isPlaying),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isPlaying
                            ? PriceShieldColors.danger
                            : const Color(0xfff59e0b),
                        foregroundColor: isPlaying ? Colors.white : Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 4,
                      ),
                      icon: Icon(
                        isPlaying
                            ? Icons.stop_circle_rounded
                            : Icons.volume_up_rounded,
                        size: 24,
                      ),
                      label: Text(
                        isPlaying
                            ? 'Stop Audio (0:${remainingSec.toString().padLeft(2, '0')})'
                            : _language == ShowcardLanguage.english
                                ? '🔊 Play Audio Law (English)'
                                : '🔊 Play Statutory Voice-Out (हिंदी)',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            children: [
              // Top notice bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: const Color(0xfff59e0b).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xfff59e0b)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.screen_rotation_rounded,
                        color: Color(0xfff59e0b), size: 18),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Hold screen towards shopkeeper to display statutory law',
                        style: TextStyle(
                          color: Color(0xfffef08a),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 1-Tap Language Toggle Tabs
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _langChip('Dual / दोनों भाषाएं', ShowcardLanguage.bilingual),
                  const SizedBox(width: 8),
                  _langChip('हिंदी', ShowcardLanguage.hindi),
                  const SizedBox(width: 8),
                  _langChip('English', ShowcardLanguage.english),
                ],
              ),
              const SizedBox(height: 14),

              ShowcardView(
                data: widget.data,
                selectedLanguage: _language,
                isFullScreen: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _langChip(String label, ShowcardLanguage lang) {
    final isSelected = _language == lang;
    return InkWell(
      onTap: () => setState(() => _language = lang),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xfff59e0b) : const Color(0xff162235),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xfff59e0b) : const Color(0xff2d3c52),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
            color: isSelected ? Colors.black : Colors.white70,
          ),
        ),
      ),
    );
  }
}
