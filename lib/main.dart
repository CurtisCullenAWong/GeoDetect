import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'services/history_service.dart';
import 'screens/get_started_screen.dart';
import 'screens/map_screen.dart';
import 'screens/analyze_screen.dart';
import 'screens/history_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  
  // Initialize history service
  final historyService = HistoryService();
  await historyService.initialize();
  
  runApp(
    ChangeNotifierProvider.value(
      value: historyService,
      child: const GeoDetectApp(),
    ),
  );
}

class GeoDetectApp extends StatelessWidget {
  const GeoDetectApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GeoDetect',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF008080),
          brightness: Brightness.light,
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const GetStartedScreen(),
        '/map': (context) => const MapScreen(),
        '/analyze': (context) => const AnalyzeScreen(),
        '/history': (context) => const HistoryScreen(),
      },
    );
  }
}