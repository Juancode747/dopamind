import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';

import '../models/predefined_tasks.dart';
import '../models/photo_analysis.dart';
import 'photo_regions.dart';

class CameraService {
  final ImagePicker _picker = ImagePicker();
  bool get supportsAnalysis =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
  bool get supportsCamera => kIsWeb || supportsAnalysis;
  Future<XFile?> takePhoto() => _pick(ImageSource.camera);
  Future<XFile?> pickFromGallery() => _pick(ImageSource.gallery);
  Future<XFile?> _pick(ImageSource source) => _picker.pickImage(
    source: source,
    maxWidth: 1600,
    maxHeight: 1600,
    imageQuality: 92,
    requestFullMetadata: false,
  );

  Future<PhotoAnalysis> analyzeImage(String path) async {
    if (!supportsAnalysis)
      throw UnsupportedError('Análisis solo disponible en Android e iOS.');
    final labeler = ImageLabeler(
      options: ImageLabelerOptions(confidenceThreshold: 0.25),
    );
    final regions = await PhotoRegions.prepare(path);
    final labels = <PhotoLabel>[];
    try {
      for (final region in regions.paths) {
        try {
          final detected = await labeler.processImage(
            InputImage.fromFilePath(region),
          );
          labels.addAll(
            detected.map((label) => PhotoLabel(label.label, label.confidence)),
          );
        } catch (_) {
          if (region == path) rethrow;
        }
      }
      return PhotoAnalysis.merge(labels);
    } finally {
      try {
        await labeler.close();
      } finally {
        await regions.dispose();
      }
    }
  }

  static String normalize(String text) {
    var value = text.toLowerCase().trim();
    const accented = 'áéíóúüñ';
    const plain = 'aeiouun';
    for (var i = 0; i < accented.length; i++) {
      value = value.replaceAll(accented[i], plain[i]);
    }
    return value
        .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  // Object synonyms and Spanish equivalents; no arbitrary non-empty result
  // can complete a task, and low-confidence labels are only suggestions.
  static const vocabulary = <String, List<String>>{
    'Vajilla': [
      'loza',
      'vajilla',
      'plato',
      'platos',
      'plate',
      'dish',
      'dishes',
      'dishware',
      'tableware',
      'saucer',
      'bowl',
      'cuenco',
    ],
    'Cubiertos': [
      'cubierto',
      'cubiertos',
      'cutlery',
      'silverware',
      'fork',
      'spoon',
      'tenedor',
      'cuchara',
      'utensil',
      'kitchen utensil',
    ],
    'Taza': ['taza', 'tazas', 'cup', 'mug', 'coffee cup'],
    'Vaso': ['vaso', 'vasos', 'glass', 'drinkware', 'glass bottle'],
    'Olla o sartén': ['olla', 'sarten', 'pot', 'pan', 'cookware', 'frying pan'],
    'Lavaplatos': [
      'lavaplatos',
      'fregadero',
      'sink',
      'kitchen sink',
      'dishwasher',
    ],
    'Ropa': [
      'ropa',
      'clothes',
      'clothing',
      'shirt',
      't shirt',
      'camisa',
      'camiseta',
      'pants',
      'pantalon',
      'textile',
      'fabric',
    ],
    'Lavandería': [
      'lavadora',
      'washing machine',
      'laundry',
      'washing',
      'detergent',
      'detergente',
    ],
    'Cama': [
      'cama',
      'bed',
      'bedding',
      'bedroom',
      'pillow',
      'almohada',
      'blanket',
      'cobija',
      'sheet',
      'sabana',
      'mattress',
    ],
    'Basura': [
      'basura',
      'trash',
      'garbage',
      'waste',
      'waste container',
      'dustbin',
      'trash can',
      'bin',
    ],
    'Piso': ['piso', 'floor', 'flooring'],
    'Escoba o trapeador': ['escoba', 'broom', 'mop', 'trapeador', 'fregona'],
    'Baño': ['bano', 'bathroom', 'toilet', 'inodoro', 'shower', 'ducha'],
    'Libro': [
      'libro',
      'libros',
      'book',
      'books',
      'reading',
      'leer',
      'novel',
      'novela',
    ],
    'Cuaderno': [
      'cuaderno',
      'notebook',
      'journal',
      'diary',
      'diario',
      'writing',
      'handwriting',
    ],
    'Lápiz': ['lapiz', 'pen', 'pencil', 'boligrafo'],
    'Computador': [
      'computador',
      'computer',
      'laptop',
      'computadora',
      'ordenador',
    ],
    'Escritorio': ['escritorio', 'desk', 'office', 'oficina'],
    'Teléfono': ['telefono', 'phone', 'mobile phone', 'smartphone', 'celular'],
    'Botella': ['botella', 'bottle', 'water bottle'],
    'Agua': ['agua', 'water', 'drink', 'beverage'],
    'Comida': ['comida', 'food', 'meal', 'eating', 'comer'],
    'Fruta': ['fruta', 'fruit'],
    'Verdura': ['verdura', 'vegetable'],
    'Ejercicio': [
      'ejercicio',
      'exercise',
      'fitness',
      'physical fitness',
      'gym',
      'gimnasio',
      'weight training',
      'dumbbell',
      'mancuerna',
      'pesa',
      'yoga',
    ],
    'Exterior': [
      'outdoor',
      'outdoors',
      'park',
      'parque',
      'street',
      'calle',
      'nature',
      'naturaleza',
      'walking',
      'caminar',
    ],
    'Armario': ['armario', 'closet', 'wardrobe', 'hanger', 'percha'],
  };

  static bool _contains(String label, String word) =>
      word.isNotEmpty &&
      RegExp(r'(^|\s)' + RegExp.escape(word) + r'($|\s)').hasMatch(label);

  static String displayLabel(String label) {
    final normalized = normalize(label);
    for (final entry in vocabulary.entries) {
      if (entry.value.contains(normalized)) return entry.key;
    }
    return label;
  }

  bool verifyTaskCompletion(
    String taskTitle,
    List<String> detectedObjects, {
    List<String> taskKeywords = const [],
  }) {
    var keywords = taskKeywords;
    if (keywords.isEmpty) {
      final presets = PredefinedTasks.all.where(
        (task) => normalize(task.title) == normalize(taskTitle),
      );
      keywords = presets.isNotEmpty
          ? presets.first.verificationKeywords
          : [taskTitle];
    }
    final expected = keywords
        .map(normalize)
        .where((word) => word.isNotEmpty)
        .toSet();
    // Expand only groups explicitly represented in the task, never all objects.
    final expanded = <String>{...expected};
    for (final aliases in vocabulary.values) {
      if (expected.any(
        (word) => aliases.any((alias) => _contains(word, alias)),
      ))
        expanded.addAll(aliases);
    }
    return detectedObjects.any((object) {
      final label = normalize(object);
      return expanded.any((word) => _contains(label, word));
    });
  }
}
