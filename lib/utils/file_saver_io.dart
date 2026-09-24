// Desktop/Mobile implementation using dart:io
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class FileSaver {
  static Future<void> saveFile({
    required String fileName,
    required String content,
    String mimeType = 'text/plain',
  }) async {
    // For desktop platforms, save to Downloads folder
    final directory = await getDownloadsDirectory();
    if (directory != null) {
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(content);
    } else {
      // Fallback to application documents directory
      final appDir = await getApplicationDocumentsDirectory();
      final file = File('${appDir.path}/$fileName');
      await file.writeAsString(content);
    }
  }
}
