import 'package:flutter/foundation.dart';
import 'download_service_stub.dart'
    if (dart.library.io) 'download_service_native.dart'
    if (dart.library.html) 'download_service_web.dart';

class DownloadService {
  static Future<void> download({
    required String url,
    required String filename,
    required void Function(double progress) onProgress,
    required void Function(String path) onDone,
    required void Function(String error) onError,
  }) async {
    await downloadPlatform(
      url: url,
      filename: filename,
      onProgress: onProgress,
      onDone: onDone,
      onError: onError,
    );
  }
}
