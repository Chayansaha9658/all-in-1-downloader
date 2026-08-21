import 'dart:io';

import 'package:http/http.dart' as http;

class FileSaverService {
  Future<String> downloadToFolder({
    required String folderPath,
    required Uri sourceUri,
    required String filename,
    required void Function(double progress) onProgress,
  }) async {
    final request = http.Request('GET', sourceUri);
    final streamedResponse = await http.Client().send(request);
    if (streamedResponse.statusCode != 200) {
      throw Exception('File download failed');
    }

    final total = streamedResponse.contentLength ?? 0;
    final targetDir = Directory(folderPath);
    await targetDir.create(recursive: true);
    final targetFile = File('${targetDir.path}/$filename');
    final sink = targetFile.openWrite();
    var received = 0;

    await for (final chunk in streamedResponse.stream) {
      sink.add(chunk);
      received += chunk.length;
      if (total > 0) onProgress(received / total);
    }
    await sink.close();

    return targetFile.path;
  }
}
