import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/chat_message.dart';
import '../providers/chat_providers.dart';
import '../theme/app_theme.dart';

class FileExplorerScreen extends ConsumerStatefulWidget {
  const FileExplorerScreen({super.key});

  @override
  ConsumerState<FileExplorerScreen> createState() => _FileExplorerScreenState();
}

class _FileExplorerScreenState extends ConsumerState<FileExplorerScreen> {
  String _currentPath = '\$HOME';
  final List<FileItem> _files = [];
  bool _isLoading = true;
  final TextEditingController _pathController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _pathController.text = _currentPath;
    _loadFiles();
  }

  @override
  void dispose() {
    _pathController.dispose();
    super.dispose();
  }

  Future<void> _loadFiles() async {
    setState(() => _isLoading = true);
    
    final terminalService = ref.read(terminalServiceProvider);
    final files = await terminalService.listDirectory(_currentPath);
    
    setState(() {
      _files.clear();
      _files.addAll(files);
      _isLoading = false;
    });
  }

  Future<void> _navigateTo(String path) async {
    setState(() {
      _currentPath = path;
      _pathController.text = path;
      _isLoading = true;
    });
    
    await _loadFiles();
  }

  Future<void> _createNewFile() async {
    final name = await _showNameDialog('File');
    if (name == null) return;
    
    final terminalService = ref.read(terminalServiceProvider);
    await terminalService.writeFile('$_currentPath/$name', '');
    await _loadFiles();
  }

  Future<void> _createNewDirectory() async {
    final name = await _showNameDialog('Directory');
    if (name == null) return;
    
    final terminalService = ref.read(terminalServiceProvider);
    await terminalService.createDirectory('$_currentPath/$name');
    await _loadFiles();
  }

  Future<String?> _showNameDialog(String type) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('New $type'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: '$type name',
            hintText: 'Enter $type name',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteFile(FileItem file) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete'),
        content: Text('Delete ${file.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      final terminalService = ref.read(terminalServiceProvider);
      await terminalService.deleteFile(file.path);
      await _loadFiles();
    }
  }

  Future<void> _viewFile(FileItem file) async {
    if (file.isDirectory) {
      await _navigateTo(file.path);
      return;
    }
    
    final terminalService = ref.read(terminalServiceProvider);
    final result = await terminalService.readFile(file.path);
    
    if (!mounted) return;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _FileContentSheet(
        fileName: file.name,
        content: result.output,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildPathBar(),
          if (_isLoading)
            const Expanded(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_files.isEmpty)
            _buildEmptyState()
          else
            Expanded(child: _buildFileList()),
        ],
      ),
      floatingActionButton: _buildFAB(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Text(
        'File Explorer',
        style: GoogleFonts.inter(
          fontWeight: FontWeight.w600,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _loadFiles,
          tooltip: 'Refresh',
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (value) {
            switch (value) {
              case 'file':
                _createNewFile();
                break;
              case 'folder':
                _createNewDirectory();
                break;
              case 'home':
                _navigateTo('\$HOME');
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'file',
              child: ListTile(
                leading: Icon(Icons.insert_drive_file),
                title: Text('New File'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'folder',
              child: ListTile(
                leading: Icon(Icons.create_new_folder),
                title: Text('New folder'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'home',
              child: ListTile(
                leading: Icon(Icons.home),
                title: Text('Go Home'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPathBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.glassmorphismDecoration,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _currentPath == '\$HOME'
                ? null
                : () {
                    final parts = _currentPath.split('/');
                    parts.removeLast();
                    _navigateTo(parts.isEmpty ? '\$HOME' : parts.join('/'));
                  },
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _pathController,
              decoration: InputDecoration(
                hintText: 'Current path',
                prefixIcon: const Icon(Icons.folder, size: 20),
                border: InputBorder.none,
                isDense: true,
              ),
              onSubmitted: (value) => _navigateTo(value),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward),
            onPressed: () => _navigateTo(_pathController.text),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: -0.1);
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.folder_open,
            size: 64,
            color: AppTheme.secondaryColor.withAlpha(120),
          ),
          const SizedBox(height: 16),
          Text(
            'No files',
            style: GoogleFonts.inter(
              fontSize: 18,
              color: AppTheme.secondaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create a new file or folder to get started',
            style: GoogleFonts.inter(
              color: AppTheme.secondaryColor.withAlpha(180),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _files.length,
      itemBuilder: (context, index) {
        final file = _files[index];
        return _FileListItem(
          file: file,
          onTap: () => _viewFile(file),
          onDelete: () => _deleteFile(file),
        ).animate().fadeIn(delay: Duration(milliseconds: index * 50)).slideX(begin: 0.1);
      },
    );
  }

  Widget _buildFAB() {
    return FloatingActionButton(
      onPressed: () {
        showModalBottomSheet(
          context: context,
          builder: (context) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.insert_drive_file),
                  title: const Text('New File'),
                  onTap: () {
                    Navigator.pop(context);
                    _createNewFile();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.create_new_folder),
                  title: const Text('New Folder'),
                  onTap: () {
                    Navigator.pop(context);
                    _createNewDirectory();
                  },
                ),
              ],
            ),
          ),
        );
      },
      child: const Icon(Icons.add),
    );
  }
}

class _FileListItem extends StatelessWidget {
  final FileItem file;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _FileListItem({
    required this.file,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          file.isDirectory ? Icons.folder : _getFileIcon(file.name),
          color: file.isDirectory
              ? AppTheme.primaryColor
              : AppTheme.secondaryColor,
        ),
        title: Text(
          file.name,
          style: GoogleFonts.inter(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          _formatFileInfo(file),
          style: TextStyle(
            fontSize: 12,
            color: AppTheme.secondaryColor,
          ),
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (value) {
            switch (value) {
              case 'delete':
                onDelete();
                break;
              case 'rename':
                break;
              case 'copy':
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'rename',
              child: Text('Rename'),
            ),
            const PopupMenuItem(
              value: 'copy',
              child: Text('Copy'),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Text(
                'Delete',
                style: TextStyle(color: AppTheme.errorColor),
              ),
            ),
          ],
        ),
        onTap: onTap,
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
      'yaml': Icons.data_object,
      'yml': Icons.data_object,
      'sh': Icons.terminal,
      'html': Icons.web,
      'css': Icons.palette,
    };
    return icons[ext] ?? Icons.insert_drive_file;
  }

  String _formatFileInfo(FileItem file) {
    final size = _formatSize(file.size);
    final mod = _formatDate(file.modified);
    return '$size · $mod · ${file.permissions}';
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _FileContentSheet extends StatelessWidget {
  final String fileName;
  final String content;

  const _FileContentSheet({
    required this.fileName,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
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
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        fileName,
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  child: SelectableText(
                    content,
                    style: GoogleFonts.firaCode(
                      fontSize: 13,
                      color: AppTheme.aiText,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}