# NIM Builder - Flutter AI App with Termux Bridge

## Overview
NIM Builder is a Flutter AI application that uses Nvidia NIM API for intelligence and bridges directly into the Termux environment to execute commands, manage files, and run code.

## Features
- **AI Brain**: Nvidia NIM (OpenAI-compatible) API integration
- **Termux Bridge**: Execute commands via Termux RUN_COMMAND intent
- **Chat View**: Material 3 style with code block syntax highlighting
- **Live Terminal**: Real-time xterm.dart terminal view
- **File Explorer**: Browse and manage files in Termux home directory

## Setup Guide

### 1. Prerequisites

```bash
# Install Flutter SDK
flutter --version

# Install dependencies
cd nim_builder
flutter pub get
```

### 2. Termux Configuration (Required)

The Termux app must be configured to accept external commands from NIM Builder.

#### Step 1: Install Termux
- Get Termux from F-Droid (recommended) or Play Store
- Note: The Play Store version is outdated

#### Step 2: Enable External Apps
Open Termux and run:

```bash
# Create or edit the termux.properties file
echo "allow-external-apps=true" > ~/.termux/termux.properties

# Alternative: Use termux-setup-storage first, then edit
termux-setup-storage
```

Then create the file manually:
```bash
# Open in editor
vi ~/.termux/termux.properties
```

Add this line:
```
allow-external-apps = true
```

#### Step 3: Verify Configuration
```bash
# Check the file exists
cat ~/.termux/termux.properties

# Should output: allow-external-apps=true
```

### 3. Android Permissions

The AndroidManifest.xml includes:
- `com.termux.permission.RUN_COMMAND` - Execute commands in Termux
- Internet permission for NIM API calls
- Storage permissions for reading Termux output files

### 4. API Key Setup

1. Get your Nvidia NIM API key from https://build.nvidia.com/
2. Open the NIM Builder app
3. Go to Settings (gear icon)
4. Enter your API key
5. Save

### 5. Building the App

```bash
# Debug build
flutter build apk --debug

# Release build
flutter build apk --release

# Build for Android
flutter build apk --debug --target-platform android-arm64
```

## Architecture

### Core Components

```
lib/
├── main.dart                    # App entry point
├── models/
│   └── chat_message.dart       # Data models
├── providers/
│   └── chat_providers.dart    # Riverpod state management
├── screen
│   ├── home_screen.dart        # Main navigation
│   ├── chat_screen.dart      # AI chat interface
│   ├── terminal_view.dart    # Live terminal
│   └── file_explorer_screen.dart # File browser
├── services/
│   ├── nim_service.dart       # Nvidia NIM API
│   └── terminal_service.dart # Termux bridge
└── theme/
    └── app_theme.dart       # Glassmorphism theme
```

### Key Services

#### TerminalService
Handles communication with Termux via android_intent_plus:
- `executeCommand(String)` - Run shell commands
- `executeShellCommand(String)` - Execute bash scripts
- `listDirectory(String)` - List files in a directory
- `getGeneratedFiles()` - Get AI-generated files
- `readFile(String)` - Read file contents
- `writeFile(String, String)` - Write file

#### NimService
Handles Nvidia NIM API interactions:
- `sendMessage(String)` - Send message to AI
- Parses code blocks from responses
- Streams responses for real-time display

### Intent Communication

The app uses `com.termux.RUN_COMMAND` intent:
```dart
final intent = AndroidIntent(
  action: 'com.termux.RUN_COMMAND',
  package: 'com.termux',
  arguments: {
    'command': 'ls -la $HOME',
    'output_file': '/path/to/output.txt',
  },
);
```

### Output File Pattern
Commands write output to temporary files:
- Format: `nim_builder_output_<timestamp>.txt`
- Read after command execution completes
- Auto-delete after reading

## Usage

### Chat Commands
The AI understands code blocks marked with language identifiers:
- `bash` / `sh` / `shell` - Execute shell commands
- `python` - Run Python code
- `javascript` - Run Node.js code
- Any other block - Display but don't execute

Example AI interaction:
```
User: List my files
AI: I'll list your home directory.
```bash
ls -la $HOME
```
```
App executes and shows output
```

### Quick Actions
From the empty chat screen:
- "List files" - `ls -la $HOME`
- "System info" - `uname -a`
- "Storage" - `df -h`
- "Processes" - `ps aux`

### Terminal View
Direct terminal access:
- Type commands manually
- Use arrow keys for history
- Ctrl+C to cancel
- Tab for completion

### File Explorer
Browse Termux files:
- Tap to open/view
- Long-press for options
- Create new files/folders
- Delete files

## Troubleshooting

### Termux Not Found
1. Install Termux from F-Droid
2. Ensure `allow-external-apps=true` is set
3. Restart both apps

### Command Timeout
Default timeout is 30 seconds. Modify in TerminalService:
```dart
final result = await executeCommand(command, timeoutMs: 60000);
```

### Permission Denied
1. Check AndroidManifest.xml has the permission
2. Reinstall the app
3. Check Termux has storage permission

### API Errors
1. Verify API key is correct
2. Check internet connection
3. Verify model name in nim_service.dart

## License
MIT License - See LICENSE file for details