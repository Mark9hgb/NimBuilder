import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/chat_message.dart';
import '../services/terminal_service.dart';
import '../services/nim_service.dart';
import '../services/database_service.dart';
import '../services/settings_service.dart';

final databaseServiceProvider = Provider<DatabaseService>((ref) {
  return DatabaseService();
});

final terminalServiceProvider = Provider<TerminalService>((ref) {
  final service = TerminalService();
  ref.onDispose(() => service.dispose());
  return service;
});

final settingsServiceProvider = Provider<SettingsService>((ref) {
  return SettingsService();
});

final urlServiceProvider = Provider<UrlService>((ref) {
  return UrlService();
});

final performanceServiceProvider = Provider<PerformanceService>((ref) {
  return PerformanceService();
});

final nimSettingsProvider = StateNotifierProvider<NimSettingsNotifier, NimSettings>((ref) {
  return NimSettingsNotifier(ref);
});

class NimSettingsNotifier extends StateNotifier<NimSettings> {
  final Ref _ref;
  
  NimSettingsNotifier(this._ref) : super(NimSettings()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settingsService = _ref.read(settingsServiceProvider);
    state = await settingsService.loadSettings();
  }

  Future<void> updateApiKey(String apiKey) async {
    state = state.copyWith(apiKey: apiKey);
    await _ref.read(settingsServiceProvider).saveApiKey(apiKey);
  }

  Future<void> updateModel(String model, {String? customModelId}) async {
    state = state.copyWith(model: model, customModelId: customModelId);
    await _ref.read(settingsServiceProvider).saveModel(model);
    if (customModelId != null) {
      await _ref.read(settingsServiceProvider).saveCustomModelId(customModelId!);
    }
  }

  Future<void> setDarkMode(bool value) async {
    state = state.copyWith(isDarkMode: value);
    final settingsService = _ref.read(settingsServiceProvider);
    await settingsService.setDarkMode(value);
  }

  Future<void> setCurrentPersona(String? personaId) async {
    state = state.copyWith(currentPersonaId: personaId);
    await _ref.read(settingsServiceProvider).saveCurrentPersonaId(personaId);
  }
}

final nimServiceProvider = FutureProvider<NimService>((ref) async {
  final settings = ref.watch(nimSettingsProvider);
  if (settings.apiKey.isEmpty) {
    throw Exception('API key not configured');
  }
  
  final dbService = ref.read(databaseServiceProvider);
  String? systemPrompt;
  
  if (settings.currentPersonaId != null) {
    final persona = await dbService.getPersona(settings.currentPersonaId!);
    systemPrompt = persona?.systemPrompt;
  }
  
  return NimService(
    apiKey: settings.apiKey,
    model: settings.model,
    endpoint: settings.endpoint,
    temperature: settings.temperature,
    maxTokens: settings.maxTokens,
    customModelId: settings.customModelId.isEmpty ? null : settings.customModelId,
    systemPrompt: systemPrompt,
  );
});

final chatMessagesProvider = StateNotifierProvider<ChatMessagesNotifier, List<ChatMessage>>((ref) {
  return ChatMessagesNotifier(ref);
});

class ChatMessagesNotifier extends StateNotifier<List<ChatMessage>> {
  final Ref _ref;
  String _currentSessionId = '';
  
  ChatMessagesNotifier(this._ref) : super([]);

  String get currentSessionId => _currentSessionId;

  Future<void> loadSession(String sessionId) async {
    if (sessionId.isEmpty) {
      _currentSessionId = '';
      state = [];
      return;
    }
    
    _currentSessionId = sessionId;
    final dbService = _ref.read(databaseServiceProvider);
    final messages = await dbService.getMessagesForSession(sessionId);
    state = messages;
  }

  Future<String> createNewSession({String? title, String? model, String? personaId}) async {
    final dbService = _ref.read(databaseServiceProvider);
    final sessionId = const Uuid().v4();
    
    final session = ChatSession(
      id: sessionId,
      title: title ?? 'New Chat',
      createdAt: DateTime.now(),
      lastMessageAt: DateTime.now(),
      model: model ?? 'meta/llama-3.1-405b-instruct',
      personaId: personaId,
    );
    
    await dbService.createSession(session);
    _currentSessionId = sessionId;
    state = [];
    
    return sessionId;
  }

