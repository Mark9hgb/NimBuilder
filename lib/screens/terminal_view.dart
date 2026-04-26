import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:xterm/xterm.dart';
import '../providers/chat_providers.dart';
import '../theme/app_theme.dart';

class TerminalView extends ConsumerStatefulWidget {
  const TerminalView({super.key});

  @override
  ConsumerState<TerminalView> createState() => _TerminalViewState();
}

class _TerminalViewState extends ConsumerState<TerminalView> {
  late TerminalController _terminalController;
  late Terminal _terminal;
  final TextEditingController _inputController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final List<String> _history = [];
  int _historyIndex = -1;

  @override
  void initState() {
    super.initState();
    _terminal = Terminal(
      maxLines: 10000,
    );
    _terminalController = TerminalController();
    _initializeTerminal();
  }

  Future<void> _initializeTerminal() async {
    final terminalService = ref.read(terminalServiceProvider);
    
    _terminal.write('NIM Builder Terminal\r\n');
    _terminal.write('─────────────────────────\r\n');
    _terminal.write('Type commands and press Enter to execute\r\n\r\n');
    
    _terminal.onOutput = (data) {
      _executeCommand(data);
    };
  }

  Future<void> _executeCommand(String command) async {
    final trimmed = command.trim();
    if (trimmed.isEmpty) return;

    _terminal.write('\r\n');
    _history.add(trimmed);
    _historyIndex = _history.length;
    
    final terminalService = ref.read(terminalServiceProvider);
    final result = await terminalService.executeShellCommand(trimmed);
    
    _terminal.write(result.output);
    if (!result.output.endsWith('\r\n')) {
      _terminal.write('\r\n');
    }
    _terminal.write('\r\n\$ ');
    
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: AppAnimations.fast,
          curve: AppAnimations.defaultCurve,
        );
      }
    });
  }

  void _handleSubmit() {
    final command = _inputController.text;
    if (command.isEmpty) return;
    
    _terminal.write('\$ $command\r\n');
    _inputController.clear();
    _executeCommand(command);
  }

  void _navigateHistory(bool up) {
    if (_history.isEmpty) return;
    
    if (up) {
      if (_historyIndex > 0) {
        _historyIndex--;
        _inputController.text = _history[_historyIndex];
        _inputController.selection = TextSelection.fromPosition(
          TextPosition(offset: _inputController.text.length),
        );
      }
    } else {
      if (_historyIndex < _history.length - 1) {
        _historyIndex++;
        _inputController.text = _history[_historyIndex];
      } else {
        _historyIndex = _history.length;
        _inputController.clear();
      }
    }
  }

  @override
  void dispose() {
    _terminalController.dispose();
    _inputController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewMode = ref.watch(currentViewModeProvider);

    return Scaffold(
      backgroundColor: AppTheme.terminalBackground,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(
            child: _buildTerminalOutput(),
          ),
          _buildInputBar(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppTheme.terminalBackground,
      title: Text(
        'Terminal',
        style: GoogleFonts.firaCode(
          color: AppTheme.terminalText,
          fontSize: 16,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.clear_all, color: AppTheme.terminalText),
          onPressed: () {
            _terminal.buffer.clear();
            _terminal.write('\x1B[2J\x1B[H');
          },
          tooltip: 'Clear',
        ),
        IconButton(
          icon: const Icon(Icons.vertical_split, color: AppTheme.terminalText),
          onPressed: _showSidePanel,
          tooltip: 'Side panel',
        ),
      ],
    );
  }

  Widget _buildTerminalOutput() {
    return GestureDetector(
      onTap: () => _focusNode.requestFocus(),
      child: Container(
        color: AppTheme.terminalBackground,
        child: TerminalView(
          terminal: _terminal,
          controller: _terminalController,
          autofocus: true,
          backgroundOpacity: 0,
          textStyle: AppTheme.terminalTextStyle,
          padding: const EdgeInsets.all(16),
          onSecondaryTapDown: (details, offset) {
            _showContextMenu(details.globalPosition);
          },
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.terminalBackground,
        border: Border(
          top: BorderSide(
            color: AppTheme.terminalText.withAlpha(40),
          ),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Text(
              '\$ ',
              style: GoogleFonts.firaCode(
                color: AppTheme.terminalPrompt,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Expanded(
              child: TextField(
                controller: _inputController,
                focusNode: _focusNode,
                style: GoogleFonts.firaCode(
                  color: AppTheme.terminalText,
                  fontSize: 14,
                ),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Enter command...',
                  hintStyle: TextStyle(color: Colors.grey),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
                cursorColor: AppTheme.terminalText,
                keyboardType: TextInputType.text,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _handleSubmit(),
                onChanged: (_) => _historyIndex = _history.length,
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.send,
                color: _inputController.text.isEmpty 
                    ? Colors.grey 
                    : AppTheme.terminalText,
              ),
              onPressed: _inputController.text.isEmpty ? null : _handleSubmit,
            ),
          ],
        ),
      ),
    );
  }

  void _showContextMenu(Offset position) {
    final overlay = Overlay.of(context);
    final renderBox = context.findRenderObject() as RenderBox;
    final offset = renderBox.globalToLocal(position);

    final entry = OverlayEntry(
      builder: (context) => Positioned(
        left: offset.dx,
        top: offset.dy,
        child: Material(
          color: Colors.transparent,
          child: PopupMenuButton<String>(
            icon: const Icon(Icons.add_moderator),
            offset: Offset.zero,
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'clear', child: Text('Clear')),
              const PopupMenuItem(value: 'copy', child: Text('Copy')),
              const PopupMenuItem(value: 'paste', child: Text('Paste')),
            ],
            onSelected: (value) {
              switch (value) {
                case 'clear':
                  _terminal.buffer.clear();
                  break;
                case 'copy':
                  break;
                case 'paste':
                  break;
              }
            },
          ),
        ),
      ),
    );

    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 2), () => entry.remove());
  }

  void _showSidePanel() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _SidePanelSheet(),
    );
  }
}

class _SidePanelSheet extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final files = ref.watch(filesProvider);

    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 16),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.secondaryColor.withAlpha(80),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Quick Commands',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: files.when(
              data: (fileList) => ListView.builder(
                itemCount: fileList.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    leading: const Icon(Icons.insert_drive_file),
                    title: Text(fileList[index]),
                    onTap: () {
                      Navigator.pop(context);
                    },
                  );
                },
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }
}