import 'package:flutter_test/flutter_test.dart';
import 'package:priceshield/features/deescalation/services/deescalation_voice_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DeescalationVoiceService Script & Constants Tests', () {
    test('Hindi regulatory script contains required legal citations', () {
      final script = DeescalationVoiceService.hindiScript;
      expect(script, contains('नियम 18(2)'));
      expect(script, contains('विधिक मापविज्ञान'));
      expect(script, contains('जन विश्वास अधिनियम 2023'));
      expect(script, contains('एमआरपी'));
      expect(script, contains('कूलिंग और फ्रिज'));
      expect(script, contains('5 लाख रुपये'));
    });

    test('English regulatory script contains required legal citations', () {
      final script = DeescalationVoiceService.englishScript;
      expect(script, contains('Rule 18(2)'));
      expect(script, contains('Legal Metrology Packaged Commodities Rules 2011'));
      expect(script, contains('Jan Vishwas Act 2023'));
      expect(script, contains('refrigeration expenses'));
      expect(script, contains('5 lakh rupees'));
      expect(script, contains('printed MRP'));
    });

    test('Estimated duration constant is 15 seconds', () {
      expect(DeescalationVoiceService.totalEstimatedSeconds, 15);
    });

    test('DeescalationVoiceService initializes with correct defaults and disposes cleanly', () {
      final service = DeescalationVoiceService();
      expect(service.state, VoicePlaybackState.stopped);
      expect(service.currentLanguage, VoiceLanguage.hindi);
      expect(service.isPlaying, isFalse);
      expect(service.remainingSecondsNotifier.value, 15);
      expect(service.isDisposed, isFalse);

      // Safe disposal
      service.dispose();
      expect(service.isDisposed, isTrue);

      // Post-disposal safe operations
      expect(() => service.stop(), returnsNormally);
      expect(() => service.setLanguage(VoiceLanguage.english), returnsNormally);
    });
  });
}
