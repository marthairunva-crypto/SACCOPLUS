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

  // Catch Flutter framework errors
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
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
      navigatorKey: navigatorKey,
      title: SaccoService.current.saccoName.isNotEmpty
          ? SaccoService.current.saccoName
          : 'MBADIFA SACCO',
      debugShowCheckedModeBanner: false,
      theme: theme,
      useInheritedMediaQuery: true,
      locale: DevicePreview.locale(context),
      builder: DevicePreview.appBuilder,
      home: const SplashScreen(),
    );
  }
}
