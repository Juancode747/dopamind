class PhotoRegions {
  PhotoRegions(this.paths);
  final List<String> paths;
  static Future<PhotoRegions> prepare(String path) async =>
      PhotoRegions([path]);
  Future<void> dispose() async {}
}
