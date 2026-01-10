import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'config/themes.dart';
import 'services/storage_service.dart';
import 'services/chat_service.dart';
import 'services/image_generation_service.dart';
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

  runApp(DocanApp(storageService: storageService, initialTheme: savedTheme));
}

class DocanApp extends StatelessWidget {
  final StorageService storageService;
  final LiquidGlassTheme initialTheme;

  const DocanApp({
    super.key,
    required this.storageService,
    required this.initialTheme,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Theme provider
        ChangeNotifierProvider(
          create: (_) =>
              ThemeProvider()..loadFromPreferences(theme: initialTheme),
        ),
        // Chat service
        ChangeNotifierProvider(
          create: (_) => ChatService(storageService)..initialize(),
        ),
        // Image generation service
        ChangeNotifierProvider(
          create: (_) => ImageGenerationService(storageService)..initialize(),
        ),
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
