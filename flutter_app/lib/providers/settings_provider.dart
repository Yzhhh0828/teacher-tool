import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class LlmSettings {
  final String provider;
  final String apiKey;
  final String baseUrl;

  const LlmSettings({
    this.provider = 'openai',
    this.apiKey = '',
    this.baseUrl = '',
  });

  LlmSettings copyWith({String? provider, String? apiKey, String? baseUrl}) {
    return LlmSettings(
      provider: provider ?? this.provider,
      apiKey: apiKey ?? this.apiKey,
      baseUrl: baseUrl ?? this.baseUrl,
    );
  }

  bool get isConfigured => apiKey.isNotEmpty;
}

class SettingsNotifier extends StateNotifier<LlmSettings> {
  static const _storage = FlutterSecureStorage();

  SettingsNotifier() : super(const LlmSettings()) {
    _load();
  }

  Future<void> _load() async {
    final provider = await _storage.read(key: 'llm_provider') ?? 'openai';
    final apiKey = await _storage.read(key: 'llm_api_key') ?? '';
    final baseUrl = await _storage.read(key: 'llm_base_url') ?? '';
    state = LlmSettings(provider: provider, apiKey: apiKey, baseUrl: baseUrl);
  }

  Future<void> save({required String provider, required String apiKey, required String baseUrl}) async {
    await _storage.write(key: 'llm_provider', value: provider);
    await _storage.write(key: 'llm_api_key', value: apiKey);
    await _storage.write(key: 'llm_base_url', value: baseUrl);
    state = LlmSettings(provider: provider, apiKey: apiKey, baseUrl: baseUrl);
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, LlmSettings>(
  (ref) => SettingsNotifier(),
);
