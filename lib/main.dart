import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:device_preview/device_preview.dart'; // ✅ ADDED
import 'firebase_options.dart';
import 'core/sacco_service.dart';
import 'theme/modern_theme.dart';
import 'screens/common/splash_screen.dart';

// Global navigator key for showing dialogs from error handlers
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
  ));

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Print Firebase console links to CMD
  debugPrint('');
  debugPrint('╔═══════════════════════════════════════════════════════════════════════╗');
  debugPrint('║                      FIREBASE CONSOLE LINKS                           ║');
  debugPrint('╠═══════════════════════════════════════════════════════════════════════╣');
  debugPrint('║                                                                       ║');
  debugPrint('║  Firestore Database:                                                  ║');
  debugPrint('║  https://console.firebase.google.com/project/mwiza-projects/firestore ║');
  debugPrint('║                                                                       ║');
  debugPrint('║  Firestore Indexes:                                                   ║');
  debugPrint('║  https://console.firebase.google.com/project/mwiza-projects/firestore/indexes ║');
  debugPrint('║                                                                       ║');
  debugPrint('║  TIP: Ctrl+Click (Windows/Linux) or Cmd+Click (Mac) to open          ║');
  debugPrint('║  Or select the link and copy with Ctrl+C / Cmd+C                     ║');
  debugPrint('╚═══════════════════════════════════════════════════════════════════════╝');
  debugPrint('');

  // Catch Flutter framework errors
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);

    // Check if it's a Firestore index error
    final errorString = details.exception.toString();
    if (errorString.contains('index') && errorString.contains('firebase')) {
      debugPrint('');
      debugPrint('╔═══════════════════════════════════════════════════════════════════════╗');
      debugPrint('║                   FIRESTORE INDEX REQUIRED                            ║');
      debugPrint('╠═══════════════════════════════════════════════════════════════════════╣');
      debugPrint('║                                                                       ║');

      // Extract and print the index URL if present
      final urlMatch = RegExp(r'https://console\.firebase\.google\.com[^\s\)]+')
          .firstMatch(errorString);
      
      String? indexUrl;
      if (urlMatch != null) {
        indexUrl = urlMatch.group(0)!;
        debugPrint('║  CLICK THIS LINK TO AUTO-CREATE THE INDEX:                           ║');
        debugPrint('║                                                                       ║');
        debugPrint('║  $indexUrl');
        debugPrint('║                                                                       ║');
        debugPrint('║  TIP: Ctrl+Click (Windows/Linux) or Cmd+Click (Mac) to open         ║');
        debugPrint('║  Or copy the link above with Ctrl+C / Cmd+C                          ║');
        debugPrint('║  The link will automatically create the required index               ║');
      } else {
        debugPrint('║  Manually create indexes at:                                         ║');
        debugPrint('║  https://console.firebase.google.com/project/mwiza-projects/firestore/indexes ║');
        debugPrint('║                                                                       ║');
        debugPrint('║  TIP: Copy the link above and paste in your browser                  ║');
      }
      debugPrint('║                                                                       ║');
      debugPrint('╚═══════════════════════════════════════════════════════════════════════╝');
      debugPrint('');

      // Show dialog with copyable link
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final context = navigatorKey.currentContext;
        if (context != null) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => FirebaseIndexDialog(indexUrl: indexUrl),
          );
        }
      });
    }
  };

  // Run app with DevicePreview
  runApp(
    DevicePreview(
      enabled: false, // Enabled in debug/profile mode only
      builder: (context) => const SaccoPlusApp(),
    ),
  );
}

class SaccoPlusApp extends StatefulWidget {
  const SaccoPlusApp({super.key});

  // Allow child widgets to trigger a theme rebuild after login
  static _SaccoPlusAppState? of(BuildContext context) =>
      context.findAncestorStateOfType<_SaccoPlusAppState>();

  @override
  State<SaccoPlusApp> createState() => _SaccoPlusAppState();
}

class _SaccoPlusAppState extends State<SaccoPlusApp> {
  /// Called after login when SaccoService has loaded the tenant profile.
  void refreshTheme() => setState(() {});

  @override
  Widget build(BuildContext context) {
    // Use modern clean theme for the entire app
    final theme = ModernTheme.lightTheme;

    return MaterialApp(
      navigatorKey: navigatorKey, // Add global navigator key
      title: SaccoService.current.saccoName.isNotEmpty
          ? SaccoService.current.saccoName
          : 'MBADIFA SACCO',
      debugShowCheckedModeBanner: false,
      theme: theme,

      // Device Preview configuration
      useInheritedMediaQuery: true,
      locale: DevicePreview.locale(context),
      builder: DevicePreview.appBuilder,

      home: const SplashScreen(),
    );
  }
}


// Firebase Index Error Dialog with copyable link
class FirebaseIndexDialog extends StatelessWidget {
  final String? indexUrl;

  const FirebaseIndexDialog({super.key, this.indexUrl});

  @override
  Widget build(BuildContext context) {
    final defaultUrl = 'https://console.firebase.google.com/project/mwiza-projects/firestore/indexes';
    final urlToCopy = indexUrl ?? defaultUrl;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange[700], size: 28),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Firestore Index Required',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'A database query requires a Firestore index to work properly.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            if (indexUrl != null) ...[
              const Text(
                'Click the link below to automatically create the required index:',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ] else ...[
              const Text(
                'Create the index manually at:',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ],
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: SelectableText(
                urlToCopy,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.blue,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'After creating the index, it may take a few minutes to build. Refresh your app once it\'s ready.',
                      style: TextStyle(fontSize: 12, color: Colors.blue[900]),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        OutlinedButton.icon(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: urlToCopy));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: const [
                    Icon(Icons.check_circle, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text('Link copied to clipboard!'),
                  ],
                ),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 2),
              ),
            );
          },
          icon: const Icon(Icons.copy, size: 18),
          label: const Text('Copy Link'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue[700],
            foregroundColor: Colors.white,
          ),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
