import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:convert';

/// Auto-update service for Windows desktop app
/// Checks GitHub releases for new versions and downloads them
class UpdateService {
  static const String githubRepo = 'MOSEST4/SACCOPLUS';
  static const String githubApiUrl = 'https://api.github.com/repos/$githubRepo/releases/latest';
  
  /// Check if a new version is available
  static Future<Map<String, dynamic>> checkForUpdates() async {
    try {
      // Get current version
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      
      // Fetch latest release from GitHub
      final response = await http.get(Uri.parse(githubApiUrl));
      
      if (response.statusCode != 200) {
        return {
          'hasUpdate': false,
          'error': 'Failed to check for updates',
        };
      }
      
      final releaseData = json.decode(response.body);
      final latestVersion = releaseData['tag_name']?.replaceAll('v', '') ?? '';
      final downloadUrl = _getWindowsAssetUrl(releaseData['assets']);
      
      if (downloadUrl == null) {
        return {
          'hasUpdate': false,
          'error': 'No Windows build found in latest release',
        };
      }
      
      // Compare versions
      final hasUpdate = _isNewerVersion(currentVersion, latestVersion);
      
      return {
        'hasUpdate': hasUpdate,
        'currentVersion': currentVersion,
        'latestVersion': latestVersion,
        'downloadUrl': downloadUrl,
        'releaseNotes': releaseData['body'] ?? '',
        'publishedAt': releaseData['published_at'] ?? '',
      };
    } catch (e) {
      print('Error checking for updates: $e');
      return {
        'hasUpdate': false,
        'error': 'Error: $e',
      };
    }
  }
  
  /// Download the update file
  static Future<String?> downloadUpdate(String downloadUrl, Function(double) onProgress) async {
    try {
      final response = await http.get(Uri.parse(downloadUrl));
      
      if (response.statusCode != 200) {
        return null;
      }
      
      final bytes = response.bodyBytes;
      final dir = await getApplicationDocumentsDirectory();
      final fileName = downloadUrl.split('/').last;
      final filePath = '${dir.path}/$fileName';
      
      final file = File(filePath);
      await file.writeAsBytes(bytes);
      
      return filePath;
    } catch (e) {
      print('Error downloading update: $e');
      return null;
    }
  }
  
  /// Get Windows asset download URL from release assets
  static String? _getWindowsAssetUrl(List<dynamic> assets) {
    for (var asset in assets) {
      final name = asset['name']?.toString().toLowerCase() ?? '';
      if (name.contains('windows') && (name.endsWith('.zip') || name.endsWith('.exe'))) {
        return asset['browser_download_url'];
      }
    }
    return null;
  }
  
  /// Compare version strings (e.g., "1.0.0" vs "1.0.1")
  static bool _isNewerVersion(String current, String latest) {
    final currentParts = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final latestParts = latest.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    
    // Pad shorter version with zeros
    while (currentParts.length < 3) currentParts.add(0);
    while (latestParts.length < 3) latestParts.add(0);
    
    // Compare major.minor.patch
    for (int i = 0; i < 3; i++) {
      if (latestParts[i] > currentParts[i]) return true;
      if (latestParts[i] < currentParts[i]) return false;
    }
    
    return false; // Versions are equal
  }
  
  /// Open the downloaded file location in File Explorer
  static Future<void> openDownloadLocation(String filePath) async {
    if (Platform.isWindows) {
      final dir = File(filePath).parent.path;
      await Process.run('explorer', [dir]);
    }
  }
}
