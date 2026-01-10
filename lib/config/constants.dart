/// App constants for Docan
library;

class AppConstants {
  AppConstants._();

  // App Info
  static const String appName = 'Docan';
  static const String appVersion = '1.0.0';

  // API Endpoints
  static const String geminiBaseUrl =
      'https://generativelanguage.googleapis.com/v1beta';
  static const String openAIBaseUrl = 'https://api.openai.com/v1';
  static const String claudeBaseUrl = 'https://api.anthropic.com/v1';
  static const String ollamaDefaultUrl = 'http://localhost:11434';
  static const String lmStudioDefaultUrl = 'http://localhost:1234/v1';

  // Default Models
  static const String defaultGeminiModel = 'gemini-2.5-flash';
  static const String defaultOpenAIModel = 'gpt-4o';
  static const String defaultClaudeModel = 'claude-sonnet-4-20250514';
  static const String defaultOllamaModel = 'llama3.2';
  static const String defaultLMStudioModel = 'default';

  // AI Parameters
  static const double defaultTemperature = 0.7;
  static const int defaultMaxTokens = 2048;
  static const double minTemperature = 0.0;
  static const double maxTemperature = 2.0;
  static const int minMaxTokens = 256;
  static const int maxMaxTokens = 8192;

  // Liquid Glass Animation Durations
  static const Duration entryExitDuration = Duration(milliseconds: 500);
  static const Duration hoverDuration = Duration(milliseconds: 175);
  static const Duration buttonPressDuration = Duration(milliseconds: 100);
  static const Duration buttonReleaseDuration = Duration(milliseconds: 300);
  static const Duration morphDuration = Duration(milliseconds: 650);

  // Liquid Glass Blur Values
  static const double blurMin = 10.0;
  static const double blurDefault = 30.0;
  static const double blurMax = 40.0;
  static const double blurScrolling = 15.0;

  // Layout Breakpoints
  static const double mobileBreakpoint = 600.0;
  static const double tabletBreakpoint = 900.0;
  static const double desktopBreakpoint = 1200.0;

  // Sidebar
  static const double sidebarWidth = 240.0;
  static const double sidebarCollapsedWidth = 72.0;

  // Spacing (8pt grid)
  static const double spacingXS = 4.0;
  static const double spacingS = 8.0;
  static const double spacingM = 16.0;
  static const double spacingL = 24.0;
  static const double spacingXL = 32.0;

  // Border Radius
  static const double radiusS = 12.0;
  static const double radiusM = 20.0;
  static const double radiusL = 28.0;
  static const double radiusNavBar = 30.0;

  // Nav Bar Heights
  static const double navBarHeightFull = 60.0;
  static const double navBarHeightCompact = 44.0;

  // Message Bubble
  static const double bubbleMaxWidthRatio = 0.75;
  static const double bubblePadding = 12.0;

  // Storage Keys
  static const String keyGeminiApiKey = 'gemini_api_key';
  static const String keyOpenAIApiKey = 'openai_api_key';
  static const String keyClaudeApiKey = 'claude_api_key';
  static const String keyOllamaUrl = 'ollama_url';
  static const String keyLMStudioUrl = 'lmstudio_url';
  static const String keyThemeMode = 'theme_mode';
  static const String keyTemperature = 'temperature';
  static const String keyMaxTokens = 'max_tokens';
  static const String keySystemPrompt = 'system_prompt';
  static const String keySelectedProvider = 'selected_provider';
  static const String keySelectedModel = 'selected_model';
  static const String keyConversations = 'conversations';
}
