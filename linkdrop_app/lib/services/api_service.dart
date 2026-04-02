import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/media_info.dart';

class ApiService {
  // On Android emulator use 10.0.2.2, on physical device use your PC's LAN IP
  // On web/Windows/macOS localhost works fine
  static String get baseUrl => 'https://linkdrop-production.up.railway.app/api';

  static Future<MediaInfo> fetchInfo(String url) async {
    final uri = Uri.parse('$baseUrl/info?url=${Uri.encodeComponent(url)}');
    final response = await http.get(uri).timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      return MediaInfo.fromJson(json.decode(response.body));
    } else {
      final error = json.decode(response.body);
      throw Exception(error['error'] ?? 'Failed to fetch info');
    }
  }

  static String getDownloadUrl(String url, String? formatId, String title, {String? directUrl}) {
    if (directUrl != null) {
      return '$baseUrl/download?direct_url=${Uri.encodeComponent(directUrl)}&title=${Uri.encodeComponent(title)}';
    }
    final params = <String, String>{
      'url': url,
      'title': title,
      if (formatId != null) 'format_id': formatId,
    };
    final query = params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
    return '$baseUrl/download?$query';
  }
}
