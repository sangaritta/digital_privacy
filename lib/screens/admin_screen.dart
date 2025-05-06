import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:go_router/go_router.dart';
import 'dart:async'; // For StreamSubscription
// import 'package:firebase_auth/firebase_auth.dart'; // Uncomment for logout

class AdminScreen extends StatefulWidget {
  final String sessionId;
  const AdminScreen({super.key, required this.sessionId});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final DatabaseReference _sessionRef = FirebaseDatabase.instance.ref('sessions');
  Map<String, String> _connectedStudents = {};
  int _currentStep = 0;
  StreamSubscription? _studentListener;
  StreamSubscription? _stepListener;
  bool _isLoading = true;
  bool _sessionExists = true; // Assume session exists until checked

  // Define the total number of steps in your presentation (0-based index)
  // This MUST match the steps defined in StudentScreen._buildStepContent
  // UPDATED: Changed from 5 to 10 based on new content
  static const int _totalSteps = 10; 

  @override
  void initState() {
    super.initState();
    _checkSessionExistsAndListen();
  }

  // Checks if the session exists before starting listeners
  Future<void> _checkSessionExistsAndListen() async {
    try {
      final snapshot = await _sessionRef.child(widget.sessionId).get();
      if (!snapshot.exists) {
        if (mounted) {
          setState(() {
            _sessionExists = false;
            _isLoading = false;
          });
        }
        return;
      }
      // Session exists, proceed to listen
      if (mounted) {
         setState(() { _isLoading = false; }); // Stop loading indicator
       _listenForStudents();
       _listenForCurrentStep();
      }
    } catch (e) {
      print("Error checking session existence: $e");
      if (mounted) {
        setState(() {
          _sessionExists = false; // Treat error as session not accessible
          _isLoading = false;
          // Consider showing an error message specific to the failure
        });
      }
    }
  }

  @override
  void dispose() {
    _studentListener?.cancel();
    _stepListener?.cancel();
    super.dispose();
  }

  void _listenForStudents() {
    final studentRef = _sessionRef.child(widget.sessionId).child('students');
    _studentListener = studentRef.onValue.listen((DatabaseEvent event) {
      final data = event.snapshot.value;
      final Map<String, String> updatedStudents = {};
      if (data != null && data is Map) {
        // Iterate through student entries
        data.forEach((key, value) {
          // Check if the student entry is valid and if they are marked as online
          if (value is Map && value.containsKey('nickname') && value.containsKey('isOnline') && value['isOnline'] == true) {
            updatedStudents[key.toString()] = value['nickname'].toString();
          }
        });
      }
      // Update the state only if the widget is still mounted
      if (mounted) {
        setState(() {
          _connectedStudents = updatedStudents;
        });
      }
    }, onError: (error) {
      print("Error listening to students: $error");
      // Optional: Handle error, e.g., clear students list or show a message
      if (mounted) {
         setState(() => _connectedStudents = {}); // Clear list on error
       }
    });
  }

  void _listenForCurrentStep() {
    final stepRef = _sessionRef.child(widget.sessionId).child('currentStep');
    _stepListener = stepRef.onValue.listen((DatabaseEvent event) {
      final step = event.snapshot.value;
      // Update the state if the widget is mounted and the step value is valid
      if (mounted && step is int) {
        setState(() {
          _currentStep = step;
        });
      }
    }, onError: (error) {
      print("Error listening to current step: $error");
      // Optional: Handle error, maybe show a message to the admin
    });
  }

