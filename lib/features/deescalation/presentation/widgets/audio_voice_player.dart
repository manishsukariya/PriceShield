import 'package:flutter/material.dart';
import 'package:priceshield/core/theme/app_theme.dart';
import 'package:priceshield/features/deescalation/services/deescalation_voice_service.dart';

class AudioVoicePlayer extends StatefulWidget {
  const AudioVoicePlayer({
    super.key,
    required this.voiceService,
  });

  final DeescalationVoiceService voiceService;

  @override
  State<AudioVoicePlayer> createState() => _AudioVoicePlayerState();
}

class _AudioVoicePlayerState extends State<AudioVoicePlayer>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  bool _showScript = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    widget.voiceService.stateNotifier.addListener(_onStateChange);
  }

  void _onStateChange() {
    if (widget.voiceService.isPlaying) {
      if (!_animController.isAnimating) {
        _animController.repeat(reverse: true);
      }
    } else {
      if (_animController.isAnimating) {
        _animController.stop();
        _animController.reset();
      }
    }
  }

  @override
  void dispose() {
    widget.voiceService.stateNotifier.removeListener(_onStateChange);
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<VoicePlaybackState>(
      valueListenable: widget.voiceService.stateNotifier,
      builder: (context, playbackState, _) {
        final isPlaying = playbackState == VoicePlaybackState.playing;

        return ValueListenableBuilder<VoiceLanguage>(
          valueListenable: widget.voiceService.languageNotifier,
          builder: (context, currentLang, _) {
            return ValueListenableBuilder<int>(
              valueListenable: widget.voiceService.remainingSecondsNotifier,
              builder: (context, remainingSec, _) {
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isPlaying
                          ? PriceShieldColors.primary
                          : PriceShieldColors.border,
                      width: isPlaying ? 2.0 : 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isPlaying
                            ? PriceShieldColors.primary.withValues(alpha: 0.18)
                            : const Color(0x0A0D1B2A),
                        blurRadius: isPlaying ? 18 : 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header Row
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isPlaying
                                  ? PriceShieldColors.mint
                                  : const Color(0xfff1f5f9),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              isPlaying
                                  ? Icons.volume_up_rounded
                                  : Icons.record_voice_over_rounded,
                              color: isPlaying
                                  ? PriceShieldColors.primary
                                  : PriceShieldColors.navy,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Text(
                                      '15s Audio Voice-Out',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 16,
                                        color: PriceShieldColors.navy,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isPlaying
                                            ? PriceShieldColors.danger
                                            : PriceShieldColors.primary,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        isPlaying ? 'LIVE' : 'OFFLINE',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'Play aloud to vendor to defuse confrontation',
                                  style: TextStyle(
                                    color: PriceShieldColors.muted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Countdown timer pill
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: isPlaying
                                  ? const Color(0xfffef3c7)
                                  : const Color(0xfff8fafc),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isPlaying
                                    ? const Color(0xfff59e0b)
                                    : PriceShieldColors.border,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.timer_outlined,
                                  size: 14,
                                  color: isPlaying
                                      ? const Color(0xffd97706)
                                      : PriceShieldColors.muted,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isPlaying
                                      ? '0:${remainingSec.toString().padLeft(2, '0')}'
                                      : '15s',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                    color: isPlaying
                                        ? const Color(0xffd97706)
                                        : PriceShieldColors.text,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Language Switcher Tabs
                      Row(
                        children: [
                          Expanded(
                            child: _langOption(
                              label: '🇮🇳 हिंदी (Hindi)',
                              isSelected: currentLang == VoiceLanguage.hindi,
                              onTap: () => widget.voiceService
                                  .setLanguage(VoiceLanguage.hindi),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _langOption(
                              label: '🇬🇧 English',
                              isSelected: currentLang == VoiceLanguage.english,
                              onTap: () => widget.voiceService
                                  .setLanguage(VoiceLanguage.english),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      // Soundwave Animation Bar (when playing)
                      if (isPlaying) ...[
                        AnimatedBuilder(
                          animation: _animController,
                          builder: (context, _) => _buildSoundWaveBars(),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Play / Stop Action Button
                      SizedBox(
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            if (isPlaying) {
                              await widget.voiceService.stop();
                            } else {
                              final ok = await widget.voiceService.play();
                              if (!ok && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Could not play audio voice-out. Check volume and TTS settings.'),
                                    duration: Duration(seconds: 3),
                                  ),
                                );
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isPlaying
                                ? PriceShieldColors.danger
                                : PriceShieldColors.navy,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          icon: Icon(
                            isPlaying
                                ? Icons.stop_circle_rounded
                                : Icons.play_arrow_rounded,
                            size: 26,
                          ),
                          label: Text(
                            isPlaying
                                ? 'Stop Playing Audio'
                                : currentLang == VoiceLanguage.hindi
                                    ? 'Play Hindi Voice-Out (दुकानदार को सुनाएं)'
                                    : 'Play English Voice-Out (Play to Vendor)',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),

                      // Volume notice hint
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: const Color(0xfffffbeb),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xfffef3c7)),
                        ),
                        child: Row(
                          children: const [
                            Icon(Icons.volume_up,
                                size: 16, color: Color(0xffd97706)),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Tip: Turn up media volume to play clearly to the vendor.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xff92400e),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 10),

                      // Collapsible script preview
                      InkWell(
                        onTap: () => setState(() => _showScript = !_showScript),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Icon(
                                _showScript
                                    ? Icons.keyboard_arrow_up
                                    : Icons.keyboard_arrow_down,
                                size: 18,
                                color: PriceShieldColors.muted,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _showScript
                                    ? 'Hide Spoken Script'
                                    : 'Preview Spoken Script (आवाज में क्या बोलेगा)',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: PriceShieldColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      if (_showScript) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xfff8fafc),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: PriceShieldColors.border),
                          ),
                          child: Text(
                            currentLang == VoiceLanguage.hindi
                                ? DeescalationVoiceService.hindiScript
                                : DeescalationVoiceService.englishScript,
                            style: const TextStyle(
                              fontSize: 13,
                              color: PriceShieldColors.text,
                              height: 1.4,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _langOption({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: isSelected
              ? PriceShieldColors.primary.withValues(alpha: 0.12)
              : const Color(0xfff1f5f9),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? PriceShieldColors.primary
                : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              color: isSelected
                  ? PriceShieldColors.primary
                  : PriceShieldColors.text,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSoundWaveBars() {
    final v = _animController.value;
    final heights = [
      8.0 + (v * 16.0),
      14.0 + ((1.0 - v) * 14.0),
      10.0 + (v * 20.0),
      18.0 + ((1.0 - v) * 10.0),
      6.0 + (v * 14.0),
      15.0 + ((1.0 - v) * 16.0),
      9.0 + (v * 18.0),
      12.0 + ((1.0 - v) * 12.0),
    ];

    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: PriceShieldColors.mint.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: heights.map((h) {
          return Container(
            width: 4,
            height: h,
            decoration: BoxDecoration(
              color: PriceShieldColors.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          );
        }).toList(),
      ),
    );
  }
}
