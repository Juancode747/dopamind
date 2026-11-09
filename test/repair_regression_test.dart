import 'package:flutter_test/flutter_test.dart';
import 'package:dopamind/models/breathing_cycle.dart';
import 'package:dopamind/services/camera_service.dart';
import 'package:dopamind/services/timer_service.dart';

void main() {
  test('Respiración cambia a exhalar exactamente a los cuatro segundos', () {
    expect(BreathingCycle(0).prompt, 'Inhala · 4 s');
    expect(BreathingCycle(3).prompt, 'Inhala · 1 s');
    expect(BreathingCycle(4).prompt, 'Exhala · 6 s');
    expect(BreathingCycle(9).prompt, 'Exhala · 1 s');
    expect(BreathingCycle(10).prompt, 'Inhala · 4 s');
    expect(BreathingCycle(24).prompt, 'Exhala · 6 s');
    expect(BreathingCycle(0).scale, closeTo(0.8, 0.001));
    expect(BreathingCycle(4).scale, closeTo(1.2, 0.001));
  });

  testWidgets('Pausar congela la fase; reanudar notifica inmediatamente', (
    tester,
  ) async {
    final timer = TimerService();
    timer.startTimer(1);
    await tester.pump(const Duration(seconds: 3));
    timer.pauseTimer();
    await tester.pump(const Duration(seconds: 8));
    expect(timer.elapsedSeconds, 3);
    var notifications = 0;
    timer.addListener(() => notifications++);
    timer.resumeTimer();
    expect(notifications, 1);
    await tester.pump(const Duration(seconds: 1));
    expect(BreathingCycle(timer.elapsedSeconds).inhaling, isFalse);
    await tester.pump(const Duration(seconds: 56));
    expect(timer.remainingSeconds, 0);
    expect(timer.isRunning, isFalse);
    timer.dispose();
  });

  test('Loza reconoce vajilla, rechaza objetos ajenos y resultados vacíos', () {
    final camera = CameraService();
    expect(camera.verifyTaskCompletion('Lavar la loza', ['tableware']), isTrue);
    expect(camera.verifyTaskCompletion('Lavar la loza', ['cat']), isFalse);
    expect(camera.verifyTaskCompletion('Lavar la loza', []), isFalse);
    expect(camera.verifyTaskCompletion('Tarea sin contexto', ['cat']), isFalse);
    expect(camera.verifyTaskCompletion('Lavar la ropa', ['plate']), isFalse);
  });

  test(
    'Palabras explícitas no aceptan coincidencias parciales ni contexto ajeno',
    () {
      final camera = CameraService();
      expect(
        camera.verifyTaskCompletion(
          'Lavar la loza',
          ['cupboard'],
          taskKeywords: ['cup'],
        ),
        isFalse,
      );
      expect(
        camera.verifyTaskCompletion(
          'Lavar la loza',
          ['coffee cup'],
          taskKeywords: ['cup'],
        ),
        isTrue,
      );
      expect(
        camera.verifyTaskCompletion(
          'Lavar la loza',
          ['plate'],
          taskKeywords: ['book'],
        ),
        isFalse,
      );
    },
  );
}
