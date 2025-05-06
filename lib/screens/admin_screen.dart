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
  StreamSubscription? _videoStateListener;
  StreamSubscription? _bgMusicStateListener; // Listener for background music state
  bool _isLoading = true;
  bool _sessionExists = true;

  // --- Timer State ---
  Timer? _presentationTimer;
  Duration _elapsedTime = Duration.zero;
  bool _isTimerRunning = false;

  // --- Video Control State ---
  String _videoPlayerState = "paused";
  static const String _videoId = "OKDMIbG9uZU";
  static const int _videoStep = 2;
  
  // --- Background Music State ---
  String _bgMusicState = "paused"; // "playing", "paused"

  // --- Key Points ---
  final Map<int, String> _keyPointsMap = {
     0: "Welcome & Hook: The Price of Connection", 1: "The Problem: Consent Fatigue & Data Overload", 2: "Surveillance Capitalism: Your Life as Profit", 3: "Real World Impact: Cambridge Analytica", 4: "Rhetoric: Making the Invisible Visible (Stories & Questions)", 5: "Your Phone: A Powerful Data Sensor (Metaphors)", 6: "ISPs: Gatekeepers Watching Your Traffic (Kolbi, Claro, Liberty...)", 7: "Taking Control: Knowledge + Action (Quiz Intro)", 8: "Tools for Privacy: VPNs & Secure Apps", 9: "Human Error & Mindfulness", 10: "Conclusion: Privacy as Autonomy & Call to Action", 11: "Quiz Results",
  };

  // --- Dialogue State (No internal quotes/apostrophes) ---
  final Map<int, String> _dialogueMap = {
     0: "(Start Intro Music - Low Volume) Good morning. Think about this morning: how many of you checked your phone almost immediately? Maybe social media, news, messages? We are woven into this amazing digital world, more connected than ever. But have we paused to truly consider the cost of that constant connection? What are we trading for this convenience?", 1: "(Step 1: Consent Fatigue) On your screens, you see the term Consent Fatigue. We face a daily barrage - Accept Cookies, Agree to Terms. It is overwhelming, right? Gurses and Del Alamo identified this back in 2016. We click yes, yes, yes, just to get to the content, often without really knowing what permissions we just granted. What hidden agreements are buried in that text?", 2: "(Step 2: Surveillance Capitalism Intro + VIDEO TRIGGER) Here is the stark reality: our clicks, scrolls, searches, even our locations - our digital lives - are being systematically collected and turned into profit. Professor Shoshana Zuboff calls this Surveillance Capitalism. It is a new economic logic where your personal experiences are the raw material. My app tries to make this tangible, unlike dense policies. But the scale is massive. Social media, device makers, internet providers - they are part of a global data market worth hundreds of billions. Words cannot fully capture it, so lets see a glimpse of how this engine works. (Trigger Video Play)", 3: "(After Video Ends) That clip, from The Great Hack, gives a sense of the industrial scale of data collection, centered on the Cambridge Analytica scandal. Billions of data points, harvested, analyzed, used not just for ads, but to predict and even influence our behavior. Think about Meta (Facebook/Instagram) - making over 130 billion dollars a year. That revenue comes directly from their ability to profile and target *us*, using *our* data (Tang & Wang, 2018). It raises profound questions about influence and autonomy.", 4: "(Step 4: Rhetoric - Making Invisible Visible) How do we grasp something so pervasive yet often invisible? We use the power of rhetoric - making concepts relatable. Think about this analogy: Would you be comfortable with a stranger following you all day, recording every shop you enter, every conversation you have, every book you browse? Of course not! It feels invasive, creepy. Yet, metaphorically, that is startlingly close to what happens in our digital lives. We need these mental models to understand the stakes.", 5: "(Step 5: The Phone as Sensor) And the device we carry everywhere? Your smartphone is less a phone and more a sophisticated collection of sensors. Seventeen or more, according to Tang and Wang, constantly generating data - where you go (GPS, Wi-Fi), who you talk to (call logs), even *how* you move (accelerometer). While companies like Apple and Google present different privacy stances - remember App Tracking Transparency? - lawsuits and research reveal vast amounts of data are still collected. Worse, many apps request permissions they absolutely do not need for their core function - over 40% according to one study (Petryk et al., 2023)! Is that flashlight app *really* needing access to your contacts?", 6: "(Step 6: ISPs - The Local Angle) Even the companies providing our internet access - think Kolbi, Claro, Liberty, Metrocom, Telecable - are positioned as critical gatekeepers. They see the raw traffic flowing to and from your home. Since regulations like Net Neutrality have weakened in places, ISPs have gained more power to monitor your browsing habits, analyze your DNS requests (the phonebook of the internet), and yes, monetize that information (Feld, 2017). Some even dangle discounts - lower your bill, but let us track everything you do online. Is that a fair trade? Is privacy becoming a luxury item only some can afford?", 7: "(Step 7: Taking Control - Empowerment) Okay, this can feel overwhelming, maybe even a bit dystopian. But the goal here is not fear, it is *empowerment*. We cannot just log off, but we *can* become more informed and intentional. Later, the quiz in this app will help reinforce some key ideas. Knowledge must lead to action. There are concrete steps we can take. (Dialogue now focuses on solutions)", 8: "(Step 8: Tools for Privacy - VPNs etc.) There are tools designed to shield us. Consider Virtual Private Networks, or VPNs. Their usage has surged over 400% recently (GlobalWebIndex, 2024), showing people *are* concerned! A VPN encrypts your traffic and masks your location, making it harder for ISPs and websites to track you. But beware: Consumer Reports found many *free* VPNs have flaws. Invest in a reputable, audited service. Also explore privacy-respecting browsers like DuckDuckGo or Brave, and secure messaging apps like Signal.", 9: "(Step 9: Human Element - Mistakes & Mindfulness) Beyond corporate surveillance, sometimes the biggest risks come from our own habits. Reusing passwords, clicking on suspicious links, oversharing on public profiles... We have all done it. IBMs research highlights a staggering statistic: 82% of data breaches involve a human element (IBM Security, 2023). While we cannot be perfect, developing digital mindfulness - pausing before clicking, reviewing settings periodically, using strong, unique passwords - makes a huge difference.", 10: "(Step 10: Conclusion - Why It Matters) So, why is this fight for digital privacy so crucial? It is not merely about hiding embarrassing photos. As philosopher Helen Nissenbaum argues, it is about contextual integrity - information flowing appropriately according to social norms. It is about autonomy, the ability to think, explore, and connect without fear of constant monitoring or manipulation (Solove, 2008; Zuboff, 2019). This is fundamental for individual freedom and a healthy democracy. We need systemic change - better regulations, more transparency like Europes Data Governance Act. But change also begins with individual awareness and action. Use the tools. Question the defaults. Demand better. Lets transform consent fatigue into conscious digital citizenship. Thank you.", 11: "(Quiz results are being displayed.)",
  };

  static const int _totalSteps = 11;

  @override
  void initState() {
    super.initState();
    _checkSessionExistsAndListen();
    _listenForVideoState();
    _listenForBgMusicState();
  }

  // --- Timer Methods (Restored Full Implementation) ---
  void _startTimer() { 
    if (_isTimerRunning) return;
    _presentationTimer = Timer.periodic(const Duration(seconds: 1), (timer) { 
      if (mounted) { 
        setState(() => _elapsedTime += const Duration(seconds: 1)); 
      }
    }); 
    setState(() => _isTimerRunning = true); 
  }
  void _stopTimer() { 
    if (!_isTimerRunning) return;
    _presentationTimer?.cancel(); 
    setState(() => _isTimerRunning = false); 
  }
  void _resetTimer() { 
    _presentationTimer?.cancel(); 
    setState(() { _elapsedTime = Duration.zero; _isTimerRunning = false; });
  }
  String _formatDuration(Duration duration) { 
    String twoDigits(int n) => n.toString().padLeft(2, "0"); 
    final hours = twoDigits(duration.inHours); 
    final minutes = twoDigits(duration.inMinutes.remainder(60)); 
    final seconds = twoDigits(duration.inSeconds.remainder(60)); 
    return "$hours:$minutes:$seconds"; 
  }

  // --- Video Control Methods (Restored Full Implementation) ---
  Future<void> _setVideoState(String newState) async {
    try {
       await _sessionRef.child(widget.sessionId).child("videoControl").set({
         "videoId": _videoId,
         "state": newState,
         "timestamp": ServerValue.timestamp,
       });
    } catch (e) {
       if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error controlling video: $e")));
       }
    }
  }
  
  void _listenForVideoState() {
     final videoControlRef = _sessionRef.child(widget.sessionId).child("videoControl/state");
     _videoStateListener = videoControlRef.onValue.listen((DatabaseEvent event) {
       final state = event.snapshot.value;
       if (mounted && state is String) {
          setState(() { _videoPlayerState = state; });
       }
     }, onError: (error) {
       print("Error listening to video state: $error");
     });
  }

  // --- Background Music Control Methods (Restored Full Implementation) ---
  Future<void> _setBgMusicState(String newState) async {
    try {
      await _sessionRef.child(widget.sessionId).child("bgMusicControl").set({
        "state": newState, // playing, paused
        "timestamp": ServerValue.timestamp,
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error controlling music: $e")));
      }
    }
  }
  
   void _listenForBgMusicState() {
     final musicControlRef = _sessionRef.child(widget.sessionId).child("bgMusicControl/state");
     _bgMusicStateListener = musicControlRef.onValue.listen((DatabaseEvent event) {
       final state = event.snapshot.value;
       if (mounted && state is String) {
          setState(() { _bgMusicState = state; });
       }
     }, onError: (error) {
       print("Error listening to music state: $error");
     });
  }

  // --- End Media Control Methods ---

  // Restored _checkSessionExistsAndListen
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
         // Fetch initial music state (Important to sync UI on load)
         _sessionRef.child(widget.sessionId).child("bgMusicControl/state").get().then((snapshot) {
            if(mounted && snapshot.exists && snapshot.value is String) {
               setState(() { _bgMusicState = snapshot.value as String; });
            }
         });
          // Fetch initial video state (Important to sync UI on load)
         _sessionRef.child(widget.sessionId).child("videoControl/state").get().then((snapshot) {
            if(mounted && snapshot.exists && snapshot.value is String) {
               setState(() { _videoPlayerState = snapshot.value as String; });
            }
         });
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
    _videoStateListener?.cancel();
    _bgMusicStateListener?.cancel(); 
    super.dispose();
  }

  // Restored _listenForStudents
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

  // Restored _listenForCurrentStep
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

  // Restored _navigateStep
  Future<void> _navigateStep(int delta) async {
     final newStep = (_currentStep + delta).clamp(0, _totalSteps - 1);
    if (newStep != _currentStep) {
      try {
        if (_currentStep == _videoStep && newStep != _videoStep) {
           await _setVideoState("reset"); 
        }
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

  // Restored _logout
  Future<void> _logout() async {
     _presentationTimer?.cancel();
     // Reset states on logout to avoid carrying over to next session
     await _setVideoState("reset"); 
     await _setBgMusicState("paused"); 
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
    final currentKeyPoint = _keyPointsMap[_currentStep] ?? " ";
    final bool showVideoControls = _currentStep == _videoStep;

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
            // --- Timer Card (Restored) ---
            Card(
               elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  children: [
                    Text( "Presentation Timer", style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text( _formatDuration(_elapsedTime), style: Theme.of(context).textTheme.headlineMedium?.copyWith( fontWeight: FontWeight.bold, fontFamily: "monospace") ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton.filledTonal( icon: Icon(_isTimerRunning ? Icons.pause : Icons.play_arrow), tooltip: _isTimerRunning ? "Pause Timer" : "Start Timer", onPressed: _isTimerRunning ? _stopTimer : _startTimer, iconSize: 28),
                        IconButton.filledTonal( icon: const Icon(Icons.stop), tooltip: "Stop & Reset Timer", onPressed: _resetTimer, iconSize: 28 ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            
             // --- Media Controls Card (Added Bg Music Controls) ---
             Card(
               elevation: 3,
               child: Padding(
                 padding: const EdgeInsets.all(12.0),
                 child: Column(
                   children: [
                     Text( "Media Controls", style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold) ),
                     const SizedBox(height: 8),
                     Row(
                       mainAxisAlignment: MainAxisAlignment.spaceAround,
                       children: [
                          // Background Music Controls
                          Column(
                            children: [
                               const Text("Music", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                               Row(
                                 children: [
                                    IconButton.filledTonal( icon: const Icon(Icons.play_arrow), tooltip: "Play Music", onPressed: _bgMusicState == "playing" ? null : () => _setBgMusicState("playing"), iconSize: 28),
                                    const SizedBox(width: 8),
                                    IconButton.filledTonal( icon: const Icon(Icons.pause), tooltip: "Pause Music", onPressed: _bgMusicState != "playing" ? null : () => _setBgMusicState("paused"), iconSize: 28),
                                 ],
                               )
                            ],
                          ),
                          // Video Controls 
                          Column(
                             children: [
                               Text("Video", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: showVideoControls ? null : Colors.grey)),
                               Row(
                                 children: [
                                    IconButton.filledTonal( icon: const Icon(Icons.play_arrow), tooltip: "Play Video", onPressed: !showVideoControls || _videoPlayerState == "playing" ? null : () => _setVideoState("playing"), iconSize: 28),
                                    const SizedBox(width: 8),
                                    IconButton.filledTonal( icon: const Icon(Icons.pause), tooltip: "Pause Video", onPressed: !showVideoControls || _videoPlayerState != "playing" ? null : () => _setVideoState("paused"), iconSize: 28),
                                    const SizedBox(width: 8),
                                    IconButton.filledTonal( icon: const Icon(Icons.replay), tooltip: "Reset Video", onPressed: !showVideoControls ? null : () => _setVideoState("reset"), iconSize: 28),
                                 ],
                               )
                            ],
                          ),
                       ],
                     ),
                   ]
                 ),
               ),
             ),
            const SizedBox(height: 20),

            // --- Presentation Controls Card (Restored) ---
            Card(
               elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(15.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text( "Presentation Control", style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold) ),
                    const SizedBox(height: 15),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: <Widget>[
                        IconButton.filledTonal( icon: const Icon(Icons.arrow_back_ios_new), tooltip: "Previous Step", onPressed: _currentStep == 0 ? null : () => _navigateStep(-1), iconSize: 30),
                        Column(
                          children: [
                            const Text("Step"),
                            Text( "${_currentStep + 1}${_currentStep == 10 ? ' (Quiz)' : ' of $_totalSteps'}", style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold) ),
                          ],
                        ),
                        IconButton.filledTonal( icon: const Icon(Icons.arrow_forward_ios), tooltip: "Next Step", onPressed: _currentStep >= _totalSteps - 1 ? null : () => _navigateStep(1), iconSize: 30),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            
            // --- Dialogue Card (Restored) ---
            Card(
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(15.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                     Text( "Step ${_currentStep + 1}: $currentKeyPoint", style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold) ),
                    const Divider(height: 20, thickness: 1), 
                    Text( "Full Notes:", style: Theme.of(context).textTheme.titleSmall?.copyWith(fontStyle: FontStyle.italic) ),
                    const SizedBox(height: 5),
                    SelectableText( currentDialogue, style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.4), textAlign: TextAlign.left ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // --- Connected Students Section (Restored) ---
             Text( "Connected Students (${_connectedStudents.length}):", style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold) ),
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
                      return ListTile( leading: const Icon(Icons.person_outline), title: Text(nickname), dense: true );
                    },
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
