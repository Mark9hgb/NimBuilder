import 'package:flutter/foundation.dart';

class ChatMessage {
  final String id;
  final String content;
  final bool isUser;
  final DateTime timestamp;
  final MessageType type;
  final String? code;
  final bool isLoading;
  final String? imageBase64;
  final String? fileContext;

  ChatMessage({
    required this.id,
    required this.content,
    required this.isUser,
    required this.timestamp,
    this.type = MessageType.text,
    this.code,
    this.isLoading = false,
    this.imageBase64,
    this.fileContext,
  });

  ChatMessage copyWith({
    String? id,
    String? content,
    bool? isUser,
    DateTime? timestamp,
    MessageType? type,
    String? code,
    bool? isLoading,
    String? imageBase64,
    String? fileContext,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      content: content ?? this.content,
      isUser: isUser ?? this.isUser,
      timestamp: timestamp ?? this.timestamp,
      type: type ?? this.type,
      code: code ?? this.code,
      isLoading: isLoading ?? this.isLoading,
      imageBase64: imageBase64 ?? this.imageBase64,
      fileContext: fileContext ?? this.fileContext,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'content': content,
      'isUser': isUser ? 1 : 0,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'type': type.index,
      'code': code,
      'imageBase64': imageBase64,
      'fileContext': fileContext,
    };
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'] as String,
      content: map['content'] as String,
      isUser: map['isUser'] == 1,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      type: MessageType.values[map['type'] as int],
      code: map['code'] as String?,
      imageBase64: map['imageBase64'] as String?,
      fileContext: map['fileContext'] as String?,
    );
  }
}

enum MessageType {
  text,
  code,
  command,
  system,
  error,
  image,
}

class FileItem {
  final String name;
  final String path;
  final bool isDirectory;
  final int size;
  final DateTime modified;
  final String permissions;

  FileItem({
    required this.name,
    required this.path,
    required this.isDirectory,
    required this.size,
    required this.modified,
    required this.permissions,
  });

  factory FileItem.fromLsLine(String line, String basePath) {
    final parts = line.split(RegExp(r'\s+'));
    if (parts.length < 9) {
      return FileItem(
        name: line,
        path: '$basePath/$line',
        isDirectory: false,
        size: 0,
        modified: DateTime.now(),
        permissions: 'rwxr-xr-x',
      );
    }

    final perms = parts[0];
    final isDir = perms.startsWith('d');
    final size = int.tryParse(parts[4]) ?? 0;
    final name = parts[parts.length - 1];

    return FileItem(
      name: name,
      path: '$basePath/$name',
      isDirectory: isDir,
      size: size,
      modified: DateTime.now(),
      permissions: perms,
    );
  }
}

class CommandResult {
  final String command;
  final String output;
  final int exitCode;
  final Duration executionTime;
  final bool success;

  CommandResult({
    required this.command,
    required this.output,
    required this.exitCode,
    required this.executionTime,
  }) : success = exitCode == 0;
}

class ProcessInfo {
  final int pid;
  final String user;
  final double cpu;
  final double memory;
  final String command;
  final String status;

  ProcessInfo({
    required this.pid,
    required this.user,
    required this.cpu,
    required this.memory,
    required this.command,
    required this.status,
  });

  factory ProcessInfo.fromPsLine(String line) {
    final parts = line.split(RegExp(r'\s+'));
    if (parts.length < 11) {
      return ProcessInfo(
        pid: 0,
        user: '',
        cpu: 0,
        memory: 0,
        command: line,
        status: '',
      );
    }

    return ProcessInfo(
      pid: int.tryParse(parts[0]) ?? 0,
      user: parts[1],
      cpu: double.tryParse(parts[2]) ?? 0,
      memory: double.tryParse(parts[3]) ?? 0,
      command: parts.sublist(10).join(' '),
      status: parts[7],
    );
  }
}

class EnvironmentVariable {
  final String name;
  final String value;
  final bool isCustom;

  EnvironmentVariable({
    required this.name,
    required this.value,
    this.isCustom = false,
  });
}

class GitStatus {
  final String branch;
  final List<String> modified;
  final List<String> staged;
  final List<String> untracked;
  final List<String> deleted;

  GitStatus({
    required this.branch,
    required this.modified,
    required this.staged,
    required this.untracked,
    required this.deleted,
  });

  factory GitStatus.parse(String output, String branchName) {
    final lines = output.split('\n');
    final modified = <String>[];
    final staged = <String>[];
    final untracked = <String>[];
    final deleted = <String>[];

    for (final line in lines) {
      if (line.isEmpty) continue;
      final status = line.substring(0, 2);
      final file = line.substring(3).trim();
      
      if (status.contains('M') && !status.contains('?')) {
        modified.add(file);
      }
      if (status.contains('A')) {
        staged.add(file);
      }
      if (status.contains('?')) {
        untracked.add(file);
      }
      if (status.contains('D')) {
        deleted.add(file);
      }
    }

    return GitStatus(
      branch: branchName,
      modified: modified,
      staged: staged,
      untracked: untracked,
      deleted: deleted,
    );
  }

  bool get isClean => modified.isEmpty && staged.isEmpty && untracked.isEmpty && deleted.isEmpty;
}

class BackgroundJob {
  final String id;
  final String command;
  final DateTime startTime;
  final JobStatus status;
  final String? output;
  final int? pid;

  BackgroundJob({
    required this.id,
    required this.command,
    required this.startTime,
    required this.status,
    this.output,
    this.pid,
  });

