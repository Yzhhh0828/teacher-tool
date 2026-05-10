import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Per-provider credentials. Each provider gets its own slot so users can
/// switch between OpenAI / Anthropic / Ollama without losing the others.
class LlmProfile {
  final String apiKey;
  final String baseUrl;
  final String model;

  const LlmProfile({this.apiKey = '', this.baseUrl = '', this.model = ''});

  LlmProfile copyWith({String? apiKey, String? baseUrl, String? model}) {
    return LlmProfile(
      apiKey: apiKey ?? this.apiKey,
      baseUrl: baseUrl ?? this.baseUrl,
      model: model ?? this.model,
    );
  }
}

class LlmSettings {
  final String provider;
  final Map<String, LlmProfile> profiles;

  const LlmSettings({
    this.provider = 'openai',
    this.profiles = const {},
  });

  LlmProfile profileFor(String name) => profiles[name] ?? const LlmProfile();
  LlmProfile get active => profileFor(provider);

  /// Sensible defaults shown in the UI as hints.
  static const Map<String, ({String baseUrl, String model})> defaults = {
    'openai': (baseUrl: 'https://api.openai.com/v1', model: 'gpt-4o-mini'),
    'anthropic':
        (baseUrl: 'https://api.anthropic.com', model: 'claude-3-5-sonnet-latest'),
    'ollama': (baseUrl: 'http://localhost:11434', model: 'llama3.2'),
  };

  LlmSettings copyWith({String? provider, Map<String, LlmProfile>? profiles}) {
    return LlmSettings(
      provider: provider ?? this.provider,
      profiles: profiles ?? this.profiles,
    );
  }

  /// "Configured" means: either Ollama (no key required) or a provider with
  /// a non-empty key.
  bool get isConfigured {
    if (provider == 'ollama') return true;
    return active.apiKey.isNotEmpty;
  }
}

class SettingsNotifier extends StateNotifier<LlmSettings> {
  static const _storage = FlutterSecureStorage();
  static const _providers = ['openai', 'anthropic', 'ollama'];

  SettingsNotifier() : super(const LlmSettings()) {
    _load();
  }

  Future<void> _load() async {
    final provider = await _storage.read(key: 'llm_provider') ?? 'openai';
    final profiles = <String, LlmProfile>{};
    for (final p in _providers) {
      profiles[p] = LlmProfile(
        apiKey: await _storage.read(key: 'llm_${p}_api_key') ?? '',
        baseUrl: await _storage.read(key: 'llm_${p}_base_url') ?? '',
        model: await _storage.read(key: 'llm_${p}_model') ?? '',
      );
    }
    // Migrate the legacy single-key layout into the openai slot if present.
    final legacyKey = await _storage.read(key: 'llm_api_key');
    final legacyBase = await _storage.read(key: 'llm_base_url');
    if ((legacyKey?.isNotEmpty ?? false) && profiles['openai']!.apiKey.isEmpty) {
      profiles['openai'] = profiles['openai']!.copyWith(
        apiKey: legacyKey,
        baseUrl: legacyBase ?? '',
      );
    }
    state = LlmSettings(provider: provider, profiles: profiles);
  }

  Future<void> save({
    required String provider,
    required String apiKey,
    required String baseUrl,
    required String model,
  }) async {
    await _storage.write(key: 'llm_provider', value: provider);
    await _storage.write(key: 'llm_${provider}_api_key', value: apiKey);
    await _storage.write(key: 'llm_${provider}_base_url', value: baseUrl);
    await _storage.write(key: 'llm_${provider}_model', value: model);
    final next = Map<String, LlmProfile>.from(state.profiles);
    next[provider] = LlmProfile(apiKey: apiKey, baseUrl: baseUrl, model: model);
    state = state.copyWith(provider: provider, profiles: next);
  }

  /// Switch the active provider without overwriting credentials.
  Future<void> selectProvider(String provider) async {
    await _storage.write(key: 'llm_provider', value: provider);
    state = state.copyWith(provider: provider);
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, LlmSettings>(
  (ref) => SettingsNotifier(),
);

/// Build the LLM headers map honouring per-provider profiles. Returns
/// `null` if the user hasn't configured anything yet (so the backend
/// falls back to env defaults).
Map<String, String>? llmHeadersFromSettings(LlmSettings s) {
  if (!s.isConfigured) return null;
  final p = s.active;
  return {
    'X-LLM-Provider': s.provider,
    if (p.apiKey.isNotEmpty) 'X-API-Key': p.apiKey,
    if (p.baseUrl.isNotEmpty) 'X-Base-URL': p.baseUrl,
    if (p.model.isNotEmpty) 'X-LLM-Model': p.model,
  };
}
