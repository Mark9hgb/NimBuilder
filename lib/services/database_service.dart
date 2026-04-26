import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/chat_message.dart';

class DatabaseService {
  static Database? _database;
  static const String _dbName = 'nim_builder.db';
  static const int _dbVersion = 1;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE chat_sessions (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        createdAt INTEGER NOT NULL,
        lastMessageAt INTEGER NOT NULL,
        model TEXT NOT NULL,
        personaId TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE chat_messages (
        id TEXT PRIMARY KEY,
        sessionId TEXT NOT NULL,
        content TEXT NOT NULL,
        isUser INTEGER NOT NULL,
        timestamp INTEGER NOT NULL,
        type INTEGER NOT NULL,
        code TEXT,
        imageBase64 TEXT,
        fileContext TEXT,
        FOREIGN KEY (sessionId) REFERENCES chat_sessions(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE ai_personas (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT NOT NULL,
        systemPrompt TEXT NOT NULL,
        isDefault INTEGER NOT NULL DEFAULT 0,
        createdAt INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_messages_session ON chat_messages(sessionId)
    ''');

    await db.execute('''
      CREATE INDEX idx_sessions_lastmessage ON chat_sessions(lastMessageAt)
    ''');

    await _insertDefaultPersonas(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE chat_sessions ADD COLUMN personaId TEXT');
    }
  }

  Future<void> _insertDefaultPersonas(Database db) async {
    final defaultPersonas = [
      AiPersona(
        id: 'default_terminal',
        name: 'Terminal Expert',
        description: 'Specializes in terminal commands and shell scripting',
        systemPrompt: '''You are an AI assistant with access to a full Linux terminal via Termux on Android. Your capabilities include:
1. File Operations: Create, read, update, and delete files in the Termux home directory
2. Command Execution: Run any Linux command available in Termux
3. Code Execution: Execute Python, Node.js, C, Go, Rust, or other languages
4. System Information: Query system info, environment variables, running processes
5. Package Management: Use apt/apt-get to install packages within Termux
6. Git Operations: Clone repos, commit changes, push/pull

IMPORTANT RULES:
- Always use code blocks with ```bash for shell commands
- Report command output back to user with proper formatting
- Use tool call markers when executing commands''',
        isDefault: true,
        createdAt: DateTime.now(),
      ),
      AiPersona(
        id: 'default_developer',
        name: 'Developer',
        description: 'Helps with coding, debugging, and software development',
        systemPrompt: '''You are an AI coding assistant specialized in software development. You have access to a Linux terminal via Termux to:
1. Write and execute code in multiple languages (Python, JavaScript, Dart, Go, Rust, C, etc.)
2. Create and manage project files
3. Run build commands and tests
4. Debug and fix issues
5. Use git for version control

Guidelines:
- Write clean, well-documented code
- Explain your approach before writing code
- Use appropriate error handling
- Test your code before presenting it complete''',
        isDefault: true,
        createdAt: DateTime.now(),
      ),
      AiPersona(
        id: 'default_file_manager',
        name: 'File Manager',
        description: 'Specializes in file operations, organization, and management',
        systemPrompt: '''You are an AI assistant specialized in file management via Termux. You can:
1. List and navigate directories
2. Create, read, copy, move, and delete files
3. Search for files and content
4. Manage permissions and attributes
5. Compress and extract archives

Always confirm before destructive operations and provide clear feedback.''',
        isDefault: true,
        createdAt: DateTime.now(),
      ),
    ];

    for (final persona in defaultPersonas) {
      await db.insert('ai_personas', persona.toMap());
    }
  }

  Future<List<ChatSession>> getAllSessions() async {
    final db = await database;
    final maps = await db.query(
      'chat_sessions',
      orderBy: 'lastMessageAt DESC',
    );
    return maps.map((map) => ChatSession.fromMap(map)).toList();
  }

  Future<ChatSession?> getSession(String id) async {
    final db = await database;
    final maps = await db.query(
      'chat_sessions',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return ChatSession.fromMap(maps.first);
  }

  Future<String> createSession(ChatSession session) async {
    final db = await database;
    await db.insert('chat_sessions', session.toMap());
    return session.id;
  }

  Future<void> updateSession(ChatSession session) async {
    final db = await database;
    await db.update(
      'chat_sessions',
      session.toMap(),
      where: 'id = ?',
      whereArgs: [session.id],
    );
  }

  Future<void> deleteSession(String id) async {
    final db = await database;
    await db.delete(
      'chat_sessions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<ChatMessage>> getMessagesForSession(String sessionId) async {
    final db = await database;
    final maps = await db.query(
      'chat_messages',
      where: 'sessionId = ?',
      whereArgs: [sessionId],
      orderBy: 'timestamp ASC',
    );
    return maps.map((map) => ChatMessage.fromMap(map)).toList();
  }

  Future<void> saveMessage(ChatMessage message, String sessionId) async {
    final db = await database;
    final map = message.toMap();
    map['sessionId'] = sessionId;
    
    final existing = await db.query(
      'chat_messages',
      where: 'id = ?',
      whereArgs: [message.id],
    );
    
    if (existing.isEmpty) {
      await db.insert('chat_messages', map);
    } else {
      await db.update(
        'chat_messages',
        map,
        where: 'id = ?',
        whereArgs: [message.id],
      );
    }

    await db.update(
      'chat_sessions',
      {'lastMessageAt': message.timestamp.millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [sessionId],
    );
  }

  Future<void> deleteMessage(String messageId) async {
    final db = await database;
    await db.delete(
      'chat_messages',
      where: 'id = ?',
      whereArgs: [messageId],
    );
  }

  Future<List<AiPersona>> getAllPersonas() async {
    final db = await database;
    final maps = await db.query('ai_personas', orderBy: 'createdAt ASC');
    return maps.map((map) => AiPersona.fromMap(map)).toList();
  }

  Future<AiPersona?> getPersona(String id) async {
    final db = await database;
    final maps = await db.query(
      'ai_personas',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return AiPersona.fromMap(maps.first);
  }

  Future<String> savePersona(AiPersona persona) async {
    final db = await database;
    await db.insert('ai_personas', persona.toMap());
    return persona.id;
  }

  Future<void> updatePersona(AiPersona persona) async {
    final db = await database;
    await db.update(
      'ai_personas',
      persona.toMap(),
      where: 'id = ?',
      whereArgs: [persona.id],
    );
  }

  Future<void> deletePersona(String id) async {
    final db = await database;
    await db.delete(
      'ai_personas',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> clearOldSessions({int keepDays = 30}) async {
    final db = await database;
    final cutoff = DateTime.now().subtract(Duration(days: keepDays));
    await db.delete(
      'chat_sessions',
      where: 'lastMessageAt < ?',
      whereArgs: [cutoff.millisecondsSinceEpoch],
    );
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}