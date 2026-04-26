import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import '../models/chat_message.dart';
import '../providers/chat_providers.dart';
import '../services/settings_service.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late TextEditingController _apiKeyController;
  late TextEditingController _customModelController;
  late TextEditingController _temperatureController;
  late TextEditingController _maxTokensController;
  
  String _selectedModel = 'meta/llama-3.1-405b-instruct';
  String _selectedPersona = 'default_terminal';
  bool _isDarkMode = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _apiKeyController = TextEditingController();
    _customModelController = TextEditingController();
    _temperatureController = TextEditingController(text: '0.7');
    _maxTokensController = TextEditingController(text: '4096');
    _loadSettings();
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _customModelController.dispose();
    _temperatureController.dispose();
    _maxTokensController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final settingsService = ref.read(settingsServiceProvider);
    final settings = await settingsService.loadSettings();
    
    setState(() {
      _apiKeyController.text = settings.apiKey;
      _selectedModel = settings.model;
      _customModelController.text = settings.customModelId;
      _temperatureController.text = settings.temperature.toString();
      _maxTokensController.text = settings.maxTokens.toString();
      _isDarkMode = settings.isDarkMode;
      _selectedPersona = settings.currentPersonaId ?? 'default_terminal';
      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    final settingsNotifier = ref.read(nimSettingsProvider.notifier);
    
    await settingsNotifier.updateApiKey(_apiKeyController.text);
    await settingsNotifier.updateModel(_selectedModel, customModelId: _customModelController.text);
    
    await settingsNotifier.setDarkMode(_isDarkMode);
    await settingsNotifier.setCurrentPersona(_selectedPersona);
    
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Settings saved')),
    );
  }

  Future<void> _createPersona() async {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final promptController = TextEditingController();
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Persona'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: promptController,
                maxLines: 5,
                decoration: const InputDecoration(labelText: 'System Prompt'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    
    if (result == true) {
      final dbService = ref.read(databaseServiceProvider);
      final persona = AiPersona(
        id: const Uuid().v4(),
        name: nameController.text,
        description: descriptionController.text,
        systemPrompt: promptController.text,
        createdAt: DateTime.now(),
      );
      
      await dbService.savePersona(persona);
      ref.invalidate(allPersonasProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final personasAsync = ref.watch(allPersonasProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Settings',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        actions: [
          TextButton(
            onPressed: _saveSettings,
            child: const Text('Save'),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSection(
                  'API Configuration',
                  [
                    _buildApiKeyField(),
                    const SizedBox(height: 16),
                    _buildModelSelector(),
                    const SizedBox(height: 16),
                    _buildCustomModelField(),
                  ],
                ),
                const SizedBox(height: 24),
                _buildSection(
                  'Model Parameters',
                  [
                    _buildTemperatureSlider(),
                    const SizedBox(height: 16),
                    _buildMaxTokensSlider(),
                  ],
                ),
                const SizedBox(height: 24),
                _buildSection(
                  'AI Persona',
                  [
                    _buildPersonaSelector(personasAsync),
                    const SizedBox(height: 16),
                    _buildCreatePersonaButton(),
                  ],
                ),
                const SizedBox(height: 24),
                _buildSection(
                  'Appearance',
                  [
                    _buildDarkModeToggle(),
                  ],
                ),
                const SizedBox(height: 24),
                _buildSection(
                  'About',
                  [
                    ListTile(
                      leading: const Icon(Icons.info_outline),
                      title: const Text('Version'),
                      subtitle: const Text('1.0.0'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.code),
                      title: const Text('NIM Builder'),
                      subtitle: const Text('Powered by Nvidia NIM'),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ).animate().fadeIn(),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildApiKeyField() {
    return TextField(
      controller: _apiKeyController,
      decoration: InputDecoration(
        labelText: 'Nvidia NIM API Key',
        hintText: 'Enter your API key',
        prefixIcon: const Icon(Icons.key),
        suffixIcon: IconButton(
          icon: const Icon(Icons.visibility_off),
          onPressed: () {},
        ),
      ),
      obscureText: true,
    );
  }

  Widget _buildModelSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Model',
          style: GoogleFonts.inter(
            fontSize: 12,
            color: Theme.of(context).colorScheme.secondary,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedModel,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.model_training),
          ),
          items: NimModel.availableModels.map((model) {
            return DropdownMenuItem(
              value: model.id,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(model.displayName),
                  Text(
                    model.description,
                    style: TextStyle(
                      fontSize: 10,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() => _selectedModel = value);
            }
          },
        ),
      ],
    );
  }

  Widget _buildCustomModelField() {
    return TextField(
      controller: _customModelController,
      decoration: const InputDecoration(
        labelText: 'Custom Model ID (Optional)',
        hintText: 'Use custom model instead of preset',
        prefixIcon: Icon(Icons.custom_services),
      ),
    );
  }

  Widget _buildTemperatureSlider() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Temperature',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Theme.of(context).colorScheme.secondary,
              ),
            ),
            Text(_temperatureController.text),
          ],
        ),
        Slider(
          value: double.tryParse(_temperatureController.text) ?? 0.7,
          min: 0.0,
          max: 2.0,
          divisions: 20,
          onChanged: (value) {
            setState(() {
              _temperatureController.text = value.toStringAsFixed(1);
            });
          },
        ),
      ],
    );
  }

  Widget _buildMaxTokensSlider() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Max Tokens',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Theme.of(context).colorScheme.secondary,
              ),
            ),
            Text(_maxTokensController.text),
          ],
        ),
        Slider(
          value: (double.tryParse(_maxTokensController.text) ?? 4096).clamp(256, 8192),
          min: 256,
          max: 8192,
          divisions: 31,
          onChanged: (value) {
            setState(() {
              _maxTokensController.text = value.toInt().toString();
            });
          },
        ),
      ],
    );
  }

  Widget _buildPersonaSelector(AsyncValue<List<AiPersona>> personasAsync) {
    return personasAsync.when(
      data: (personas) => DropdownButtonFormField<String>(
        value: _selectedPersona,
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.person),
        ),
        items: personas.map((persona) {
          return DropdownMenuItem(
            value: persona.id,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(persona.name),
                Text(
                  persona.description,
                  style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
        onChanged: (value) {
          if (value != null) {
            setState(() => _selectedPersona = value);
          }
        },
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('Error loading personas: $e'),
    );
  }

  Widget _buildCreatePersonaButton() {
    return OutlinedButton.icon(
      onPressed: _createPersona,
      icon: const Icon(Icons.add),
      label: const Text('Create Custom Persona'),
    );
  }

  Widget _buildDarkModeToggle() {
    return SwitchListTile(
      value: _isDarkMode,
      onChanged: (value) {
        setState(() => _isDarkMode = value);
      },
      title: const Text('Dark Mode'),
      subtitle: const Text('Use dark theme'),
      secondary: const Icon(Icons.dark_mode),
    );
  }
}