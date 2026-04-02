import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:permission_handler/permission_handler.dart';

Future<void> downloadPlatform({
  required String url,
  required String filename,
  required void Function(double progress) onProgress,
  required void Function(String path) onDone,
  required void Function(String error) onError,
}) async {
  try {
    // Android storage permission (only needed < API 29)
    if (Platform.isAndroid) {
      final status = await Permission.storage.request();
      if (!status.isGranted) {
        onError('Storage permission denied');
        return;
      }
    }

    Directory dir;
    if (Platform.isAndroid) {
      dir = Directory('/storage/emulated/0/Download');
    } else if (Platform.isWindows) {
      final docs = await getApplicationDocumentsDirectory();
      dir = Directory('${docs.parent.path}\\Downloads');
      if (!await dir.exists()) dir = docs;
    } else if (Platform.isMacOS || Platform.isLinux) {
      final home = Platform.environment['HOME'] ?? '';
      dir = Directory('$home/Downloads');
      if (!await dir.exists()) dir = await getApplicationDocumentsDirectory();
    } else {
      dir = await getApplicationDocumentsDirectory();
    }

    final savePath = '${dir.path}${Platform.pathSeparator}$filename';

    await Dio().download(
      url,
      savePath,
      onReceiveProgress: (received, total) {
        if (total > 0) onProgress(received / total);
      },
      options: Options(
        receiveTimeout: const Duration(minutes: 30),
        sendTimeout: const Duration(minutes: 5),
      ),
    );

    onDone(savePath);

    // Open file on mobile/desktop
    if (Platform.isAndroid || Platform.isIOS) {
      await OpenFile.open(savePath);
    }
  } catch (e) {
    onError(e.toString());
  }
}
