// Web implementation using dart:html
import 'dart:html' as html;

class FileSaver {
  static Future<void> saveFile({
    required String fileName,
    required String content,
    String mimeType = 'text/plain',
  }) async {
    final blob = html.Blob([content], mimeType);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', fileName)
      ..click();
    html.Url.revokeObjectUrl(url);
  }
}
