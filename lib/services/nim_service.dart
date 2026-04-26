import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import '../models/chat_message.dart';

class NimService {
  static const String _defaultEndpoint = 'https://cloud.nvidia.com/nim/v1';
  
  final String apiKey;
  final String model;
  final String endpoint;
  final double temperature;
  final int maxTokens;
  final String? customModelId;
  
  final List<Map<String, dynamic>> _messages = [];
  final StreamController<ChatMessage> _responseController = StreamController<ChatMessage>.broadcast();
  
  Stream<ChatMessage> get responseStream => _responseController.stream;
  
  String _customSystemPrompt;

  NimService({
    required this.apiKey,
    this.model = 'meta/llama-3.1-405b-instruct',
    String? endpoint,
    this.temperature = 0.7,
    this.maxTokens = 4096,
    this.customModelId,
    String? systemPrompt,
  }) : _customSystemPrompt = systemPrompt ?? _defaultSystemPrompt,
       endpoint = endpoint ?? _defaultEndpoint {
    _initializeSystemPrompt();
  }

  static String get _defaultSystemPrompt => '''You are an AI assistant with access to a full Linux terminal via Termux on Android. Your capabilities include:

1. **File Operations**: Create, read, update, and delete files in the Termux home directory (\$HOME)
2. **Command Execution**: Run any Linux command available in Termux (bash, python, node, git, etc.)
3. **Code Execution**: Execute Python, Node.js, C, Go, Rust, or other compiled languages
4. **System Information**: Query system info, environment variables, running processes
5. **Package Management**: Use apt/apt-get to install packages within Termux
6. **Git Operations**: Clone repos, commit changes, push/pull

IMPORTANT RULES:
- Always use code blocks with \`\`\`bash for shell commands
- Use \`\`\`python for Python code, \`\`\`javascript for Node.js, etc.
- After providing code, the app will automatically execute it
- Report command output back to user with proper formatting
- Use "tool call" markers when you need to execute commands
- Never assume file contents - always read files before modifying them
- Provide explanations alongside code, not just code

When you output a code block, prefix it with "TOOL CALL:" to indicate execution.
Example format:
\`\`\`bash
ls -la \$HOME
\`\`\`

The user can see the command output in real-time in the terminal view.''';

  void setSystemPrompt(String prompt) {
    _customSystemPrompt = prompt;
    _initializeSystemPrompt();
  }

  void _initializeSystemPrompt() {
    _messages.clear();
    _messages.add({
      'role': 'system',
      'content': _customSystemPrompt,
    });
  }

  void addUserMessage(String content, {String? imageBase64, String? fileContext}) {
    final message = <String, dynamic>{
      'role': 'user',
      'content': content,
    };
    
    if (imageBase64 != null && modelSupportsVision()) {
      message['images'] = [
        {'data': imageBase64, 'format': 'base64'}
      ];
    }
    
    _messages.add(message);
  }

  void addUserMessageWithContext(String content, String fileContext) {
    final contextMessage = '''Context from files:
$fileContext

User message:
$content''';
    
    addUserMessage(contextMessage);
  }

  void addAssistantMessage(String content) {
    _messages.add({
      'role': 'assistant',
      'content': content,
    });
  }

  bool modelSupportsVision() {
    final modelInfo = NimModel.availableModels.firstWhere(
      (m) => m.id == model,
      orElse: () => const NimModel(
        id: '',
        name: '',
        displayName: '',
        description: '',
        supportsVision: false,
      ),
    );
    return modelInfo.supportsVision;
  }

  Stream<List<String>> sendMessage(String content, {String? imageBase64, String? fileContext}) async* {
    if (fileContext != null && fileContext.isNotEmpty) {
      addUserMessageWithContext(content, fileContext);
    } else {
      addUserMessage(content, imageBase64: imageBase64);
    }
    
    final responseId = DateTime.now().millisecondsSinceEpoch.toString();
    final loadingMessage = ChatMessage(
      id: responseId,
      content: '',
      isUser: false,
      timestamp: DateTime.now(),
      isLoading: true,
    );
    _responseController.add(loadingMessage);
    
    try {
      final response = await _makeApiCall();
      
      if (response.containsKey('choices')) {
        final assistantMessage = response['choices'][0]['message'];
        final content = assistantMessage['content'] as String;
        addAssistantMessage(content);
        
        final codeBlocks = _parseCodeBlocks(content);
        
        final message = ChatMessage(
          id: responseId,
          content: content,
          isUser: false,
          timestamp: DateTime.now(),
          type: codeBlocks.isNotEmpty ? MessageType.code : MessageType.text,
        );
        _responseController.add(message);
        
        yield codeBlocks;
      }
    } catch (e) {
      final errorMessage = ChatMessage(
        id: responseId,
        content: 'Error: $e',
        isUser: false,
        timestamp: DateTime.now(),
        type: MessageType.error,
      );
      _responseController.add(errorMessage);
      yield [];
    }
  }

  Stream<List<String>> sendMessageWithFileContext(String content, String filePath, String fileContent) async* {
    final fileContext = '''File: $filePath
Content:
$fileContent''';
    
    yield* sendMessage(content, fileContext: fileContext);
  }

  Future<Map<String, dynamic>> _makeApiCall() async {
    final effectiveModel = customModelId?.isNotEmpty == true ? customModelId! : model;
    final uri = Uri.parse('$endpoint/chat/completions');
    
    final body = jsonEncode({
      'model': effectiveModel,
      'messages': _messages,
      'temperature': temperature,
      'max_tokens': maxTokens,
      'stream': false,
    });
    
    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
        'Accept': 'application/json',
      },
      body: body,
    );
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('API error: ${response.statusCode} - ${response.body}');
    }
  }

  List<String> _parseCodeBlocks(String content) {
    final codeBlocks = <String>[];
    final regex = RegExp(r'```(\w+)?\n([\s\S]*?)```');
    
    for (final match in regex.allMatches(content)) {
      final language = match.group(1) ?? 'text';
      final code = match.group(2)?.trim() ?? '';
      
      if (code.isNotEmpty) {
        codeBlocks.add('$language:$code');
      }
    }
    
    return codeBlocks;
  }

  List<Map<String, dynamic>> getConversation() => List.unmodifiable(_messages);

  void clearConversation() {
    _messages.clear();
    _initializeSystemPrompt();
  }

  void loadConversation(List<Map<String, dynamic>> messages) {
    _messages.clear();
    _messages.add({
      'role': 'system',
      'content': _customSystemPrompt,
    });
    _messages.addAll(messages);
  }

  void dispose() {
    _responseController.close();
  }

  static Future<String> encodeImageBase64(String imagePath) async {
    final file = File(imagePath);
    if (!await file.exists()) {
      throw FileSystemException('Image file not found', imagePath);
    }
    
    final bytes = await file.readAsBytes();
    
    final image = img.decodeImage(bytes);
    if (image == null) {
      throw FormatException('Could not decode image');
    }
    
    final resized = img.copyResize(image, width: image.width > 1024 ? 1024 : image.width);
    final jpegBytes = img.encodeJpg(resized, quality: 80);
    
    return base64Encode(jpegBytes);
  }

  static Future<String> encodeImageFromBytes(List<int> bytes) async {
    final image = img.decodeImage(bytes);
    if (image == null) {
      throw FormatException('Could not decode image');
    }
    
    final resized = img.copyResize(image, width: image.width > 1024 ? 1024 : image.width);
    final jpegBytes = img.encodeJpg(resized, quality: 80);
    
    return base64Encode(jpegBytes);
  }
}