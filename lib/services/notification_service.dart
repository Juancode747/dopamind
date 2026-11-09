import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/task.dart';

enum ReminderResult { exact, approximate, permissionDenied, unsupported }

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  final taskToOpen = ValueNotifier<int?>(null);
  bool _initialized = false;
  bool get isInitialized => _initialized;
  bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> init() async {
    if (_initialized || !_supported) return;
    tz_data.initializeTimeZones();
    await _notifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('ic_notification'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) {
        if (response.id != null) _notifications.cancel(response.id!);
        taskToOpen.value = int.tryParse(response.payload ?? '');
      },
    );
    final launch = await _notifications.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) {
      taskToOpen.value = int.tryParse(
        launch?.notificationResponse?.payload ?? '',
      );
    }
    _initialized = true;
  }

  /// Preserve the absolute instant selected in the phone's local time.
  static tz.TZDateTime scheduledInstant(DateTime date) =>
      tz.TZDateTime.from(date, tz.UTC);

  Future<ReminderResult> scheduleTask(
    Task task, {
    bool requestPermissions = true,
  }) async {
    if (!_supported) return ReminderResult.unsupported;
    if (!_initialized) await init();
    final date = task.dueDate;
    if (task.id == null || date == null || !date.isAfter(DateTime.now())) {
      throw ArgumentError(
        'El recordatorio necesita una tarea guardada y una fecha futura.',
      );
    }
    await _notifications.cancel(task.id!);
    final android = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    var exact = true;
    if (android != null) {
      var allowed = await android.areNotificationsEnabled() ?? false;
      if (!allowed && requestPermissions)
        allowed = await android.requestNotificationsPermission() ?? false;
      if (!allowed) return ReminderResult.permissionDenied;
      exact = await android.canScheduleExactNotifications() ?? false;
      if (!exact && requestPermissions)
        exact = await android.requestExactAlarmsPermission() ?? false;
    } else if (requestPermissions) {
      final allowed = await _notifications
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      if (allowed != true) return ReminderResult.permissionDenied;
    }
    await _notifications.zonedSchedule(
      task.id!,
      task.alarmEnabled ? '⏰ ${task.title}' : task.title,
      task.description?.isNotEmpty == true
          ? task.description
          : 'Es hora de tu tarea',
      scheduledInstant(date),
      details(alarm: task.alarmEnabled),
      androidScheduleMode: exact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: '${task.id}',
    );
    return exact ? ReminderResult.exact : ReminderResult.approximate;
  }

  static NotificationDetails details({required bool alarm}) =>
      NotificationDetails(
        android: AndroidNotificationDetails(
          alarm ? 'task_alarms_v2' : 'task_reminders_v2',
          alarm ? 'Alarmas de tareas' : 'Recordatorios de tareas',
          channelDescription: alarm
              ? 'Alarma audible durante un máximo de un minuto'
              : 'Avisos con sonido en la fecha elegida',
          icon: 'ic_notification',
          importance: Importance.max,
          priority: Priority.high,
          category: alarm
              ? AndroidNotificationCategory.alarm
              : AndroidNotificationCategory.reminder,
          playSound: true,
          enableVibration: true,
          sound: alarm
              ? const UriAndroidNotificationSound(
                  'content://settings/system/alarm_alert',
                )
              : null,
          audioAttributesUsage: alarm
              ? AudioAttributesUsage.alarm
              : AudioAttributesUsage.notification,
          additionalFlags: alarm ? Int32List.fromList([4]) : null,
          timeoutAfter: alarm ? 60000 : null,
          autoCancel: true,
          actions: [
            AndroidNotificationAction(
              'open',
              alarm ? 'Detener y ver tarea' : 'Ver tarea',
              showsUserInterface: true,
            ),
          ],
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );

  Future<Set<int>> pendingIds() async =>
      (await _notifications.pendingNotificationRequests())
          .map((n) => n.id)
          .toSet();
  Future<void> cancelNotification(int taskId) async {
    if (_initialized) await _notifications.cancel(taskId);
  }

  Future<void> cancelAllNotifications() async {
    if (_initialized) await _notifications.cancelAll();
  }
}
