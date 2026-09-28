import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';

class CameraService {
  final ImagePicker _picker = ImagePicker();

  Future<String?> takePhoto() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      return photo?.path;
    } catch (e) {
      debugPrint('Error taking photo: $e');
      return null;
    }
  }

  Future<String?> pickFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      return image?.path;
    } catch (e) {
      debugPrint('Error picking from gallery: $e');
      return null;
    }
  }

  Future<List<String>> analyzeImage(String imagePath) async {
    if (kIsWeb) {
      return [];
    }
    return _analyzeWithMlKit(imagePath);
  }

  Future<List<String>> _analyzeWithMlKit(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);

      final options = ImageLabelerOptions(
        confidenceThreshold: 0.5,
      );

      final imageLabeler = ImageLabeler(options: options);
      final labels = await imageLabeler.processImage(inputImage);
      final detected = <String>[];

      for (final label in labels) {
        detected.add(label.label.toLowerCase());
      }

      await imageLabeler.close();
      return detected;
    } catch (e) {
      debugPrint('ML Kit error: $e');
      return [];
    }
  }

  bool verifyTaskCompletion(
    String taskTitle,
    List<String> detectedObjects, {
    List<String> taskKeywords = const [],
  }) {
    final titleLower = taskTitle.toLowerCase();

    // 1. Usar palabras clave personalizadas de la tarea (creadas por el usuario)
    if (taskKeywords.isNotEmpty) {
      for (final obj in detectedObjects) {
        if (taskKeywords
            .any((keyword) => obj.toLowerCase().contains(keyword.toLowerCase()))) {
          return true;
        }
      }
    }

    // 2. Verificación inteligente por contexto de la tarea
    final Map<String, List<String>> contextMap = {
      'lavar': [
        'plate', 'dish', 'dishes', 'cup', 'spoon', 'fork', 'bowl',
        'plato', 'vaso', 'cuchara', 'tenedor', 'taza', 'olla', 'sarten',
        'kitchen', 'sink', 'fregadero', 'lavabo'
      ],
      'loza': [
        'plate', 'dish', 'cup', 'spoon', 'fork', 'bowl',
        'plato', 'vaso', 'cuchara', 'tenedor', 'taza'
      ],
      'platos': [
        'plate', 'dish', 'dishes', 'cup', 'spoon', 'fork',
        'plato', 'vaso', 'cuchara', 'tenedor'
      ],
      'ropa': [
        'clothing', 'shirt', 'pants', 'shoe', 'dress', 'fabric',
        'camisa', 'pantalon', 'calza', 'zapato', 'vestido'
      ],
      'dormir': [
        'bed', 'pillow', 'blanket', 'mattress',
        'cama', 'almohada', 'sabana', 'cobija'
      ],
      'baño': [
        'soap', 'towel', 'brush', 'shampoo', 'bathroom',
        'jabon', 'toalla', 'cepillo'
      ],
      'cocina': [
        'refrigerator', 'microwave', 'oven', 'stove', 'kitchen',
        'refrigerador', 'microondas', 'horno', 'estufa'
      ],
      'comer': [
        'food', 'fruit', 'vegetable', 'plate', 'fork', 'meal',
        'fruta', 'verdura', 'plato', 'tenedor', 'comida'
      ],
      'ejercicio': [
        'dumbbell', 'weight', 'yoga', 'mat', 'exercise', 'gym',
        'pesa', 'mancuerna', 'colchoneta'
      ],
      'leer': [
        'book', 'notebook', 'pen', 'pencil', 'reading',
        'libro', 'cuaderno', 'lapiz'
      ],
    };

    for (final entry in contextMap.entries) {
      if (titleLower.contains(entry.key)) {
        for (final obj in detectedObjects) {
          if (entry.value
              .any((keyword) => obj.toLowerCase().contains(keyword))) {
            return true;
          }
        }
      }
    }

    return detectedObjects.isNotEmpty;
  }
}
