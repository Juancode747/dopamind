import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/notification_service.dart';
import '../services/timer_service.dart';
import 'home_screen.dart';
import 'tasks_screen.dart';
import 'mindfulness_screen.dart';
import 'focus_screen.dart';
import 'journal_screen.dart';
import 'achievements_screen.dart';

/// Every feature route lives inside this shell, so pushing a route cannot hide
/// the main navigation. Dialogs and sheets remain temporary overlays.
class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final _navigator = GlobalKey<NavigatorState>();
  final _route = ValueNotifier<String>('/');
  late final _observer = _ShellObserver(_route);
  static const _destinations = [
    '/',
    '/tasks',
    '/mindfulness',
    '/journal',
    '/achievements',
  ];

  @override
  void initState() {
    super.initState();
    NotificationService().taskToOpen.addListener(_openNotification);
    WidgetsBinding.instance.addPostFrameCallback((_) => _openNotification());
  }

  void _openNotification() {
    if (!mounted || NotificationService().taskToOpen.value == null) return;
    NotificationService().taskToOpen.value = null;
    _navigate('/tasks');
  }

  Future<void> _navigate(String route) async {
    if (route == _route.value) return;
    final timer = context.read<TimerService>();
    if (timer.isRunning || timer.isPaused) {
      final leave = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('¿Salir de la práctica?'),
          content: const Text('La sesión se detendrá al cambiar de sección.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Continuar aquí'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Salir'),
            ),
          ],
        ),
      );
      if (leave != true || !mounted) return;
      // The screens receive the pop and finish their own session exactly once.
    }
    ScaffoldMessenger.of(context).clearSnackBars();
    final navigator = _navigator.currentState!;
    navigator.popUntil((route) => route.isFirst);
    if (route != '/') navigator.pushNamed(route);
  }

  @override
  void dispose() {
    NotificationService().taskToOpen.removeListener(_openNotification);
    _route.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: NavigatorPopHandler<Object?>(
      onPopWithResult: (_) => _navigator.currentState!.maybePop(),
      child: Navigator(
        key: _navigator,
        observers: [_observer],
        onGenerateRoute: (settings) {
          final screen = switch (settings.name) {
            '/tasks' => const TasksScreen(),
            '/mindfulness' => const MindfulnessScreen(),
            '/focus' => const FocusScreen(),
            '/journal' => const JournalScreen(),
            '/achievements' => const AchievementsScreen(),
            _ => const HomeScreen(),
          };
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => screen,
          );
        },
      ),
    ),
    bottomNavigationBar: ValueListenableBuilder<String>(
      valueListenable: _route,
      builder: (context, route, _) => NavigationBar(
        key: const ValueKey('main-navigation'),
        selectedIndex: route == '/focus'
            ? 2
            : _destinations.indexOf(route).clamp(0, 4),
        onDestinationSelected: (index) => _navigate(_destinations[index]),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            label: 'Inicio',
          ),
          NavigationDestination(icon: Icon(Icons.task_alt), label: 'Tareas'),
          NavigationDestination(
            icon: Icon(Icons.self_improvement),
            label: 'Plena',
          ),
          NavigationDestination(
            icon: Icon(Icons.book_outlined),
            label: 'Diario',
          ),
          NavigationDestination(
            icon: Icon(Icons.emoji_events_outlined),
            label: 'Logros',
          ),
        ],
      ),
    ),
  );
}

class _ShellObserver extends NavigatorObserver {
  _ShellObserver(this.current);
  final ValueNotifier<String> current;
  void _update(Route<dynamic>? route) {
    if (route is PageRoute) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (navigator?.mounted ?? false)
          current.value = route.settings.name ?? '/';
      });
    }
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _update(route);
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _update(previousRoute);
}
