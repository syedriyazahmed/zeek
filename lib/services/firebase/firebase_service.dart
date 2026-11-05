import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class FirebaseService {
  FirebaseService._();
  static final FirebaseService instance = FirebaseService._();

  bool _isInitialized = false;
  String? _initializationError;

  bool get isInitialized => _isInitialized;
  String? get initializationError => _initializationError;

  FirebaseAuth? _auth;
  FirebaseFirestore? _firestore;

  FirebaseAuth? get auth => _auth;
  FirebaseFirestore? get firestore => _firestore;

  Future<void> initialize({FirebaseOptions? options}) async {
    try {
      if (Firebase.apps.isEmpty) {
        if (options != null) {
          await Firebase.initializeApp(options: options);
        } else {
          await Firebase.initializeApp();
        }
      }
      _auth = FirebaseAuth.instance;
      _firestore = FirebaseFirestore.instance;
      _isInitialized = true;
      _initializationError = null;

      // Enable offline persistence for web / mobile
      if (!kIsWeb) {
        _firestore?.settings = const Settings(
          persistenceEnabled: true,
          cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
        );
      }
      debugPrint('[FirebaseService] Successfully connected to Firebase.');
    } catch (e, stackTrace) {
      _initializationError = e.toString();
      debugPrint('====================================================');
      debugPrint('[FirebaseService] FIREBASE INITIALIZATION ERROR:');
      debugPrint(e.toString());
      debugPrint('Stack trace:\n$stackTrace');
      debugPrint('[FirebaseService] Running in localized shop database mode.');
      debugPrint('====================================================');
      _isInitialized = false;
    }
  }

  /// Connect to local Firebase Emulators if running during development
  void useEmulators({
    String host = 'localhost',
    int authPort = 9099,
    int firestorePort = 8080,
  }) {
    if (!_isInitialized) return;
    try {
      _auth?.useAuthEmulator(host, authPort);
      _firestore?.useFirestoreEmulator(host, firestorePort);
      debugPrint('[FirebaseService] Connected to Firebase Emulators at $host.');
    } catch (e) {
      debugPrint('[FirebaseService] Error connecting to emulators: $e');
    }
  }
}

