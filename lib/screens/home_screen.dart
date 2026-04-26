import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import 'providers/chat_providers.dart';
import 'screens/chat_screen.dart';
import 'screens/terminal_view.dart';
import 'screens/file_explorer_screen.dart';
import 'screens/process_manager_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/performance_profiler_screen.dart';
import 'theme/app_theme.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewMode = ref.watch(currentViewModeProvider);
    final isTermuxAvailable = ref.watch(isTermuxAvailableProvider);
    final isDarkMode = ref.watch(isDarkModeProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, ref, isTermuxAvailable, isDarkMode),
            Expanded(
              child: _buildContent(viewMode),
            ),
            _buildNavigationRail(ref, viewMode),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref, AsyncValue<bool> isTermuxAvailable, bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.surface,
            Theme.of(context).colorScheme.surface.withAlpha(240),
          ],
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.smart_toy,
              color: Theme.of(context).colorScheme.primary,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'NIM Builder',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                isTermuxAvailable.when(
                  data: (available) => Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: available ? Colors.green : Colors.orange,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        available ? 'Termux connected' : 'Termux not found',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                      ),
                    ],
                  ),
                  loading: () => Text(
                    'Checking...',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                  error: (_, __) => Text(
                    'Error checking',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppTheme.errorColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              isDarkMode ? Icons.light_mode : Icons.dark_mode,
            ),
            onPressed: () => ref.read(isDarkModeProvider.notifier).toggle(),
            tooltip: isDarkMode ? 'Light mode' : 'Dark mode',
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => _showSettings(context),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: -0.2);
  }

  Widget _buildContent(ViewMode mode) {
    switch (mode) {
      case ViewMode.chat:
        return const ChatScreen();
      case ViewMode.terminal:
        return const TerminalView();
case ViewMode.files:
      return const FileExplorerScreen();
    case ViewMode.processes:
      return const ProcessManagerScreen();
    case ViewMode.performance:
      return const PerformanceProfilerScreen();
  }
}

  Widget _buildNavigationRail(WidgetRef ref, ViewMode mode) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: NavigationBar(
        selectedIndex: mode.index,
        onDestinationSelected: (index) {
          ref.read(currentViewModeProvider.notifier).state = ViewMode.values[index];
        },
        backgroundColor: Colors.transparent,
        elevation: 0,
        height: 64,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.chat_outlined),
            selectedIcon: Icon(Icons.chat),
            label: 'Chat',
          ),
          NavigationDestination(
            icon: Icon(Icons.terminal_outlined),
            selectedIcon: Icon(Icons.terminal),
            label: 'Terminal',
          ),
          NavigationDestination(
            icon: Icon(Icons.folder_outlined),
            selectedIcon: Icon(Icons.folder),
            label: 'Files',
          ),
NavigationDestination(
    icon: Icon(Icons.memory_outlined),
    selectedIcon: Icon(Icons.memory),
    label: 'Processes',
  ),
  NavigationDestination(
    icon: Icon(Icons.analytics_outlined),
    selectedIcon: Icon(Icons.analytics),
    label: 'Performance',
  ),
],
      ),
    );
  }

  void _showSettings(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );
  }
}

class SessionManagerScreen extends ConsumerWidget {
  const SessionManagerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(allSessionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Sessions',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _createNewSession(context, ref),
          ),
        ],
      ),
      body: sessionsAsync.when(
        data: (sessions) {
          if (sessions.isEmpty) {
            return _buildEmptyState(context, ref);
          }
          return ListView.builder(
            itemCount: sessions.length,
            itemBuilder: (context, index) {
              final session = sessions[index];
              return ListTile(
                leading: const Icon(Icons.chat),
                title: Text(session.title),
                subtitle: Text(_formatDate(session.lastMessageAt)),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'delete') {
                      ref.read(chatMessagesProvider.notifier).deleteSession(session.id);
                      ref.invalidate(allSessionsProvider);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
                onTap: () {
                  ref.read(chatMessagesProvider.notifier).loadSession(session.id);
                  Navigator.pop(context);
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_outline,
            size: 64,
            color: Theme.of(context).colorScheme.secondary.withAlpha(120),
          ),
          const SizedBox(height: 16),
          Text(
            'No sessions',
            style: GoogleFonts.inter(
              fontSize: 18,
              color: Theme.of(context).colorScheme.secondary,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => _createNewSession(context, ref),
            child: const Text('New Chat'),
          ),
        ],
      ),
    );
  }

  Future<void> _createNewSession(BuildContext context, WidgetRef ref) async {
    final sessionId = await ref.read(chatMessagesProvider.notifier).createNewSession();
    ref.invalidate(allSessionsProvider);
    if (context.mounted) {
      Navigator.pop(context);
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    
    if (diff.inDays == 0) {
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}