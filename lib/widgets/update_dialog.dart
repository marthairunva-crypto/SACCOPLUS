import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/update_service.dart';

class UpdateDialog extends StatefulWidget {
  final Map<String, dynamic> updateInfo;

  const UpdateDialog({Key? key, required this.updateInfo}) : super(key: key);

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool _isDownloading = false;
  double _downloadProgress = 0;
  String? _downloadedFilePath;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.system_update, color: Colors.green.shade700),
          const SizedBox(width: 8),
          const Text('Update Available'),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Version info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Current Version:',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        widget.updateInfo['currentVersion'],
                        style: GoogleFonts.inter(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'New Version:',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        widget.updateInfo['latestVersion'],
                        style: GoogleFonts.inter(
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Release notes
            if (widget.updateInfo['releaseNotes']?.toString().isNotEmpty ?? false) ...[
              Text(
                'What\'s New:',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                constraints: const BoxConstraints(maxHeight: 150),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    widget.updateInfo['releaseNotes'],
                    style: GoogleFonts.inter(fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            // Download progress
            if (_isDownloading) ...[
              LinearProgressIndicator(value: _downloadProgress),
              const SizedBox(height: 8),
              Text(
                'Downloading... ${(_downloadProgress * 100).toStringAsFixed(0)}%',
                style: GoogleFonts.inter(fontSize: 12),
              ),
            ],
            
            // Success message
            if (_downloadedFilePath != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Update downloaded! Close the app and install the new version.',
                        style: GoogleFonts.inter(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (_downloadedFilePath != null)
          TextButton(
            onPressed: () async {
              await UpdateService.openDownloadLocation(_downloadedFilePath!);
            },
            child: const Text('Open Download Folder'),
          ),
        if (!_isDownloading && _downloadedFilePath == null)
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Later'),
          ),
        if (!_isDownloading && _downloadedFilePath == null)
          ElevatedButton.icon(
            onPressed: _downloadUpdate,
            icon: const Icon(Icons.download),
            label: const Text('Download Now'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700,
            ),
          ),
        if (_downloadedFilePath != null)
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
      ],
    );
  }

  Future<void> _downloadUpdate() async {
    setState(() => _isDownloading = true);
    
    final downloadUrl = widget.updateInfo['downloadUrl'];
    
    final filePath = await UpdateService.downloadUpdate(
      downloadUrl,
      (progress) {
        setState(() => _downloadProgress = progress);
      },
    );
    
    setState(() {
      _isDownloading = false;
      _downloadedFilePath = filePath;
    });
    
    if (filePath != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Update downloaded successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to download update'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
