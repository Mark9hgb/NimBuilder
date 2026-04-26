import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_message.dart';

class SettingsService {
  static const String _apiKeyKey = 'nim_api_key';
  static const String _modelKey = 'nim_model';
  static const String _customModelKey = 'nim_custom_model';
  static const String _endpointKey = 'nim_endpoint';
  static const String _temperatureKey = 'nim_temperature';
  static const String _maxTokensKey = 'nim_max_tokens';
  static const String _isDarkModeKey = 'is_dark_mode';
  static const String _currentPersonaKey = 'current_persona_id';
  static const String _currentSessionKey = 'current_session_id';

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );

  Future<NimSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    final apiKey = await _secureStorage.read(key: _apiKeyKey);
    final model = prefs.getString(_modelKey) ?? 'meta/llama-3.1-405b-instruct';
    final customModel = prefs.getString(_customModelKey) ?? '';
    final endpoint = prefs.getString(_endpointKey) ?? 'https://cloud.nvidia.com/nim/v1';
    final temperature = prefs.getDouble(_temperatureKey) ?? 0.7;
    final maxTokens = prefs.getInt(_maxTokensKey) ?? 4096;
    final isDarkMode = prefs.getBool(_isDarkModeKey) ?? false;
    final currentPersonaId = prefs.getString(_currentPersonaKey);

    return NimSettings(
      apiKey: apiKey ?? '',
      model: model,
      customModelId: customModel,
      endpoint: endpoint,
      temperature: temperature,
      maxTokens: maxTokens,
      isDarkMode: isDarkMode,
      currentPersonaId: currentPersonaId,
    );
  }

  Future<void> saveSettings(NimSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    
    if (settings.apiKey.isNotEmpty) {
      await _secureStorage.write(key: _apiKeyKey, value: settings.apiKey);
    }
    
    await prefs.setString(_modelKey, settings.model);
    await prefs.setString(_customModelKey, settings.customModelId);
    await prefs.setString(_endpointKey, settings.endpoint);
    await prefs.setDouble(_temperatureKey, settings.temperature);
    await prefs.setInt(_maxTokensKey, settings.maxTokens);
    await prefs.setBool(_isDarkModeKey, settings.isDarkMode);
    
    if (settings.currentPersonaId != null) {
      await prefs.setString(_currentPersonaKey, settings.currentPersonaId!);
    }
  }

  Future<void> saveApiKey(String apiKey) async {
    await _secureStorage.write(key: _apiKeyKey, value: apiKey);
  }

  Future<String?> getApiKey() async {
    return _secureStorage.read(key: _apiKeyKey);
  }

  Future<void> saveModel(String model) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modelKey, model);
  }

  Future<String> getModel() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_modelKey) ?? 'meta/llama-3.1-405b-instruct';
  }

  Future<void> saveCustomModelId(String modelId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_customModelKey, modelId);
  }

  Future<String> getCustomModelId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_customModelKey) ?? '';
  }

  Future<bool> isDarkMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isDarkModeKey) ?? false;
  }

  Future<void> setDarkMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isDarkModeKey, value);
  }

  Future<void> saveCurrentPersonaId(String? personaId) async {
    final prefs = await SharedPreferences.getInstance();
    if (personaId != null) {
      await prefs.setString(_currentPersonaKey, personaId);
    } else {
      await prefs.remove(_currentPersonaKey);
    }
  }

  Future<String?> getCurrentPersonaId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_currentPersonaKey);
  }

  Future<void> saveCurrentSessionId(String? sessionId) async {
    final prefs = await SharedPreferences.getInstance();
    if (sessionId != null) {
      await prefs.setString(_currentSessionKey, sessionId);
    } else {
      await prefs.remove(_currentSessionKey);
    }
  }

  Future<String?> getCurrentSessionId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_currentSessionKey);
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await _secureStorage.deleteAll();
  }
}

final settingsServiceProvider = Provider<SettingsService>((ref) {
  return SettingsService();
});

final nimSettingsProvider = FutureProvider<NimSettings>((ref) async {
  final settingsService = ref.watch(settingsServiceProvider);
  return settingsService.loadSettings();
});

final isDarkModeProvider = StateNotifierProvider<IsDarkModeNotifier, bool>((ref) {
  return IsDarkModeNotifier(ref);
});

class IsDarkModeNotifier extends StateNotifier<bool> {
  final Ref _ref;
  
  IsDarkModeNotifier(this._ref) : super(false) {
    _loadInitialValue();
  }

  Future<void> _loadInitialValue() async {
    final settingsService = _ref.read(settingsServiceProvider);
    state = await settingsService.isDarkMode();
  }

  Future<void> toggle() async {
    final newValue = !state;
    final settingsService = _ref.read(settingsServiceProvider);
    await settingsService.setDarkMode(newValue);
    state = newValue;
  }

  Future<void> set(bool value) async {
    final settingsService = _ref.read(settingsServiceProvider);
    await settingsService.setDarkMode(value);
    state = value;
  }
}

final selectedModelProvider = StateProvider<String>((ref) => 'meta/llama-3.1-405b-instruct');

final customModelIdProvider = StateProvider<String>((ref) => '');

final currentPersonaIdProvider = StateProvider<String?>((ref) => null);