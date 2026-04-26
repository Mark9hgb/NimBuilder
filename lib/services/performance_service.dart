import 'dart:async';
import 'dart:developer' as developer;

class PerformanceService {
  static final PerformanceService _instance = PerformanceService._internal();
  factory PerformanceService() => _instance;
  PerformanceService._internal();

  final List<PerformanceMetric> _metrics = [];
  final List<AiRequest> _aiRequests = [];
  final Map<String, List<double>> _responseTimes = {};
  final Map<String, int> _requestCounts = {};
  final Map<String, int> _errorCounts = {};

  DateTime? _sessionStartTime;

  void startSession() {
    _sessionStartTime = DateTime.now();
    _metrics.clear();
    _aiRequests.clear();
    _responseTimes.clear();
    _requestCounts.clear();
    _errorCounts.clear();
  }

  void logAiRequest({
    required String model,
    required int promptTokens,
    required int completionTokens,
    required Duration responseTime,
    required bool success,
    String? error,
  }) {
    final request = AiRequest(
      model: model,
      promptTokens: promptTokens,
      completionTokens: completionTokens,
      responseTime: responseTime,
      success: success,
      error: error,
      timestamp: DateTime.now(),
    );

    _aiRequests.add(request);
    _requestCounts[model] = (_requestCounts[model] ?? 0) + 1;

    if (!success) {
      _errorCounts[model] = (_errorCounts[model] ?? 0) + 1;
    }

    _responseTimes[model] ??= [];
    _responseTimes[model]!.add(responseTime.inMilliseconds.toDouble());

    _metrics.add(PerformanceMetric(
      type: MetricType.aiRequest,
      label: 'AI Request ($model)',
      value: responseTime.inMilliseconds.toDouble(),
      timestamp: DateTime.now(),
    ));

    developer.log(
      'AI Request: model=$model, tokens=$promptTokens+$completionTokens, time=${responseTime.inMilliseconds}ms',
      name: 'NIMBuilder',
    );
  }

  void logCommand({
    required String command,
    required Duration executionTime,
    required bool success,
  }) {
    _metrics.add(PerformanceMetric(
      type: MetricType.commandExecution,
      label: command.length > 30 ? '${command.substring(0, 30)}...' : command,
      value: executionTime.inMilliseconds.toDouble(),
      timestamp: DateTime.now(),
    ));

    developer.log(
      'Command: $command, time=${executionTime.inMilliseconds}ms',
      name: 'NIMBuilder',
    );
  }

  void logUiRender(String component, Duration renderTime) {
    _metrics.add(PerformanceMetric(
      type: MetricType.uiRender,
      label: component,
      value: renderTime.inMilliseconds.toDouble(),
      timestamp: DateTime.now(),
    ));
  }

  void logNetwork(String endpoint, Duration duration, int bytes) {
    _metrics.add(PerformanceMetric(
      type: MetricType.network,
      label: endpoint,
      value: duration.inMilliseconds.toDouble(),
      timestamp: DateTime.now(),
      metadata: {'bytes': bytes},
    ));
  }

  // Analytics
  Map<String, dynamic> getSessionStats() {
    final totalRequests = _aiRequests.length;
    final successfulRequests = _aiRequests.where((r) => r.success).length;
    final failedRequests = _aiRequests.where((r) => !r.success).length;
    
    final totalTokens = _aiRequests.fold<int>(
      0,
      (sum, r) => sum + r.promptTokens + r.completionTokens,
    );

    final responseTimes = _aiRequests.map((r) => r.responseTime.inMilliseconds.toDouble()).toList();
    responseTimes.sort();

    final avgResponseTime = responseTimes.isEmpty
        ? 0.0
        : responseTimes.reduce((a, b) => a + b) / responseTimes.length;

    final p50ResponseTime = _percentile(responseTimes, 0.5);
    final p95ResponseTime = _percentile(responseTimes, 0.95);
    final p99ResponseTime = _percentile(responseTimes, 0.99);

    return {
      'totalRequests': totalRequests,
      'successfulRequests': successfulRequests,
      'failedRequests': failedRequests,
      'successRate': totalRequests > 0 ? (successfulRequests / totalRequests * 100) : 0,
      'totalTokens': totalTokens,
      'avgResponseTime': avgResponseTime,
      'p50ResponseTime': p50ResponseTime,
      'p95ResponseTime': p95ResponseTime,
      'p99ResponseTime': p99ResponseTime,
      'sessionDuration': _sessionDuration().inSeconds,
    };
  }

  Map<String, dynamic> getModelStats(String model) {
    final modelRequests = _aiRequests.where((r) => r.model == model).toList();
    
    if (modelRequests.isEmpty) {
      return {'error': 'No requests for this model'};
    }

    final times = _responseTimes[model] ?? [];
    final avgTime = times.isEmpty ? 0.0 : times.reduce((a, b) => a + b) / times.length;
    
    return {
      'model': model,
      'requests': modelRequests.length,
      'errors': _errorCounts[model] ?? 0,
      'avgResponseTime': avgTime,
      'minResponseTime': times.isEmpty ? 0 : times.reduce((a, b) => a < b ? a : b),
      'maxResponseTime': times.isEmpty ? 0 : times.reduce((a, b) => a > b ? a : b),
    };
  }

  List<Map<String, dynamic>> getAllModelStats() {
    return _requestCounts.keys.map((model) => getModelStats(model)).toList();
  }

  List<AiRequest> getRecentRequests({int limit = 20}) {
    final sorted = List<AiRequest>.from(_aiRequests)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return sorted.take(limit).toList();
  }

  List<PerformanceMetric> getMetrics({MetricType? type, int limit = 50}) {
    var metrics = List<PerformanceMetric>.from(_metrics);
    
    if (type != null) {
      metrics = metrics.where((m) => m.type == type).toList();
    }
    
    metrics.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return metrics.take(limit).toList();
  }

  double _percentile(List<double> sortedValues, double percentile) {
    if (sortedValues.isEmpty) return 0;
    
    final sorted = List<double>.from(sortedValues)..sort();
    final index = (sorted.length * percentile).floor();
    return sorted[index.clamp(0, sorted.length - 1)];
  }

  Duration _sessionDuration() {
    if (_sessionStartTime == null) return Duration.zero;
    return DateTime.now().difference(_sessionStartTime!);
  }

  void clear() {
    _metrics.clear();
    _aiRequests.clear();
    _responseTimes.clear();
    _requestCounts.clear();
    _errorCounts.clear();
    _sessionStartTime = null;
  }

  void dispose() {
    clear();
  }
}

class PerformanceMetric {
  final MetricType type;
  final String label;
  final double value;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;

  PerformanceMetric({
    required this.type,
    required this.label,
    required this.value,
    required this.timestamp,
    this.metadata,
  });
}

enum MetricType {
  aiRequest,
  commandExecution,
  uiRender,
  network,
}

class AiRequest {
  final String model;
  final int promptTokens;
  final int completionTokens;
  final Duration responseTime;
  final bool success;
  final String? error;
  final DateTime timestamp;

  AiRequest({
    required this.model,
    required this.promptTokens,
    required this.completionTokens,
    required this.responseTime,
    required this.success,
    this.error,
    required this.timestamp,
  });

  int get totalTokens => promptTokens + completionTokens;
}