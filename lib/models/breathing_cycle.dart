/// One clock drives the instructions and circle, including pause/resume.
class BreathingCycle {
  BreathingCycle(int elapsedSeconds) : second = elapsedSeconds % 10;
  final int second;
  bool get inhaling => second < 4;
  int get remaining => inhaling ? 4 - second : 10 - second;
  String get prompt =>
      inhaling ? 'Inhala · $remaining s' : 'Exhala · $remaining s';
  double get scale =>
      inhaling ? 0.8 + 0.4 * second / 4 : 1.2 - 0.4 * (second - 4) / 6;
}
