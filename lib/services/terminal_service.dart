import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:android_intent_plus/android_intent_plus.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../models/chat_message.dart';

class TerminalService {
  static const String _termuxPackage = 'com.termux';
  static const String _runCommandAction = 'com.termux.RUN_COMMAND';
  static const String _outputFilePrefix = 'nim_builder_output_';

  final AndroidIntent _intent = AndroidIntent(action: _runCommandAction);
  
  String? _lastOutputFilePath;
  final StreamController<String> _outputController = StreamController<String>.broadcast();
  final StreamController<BackgroundJob> _jobController = StreamController<BackgroundJob>.broadcast();
  
  Stream<String> get outputStream => _outputController.stream;
  Stream<BackgroundJob> get jobStream => _jobController.stream;
  bool _isTermuxAvailable = false;

  bool get isTermuxAvailable => _isTermuxAvailable;
  final Map<String, BackgroundJob> _backgroundJobs = {};

  Future<void> initialize() async {
    await _checkTermuxAvailability();
    await _setupResultReceiver();
  }

  Future<void> _checkTermuxAvailability() async {
    try {
      final intent = AndroidIntent(
        action: AndroidIntent.ACTION_VIEW,
        package: _termuxPackage,
      );
      await intent.canLaunch();
      _isTermuxAvailable = true;
    } catch (e) {
      _isTermuxAvailable = false;
    }
  }

  Future<void> _setupResultReceiver() async {
    const platform = MethodChannel('com.nimbuilder.app/termux');
    try {
      platform.setMethodCallHandler((call) async {
        if (call.method == 'onCommandResult') {
          final output = call.arguments as String?;
          if (output != null) {
            _outputController.add(output);
          }
        }
      });
    } catch (e) {
      debugPrint('Failed to setup result receiver: $e');
    }
  }

  Future<String> getOutputFilePath() async {
    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    _lastOutputFilePath = '${tempDir.path}/$_outputFilePrefix$timestamp.txt';
    return _lastOutputFilePath!;
  }

  Future<CommandResult> executeCommand(String command, {int? timeoutMs}) async {
    final startTime = DateTime.now();
    final outputFile = await getOutputFilePath();
    
    final args = {
      'command': command,
      'output_file': outputFile,
      'background': false,
    };

    try {
      final intent = AndroidIntent(
        action: _runCommandAction,
        package: _termuxPackage,
        arguments: args,
      );

      await intent.launch();
      
      final result = await _waitForOutput(outputFile, timeoutMs ?? 30000);
      final executionTime = DateTime.now().difference(startTime);
      
      return CommandResult(
        command: command,
        output: result,
        exitCode: result.contains('error') ? 1 : 0,
        executionTime: executionTime,
      );
    } catch (e) {
      final executionTime = DateTime.now().difference(startTime);
      return CommandResult(
        command: command,
        output: 'Error executing command: $e',
        exitCode: 1,
        executionTime: executionTime,
      );
    }
  }

  Future<String> _waitForOutput(String outputFile, int timeoutMs) async {
    final deadline = DateTime.now().add(Duration(milliseconds: timeoutMs));
    
    while (DateTime.now().isBefore(deadline)) {
      try {
        final file = File(outputFile);
        if (await file.exists()) {
          final content = await file.readAsString();
          await file.delete();
          return content;
        }
      } catch (e) {
        // File not ready yet
      }
      
      await Future.delayed(const Duration(milliseconds: 100));
    }
    
    return 'Command timed out after ${timeoutMs}ms';
  }

  Future<CommandResult> executeShellCommand(String command) async {
    return executeCommand(command);
  }

  Future<CommandResult> runBashScript(String script, {String? name}) async {
    final scriptName = name ?? 'nim_script_${DateTime.now().millisecondsSinceEpoch}.sh';
    final scriptPath = '\$HOME/$scriptName';
    
    await executeCommand('cat > $scriptPath << \'EOF\'\n$script\nEOF');
    await executeCommand('chmod +x $scriptPath');
    
    return executeCommand(scriptPath);
  }

  Future<List<FileItem>> listDirectory(String path) async {
    final result = await executeCommand('ls -la "$path"');
    
    if (!result.success) {
      return [];
    }
    
    final lines = result.output.split('\n').where((line) => line.isNotEmpty).skip(1);
    return lines.map((line) => FileItem.fromLsLine(line, path)).toList();
  }

  Future<List<String>> getGeneratedFiles() async {
    final result = await executeCommand('ls -1 $HOME');
    if (!result.success) {
      return [];
    }
    return result.output.split('\n').where((f) => f.isNotEmpty).toList();
  }

  Future<CommandResult> readFile(String path) async {
    return executeCommand('cat "$path"');
  }

  Future<CommandResult> writeFile(String path, String content) async {
    final escapedContent = content.replaceAll("'", "'\\''");
    return executeCommand("echo '$escapedContent' > '$path'");
  }

  Future<CommandResult> deleteFile(String path) async {
    return executeCommand('rm -rf "$path"');
  }

  Future<CommandResult> createDirectory(String path) async {
    return executeCommand('mkdir -p "$path"');
  }

  Future<CommandResult> copyFile(String source, String destination) async {
    return executeCommand('cp "$source" "$destination"');
  }

  Future<CommandResult> moveFile(String source, String destination) async {
    return executeCommand('mv "$source" "$destination"');
  }

