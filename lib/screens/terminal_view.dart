import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/chat_providers.dart';
import '../services/terminal_service.dart';
import '../theme/app_theme.dart';

class TerminalView extends ConsumerStatefulWidget {
  const TerminalView({super.key});

  @override
  ConsumerState<TerminalView> createState() => _TerminalViewState();
}

class _TerminalViewState extends ConsumerState<TerminalView> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<String> _output = [];
  final List<String> _history = [];
  int _historyIndex = -1;

  @override
  void initState() {
    super.initState();
    _output.add('NIM Builder Terminal');
    _output.add('========================');
    _output.add('Type commands and press Enter to execute');
    _output.add('');
    _output.add('\$ ');
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _executeCommand(String command) async {
    if (command.trim().isEmpty) {
      _output.add('\$ ');
      return;
    }

    _history.add(command);
    _historyIndex = _history.length;

    _output.add('\$ $command');

    final terminalService = ref.read(terminalServiceProvider);
    final result = await terminalService.executeShellCommand(command);

    _output.add(result.output);
    if (!result.output.endsWith('\n')) {
      _output.add('');
    }
    _output.add('\$ ');

    _scrollToBottom();
    setState(() {});
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
        );
      }
    });
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.terminalBackground,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(child: _buildTerminalOutput()),
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
            setState(() {
              _output.clear();
              _output.add('Terminal cleared');
              _output.add('\$ ');
            });
          },
          tooltip: 'Clear',
        ),
        IconButton(
          icon: const Icon(Icons.refresh, color: AppTheme.terminalText),
          onPressed: () {
            _output.add('Reset terminal');
            _output.add('\$ ');
          },
          tooltip: 'Reset',
        ),
      ],
    );
  }

  Widget _buildTerminalOutput() {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Container(
        color: AppTheme.terminalBackground,
        padding: const EdgeInsets.all(16),
        child: ListView.builder(
          controller: _scrollController,
          itemCount: _output.length,
          itemBuilder: (context, index) {
            return SelectableText(
              _output[index],
              style: GoogleFonts.firaCode(
                fontSize: 14,
                color: _output[index].startsWith('\$ ')
                    ? AppTheme.terminalPrompt
                    : AppTheme.terminalText,
                height: 1.4,
              ),
            );
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
                onSubmitted: _executeCommand,
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.send,
                color: _inputController.text.isEmpty 
                    ? Colors.grey 
                    : AppTheme.terminalText,
              ),
              onPressed: _inputController.text.isEmpty 
                  ? null 
                  : () => _executeCommand(_inputController.text),
            ),
          ],
        ),
      ),
    );
  }
}