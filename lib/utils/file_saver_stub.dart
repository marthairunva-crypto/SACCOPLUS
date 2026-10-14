// Stub implementation - should never be called
class FileSaver {
  static Future<void> saveFile({
    required String fileName,
    required String content,
    String mimeType = 'text/plain',
  }) async {
    throw UnsupportedError('File saving not supported on this platform');
  }
}
