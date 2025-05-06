import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart'; // Restored import
import 'package:firebase_database/firebase_database.dart';
import 'dart:async'; // For StreamSubscription
import 'package:flutter/services.dart'; // For Clipboard
// Renamed import prefix for just_audio to avoid conflicts
import 'package:just_audio/just_audio.dart' as ja;
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

class ProjectorScreen extends StatefulWidget {
  final String sessionId;
  const ProjectorScreen({super.key, required this.sessionId});

  @override
  State<ProjectorScreen> createState() => _ProjectorScreenState();
}

class _ProjectorScreenState extends State<ProjectorScreen> {
  final DatabaseReference _sessionRef = FirebaseDatabase.instance.ref("sessions");
  Map<String, String> _connectedStudents = {};
  int _currentStep = 0;
  StreamSubscription? _studentListener;
  StreamSubscription? _stepListener;
  StreamSubscription? _videoControlListener;
  StreamSubscription? _quizAnswersListener;
  StreamSubscription? _bgMusicControlListener;

  // Audio Player
  late ja.AudioPlayer _audioPlayer;
  final String _audioAssetPath = "assets/audio/background_music.mp3";

  // YouTube Player
  YoutubePlayerController? _youtubeController;
  bool _isVideoPlayerReady = false;
  static const int _videoStep = 2;

  // Quiz Answer State
  Map<int, Map<int, int>> _quizAnswerCounts = {};

  @override
  void initState() {
    super.initState();
    _audioPlayer = ja.AudioPlayer();
    _listenForStudents();
    _listenForCurrentStep();
    _listenForVideoControls();
    _listenForQuizAnswers();
    _listenForBgMusicControls();
    _initAudioPlayer();
  }

  // Restored _initAudioPlayer
  Future<void> _initAudioPlayer() async {
    try {
      await _audioPlayer.setAsset(_audioAssetPath);
      await _audioPlayer.setLoopMode(ja.LoopMode.one);
      await _audioPlayer.setVolume(0.5);
      // Don't auto-play; wait for command
    } catch (e) {
      // Use print for debugging, consider a logger for production
      print("Error initializing audio player: $e"); 
    }
  }

  // Restored _listenForVideoControls
  void _listenForVideoControls() {
    final videoControlRef = _sessionRef.child(widget.sessionId).child("videoControl");
    _videoControlListener = videoControlRef.onValue.listen((DatabaseEvent event) {
      final controlData = event.snapshot.value;
      if (mounted && controlData is Map) {
        final newState = controlData["state"] as String?;
        final videoId = controlData["videoId"] as String?;

        if (videoId != null && (_youtubeController == null || _youtubeController!.initialVideoId != videoId)) {
          _youtubeController?.dispose();
          _youtubeController = YoutubePlayerController(
            initialVideoId: videoId,
            flags: const YoutubePlayerFlags(autoPlay: false, mute: false, disableDragSeek: true, loop: false, isLive: false, forceHD: false, enableCaption: true),
          )..addListener(_youtubePlayerListener);
          setState(() { _isVideoPlayerReady = false; });
        } else if (_youtubeController != null && newState != null) {
          _controlYoutubePlayer(newState);
        }
      }
    }, onError: (error) {
      print("Error listening to video controls: $error");
    });
  }

  // Restored _youtubePlayerListener
  void _youtubePlayerListener() {
    if (_youtubeController == null) return;
    if (mounted && !_isVideoPlayerReady && _youtubeController!.value.isReady) {
      setState(() { _isVideoPlayerReady = true; });
      _sessionRef.child(widget.sessionId).child("videoControl/state").get().then((snapshot) {
        if (snapshot.exists && snapshot.value is String) {
          _controlYoutubePlayer(snapshot.value as String);
        }
      });
    }
     // Add listener for player state changes to potentially update Firebase 
     // (e.g., mark as ended when video finishes naturally)
     PlayerState currentYoutubeState = _youtubeController!.value.playerState;
     if (currentYoutubeState == PlayerState.ended) {
        _sessionRef.child(widget.sessionId).child("videoControl/state").set("ended");
     } 
     // You could potentially sync other states like 'playing' or 'paused' back to Firebase
     // if needed, but be careful of creating listener loops.
  }

