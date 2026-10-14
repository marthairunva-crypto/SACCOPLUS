// Generated Firebase options for mwiza-projects
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        return android;
    }
  }

  // Web config (from the JS snippet you provided)
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyC0HwJn3KvCXy0MZh9TI6_eacByPFF8hRc',
    authDomain: 'mwiza-projects.firebaseapp.com',
    projectId: 'mwiza-projects',
    storageBucket: 'mwiza-projects.firebasestorage.app',
    messagingSenderId: '1014389560221',
    appId: '1:1014389560221:web:cb0f45fb75333f2b7f9574',
    measurementId: 'G-6VG1G5D3WW',
  );

  // Android config (from google-services.json)
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAdrvnjySa2Btru872Tm6AQCKutdCEqz_o',
    appId: '1:1014389560221:android:b3109ea528916a497f9574',
    messagingSenderId: '1014389560221',
    projectId: 'mwiza-projects',
    storageBucket: 'mwiza-projects.firebasestorage.app',
  );

  // iOS — fill in if you add GoogleService-Info.plist
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAdrvnjySa2Btru872Tm6AQCKutdCEqz_o',
    appId: '1:1014389560221:ios:b3109ea528916a497f9574',
    messagingSenderId: '1014389560221',
    projectId: 'mwiza-projects',
    storageBucket: 'mwiza-projects.firebasestorage.app',
    iosBundleId: 'com.example.agriLoan',
  );
}
