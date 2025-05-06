import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:async'; // For StreamSubscription
import 'package:flutter/foundation.dart'
    show kDebugMode; // Explicitly import kDebugMode

// Helper class to store quiz data
class QuizQuestion {
  final String question;
  final List<String> options;
  final int correctIndex;

  QuizQuestion({
    required this.question,
    required this.options,
    required this.correctIndex,
  });
}

class StudentScreen extends StatefulWidget {
  final String sessionId;
  final String? studentId;

  const StudentScreen({super.key, required this.sessionId, this.studentId});

  @override
  State<StudentScreen> createState() => _StudentScreenState();
}

class _StudentScreenState extends State<StudentScreen> {
  final DatabaseReference _sessionRef = FirebaseDatabase.instance.ref(
    "sessions",
  );
  StreamSubscription? _stepListener;
  int _currentStep = 0;
  bool _isLoading = true;
  late String _studentId;

  // --- Quiz State ---
  final PageController _quizPageController = PageController();
  int _currentQuizQuestionIndex = 0;
  List<int?> _selectedAnswers = [];
  bool _quizSubmitted = false; // Used to show final score screen locally
  int _quizScore = 0;

  final List<QuizQuestion> _quizQuestions = [
    QuizQuestion(
      question:
          "According to Zuboff (2019), what is the primary goal of Surveillance Capitalism?",
      options: [
        "A) To provide free internet access to everyone.",
        "B) To enhance user privacy through encryption.",
        "C) To collect personal data for predicting behavior and generating profit.",
        "D) To regulate online content more effectively.",
      ],
      correctIndex: 2,
    ),
    QuizQuestion(
      question:
          "What did Gurses & Del Alamo (2016) describe as consent fatigue?",
      options: [
        "A) The physical tiredness from using digital devices too long.",
        "B) Users agreeing to terms without understanding due to being overwhelmed by requests.",
        "C) A feeling of satisfaction after carefully reading privacy policies.",
        "D) The legal requirement for platforms to get consent multiple times.",
      ],
      correctIndex: 1,
    ),
    QuizQuestion(
      question:
          "What does Apples App Tracking Transparency (ATT) primarily aim to do?",
      options: [
        "A) Block all advertisements within apps.",
        "B) Require user consent before apps can track activity across other apps/websites.",
        "C) Automatically encrypt all data stored on the device.",
        "D) Increase the speed of app performance.",
      ],
      correctIndex: 1,
    ),
    QuizQuestion(
      question:
          "Why can Internet Service Providers (ISPs) pose a significant privacy risk according to the research?",
      options: [
        "A) They manufacture the devices people use.",
        "B) They can see unencrypted traffic, DNS lookups, and potentially sell browsing data.",
        "C) They primarily rely on selling hardware for profit.",
        "D) They are required by law to delete all user logs daily.",
      ],
      correctIndex: 1,
    ),
    QuizQuestion(
      question:
          "What technology saw a 417% usage increase since 2019, indicating growing public concern about data handling?",
      options: [
        "A) Social Media Platforms",
        "B) Smart Home Devices",
        "C) Virtual Private Networks (VPNs)",
        "D) Email Services",
      ],
      correctIndex: 2,
    ),
  ];

  final List<Color> _kahootColors = [
    Colors.red,
    Colors.blue,
    Colors.orange,
    Colors.green,
  ];
  final List<IconData> _kahootIcons = [
    Icons.change_history,
    Icons.diamond_outlined,
    Icons.circle_outlined,
    Icons.square_outlined,
  ];
  final Map<int, IconData> _stepIcons = {
    0: Icons.waving_hand,
    1: Icons.warning_amber_rounded,
    2: Icons.lightbulb_outline,
    3: Icons.campaign_outlined,
    4: Icons.question_answer_outlined,
    5: Icons.fingerprint,
    6: Icons.router_outlined,
    7: Icons.shield_outlined,
    8: Icons.vpn_key_outlined,
    9: Icons.error_outline,
  };

  @override
  void initState() {
    super.initState();
    _studentId =
        widget.studentId ??
        FirebaseDatabase.instance.ref().push().key ??
        "unknown_student_${DateTime.now().millisecondsSinceEpoch}";
    _selectedAnswers = List<int?>.filled(_quizQuestions.length, null);
    _listenForCurrentStep();
  }

  @override
  void dispose() {
    _stepListener?.cancel();
    _quizPageController.dispose();
    super.dispose();
  }