  // Restored _controlYoutubePlayer
  void _controlYoutubePlayer(String firebaseState) {
    if (!_isVideoPlayerReady || _youtubeController == null) return;

    try {
       if (firebaseState == "playing" && !_youtubeController!.value.isPlaying) {
         _youtubeController!.play();
       } else if ((firebaseState == "paused" || firebaseState == "ended") && _youtubeController!.value.isPlaying) {
         _youtubeController!.pause();
       } else if (firebaseState == "reset") {
         _youtubeController!.seekTo(Duration.zero);
         // Set state back to paused in FB after reset is processed
         // Use a timer to ensure seekTo completes before setting state
         Timer(const Duration(milliseconds: 200), () {
           if (mounted) {
             _sessionRef.child(widget.sessionId).child("videoControl/state").set("paused");
           }
         });
       }
    } catch (e) {
       print("Error controlling YouTube player: $e");
    } 
  }

  // Restored _listenForQuizAnswers
  void _listenForQuizAnswers() {
    final answersRef = _sessionRef.child(widget.sessionId).child("quizAnswers");
    _quizAnswersListener = answersRef.onValue.listen((DatabaseEvent event) {
      final data = event.snapshot.value;
      Map<int, Map<int, int>> updatedCounts = {};

      if (data != null && data is Map) {
        data.forEach((questionKey, answersForQuestion) {
          if (questionKey is String && questionKey.startsWith("q_") && answersForQuestion is Map) {
            try {
              int questionIndex = int.parse(questionKey.substring(2));
              Map<int, int> countsForThisQuestion = {};
              answersForQuestion.forEach((studentId, answerData) {
                if (answerData is Map && answerData.containsKey("answerIndex")) {
                  // Ensure answerIndex is treated as int
                  var rawIndex = answerData["answerIndex"];
                  int? answerIndex = (rawIndex is int) ? rawIndex : int.tryParse(rawIndex.toString());
                  if (answerIndex != null) {
                     countsForThisQuestion[answerIndex] = (countsForThisQuestion[answerIndex] ?? 0) + 1;
                  } 
                }
              });
              updatedCounts[questionIndex] = countsForThisQuestion;
            } catch (e) {
              print("Error parsing quiz answer data for $questionKey: $e");
            }
          }
        });
      }

      if (mounted) {
        setState(() {
          _quizAnswerCounts = updatedCounts;
        });
      }
    }, onError: (error) {
      print("Error listening to quiz answers: $error");
    });
  }

  // Restored _listenForBgMusicControls
  void _listenForBgMusicControls() {
    final musicControlRef = _sessionRef.child(widget.sessionId).child("bgMusicControl/state");
    _bgMusicControlListener = musicControlRef.onValue.listen((DatabaseEvent event) {
      final state = event.snapshot.value;
      if (mounted && state is String) {
        try {
           if (state == "playing" && !_audioPlayer.playing) {
             _audioPlayer.play();
           } else if (state == "paused" && _audioPlayer.playing) {
             _audioPlayer.pause();
           }
         } catch (e) {
            print("Error controlling background music: $e");
         }
      }
    }, onError: (error) {
      print("Error listening to background music state: $error");
    });
  }

