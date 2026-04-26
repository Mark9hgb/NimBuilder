import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import '../providers/chat_providers.dart';
import '../services/terminal_service.dart';
import '../theme/app_theme.dart';

class CodeEditorScreen extends ConsumerStatefulWidget {
  const CodeEditorScreen({super.key});

  @override
  ConsumerState<CodeEditorScreen> createState() => _CodeEditorScreenState();
}

class _CodeEditorScreenState extends ConsumerState<CodeEditorScreen> {
  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _fileNameController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _currentFilePath = '';
  String _currentLanguage = 'python';
  bool _hasChanges = false;
  bool _isExecuting = false;
  List<int> _lineCount = [];

  final Map<String, String> _languageExtensions = {
    'python': 'py',
    'javascript': 'js',
    'dart': 'dart',
    'bash': 'sh',
    'rust': 'rs',
    'go': 'go',
    'java': 'java',
    'c': 'c',
    'cpp': 'cpp',
    'html': 'html',
    'css': 'css',
    'json': 'json',
    'yaml': 'yaml',
    'markdown': 'md',
    'text': 'txt',
  };

  @override
  void initState() {
    super.initState();
    _updateLineCount();
  }

  @override
  void dispose() {
    _contentController.dispose();
    _fileNameController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _updateLineCount() {
    final lines = _contentController.text.split('\n');
    _lineCount = List.generate(lines.length, (i) => i + 1);
  }

  void _onTextChanged(String text) {
    setState(() {
      _hasChanges = true;
    });
    _updateLineCount();
  }

  Future<void> _newFile() async {
    if (_hasChanges) {
      final discard = await _confirmDiscard();
      if (!discard) return;
    }
    
    setState(() {
      _contentController.clear();
      _currentFilePath = '';
      _fileNameController.clear();
      _hasChanges = false;
      _updateLineCount();
    });
  }

  Future<void> _openFile() async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _FilePickerSheet(
        onFileSelected: (path, content) {
          setState(() {
            _currentFilePath = path;
            _contentController.text = content;
            _fileNameController.text = path.split('/').last;
            _currentLanguage = _detectLanguage(path);
            _hasChanges = false;
            _updateLineCount();
          });
        },
      ),
    );
  }

  Future<void> _saveFile() async {
    String fileName = _fileNameController.text.trim();
    if (fileName.isEmpty) {
      fileName = 'untitled.${_languageExtensions[_currentLanguage]}';
      _fileNameController.text = fileName;
    }
    
    String path = _currentFilePath.isEmpty ? '\$HOME/$fileName' : _currentFilePath;
    
    final terminalService = ref.read(terminalServiceProvider);
    
    final escapedContent = _contentController.text
        .replaceAll("'", "'\\''")
        .replaceAll('\n', '\\n\n');
    
    final result = await terminalService.writeFile(path, _contentController.text);
    
    if (!mounted) return;
    
    if (result.success) {
      setState(() {
        _currentFilePath = path;
        _hasChanges = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved to $path'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${result.output}'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  Future<bool> _confirmDiscard() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('You have unsaved changes. Discard them?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _executeCode() async {
    if (_contentController.text.isEmpty) return;
    
    setState(() => _isExecuting = true);
    
    final terminalService = ref.read(terminalServiceProvider);
    final extension = _languageExtensions[_currentLanguage];
    
    try {
      if (extension == 'py') {
        final scriptName = _currentFilePath.isNotEmpty ? _currentFilePath : 'temp_script.py';
        final result = await terminalService.executeCommand('python3 $scriptName');
        _showOutput(result.output, result.success);
} else if (extension == 'js') {
        final scriptName = _currentFilePath.isNotEmpty ? _currentFilePath : 'temp_script.js';
        final result = await terminalService.executeCommand('node $scriptName');
        _showOutput(result.output, result.success);
      } else {
        final scriptName = _currentFilePath.isNotEmpty ? _currentFilePath : 'temp_script';
        final result = await terminalService.executeCommand('${_getRunCommand()} $scriptName');
        _showOutput(result.output, result.success);
      } else if (extension == 'sh') {
        final result = await terminalService.executeShellCommand(_contentController.text);
        _showOutput(result.output, result.success);
      } else {
        final result = await terminalService.executeCommand(
          '${_getRunCommand()} ${_currentFilePath.isNotEmpty ? _currentFilePath : <dynamic>('temp_script')}',
        );
        _showOutput(result.output, result.success);
      }
    } catch (e) {
      _showOutput('Error: $e', false);
    }
    
    if (mounted) setState(() => _isExecuting = false);
  }

  String _getRunCommand() {
    switch (_currentLanguage) {
      case 'rust':
        return 'cargo run';
      case 'go':
        return 'go run';
      case 'java':
        return 'java';
      case 'c':
      case 'cpp':
        return './a.out';
      default:
        return 'bash';
    }
  }

  void _showOutput(String output, bool success) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _OutputSheet(
        output: output,
        isSuccess: success,
      ),
    );
  }

  String _detectLanguage(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    for (final entry in _languageExtensions.entries) {
      if (entry.value == ext) {
        return entry.key;
      }
    }
    return 'text';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.codeBackground,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildToolbar(),
          Expanded(child: _buildEditor()),
          _buildStatusBar(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppTheme.codeBackground,
      title: Text(
        _currentFilePath.isEmpty ? 'Untitled' : _fileNameController.text,
        style: GoogleFonts.firaCode(color: AppTheme.codeText),
      ),
      actions: [
        if (_hasChanges)
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.orange.withAlpha(40),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'modified',
              style: TextStyle(color: Colors.orange, fontSize: 12),
            ),
          ),
        IconButton(
          icon: const Icon(Icons.note_add, color: AppTheme.codeText),
          onPressed: _newFile,
          tooltip: 'New file',
        ),
        IconButton(
          icon: const Icon(Icons.folder_open, color: AppTheme.codeText),
          onPressed: _openFile,
          tooltip: 'Open file',
        ),
        IconButton(
          icon: const Icon(Icons.save, color: AppTheme.codeText),
          onPressed: _saveFile,
          tooltip: 'Save',
        ),
      ],
    );
  }

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.all(8),
      color: AppTheme.codeBackground.withAlpha(240),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildLanguageChip('Python', 'python'),
                  _buildLanguageChip('JavaScript', 'javascript'),
                  _buildLanguageChip('Dart', 'dart'),
                  _buildLanguageChip('Bash', 'bash'),
                  _buildLanguageChip('Rust', 'rust'),
                  _buildLanguageChip('Go', 'go'),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          IconButton(
            icon: _isExecuting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.codeText,
                    ),
                  )
                : const Icon(Icons.play_arrow, color: Colors.green),
            onPressed: _isExecuting ? null : _executeCode,
            tooltip: 'Run code',
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageChip(String label, String language) {
    final isSelected = _currentLanguage == language;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          if (selected) {
            setState(() => _currentLanguage = language);
          }
        },
        selectedColor: AppTheme.primaryColor.withAlpha(80),
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : AppTheme.codeText,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildEditor() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 50,
          padding: const EdgeInsets.symmetric(vertical: 16),
          color: AppTheme.codeBackground.withAlpha(200),
          child: ListView.builder(
            controller: _scrollController,
            itemCount: _lineCount.length,
            itemBuilder: (context, index) {
              return Container(
                height: 20,
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  '${_lineCount[index]}',
                  style: GoogleFonts.firaCode(
                    fontSize: 13,
                    color: AppTheme.codeText.withAlpha(100),
                  ),
                ),
              );
            },
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _contentController,
              maxLines: null,
              style: GoogleFonts.firaCode(
                fontSize: 13,
                color: AppTheme.codeText,
                height: 1.54,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: _onTextChanged,
              cursorColor: AppTheme.primaryColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppTheme.codeBackground.withAlpha(200),
      child: Row(
        children: [
          Text(
            _currentLanguage.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.codeText.withAlpha(150),
            ),
          ),
          const Spacer(),
          Text(
            'Lines: ${_lineCount.length}',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.codeText.withAlpha(150),
            ),
          ),
          const SizedBox(width: 16),
          Text(
            'UTF-8',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.codeText.withAlpha(150),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilePickerSheet extends ConsumerWidget {
  final Function(String path, String content) onFileSelected;

  const _FilePickerSheet({required this.onFileSelected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filesAsync = ref.watch(filesProvider);

    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
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
              color: AppTheme.secondaryColor.withAlpha(80),
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
            child: filesAsync.when(
              data: (files) => ListView.builder(
                itemCount: files.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    leading: const Icon(Icons.insert_drive_file),
                    title: Text(files[index]),
                    onTap: () async {
                      final terminalService = ref.read(terminalServiceProvider);
                      final result = await terminalService.readFile('\$HOME/${files[index]}');
                      Navigator.pop(context);
                      onFileSelected('\$HOME/${files[index]}', result.output);
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

class _OutputSheet extends StatelessWidget {
  final String output;
  final bool isSuccess;

  const _OutputSheet({
    required this.output,
    required this.isSuccess,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.5,
      decoration: BoxDecoration(
        color: AppTheme.codeBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 16),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.codeText.withAlpha(80),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(
                isSuccess ? Icons.check_circle : Icons.error,
                color: isSuccess ? Colors.green : AppTheme.errorColor,
              ),
              const SizedBox(width: 8),
              Text(
                isSuccess ? 'Execution successful' : 'Execution failed',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.codeText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: SelectableText(
                output,
                style: GoogleFonts.firaCode(
                  fontSize: 13,
                  color: AppTheme.codeText,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}