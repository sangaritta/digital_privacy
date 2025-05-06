import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:go_router/go_router.dart';
import 'dart:async'; // For StreamSubscription (though maybe not needed here long term)

class StudentJoinScreen extends StatefulWidget {
  final String? sessionIdFromUrl; // Session ID from QR code URL
  const StudentJoinScreen({super.key, this.sessionIdFromUrl});

  @override
  State<StudentJoinScreen> createState() => _StudentJoinScreenState();
}

class _StudentJoinScreenState extends State<StudentJoinScreen> {
  final _nicknameController = TextEditingController();
  final _sessionCodeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? _errorMessage;
  bool _isJoining = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill session code if provided via URL (from QR scan)
    if (widget.sessionIdFromUrl != null) {
      _sessionCodeController.text = widget.sessionIdFromUrl!;
    }
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _sessionCodeController.dispose();
    super.dispose();
  }

  Future<void> _joinSession() async {
    // Prevent multiple simultaneous attempts
    if (_isJoining || !_formKey.currentState!.validate()) return;

    setState(() {
      _isJoining = true;
      _errorMessage = null; // Clear previous errors
    });

    final nickname = _nicknameController.text.trim();
    final sessionId = _sessionCodeController.text.trim().toUpperCase();

    // Basic validation already done by form validator

    // 1. Check if session exists in Firebase
    final sessionRef = FirebaseDatabase.instance.ref('sessions/$sessionId');
    final snapshot = await sessionRef.get();

    if (!snapshot.exists) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Session not found. Please check the code.';
          _isJoining = false;
        });
      }
      return;
    }

    // 2. Add student to the session (using push for unique ID)
    final studentRef = sessionRef.child('students').push(); // Generate unique ID
    final studentId = studentRef.key; // Get the generated key

    if (studentId == null) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Could not generate student ID. Please try again.';
          _isJoining = false;
        });
      }
      return;
    }

    try {
      // 3. Set student data including initial online status
      await studentRef.set({
        'nickname': nickname,
        'joinedAt': ServerValue.timestamp,
        'isOnline': true, // Set initial online status
        // Add other relevant student info if needed
      });

      // 4. Setup presence (will mark offline on disconnect)
      _setupPresence(sessionId, studentId);

      // 5. Navigate to the StudentScreen for the joined session
      if (mounted) {
        // Pass student info via 'extra' in case StudentScreen needs it later
        context.go('/student/$sessionId', extra: { 'studentId': studentId, 'nickname': nickname });
      }
    } catch (e) {
      print("Error joining session: $e");
      if (mounted) {
        setState(() {
          _errorMessage = 'An error occurred while joining. Please try again.';
          _isJoining = false; // Allow retry on error
        });
      }
    }
    // Don't reset _isJoining here if navigation is successful, as this screen is replaced.
  }

  // Setup basic presence - marks student as offline when disconnected
  // This runs once when the student joins. The listener keeps running
  // in the background managed by the Firebase SDK.
  void _setupPresence(String sessionId, String studentId) {
    final studentStatusRef = FirebaseDatabase.instance.ref('sessions/$sessionId/students/$studentId/isOnline');
    final connectedRef = FirebaseDatabase.instance.ref('.info/connected');

    // Use a listener to handle initial connection and reconnections
    // This listener needs to be managed if the user can navigate away *without*
    // disconnecting (e.g. back button before joining), but here we assume
    // successful join replaces the screen.
    connectedRef.onValue.listen((event) {
      final isConnected = event.snapshot.value == true;
      if (isConnected) {
        // We're connected (or reconnected). Set online status.
        studentStatusRef.set(true);
        // IMPORTANT: Set up onDisconnect hook *every time* connection is established.
        studentStatusRef.onDisconnect().set(false);
      }
      // Note: No 'else' needed as onDisconnect handles marking offline.
    });
    // Potential Improvement: Store this listener subscription and cancel in dispose()
    // if there's a chance this screen persists or user navigates back.
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Join Session')),
      body: Center(
        child: SingleChildScrollView( // Prevents overflow on smaller screens
          padding: const EdgeInsets.all(30.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  widget.sessionIdFromUrl != null
                      ? 'Enter Your Nickname'
                      : 'Enter Nickname and Session Code',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),
                TextFormField(
                  controller: _nicknameController,
                  decoration: const InputDecoration(
                    labelText: 'Nickname',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a nickname';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _sessionCodeController,
                  decoration: const InputDecoration(
                    labelText: '8-Digit Session Code',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.tag),
                    counterText: "", // Hide the default counter
                  ),
                  maxLength: 8, // Enforce length
                  textCapitalization: TextCapitalization.characters, // Help with uppercase
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter the session code';
                    }
                    final trimmedValue = value.trim();
                    if (trimmedValue.length != 8) {
                     return 'Code must be exactly 8 characters';
                    }
                    // Basic hex check (allows 0-9, A-F, a-f)
                    if (!RegExp(r'^[a-fA-F0-9]{8}$').hasMatch(trimmedValue)) {
                      return 'Code must contain only letters A-F and numbers 0-9';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 30),
                // Display error message if any
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 15.0),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                      textAlign: TextAlign.center,
                    ),
                  ),
                 // Show loading indicator or join button
                 _isJoining
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                    onPressed: _joinSession,
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15)),
                    child: const Text('Join', style: TextStyle(fontSize: 16)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
