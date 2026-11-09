import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/task.dart';
import '../models/journal_entry.dart';
import '../models/achievement.dart';
import '../services/database_service.dart';
import 'notification_service.dart';

class AppProvider extends ChangeNotifier {
  final DatabaseService _db;
  final SharedPreferences _prefs;
  late final Future<void> ready;

  List<Task> _tasks = [];
  List<JournalEntry> _journalEntries = [];
  List<Achievement> _achievements = [];
  int _userPoints = 0;
  int _userLevel = 1;
  int _currentStreak = 0;
  bool _onboardingCompleted = false;

  AppProvider(this._prefs, {DatabaseService? database})
    : _db = database ?? DatabaseService() {
    ready = _loadData();
  }

  List<Task> get tasks => _tasks;
  List<JournalEntry> get journalEntries => _journalEntries;
  List<Achievement> get achievements => _achievements;
  int get userPoints => _userPoints;
  int get userLevel => _userLevel;
  int get currentStreak => _currentStreak;
  bool get onboardingCompleted => _onboardingCompleted;

  List<Task> get pendingTasks => _tasks.where((t) => !t.completed).toList();
  List<Task> get completedTasks => _tasks.where((t) => t.completed).toList();
  List<Task> get highPriorityTasks =>
      _tasks.where((t) => !t.completed && t.priority == 'high').toList();

  int get todayCompletedCount {
    final today = DateTime.now();
    return _tasks
        .where(
          (t) =>
              t.completed &&
              t.completedAt != null &&
              t.completedAt!.year == today.year &&
              t.completedAt!.month == today.month &&
              t.completedAt!.day == today.day,
        )
        .length;
  }

  int get totalCompletedCount => _tasks.where((t) => t.completed).length;

  double get levelProgress => (_userPoints % 100) / 100;

  Future<void> _loadData() async {
    _onboardingCompleted = _prefs.getBool('onboarding_completed') ?? false;
    _userPoints = _prefs.getInt('user_points') ?? 0;
    _userLevel = _prefs.getInt('user_level') ?? 1;
    _currentStreak = _prefs.getInt('current_streak') ?? 0;

    _tasks = await _db.getTasks();
    _journalEntries = await _db.getJournalEntries();
    _achievements = await _db.getAchievements();

    _checkStreak();
    await _restoreReminders();
    notifyListeners();
  }

  void _checkStreak() {
    final lastActive = _prefs.getString('last_active_date');
    if (lastActive == null) {
      _currentStreak = 1;
      _prefs.setInt('current_streak', _currentStreak);
      _prefs.setString('last_active_date', DateTime.now().toIso8601String());
      return;
    }

    final lastDate = DateTime.parse(lastActive);
    final today = DateTime.now();
    final difference = DateTime(
      today.year,
      today.month,
      today.day,
    ).difference(DateTime(lastDate.year, lastDate.month, lastDate.day)).inDays;

    if (difference == 1) {
      _currentStreak++;
      _prefs.setInt('current_streak', _currentStreak);
      _updateStreakAchievements();
    } else if (difference > 1) {
      _currentStreak = 1;
      _prefs.setInt('current_streak', _currentStreak);
    }

    _prefs.setString('last_active_date', today.toIso8601String());
  }

  void _updateStreakAchievements() {
    if (_currentStreak >= 3) _db.incrementAchievement('streak_3');
    if (_currentStreak >= 7) _db.incrementAchievement('streak_7');
    if (_currentStreak >= 30) _db.incrementAchievement('streak_30');
  }

  void completeOnboarding() {
    _onboardingCompleted = true;
    _prefs.setBool('onboarding_completed', true);
    notifyListeners();
  }

  Future<Task> addTask(Task task) async {
    final id = await _db.insertTask(task);
    final saved = task.copyWith(id: id);
    _tasks.insert(0, saved);
    notifyListeners();
    return saved;
  }

