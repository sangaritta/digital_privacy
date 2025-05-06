import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_database/firebase_database.dart';
// import 'package:firebase_auth/firebase_auth.dart'; // Uncomment if needed for logout

class AdminSessionSelectionScreen extends StatefulWidget {
  const AdminSessionSelectionScreen({super.key});

  @override
  State<AdminSessionSelectionScreen> createState() =>
      _AdminSessionSelectionScreenState();
}

class _AdminSessionSelectionScreenState
    extends State<AdminSessionSelectionScreen> {
  final _sessionCodeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? _errorMessage;
  bool _isLoading = false;

  @override
  void dispose() {
    _sessionCodeController.dispose();
    super.dispose();
  }

  Future<void> _goToSession() async {
    if (_isLoading || !_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final sessionId = _sessionCodeController.text.trim().toUpperCase();

    // Check if session exists
    final sessionRef = FirebaseDatabase.instance.ref('sessions/$sessionId');
    try {
      final snapshot = await sessionRef.get();
      if (!snapshot.exists) {
        if (mounted) {
          setState(() {
            _errorMessage = 'Session ID "$sessionId" not found.';
            _isLoading = false;
          });
        }
        return;
      }

      // Session exists, navigate to the admin screen for this session
      if (mounted) {
        context.go('/admin/$sessionId');
      }
    } catch (e) {
      //print("Error checking session: $e");
      if (mounted) {
        setState(() {
          _errorMessage = 'An error occurred while checking the session.';
          _isLoading = false;
        });
      }
    }
    // Keep loading indicator if navigation happens, as the screen is replaced.
    // Set loading to false only on error cases handled above.
  }

  // Optional: Add logout functionality here too if needed
  // Future<void> _logout() async { ... }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Session'),
        // actions: [ // Optional Logout Button
        //   IconButton(
        //     icon: const Icon(Icons.logout),
        //     tooltip: 'Logout',
        //     onPressed: _logout, // Define _logout if needed
        //   ),
        // ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(30.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  'Enter the Session ID to manage',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),
                TextFormField(
                  controller: _sessionCodeController,
                  decoration: const InputDecoration(
                    labelText: '8-Digit Session Code',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.tag),
                    counterText: "",
                  ),
                  maxLength: 8,
                  textCapitalization: TextCapitalization.characters,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter the session code';
                    }
                    final trimmedValue = value.trim();
                    if (trimmedValue.length != 8) {
                      return 'Code must be exactly 8 characters';
                    }
                    if (!RegExp(r'^[a-fA-F0-9]{8}$').hasMatch(trimmedValue)) {
                      return 'Code must contain only letters A-F and numbers 0-9';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 30),
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 15.0),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                _isLoading
                    ? const CircularProgressIndicator()
                    : ElevatedButton.icon(
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text('Go to Session'),
                      onPressed: _goToSession,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 30,
                          vertical: 15,
                        ),
                      ),
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
