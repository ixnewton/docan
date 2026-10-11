import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'config/themes.dart';
import 'services/storage_service.dart';
import 'services/chat_service.dart';
import 'services/image_generation_service.dart';
import 'services/playbook_service.dart';
import 'utils/theme_provider.dart';
import 'utils/screen_size_helper.dart';
import 'screens/mobile/mobile_chat_screen.dart';
import 'screens/desktop/desktop_chat_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive for local storage
  await Hive.initFlutter();

  // Initialize storage service
  final storageService = await StorageService.getInstance();

  // Load saved theme
  final savedTheme = await storageService.getTheme();
  final isDarkMode = savedTheme == 'dark';

  // Create services up front and await chat initialization so stored
  // settings (API keys, local server URLs) are loaded before the UI
  // tests provider availability
  final playbookService = PlaybookService()..initialize();
  final chatService = ChatService(storageService)
    ..setPlaybookService(playbookService);
  await chatService.initialize();
  final imageService = ImageGenerationService(storageService)..initialize();

  runApp(
    DocanApp(
      storageService: storageService,
      initialDarkMode: isDarkMode,
      chatService: chatService,
      playbookService: playbookService,
      imageService: imageService,
    ),
  );
}

class DocanApp extends StatelessWidget {
  final StorageService storageService;
  final bool initialDarkMode;
  final ChatService chatService;
  final PlaybookService playbookService;
  final ImageGenerationService imageService;

  const DocanApp({
    super.key,
    required this.storageService,
    required this.initialDarkMode,
    required this.chatService,
    required this.playbookService,
    required this.imageService,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Theme provider
        ChangeNotifierProvider(
          create: (_) =>
              ThemeProvider()..loadFromPreferences(isDarkMode: initialDarkMode),
        ),
        // Playbook service (created first)
        ChangeNotifierProvider.value(value: playbookService),
        // Chat service (with playbook service connected)
        ChangeNotifierProvider.value(value: chatService),
        // Image generation service
        ChangeNotifierProvider.value(value: imageService),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'Docan',
            debugShowCheckedModeBanner: false,
            theme: themeProvider.lightTheme,
            darkTheme: themeProvider.darkTheme,
            themeMode: themeProvider.themeMode,
            home: const ResponsiveHome(),
          );
        },
      ),
    );
  }
}

/// Responsive home that switches between mobile and desktop layouts
class ResponsiveHome extends StatelessWidget {
  const ResponsiveHome({super.key});

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout(
      mobile: const MobileChatScreen(),
      desktop: const DesktopChatScreen(),
    );
  }
}