  Future<void> _restoreReminders() async {
    final notifications = NotificationService();
    if (!notifications.isInitialized) return;
    try {
      if (_prefs.getBool('dated_reminders_v2') != true) {
        // Remove the old hash-based repeating reminders once.
        await notifications.cancelAllNotifications();
        for (var index = 0; index < _tasks.length; index++) {
          final task = _tasks[index];
          if (!task.completed &&
              task.dueDate == null &&
              task.scheduledHour != null) {
            final now = DateTime.now();
            var date = DateTime(
              now.year,
              now.month,
              now.day,
              task.scheduledHour!,
              task.scheduledMinute ?? 0,
            );
            if (!date.isAfter(now))
              date = DateTime(
                now.year,
                now.month,
                now.day + 1,
                task.scheduledHour!,
                task.scheduledMinute ?? 0,
              );
            final updated = task.copyWith(dueDate: date);
            await _db.updateTask(updated);
            _tasks[index] = updated;
          }
        }
        await _prefs.setBool('dated_reminders_v2', true);
      }
      final pending = await notifications.pendingIds();
      // A previous save may have succeeded while cancelling its alarm failed.
      // Retry from the persisted task state after restarting the app.
      for (final task in _tasks.where((t) => t.completed)) {
        if (task.id != null && pending.contains(task.id)) {
          await _cancelCompletedReminder(task.id!);
        }
      }
      for (final task in _tasks) {
        if (!task.completed &&
            task.id != null &&
            task.dueDate != null &&
            task.dueDate!.isAfter(DateTime.now()) &&
            !pending.contains(task.id)) {
          await notifications.scheduleTask(task, requestPermissions: false);
        }
      }
    } catch (error) {
      debugPrint('No se pudieron restaurar los recordatorios: $error');
    }
  }

  /// Returns false only when the task was saved but its reminder could not
  /// be cancelled. Database failures still propagate to the caller.
  Future<bool> updateTask(Task task) async {
    await _db.updateTask(task);
    final index = _tasks.indexWhere((t) => t.id == task.id);
    if (index != -1) {
      _tasks[index] = task;
    }
    notifyListeners();
    if (task.completed && task.id != null) {
      return _cancelCompletedReminder(task.id!);
    }
    return true;
  }

  Future<bool> _cancelCompletedReminder(int id) async {
    try {
      await NotificationService().cancelNotification(id);
      return true;
    } catch (error) {
      debugPrint('Tarea guardada; no se pudo cancelar el aviso: $error');
      return false;
    }
  }

  Future<bool> completeTask(Task task) async {
    final updated = task.copyWith(completed: true, completedAt: DateTime.now());
    final reminderCancelled = await updateTask(updated);
    _addPoints(10);
    await _db.incrementAchievement('first_task');
    await _db.incrementAchievement('tasks_50');
    notifyListeners();
    return reminderCancelled;
  }

  Future<void> deleteTask(int id) async {
    await NotificationService().cancelNotification(id);
    await _db.deleteTask(id);
    _tasks.removeWhere((t) => t.id == id);
    notifyListeners();
  }

  Future<void> addJournalEntry(JournalEntry entry) async {
    final id = await _db.insertJournalEntry(entry);
    _journalEntries.insert(0, entry.copyWith(id: id));
    _addPoints(5);
    await _db.incrementAchievement('journal_1');
    final count = await _db.getJournalCount();
    if (count >= 7) await _db.incrementAchievement('journal_7');
    notifyListeners();
  }

  Future<void> deleteJournalEntry(int id) async {
    await _db.deleteJournalEntry(id);
    _journalEntries.removeWhere((e) => e.id == id);
    notifyListeners();
  }

  void addMindfulSession(int minutes) {
    _addPoints(minutes * 2);
    _db.incrementAchievement('mindful_1');
    _db.insertSession('mindfulness', minutes);
    notifyListeners();
  }

  void addFocusSession(int minutes) {
    _addPoints(minutes * 3);
    _db.incrementAchievement('focus_1');
    _db.insertSession('focus', minutes);
    notifyListeners();
  }

  void addPhotoVerification() {
    _addPoints(15);
    _db.incrementAchievement('photo_verify');
    notifyListeners();
  }

  void _addPoints(int points) {
    _userPoints += points;
    final newLevel = (_userPoints ~/ 100) + 1;
    if (newLevel > _userLevel) {
      _userLevel = newLevel;
      _prefs.setInt('user_level', _userLevel);
    }
    _prefs.setInt('user_points', _userPoints);
    notifyListeners();
  }

  Achievement? getAchievement(String key) {
    try {
      return _achievements.firstWhere((a) => a.key == key);
    } catch (_) {
      return null;
    }
  }
}
