import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dopamind/services/camera_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Photo pipeline examines full image and two crops and cleans resources', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final directory = await Directory.systemTemp.createTemp('dopamind_test_');
    const channel = MethodChannel('google_mlkit_image_labeler');
    final paths = <String>[];
    var closed = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'vision#closeImageLabelDetector') { closed = true; return null; }
      final path = call.arguments['imageData']['path'] as String;
      expect(await File(path).exists(), isTrue);
      paths.add(path);
      return [{'text': 'Dishware', 'index': 1, 'confidence': paths.length == 1 ? .3 : .7}];
    });
    try {
      final recorder = ui.PictureRecorder();
      ui.Canvas(recorder).drawRect(const ui.Rect.fromLTWH(0, 0, 100, 80), ui.Paint()..color = const ui.Color(0xFFFFFFFF));
      final picture = recorder.endRecording();
      final image = await picture.toImage(100, 80);
      picture.dispose();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      final source = File('${directory.path}/source.png');
      await source.writeAsBytes(bytes!.buffer.asUint8List());
      final result = await CameraService().analyzeImage(source.path);
      expect(paths.length, 3);
      expect(result.reliableLabels, ['dishware']);
      expect(closed, isTrue);
      expect(await source.exists(), isTrue);
      for (final path in paths.skip(1)) { expect(await File(path).exists(), isFalse); }
    } finally {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
      await directory.delete(recursive: true);
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
