import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:device_preview/device_preview.dart'; // ✅ ADDED
import 'firebase_options.dart';
import 'core/sacco_service.dart';
import 'theme/modern_theme.dart';
import 'screens/common/splash_screen.dart';

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
  debugPrint('║                     🔥 FIREBASE CONSOLE LINKS                         ║');
  debugPrint('╠═══════════════════════════════════════════════════════════════════════╣');
  debugPrint('║                                                                       ║');
  debugPrint('║  📊 Firestore Database:                                               ║');
  debugPrint('║  https://console.firebase.google.com/project/mwiza-projects/firestore ║');
  debugPrint('║                                                                       ║');
  debugPrint('║  � Firestore Indexes:                                                ║');
  debugPrint('║  https://console.firebase.google.com/project/mwiza-projects/firestore/indexes ║');
  debugPrint('║                                                                       ║');
  debugPrint('║  💡 TIP: Ctrl+Click (Windows/Linux) or Cmd+Click (Mac) to open       ║');
  debugPrint('║  💡 Or select the link and copy with Ctrl+C / Cmd+C                  ║');
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
      debugPrint('║                  ⚠️  FIRESTORE INDEX REQUIRED ⚠️                       ║');
      debugPrint('╠═══════════════════════════════════════════════════════════════════════╣');
      debugPrint('║                                                                       ║');

      // Extract and print the index URL if present
      final urlMatch = RegExp(r'https://console\.firebase\.google\.com[^\s\)]+')
          .firstMatch(errorString);
      if (urlMatch != null) {
        final url = urlMatch.group(0)!;
        debugPrint('║  🔗 CLICK THIS LINK TO AUTO-CREATE THE INDEX:                        ║');
        debugPrint('║                                                                       ║');
        debugPrint('║  $url');
        debugPrint('║                                                                       ║');
        debugPrint('║  💡 Ctrl+Click (Windows/Linux) or Cmd+Click (Mac) to open            ║');
        debugPrint('║  💡 Or copy the link above with Ctrl+C / Cmd+C                       ║');
        debugPrint('║  💡 The link will automatically create the required index            ║');
      } else {
        debugPrint('║  🔗 Manually create indexes at:                                      ║');
        debugPrint('║  https://console.firebase.google.com/project/mwiza-projects/firestore/indexes ║');
        debugPrint('║                                                                       ║');
        debugPrint('║  💡 Copy the link above and paste in your browser                    ║');
      }
      debugPrint('║                                                                       ║');
      debugPrint('╚═══════════════════════════════════════════════════════════════════════╝');
      debugPrint('');
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