  // Process Management
  Future<List<ProcessInfo>> getProcesses({String? filter}) async {
    String command = 'ps aux';
    if (filter != null && filter.isNotEmpty) {
      command = 'ps aux | grep -i "$filter" | grep -v grep';
    }
    
    final result = await executeCommand(command);
    
    if (!result.success) {
      return [];
    }
    
    final lines = result.output.split('\n').where((line) => line.isNotEmpty).skip(1);
    return lines.map((line) => ProcessInfo.fromPsLine(line)).toList();
  }

  Future<CommandResult> killProcess(int pid, {bool force = false}) async {
    final signal = force ? '-9' : '-15';
    return executeCommand('kill $signal $pid');
  }

  Future<CommandResult> killProcessByName(String name) async {
    return executeCommand("pkill -f '$name'");
  }

  // Environment Variables
  Future<List<EnvironmentVariable>> getEnvironmentVariables() async {
    final result = await executeCommand('env');
    
    if (!result.success) {
      return [];
    }
    
    final lines = result.output.split('\n').where((line) => line.isNotEmpty);
    return lines.map((line) {
      final idx = line.indexOf('=');
      if (idx == -1) {
        return EnvironmentVariable(name: line, value: '');
      }
      return EnvironmentVariable(
        name: line.substring(0, idx),
        value: line.substring(idx + 1),
      );
    }).toList();
  }

  Future<CommandResult> setEnvironmentVariable(String name, String value) async {
    return executeCommand('export $name="$value"');
  }

  Future<CommandResult> appendToPath(String path) async {
    final result = await executeCommand('echo \'export PATH=\$PATH:$path\' >> ~/.bashrc');
    if (result.success) {
      return executeCommand('source ~/.bashrc');
    }
    return result;
  }

  // Git Integration
  Future<CommandResult> gitInit(String path) async {
    return executeCommand('cd "$path" && git init');
  }

  Future<GitStatus> gitStatus(String path) async {
    final branchResult = await executeCommand('cd "$path" && git branch --show-current');
    final statusResult = await executeCommand('cd "$path" && git status --porcelain');
    
    final branchName = branchResult.output.trim();
    
    if (branchResult.exitCode != 0) {
      return GitStatus(
        branch: '',
        modified: [],
        staged: [],
        untracked: [],
        deleted: [],
      );
    }
    
    return GitStatus.parse(statusResult.output, branchName);
  }

  Future<CommandResult> gitClone(String url, {String? path}) async {
    final targetPath = path ?? '\$HOME/${url.split('/').last.replaceAll('.git', '')}';
    return executeCommand('git clone "$url" "$targetPath"');
  }

  Future<CommandResult> gitAdd(String path, {String? files}) async {
    final filesArg = files ?? '.';
    return executeCommand('cd "$path" && git add "$filesArg"');
  }

  Future<CommandResult> gitCommit(String path, String message) async {
    return executeCommand('cd "$path" && git commit -m "$message"');
  }

  Future<CommandResult> gitPush(String path, {String? remote, String? branch}) async {
    final remoteArg = remote ?? 'origin';
    final branchArg = branch ?? 'main';
    return executeCommand('cd "$path" && git push "$remoteArg" "$branchArg"');
  }

  Future<CommandResult> gitPull(String path, {String? remote, String? branch}) async {
    final remoteArg = remote ?? 'origin';
    final branchArg = branch ?? 'main';
    return executeCommand('cd "$path" && git pull "$remoteArg" "$branchArg"');
  }

  Future<CommandResult> gitLog(String path, {int? limit}) async {
    final limitArg = limit ?? 10;
    return executeCommand('cd "$path" && git log --oneline -n $limitArg');
  }

  Future<CommandResult> gitDiff(String path, {String? file}) async {
    final fileArg = file ?? '';
    return executeCommand('cd "$path" && git diff "$fileArg"');
  }

  // Background Jobs
  Future<BackgroundJob> startBackgroundJob(String command) async {
    final jobId = DateTime.now().millisecondsSinceEpoch.toString();
    
    final job = BackgroundJob(
      id: jobId,
      command: command,
      startTime: DateTime.now(),
      status: JobStatus.running,
    );
    
    _backgroundJobs[jobId] = job;
    _jobController.add(job);
    
    _runBackgroundJob(jobId, command);
    
    return job;
  }

  Future<void> _runBackgroundJob(String jobId, String command) async {
    try {
      final result = await executeCommand(command);
      
      _backgroundJobs[jobId] = _backgroundJobs[jobId]!.copyWith(
        status: result.success ? JobStatus.completed : JobStatus.failed,
        output: result.output,
      );
      _jobController.add(_backgroundJobs[jobId]!);
    } catch (e) {
      _backgroundJobs[jobId] = _backgroundJobs[jobId]!.copyWith(
        status: JobStatus.failed,
        output: 'Error: $e',
      );
      _jobController.add(_backgroundJobs[jobId]!);
    }
  }

  Future<CommandResult> cancelBackgroundJob(String jobId) async {
    final job = _backgroundJobs[jobId];
    if (job == null) {
      return CommandResult(
        command: jobId,
        output: 'Job not found',
        exitCode: 1,
        executionTime: Duration.zero,
      );
    }
    
    if (job.pid != null) {
      return killProcess(job.pid!);
    }
    
    return CommandResult(
      command: jobId,
      output: 'Job cancelled',
      exitCode: 0,
      executionTime: Duration.zero,
    );
  }

  List<BackgroundJob> getRunningJobs() {
    return _backgroundJobs.values.where((j) => j.status == JobStatus.running).toList();
  }

  List<BackgroundJob> getCompletedJobs() {
    return _backgroundJobs.values.where((j) => j.status != JobStatus.running).toList();
  }

  Stream<String> get liveOutputStream => _outputController.stream;

  void dispose() {
    _outputController.close();
    _jobController.close();
  }
}