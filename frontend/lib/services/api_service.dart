import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/video_info.dart';
import 'backend_config_service.dart';

class ApiService {
  String get _base => BackendConfigService.instance.baseUrl;

  Future<VideoInfo> fetchInfo(String url) async {
    final response = await http.post(
      Uri.parse('$_base/api/info'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'url': url}),
    );
    if (response.statusCode != 200) {
      throw Exception(_extractError(response.body));
    }
    return VideoInfo.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<String> startDownloadJob({
    required String url,
    String? formatId,
    bool audioOnly = false,
    String audioFormat = 'mp3',
  }) async {
    final response = await http.post(
      Uri.parse('$_base/api/download/start'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'url': url,
        'format_id': ?formatId,
        'audio_only': audioOnly,
        'audio_format': audioFormat,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception(_extractError(response.body));
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['job_id'] as String;
  }

  Stream<Map<String, dynamic>> streamJobEvents(String jobId) async* {
    final request = http.Request(
      'GET',
      Uri.parse('$_base/api/download/$jobId/events'),
    );
    final streamedResponse = await http.Client().send(request);
    final lines = streamedResponse.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter());
    await for (final line in lines) {
      if (line.startsWith('data: ')) {
        yield jsonDecode(line.substring(6)) as Map<String, dynamic>;
      }
    }
  }

  Uri fileUri(String filename) =>
      Uri.parse('$_base/api/file/${Uri.encodeComponent(filename)}');

  Future<void> cancelJob(String jobId) async {
    await http.post(Uri.parse('$_base/api/download/$jobId/cancel'));
  }

  String _extractError(String body) {
    try {
      final data = jsonDecode(body) as Map<String, dynamic>;
      return data['detail']?.toString() ?? 'Something went wrong';
    } catch (_) {
      return 'Something went wrong';
    }
  }
}
