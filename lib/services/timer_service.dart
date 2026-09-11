import 'dart:async';
import 'package:flutter/foundation.dart';

class TimerService extends ChangeNotifier {
  Timer? _timer;
  int _totalSeconds = 0;
  int _remainingSeconds = 0;
  bool _isRunning = false;
  bool _isPaused = false;
  String _currentMode = 'mindfulness'; // mindfulness, focus, pomodoro
  int _pomodoroSession = 0;
  bool _isBreak = false;

  int get totalSeconds => _totalSeconds;
  int get remainingSeconds => _remainingSeconds;
  bool get isRunning => _isRunning;
  bool get isPaused => _isPaused;
  String get currentMode => _currentMode;
  int get pomodoroSession => _pomodoroSession;
  bool get isBreak => _isBreak;

  double get progress =>
      _totalSeconds > 0 ? (_totalSeconds - _remainingSeconds) / _totalSeconds : 0;

  String get formattedTime {
    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void startTimer(int minutes, {String mode = 'mindfulness'}) {
    _totalSeconds = minutes * 60;
    _remainingSeconds = _totalSeconds;
    _currentMode = mode;
    _isRunning = true;
    _isPaused = false;
    _isBreak = false;
    notifyListeners();
    _startCountdown();
  }

  void _startCountdown() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        _remainingSeconds--;
        notifyListeners();
      } else {
        _timer?.cancel();
        _isRunning = false;
        if (_currentMode == 'pomodoro') {
          _handlePomodoroComplete();
        }
        notifyListeners();
      }
    });
  }

  void pauseTimer() {
    _timer?.cancel();
    _isPaused = true;
    _isRunning = false;
    notifyListeners();
  }

  void resumeTimer() {
    _isPaused = false;
    _isRunning = true;
    _startCountdown();
  }

  void stopTimer() {
    _timer?.cancel();
    _isRunning = false;
    _isPaused = false;
    _remainingSeconds = 0;
    notifyListeners();
  }

  int get elapsedSeconds => _totalSeconds - _remainingSeconds;

  int get elapsedMinutes => elapsedSeconds ~/ 60;

  void _handlePomodoroComplete() {
    _pomodoroSession++;
    if (_pomodoroSession % 4 == 0) {
      _isBreak = true;
      _totalSeconds = 15 * 60; // Long break
    } else {
      _isBreak = true;
      _totalSeconds = 5 * 60; // Short break
    }
    _remainingSeconds = _totalSeconds;
    notifyListeners();
  }

  void startPomodoroBreak() {
    _isBreak = true;
    _isRunning = true;
    _startCountdown();
  }

  void resetPomodoro() {
    _pomodoroSession = 0;
    _isBreak = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
