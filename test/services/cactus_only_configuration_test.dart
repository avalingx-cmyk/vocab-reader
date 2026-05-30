import 'package:bookbeam/providers/settings_provider.dart';
import 'package:bookbeam/services/ai_service.dart';
import 'package:bookbeam/services/cactus_local_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Cactus-only configuration', () {
    test('defaults settings to cactus provider', () {
      const state = SettingsState();

      expect(state.aiProvider, 'cactus');
      expect(state.cactusModelId, 'qwen3-0.6b');
    });

    test('only exposes qwen3-0.6b as the downloadable cactus model', () {
      expect(CactusLocalService.availableModels, hasLength(1));
      expect(CactusLocalService.availableModels.single.id, 'qwen3-0.6b');
    });

    test('does not treat local provider as configured', () {
      final service = AIService();

      service.configure(provider: 'local', localModelId: 'qwen');

      expect(service.isConfigured, isFalse);
    });
  });
}
