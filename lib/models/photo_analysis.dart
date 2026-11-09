class PhotoLabel {
  const PhotoLabel(this.name, this.confidence);
  final String name;
  final double confidence;
}

class PhotoAnalysis {
  const PhotoAnalysis(this.labels);
  final List<PhotoLabel> labels;
  List<String> get reliableLabels => labels
      .where((label) => label.confidence >= 0.45)
      .map((label) => label.name)
      .toList();

  static PhotoAnalysis merge(Iterable<PhotoLabel> labels) {
    final best = <String, double>{};
    for (final label in labels) {
      final key = label.name.toLowerCase().trim();
      if (label.confidence > (best[key] ?? 0)) best[key] = label.confidence;
    }
    final merged =
        best.entries.map((entry) => PhotoLabel(entry.key, entry.value)).toList()
          ..sort((a, b) => b.confidence.compareTo(a.confidence));
    return PhotoAnalysis(merged);
  }
}
