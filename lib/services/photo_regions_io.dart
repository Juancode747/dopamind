import 'dart:io';
import 'dart:ui' as ui;

/// Reframe the central object at two scales so a small object is not lost when
/// the on-device labeler resizes the whole photo to its model input size.
class PhotoRegions {
  PhotoRegions(this.paths, this._directory);
  final List<String> paths;
  final Directory _directory;
  static Future<PhotoRegions> prepare(String path) async {
    final directory = await Directory.systemTemp.createTemp('dopamind_photo_');
    final paths = <String>[path];
    ui.Image? image;
    try {
      final codec = await ui.instantiateImageCodec(
        await File(path).readAsBytes(),
      );
      try {
        image = (await codec.getNextFrame()).image;
      } finally {
        codec.dispose();
      }
      for (final fraction in [0.7, 0.45]) {
        final width = (image.width * fraction).round();
        final height = (image.height * fraction).round();
        final recorder = ui.PictureRecorder();
        final canvas = ui.Canvas(recorder);
        canvas.drawImageRect(
          image,
          ui.Rect.fromLTWH(
            (image.width - width) / 2,
            (image.height - height) / 2,
            width.toDouble(),
            height.toDouble(),
          ),
          ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
          ui.Paint(),
        );
        final picture = recorder.endRecording();
        final crop = await picture.toImage(width, height);
        picture.dispose();
        try {
          final bytes = await crop.toByteData(format: ui.ImageByteFormat.png);
          if (bytes != null) {
            final file = File('${directory.path}/crop_${paths.length}.png');
            await file.writeAsBytes(
              bytes.buffer.asUint8List(
                bytes.offsetInBytes,
                bytes.lengthInBytes,
              ),
            );
            paths.add(file.path);
          }
        } finally {
          crop.dispose();
        }
      }
    } catch (_) {
      // The original remains usable when a crop cannot be generated.
    } finally {
      image?.dispose();
    }
    return PhotoRegions(paths, directory);
  }

  Future<void> dispose() async {
    if (await _directory.exists()) await _directory.delete(recursive: true);
  }
}
