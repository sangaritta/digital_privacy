import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:go_router/go_router.dart';
import 'dart:async'; // For StreamSubscription and Timer
// import 'package:firebase_auth/firebase_auth.dart'; // Uncomment for logout

class AdminScreen extends StatefulWidget {
  final String sessionId;
  const AdminScreen({super.key, required this.sessionId});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final DatabaseReference _sessionRef = FirebaseDatabase.instance.ref("sessions");
  Map<String, String> _connectedStudents = {};
  int _currentStep = 0;
  StreamSubscription? _studentListener;
  StreamSubscription? _stepListener;
  bool _isLoading = true;
  bool _sessionExists = true;

  // --- Timer State ---
  Timer? _presentationTimer;
  Duration _elapsedTime = Duration.zero;
  bool _isTimerRunning = false;

  // --- Dialogue State (No internal quotes or apostrophes) ---
  final Map<int, String> _dialogueMap = {
    0: "(Start Intro Music - Low Volume)Good morning. How many of you used your phone before you even got out of bed today? Checked social media? Maybe the news? We live incredible digital lives, connected like never before. But have you ever stopped to think... what is the price of that connection?",
    1: "(Step 1: Consent Fatigue)On your screens now, you will see the term Consent Fatigue. We are constantly bombarded - Accept Cookies, Agree to Terms - Gurses & Del Alamo called it fatigue (2016). We click yes without reading, overwhelmed. But what are we agreeing to?",
    2: "(Step 2: Guided Interaction)The reality is, our clicks, our scrolls, our *lives* online are being turned into profit. It is called Surveillance Capitalism, a term coined by Shoshana Zuboff (2019). My app here is not just showing you text; it is designed to guide you interactively... Social media platforms, device makers, even our internet providers - they are all players in a global data market worth over \$300 Billion *this year*. Lets see a glimpse... (Play Clip 1: The Great Hack)",
    3: "(After Clip 1)Scary, right? That was from The Great Hack, showing the Cambridge Analytica scandal. Billions of data points, harvested, analyzed, and used to influence behaviour. Meta alone makes over \$130 billion a year from ads targeted using *your* data (Tang & Wang, 2018).",
    4: "(Step 3/4: Rhetoric/Stories/Questions)So, how do we make sense of something so vast and often invisible? We use rhetoric. We use stories, questions. Think about it: Would you let a stranger follow you all day, noting every shop you visit...? That sounds absurd, right? But that is essentially what happens online.",
    5: "(Step 5: Metaphors/Slogans)We use metaphors - like data collection being those digital footprints you leave behind. It makes the abstract tangible. And the device in your pocket? It is a powerful sensor. Apple and Google have different approaches... lawsuits show even they collect more than we think. Your phone generates gigs of data daily - location, messages, health insights! Apps often ask for permissions they do not *need* - 43% access mics/cameras unnecessarily (Petryk et al., 2023).",
    6: "(ISP Section)Even your Internet Service Provider - Comcast, AT&T - sees your traffic. Since privacy rules were rolled back, they can legally monitor your browsing... and sell that data (Feld, 2017). Some even offer *discounts* if you let them watch everything you do. Is that really a choice? Privacy becomes a luxury.",
    7: "(Step 6: Quiz Intro / Taking Control - Start Empowerment Music)Okay, that was heavy. But the goal is not to scare you into logging off forever. It is to empower you. This app includes a quiz later to help reflect. But knowledge is only powerful when applied. There ARE things you can do. (Play Clip 2: Privacy 101)",
    8: "(After Clip 2 / VPNs - Step 8 Data Viz)As Naomi Brockwell shows... use privacy-focused browsers... secure messaging apps... Consider a VPN. VPN use is up over 400% since 2019! But be careful - Consumer Reports found many *free* VPNs are insecure. Choose reputable, paid services.",
    9: "(Step 7: Visual Design / Humor)Sometimes, the biggest risks are not giant corporations, but simple mistakes. We reuse passwords, click dodgy links... It can even be funny... (Play Clip 3: TeachPrivacy Funny Fail). Okay, maybe only funny in retrospect. But IBM reported 82% of data breaches involve human error. Being mindful is key.",
    10: "(Step 9: Conclusion - Thoughtful Music)So, why does all this matter? Digital privacy is not about hiding secrets. As Helen Nissenbaum argues, it is about contextual integrity... It is about autonomy... fundamental to a democratic society. We need change at a higher level... But change also starts with us... Use the tools available... Review permissions... Question defaults... Demand better... This app is a starting point. Explore it, reflect... Lets move from consent fatigue to conscious control. Thank you.",
    11: "(Quiz results are being displayed.)",
  };

  // Total steps = 10 content steps (0-9) + 1 quiz step (10)
  static const int _totalSteps = 11;

  @override
  void initState() {
    super.initState();
    _checkSessionExistsAndListen();
  }

