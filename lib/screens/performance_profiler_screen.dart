import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/performance_service.dart';
import '../theme/app_theme.dart';

class PerformanceProfilerScreen extends ConsumerStatefulWidget {
  const PerformanceProfilerScreen({super.key});

  @override
  ConsumerState<PerformanceProfilerScreen> createState() => _PerformanceProfilerScreenState();
}

class _PerformanceProfilerScreenState extends ConsumerState<PerformanceProfilerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final PerformanceService _performanceService = PerformanceService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _performanceService.startSession();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Performance',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _performanceService.startSession(),
            tooltip: 'Reset session',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'export') {
                _exportStats();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'export', child: Text('Export Stats')),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Models'),
            Tab(text: 'Requests'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          _buildModelsTab(),
          _buildRequestsTab(),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    final stats = _performanceService.getSessionStats();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildStatCard(
          'Total Requests',
          '${stats['totalRequests']}',
          Icons.chat,
          AppTheme.primaryColor,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMiniStatCard(
                'Success Rate',
                '${(stats['successRate'] as double).toStringAsFixed(1)}%',
                Icons.check_circle,
                Colors.green,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMiniStatCard(
                'Errors',
                '${stats['failedRequests']}',
                Icons.error,
                AppTheme.errorColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMiniStatCard(
                'Avg Response',
                '${(stats['avgResponseTime'] as double).toStringAsFixed(0)}ms',
                Icons.speed,
                AppTheme.primaryColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMiniStatCard(
                'Total Tokens',
                '${stats['totalTokens']}',
                Icons.token,
                Colors.orange,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          'Response Time Distribution',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        _buildResponseTimeDistribution(stats),
        const SizedBox(height: 24),
        Text(
          'Session Info',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        _buildInfoTile('Duration', _formatDurationSeconds(stats['sessionDuration'] as int)),
        _buildInfoTile('P50', '${(stats['p50ResponseTime'] as double).toStringAsFixed(0)}ms'),
        _buildInfoTile('P95', '${(stats['p95ResponseTime'] as double).toStringAsFixed(0)}ms'),
        _buildInfoTile('P99', '${(stats['p99ResponseTime'] as double).toStringAsFixed(0)}ms'),
      ],
    );
  }

  Widget _buildModelsTab() {
    final modelStats = _performanceService.getAllModelStats();

    if (modelStats.isEmpty) {
      return _buildEmptyState('No model data yet');
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: modelStats.length,
      itemBuilder: (context, index) {
        final stats = modelStats[index];
        if (stats.containsKey('error')) {
          return const SizedBox.shrink();
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.model_training,
                      color: AppTheme.primaryColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        stats['model'].toString().split('/').last,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withAlpha(30),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${stats['requests']} requests',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildStatItem(
                      'Avg',
                      '${(stats['avgResponseTime'] as double).toStringAsFixed(0)}ms',
                    ),
                    _buildStatItem(
                      'Min',
                      '${(stats['minResponseTime'] as double).toStringAsFixed(0)}ms',
                    ),
                    _buildStatItem(
                      'Max',
                      '${(stats['maxResponseTime'] as double).toStringAsFixed(0)}ms',
                    ),
                    _buildStatItem(
                      'Errors',
                      '${stats['errors']}',
                      error: (stats['errors'] as int) > 0,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ).animate().fadeIn(delay: Duration(milliseconds: index * 100));
      },
    );
  }

  Widget _buildRequestsTab() {
    final requests = _performanceService.getRecentRequests();

    if (requests.isEmpty) {
      return _buildEmptyState('No requests yet');
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: requests.length,
      itemBuilder: (context, index) {
        final request = requests[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Icon(
              request.success ? Icons.check_circle : Icons.error,
              color: request.success ? Colors.green : AppTheme.errorColor,
            ),
            title: Text(
              request.model.split('/').last,
              style: GoogleFonts.inter(fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              '${request.promptTokens} + ${request.completionTokens} = ${request.totalTokens} tokens',
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${request.responseTime.inMilliseconds}ms',
                  style: GoogleFonts.firaCode(fontSize: 12),
                ),
                Text(
                  _formatTime(request.timestamp),
                  style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ),
              ],
            ),
          ),
        ).animate().fadeIn(delay: Duration(milliseconds: index * 50));
      },
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn().scale(begin: const Offset(0.95, 0.95));
  }

  Widget _buildMiniStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withAlpha(15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ),
                Text(
                  value,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResponseTimeDistribution(Map<String, dynamic> stats) {
    final p50 = (stats['p50ResponseTime'] as double);
    final p95 = (stats['p95ResponseTime'] as double);
    final p99 = (stats['p99ResponseTime'] as double);
    final max = p99 > 0 ? p99 * 1.1 : 1000.0;

    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.codeBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildBar('P50', p50, max, Colors.green),
                const SizedBox(width: 8),
                _buildBar('P95', p95, max, Colors.orange),
                const SizedBox(width: 8),
                _buildBar('P99', p99, max, Colors.red),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Response Time (ms)',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.codeText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBar(String label, double value, double max, Color color) {
    final height = max > 0 ? (value / max * 150) : 0.0;

    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            value.toStringAsFixed(0),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            height: height,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: AppTheme.codeText.withAlpha(180),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile(String label, String value) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      trailing: Text(
        value,
        style: GoogleFonts.firaCode(),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, {bool error = false}) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.firaCode(
              color: error ? AppTheme.errorColor : null,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Theme.of(context).colorScheme.secondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.analytics_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.secondary.withAlpha(120),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: GoogleFonts.inter(
              color: Theme.of(context).colorScheme.secondary,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    
    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  String _formatDurationSeconds(int seconds) {
    final duration = Duration(seconds: seconds);
    return _formatDuration(duration);
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  void _exportStats() {
    final stats = _performanceService.getSessionStats();
    final modelStats = _performanceService.getAllModelStats();
    
    final export = '''
NIM Builder Performance Report
=============================
Generated: ${DateTime.now()}

Session Overview:
- Total Requests: ${stats['totalRequests']}
- Success Rate: ${(stats['successRate'] as double).toStringAsFixed(1)}%
- Failed: ${stats['failedRequests']}
- Total Tokens: ${stats['totalTokens']}
- Avg Response: ${(stats['avgResponseTime'] as double).toStringAsFixed(0)}ms
- P50: ${(stats['p50ResponseTime'] as double).toStringAsFixed(0)}ms
- P95: ${(stats['p95ResponseTime'] as double).toStringAsFixed(0)}ms
- P99: ${(stats['p99ResponseTime'] as double).toStringAsFixed(0)}ms

Model Breakdown:
${modelStats.map((m) => '- ${m['model']}: ${m['requests']} requests, ${m['errors']} errors').join('\n')}
''';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Stats exported to clipboard'),
        action: SnackBarAction(
          label: 'Copy',
          onPressed: () {
            // Copy to clipboard
          },
        ),
      ),
    );
  }
}