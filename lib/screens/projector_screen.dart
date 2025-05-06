import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart'; // Restored import
import 'package:firebase_database/firebase_database.dart';
import 'dart:async'; // For StreamSubscription
import 'package:flutter/services.dart'; // For Clipboard
// Renamed import prefix for just_audio to avoid conflicts
import 'package:just_audio/just_audio.dart' as ja;
//import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
// Conditional import for fullscreen helpers
import '../web_fullscreen_helper_stub.dart'
  if (dart.library.js) '../web_fullscreen_helper.dart';

class ProjectorScreen extends StatefulWidget {
  final String sessionId;
  const ProjectorScreen({super.key, required this.sessionId});

  @override
  State<ProjectorScreen> createState() => _ProjectorScreenState();
}

class _ProjectorScreenState extends State<ProjectorScreen> {
  final DatabaseReference _sessionRef = FirebaseDatabase.instance.ref(
    "sessions",
  );
  Map<String, String> _connectedStudents = {};
  int _currentStep = 0;
  StreamSubscription? _studentListener;
  StreamSubscription? _stepListener;
  StreamSubscription? _videoControlListener;
  StreamSubscription? _quizAnswersListener;
  StreamSubscription? _bgMusicControlListener;
  StreamSubscription? _fullscreenStateListener;
  StreamSubscription? _quizResultsListener;

  // Audio Player
  late ja.AudioPlayer _audioPlayer;
  final String _audioAssetPath = "assets/audio/background_music.mp3";

  // Video Player
  VideoPlayerController? _videoController;
  Future<void>? _videoInitFuture;
  static const int _videoStep = 2;
  final String _firebaseVideoUrl =
      'https://firebasestorage.googleapis.com/v0/b/matterportal.appspot.com/o/2025-05-06%2000-51-51.mp4?alt=media&token=edcd2f22-8943-470d-b751-49036b0c968f';

  // Quiz Answer State
  Map<int, Map<int, int>> _quizAnswerCounts =
      {}; // questionIndex -> answerIndex -> count
  int _currentQuizQuestionIndex = 0;
  int _currentQuizResultsIndex = 0;

  // --- Fullscreen State ---
  bool _isFullscreen = false;

  // --- Step Titles (match student_screen.dart) ---
  static const List<String> _stepTitles = [
    'Welcome!',
    'The Challenge: Consent Fatigue',
    'Surveillance Capitalism',
    'Real World Impact',
    'Making the Invisible Visible',
    'Your Phone: A Data Sensor',
    'ISPs: Gatekeepers',
    'Taking Control',
    'Tools for Privacy',
    'Human Error & Mindfulness',
    'Quiz',
    'Quiz Results',
  ];

  String _getStepTitle(int step) {
    if (step >= 0 && step < _stepTitles.length) {
      return _stepTitles[step];
    }
    return 'Session';
  }

  void _listenForFullscreenState() {
    final fullscreenRef = _sessionRef.child(widget.sessionId).child("videoControl/fullscreen");
    _fullscreenStateListener = fullscreenRef.onValue.listen(
      (DatabaseEvent event) {
        final value = event.snapshot.value;
        if (mounted && value is bool) {
          if (_isFullscreen != value) {
            setState(() {
              _isFullscreen = value;
            });
          }
        }
      },
      onError: (error) {},
    );
  }

