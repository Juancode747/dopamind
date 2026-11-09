import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dopamind/models/task.dart';
import 'package:dopamind/models/journal_entry.dart';
import 'package:dopamind/models/achievement.dart';
import 'package:dopamind/models/photo_analysis.dart';
import 'package:dopamind/screens/app_shell.dart';
import 'package:dopamind/services/app_provider.dart';
import 'package:dopamind/services/database_service.dart';
import 'package:dopamind/services/notification_service.dart';
import 'package:dopamind/services/camera_service.dart';
import 'package:dopamind/services/timer_service.dart';

class MemoryTasks implements DatabaseService {
  final tasks = <Task>[];
  @override
  Future<List<Task>> getTasks({bool? completed, String? priority}) async =>
      List.of(tasks);
  @override
  Future<List<JournalEntry>> getJournalEntries() async => [];
  @override
  Future<List<Achievement>> getAchievements() async => [];
  @override
  Future<int> insertTask(Task task) async {
    tasks.add(task.copyWith(id: tasks.length + 1));
    return tasks.length;
  }

  @override
  Future<int> updateTask(Task task) async {
    final i = tasks.indexWhere((t) => t.id == task.id);
    tasks[i] = task;
    return 1;
  }

  @override
  Future<void> incrementAchievement(String key, {int incrementBy = 1}) async {}
  @override
  Future<int> insertSession(String type, int durationMinutes) async => 1;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  final calls = <MethodCall>[];
  var allowed = true;
  var exact = true;
  setUp(() async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    allowed = true;
    exact = true;
    calls.clear();
    SharedPreferences.setMockInitialValues({'dated_reminders_v2': true});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return switch (call.method) {
            'initialize' => true,
            'getNotificationAppLaunchDetails' => {
              'notificationLaunchedApp': false,
            },
            'areNotificationsEnabled' ||
            'requestNotificationsPermission' => allowed,
            'canScheduleExactNotifications' ||
            'requestExactAlarmsPermission' => exact,
            'pendingNotificationRequests' => <Map<String, dynamic>>[],
            _ => null,
          };
        });
    await NotificationService().init();
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  test(
    'Reminder preserves date and instant, uses DB id, and does not repeat',
    () async {
      final date = DateTime.now().add(const Duration(days: 4, hours: 2));
      final task = Task(
        id: 42,
        title: 'Loza',
        dueDate: date,
        alarmEnabled: true,
      );
      expect(
        await NotificationService().scheduleTask(task),
        ReminderResult.exact,
      );
      final args =
          calls.lastWhere((call) => call.method == 'zonedSchedule').arguments
              as Map;
      expect(args['id'], 42);
      expect(args['payload'], '42');
      expect(args['matchDateTimeComponents'], isNull);
      expect(
        NotificationService.scheduledInstant(date).millisecondsSinceEpoch,
        date.millisecondsSinceEpoch,
      );
      final android = args['platformSpecifics'] as Map;
      expect(android['channelId'], 'task_alarms_v2');
      expect(android['additionalFlags'], [4]);
      expect(android['timeoutAfter'], 60000);
    },
  );

  test(
    'Denied permission is reported and never reported as scheduled',
    () async {
      allowed = false;
      expect(
        await NotificationService().scheduleTask(
          Task(
            id: 1,
            title: 'Tarea',
            dueDate: DateTime.now().add(const Duration(days: 1)),
          ),
        ),
        ReminderResult.permissionDenied,
      );
      expect(calls.where((call) => call.method == 'zonedSchedule'), isEmpty);
    },
  );

  test(
    'Exact permission denied produces an explicit approximate reminder',
    () async {
      exact = false;
      expect(
        await NotificationService().scheduleTask(
          Task(
            id: 2,
            title: 'Tarea',
            dueDate: DateTime.now().add(const Duration(days: 1)),
          ),
        ),
        ReminderResult.approximate,
      );
    },
  );

  test(
    'Task roundtrip keeps date and alarm; v1 records default to no alarm',
    () {
      final task = Task(
        title: 'Lavar',
        dueDate: DateTime(2030, 12, 31, 23, 15),
        scheduledHour: 23,
        scheduledMinute: 15,
        alarmEnabled: true,
      );
      final restored = Task.fromMap(task.toMap());
      expect(restored.dueDate, task.dueDate);
      expect(restored.alarmEnabled, isTrue);
      final old = task.toMap()..remove('alarm_enabled');
      expect(Task.fromMap(old).alarmEnabled, isFalse);
    },
  );

  test('Spanish task vocabulary matches real English labels, not unrelated objects', () {
    final camera = CameraService();
    expect(
      camera.verifyTaskCompletion('Guardar los platos', ['Dishware']),
      isTrue,
    );
    expect(camera.verifyTaskCompletion('Lavar tazas', ['Coffee cup']), isTrue);
    expect(
      camera.verifyTaskCompletion('Ordenar el cuaderno', ['Notebook']),
      isTrue,
    );
    expect(camera.verifyTaskCompletion('Lavar tazas', ['Cat']), isFalse);
    final result = PhotoAnalysis.merge([
      const PhotoLabel('dish', .3),
      const PhotoLabel('dish', .7),
      const PhotoLabel('cat', .3),
    ]);
    expect(result.labels.length, 2);
    expect(result.reliableLabels, ['dish']);
  });

  testWidgets(
    'Navigation stays visible across sections, dialogs, quick actions and back',
    (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final db = MemoryTasks();
      final provider = AppProvider(
        await SharedPreferences.getInstance(),
        database: db,
      );
      await provider.ready;
      final timer = TimerService();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: provider),
            ChangeNotifierProvider.value(value: timer),
          ],
          child: const MaterialApp(home: AppShell()),
        ),
      );
      await tester.pumpAndSettle();
      final bar = find.byKey(const ValueKey('main-navigation'));
      for (final label in ['Tareas', 'Diario', 'Logros', 'Plena', 'Inicio']) {
        await tester.tap(find.descendant(of: bar, matching: find.text(label)));
        await tester.pumpAndSettle();
        expect(bar, findsOneWidget);
      }
      await tester.tap(find.descendant(of: bar, matching: find.text('Tareas')));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.add_circle_rounded));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Lavar tazas');
      await tester.ensureVisible(find.text('Elegir fecha y hora (opcional)'));
      await tester.tap(find.text('Elegir fecha y hora (opcional)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Elegir'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Elegir'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Sonar como alarma'));
      await tester.tap(find.text('Sonar como alarma'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Crear Tarea'));
      await tester.tap(find.text('Crear Tarea'));
      await tester.pumpAndSettle();
      expect(db.tasks.single.title, 'Lavar tazas');
      expect(db.tasks.single.alarmEnabled, isTrue);
      expect(db.tasks.single.dueDate, isNotNull);
      expect(
        calls
            .where((call) => call.method == 'zonedSchedule')
            .last
            .arguments['id'],
        db.tasks.single.id,
      );
      expect(bar, findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(bar, findsOneWidget);
      expect(find.text('DopamiND'), findsOneWidget);
      expect(tester.getRect(bar).bottom, lessThanOrEqualTo(740));
      await tester.tap(find.descendant(of: bar, matching: find.text('Plena')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Comenzar'));
      await tester.tap(find.text('Comenzar'));
      await tester.pump(const Duration(seconds: 1));
      expect(timer.isRunning, isTrue);
      await tester.tap(find.descendant(of: bar, matching: find.text('Tareas')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salir'));
      await tester.pumpAndSettle();
      expect(timer.isRunning, isFalse);
      expect(bar, findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      provider.dispose();
      timer.dispose();
      debugDefaultTargetPlatformOverride = null;
    },
  );
}
