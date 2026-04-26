import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/chat_message.dart';
import '../providers/chat_providers.dart';
import '../theme/app_theme.dart';

class ProcessManagerScreen extends ConsumerStatefulWidget {
  const ProcessManagerScreen({super.key});

  @override
  ConsumerState<ProcessManagerScreen> createState() => _ProcessManagerScreenState();
}

class _ProcessManagerScreenState extends ConsumerState<ProcessManagerScreen> {
  final TextEditingController _filterController = TextEditingController();
  String _filter = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadProcesses();
  }

  @override
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }

  Future<void> _loadProcesses() async {
    setState(() => _isLoading = true);
    ref.invalidate(processesProvider);
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _killProcess(ProcessInfo process) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kill Process'),
        content: Text('Kill "${process.command}"?\nPID: ${process.pid}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.errorColor),
            child: const Text('Kill'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final terminalService = ref.read(terminalServiceProvider);
      final result = await terminalService.killProcess(process.pid);
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.success ? 'Process killed' : result.output),
          backgroundColor: result.success ? Colors.green : AppTheme.errorColor,
        ),
      );
      
      _loadProcesses();
    }
  }

  @override
  Widget build(BuildContext context) {
    final processesAsync = ref.watch(processesProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : processesAsync.when(
                    data: (processes) => _buildProcessList(processes),
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => _buildError(e),
                  ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Text(
        'Process Manager',
        style: GoogleFonts.inter(fontWeight: FontWeight.w600),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _loadProcesses,
          tooltip: 'Refresh',
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (value) {
            switch (value) {
              case 'all':
                _filterController.clear();
                setState(() => _filter = '');
                _loadProcesses();
                break;
              case 'user':
                _filterController.text = '';
                setState(() => _filter = 'user');
                _loadProcesses();
                break;
              case 'system':
                _filterController.text = '';
                setState(() => _filter = 'system');
                _loadProcesses();
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'all', child: Text('Show All')),
            const PopupMenuItem(value: 'user', child: Text('My Processes')),
            const PopupMenuItem(value: 'system', child: Text('System Processes')),
          ],
        ),
      ],
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _filterController,
        decoration: InputDecoration(
          hintText: 'Filter processes...',
          prefixIcon: const Icon(Icons.filter_list),
          suffixIcon: _filter.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _filterController.clear();
                    setState(() => _filter = '');
                    _loadProcesses();
                  },
                )
              : null,
        ),
        onChanged: (value) {
          _filter = value;
        },
        onSubmitted: (_) => _loadProcesses(),
      ),
    );
  }

  Widget _buildProcessList(List<ProcessInfo> processes) {
    if (processes.isEmpty) {
      return _buildEmpty();
    }

    return RefreshIndicator(
      onRefresh: _loadProcesses,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: processes.length,
        itemBuilder: (context, index) {
          final process = processes[index];
          return _ProcessTile(
            process: process,
            onKill: () => _killProcess(process),
          ).animate().fadeIn(delay: Duration(milliseconds: index * 30));
        },
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.memory,
            size: 64,
            color: Theme.of(context).colorScheme.secondary.withAlpha(120),
          ),
          const SizedBox(height: 16),
          Text(
            'No processes',
            style: GoogleFonts.inter(
              fontSize: 18,
              color: Theme.of(context).colorScheme.secondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(Object e) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: AppTheme.errorColor),
          const SizedBox(height: 16),
          Text('Error: $e'),
          const SizedBox(height: 16),
          FilledButton(onPressed: _loadProcesses, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _ProcessTile extends StatelessWidget {
  final ProcessInfo process;
  final VoidCallback onKill;

  const _ProcessTile({
    required this.process,
    required this.onKill,
  });

  @override
  Widget build(BuildContext context) {
    final isSystemProcess = process.user == 'root' || process.user == 'system';
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isSystemProcess
              ? AppTheme.errorColor.withAlpha(30)
              : AppTheme.primaryColor.withAlpha(30),
          child: Icon(
            isSystemProcess ? Icons.security : Icons.play_arrow,
            color: isSystemProcess ? AppTheme.errorColor : AppTheme.primaryColor,
          ),
        ),
        title: Text(
          process.command,
          style: GoogleFonts.firaCode(fontSize: 13),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Row(
          children: [
            _buildChip('PID: ${process.pid}'),
            const SizedBox(width: 8),
            _buildChip('CPU: ${process.cpu.toStringAsFixed(1)}%'),
            const SizedBox(width: 8),
            _buildChip('MEM: ${process.memory.toStringAsFixed(1)}%'),
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (value) {
            if (value == 'kill') onKill();
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'kill',
              child: Row(
                children: [
                  Icon(Icons.stop, color: AppTheme.errorColor),
                  const SizedBox(width: 8),
                  const Text('Kill'),
                ],
              ),
            ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }

  Widget _buildChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: AppTheme.secondaryColor,
        ),
      ),
    );
  }
}