  // Function to update the current step in Firebase
  Future<void> _navigateStep(int delta) async {
    // Calculate the new step, clamping it within the valid range [0, totalSteps - 1]
    final newStep = (_currentStep + delta).clamp(0, _totalSteps - 1); 

    // Only update Firebase if the step has actually changed
    if (newStep != _currentStep) {
      try {
        await _sessionRef.child(widget.sessionId).child('currentStep').set(newStep);
        // The state will update automatically via the _stepListener
      } catch (e) {
        print("Error updating step: $e");
        // Show a snackbar or other feedback if the update fails
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to change step: ${e.toString()}')),
          );
        }
      }
    }
  }

  // --- Logout Functionality ---
  Future<void> _logout() async {
    // --- !!! Implement Real Firebase Logout Here !!! ---
    /*
    try {
      await FirebaseAuth.instance.signOut();
      // Navigate back to the login or initial screen after logout
      if (mounted) {
        context.go('/'); // Go back to mode selection
        // Or context.go('/admin'); // Go back to admin login
      }
    } catch (e) {
      print("Error logging out: $e");
      // Optionally show an error message
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Logout failed: ${e.toString()}')),
         );
      }
    }
    */

    // --- Temporary Logout Simulation ---
    print("Simulating logout...");
    if (mounted) {
      context.go('/'); // Navigate back to the initial mode selection screen
    }
    // --- End Temporary Logout ---
  }

  @override
  Widget build(BuildContext context) {
    // Show loading indicator while checking session status
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text('Admin - Session: ${widget.sessionId}')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Show error message if the session doesn't exist or couldn't be accessed
    if (!_sessionExists) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Padding(
           padding: const EdgeInsets.all(20.0),
           child: Center(
            child: Column(
               mainAxisAlignment: MainAxisAlignment.center,
               children: [
                 const Icon(Icons.error_outline, size: 50, color: Colors.redAccent),
                 const SizedBox(height: 15),
                 const Text(
                   'Session Not Found',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                 ),
                 const SizedBox(height: 10),
                 Text(
                   'Session ID "${widget.sessionId}" does not exist or could not be loaded. Please check the ID and try again.',
                    textAlign: TextAlign.center,
                 ),
                 const SizedBox(height: 20),
                 ElevatedButton(
                    onPressed: () => context.go('/'), // Go back to start
                    child: const Text('Go Back'),
                 )
               ],
            ),
           ),
        ),
      );
    }

    // --- Main Admin UI (if session exists) ---
    return Scaffold(
      appBar: AppBar(
        title: Text('Admin - Session: ${widget.sessionId}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: _logout, // Call the logout function
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // --- Presentation Controls Card ---
            Card(
              elevation: 4, // Add some shadow
              child: Padding(
                padding: const EdgeInsets.all(15.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Presentation Control',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 15),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: <Widget>[
                        // Previous Step Button
                        IconButton.filledTonal(
                          icon: const Icon(Icons.arrow_back_ios_new),
                          tooltip: 'Previous Step',
                          // Disable if already at the first step (0)
                          onPressed: _currentStep == 0 ? null : () => _navigateStep(-1),
                          iconSize: 30,
                        ),
                        // Current Step Display
                        Column(
                          children: [
                            Text(
                              'Step', // Label for the step number
                              style: Theme.of(context).textTheme.labelMedium,
                            ),
                            Text(
                              '${_currentStep + 1}', // Display 1-based step number
                              style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        // Next Step Button
                        IconButton.filledTonal(
                          icon: const Icon(Icons.arrow_forward_ios),
                          tooltip: 'Next Step',
                           // Disable if already at the last step
                           onPressed: _currentStep >= _totalSteps - 1 ? null : () => _navigateStep(1),
                          iconSize: 30,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),
            // --- Connected Students Section ---
            Text(
              'Connected Students (${_connectedStudents.length}):',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: _connectedStudents.isEmpty
                  // Display a message if no students are connected
                  ? const Card(
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.all(20.0),
                          child: Text('No students connected yet.'),
                        ),
                      ),
                    )
                  // Display the list of connected students in a Card
                  : Card(
                      elevation: 2,
                      child: ListView.builder(
                        itemCount: _connectedStudents.length,
                        itemBuilder: (context, index) {
                          final nickname = _connectedStudents.values.elementAt(index);
                          // final studentId = _connectedStudents.keys.elementAt(index); // For debugging
                          return ListTile(
                            leading: const Icon(Icons.person_outline),
                            title: Text(nickname),
                            // subtitle: Text(studentId), // Optional: Show student ID
                            dense: true, // Make list items more compact
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}