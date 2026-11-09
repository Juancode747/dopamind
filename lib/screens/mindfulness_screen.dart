import '../widgets/session_body.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/timer_service.dart';
import '../services/app_provider.dart';
import '../utils/colors.dart';
import '../utils/constants.dart';
import '../models/breathing_cycle.dart';

class MindfulnessScreen extends StatefulWidget {
  const MindfulnessScreen({super.key});

  @override
  State<MindfulnessScreen> createState() => _MindfulnessScreenState();
}

class _MindfulnessScreenState extends State<MindfulnessScreen> {
  int _selectedMinutes = 5;
  String _selectedMode = 'respiracion';
  bool _sessionStarted = false;

  void _startSession() {
    final timerService = context.read<TimerService>();
    timerService.startTimer(_selectedMinutes, mode: 'mindfulness');
    setState(() => _sessionStarted = true);
  }

  void _endSession() {
    if (!mounted || !_sessionStarted) return;
    final timerService = context.read<TimerService>();
    final provider = context.read<AppProvider>();
    final elapsed = timerService.elapsedMinutes;
    provider.addMindfulSession(elapsed > 0 ? elapsed : 1);
    timerService.stopTimer();

    setState(() => _sessionStarted = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Sesión completada: $elapsed minutos'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final timerService = context.watch<TimerService>();

    if (_sessionStarted &&
        !timerService.isRunning &&
        timerService.remainingSeconds == 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _endSession();
      });
    }

    return PopScope<void>(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop && _sessionStarted) _endSession();
      },
      child: Scaffold(
        backgroundColor: AppColors.focusMode,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: () {
                        if (_sessionStarted) _endSession();
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.arrow_back_ios_rounded),
                      color: Colors.white,
                    ),
                    const Expanded(
                      child: Text(
                        'Atención Plena',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              Expanded(
                child: _sessionStarted
                    ? _buildActiveSession(timerService)
                    : _buildSessionSetup(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSessionSetup() {
    return SessionBody(
      child: Column(
        children: [
          const Spacer(),
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.mindfulness,
                  AppColors.mindfulness.withOpacity(0.6),
                ],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.mindfulness.withOpacity(0.4),
                  blurRadius: 40,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: const Center(
              child: Text('🧘', style: TextStyle(fontSize: 56)),
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'Elige tu práctica',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildModeChip('Respiración', 'respiracion', Icons.air),
              _buildModeChip('Escaneo', 'escaneo', Icons.accessibility_new),
              _buildModeChip('Gratitud', 'gratitud', Icons.favorite),
            ],
          ),
          const SizedBox(height: 32),
          const Text(
            'Duración',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            runSpacing: 8,
            children: [3, 5, 10, 15, 20].map((min) {
              final isSelected = _selectedMinutes == min;
              return GestureDetector(
                onTap: () => setState(() => _selectedMinutes = min),
                child: Container(
                  width: 56,
                  height: 56,
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.mindfulness
                        : Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.mindfulness
                          : Colors.white.withOpacity(0.2),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '$min',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _startSession,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.mindfulness,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Comenzar',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildModeChip(String label, String value, IconData icon) {
    final isSelected = _selectedMode == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedMode = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.mindfulness
              : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveSession(TimerService timerService) {
    final prompts = AppConstants.mindfulnessPrompts[_selectedMode] ?? [];
    final currentPromptIndex = prompts.isEmpty
        ? 0
        : (timerService.progress * prompts.length).floor().clamp(
            0,
            prompts.length - 1,
          );
    final breath = BreathingCycle(timerService.elapsedSeconds);
    final currentPrompt = _selectedMode == 'respiracion'
        ? breath.prompt
        : (prompts.isNotEmpty ? prompts[currentPromptIndex] : '');

    return SessionBody(
      child: Column(
        children: [
          const Spacer(),
          AnimatedScale(
            scale: _selectedMode == 'respiracion' ? breath.scale : 1,
            duration: timerService.isPaused
                ? Duration.zero
                : const Duration(seconds: 1),
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.mindfulness.withOpacity(0.3),
                    AppColors.mindfulness.withOpacity(0.1),
                  ],
                ),
                border: Border.all(
                  color: AppColors.mindfulness.withOpacity(0.5),
                  width: 3,
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      timerService.formattedTime,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${_selectedMinutes} min total',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 40),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            child: Text(
              currentPrompt,
              key: ValueKey(currentPrompt),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (timerService.isRunning)
                _buildControlButton(
                  Icons.pause_rounded,
                  timerService.pauseTimer,
                )
              else if (timerService.isPaused)
                _buildControlButton(
                  Icons.play_arrow_rounded,
                  timerService.resumeTimer,
                ),
              const SizedBox(width: 24),
              _buildControlButton(
                Icons.stop_rounded,
                _endSession,
                isStop: true,
              ),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildControlButton(
    IconData icon,
    VoidCallback onTap, {
    bool isStop = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: isStop
              ? AppColors.error.withOpacity(0.2)
              : Colors.white.withOpacity(0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: isStop ? AppColors.error : Colors.white,
          size: 32,
        ),
      ),
    );
  }
}
