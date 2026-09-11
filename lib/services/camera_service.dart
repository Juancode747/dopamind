import 'dart:io';
import 'package:image_picker/image_picker.dart';

class CameraService {
  final ImagePicker _picker = ImagePicker();

  Future<String?> takePhoto() async {
    final XFile? photo = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (photo != null) {
      return photo.path;
    }
    return null;
  }

  Future<String?> pickFromGallery() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (image != null) {
      return image.path;
    }
    return null;
  }

  Future<List<String>> analyzeImage(String imagePath) async {
    // ML Kit image labeling - simplified version
    // In production, use google_mlkit_image_labeling
    final file = File(imagePath);
    if (!await file.exists()) return [];

    // Basic object detection keywords
    return _detectObjectsFromPath(imagePath);
  }

  List<String> _detectObjectsFromPath(String path) {
    // Simplified detection based on file analysis
    // Real implementation would use ML Kit
    final lowerPath = path.toLowerCase();
    final detected = <String>[];

    if (lowerPath.contains('kitchen') || lowerPath.contains('cocina')) {
      detected.addAll(['plato', 'vaso', 'cuchara', 'tenedor']);
    }
    if (lowerPath.contains('bath') || lowerPath.contains('baño')) {
      detected.addAll(['jabón', 'toalla', 'cepillo']);
    }
    if (lowerPath.contains('bed') || lowerPath.contains('dormitorio')) {
      detected.addAll(['cama', 'almohada', 'sábana']);
    }

    return detected;
  }

  bool verifyTaskCompletion(String taskTitle, List<String> detectedObjects) {
    final titleLower = taskTitle.toLowerCase();

    final taskKeywords = {
      'lavar': ['plato', 'vaso', 'cuchara', 'tenedor', 'taza', 'ollas', 'sartén'],
      'loza': ['plato', 'vaso', 'cuchara', 'tenedor', 'taza'],
      'platos': ['plato', 'vaso', 'cuchara', 'tenedor'],
      'ropa': ['camisa', 'pantalón', 'calza', 'zapato', 'vestido'],
      'dormir': ['cama', 'almohada', 'sábana', 'cobija'],
      'baño': ['jabón', 'toalla', 'cepillo', 'shampoo'],
      'cocina': ['refrigerador', 'microondas', 'horno', 'estufa'],
      'comer': ['fruta', 'verdura', 'plato', 'tenedor'],
      'ejercicio': ['pesas', 'mancuerna', 'colchoneta'],
      'leer': ['libro', 'cuaderno', 'lápiz'],
    };

    for (final entry in taskKeywords.entries) {
      if (titleLower.contains(entry.key)) {
        for (final obj in detectedObjects) {
          if (entry.value.any((keyword) => obj.toLowerCase().contains(keyword))) {
            return true;
          }
        }
      }
    }

    return detectedObjects.isNotEmpty;
  }
}
