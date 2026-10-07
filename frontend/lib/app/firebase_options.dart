import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Public app identifiers. Only anonymous scanner Auth is used; no Storage SDK.
abstract final class UnlabelFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => android,
      TargetPlatform.iOS => ios,
      _ => throw UnsupportedError(
        'Anonymous saving supports Android, iOS and web.',
      ),
    };
  }

  static const web = FirebaseOptions(
    apiKey: 'AIzaSyAZA7aXNzPCv-mE0vI9iVXsMnkE0GhmZB4',
    appId: '1:122855940292:web:fca019ca44eb1f3c62e991',
    messagingSenderId: '122855940292',
    projectId: 'unlabel-india-catalogue',
    authDomain: 'unlabel-india-catalogue.firebaseapp.com',
  );
  static const android = FirebaseOptions(
    apiKey: 'AIzaSyC1Hp0kaBkFkDIEDikpY2Ugq4n_IT_lhgg',
    appId: '1:122855940292:android:4ba13122b4c8f51362e991',
    messagingSenderId: '122855940292',
    projectId: 'unlabel-india-catalogue',
  );
  static const ios = FirebaseOptions(
    apiKey: 'AIzaSyCqafLzUs8chTr4uHoqm1RV3gNpSehVkSA',
    appId: '1:122855940292:ios:5f90727b0c59810962e991',
    messagingSenderId: '122855940292',
    projectId: 'unlabel-india-catalogue',
    iosBundleId: 'in.unlabel.unlabel',
  );
}
