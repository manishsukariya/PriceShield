import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

enum VoiceLanguage {
  hindi,
  english,
}

enum VoicePlaybackState {
  stopped,
  playing,
  paused,
}

class DeescalationVoiceService {
  DeescalationVoiceService({FlutterTts? tts}) : _tts = tts ?? FlutterTts() {
    _initTts();
  }

  final FlutterTts _tts;
  bool _initialized = false;
  bool _isDisposed = false;
  VoicePlaybackState _state = VoicePlaybackState.stopped;
  VoiceLanguage _currentLanguage = VoiceLanguage.hindi;

  VoicePlaybackState get state => _state;
  VoiceLanguage get currentLanguage => _currentLanguage;
  bool get isPlaying => _state == VoicePlaybackState.playing;
  bool get isDisposed => _isDisposed;

  final ValueNotifier<VoicePlaybackState> stateNotifier =
      ValueNotifier<VoicePlaybackState>(VoicePlaybackState.stopped);
  final ValueNotifier<VoiceLanguage> languageNotifier =
      ValueNotifier<VoiceLanguage>(VoiceLanguage.hindi);
  final ValueNotifier<int> remainingSecondsNotifier = ValueNotifier<int>(15);

  Timer? _countdownTimer;

  static const int totalEstimatedSeconds = 15;

  static const String hindiScript =
      'नमस्ते। भारत सरकार के विधिक मापविज्ञान नियम 2011 के नियम 18(2) के अनुसार, '
      'पैकेज्ड वस्तुओं के अधिकतम खुदरा मूल्य यानी एमआरपी में कूलिंग और फ्रिज का खर्च '
      'पहले से शामिल होता है। जन विश्वास अधिनियम 2023 के तहत एमआरपी से ज्यादा वसूलना '
      'गैरकानूनी है, जिस पर 5 लाख रुपये तक का जुर्माना हो सकता है। '
      'कृपया केवल छपा हुआ एमआरपी ही स्वीकार करें।';

  static const String englishScript =
      'Attention please. As per Rule 18(2) of the Legal Metrology Packaged Commodities Rules 2011, '
      'Maximum Retail Price includes all taxes and refrigeration expenses. '
      'Under the Jan Vishwas Act 2023, charging an extra cooling fee above printed MRP '
      'can attract penalties up to 5 lakh rupees. Please charge only the printed MRP.';

  Future<void> _initTts() async {
    if (_initialized || _isDisposed) return;
    try {
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      await _tts.setSpeechRate(0.46);

      _tts.setStartHandler(() {
        if (_isDisposed) return;
        _state = VoicePlaybackState.playing;
        stateNotifier.value = VoicePlaybackState.playing;
        _startCountdown();
      });

      _tts.setCompletionHandler(() {
        _onPlaybackFinished();
      });

      _tts.setCancelHandler(() {
        _onPlaybackFinished();
      });

      _tts.setErrorHandler((msg) {
        debugPrint('TTS Error: $msg');
        _onPlaybackFinished();
      });

      _initialized = true;
    } catch (e) {
      debugPrint('TTS init error: $e');
    }
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    if (_isDisposed) return;
    remainingSecondsNotifier.value = totalEstimatedSeconds;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isDisposed) {
        timer.cancel();
        return;
      }
      if (remainingSecondsNotifier.value > 0) {
        remainingSecondsNotifier.value -= 1;
      } else {
        timer.cancel();
      }
    });
  }

  void _onPlaybackFinished() {
    if (_isDisposed) return;
    _countdownTimer?.cancel();
    remainingSecondsNotifier.value = totalEstimatedSeconds;
    _state = VoicePlaybackState.stopped;
    stateNotifier.value = VoicePlaybackState.stopped;
  }

  Future<void> setLanguage(VoiceLanguage lang) async {
    if (_isDisposed) return;
    if (_currentLanguage == lang && _initialized) return;

    if (isPlaying) {
      await stop();
    }

    _currentLanguage = lang;
    if (_isDisposed) return;
    languageNotifier.value = lang;

    await _initTts();
    if (_isDisposed) return;

    try {
      if (lang == VoiceLanguage.hindi) {
        await _tts.setLanguage('hi-IN');
      } else {
        await _tts.setLanguage('en-IN');
      }
    } catch (e) {
      debugPrint('Failed to set TTS language: $e');
    }
  }

  Future<bool> play({VoiceLanguage? language}) async {
    if (_isDisposed) return false;
    await _initTts();
    if (_isDisposed) return false;

    if (language != null) {
      await setLanguage(language);
      if (_isDisposed) return false;
    }

    final script = _currentLanguage == VoiceLanguage.hindi
        ? hindiScript
        : englishScript;

    // Apply specific rate based on language for crisp authoritative voice
    try {
      if (_currentLanguage == VoiceLanguage.hindi) {
        await _tts.setLanguage('hi-IN');
        await _tts.setSpeechRate(0.48);
      } else {
        await _tts.setLanguage('en-IN');
        await _tts.setSpeechRate(0.45);
      }
    } catch (e) {
      debugPrint('TTS language setting error: $e');
    }

    if (_isDisposed) return false;

    try {
      final result = await _tts.speak(script);
      if (_isDisposed) return false;

      if (result == 1 || result == true) {
        _state = VoicePlaybackState.playing;
        stateNotifier.value = VoicePlaybackState.playing;
        _startCountdown();
        return true;
      } else {
        _onPlaybackFinished();
      }
    } catch (e) {
      debugPrint('TTS speak error: $e');
      _onPlaybackFinished();
    }
    return false;
  }

  Future<void> stop() async {
    if (_isDisposed) return;
    try {
      await _tts.stop();
    } catch (e) {
      debugPrint('TTS stop error: $e');
    } finally {
      _onPlaybackFinished();
    }
  }

  void dispose() {
    _isDisposed = true;
    _countdownTimer?.cancel();
    try {
      _tts.stop();
    } catch (_) {}
    stateNotifier.dispose();
    languageNotifier.dispose();
    remainingSecondsNotifier.dispose();
  }
}
