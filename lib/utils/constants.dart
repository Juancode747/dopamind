class AppConstants {
  static const String appName = 'DopamiND';
  static const String appTagline = 'Regula tu dopamina';
  static const String appDescription =
      'Reduce tu tiempo en pantalla y fomenta actividades de atención plena';

  static const int maxFocusMinutes = 120;
  static const int minFocusMinutes = 5;
  static const int defaultFocusMinutes = 25;
  static const int pomodoroBreakMinutes = 5;
  static const int pomodoroLongBreakMinutes = 15;
  static const int pomodoroSessionsBeforeLongBreak = 4;

  static const String onboardingKey = 'onboarding_completed';
  static const String userPointsKey = 'user_points';
  static const String userLevelKey = 'user_level';
  static const String streakKey = 'current_streak';
  static const String lastActiveKey = 'last_active_date';

  static const Map<String, List<String>> mindfulnessPrompts = {
    'respiracion': [
      'Inhala durante 4 segundos',
      'Mantén el aire 4 segundos',
      'Exhala lentamente en 6 segundos',
      'Repite el ciclo 10 veces',
    ],
    'escaneo': [
      'Cierra los ojos y relaja el cuerpo',
      'Nota cada parte de tu cuerpo',
      'Observa tus pensamientos sin juzgar',
      'Vuelve al presente lentamente',
    ],
    'gratitud': [
      'Piensa en 3 cosas por las que estás agradecido',
      'Siente la emoción de gratitud',
      'Respira profundo y sonríe',
      'Lleva esa sensación al día',
    ],
  };

  static const List<String> journalPrompts = [
    '¿Cómo me sentí hoy y por qué?',
    '¿Qué hice bien hoy?',
    '¿Qué puedo mejorar mañana?',
    '¿Qué me quitó paz hoy?',
    '¿Qué actividad me hizo sentir presente?',
    '¿Cuánto tiempo estuve en pantalla hoy?',
    '¿Qué haré diferente mañana?',
    '¿Qué es lo más importante que aprendí hoy?',
  ];

  static const Map<String, String> achievementIcons = {
    'first_task': '✓',
    'streak_3': '🔥',
    'streak_7': '🌟',
    'streak_30': '👑',
    'mindful_1': '🧘',
    'mindful_10': '🧠',
    'focus_1': '🎯',
    'focus_10': '🏆',
    'journal_1': '📝',
    'journal_7': '📖',
    'photo_verify': '📸',
    'level_5': '⭐',
    'level_10': '💎',
    'tasks_50': '🚀',
  };
}
