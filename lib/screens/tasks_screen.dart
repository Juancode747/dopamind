import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/task.dart';
import '../models/predefined_tasks.dart';
import '../services/app_provider.dart';
import '../services/camera_service.dart';
import '../services/notification_service.dart';
import '../utils/colors.dart';

import 'package:permission_handler/permission_handler.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key, this.cameraService});

  final CameraService? cameraService;

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
  DateTime? _selectedDate;
  bool _alarmEnabled = false;
  bool _savingTask = false;
  List<String> _selectedKeywords = [];
  late final CameraService _cameraService;
  bool _photoBusy = false;

  @override
  void initState() {
    super.initState();
    _cameraService = widget.cameraService ?? CameraService();
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
    _selectedDate = null;
    _alarmEnabled = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          _buildAddTaskSheet(isPredefined: predefined != null),
    );
  }

  Future<DateTime?> _pickDateTime({DateTime? initial}) async {
    final now = DateTime.now();
    final start = initial != null && initial.isAfter(now)
        ? initial
        : now.add(const Duration(minutes: 10));
    final date = await showDatePicker(
      context: context,
      initialDate: start,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 10, 12, 31),
      helpText: 'Fecha de la tarea',
      cancelText: 'Cancelar',
      confirmText: 'Elegir',
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(start),
      helpText: 'Hora del recordatorio',
      cancelText: 'Cancelar',
      confirmText: 'Elegir',
    );
    if (time == null || !mounted) return null;
    final selected = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    if (!selected.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Elige una fecha y hora futuras.')),
      );
      return null;
    }
    return selected;
  }

  Future<void> _scheduleReminder(Task task) async {
    String message;
    var settings = false;
    Object? failure;
    try {
      final result = await NotificationService().scheduleTask(task);
      message = switch (result) {
        ReminderResult.exact =>
          '${task.alarmEnabled ? 'Alarma' : 'Recordatorio'} programado: ${task.scheduledLabel}',
        ReminderResult.approximate => 'Aviso programado. Android puede retrasarlo porque no autorizaste alarmas exactas.',
        ReminderResult.permissionDenied => 'Tarea guardada, pero las notificaciones están bloqueadas. Actívalas en Ajustes y vuelve a programar el aviso.',
        ReminderResult.unsupported => 'Tarea guardada. Los recordatorios están disponibles en Android e iOS.',
      };
      settings = result == ReminderResult.permissionDenied;
    } catch (error) {
      debugPrint('Error al programar recordatorio: $error');
      failure = error;
      message = 'Tarea guardada, pero no se pudo programar el aviso. Usa el calendario de la tarea para intentarlo de nuevo.';
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 8),
        action: settings
            ? SnackBarAction(label: 'Ajustes', onPressed: openAppSettings)
            : failure != null
            ? SnackBarAction(
                label: 'Detalles',
                onPressed: () => _showErrorDetails('Programar aviso', failure!),
              )
            : null,
      ),
    );
  }

  void _showErrorDetails(String operation, Object error) {
    if (!mounted) return;
    final details = '$operation\n$error';
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Detalles del error'),
        content: SingleChildScrollView(child: SelectableText(details)),
        actions: [
          TextButton(
            onPressed: () => Clipboard.setData(ClipboardData(text: details)),
            child: const Text('Copiar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  static const _cancellationWarning =
      'La tarea está guardada, pero no se pudo cancelar su aviso. '
      'Podría sonar todavía; se volverá a intentar al abrir la app.';

  Future<void> _completeTask(Task task) async {
    try {
      final cancelled = await context.read<AppProvider>().completeTask(task);
      if (!mounted || cancelled) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text(_cancellationWarning)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No se pudo guardar la tarea.'),
          action: SnackBarAction(
            label: 'Detalles',
            onPressed: () => _showErrorDetails('Guardar tarea', error),
          ),
        ),
      );
    }
  }

  Future<void> _changeReminder(Task task) async {
    final date = await _pickDateTime(initial: task.dueDate);
    if (date == null || !mounted) return;
    var alarm = task.alarmEnabled;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('Recordatorio de la tarea'),
          content: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Sonar como alarma'),
            subtitle: const Text(
              'En Android: sonido repetido hasta un minuto. Puedes detenerlo desde la notificación.',
            ),
            value: alarm,
            onChanged: (value) => update(() => alarm = value),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Programar'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    final updated = task.copyWith(
      dueDate: date,
      scheduledHour: date.hour,
      scheduledMinute: date.minute,
      alarmEnabled: alarm,
    );
    try {
      await context.read<AppProvider>().updateTask(updated);
      await _scheduleReminder(updated);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo guardar el cambio.')),
      );
    }
  }

  Future<void> _addTask() async {
    if (_savingTask || _titleController.text.trim().isEmpty) return;
    final due = _selectedDate;
    if (due != null && !due.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Elige una fecha y hora futuras.')),
      );
      return;
    }
    final task = Task(
      title: _titleController.text.trim(),
      description: _descController.text.trim().isEmpty
          ? null
          : _descController.text.trim(),
      priority: _selectedPriority,
      category: _selectedCategory,
      dueDate: due,
      scheduledHour: due?.hour,
      scheduledMinute: due?.minute,
      alarmEnabled: due != null && _alarmEnabled,
      verificationKeywords: List.of(_selectedKeywords),
    );
    final provider = context.read<AppProvider>();
    _savingTask = true;
    Navigator.pop(context);
    try {
      final saved = await provider.addTask(task);
      if (saved.dueDate != null) await _scheduleReminder(saved);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo guardar la tarea. Intenta de nuevo.'),
        ),
      );
    } finally {
      _savingTask = false;
    }
  }

  Future<void> _verifyWithPhoto(Task task) async {
    if (_photoBusy) return;
    setState(() => _photoBusy = true);
    var stage = 'Abrir cámara o galería';
    try {
      final source = await showModalBottomSheet<String>(
        context: context,
        builder: (sheetContext) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(
                title: Text('Adjuntar foto de la tarea'),
                subtitle: Text(
                  'Centra el objeto, acércate y usa buena luz. Se analizará la foto completa y dos acercamientos en tu teléfono.',
                ),
              ),
              if (_cameraService.supportsCamera)
                ListTile(
                  leading: const Icon(Icons.camera_alt_rounded),
                  title: const Text('Tomar foto'),
                  onTap: () => Navigator.pop(sheetContext, 'camera'),
                ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded),
                title: const Text('Elegir de galería'),
                onTap: () => Navigator.pop(sheetContext, 'gallery'),
              ),
            ],
          ),
        ),
      );
      if (source == null || !mounted) return;
      final photo = source == 'camera'
          ? await _cameraService.takePhoto()
          : await _cameraService.pickFromGallery();
      if (photo == null || !mounted) return;
      stage = 'Leer foto';
      final bytes = await photo.readAsBytes();
      if (bytes.isEmpty) throw const FormatException('Foto vacía');
      if (bytes.length > 8 * 1024 * 1024) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'La foto es demasiado grande. Elige una de menos de 8 MB.',
            ),
          ),
        );
        return;
      }
      // Validate decoding before offering to save the evidence.
      final codec = await ui.instantiateImageCodec(bytes);
      codec.dispose();
      if (!mounted) return;

      bool related = false;
      var observations = <String>[];
      String explanation;
      if (!_cameraService.supportsAnalysis) {
        explanation =
            'La foto se cargó. En esta plataforma no está disponible '
            'el reconocimiento automático. Puedes confirmar la tarea manualmente.';
      } else {
        try {
          final detected = await _cameraService
              .analyzeImage(photo.path)
              .timeout(const Duration(seconds: 45));
          related = _cameraService.verifyTaskCompletion(
            task.title,
            detected.reliableLabels,
            taskKeywords: task.verificationKeywords,
          );
          observations = detected.labels
              .take(6)
              .map(
                (label) =>
                    '${CameraService.displayLabel(label.name)} · ${(label.confidence * 100).round()}%',
              )
              .toList();
          explanation = related
              ? 'Se reconocen objetos relacionados con la tarea. '
                    'La foto no demuestra por sí sola que esté terminada. '
                    '¿Confirmas que la completaste?'
              : 'La foto se cargó, pero no se reconocieron objetos relacionados. '
                    'Puedes intentar con otra foto o confirmar manualmente. '
                    'Acerca el objeto al centro y usa buena luz. '
                    'No se marcará como verificada por foto.';
        } catch (error) {
          debugPrint('Error de análisis de foto: $error');
          explanation =
              'La foto se cargó, pero falló el análisis. '
              'Puedes volver a intentar o confirmar manualmente; '
              'no se marcará como verificada por foto.';
        }
      }
      if (!mounted) return;
      final confirm = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(task.title),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.memory(bytes, height: 200, fit: BoxFit.contain),
                const SizedBox(height: 16),
                if (observations.isNotEmpty) ...[
                  const Text(
                    'Objetos sugeridos por el detector',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: observations
                        .map((label) => Chip(label: Text(label)))
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                ],
                Text(explanation),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Volver'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(
                related ? 'Confirmar tarea' : 'Confirmar manualmente',
              ),
            ),
          ],
        ),
      );
      if (confirm != true || !mounted) return;
      stage = 'Guardar tarea y foto';
      final provider = context.read<AppProvider>();
      // Store bytes in the existing SQLite field, never a temporary camera path
      // or browser blob URL that disappears on restart.
      final reminderCancelled = await provider.updateTask(
        task.copyWith(
          completed: true,
          completedAt: DateTime.now(),
          photoVerified: related,
          photoPath: Uri.dataFromBytes(
            bytes,
            mimeType: photo.mimeType ?? 'application/octet-stream',
          ).toString(),
        ),
      );
      if (related) provider.addPhotoVerification();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            !reminderCancelled
                ? 'Foto y tarea guardadas. $_cancellationWarning'
                : related
                ? 'Tarea completada con foto: ${task.title}'
                : 'Tarea confirmada manualmente con foto adjunta',
          ),
          backgroundColor: reminderCancelled ? AppColors.success : null,
          duration: Duration(seconds: reminderCancelled ? 4 : 10),
        ),
      );
    } on PlatformException catch (error) {
      debugPrint('$stage: $error');
      if (!mounted) return;
      final denied =
          error.code.toLowerCase().contains('denied') ||
          error.code.toLowerCase().contains('restricted');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            stage != 'Abrir cámara o galería'
                ? 'No se pudo completar: $stage. Consulta los detalles.'
                : denied
                ? 'Permiso denegado. Revisa los permisos de cámara y fotos en Ajustes.'
                : 'No se pudo abrir la cámara o galería. Intenta de nuevo.',
          ),
          action: denied
              ? SnackBarAction(label: 'Ajustes', onPressed: openAppSettings)
              : SnackBarAction(
                  label: 'Detalles',
                  onPressed: () => _showErrorDetails(stage, error),
                ),
        ),
      );
    } catch (error) {
      debugPrint('Error al cargar o guardar foto: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo completar: $stage. Consulta los detalles.'),
          action: SnackBarAction(
            label: 'Detalles',
            onPressed: () => _showErrorDetails(stage, error),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _photoBusy = false);
    }
  }

  void _showSavedPhoto(Task task) {
    final data = Uri.tryParse(task.photoPath ?? '')?.data;
    if (data == null) return;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(task.title),
        content: Image.memory(data.contentAsBytes(), fit: BoxFit.contain),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            if (_photoBusy) const LinearProgressIndicator(),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      'Mis Tareas',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
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
    return provider.pendingTasks.where((t) => t.scheduledHour != null).length;
  }

  Widget _buildScheduleView(AppProvider provider) {
    final scheduledTasks =
        provider.tasks
            .where((t) => t.scheduledHour != null && !t.completed)
            .toList()
          ..sort((a, b) {
            return (a.dueDate ?? a.createdAt).compareTo(
              b.dueDate ?? b.createdAt,
            );
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
              style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
            ),
            SizedBox(height: 8),
            Text(
              'Elige fecha y hora en tus tareas\npara ver tus recordatorios aquí',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textLight, fontSize: 14),
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
                Text(task.scheduledLabel, style: const TextStyle(fontSize: 12)),
                if (task.alarmEnabled)
                  const Text('Alarma', style: TextStyle(fontSize: 12)),
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
              onPressed: () => _changeReminder(task),
              icon: const Icon(Icons.edit_calendar),
              tooltip: 'Programar recordatorio',
            ),
          if (!task.completed)
            IconButton(
              onPressed: _photoBusy ? null : () => _verifyWithPhoto(task),
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
              completed
                  ? 'No hay tareas completadas'
                  : 'No hay tareas pendientes',
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
      direction: completed
          ? DismissDirection.none
          : DismissDirection.endToStart,
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
                onTap: () => _completeTask(task),
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: task.priorityColor, width: 2),
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
                      decoration: completed ? TextDecoration.lineThrough : null,
                      color: completed
                          ? AppColors.textLight
                          : AppColors.textPrimary,
                    ),
                  ),
                  if (task.dueDate != null)
                    Text(
                      '${task.alarmEnabled ? '⏰ ' : ''}${task.scheduledLabel}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  Row(
                    children: [
                      if (task.dueDate == null &&
                          task.scheduledTime.isNotEmpty) ...[
                        Icon(
                          Icons.schedule_rounded,
                          size: 14,
                          color: AppColors.textLight,
                        ),
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
                        const Icon(
                          Icons.camera_alt_rounded,
                          size: 14,
                          color: AppColors.secondary,
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'Foto relacionada',
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
            if (task.photoPath?.startsWith('data:') ?? false)
              IconButton(
                onPressed: () => _showSavedPhoto(task),
                icon: const Icon(Icons.image_outlined),
                tooltip: 'Ver foto guardada',
              ),
            if (!completed)
              IconButton(
                onPressed: () => _changeReminder(task),
                icon: const Icon(Icons.edit_calendar),
                tooltip: 'Programar recordatorio',
              ),
            if (!completed)
              IconButton(
                onPressed: _photoBusy ? null : () => _verifyWithPhoto(task),
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

                Material(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event, color: AppColors.primary),
                    title: Text(
                      _selectedDate == null
                          ? 'Elegir fecha y hora (opcional)'
                          : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year} · ${_selectedTime!.format(context)}',
                    ),
                    subtitle: const Text(
                      'Un aviso para la fecha elegida; no se repite cada día.',
                    ),
                    onTap: () async {
                      final picked = await _pickDateTime(
                        initial: _selectedDate,
                      );
                      if (picked != null && context.mounted) {
                        setModalState(() {
                          _selectedDate = picked;
                          _selectedTime = TimeOfDay.fromDateTime(picked);
                        });
                      }
                    },
                    trailing: _selectedDate == null
                        ? null
                        : IconButton(
                            tooltip: 'Quitar recordatorio',
                            icon: const Icon(Icons.close),
                            onPressed: () => setModalState(() {
                              _selectedDate = null;
                              _selectedTime = null;
                              _alarmEnabled = false;
                            }),
                          ),
                  ),
                ),
                if (_selectedDate != null)
                  Material(
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Sonar como alarma'),
                      subtitle: const Text(
                        'En Android, repite el sonido hasta un minuto. Requiere permisos de notificaciones y alarmas; respeta los ajustes de sonido del teléfono.',
                      ),
                      value: _alarmEnabled,
                      onChanged: (value) =>
                          setModalState(() => _alarmEnabled = value),
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
                      'Alta',
                      'high',
                      AppColors.priorityHigh,
                      setModalState,
                    ),
                    const SizedBox(width: 8),
                    _buildPriorityChip(
                      'Media',
                      'medium',
                      AppColors.priorityMedium,
                      setModalState,
                    ),
                    const SizedBox(width: 8),
                    _buildPriorityChip(
                      'Baja',
                      'low',
                      AppColors.priorityLow,
                      setModalState,
                    ),
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
                    _buildCategoryChip(
                      'General',
                      'general',
                      Icons.task_alt,
                      setModalState,
                    ),
                    _buildCategoryChip(
                      'Hogar',
                      'hogar',
                      Icons.home_outlined,
                      setModalState,
                    ),
                    _buildCategoryChip(
                      'Trabajo',
                      'trabajo',
                      Icons.work_outline,
                      setModalState,
                    ),
                    _buildCategoryChip(
                      'Salud',
                      'salud',
                      Icons.favorite_outline,
                      setModalState,
                    ),
                    _buildCategoryChip(
                      'Personal',
                      'personal',
                      Icons.person_outline,
                      setModalState,
                    ),
                    _buildCategoryChip(
                      'Estudio',
                      'estudio',
                      Icons.school_outlined,
                      setModalState,
                    ),
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
    String label,
    String value,
    Color color,
    StateSetter setModalState,
  ) {
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
    String label,
    String value,
    IconData icon,
    StateSetter setModalState,
  ) {
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