  Future<void> sendMessage(String content, {String? imageBase64, String? fileContext}) async {
    if (_currentSessionId.isEmpty) {
      await createNewSession();
    }
    
    final userMessage = ChatMessage(
      id: const Uuid().v4(),
      content: content,
      isUser: true,
      timestamp: DateTime.now(),
      imageBase64: imageBase64,
      fileContext: fileContext,
    );
    
    state = [...state, userMessage];
    
    final dbService = _ref.read(databaseServiceProvider);
    await dbService.saveMessage(userMessage, _currentSessionId);
  }

  Future<void> sendMessageWithAi(String content, {String? imageBase64, String? fileContext}) async {
    if (_currentSessionId.isEmpty) {
      await createNewSession();
    }
    
    final userMessage = ChatMessage(
      id: const Uuid().v4(),
      content: content,
      isUser: true,
      timestamp: DateTime.now(),
      imageBase64: imageBase64,
      fileContext: fileContext,
    );
    
    state = [...state, userMessage];
    
    final dbService = _ref.read(databaseServiceProvider);
    await dbService.saveMessage(userMessage, _currentSessionId);
    
    final nimService = await _ref.read(nimServiceProvider.future);
    final terminalService = _ref.read(terminalServiceProvider);
    
    await for (final codeBlocks in nimService.sendMessage(
      content,
      imageBase64: imageBase64,
      fileContext: fileContext,
    )) {
      for (final block in codeBlocks) {
        final separatorIndex = block.indexOf(':');
        if (separatorIndex == -1) continue;
        
        final language = block.substring(0, separatorIndex);
        final code = block.substring(separatorIndex + 1);
        
        if (language == 'bash' || language == 'sh' || language == 'shell') {
          final result = await terminalService.executeShellCommand(code);
          
          final resultMessage = ChatMessage(
            id: const Uuid().v4(),
            content: result.output,
            isUser: false,
            timestamp: DateTime.now(),
            type: MessageType.command,
            code: code,
          );
          
          state = [...state, resultMessage];
          await dbService.saveMessage(resultMessage, _currentSessionId);
        }
      }
    }
  }

  void addMessage(ChatMessage message) {
    state = [...state, message];
  }

  void updateMessage(String id, ChatMessage Function(ChatMessage) update) {
    state = state.map((msg) => msg.id == id ? update(msg) : msg).toList();
  }

  void clearMessages() {
    state = [];
  }

  Future<void> deleteSession(String sessionId) async {
    final dbService = _ref.read(databaseServiceProvider);
    await dbService.deleteSession(sessionId);
    if (_currentSessionId == sessionId) {
      _currentSessionId = '';
      state = [];
    }
  }
}

final allSessionsProvider = FutureProvider<List<ChatSession>>((ref) async {
  final dbService = ref.watch(databaseServiceProvider);
  return dbService.getAllSessions();
});

final allPersonasProvider = FutureProvider<List<AiPersona>>((ref) async {
  final dbService = ref.watch(databaseServiceProvider);
  return dbService.getAllPersonas();
});

final selectedModelProvider = StateProvider<String>((ref) => 'meta/llama-3.1-405b-instruct');

final customModelIdProvider = StateProvider<String>((ref) => '');

final currentPersonaIdProvider = StateProvider<String?>((ref) => null);

enum ViewMode { chat, terminal, files, processes, editor, performance }

final currentViewModeProvider = StateProvider<ViewMode>((ref) => ViewMode.chat);

final isTermuxAvailableProvider = FutureProvider<bool>((ref) async {
  final terminalService = ref.watch(terminalServiceProvider);
  await terminalService.initialize();
  return terminalService.isTermuxAvailable;
});

final isLoadingProvider = StateProvider<bool>((ref) => false);

final terminalOutputProvider = StreamProvider<String>((ref) {
  final terminalService = ref.watch(terminalServiceProvider);
  return terminalService.outputStream;
});

final filesProvider = FutureProvider<List<String>>((ref) async {
  final terminalService = ref.watch(terminalServiceProvider);
  return terminalService.getGeneratedFiles();
});

final processesProvider = FutureProvider<List<ProcessInfo>>((ref) async {
  final terminalService = ref.watch(terminalServiceProvider);
  return terminalService.getProcesses();
});

final environmentVariablesProvider = FutureProvider<List<EnvironmentVariable>>((ref) async {
  final terminalService = ref.watch(terminalServiceProvider);
  return terminalService.getEnvironmentVariables();
});

final backgroundJobsProvider = StreamProvider<BackgroundJob>((ref) {
  final terminalService = ref.watch(terminalServiceProvider);
  return terminalService.jobStream;
});