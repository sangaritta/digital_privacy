import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:async'; // For StreamSubscription
import 'package:flutter/services.dart'; // For Clipboard
import 'package:just_audio/just_audio.dart'; // Import just_audio
import 'package:flutter/foundation.dart'; // For kIsWeb

class ProjectorScreen extends StatefulWidget {
  final String sessionId;
  const ProjectorScreen({super.key, required this.sessionId});

  @override
  State<ProjectorScreen> createState() => _ProjectorScreenState();
}

class _ProjectorScreenState extends State<ProjectorScreen> {
  final DatabaseReference _sessionRef = FirebaseDatabase.instance.ref("sessions");
  Map<String, String> _connectedStudents = {}; // Map of studentId: nickname
  int _currentStep = 0;
  StreamSubscription? _studentListener;
  StreamSubscription? _stepListener;
  late AudioPlayer _audioPlayer; // Declare AudioPlayer

  final String _audioAssetPath = "assets/audio/background_music.mp3";

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _listenForStudents();
    _listenForCurrentStep();
    _initAudioPlayer();
  }

  Future<void> _initAudioPlayer() async {
    try {
      await _audioPlayer.setAsset(_audioAssetPath);
      await _audioPlayer.setLoopMode(LoopMode.one);
      await _audioPlayer.setVolume(0.5);
      _audioPlayer.play();
    } catch (e) {
      print("Error initializing audio player: $e");
    }
  }

  @override
  void dispose() {
    _studentListener?.cancel();
    _stepListener?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _listenForStudents() {
    final studentRef = _sessionRef.child(widget.sessionId).child("students");
    _studentListener = studentRef.onValue.listen((DatabaseEvent event) {
      final data = event.snapshot.value;
      final Map<String, String> updatedStudents = {};
      if (data != null && data is Map) {
        data.forEach((key, value) {
          if (value is Map &&
              value.containsKey("nickname") &&
              value.containsKey("isOnline") &&
              value["isOnline"] == true) {
            updatedStudents[key.toString()] = value["nickname"].toString();
          }
        });
      }
      if (mounted) {
        setState(() {
          _connectedStudents = updatedStudents;
        });
      }
    }, onError: (error) {
      print("Error listening to students: $error");
      if (mounted) {
        setState(() {
          _connectedStudents = {};
        });
      }
    });
  }

  void _listenForCurrentStep() {
    final stepRef = _sessionRef.child(widget.sessionId).child("currentStep");
    _stepListener = stepRef.onValue.listen((DatabaseEvent event) {
      final step = event.snapshot.value;
      if (mounted && step is int) {
        setState(() {
          _currentStep = step;
        });
      }
    }, onError: (error) {
      print("Error listening to current step: $error");
    });
  }

  // Updated to return a specific title for the quiz step
  String _getStepTitle(int step) {
    switch (step) {
      case 0: return "Welcome";
      case 1: return "The Challenge: Consent Fatigue";
      case 2: return "Our Solution: Guided Interaction";
      case 3: return "Making it Persuasive: Rhetoric";
      case 4: return "Technique 1: Stories & Questions";
      case 5: return "Technique 2: Metaphors & Slogans";
      case 6: return "The Quiz: More Than Just Testing";
      case 7: return "Visual Language: Design Matters";
      case 8: return "Visual Language: Making Data Clear";
      case 9: return "Wrap Up & Questions";
      case 10: return "Quiz Time!"; // Title for the active quiz step
      // We might need a step 11 if admin controls when results show
      // case 11: return "Quiz Results"; 
      default: return "Presentation";
    }
  }


  @override
  Widget build(BuildContext context) {
    final String baseUrl = Uri.base.toString();
    final String cleanBaseUrl = baseUrl.endsWith("#/") ? baseUrl.substring(0, baseUrl.length - 2) : (baseUrl.endsWith("/") ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl);
    final String joinUrl = "$cleanBaseUrl/#/student/join?sessionId=${widget.sessionId}";

    return Scaffold(
      appBar: AppBar(
        title: Text("Projector - Session: ${widget.sessionId}"),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [ 
           StreamBuilder<PlayerState>(
             stream: _audioPlayer.playerStateStream,
             builder: (context, snapshot) {
               final playerState = snapshot.data;
               final processingState = playerState?.processingState;
               final playing = playerState?.playing;
               if (processingState == ProcessingState.loading ||
                   processingState == ProcessingState.buffering) {
                 return Container(
                   margin: const EdgeInsets.all(8.0),
                   width: 24.0,
                   height: 24.0,
                   child: const CircularProgressIndicator(color: Colors.white),
                 );
               } else if (playing != true) {
                 return IconButton(
                   icon: const Icon(Icons.play_arrow, color: Colors.white),
                   tooltip: "Play Music",
                   onPressed: _audioPlayer.play,
                 );
               } else if (processingState != ProcessingState.completed) {
                 return IconButton(
                   icon: const Icon(Icons.pause, color: Colors.white),
                   tooltip: "Pause Music",
                   onPressed: _audioPlayer.pause,
                 );
               } else {
                 return IconButton(
                   icon: const Icon(Icons.replay, color: Colors.white),
                    tooltip: "Replay Music",
                   onPressed: () => _audioPlayer.seek(Duration.zero),
                 );
               }
             },
           ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: Container(
         decoration: BoxDecoration(
           gradient: LinearGradient(
             begin: Alignment.topLeft,
             end: Alignment.bottomRight,
             colors: [
               Colors.blue.shade800,
               Colors.blue.shade500,
               Colors.cyan.shade300,
             ],
           ),
         ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20.0, kToolbarHeight + 20, 20.0, 20.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Left Column: QR, Code, URL (Only show if NOT quiz step)
                if (_currentStep != 10)
                  Expanded(
                    flex: 2,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        const Text(
                          "Scan QR or Enter Code to Join:",
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 25),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                spreadRadius: 2,
                                blurRadius: 5,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: QrImageView(
                            data: joinUrl,
                            version: QrVersions.auto,
                            size: MediaQuery.of(context).size.height * 0.3,
                            foregroundColor: Colors.black,
                            errorCorrectionLevel: QrErrorCorrectLevel.M,
                          ),
                        ),
                        const SizedBox(height: 25),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            widget.sessionId,
                            style: const TextStyle(
                              fontSize: 42,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 6,
                              fontFamily: "monospace",
                            ),
                          ),
                        ),
                        const SizedBox(height: 15),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                              Flexible(
                                child: SelectableText(
                                  joinUrl,
                                  style: const TextStyle(fontSize: 14, color: Colors.white70),
                                  textAlign: TextAlign.center,
                              ),
                              ),
                            IconButton(
                              icon: const Icon(Icons.copy, size: 16, color: Colors.white70),
                              tooltip: "Copy Link",
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: joinUrl));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Join link copied to clipboard!")),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                // Spacer (Only show if NOT quiz step)
                if (_currentStep != 10) const SizedBox(width: 40),

                // Right Column: Current Step Title, Student List (or centered Title if quiz step)
                Expanded(
                  // Take full width if it is the quiz step
                  flex: _currentStep == 10 ? 3 : 1, 
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center, 
                    children: [
                       Text(
                         _getStepTitle(_currentStep),
                         style: TextStyle(
                           fontSize: _currentStep == 10 ? 48 : 28, // Larger title for Quiz Time
                           fontWeight: FontWeight.bold,
                           color: Colors.white,
                         ),
                          textAlign: TextAlign.center,
                       ),
                       const SizedBox(height: 5),
                       Text(
                         // Show step number only if not quiz time
                         _currentStep == 10 ? "" : "Step ${_currentStep + 1} of 11", 
                         style: const TextStyle(
                           fontSize: 16,
                           color: Colors.white70,
                          ),
                          textAlign: TextAlign.center,
                        ),

                      const Divider(color: Colors.white54, height: 40),

                       Row(
                         mainAxisAlignment: MainAxisAlignment.center,
                         children: [
                           const Icon(Icons.people_alt_outlined, color: Colors.white, size: 22),
                           const SizedBox(width: 8),
                           Text(
                             "Connected Students (${_connectedStudents.length}):",
                             style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white),
                           ),
                         ],
                       ),
                       const SizedBox(height: 15),
                       Expanded(
                         child: _connectedStudents.isEmpty
                             ? const Center(child: Text("No students connected yet.", style: TextStyle(color: Colors.white70)))
                             : Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                 child: ListView.builder(
                                   padding: const EdgeInsets.symmetric(vertical: 8.0),
                                   shrinkWrap: true,
                                   itemCount: _connectedStudents.length,
                                   itemBuilder: (context, index) {
                                     final nickname = _connectedStudents.values.elementAt(index);
                                     return ListTile(
                                       leading: const Icon(Icons.person_outline, color: Colors.white),
                                       title: Text(nickname, style: const TextStyle(color: Colors.white)),
                                       dense: true,
                                     );
                                   },
                                 ),
                               ),
                       ),
                    ],
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
