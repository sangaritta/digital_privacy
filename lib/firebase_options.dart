// File generated by FlutterFire CLI.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCbqhH6J8KNrbY5EQPCEKlX0EJMA-CaE10',
    appId: '1:232110446646:web:04480782e49d890553e097',
    messagingSenderId: '232110446646',
    projectId: 'mydata-999',
    authDomain: 'mydata-999.firebaseapp.com',
    databaseURL: 'https://mydata-999-default-rtdb.firebaseio.com',
    storageBucket: 'mydata-999.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBFf_hmuYhlS8VnFygSjfijewB3ZqX9FAg',
    appId: '1:232110446646:android:c6052aa2e3afa78c53e097',
    messagingSenderId: '232110446646',
    projectId: 'mydata-999',
    databaseURL: 'https://mydata-999-default-rtdb.firebaseio.com',
    storageBucket: 'mydata-999.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyB59MF9sHaSThwsJAztEDJtXyDAlb3Xbj8',
    appId: '1:232110446646:ios:6d35bf06f5968e9e53e097',
    messagingSenderId: '232110446646',
    projectId: 'mydata-999',
    databaseURL: 'https://mydata-999-default-rtdb.firebaseio.com',
    storageBucket: 'mydata-999.firebasestorage.app',
    iosBundleId: 'cc.blackmatter.ttu',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyB59MF9sHaSThwsJAztEDJtXyDAlb3Xbj8',
    appId: '1:232110446646:ios:6d35bf06f5968e9e53e097',
    messagingSenderId: '232110446646',
    projectId: 'mydata-999',
    databaseURL: 'https://mydata-999-default-rtdb.firebaseio.com',
    storageBucket: 'mydata-999.firebasestorage.app',
    iosBundleId: 'cc.blackmatter.ttu',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyCbqhH6J8KNrbY5EQPCEKlX0EJMA-CaE10',
    appId: '1:232110446646:web:888f2a0686bd186353e097',
    messagingSenderId: '232110446646',
    projectId: 'mydata-999',
    authDomain: 'mydata-999.firebaseapp.com',
    databaseURL: 'https://mydata-999-default-rtdb.firebaseio.com',
    storageBucket: 'mydata-999.firebasestorage.app',
  );
}
