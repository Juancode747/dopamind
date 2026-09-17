class PredefinedTask {
  final String title;
  final String description;
  final String priority;
  final String category;
  final String icon;
  final List<String> verificationKeywords;

  const PredefinedTask({
    required this.title,
    required this.description,
    this.priority = 'medium',
    this.category = 'general',
    this.icon = '📋',
    this.verificationKeywords = const [],
  });
}

class PredefinedTasks {
  static const List<PredefinedTask> all = [
    // Hogar
    PredefinedTask(
      title: 'Lavar la loza',
      description: 'Lavar todos los platos, vasos y cubiertos',
      priority: 'high',
      category: 'hogar',
      icon: '🍽️',
      verificationKeywords: [
        'plate', 'dish', 'dishes', 'cup', 'spoon', 'fork', 'bowl',
        'plato', 'vaso', 'cuchara', 'tenedor', 'taza', 'sarten', 'olla',
        'kitchen', 'sink', 'fregadero', 'lavabo'
      ],
    ),
    PredefinedTask(
      title: 'Hacer la cama',
      description: 'Ordenar las sábanas, almohadas y cobija',
      priority: 'medium',
      category: 'hogar',
      icon: '🛏️',
      verificationKeywords: [
        'bed', 'pillow', 'blanket', 'sheet', 'mattress',
        'cama', 'almohada', 'sabana', 'cobija', 'colcha',
        'bedroom', 'dormitorio'
      ],
    ),
    PredefinedTask(
      title: 'Sacar la basura',
      description: 'Recolectar y sacar la basura del hogar',
      priority: 'high',
      category: 'hogar',
      icon: '🗑️',
      verificationKeywords: [
        'trash', 'garbage', 'bin', 'bag', 'waste',
        'basura', 'bolsa', 'contenedor', 'reciclaje'
      ],
    ),
    PredefinedTask(
      title: 'Limpiar el piso',
      description: 'Barrer y trapear todas las habitaciones',
      priority: 'medium',
      category: 'hogar',
      icon: '🧹',
      verificationKeywords: [
        'broom', 'mop', 'floor', 'clean', 'bucket',
        'escoba', 'trapeador', 'piso', 'balde', 'fregona'
      ],
    ),
    PredefinedTask(
      title: 'Lavar la ropa',
      description: 'Lavar, secar y doblar la ropa',
      priority: 'high',
      category: 'hogar',
      icon: '👕',
      verificationKeywords: [
        'clothes', 'shirt', 'pants', 'washing', 'laundry', 'detergent',
        'ropa', 'camisa', 'pantalon', 'lavadora', 'detergente', 'jabon',
        'clothesline', 'tendedero', 'secadora'
      ],
    ),
    PredefinedTask(
      title: 'Cocinar',
      description: 'Preparar una comida saludable',
      priority: 'high',
      category: 'hogar',
      icon: '🍳',
      verificationKeywords: [
        'food', 'cooking', 'stove', 'pan', 'pot', 'kitchen',
        'comida', 'cocinar', 'estufa', 'sarten', 'olla', 'cocina',
        'vegetable', 'fruit', 'verdura', 'fruta', 'ingredient'
      ],
    ),
    PredefinedTask(
      title: 'Organizar el armario',
      description: 'Ordenar y clasificar la ropa del armario',
      priority: 'low',
      category: 'hogar',
      icon: '👔',
      verificationKeywords: [
        'closet', 'clothes', 'hanger', 'wardrobe', 'fold',
        'armario', 'ropa', 'percha', 'clóset', 'doblar'
      ],
    ),
    PredefinedTask(
      title: 'Limpiar el baño',
      description: 'Limpiar inodoro, lavabo y ducha',
      priority: 'high',
      category: 'hogar',
      icon: '🚿',
      verificationKeywords: [
        'bathroom', 'toilet', 'sink', 'shower', 'clean', 'soap',
        'baño', 'inodoro', 'lavabo', 'ducha', 'limpiar', 'jabon'
      ],
    ),

    // Salud
    PredefinedTask(
      title: 'Hacer ejercicio',
      description: 'Realizar 30 minutos de actividad física',
      priority: 'high',
      category: 'salud',
      icon: '💪',
      verificationKeywords: [
        'exercise', 'workout', 'gym', 'dumbbell', 'running', 'yoga',
        'ejercicio', 'pesa', 'mancuerna', 'gimnasio', 'correr', 'yoga',
        'mat', 'colchoneta', 'resistance'
      ],
    ),
    PredefinedTask(
      title: 'Beber agua',
      description: 'Tomar al menos 8 vasos de agua al día',
      priority: 'medium',
      category: 'salud',
      icon: '💧',
      verificationKeywords: [
        'water', 'glass', 'bottle', 'drink', 'hydration',
        'agua', 'vaso', 'botella', 'beber', 'hidratacion'
      ],
    ),
    PredefinedTask(
      title: 'Meditar',
      description: 'Dedicar 10 minutos a la meditación',
      priority: 'medium',
      category: 'salud',
      icon: '🧘',
      verificationKeywords: [
        'meditation', 'peaceful', 'calm', 'breathing', 'mindful',
        'meditacion', 'paz', 'calma', 'respiracion', 'mindfulness'
      ],
    ),
    PredefinedTask(
      title: 'Dormir 8 horas',
      description: 'Acostarse temprano para descansar bien',
      priority: 'high',
      category: 'salud',
      icon: '😴',
      verificationKeywords: [
        'bed', 'sleep', 'pillow', 'blanket', 'night', 'rest',
        'cama', 'dormir', 'almohada', 'cobija', 'noche', 'descanso'
      ],
    ),

    // Personal
    PredefinedTask(
      title: 'Leer 30 minutos',
      description: 'Leer un libro o artículo interesante',
      priority: 'medium',
      category: 'personal',
      icon: '📖',
      verificationKeywords: [
        'book', 'reading', 'page', 'novel', 'library',
        'libro', 'leer', 'pagina', 'novela', 'biblioteca'
      ],
    ),
    PredefinedTask(
      title: 'Escribir en el diario',
      description: 'Registrar pensamientos y emociones del día',
      priority: 'low',
      category: 'personal',
      icon: '📝',
      verificationKeywords: [
        'diary', 'journal', 'writing', 'pen', 'notebook',
        'diario', 'escribir', 'lapiz', 'cuaderno', 'nota'
      ],
    ),
    PredefinedTask(
      title: 'Llamar a un familiar',
      description: 'Hablar con alguien cercano',
      priority: 'medium',
      category: 'personal',
      icon: '📞',
      verificationKeywords: [
        'phone', 'call', 'talking', 'family',
        'telefono', 'llamar', 'hablar', 'familia'
      ],
    ),
    PredefinedTask(
      title: 'Salir a caminar',
      description: 'Caminar al menos 20 minutos al aire libre',
      priority: 'medium',
      category: 'personal',
      icon: '🚶',
      verificationKeywords: [
        'walking', 'outdoor', 'street', 'park', 'nature',
        'caminar', 'calle', 'parque', 'natura', 'paseo'
      ],
    ),

    // Trabajo/Estudio
    PredefinedTask(
      title: 'Estudiar 1 hora',
      description: 'Dedicar tiempo al estudio o capacitación',
      priority: 'high',
      category: 'estudio',
      icon: '📚',
      verificationKeywords: [
        'study', 'book', 'notebook', 'computer', 'desk',
        'estudiar', 'libro', 'cuaderno', 'computador', 'escritorio'
      ],
    ),
    PredefinedTask(
      title: 'Organizar el escritorio',
      description: 'Mantener el espacio de trabajo limpio',
      priority: 'low',
      category: 'trabajo',
      icon: '🖥️',
      verificationKeywords: [
        'desk', 'office', 'computer', 'organize', 'clean',
        'escritorio', 'oficina', 'computador', 'organizar', 'limpiar'
      ],
    ),
    PredefinedTask(
      title: 'Revisar correo',
      description: 'Responder mensajes importantes pendientes',
      priority: 'medium',
      category: 'trabajo',
      icon: '📧',
      verificationKeywords: [
        'email', 'computer', 'inbox', 'message',
        'correo', 'computador', 'bandeja', 'mensaje'
      ],
    ),

    // Reducción de dopamina
    PredefinedTask(
      title: 'Sin celular 1 hora',
      description: 'No usar el celular por una hora',
      priority: 'high',
      category: 'personal',
      icon: '📵',
      verificationKeywords: [
        'offline', 'phone', 'no screen',
        'offline', 'celular', 'pantalla'
      ],
    ),
    PredefinedTask(
      title: 'Caminar sin audífonos',
      description: 'Caminar escuchando el ambiente, sin distracciones',
      priority: 'medium',
      category: 'salud',
      icon: '🌿',
      verificationKeywords: [
        'walking', 'outdoor', 'nature', 'park', 'street',
        'caminar', 'natura', 'parque', 'calle', 'aire'
      ],
    ),
    PredefinedTask(
      title: 'Comer sin pantalla',
      description: 'Comer sin ver el celular ni la tele',
      priority: 'high',
      category: 'salud',
      icon: '🍽️',
      verificationKeywords: [
        'food', 'eating', 'table', 'plate', 'meal',
        'comida', 'comer', 'mesa', 'plato', 'almuerzo'
      ],
    ),
    PredefinedTask(
      title: '10 min sin estímulos',
      description: 'Estar sentado sin hacer nada, solo respirar',
      priority: 'high',
      category: 'salud',
      icon: '🪷',
      verificationKeywords: [
        'calm', 'peaceful', 'quiet', 'still',
        'calma', 'paz', 'silencio', 'quiet'
      ],
    ),
  ];

  static List<PredefinedTask> getByCategory(String category) {
    return all.where((t) => t.category == category).toList();
  }

  static List<String> get categories => [
        'hogar',
        'salud',
        'personal',
        'trabajo',
        'estudio',
      ];
}
