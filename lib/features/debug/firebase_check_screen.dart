import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

class FirebaseCheckScreen extends StatefulWidget {
  const FirebaseCheckScreen({super.key});

  @override
  State<FirebaseCheckScreen> createState() => _FirebaseCheckScreenState();
}

class _FirebaseCheckScreenState extends State<FirebaseCheckScreen> {
  bool _isLoading = false;
  bool? _isSuccess;
  String? _projectId;
  String? _statusMessage;
  String? _detailedLog;

  Future<void> _testFirebaseConnection() async {
    setState(() {
      _isLoading = true;
      _isSuccess = null;
      _statusMessage = null;
      _detailedLog = null;
    });

    try {
      // 1. Verify and show Firebase project ID
      final app = Firebase.app();
      final projectId = app.options.projectId;
      _projectId = projectId.isNotEmpty ? projectId : 'Unknown (Default App)';

      // 2. Write document to 'connection_test' collection with server timestamp
      final testCollection = FirebaseFirestore.instance.collection('connection_test');
      final newDocRef = testCollection.doc();
      final testPayload = {
        'testId': newDocRef.id,
        'createdAt': FieldValue.serverTimestamp(),
        'platform': Theme.of(context).platform.toString(),
        'clientTime': DateTime.now().toIso8601String(),
        'message': 'Live Firebase Connection Test',
      };

      await newDocRef.set(testPayload);

      // 3. Read that document back
      final snapshot = await newDocRef.get();
      if (!snapshot.exists) {
        throw Exception('Document was written but could not be read back from Firestore.');
      }

      final readData = snapshot.data();

      // 4. Success state
      setState(() {
        _isSuccess = true;
        _statusMessage = 'Connected! Firestore Read/Write Verified.';
        _detailedLog = 'Project ID: $_projectId\n'
            'Document ID: ${snapshot.id}\n'
            'Data verified: $readData';
      });
    } catch (e, stackTrace) {
      setState(() {
        _isSuccess = false;
        _statusMessage = 'Connection Failed: ${e.toString()}';
        _detailedLog = 'Stack Trace:\n$stackTrace';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Firebase Connection Check'),
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.cloud_sync, color: Color(0xFFD4AF37), size: 36),
                        const SizedBox(width: 12),
                        Text(
                          'Firebase Live Test',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'This screen verifies read/write connectivity with Cloud Firestore '
                      'and displays the active Firebase Project ID.',
                      style: TextStyle(color: Colors.black87, fontSize: 14),
                    ),
                    const SizedBox(height: 24),
                    if (_projectId != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          children: [
                            const Text(
                              'Firebase Project ID: ',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              _projectId!,
                              style: const TextStyle(
                                color: Color(0xFF1E293B),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    SizedBox(
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _testFirebaseConnection,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E293B),
                          foregroundColor: const Color(0xFFD4AF37),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFFD4AF37),
                                ),
                              )
                            : const Icon(Icons.play_arrow),
                        label: Text(
                          _isLoading ? 'Testing Connection...' : 'Test Firebase',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (_isSuccess == true)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green.shade400, width: 2),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.check_circle, color: Colors.green, size: 28),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _statusMessage ?? 'Connected',
                                    style: const TextStyle(
                                      color: Colors.green,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (_detailedLog != null) ...[
                              const Divider(height: 24),
                              Text(
                                _detailedLog!,
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                  color: Colors.green.shade900,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    if (_isSuccess == false)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.shade400, width: 2),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.error, color: Colors.red, size: 28),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _statusMessage ?? 'Connection Failed',
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (_detailedLog != null) ...[
                              const Divider(height: 24),
                              Text(
                                _detailedLog!,
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 11,
                                  color: Colors.red.shade900,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

