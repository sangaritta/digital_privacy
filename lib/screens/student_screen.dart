import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:async'; // For StreamSubscription
import 'package:flutter/foundation.dart'; // For kDebugMode

class StudentScreen extends StatefulWidget {
  final String sessionId;

  const StudentScreen({
    super.key,
    required this.sessionId,
  });

  @override
  State<StudentScreen> createState() => _StudentScreenState();
}

class _StudentScreenState extends State<StudentScreen> {
  final DatabaseReference _sessionRef = FirebaseDatabase.instance.ref('sessions');
  StreamSubscription? _stepListener;
  int _currentStep = 0; // Default to the first step
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _listenForCurrentStep();
    // Note: studentId/nickname are not currently passed or used here.
    // If needed later, they can be retrieved from GoRouter state.extra.
  }

  @override
  void dispose() {
    _stepListener?.cancel();
    // Firebase Realtime Database presence handles marking offline via onDisconnect.
    super.dispose();
  }

  void _listenForCurrentStep() {
    final stepRef = _sessionRef.child(widget.sessionId).child('currentStep');
    _stepListener = stepRef.onValue.listen((DatabaseEvent event) {
      final step = event.snapshot.value;
      if (mounted) { // Check if the widget is still in the tree
        setState(() {
          _currentStep = (step is int) ? step : 0; // Handle potential null/incorrect type
          _isLoading = false; // Mark as loaded once we get the first value
        });
      }
    }, onError: (error) {
      if (kDebugMode) {
         print("Error listening to current step: $error");
      }
      if (mounted) {
        setState(() {
          _isLoading = false; // Stop loading even on error
          // Optionally show an error message to the student within the UI
        });
      }
    });
  }

  // --- Content for Each Step ---
  Widget _buildStepContent(int step) {
    switch (step) {
      case 0: // Welcome
        return _StepContentWidget(
          title: 'Welcome!',
          body: "Waiting for the presentation to begin...",
        );
      case 1: // The Problem: Consent Fatigue
        return _StepContentWidget(
          title: 'The Challenge: Consent Fatigue',
          // Use single quotes for the outer string to avoid conflict with inner double quotes
          body: 'Users are often overwhelmed with information, leading to "consent fatigue" where they click through without understanding (Gurses & Del Alamo, 2016).',
        );
      case 2: // Our Approach: Interactive Engagement
        return _StepContentWidget(
          title: 'Our Solution: Guided Interaction',
          body: "This app uses interactive elements, progressive disclosure, and personalized feedback to make privacy concepts accessible and engaging, addressing common usability hurdles (Consumer Reports, 2024).",
        );
      case 3: // Rhetorical Strategy: Why & How
        return _StepContentWidget(
          title: 'Making it Persuasive: Rhetoric',
          body: "We don't just inform; we persuade using rhetoric. This helps conceptualize abstract data practices, not just learn facts (Zuboff, 2019).",
        );
      case 4: // Rhetorical Devices 1: Stories & Questions
        return _StepContentWidget(
          title: 'Technique 1: Stories & Questions',
          // Use single quotes for the outer string
          body: 'Relatable anecdotes of privacy issues create emotional connection (Chen et al., 2024). Rhetorical questions (e.g., "Who has your location?") prompt reflection.',
        );
      case 5: // Rhetorical Devices 2: Comparisons & Catchphrases
        return _StepContentWidget(
          title: 'Technique 2: Metaphors & Slogans',
          body: "Complex ideas are simplified with metaphors (e.g., data collection as being followed). Catchy phrases act as memorable anchors.",
        );
      case 6: // The Quiz: Reinforcement & Reflection
        return _StepContentWidget(
          title: 'The Quiz: More Than Just Testing',
          // Use single quotes for the outer string
          body: 'The quiz reinforces learning, provides feedback, and encourages reflection on how privacy applies personally, disrupting the "architecture of vulnerability" (Solove, 2008).',
          // interactiveWidget: Placeholder(), // Example placeholder for future quiz widget
        );
      case 7: // Visual Rhetoric: Design Choices
        return _StepContentWidget(
          title: 'Visual Language: Design Matters',
          body: "The visual design uses color (trustworthy blues, warning reds) and clear information structure to guide you and reinforce the message.",
        );
      case 8: // Visual Rhetoric: Data Visualization Example
        return _StepContentWidget(
          title: 'Visual Language: Making Data Clear',
          body: "Abstract stats become understandable. For example, showing the 417% increase in VPN use (GlobalWebIndex, 2024) visually makes the trend obvious.",
          // Example: Could add a static image of a chart here using imageUrl
          // imageUrl: 'path/to/your/chart/image.png',
        );
      case 9: // Conclusion/Q&A
        return _StepContentWidget(
          title: 'Wrap Up & Questions',
          body: "We've covered the key aspects of using interactive and rhetorical techniques for privacy education. Time for questions!",
        );
      default:
        // Fallback for unexpected step numbers
        return Center(
          child: Text('Waiting for content (Step: $step)...'),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Session: ${widget.sessionId}'),
        automaticallyImplyLeading: false, // Don't show back button
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : AnimatedSwitcher( // Animate transitions between steps
              duration: const Duration(milliseconds: 400),
              transitionBuilder: (Widget child, Animation<double> animation) {
                // Fade transition (existing)
                return FadeTransition(opacity: animation, child: child);
              },
              child: Container(
                // Use a Key based on the step to ensure AnimatedSwitcher recognizes the change
                key: ValueKey<int>(_currentStep),
                // Center the content vertically and horizontally
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 30.0),
                child: _buildStepContent(_currentStep),
              ),
            ),
    );
  }
}

// --- Helper Widget for Consistent Step Content Layout ---
class _StepContentWidget extends StatelessWidget {
  final String title;
  final String body;
  final String? imageUrl; // Optional image URL
  final Widget? interactiveWidget; // Optional interactive widget

  const _StepContentWidget({
    required this.title,
    required this.body,
    this.imageUrl,
    this.interactiveWidget,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SingleChildScrollView( // Allow scrolling for longer content
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            title,
            style: textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          if (imageUrl != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 20.0),
              child: Image.network(imageUrl!, height: 150, fit: BoxFit.contain), // Basic image loading
            ),
          Text(
            body,
            style: textTheme.bodyLarge?.copyWith(fontSize: 18),
            textAlign: TextAlign.center,
          ),
          if (interactiveWidget != null)
            Padding(
              padding: const EdgeInsets.only(top: 30.0),
              child: interactiveWidget!,
            ),
        ],
      ),
    );
  }
}
