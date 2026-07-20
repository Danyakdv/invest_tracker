import 'package:flutter/material.dart';
import 'services/storage_service.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await StorageService.init();
  runApp(const InvestTrackerApp());
}

class InvestTrackerApp extends StatelessWidget {
  const InvestTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    final seed = const Color(0xFF2E7D5B); // спокойный зелёный, ассоциация с ростом капитала

    return MaterialApp(
      title: 'Invest Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: seed),
        appBarTheme: const AppBarTheme(centerTitle: true),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.dark,
        ),
        appBarTheme: const AppBarTheme(centerTitle: true),
      ),
      themeMode: ThemeMode.system,
      home: const HomeScreen(),
    );
  }
}