  // Restored _listenForCurrentStep with updated reset logic
  void _listenForCurrentStep() {
    final stepRef = _sessionRef.child(widget.sessionId).child("currentStep");
    _stepListener = stepRef.onValue.listen(
      (DatabaseEvent event) {
        final step = event.snapshot.value;
        if (mounted) {
          int previousStep =
              _currentStep; // Store previous step before updating
          setState(() {
            _currentStep = (step is int) ? step : 0;
            _isLoading = false;

            // Reset quiz ONLY if moving away from step 11 (results) or backwards from step 10/11
            if ((previousStep == 11 && _currentStep != 11) ||
                (_currentStep < 10 &&
                    (previousStep == 10 || previousStep == 11))) {
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
      },
      onError: (error) {
        if (kDebugMode) print("Error listening to current step: $error");
        if (mounted) setState(() => _isLoading = false);
      },
    );
  }

  // Restored _submitAnswer
  void _submitAnswer(int questionIndex, int answerIndex) {
    final answerRef = _sessionRef
        .child(widget.sessionId)
        .child("quizAnswers")
        .child("q_$questionIndex")
        .child(_studentId);
    answerRef
        .set({"answerIndex": answerIndex, "timestamp": ServerValue.timestamp})
        .catchError((error) {
          //print("Error submitting answer: $error");
        });
  }

  // Renamed and restored _calculateFinalScore
  void _calculateFinalScore() {
    _quizScore = 0;
    for (int i = 0; i < _quizQuestions.length; i++) {
      if (_selectedAnswers[i] == _quizQuestions[i].correctIndex) {
        _quizScore++;
      }
    }
    // Mark submitted locally JUST BEFORE showing results on step 11
    // Do not call setState here as build method for step 11 handles it
    _quizSubmitted = true;
  }

  // Restored _buildStepContent with Case 11
  Widget _buildStepContent(int step) {
    IconData? stepIcon = _stepIcons[step];

    switch (step) {
      case 0:
        return _StepContentWidget(
          icon: stepIcon,
          title: "Welcome!",
          body: "Waiting for the presentation to begin...",
        );
      case 1:
        return _StepContentWidget(
          icon: stepIcon,
          title: "The Challenge: Consent Fatigue",
          body: "Users are often overwhelmed with information, leading to consent fatigue where they click through without understanding (Gurses & Del Alamo, 2016).",
        );
      case 2:
        return _StepContentWidget(
          icon: stepIcon,
          title: "Surveillance Capitalism: Your Life as Profit",
          body: "Our clicks, searches, and locations are systematically collected and turned into profit. Professor Zuboff calls this Surveillance Capitalism. Companies use our data for targeting and profit.",
        );
      case 3:
        return _StepContentWidget(
          icon: stepIcon,
          title: "Real World Impact: Cambridge Analytica",
          body: "The Cambridge Analytica scandal showed how billions of data points can be used to predict and influence behavior. Social media companies profit from our data.",
        );
      case 4:
        return _StepContentWidget(
          icon: stepIcon,
          title: "Rhetoric: Making the Invisible Visible",
          body: "Would you want a stranger following you all day, recording everything? That is similar to what happens online. Mental models help us understand the stakes.",
        );
      case 5:
        return _StepContentWidget(
          icon: stepIcon,
          title: "Your Phone: A Powerful Data Sensor",
          body: "Your phone is a collection of sensors. Many apps request permissions they do not need. Is that flashlight app really needing your contacts?",
        );
      case 6:
        return _StepContentWidget(
          icon: stepIcon,
          title: "ISPs: Gatekeepers Watching Your Traffic",
          body: "Internet providers can monitor your browsing and monetize your data. Some offer discounts in exchange for tracking. Is privacy becoming a luxury?",
        );
      case 7:
        return _StepContentWidget(
          icon: stepIcon,
          title: "Taking Control: Knowledge + Action",
          body: "The goal is empowerment, not fear. We cannot just log off, but we can be more informed and intentional. The quiz will reinforce key ideas.",
        );
      case 8:
        return _StepContentWidget(
          icon: stepIcon,
          title: "Tools for Privacy: VPNs & Secure Apps",
          body: "VPN usage has surged. A VPN encrypts your traffic and masks your location. Use reputable services and privacy-respecting browsers and messengers.",
        );
      case 9:
        return _StepContentWidget(
          icon: stepIcon,
          title: "Human Error & Mindfulness",
          body: "Most breaches involve human error. Use strong passwords, be mindful before clicking, and review your privacy settings regularly.",
        );
      case 10:
        return _buildQuizWidget(); // Show quiz questions/buttons
      case 11:
        return _buildQuizResultsScreen(); // Show results
      default:
        return Center(child: Text("Waiting for content (Step: $step)..."));
    }
  }

  // Restored _buildQuizWidget (Removed results part)
  Widget _buildQuizWidget() {
    // Quiz UI remains largely the same, but doesn't show results
    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _quizPageController,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _quizQuestions.length,
            onPageChanged: (index) {
              setState(() => _currentQuizQuestionIndex = index);
            },
            itemBuilder: (context, index) {
              final questionData = _quizQuestions[index];
              final String questionText = questionData.question;
              final List<String> options = questionData.options;

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
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 35),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: options.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 2.5,
                            crossAxisSpacing: 15,
                            mainAxisSpacing: 15,
                          ),
                      itemBuilder: (context, optionIndex) {
                        bool isSelected =
                            _selectedAnswers[index] == optionIndex;
                        Color buttonColor =
                            _kahootColors[optionIndex % _kahootColors.length];
                        IconData buttonIcon =
                            _kahootIcons[optionIndex % _kahootIcons.length];

                        return ElevatedButton.icon(
                          icon: Icon(buttonIcon, color: Colors.white),
                          label: Text(
                            options[optionIndex],
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: buttonColor,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            side:
                                isSelected
                                    ? const BorderSide(
                                      color: Colors.white,
                                      width: 3,
                                    )
                                    : null,
                            elevation: isSelected ? 8 : 2,
                          ),
                          onPressed: () {
                            setState(() {
                              _selectedAnswers[index] = optionIndex;
                            });
                            _submitAnswer(index, optionIndex);
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
        Padding(
          padding: const EdgeInsets.only(top: 15.0, bottom: 5.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_currentQuizQuestionIndex < _quizQuestions.length - 1)
                ElevatedButton.icon(
                  icon: const Icon(Icons.arrow_forward_ios),
                  label: const Text("Next Question"),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 30,
                      vertical: 12,
                    ),
                  ),
                  onPressed:
                      _selectedAnswers[_currentQuizQuestionIndex] == null
                          ? null
                          : () {
                            _quizPageController.nextPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOut,
                            );
                          },
                  iconAlignment: IconAlignment.end,
                )
              else // On the last question
                Padding(
                  // Add padding to show instruction
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: Text(
                    _selectedAnswers[_currentQuizQuestionIndex] == null
                        ? "Select your answer."
                        : "Waiting for admin to show results...",
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // Restored _buildQuizResultsScreen
  Widget _buildQuizResultsScreen() {
    if (!_quizSubmitted) {
      _calculateFinalScore();
    }
    // Show each question, student's answer, and highlight correct answer
    return ListView.builder(
      itemCount: _quizQuestions.length,
      itemBuilder: (context, index) {
        final question = _quizQuestions[index];
        final selected = _selectedAnswers[index];
        final isCorrect = selected == question.correctIndex;
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Question ${index + 1}: ${question.question}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...List.generate(question.options.length, (optIdx) {
                  final isStudentAnswer = selected == optIdx;
                  final isValid = question.correctIndex == optIdx;
                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    decoration: BoxDecoration(
                      color: isValid
                        ? Colors.green.withOpacity(0.2)
                        : isStudentAnswer
                          ? Colors.orange.withOpacity(0.2)
                          : null,
                      borderRadius: BorderRadius.circular(6),
                      border: isValid
                        ? Border.all(color: Colors.green, width: 2)
                        : isStudentAnswer
                          ? Border.all(color: Colors.orange, width: 2)
                          : null,
                    ),
                    child: ListTile(
                      title: Text(question.options[optIdx]),
                      leading: isValid
                        ? const Icon(Icons.check, color: Colors.green)
                        : isStudentAnswer
                          ? const Icon(Icons.close, color: Colors.orange)
                          : null,
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Session: ${widget.sessionId}"),
        automaticallyImplyLeading: false,
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return FadeTransition(opacity: animation, child: child);
                },
                child: Container(
                  key: ValueKey<int>(_currentStep),
                  alignment: Alignment.center,
                  child: _buildStepContent(_currentStep),
                ),
              ),
    );
  }
}

// Restored _StepContentWidget build method
class _StepContentWidget extends StatelessWidget {
  final String title;
  final String body;
  final IconData? icon;

  const _StepContentWidget({
    super.key,
    required this.title,
    required this.body,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 30.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (icon != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 20.0),
              child: Icon(
                icon,
                size: 60,
                color: Theme.of(context).colorScheme.secondary,
              ),
            ),
          Text(
            title,
            style: textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
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
