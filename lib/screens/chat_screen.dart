import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/chat_message.dart';
import '../providers/chat_providers.dart';
import '../services/settings_service.dart';
import '../services/nim_service.dart';
import '../services/url_service.dart';
import '../theme/app_theme.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final ImagePicker _imagePicker = ImagePicker();
  
  String? _selectedImageBase64;
  String? _selectedFilePath;
  String _selectedFileContent = '';
  bool _isTyping = false;
  String _currentModel = 'meta/llama-3.1-405b-instruct';

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    final settings = ref.read(nimSettingsProvider);
    setState(() {
      _currentModel = settings.model;
    });
    
    final terminalService = ref.read(terminalServiceProvider);
    await terminalService.initialize();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: AppAnimations.medium,
          curve: AppAnimations.defaultCurve,
        );
      }
    });
  }

  Future<void> _pickImage() async {
    final XFile? image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 80,
    );
    
    if (image != null) {
      final base64 = await NimService.encodeImageBase64(image.path);
      setState(() => _selectedImageBase64 = base64);
    }
  }

  Future<void> _pickFile() async {
    final terminalService = ref.read(terminalServiceProvider);
    final files = await terminalService.getGeneratedFiles();
    
    if (files.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No files found')),
      );
      return;
    }
    
    final selectedFile = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => _FilePickerSheet(files: files),
    );
    
    if (selectedFile != null) {
      final result = await terminalService.readFile('\$HOME/$selectedFile');
      setState(() {
        _selectedFilePath = selectedFile;
        _selectedFileContent = result.output;
      });
    }
  }

  void _clearAttachments() {
    setState(() {
      _selectedImageBase64 = null;
      _selectedFilePath = null;
      _selectedFileContent = '';
    });
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty && _selectedImageBase64 == null) return;

    _messageController.clear();
    _focusNode.unfocus();
    
    setState(() => _isTyping = true);

    final terminalService = ref.read(terminalServiceProvider);
    final nimService = await ref.read(nimServiceProvider.future);
    
    final userMessage = ChatMessage(
      id: const Uuid().v4(),
      content: content,
      isUser: true,
      timestamp: DateTime.now(),
      imageBase64: _selectedImageBase64,
      fileContext: _selectedFilePath != null
          ? 'File: $_selectedFilePath\nContent:\n$_selectedFileContent'
          : null,
    );
    
    ref.read(chatMessagesProvider.notifier).addMessage(userMessage);
    
    _clearAttachments();
    _scrollToBottom();
    
    await for (final codeBlocks in nimService.sendMessage(
      content,
      imageBase64: _selectedImageBase64,
      fileContext: _selectedFileContent.isNotEmpty ? _selectedFileContent : null,
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
          
          ref.read(chatMessagesProvider.notifier).addMessage(resultMessage);
          ref.invalidate(filesProvider);
        }
      }
    }
    
    setState(() => _isTyping = false);
    _scrollToBottom();
  }

  List<String> _extractCodeBlocks(String content) {
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

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(chatMessagesProvider);
    final viewMode = ref.watch(currentViewModeProvider);

    return Scaffold(
      appBar: _buildAppBar(),
      body: Column(
        children: [
          if (_selectedImageBase64 != null || _selectedFilePath != null)
            _buildAttachmentBar(),
          Expanded(
            child: messages.isEmpty
                ? _buildEmptyState()
                : _buildMessageList(messages),
          ),
          if (_isTyping)
            _buildTypingIndicator(),
          _buildInputBar(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.smart_toy,
              color: Theme.of(context).colorScheme.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'NIM Builder',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                _currentModel.split('/').last,
                style: TextStyle(
                  fontSize: 10,
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        PopupMenuButton<String>(
          icon: const Icon(Icons.model_training),
          tooltip: 'Change Model',
          onSelected: (model) {
            setState(() => _currentModel = model);
            ref.read(nimSettingsProvider.notifier).updateModel(model);
          },
          itemBuilder: (context) => NimModel.availableModels.map((model) {
            return PopupMenuItem(
              value: model.id,
              child: ListTile(
                title: Text(model.displayName),
                subtitle: Text(model.description),
                leading: Icon(
                  _currentModel == model.id
                      ? Icons.check_circle
                      : Icons.circle_outlined,
                ),
              ),
            );
          }).toList(),
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: () => ref.read(chatMessagesProvider.notifier).clearMessages(),
          tooltip: 'Clear chat',
        ),
      ],
    );
  }

  Widget _buildAttachmentBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Row(
        children: [
          if (_selectedImageBase64 != null)
            Chip(
              avatar: const Icon(Icons.image, size: 16),
              label: const Text('Image attached'),
              onDeleted: _clearAttachments,
            ),
          if (_selectedFilePath != null)
            Chip(
              avatar: const Icon(Icons.insert_drive_file, size: 16),
              label: Text(_selectedFilePath!.split('/').last),
              onDeleted: _clearAttachments,
            ),
        ],
      ),
    ).animate().slideY(begin: -1);
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer.withAlpha(100),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.smart_toy_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
          ).animate().scale(duration: AppAnimations.medium),
          const SizedBox(height: 24),
          Text(
            'AI + Terminal',
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.w600,
            ),
          ).animate().fadeIn(delay: AppAnimations.fast),
          const SizedBox(height: 8),
          Text(
            _currentModel.split('/').last,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Theme.of(context).colorScheme.secondary,
            ),
          ).animate().fadeIn(delay: AppAnimations.medium),
          const SizedBox(height: 32),
          _buildQuickActions(),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    final actions = [
      ('List files', 'ls -la \$HOME'),
      ('System info', 'uname -a'),
      ('Storage', 'df -h'),
      ('Processes', 'ps aux'),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: actions.map((action) {
        return ActionChip(
          avatar: const Icon(Icons.terminal, size: 16),
          label: Text(action.$1),
          onPressed: () => _executeQuickCommand(action.$2),
        );
      }).toList(),
    ).animate().fadeIn(delay: AppAnimations.slow);
  }

  Future<void> _executeQuickCommand(String command) async {
    final terminalService = ref.read(terminalServiceProvider);
    final result = await terminalService.executeShellCommand(command);
    
    ref.read(chatMessagesProvider.notifier).addMessage(
      ChatMessage(
        id: const Uuid().v4(),
        content: result.output,
        isUser: false,
        timestamp: DateTime.now(),
        type: MessageType.command,
        code: command,
      ),
    );
    _scrollToBottom();
  }

  Widget _buildMessageList(List<ChatMessage> messages) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        return _MessageBubble(
          message: message,
          onExecute: () => _executeCode(message.code ?? ''),
        ).animate().fadeIn(duration: AppAnimations.fast);
      },
    );
  }

  Future<void> _executeCode(String code) async {
    if (code.isEmpty) return;
    
    final terminalService = ref.read(terminalServiceProvider);
    final result = await terminalService.executeShellCommand(code);
    
    ref.read(chatMessagesProvider.notifier).addMessage(
      ChatMessage(
        id: const Uuid().v4(),
        content: result.output,
        isUser: false,
        timestamp: DateTime.now(),
        type: MessageType.command,
        code: code,
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _TypingDot(),
                const SizedBox(width: 4),
                _TypingDot(delay: 100),
                const SizedBox(width: 4),
                _TypingDot(delay: 200),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(20),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            IconButton(
              icon: const Icon(Icons.image),
              onPressed: _pickImage,
              tooltip: 'Attach image',
            ),
            IconButton(
              icon: const Icon(Icons.attach_file),
              onPressed: _pickFile,
              tooltip: 'Attach file',
            ),
            Expanded(
              child: TextField(
                controller: _messageController,
                focusNode: _focusNode,
                decoration: InputDecoration(
                  hintText: 'Message AI or enter command...',
                  prefixIcon: const Icon(Icons.send),
                ),
                style: GoogleFonts.inter(),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                maxLines: null,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.send),
                onPressed: _sendMessage,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends ConsumerWidget {
  final ChatMessage message;
  final VoidCallback? onExecute;

  const _MessageBubble({
    required this.message,
    this.onExecute,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isUser = message.isUser;
    
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: EdgeInsets.only(
          left: isUser ? 16 : 12,
          right: isUser ? 12 : 16,
          top: 12,
          bottom: 12,
        ),
        decoration: BoxDecoration(
          color: isUser
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isUser ? 20 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 20),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.type == MessageType.code || message.type == MessageType.command)
              _buildCodeContent(context)
            else
              _buildTextContent(context),
            const SizedBox(height: 8),
            Text(
              _formatTimestamp(message.timestamp),
              style: TextStyle(
                fontSize: 10,
                color: isUser
                    ? Theme.of(context).colorScheme.onPrimary.withAlpha(180)
                    : Theme.of(context).colorScheme.secondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextContent(BuildContext context) {
    final isUser = message.isUser;
    final content = message.content;
    
    final urlRegex = RegExp(r'https?://[^\s]+');
    final hasUrl = urlRegex.hasMatch(content);
    
    if (!hasUrl) {
      return SelectableText(
        content,
        style: GoogleFonts.inter(
          color: isUser
              ? Theme.of(context).colorScheme.onPrimary
              : Theme.of(context).colorScheme.onSurface,
          height: 1.4,
        ),
      );
    }

    final spans = <InlineSpan>[];
    int lastEnd = 0;

    for (final match in urlRegex.allMatches(content)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: content.substring(lastEnd, match.start),
          style: GoogleFonts.inter(
            color: isUser
                ? Theme.of(context).colorScheme.onPrimary
                : Theme.of(context).colorScheme.onSurface,
          ),
        ));
      }
      
      final url = match.group(0)!;
      spans.add(TextSpan(
        text: url,
        style: GoogleFonts.inter(
          color: Colors.blue,
          decoration: TextDecoration.underline,
        ),
        recognizer: TapGestureRecognizer()..onTap = () => _openUrl(url),
      ));
      
      lastEnd = match.end;
    }

    if (lastEnd < content.length) {
      spans.add(TextSpan(
        text: content.substring(lastEnd),
        style: GoogleFonts.inter(
          color: isUser
              ? Theme.of(context).colorScheme.onPrimary
              : Theme.of(context).colorScheme.onSurface,
        ),
      ));
    }

    return RichText(
      text: TextSpan(children: spans),
    );
  }

  Widget _buildCodeContent(BuildContext context) {
    final code = message.code ?? message.content;
    final language = _detectLanguage(code);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _getLanguageColor(language).withAlpha(40),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            language.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: _getLanguageColor(language),
            ),
          ),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: HighlightView(
            code,
            language: language,
            theme: atomOneDarkTheme,
            padding: const EdgeInsets.all(12),
            textStyle: AppTheme.codeTextStyle,
          ),
        ),
        if (onExecute != null && message.type == MessageType.command) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.play_arrow, size: 16),
                onPressed: onExecute,
                tooltip: 'Run again',
              ),
              IconButton(
                icon: const Icon(Icons.copy, size: 16),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: code));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Copied to clipboard')),
                  );
                },
                tooltip: 'Copy',
              ),
            ],
          ),
        ],
      ],
    );
  }

  String _detectLanguage(String code) {
    if (code.startsWith('#!') || code.startsWith('ls ') || code.startsWith('cd ')) {
      return 'bash';
    }
    if (code.contains('def ') || code.contains('import ')) {
      return 'python';
    }
    if (code.contains('function') || code.contains('const ') || code.contains('=>')) {
      return 'javascript';
    }
    return 'bash';
  }

  Color _getLanguageColor(String language) {
    final colors = {
      'bash': const Color(0xFF4A154B),
      'python': const Color(0xFF3776AB),
      'javascript': const Color(0xFFF7DF1E),
    };
    return colors[language] ?? AppTheme.primaryColor;
  }

  String _formatTimestamp(DateTime timestamp) {
    return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
  }
}

class _TypingDot extends StatefulWidget {
  final int delay;
  
  const _TypingDot({this.delay = 0});

  @override
  State<_TypingDot> createState() => _TypingDotState();
}

class _TypingDotState extends State<_TypingDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) {
        _controller.repeat(reverse: true);
      }
    });
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withAlpha((100 + _controller.value * 155).toInt()),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }
}

class _FilePickerSheet extends StatelessWidget {
  final List<String> files;
  
  const _FilePickerSheet({required this.files});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.5,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 16),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondary.withAlpha(80),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Select File',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: files.length,
              itemBuilder: (context, index) {
                return ListTile(
                  leading: Icon(_getFileIcon(files[index])),
                  title: Text(files[index]),
                  onTap: () => Navigator.pop(context, files[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  IconData _getFileIcon(String name) {
    final ext = name.split('.').last.toLowerCase();
    final icons = {
      'py': Icons.code,
      'js': Icons.code,
      'dart': Icons.code,
      'txt': Icons.text_snippet,
      'md': Icons.article,
      'json': Icons.data_object,
    };
    return icons[ext] ?? Icons.insert_drive_file;
  }
}