  // --- Timer Methods ---
  void _startTimer() {
    if (_isTimerRunning) return;
    _presentationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _elapsedTime = _elapsedTime + const Duration(seconds: 1);
        });
      }
    });
    setState(() {
      _isTimerRunning = true;
    });
  }

  void _stopTimer() {
    if (!_isTimerRunning) return;
    _presentationTimer?.cancel();
    setState(() {
      _isTimerRunning = false;
    });
  }

  void _resetTimer() {
    _presentationTimer?.cancel();
    setState(() {
      _elapsedTime = Duration.zero;
      _isTimerRunning = false;
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$hours:$minutes:$seconds";
  }
  // --- End Timer Methods ---

  Future<void> _checkSessionExistsAndListen() async {
    try {
      final snapshot = await _sessionRef.child(widget.sessionId).get();
      if (!snapshot.exists) {
        if (mounted) setState(() { _sessionExists = false; _isLoading = false; });
        return;
      }
      if (mounted) {
         setState(() { _isLoading = false; });
         _listenForStudents();
         _listenForCurrentStep();
      }
    } catch (e) {
      print("Error checking session existence: $e");
      if (mounted) setState(() { _sessionExists = false; _isLoading = false; });
    }
  }

  @override
  void dispose() {
    _studentListener?.cancel();
    _stepListener?.cancel();
    _presentationTimer?.cancel();
    super.dispose();
  }

  void _listenForStudents() {
    final studentRef = _sessionRef.child(widget.sessionId).child("students");
    _studentListener = studentRef.onValue.listen((DatabaseEvent event) {
      final data = event.snapshot.value;
      final Map<String, String> updatedStudents = {};
      if (data != null && data is Map) {
        data.forEach((key, value) {
          if (value is Map && value.containsKey("nickname") && value.containsKey("isOnline") && value["isOnline"] == true) {
            updatedStudents[key.toString()] = value["nickname"].toString();
          }
        });
      }
      if (mounted) setState(() => _connectedStudents = updatedStudents);
    }, onError: (error) {
      print("Error listening to students: $error");
      if (mounted) setState(() => _connectedStudents = {});
    });
  }

  void _listenForCurrentStep() {
    final stepRef = _sessionRef.child(widget.sessionId).child("currentStep");
    _stepListener = stepRef.onValue.listen((DatabaseEvent event) {
      final step = event.snapshot.value;
      if (mounted && step is int) {
        setState(() => _currentStep = step);
      }
    }, onError: (error) {
      print("Error listening to current step: $error");
    });
  }

  Future<void> _navigateStep(int delta) async {
    final newStep = (_currentStep + delta).clamp(0, _totalSteps - 1);
    if (newStep != _currentStep) {
      try {
        await _sessionRef.child(widget.sessionId).child("currentStep").set(newStep);
      } catch (e) {
        print("Error updating step: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Failed to change step: ${e.toString()}")),
          );
        }
      }
    }
  }

  Future<void> _logout() async {
     _presentationTimer?.cancel();
     if (mounted) context.go("/");
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(appBar: AppBar(title: Text("Admin - Loading...")), body: const Center(child: CircularProgressIndicator()));
    }
    if (!_sessionExists) {
      return Scaffold(appBar: AppBar(title: const Text("Error")), body: Center(child: Text("Session ${widget.sessionId} not found.")));
    }

    final currentDialogue = _dialogueMap[_currentStep] ?? "(No dialogue for this step)";

    return Scaffold(
      appBar: AppBar(
        title: Text("Admin - Session: ${widget.sessionId}"),
        actions: [
          IconButton(icon: const Icon(Icons.logout), tooltip: "Logout", onPressed: _logout),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: <Widget>[
            // --- Timer Card ---
            Card(
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  children: [
                    Text(
                      "Presentation Timer",
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _formatDuration(_elapsedTime),
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontFamily: "monospace",
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton.filledTonal(
                          icon: Icon(_isTimerRunning ? Icons.pause : Icons.play_arrow),
                          tooltip: _isTimerRunning ? "Pause Timer" : "Start Timer",
                          onPressed: _isTimerRunning ? _stopTimer : _startTimer,
                          iconSize: 28,
                        ),
                        IconButton.filledTonal(
                          icon: const Icon(Icons.stop),
                          tooltip: "Stop & Reset Timer",
                          onPressed: _resetTimer,
                          iconSize: 28,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // --- Presentation Controls Card ---
            Card(
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(15.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Presentation Control",
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 15),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: <Widget>[
                        IconButton.filledTonal(
                          icon: const Icon(Icons.arrow_back_ios_new),
                          tooltip: "Previous Step",
                          onPressed: _currentStep == 0 ? null : () => _navigateStep(-1),
                          iconSize: 30,
                        ),
                        Column(
                          children: [
                            const Text("Step"),
                            Text(
                              "${_currentStep + 1}${_currentStep == 10 ? ' (Quiz)' : ' of $_totalSteps'}",
                              style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        IconButton.filledTonal(
                          icon: const Icon(Icons.arrow_forward_ios),
                          tooltip: "Next Step",
                           onPressed: _currentStep >= _totalSteps - 1 ? null : () => _navigateStep(1),
                          iconSize: 30,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // --- Dialogue Card ---
            Card(
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(15.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Presenter Notes (Step ${_currentStep + 1})",
                       style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    SelectableText(
                      currentDialogue,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.4),
                      textAlign: TextAlign.left,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // --- Connected Students Section ---
            Text(
              "Connected Students (${_connectedStudents.length}):",
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            _connectedStudents.isEmpty
              ? const Card(child: Center(child: Padding(padding: EdgeInsets.all(20.0), child: Text("No students connected yet."))))
              : Card(
                  elevation: 2,
                  child: ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _connectedStudents.length,
                    itemBuilder: (context, index) {
                      final nickname = _connectedStudents.values.elementAt(index);
                      return ListTile(
                        leading: const Icon(Icons.person_outline),
                        title: Text(nickname),
                        dense: true,
                      );
                    },
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
