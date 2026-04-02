// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:http/http.dart' as http;

Future<void> downloadPlatform({
  required String url,
  required String filename,
  required void Function(double progress) onProgress,
  required void Function(String path) onDone,
  required void Function(String error) onError,
}) async {
  try {
    onProgress(0.1);
    final response = await http.get(Uri.parse(url));
    onProgress(0.9);

    final blob = html.Blob([response.bodyBytes]);
    final blobUrl = html.Url.createObjectUrlFromBlob(blob);

    final anchor = html.AnchorElement(href: blobUrl)
      ..setAttribute('download', filename)
      ..click();

    html.Url.revokeObjectUrl(blobUrl);
    onProgress(1.0);
    onDone(filename);
  } catch (e) {
    onError(e.toString());
  }
}
