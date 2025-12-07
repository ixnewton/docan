import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/constants.dart';
import '../../models/ai_provider.dart';
import '../../services/chat_service.dart';
import '../../services/storage_service.dart';
import '../../components/settings_form.dart';
import '../../utils/liquid_glass_effects.dart';
import '../../utils/theme_provider.dart';

/// Desktop settings screen as a dialog with macOS Tahoe Liquid Glass design
class DesktopSettingsScreen extends StatefulWidget {
  const DesktopSettingsScreen({super.key});

  @override
  State<DesktopSettingsScreen> createState() => _DesktopSettingsScreenState();
}

class _DesktopSettingsScreenState extends State<DesktopSettingsScreen> {
  Map<AIProvider, String> _apiKeys = {};
  String _ollamaUrl = AppConstants.ollamaDefaultUrl;
  final Map<AIProvider, bool> _connectionStatus = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final storage = await StorageService.getInstance();
    
    final apiKeys = <AIProvider, String>{};
    for (final provider in AIProvider.values) {
      if (provider.requiresApiKey) {
        final key = await storage.getApiKey(provider);
        if (key != null) {
          apiKeys[provider] = key;
        }
      }
    }

    final ollamaUrl = await storage.getOllamaUrl();

    setState(() {
      _apiKeys = apiKeys;
      _ollamaUrl = ollamaUrl;
      _isLoading = false;
    });

    _testAllConnections();
  }

  Future<void> _testAllConnections() async {
    final chatService = context.read<ChatService>();
    
    for (final provider in AIProvider.values) {
      final isConnected = await chatService.testConnection(provider);
      if (mounted) {
        setState(() {
          _connectionStatus[provider] = isConnected;
        });
      }
    }
  }

  Future<void> _testConnection(AIProvider provider) async {
    final chatService = context.read<ChatService>();
    final isConnected = await chatService.testConnection(provider);
    
    if (mounted) {
      setState(() {
        _connectionStatus[provider] = isConnected;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isConnected
                ? '${provider.displayName} connected successfully'
                : 'Failed to connect to ${provider.displayName}',
          ),
          backgroundColor: isConnected ? Colors.green : Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenSize = MediaQuery.of(context).size;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: LiquidGlassContainer(
        width: 600,
        height: screenSize.height * 0.8,
        borderRadius: AppConstants.radiusL,
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(AppConstants.spacingM),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: theme.dividerColor.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Text(
                    'Settings',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  LiquidGlassIconButton(
                    icon: Icons.close,
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            
            // Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Consumer2<ChatService, ThemeProvider>(
                      builder: (context, chatService, themeProvider, child) {
                        return SettingsForm(
                          apiKeys: _apiKeys,
                          ollamaUrl: _ollamaUrl,
                          theme: themeProvider.theme,
                          accentColor: themeProvider.accentColor,
                          temperature: chatService.temperature,
                          maxTokens: chatService.maxTokens,
                          connectionStatus: _connectionStatus,
                          onApiKeyChanged: (provider, key) async {
                            setState(() {
                              _apiKeys[provider] = key;
                            });
                            await chatService.setApiKey(provider, key);
                          },
                          onOllamaUrlChanged: (url) async {
                            setState(() {
                              _ollamaUrl = url;
                            });
                            final storage = await StorageService.getInstance();
                            await storage.setOllamaUrl(url);
                          },
                          onThemeChanged: (theme) async {
                            themeProvider.setTheme(theme);
                            final storage = await StorageService.getInstance();
                            await storage.setTheme(theme);
                          },
                          onAccentColorChanged: (color) {
                            themeProvider.setAccentColor(color);
                          },
                          onTemperatureChanged: chatService.setTemperature,
                          onMaxTokensChanged: chatService.setMaxTokens,
                          onTestConnection: _testConnection,
                        );
                      },
                    ),
            ),
            
            // Footer
            Container(
              padding: const EdgeInsets.all(AppConstants.spacingM),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: theme.dividerColor.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Done'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
