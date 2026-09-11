import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'services/app_provider.dart';
import 'services/timer_service.dart';
import 'screens/onboarding_screen.dart';
import 'screens/home_screen.dart';
import 'screens/tasks_screen.dart';
import 'screens/mindfulness_screen.dart';
import 'screens/focus_screen.dart';
import 'screens/journal_screen.dart';
import 'screens/achievements_screen.dart';
import 'utils/colors.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  final prefs = await SharedPreferences.getInstance();
  runApp(MyApp(prefs: prefs));
}

class MyApp extends StatelessWidget {
  final SharedPreferences prefs;

  const MyApp({super.key, required this.prefs});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppProvider(prefs)),
        ChangeNotifierProvider(create: (_) => TimerService()),
      ],
      child: MaterialApp(
        title: 'DopamiND',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.primary,
            brightness: Brightness.light,
          ),
          scaffoldBackgroundColor: AppColors.background,
          appBarTheme: const AppBarTheme(
            elevation: 0,
            backgroundColor: Colors.transparent,
            foregroundColor: AppColors.textPrimary,
          ),
          cardTheme: CardThemeData(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          useMaterial3: true,
        ),
        home: _buildInitialRoute(),
        routes: {
          '/home': (_) => const HomeScreen(),
          '/tasks': (_) => const TasksScreen(),
          '/mindfulness': (_) => const MindfulnessScreen(),
          '/focus': (_) => const FocusScreen(),
          '/journal': (_) => const JournalScreen(),
          '/achievements': (_) => const AchievementsScreen(),
        },
      ),
    );
  }

  Widget _buildInitialRoute() {
    final onboardingCompleted = prefs.getBool('onboarding_completed') ?? false;
    if (onboardingCompleted) {
      return const HomeScreen();
    }
    return const OnboardingScreen();
  }
}
