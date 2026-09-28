import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/task.dart';
import '../models/predefined_tasks.dart';
import '../services/app_provider.dart';
import '../services/camera_service.dart';
import '../services/notification_service.dart';
import 'package:permission_handler/permission_handler.dart';
import '../utils/colors.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  String _selectedPriority = 'medium';
  String _selectedCategory = 'general';
  TimeOfDay? _selectedTime;
  List<String> _selectedKeywords = [];
  final CameraService _cameraService = CameraService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _showPredefinedTasks() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildPredefinedTasksSheet(),
    );
  }

  void _showAddTaskDialog({PredefinedTask? predefined}) {
    if (predefined != null) {
      _titleController.text = predefined.title;
      _descController.text = predefined.description;
      _selectedPriority = predefined.priority;
      _selectedCategory = predefined.category;
      _selectedKeywords = List.from(predefined.verificationKeywords);
    } else {
      _titleController.clear();
      _descController.clear();
      _selectedPriority = 'medium';
      _selectedCategory = 'general';
      _selectedKeywords = [];
    }
    _selectedTime = null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildAddTaskSheet(isPredefined: predefined != null),
    );
  }

  void _addTask() {
    if (_titleController.text.trim().isEmpty) return;

    final task = Task(
      title: _titleController.text.trim(),
      description: _descController.text.trim().isNotEmpty
          ? _descController.text.trim()
          : null,
      priority: _selectedPriority,
      category: _selectedCategory,
      scheduledHour: _selectedTime?.hour,
      scheduledMinute: _selectedTime?.minute,
      verificationKeywords: _selectedKeywords,
    );

    context.read<AppProvider>().addTask(task).then((_) {
      if (_selectedTime != null) {
        NotificationService().scheduleTaskNotification(
          taskId: task.title.hashCode,
          title: task.title,
          description: task.description ?? '',
          hour: _selectedTime!.hour,
          minute: _selectedTime!.minute,
        );
      }
    });
    Navigator.pop(context);
    _titleController.clear();
    _descController.clear();
    _selectedPriority = 'medium';
    _selectedCategory = 'general';
    _selectedTime = null;
    _selectedKeywords = [];
  }

  void _verifyWithPhoto(Task task) async {
    final source = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Verificar con foto',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Toma una foto para verificar que completaste la tarea',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded,
                  color: AppColors.primary),
              title: const Text('Tomar foto'),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded,
                  color: AppColors.secondary),
              title: const Text('Elegir de galería'),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    String? imagePath;
    if (source == 'camera') {
      final status = await Permission.camera.request();
      if (status.isDenied || status.isPermanentlyDenied) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Necesitas dar permiso de cámara en Configuración'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
      imagePath = await _cameraService.takePhoto();
    } else {
      final status = await Permission.photos.request();
      if (status.isDenied || status.isPermanentlyDenied) {
        final storageStatus = await Permission.storage.request();
        if (storageStatus.isDenied && !mounted) return;
      }
      imagePath = await _cameraService.pickFromGallery();
    }

    if (imagePath == null || !mounted) return;

    final detected = await _cameraService.analyzeImage(imagePath);
    final verified = _cameraService.verifyTaskCompletion(
      task.title,
      detected,
      taskKeywords: task.verificationKeywords,
    );

    if (!mounted) return;

    if (verified) {
      final updated = task.copyWith(
        completed: true,
        completedAt: DateTime.now(),
        photoVerified: true,
        photoPath: imagePath,
      );
      context.read<AppProvider>().updateTask(updated);
      context.read<AppProvider>().addPhotoVerification();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Tarea verificada: ${task.title}'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
              '❌ No se pudo verificar. Intenta con otra foto.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Mis Tareas',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        onPressed: _showPredefinedTasks,
                        icon: const Icon(Icons.add_task_rounded),
                        color: AppColors.secondary,
                        tooltip: 'Tareas predefinidas',
                      ),
                      IconButton(
                        onPressed: () => _showAddTaskDialog(),
                        icon: const Icon(Icons.add_circle_rounded),
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                labelColor: Colors.white,
                unselectedLabelColor: AppColors.textSecondary,
                tabs: [
                  Tab(text: 'Pendientes (${provider.pendingTasks.length})'),
                  Tab(text: 'Horario (${_getScheduledCount(provider)})'),
                  Tab(text: 'Hechas (${provider.completedTasks.length})'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildTaskList(provider.pendingTasks, false),
                  _buildScheduleView(provider),
                  _buildTaskList(provider.completedTasks, true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _getScheduledCount(AppProvider provider) {
    return provider.pendingTasks
        .where((t) => t.scheduledHour != null)
        .length;
  }

  Widget _buildScheduleView(AppProvider provider) {
    final scheduledTasks = provider.tasks
        .where((t) => t.scheduledHour != null && !t.completed)
        .toList()
      ..sort((a, b) {
        final aTime = a.scheduledHour! * 60 + a.scheduledMinute!;
        final bTime = b.scheduledHour! * 60 + b.scheduledMinute!;
        return aTime.compareTo(bTime);
      });

    if (scheduledTasks.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.schedule_rounded, size: 64, color: AppColors.textLight),
            SizedBox(height: 16),
            Text(
              'No hay tareas programadas',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 16,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Asigna una hora a tus tareas\npara ver tu horario aquí',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textLight,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: scheduledTasks.length,
      itemBuilder: (context, index) {
        final task = scheduledTasks[index];
        return _buildScheduleCard(task);
      },
    );
  }

  Widget _buildScheduleCard(Task task) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                task.scheduledTime,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: task.priorityColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    decoration: task.completed
                        ? TextDecoration.lineThrough
                        : null,
                    color: task.completed
                        ? AppColors.textLight
                        : AppColors.textPrimary,
                  ),
                ),
                if (task.description != null && task.description!.isNotEmpty)
                  Text(
                    task.description!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          if (!task.completed)
            IconButton(
              onPressed: () => _verifyWithPhoto(task),
              icon: const Icon(Icons.camera_alt_rounded),
              color: AppColors.primary,
              tooltip: 'Verificar con foto',
            ),
        ],
      ),
    );
  }

  Widget _buildTaskList(List<Task> tasks, bool completed) {
    if (tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              completed ? Icons.check_circle_outline : Icons.task_alt_rounded,
              size: 64,
              color: AppColors.textLight,
            ),
            const SizedBox(height: 16),
            Text(
              completed ? 'No hay tareas completadas' : 'No hay tareas pendientes',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        return _buildTaskItem(task, completed);
      },
    );
  }

  Widget _buildTaskItem(Task task, bool completed) {
    return Dismissible(
      key: Key('task_${task.id}'),
      direction: completed ? DismissDirection.none : DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_rounded, color: Colors.white),
      ),
      onDismissed: (direction) {
        NotificationService().cancelNotification(task.title.hashCode);
        context.read<AppProvider>().deleteTask(task.id!);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            if (!completed)
              GestureDetector(
                onTap: () {
                  NotificationService().cancelNotification(task.title.hashCode);
                  context.read<AppProvider>().completeTask(task);
                },
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: task.priorityColor,
                      width: 2,
                    ),
                  ),
                ),
              )
            else
              const Icon(
                Icons.check_circle_rounded,
                color: AppColors.success,
                size: 24,
              ),
            const SizedBox(width: 12),
            Container(
              width: 4,
              height: 36,
              decoration: BoxDecoration(
                color: task.priorityColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Icon(task.categoryIcon, color: AppColors.textSecondary, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      decoration:
                          completed ? TextDecoration.lineThrough : null,
                      color: completed
                          ? AppColors.textLight
                          : AppColors.textPrimary,
                    ),
                  ),
                  Row(
                    children: [
                      if (task.scheduledTime.isNotEmpty) ...[
                        Icon(Icons.schedule_rounded,
                            size: 14, color: AppColors.textLight),
                        const SizedBox(width: 4),
                        Text(
                          task.scheduledTime,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textLight,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (task.photoVerified) ...[
                        const Icon(Icons.camera_alt_rounded,
                            size: 14, color: AppColors.secondary),
                        const SizedBox(width: 4),
                        const Text(
                          'Verificada',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.secondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (!completed)
              IconButton(
                onPressed: () => _verifyWithPhoto(task),
                icon: const Icon(Icons.camera_alt_rounded),
                color: AppColors.primary,
                tooltip: 'Verificar con foto',
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPredefinedTasksSheet() {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Tareas Predefinidas',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Selecciona una tarea para agregar a tu lista',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: PredefinedTasks.all.length,
              itemBuilder: (context, index) {
                final task = PredefinedTasks.all[index];
                return _buildPredefinedTaskCard(task);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPredefinedTaskCard(PredefinedTask task) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        _showAddTaskDialog(predefined: task);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Text(task.icon, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    task.description,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getPriorityColor(task.priority).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _getPriorityLabel(task.priority),
                style: TextStyle(
                  fontSize: 11,
                  color: _getPriorityColor(task.priority),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'high':
        return AppColors.priorityHigh;
      case 'medium':
        return AppColors.priorityMedium;
      case 'low':
        return AppColors.priorityLow;
      default:
        return AppColors.priorityMedium;
    }
  }

  String _getPriorityLabel(String priority) {
    switch (priority) {
      case 'high':
        return 'Alta';
      case 'medium':
        return 'Media';
      case 'low':
        return 'Baja';
      default:
        return 'Media';
    }
  }

  Widget _buildAddTaskSheet({bool isPredefined = false}) {
    return StatefulBuilder(
      builder: (context, setModalState) {
        return Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.divider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  isPredefined ? 'Agregar Tarea' : 'Nueva Tarea',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    hintText: '¿Qué necesitas hacer?',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.divider),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primary),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _descController,
                  decoration: InputDecoration(
                    hintText: 'Descripción (opcional)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.divider),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primary),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Selector de hora
                GestureDetector(
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: _selectedTime ?? TimeOfDay.now(),
                    );
                    if (picked != null) {
                      setModalState(() => _selectedTime = picked);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.divider),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.schedule_rounded,
                            color: AppColors.primary),
                        const SizedBox(width: 12),
                        Text(
                          _selectedTime != null
                              ? '⏰ ${_selectedTime!.format(context)}'
                              : 'Asignar hora (opcional)',
                          style: TextStyle(
                            color: _selectedTime != null
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                            fontWeight: _selectedTime != null
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                        const Spacer(),
                        if (_selectedTime != null)
                          GestureDetector(
                            onTap: () =>
                                setModalState(() => _selectedTime = null),
                            child: const Icon(Icons.close,
                                size: 20, color: AppColors.textLight),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                const Text(
                  'Prioridad',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildPriorityChip(
                        'Alta', 'high', AppColors.priorityHigh, setModalState),
                    const SizedBox(width: 8),
                    _buildPriorityChip('Media', 'medium',
                        AppColors.priorityMedium, setModalState),
                    const SizedBox(width: 8),
                    _buildPriorityChip(
                        'Baja', 'low', AppColors.priorityLow, setModalState),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Categoría',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildCategoryChip('General', 'general', Icons.task_alt,
                        setModalState),
                    _buildCategoryChip('Hogar', 'hogar', Icons.home_outlined,
                        setModalState),
                    _buildCategoryChip(
                        'Trabajo', 'trabajo', Icons.work_outline, setModalState),
                    _buildCategoryChip(
                        'Salud', 'salud', Icons.favorite_outline, setModalState),
                    _buildCategoryChip('Personal', 'personal',
                        Icons.person_outline, setModalState),
                    _buildCategoryChip('Estudio', 'estudio',
                        Icons.school_outlined, setModalState),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _addTask,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      isPredefined ? 'Agregar' : 'Crear Tarea',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPriorityChip(
      String label, String value, Color color, StateSetter setModalState) {
    final isSelected = _selectedPriority == value;
    return GestureDetector(
      onTap: () => setModalState(() => _selectedPriority = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.15) : AppColors.divider,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? color : AppColors.textSecondary,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryChip(
      String label, String value, IconData icon, StateSetter setModalState) {
    final isSelected = _selectedCategory == value;
    return GestureDetector(
      onTap: () => setModalState(() => _selectedCategory = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withOpacity(0.15)
              : AppColors.divider,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
