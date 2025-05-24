import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/statistics_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/morestats_screen.dart';
import 'screens/tasks_screen.dart';
import 'screens/teams_screen.dart';
import 'screens/home_page.dart';
import 'screens/login_screen.dart';
import 'screens/growth_screen.dart';
import 'screens/achievements_screen.dart';
import 'screens/aiExplanation.dart';
import 'package:provider/provider.dart';
import 'providers/audio_service.dart';
import 'providers/theme_provider.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AudioService()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'Pomodoro App',
          debugShowCheckedModeBanner: false,
          theme: themeProvider.lightTheme,
          darkTheme: themeProvider.darkTheme,
          themeMode:
              themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          initialRoute: '/login',
          routes: {
            '/login': (context) => const LoginScreen(),
            '/': (context) => const HomePage(userId: 'user123'),
            '/home': (context) => const HomePage(userId: ''),
            '/tasks': (context) => const TasksScreen(),
            '/teams': (context) => const TeamsScreen(),
            '/statistics': (context) => const StatisticsScreen(),
            '/settings': (context) => const SettingsScreen(),
            '/morestats': (context) => const MoreStatsScreen(),
            '/growth': (context) => const GrowthScreen(),
            '/achievements': (context) => const AchievementsScreen(),
            '/ai_explanation': (context) => const AiExplanationPage(),
          },
        );
      },
    );
  }
}
