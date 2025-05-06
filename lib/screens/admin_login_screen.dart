import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Import FirebaseAuth
import 'package:flutter/foundation.dart'; // For kDebugMode

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // --- Firebase Authentication Logic --- 
    try {
      // Attempt to sign in
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      
      // User is logged in, navigate to session selection screen
      if (mounted && credential.user != null) {
        context.go('/admin/select-session'); // Navigate to the new selection screen
      } else {
        // Handle unexpected case where user is null after successful sign-in
        if (mounted) {
           setState(() => _errorMessage = 'Login failed unexpectedly after success.');
        }
      }
    } on FirebaseAuthException catch (e) {
      String message;
      // Provide user-friendly messages for common authentication errors
      if (e.code == 'user-not-found' || e.code == 'invalid-email' || e.code == 'invalid-credential') {
        message = 'Invalid email or password.'; // Generic message for security
      } else if (e.code == 'wrong-password') {
        message = 'Invalid email or password.';
      } else {
        // Log the detailed error for debugging, show generic message to user
        message = 'An login error occurred. Please try again.';
        // Use kDebugMode check to only print detailed errors during development
        if (kDebugMode) {
          print("FirebaseAuthException (${e.code}): ${e.message}");
        }
      }
      if (mounted) {
         setState(() => _errorMessage = message);
      }
    } catch (e) {
      // Catch any other unexpected errors during the login process
       if (kDebugMode) {
          print("Login error: $e");
       }
      if (mounted) {
         setState(() => _errorMessage = 'An unexpected error occurred during login.');
      }
    } finally {
      // Ensure loading indicator is always turned off, even if errors occur
      if (mounted) {
         setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Login')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(30.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text('Admin Access', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 30),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty || !value.contains('@')) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock),
                  ),
                  obscureText: true, // Hide password characters
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your password';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 30),
                // Display login error message if present
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 15.0),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                      textAlign: TextAlign.center,
                    ),
                  ),
                // Show loading indicator while logging in, otherwise show button
                _isLoading
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                        onPressed: _login, // Calls the _login function
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15)
                        ),
                        child: const Text('Login', style: TextStyle(fontSize: 16)),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
