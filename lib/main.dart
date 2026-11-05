import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'services/firebase/firebase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase (with graceful fallback to offline mode if unconfigured)
  await FirebaseService.instance.initialize();

  runApp(
    const ProviderScope(
      child: PerfumePosApp(),
    ),
  );
}
