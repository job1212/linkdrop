Future<void> downloadPlatform({
  required String url,
  required String filename,
  required void Function(double progress) onProgress,
  required void Function(String path) onDone,
  required void Function(String error) onError,
}) async {
  onError('Downloads not supported on this platform');
}