  @override
  void dispose() {
    _studentListener?.cancel();
    _stepListener?.cancel();
    _videoControlListener?.cancel();
    _quizAnswersListener?.cancel();
    _bgMusicControlListener?.cancel();
    _audioPlayer.dispose();
    _youtubeController?.dispose();
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

  // Restored _getStepTitle (Fixed: Added Step 11 Title)
  String _getStepTitle(int step) {
    switch (step) {
      case 0: return "Welcome";
      case 1: return "The Challenge: Consent Fatigue";
      case 2: return "Surveillance Capitalism";
      case 3: return "Making it Persuasive: Rhetoric";
      case 4: return "Technique 1: Stories & Questions";
      case 5: return "Technique 2: Metaphors & Slogans";
      case 6: return "The Quiz: More Than Just Testing";
      case 7: return "Visual Language: Design Matters";
      case 8: return "Visual Language: Making Data Clear";
      case 9: return "Wrap Up & Questions";
      case 10: return "Quiz Time!";
      case 11: return "Quiz Results"; // Added title for step 11
      default: return "Presentation";
    }
  }

  @override
  Widget build(BuildContext context) {
    bool showVideo = _currentStep == _videoStep && _youtubeController != null;
    bool showQuizResults = _currentStep == 11; // Results show on step 11
    bool showJoinInfo = !showVideo && !showQuizResults && _currentStep != 10; // Show QR unless video, quiz, or results

    return Scaffold(
      appBar: AppBar(
        title: Text("Projector - Session: ${widget.sessionId}"),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          // Using prefixed ja.PlayerState
          StreamBuilder<ja.PlayerState>(
            stream: _audioPlayer.playerStateStream,
            builder: (context, snapshot) {
              final playerState = snapshot.data;
              final playing = playerState?.playing;
              IconData musicIcon = playing == true ? Icons.music_note : Icons.music_off;
              Color iconColor = playing == true ? Colors.white : Colors.white54;
              return IconButton(
                icon: Icon(musicIcon, color: iconColor),
                tooltip: playing == true ? "Background Music Playing" : "Background Music Paused",
                onPressed: null, // Controlled by admin
              );
            },
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [ Colors.blue.shade800, Colors.blue.shade500, Colors.cyan.shade300 ], 
          )
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20.0, kToolbarHeight + 20, 20.0, 20.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Left Column: QR 
                if (showJoinInfo)
                  Expanded( flex: 2, child: _buildQrCodeColumn(context) ),
                if (showJoinInfo) const SizedBox(width: 40),

                // Right Column: Video or Step/Quiz Info
                Expanded(
                  flex: showJoinInfo ? 1 : 3, // Take more space if QR is hidden
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (showVideo)
                        _buildYoutubePlayer()
                      else
                        Text(
                          _getStepTitle(_currentStep),
                          style: TextStyle(fontSize: (showQuizResults || _currentStep == 10) ? 48 : 28, fontWeight: FontWeight.bold, color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                      const SizedBox(height: 5),
                      // Show step number only for content steps
                      if (!showVideo && !showQuizResults && _currentStep != 10) 
                        Text(
                          "Step ${_currentStep + 1} of 11", 
                          style: const TextStyle(fontSize: 16, color: Colors.white70),
                          textAlign: TextAlign.center,
                        ),
                      
                      const Divider(color: Colors.white54, height: 40),

                      // Show Quiz Results OR Student List
                      if (showQuizResults)
                        Expanded(child: _buildQuizResultsDisplay())
                      else
                        Expanded(child: _buildStudentList()),
                    ],
                  ),
                ),
              ],
            ),
          ),
        )
      ),
    );
  }

  // Restored _buildQrCodeColumn
  Widget _buildQrCodeColumn(BuildContext context) {
    final String baseUrl = Uri.base.toString();
    final String cleanBaseUrl = baseUrl.endsWith("#/") ? baseUrl.substring(0, baseUrl.length - 2) : (baseUrl.endsWith("/") ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl);
    final String joinUrl = "$cleanBaseUrl/#/student/join?sessionId=${widget.sessionId}";

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        const Text("Scan QR or Enter Code to Join:", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white), textAlign: TextAlign.center),
        const SizedBox(height: 25),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), spreadRadius: 2, blurRadius: 5, offset: const Offset(0, 3))]),
          child: QrImageView(data: joinUrl, version: QrVersions.auto, size: MediaQuery.of(context).size.height * 0.3, foregroundColor: Colors.black, errorCorrectionLevel: QrErrorCorrectLevel.M),
        ),
        const SizedBox(height: 25),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(color: Colors.black.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
          child: Text(widget.sessionId, style: const TextStyle(fontSize: 42, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 6, fontFamily: "monospace")),
        ),
        const SizedBox(height: 15),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(child: SelectableText(joinUrl, style: const TextStyle(fontSize: 14, color: Colors.white70), textAlign: TextAlign.center)),
            IconButton(icon: const Icon(Icons.copy, size: 16, color: Colors.white70), tooltip: "Copy Link",
              onPressed: () { Clipboard.setData(ClipboardData(text: joinUrl)); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Join link copied to clipboard!"))); },
            ),
          ],
        ),
      ],
    );
  }

  // Restored _buildYoutubePlayer
  Widget _buildYoutubePlayer() {
    if (_youtubeController == null) {
      return const Center(child: Text("Loading Video...", style: TextStyle(color: Colors.white)));
    }
    // Use AspectRatio to control size better within the column
    return AspectRatio(
        aspectRatio: 16 / 9,
        child: YoutubePlayer(
          controller: _youtubeController!,
          showVideoProgressIndicator: true,
          progressIndicatorColor: Colors.amber,
          progressColors: const ProgressBarColors(playedColor: Colors.amber, handleColor: Colors.amberAccent),
          onReady: () { setState(() { _isVideoPlayerReady = true; }); print('Projector YouTube Player is ready.'); },
          onEnded: (data) { _sessionRef.child(widget.sessionId).child("videoControl/state").set("ended"); print("Video Ended"); },
       ),
    );
  }

  // Restored _buildStudentList
  Widget _buildStudentList() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.people_alt_outlined, color: Colors.white, size: 22),
            const SizedBox(width: 8),
            Text("Connected Students (${_connectedStudents.length}):", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white)),
          ],
        ),
        const SizedBox(height: 15),
        Expanded(
          child: _connectedStudents.isEmpty
            ? const Center(child: Text("No students connected yet.", style: TextStyle(color: Colors.white70)))
            : Container(
              decoration: BoxDecoration(color: Colors.black.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
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
    );
  }

  // Restored _buildQuizResultsDisplay
  Widget _buildQuizResultsDisplay() {
    // Display results for the *first* question only for simplicity
    int questionIndexToShow = 0; 
    Map<int, int> answerCounts = _quizAnswerCounts[questionIndexToShow] ?? {};
    int totalVotesForQuestion = _connectedStudents.isNotEmpty 
        ? answerCounts.values.fold(0, (prev, count) => prev + count)
        : 0; // Avoid division by zero if no students
    final List<Color> optionColors = [Colors.red, Colors.blue, Colors.orange, Colors.green];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text("Responses: $totalVotesForQuestion / ${_connectedStudents.length}", style: const TextStyle(fontSize: 18, color: Colors.white70, fontWeight: FontWeight.bold)),
        const SizedBox(height: 25),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(4, (index) { // Assuming 4 options
              int count = answerCounts[index] ?? 0;
               // Calculate bar height relative to max possible height (e.g., 200)
              double proportion = totalVotesForQuestion == 0 ? 0 : (count / totalVotesForQuestion); 
              double maxHeight = 200; // Max height for bars
              double barHeight = proportion * maxHeight + 5; // Add base height 5
              // Clamp height to avoid exceeding max
              barHeight = barHeight.clamp(5, maxHeight + 5).toDouble();

              return Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text("$count", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 5),
                  Container(
                    width: 50, height: barHeight,
                    constraints: const BoxConstraints(minHeight: 5),
                    decoration: BoxDecoration(color: optionColors[index % optionColors.length], borderRadius: const BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(4)))
                  ),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }
}
