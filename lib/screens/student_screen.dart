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
  final DatabaseReference _sessionRef = FirebaseDatabase.instance.ref("sessions");
  StreamSubscription? _stepListener;
  int _currentStep = 0; // Default to the first step
  bool _isLoading = true;

  // --- Quiz State ---
  final PageController _quizPageController = PageController();
  int _currentQuizQuestionIndex = 0;
  List<int?> _selectedAnswers = []; // Store selected answer index for each question
  bool _quizSubmitted = false;
  int _quizScore = 0;

  // Updated Quiz Data based on provided research
  final List<Map<String, dynamic>> _quizQuestions = [
    {
      "question": "According to Zuboff (2019), what is the primary goal of Surveillance Capitalism?", // Removed internal quotes
      "options": [
        "A) To provide free internet access to everyone.",
        "B) To enhance user privacy through encryption.",
        "C) To collect personal data for predicting behavior and generating profit.",
        "D) To regulate online content more effectively."
      ],
      "correctIndex": 2, // Index C
    },
    {
      "question": "What did Gurses & Del Alamo (2016) describe as consent fatigue?", // Removed internal quotes
      "options": [
        "A) The physical tiredness from using digital devices too long.",
        "B) Users agreeing to terms without understanding due to being overwhelmed by requests.",
        "C) A feeling of satisfaction after carefully reading privacy policies.",
        "D) The legal requirement for platforms to get consent multiple times."
      ],
      "correctIndex": 1, // Index B
    },
    {
      "question": "What does Apples App Tracking Transparency (ATT) primarily aim to do?", // Removed apostrophe
      "options": [
        "A) Block all advertisements within apps.",
        "B) Require user consent before apps can track activity across other apps/websites.",
        "C) Automatically encrypt all data stored on the device.",
        "D) Increase the speed of app performance."
      ],
      "correctIndex": 1, // Index B
    },
    {
      "question": "Why can Internet Service Providers (ISPs) pose a significant privacy risk according to the research?",
      "options": [
        "A) They manufacture the devices people use.",
        "B) They can see unencrypted traffic, DNS lookups, and potentially sell browsing data.",
        "C) They primarily rely on selling hardware for profit.",
        "D) They are required by law to delete all user logs daily."
      ],
      "correctIndex": 1, // Index B
    },
    {
      "question": "What technology saw a 417% usage increase since 2019, indicating growing public concern about data handling?",
      "options": [
        "A) Social Media Platforms",
        "B) Smart Home Devices",
        "C) Virtual Private Networks (VPNs)",
        "D) Email Services"
      ],
      "correctIndex": 2, // Index C
    }
  ];

   // Define Kahoot-like colors (Can be customized further)
   final List<Color> _kahootColors = [
     Colors.red,    // Triangle
     Colors.blue,   // Diamond
     Colors.orange, // Circle
     Colors.green,  // Square
   ];
   // Define Kahoot-like icons (Mapping depends on number of options)
   final List<IconData> _kahootIcons = [
     Icons.change_history, // Triangle
     Icons.diamond_outlined, // Diamond
     Icons.circle_outlined, // Circle
     Icons.square_outlined, // Square
   ];

  @override
  void initState() {
    super.initState();
    _selectedAnswers = List<int?>.filled(_quizQuestions.length, null);
    _listenForCurrentStep();
  }

  @override
  void dispose() {
    _stepListener?.cancel();
    _quizPageController.dispose();
    super.dispose();
  }

  void _listenForCurrentStep() {
    final stepRef = _sessionRef.child(widget.sessionId).child("currentStep");
    _stepListener = stepRef.onValue.listen((DatabaseEvent event) {
      final step = event.snapshot.value;
      if (mounted) {
        setState(() {
          _currentStep = (step is int) ? step : 0;
          _isLoading = false;
          if (_currentStep != 10) {
            _quizSubmitted = false;
            _currentQuizQuestionIndex = 0;
            _selectedAnswers = List<int?>.filled(_quizQuestions.length, null);
            _quizScore = 0;
             if (_quizPageController.hasClients) {
               _quizPageController.jumpToPage(0);
             }
          }
        });
      }
    }, onError: (error) {
      if (kDebugMode) print("Error listening to current step: $error");
      if (mounted) setState(() => _isLoading = false);
    });
  }

  void _submitQuiz() {
    _quizScore = 0;
    for (int i = 0; i < _quizQuestions.length; i++) {
      if (_selectedAnswers[i] == _quizQuestions[i]["correctIndex"]) {
        _quizScore++;
      }
    }
    setState(() {
      _quizSubmitted = true;
    });
  }

  Widget _buildStepContent(int step) {
    if (step == 10) {
      return _buildQuizWidget();
    }

    // No internal quotes or apostrophes
    switch (step) {
      case 0: return _StepContentWidget(title: "Welcome!", body: "Waiting for the presentation to begin...");
      case 1: return _StepContentWidget(title: "The Challenge: Consent Fatigue", body: "Users are often overwhelmed with information, leading to consent fatigue where they click through without understanding (Gurses & Del Alamo, 2016).");
      case 2: return _StepContentWidget(title: "Our Solution: Guided Interaction", body: "This app uses interactive elements, progressive disclosure, and personalized feedback to make privacy concepts accessible and engaging, addressing common usability hurdles (Consumer Reports, 2024).");
      case 3: return _StepContentWidget(title: "Making it Persuasive: Rhetoric", body: "We do not just inform; we persuade using rhetoric. This helps conceptualize abstract data practices, not just learn facts (Zuboff, 2019).");
      case 4: return _StepContentWidget(title: "Technique 1: Stories & Questions", body: "Relatable anecdotes of privacy issues create emotional connection (Chen et al., 2024). Rhetorical questions like Who has your location? prompt reflection.");
      case 5: return _StepContentWidget(title: "Technique 2: Metaphors & Slogans", body: "Complex ideas are simplified with metaphors like data collection as being followed. Catchy phrases act as memorable anchors.");
      case 6: return _StepContentWidget(title: "The Quiz: More Than Just Testing", body: "The quiz reinforces learning, provides feedback, and encourages reflection on how privacy applies personally, disrupting the architecture of vulnerability (Solove, 2008).");
      case 7: return _StepContentWidget(title: "Visual Language: Design Matters", body: "The visual design uses color like trustworthy blues and warning reds, and clear information structure to guide you and reinforce the message.");
      case 8: return _StepContentWidget(title: "Visual Language: Making Data Clear", body: "Abstract stats become understandable. For example, showing the 417% increase in VPN use (GlobalWebIndex, 2024) visually makes the trend obvious.");
      case 9: return _StepContentWidget(title: "Wrap Up & Questions", body: "We have covered the key aspects of using interactive and rhetorical techniques for privacy education. Time for questions!");
      default: return Center(child: Text("Waiting for content (Step: $step)..."));
    }
  }

  // Updated Quiz Widget using Buttons
  Widget _buildQuizWidget() {
    if (_quizSubmitted) {
      // Same results screen as before
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            "Quiz Complete!",
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          Text(
            "Your Score: $_quizScore / ${_quizQuestions.length}",
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: _quizScore >= (_quizQuestions.length / 2) ? Colors.greenAccent : Colors.orangeAccent,
            ),
          ),
          const SizedBox(height: 30),
          const Text("Waiting for presentation to conclude...", style: TextStyle(fontStyle: FontStyle.italic)),
        ],
      );
    }

    // Build the quiz interface with PageView and Buttons
    return Column(
      children: [
         Expanded(
           child: PageView.builder(
             controller: _quizPageController,
             physics: const NeverScrollableScrollPhysics(), // Disable swiping
             itemCount: _quizQuestions.length,
             itemBuilder: (context, index) {
               final questionData = _quizQuestions[index];
               final String questionText = questionData["question"];
               final List<String> options = List<String>.from(questionData["options"]);
               bool isAnswerSelected = _selectedAnswers[index] != null;

               return Padding(
                 padding: const EdgeInsets.symmetric(horizontal: 8.0),
                 child: Column(
                   mainAxisAlignment: MainAxisAlignment.center,
                   crossAxisAlignment: CrossAxisAlignment.stretch,
                   children: [
                     Text(
                       "Question ${index + 1} of ${_quizQuestions.length}",
                       style: Theme.of(context).textTheme.titleMedium,
                       textAlign: TextAlign.center,
                     ),
                     const SizedBox(height: 15),
                     Text(
                       questionText,
                       style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w500),
                       textAlign: TextAlign.center,
                     ),
                     const SizedBox(height: 35),
                     // Use a GridView for the Kahoot-style buttons
                     GridView.builder(
                       shrinkWrap: true,
                       physics: const NeverScrollableScrollPhysics(),
                       itemCount: options.length, // Typically 4 for Kahoot
                       gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                         crossAxisCount: 2, // 2 buttons per row
                         childAspectRatio: 2.5, // Adjust aspect ratio for button shape
                         crossAxisSpacing: 15,
                         mainAxisSpacing: 15,
                       ),
                       itemBuilder: (context, optionIndex) {
                          bool isSelected = _selectedAnswers[index] == optionIndex;
                          Color buttonColor = _kahootColors[optionIndex % _kahootColors.length]; // Cycle through colors
                          IconData buttonIcon = _kahootIcons[optionIndex % _kahootIcons.length]; // Cycle through icons

                         return ElevatedButton.icon(
                            icon: Icon(buttonIcon, color: Colors.white), // Icon before text
                            label: Text(
                               options[optionIndex],
                               style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                               textAlign: TextAlign.center,
                             ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: buttonColor,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              // Visual feedback for selection
                              side: isSelected ? const BorderSide(color: Colors.white, width: 3) : null,
                              elevation: isSelected ? 8 : 2,
                            ),
                            onPressed: () {
                              setState(() {
                                _selectedAnswers[index] = optionIndex;
                              });
                              // Optional: Automatically advance after selection (more like Kahoot)
                              // Future.delayed(Duration(milliseconds: 500), () {
                              //   if (_currentQuizQuestionIndex < _quizQuestions.length - 1) {
                              //      _quizPageController.nextPage(duration: Duration(milliseconds: 300), curve: Curves.easeOut);
                              //   }
                              // });
                            },
                          );
                       },
                     ),
                   ],
                 ),
               );
             },
           ),
         ),
         // Navigation/Submit Buttons (Only shown if auto-advance is off)
         Padding(
           padding: const EdgeInsets.only(top: 15.0, bottom: 5.0),
           child: Row(
             mainAxisAlignment: MainAxisAlignment.center, // Center buttons
             children: [
               // Removed Previous Button for simpler flow
               // Show Submit button only on the last question
               if (_currentQuizQuestionIndex == _quizQuestions.length - 1)
                 ElevatedButton.icon(
                   icon: const Icon(Icons.check_circle_outline),
                   label: const Text("Submit Quiz"),
                   style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12)),
                   onPressed: () {
                     if (_selectedAnswers.any((answer) => answer == null)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Please answer all questions before submitting.")),
                        );
                     } else {
                       _submitQuiz();
                     }
                   },
                 )
               else
                 ElevatedButton.icon(
                   icon: const Icon(Icons.arrow_forward_ios),
                   label: const Text("Next Question"),
                   style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12)),
                   // Disable if no answer selected for current question
                   onPressed: _selectedAnswers[_currentQuizQuestionIndex] == null ? null : () {
                     _quizPageController.nextPage(
                       duration: const Duration(milliseconds: 300),
                       curve: Curves.easeOut,
                     );
                   },
                   iconAlignment: IconAlignment.end,
                 ),
             ],
           ),
         ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Session: ${widget.sessionId}"),
        automaticallyImplyLeading: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              transitionBuilder: (Widget child, Animation<double> animation) {
                return FadeTransition(opacity: animation, child: child);
              },
              child: Container(
                key: ValueKey<int>(_currentStep), 
                alignment: Alignment.center,
                // Removed padding here to allow quiz elements more space
                // padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 30.0),
                child: _buildStepContent(_currentStep),
              ),
            ),
    );
  }
}

// Helper Widget
class _StepContentWidget extends StatelessWidget {
  final String title;
  final String body;

  const _StepContentWidget({
    super.key,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    // Add padding back here for non-quiz content
    return SingleChildScrollView(
       padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 30.0),
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
          Text(
            body,
            style: textTheme.bodyLarge?.copyWith(fontSize: 18),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
