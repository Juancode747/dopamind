import 'dart:convert';

import 'package:dopamind/models/task.dart';
import 'package:dopamind/screens/tasks_screen.dart';
import 'package:dopamind/services/app_provider.dart';
import 'package:dopamind/services/camera_service.dart';
import 'package:dopamind/services/notification_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'navigation_reminders_test.dart' show MemoryTasks;

class CapturedPhoto extends CameraService {
  @override
  bool get supportsAnalysis => false;
  @override
  bool get supportsCamera => true;
  @override
  Future<XFile?> takePhoto() async => XFile.fromData(
    base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScLttAAAAABJRU5ErkJggg==',
    ),
    mimeType: 'image/png',
  );
}

class FailedDatabase extends MemoryTasks {
  @override
  Future<int> updateTask(Task task) async =>
      throw PlatformException(code: 'sqlite_error', message: 'Disk full');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  var failCancel = false;
  var pending = <int>[];
  final cancelled = <int>[];
  setUp(() async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    failCancel = false;
    pending = [];
    cancelled.clear();
    SharedPreferences.setMockInitialValues({'dated_reminders_v2': true});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'cancel') {
            cancelled.add(call.arguments['id'] as int);
            if (failCancel) {
              throw PlatformException(
                code: 'error',
                message: 'Missing type parameter.',
              );
            }
          }
          return switch (call.method) {
            'initialize' => true,
            'getNotificationAppLaunchDetails' => {
              'notificationLaunchedApp': false,
            },
            'pendingNotificationRequests' => [
              for (final id in pending)
                {'id': id, 'title': 'Loza', 'body': '', 'payload': '$id'},
            ],
            _ => null,
          };
        });
    await NotificationService().init();
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets(
    'Photo confirmation remains saved and visible if alarm cancellation fails',
    (tester) async {
      final db = MemoryTasks()..tasks.add(Task(id: 1, title: 'Lavar la loza'));
      final provider = AppProvider(
        await SharedPreferences.getInstance(),
        database: db,
      );
      await provider.ready;
      failCancel = true;
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: MaterialApp(home: TasksScreen(cameraService: CapturedPhoto())),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.camera_alt_rounded).first);
      // The progress bar intentionally animates until confirmation, so waiting
      // for all animations to settle here would never finish.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.runAsync(() async {
        await tester.tap(find.text('Tomar foto'));
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(Image), findsOneWidget);
      await tester.tap(find.text('Confirmar manualmente'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(db.tasks.single.completed, isTrue);
      expect(db.tasks.single.photoPath, startsWith('data:image/png;base64,'));
      expect(provider.pendingTasks, isEmpty);
      expect(
        provider.completedTasks.single.photoPath,
        db.tasks.single.photoPath,
      );
      expect(cancelled, [1]);
      expect(find.textContaining('Foto y tarea guardadas.'), findsOneWidget);
      expect(find.textContaining('No se pudo abrir la cámara'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      provider.dispose();
      debugDefaultTargetPlatformOverride = null;
    },
  );

  test(
    'Database failure leaves task pending and does not cancel its reminder',
    () async {
      final task = Task(id: 1, title: 'Loza');
      final db = FailedDatabase()..tasks.add(task);
      final provider = AppProvider(
        await SharedPreferences.getInstance(),
        database: db,
      );
      await provider.ready;
      await expectLater(
        provider.updateTask(task.copyWith(completed: true)),
        throwsA(isA<PlatformException>()),
      );
      expect(provider.pendingTasks.length, 1);
      expect(db.tasks.single.completed, isFalse);
      expect(cancelled, isEmpty);
      provider.dispose();
    },
  );

  test('Restart retries cancelling completed tasks without cancelling pending tasks', () async {
    pending = [1, 2];
    final db = MemoryTasks()
      ..tasks.addAll([
        Task(
          id: 1,
          title: 'Hecha',
          completed: true,
          photoPath: 'data:image/png;base64,photo',
        ),
        Task(id: 2, title: 'Pendiente'),
      ]);
    final provider = AppProvider(
      await SharedPreferences.getInstance(),
      database: db,
    );
    await provider.ready;
    expect(cancelled, [1]);
    expect(
      provider.completedTasks.single.photoPath,
      'data:image/png;base64,photo',
    );
    expect(provider.pendingTasks.single.id, 2);
    provider.dispose();
  });
}