  BackgroundJob copyWith({
    JobStatus? status,
    String? output,
  }) {
    return BackgroundJob(
      id: id,
      command: command,
      startTime: startTime,
      status: status ?? this.status,
      output: output ?? this.output,
      pid: pid ?? this.pid,
    );
  }
}

enum JobStatus {
  running,
  completed,
  failed,
  cancelled,
}

class AiPersona {
  final String id;
  final String name;
  final String description;
  final String systemPrompt;
  final bool isDefault;
  final DateTime createdAt;

  AiPersona({
    required this.id,
    required this.name,
    required this.description,
    required this.systemPrompt,
    this.isDefault = false,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'systemPrompt': systemPrompt,
      'isDefault': isDefault ? 1 : 0,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  factory AiPersona.fromMap(Map<String, dynamic> map) {
    return AiPersona(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String,
      systemPrompt: map['systemPrompt'] as String,
      isDefault: map['isDefault'] == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
    );
  }
}

class NimSettings {
  final String apiKey;
  final String model;
  final String customModelId;
  final String endpoint;
  final double temperature;
  final int maxTokens;
  final bool isDarkMode;
  final String? currentPersonaId;

  NimSettings({
    this.apiKey = '',
    this.model = 'meta/llama-3.1-405b-instruct',
    this.customModelId = '',
    this.endpoint = 'https://cloud.nvidia.com/nim/v1',
    this.temperature = 0.7,
    this.maxTokens = 4096,
    this.isDarkMode = false,
    this.currentPersonaId,
  });

  NimSettings copyWith({
    String? apiKey,
    String? model,
    String? customModelId,
    String? endpoint,
    double? temperature,
    int? maxTokens,
    bool? isDarkMode,
    String? currentPersonaId,
  }) {
    return NimSettings(
      apiKey: apiKey ?? this.apiKey,
      model: model ?? this.model,
      customModelId: customModelId ?? this.customModelId,
      endpoint: endpoint ?? this.endpoint,
      temperature: temperature ?? this.temperature,
      maxTokens: maxTokens ?? this.maxTokens,
      isDarkMode: isDarkMode ?? this.isDarkMode,
      currentPersonaId: currentPersonaId ?? this.currentPersonaId,
    );
  }
}

class NimModel {
  final String id;
  final String name;
  final String displayName;
  final String description;
  final int contextLength;
  final bool supportsVision;

  const NimModel({
    required this.id,
    required this.name,
    required this.displayName,
    required this.description,
    this.contextLength = 128000,
    this.supportsVision = false,
  });

  static const List<NimModel> availableModels = [
    NimModel(
      id: 'meta/llama-3.1-405b-instruct',
      name: 'meta/llama-3.1-405b-instruct',
      displayName: 'Llama 3.1 405B',
      description: 'Meta\'s largest model for complex tasks',
      contextLength: 128000,
      supportsVision: false,
    ),
    NimModel(
      id: 'meta/llama-3.1-70b-instruct',
      name: 'meta/llama-3.1-70b-instruct',
      displayName: 'Llama 3.1 70B',
      description: 'Balanced power and efficiency',
      contextLength: 128000,
      supportsVision: false,
    ),
    NimModel(
      id: 'meta/llama-3.1-8b-instruct',
      name: 'meta/llama-3.1-8b-instruct',
      displayName: 'Llama 3.1 8B',
      description: 'Fast and efficient for simple tasks',
      contextLength: 128000,
      supportsVision: false,
    ),
    NimModel(
      id: 'mistralai/mixtral-8x7b-instruct-v0.1',
      name: 'mistralai/mixtral-8x7b-instruct-v0.1',
      displayName: 'Mixtral 8x7B',
      description: 'Mixture of experts for diverse tasks',
      contextLength: 32000,
      supportsVision: false,
    ),
    NimModel(
      id: 'mistralai/mistral-7b-instruct-v0.2',
      name: 'mistralai/mistral-7b-instruct-v0.2',
      displayName: 'Mistral 7B',
      description: 'Compact and powerful',
      contextLength: 32000,
      supportsVision: false,
    ),
    NimModel(
      id: 'google/gemma-2-27b-instruct',
      name: 'google/gemma-2-27b-instruct',
      displayName: 'Gemma 2 27B',
      description: 'Google\'s efficient instruction model',
      contextLength: 8192,
      supportsVision: false,
    ),
    NimModel(
      id: 'google/gemma-2-9b-instruct',
      name: 'google/gemma-2-9b-instruct',
      displayName: 'Gemma 2 9B',
      description: 'Compact Google model',
      contextLength: 8192,
      supportsVision: false,
    ),
    NimModel(
      id: 'nvidia/llama-3.1-nemotron-70b-instruct',
      name: 'nvidia/llama-3.1-nemotron-70b-instruct',
      displayName: 'Nemotron 70B',
      description: 'NVIDIA\'s optimized instruction model',
      contextLength: 128000,
      supportsVision: false,
    ),
  ];
}

class ChatSession {
  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime lastMessageAt;
  final String model;
  final String? personaId;

  ChatSession({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.lastMessageAt,
    required this.model,
    this.personaId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'lastMessageAt': lastMessageAt.millisecondsSinceEpoch,
      'model': model,
      'personaId': personaId,
    };
  }

  factory ChatSession.fromMap(Map<String, dynamic> map) {
    return ChatSession(
      id: map['id'] as String,
      title: map['title'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
      lastMessageAt: DateTime.fromMillisecondsSinceEpoch(map['lastMessageAt'] as int),
      model: map['model'] as String,
      personaId: map['personaId'] as String?,
    );
  }
}