  void _listenForQuizResultsIndex() {
    final quizResultsRef = _sessionRef.child(widget.sessionId).child("quizResults/currentQuestion");
    _quizResultsListener = quizResultsRef.onValue.listen((DatabaseEvent event) {
      final value = event.snapshot.value;
      if (mounted && value is int) {
        setState(() {
          _currentQuizResultsIndex = value;
        });
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _audioPlayer = ja.AudioPlayer();
    _listenForStudents();
    _listenForCurrentStep();
    _listenForQuizAnswers();
    _listenForBgMusicControls();
    _listenForFullscreenState();
    _listenForQuizResultsIndex();
    _listenForVideoControls();
    _initAudioPlayer();
    _initVideoPlayer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    });
  }

  void _handleFullscreenChange(bool fullscreen) {
    if (kIsWeb) {
      if (fullscreen) {
        enterWebFullscreen();
      } else {
        exitWebFullscreen();
      }
    } else {
      SystemChrome.setEnabledSystemUIMode(
        fullscreen ? SystemUiMode.immersive : SystemUiMode.edgeToEdge,
      );
    }
  }

  void _enterWebFullscreen() {}

  void _exitWebFullscreen() {}

  @override
  void didUpdateWidget(covariant ProjectorScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _handleFullscreenChange(_isFullscreen);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _handleFullscreenChange(_isFullscreen);
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

  Future<void> _initVideoPlayer() async {
    _videoController = VideoPlayerController.network(_firebaseVideoUrl);
    _videoInitFuture = _videoController!.initialize().then((_) {
      setState(() {});
    });
  }

  // Listen for quiz answers and update counts for all questions
  void _listenForQuizAnswers() {
    final answersRef = _sessionRef.child(widget.sessionId).child("quizAnswers");
    _quizAnswersListener = answersRef.onValue.listen(
      (DatabaseEvent event) {
        final data = event.snapshot.value;
        Map<int, Map<int, int>> updatedCounts = {};
        if (data != null && data is Map) {
          data.forEach((questionKey, answersForQuestion) {
            if (questionKey is String &&
                questionKey.startsWith("q_") &&
                answersForQuestion is Map) {
              try {
                int questionIndex = int.parse(questionKey.substring(2));
                Map<int, int> countsForThisQuestion = {};
                answersForQuestion.forEach((studentId, answerData) {
                  if (answerData is Map && answerData["answerIndex"] != null) {
                    int? answerIndex =
                        answerData["answerIndex"] is int
                            ? answerData["answerIndex"]
                            : int.tryParse(
                              answerData["answerIndex"].toString(),
                            );
                    if (answerIndex != null) {
                      countsForThisQuestion[answerIndex] =
                          (countsForThisQuestion[answerIndex] ?? 0) + 1;
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
      },
      onError: (error) {
        print("Error listening to quiz answers: $error");
      },
    );
  }

  // Restored _listenForBgMusicControls
  void _listenForBgMusicControls() {
    final musicControlRef = _sessionRef
        .child(widget.sessionId)
        .child("bgMusicControl/state");
    _bgMusicControlListener = musicControlRef.onValue.listen(
      (DatabaseEvent event) {
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
      },
      onError: (error) {
        print("Error listening to background music state: $error");
      },
    );
  }

  void _listenForVideoControls() {
    final videoControlRef = _sessionRef.child(widget.sessionId).child("videoControl");
    _videoControlListener = videoControlRef.onValue.listen(
      (DatabaseEvent event) {
        final data = event.snapshot.value;
        if (data is Map) {
          final String? state = data["state"] as String?;
          if (_videoController != null && state != null) {
            if (state == "playing" && !_videoController!.value.isPlaying) {
              _videoController!.play();
            } else if (state == "paused" && _videoController!.value.isPlaying) {
              _videoController!.pause();
            } else if (state == "reset") {
              _videoController!.seekTo(Duration.zero);
              _videoController!.pause();
            }
          }
        }
      },
      onError: (error) {
        print("Error listening to video control state: $error");
      },
    );
  }

  @override
  void dispose() {
    _studentListener?.cancel();
    _stepListener?.cancel();
    _quizAnswersListener?.cancel();
    _bgMusicControlListener?.cancel();
    _fullscreenStateListener?.cancel();
    _quizResultsListener?.cancel();
    _videoControlListener?.cancel();
    _audioPlayer.dispose();
    _videoController?.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  // Restored _listenForStudents
  void _listenForStudents() {
    final studentRef = _sessionRef.child(widget.sessionId).child("students");
    _studentListener = studentRef.onValue.listen(
      (DatabaseEvent event) {
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
        if (mounted) setState(() => _connectedStudents = updatedStudents);
      },
      onError: (error) {
        print("Error listening to students: $error");
        if (mounted) setState(() => _connectedStudents = {});
      },
    );
  }

  // Restored _listenForCurrentStep
  void _listenForCurrentStep() {
    final stepRef = _sessionRef.child(widget.sessionId).child("currentStep");
    _stepListener = stepRef.onValue.listen(
      (DatabaseEvent event) {
        final step = event.snapshot.value;
        if (mounted && step is int) {
          setState(() => _currentStep = step);
        }
      },
      onError: (error) {
        print("Error listening to current step: $error");
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    bool showVideo = _currentStep == _videoStep && _videoController != null;
    bool showQuizResults = _currentStep == 11; // Results show on step 11
    bool showJoinInfo =
        !showVideo &&
        !showQuizResults &&
        _currentStep != 10; // Show QR unless video, quiz, or results

    return Scaffold(
      appBar: AppBar(
        title: Text(_getStepTitle(_currentStep) + ' - Session: ${widget.sessionId}'),
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
              IconData musicIcon =
                  playing == true ? Icons.music_note : Icons.music_off;
              Color iconColor = playing == true ? Colors.white : Colors.white54;
              return IconButton(
                icon: Icon(musicIcon, color: iconColor),
                tooltip:
                    playing == true
                        ? "Background Music Playing"
                        : "Background Music Paused",
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
            padding: const EdgeInsets.fromLTRB(
              20.0,
              kToolbarHeight + 20,
              20.0,
              20.0,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Left Column: QR
                if (showJoinInfo)
                  Expanded(flex: 2, child: _buildQrCodeColumn(context)),
                if (showJoinInfo) const SizedBox(width: 40),

                // Right Column: Video or Step/Quiz Info
                Expanded(
                  flex: showJoinInfo ? 1 : 3, // Take more space if QR is hidden
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (showVideo)
                        Flexible(
                          flex: 0,
                          child: SizedBox(
                            height: 400, // Adjust as needed for your layout
                            child: _buildFirebaseVideoPlayer(),
                          ),
                        )
                      else
                        Text(
                          _getStepTitle(_currentStep),
                          style: TextStyle(
                            fontSize:
                                (showQuizResults || _currentStep == 10)
                                    ? 48
                                    : 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      const SizedBox(height: 5),
                      // Show step number only for content steps
                      if (!showVideo && !showQuizResults && _currentStep != 10)
                        Text(
                          "Step ${_currentStep + 1} of 11",
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.white70,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      const Divider(color: Colors.white54, height: 40),
                      Flexible(
                        flex: 1,
                        child: showQuizResults
                            ? _buildQuizResultsDisplay()
                            : _buildStudentList(),
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

  Widget _buildQrCodeColumn(BuildContext context) {
    final String joinUrl =
        "${Uri.base.origin}/#/student/join?sessionId=${widget.sessionId}";

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        const Text(
          "Scan QR or Enter Code to Join:",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 25),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.18),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: QrImageView(
            data: joinUrl,
            version: QrVersions.auto,
            size: 280.0, // BIGGER QR
            backgroundColor: Colors.white,
          ),
        ),
        const SizedBox(height: 32),
        // BIG CODE ON SCREEN (SHOW ORIGINAL SESSION ID)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.23),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            widget.sessionId,
            style: const TextStyle(
              fontSize: 68, // BIGGER CODE
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 10,
              fontFamily: "monospace",
            ),
          ),
        ),
        const SizedBox(height: 24),
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
                  const SnackBar(
                    content: Text("Join link copied to clipboard!"),
                  ),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  // Utility to convert sessionId to numeric only (e.g., A1B2C3 -> 123)
  String _getNumericSessionCode(String sessionId) {
    final numeric = sessionId.replaceAll(RegExp(r'[^0-9]'), '');
    // If sessionId is already numeric, return as is; else, fallback to original
    return numeric.isNotEmpty ? numeric : sessionId;
  }

  Widget _buildFirebaseVideoPlayer() {
    if (_videoController == null) {
      return const Center(
        child: Text("Loading Video...", style: TextStyle(color: Colors.white)),
      );
    }
    return FutureBuilder(
      future: _videoInitFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (_isFullscreen) {
          return Stack(
            children: [
              Positioned.fill(
                child: Container(
                  color: Colors.black,
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: _videoController!.value.aspectRatio,
                      child: VideoPlayer(_videoController!),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 24,
                right: 24,
                child: IconButton(
                  icon: const Icon(Icons.fullscreen_exit, color: Colors.white, size: 36),
                  tooltip: "Exit Fullscreen",
                  onPressed: () async {
                    await _sessionRef.child(widget.sessionId).child("videoControl/fullscreen").set(false);
                  },
                ),
              ),
            ],
          );
        }
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onDoubleTap: () async {
                  final newFullscreen = !_isFullscreen;
                  await _sessionRef.child(widget.sessionId).child("videoControl/fullscreen").set(newFullscreen);
                },
                child: Container(
                  color: Colors.black,
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: _videoController!.value.aspectRatio,
                      child: VideoPlayer(_videoController!),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: Icon(_videoController!.value.isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white),
                    onPressed: () {
                      setState(() {
                        _videoController!.value.isPlaying
                            ? _videoController!.pause()
                            : _videoController!.play();
                      });
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.stop, color: Colors.white),
                    onPressed: () {
                      _videoController!.seekTo(Duration.zero);
                      _videoController!.pause();
                      setState(() {});
                    },
                  ),
                  IconButton(
                    icon: Icon(_isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen, color: Colors.white),
                    onPressed: () async {
                      final newFullscreen = !_isFullscreen;
                      await _sessionRef.child(widget.sessionId).child("videoControl/fullscreen").set(newFullscreen);
                    },
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // Restored _buildStudentList
  Widget _buildStudentList() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.people_alt_outlined,
              color: Colors.white,
              size: 22,
            ),
            const SizedBox(width: 8),
            Text(
              "Connected Students (${_connectedStudents.length}):",
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 15),
        Expanded(
          child:
              _connectedStudents.isEmpty
                  ? const Center(
                    child: Text(
                      "No students connected yet.",
                      style: TextStyle(color: Colors.white70),
                    ),
                  )
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
                        final nickname = _connectedStudents.values.elementAt(
                          index,
                        );
                        return ListTile(
                          leading: const Icon(
                            Icons.person_outline,
                            color: Colors.white,
                          ),
                          title: Text(
                            nickname,
                            style: const TextStyle(color: Colors.white),
                          ),
                          dense: true,
                        );
                      },
                    ),
                  ),
        ),
      ],
    );
  }

  // Show quiz results for the current question (real-time, Kahoot style)
  Widget _buildQuizResultsDisplay() {
    final int questionIndex = _currentQuizResultsIndex;
    Map<int, int> answerCounts = _quizAnswerCounts[questionIndex] ?? {};
    int totalVotesForQuestion =
        _connectedStudents.isNotEmpty
            ? answerCounts.values.fold(0, (prev, count) => prev + count)
            : 0; // Avoid division by zero if no students
    final List<Color> optionColors = [
      Colors.red,
      Colors.blue,
      Colors.orange,
      Colors.green,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          "Quiz Results - Question ${questionIndex + 1}",
          style: const TextStyle(
            fontSize: 22,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(4, (index) {
              final count = answerCounts[index] ?? 0;
              final barHeight =
                  totalVotesForQuestion > 0
                      ? (180.0 * count / totalVotesForQuestion).clamp(
                        5.0,
                        180.0,
                      )
                      : 5.0;
              return Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    "$count",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Container(
                    width: 50,
                    height: barHeight,
                    constraints: const BoxConstraints(minHeight: 5),
                    decoration: BoxDecoration(
                      color: optionColors[index % optionColors.length],
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(4),
                        topRight: Radius.circular(4),
                      ),
                    ),
                  ),
                ],
              );
            }),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
              tooltip: "Previous Question",
              onPressed:
                  _currentQuizResultsIndex > 0
                      ? () => setState(() => _currentQuizResultsIndex--)
                      : null,
            ),
            const SizedBox(width: 12),
            Text(
              "Question ${questionIndex + 1}",
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
            const SizedBox(width: 12),
            IconButton(
              icon: const Icon(Icons.arrow_forward_ios, color: Colors.white),
              tooltip: "Next Question",
              onPressed:
                  _quizAnswerCounts.containsKey(_currentQuizResultsIndex + 1)
                      ? () => setState(() => _currentQuizResultsIndex++)
                      : null,
            ),
          ],
        ),
      ],
    );
  }
}
