import 'dart:io';

import 'package:path_provider/path_provider.dart';

class FolderService {
  static const folderName = 'All in 1 Downloader';

  Future<String> getSavedFolder() async {
    Directory? base;
    try {
      base = await getDownloadsDirectory();
    } catch (_) {
      base = null;
    }
    base ??= await getApplicationDocumentsDirectory();

    final target = Directory('${base.path}/$folderName');
    await target.create(recursive: true);
    return target.path;
  }
}
