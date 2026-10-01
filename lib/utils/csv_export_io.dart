import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

/// Desktop/Mobile CSV download implementation
Future<void> downloadCsv(String csvContent, String filename) async {
  try {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      // Desktop platforms - save to Downloads folder
      final downloadsDir = await getDownloadsDirectory();
      
      if (downloadsDir != null) {
        final file = File('${downloadsDir.path}/$filename');
        await file.writeAsString(csvContent);
        print('CSV saved to: ${file.path}');
      } else {
        // Fallback to user selection
        final result = await FilePicker.platform.saveFile(
          dialogTitle: 'Save CSV File',
          fileName: filename,
          type: FileType.custom,
          allowedExtensions: ['csv'],
        );

        if (result != null) {
          final file = File(result);
          await file.writeAsString(csvContent);
          print('CSV saved to: $result');
        }
      }
    } else if (Platform.isAndroid || Platform.isIOS) {
      // Mobile platforms - save to app documents
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$filename');
      await file.writeAsString(csvContent);
      print('CSV saved to: ${file.path}');
    }
  } catch (e) {
    print('Error saving CSV: $e');
    rethrow;
  }
}
