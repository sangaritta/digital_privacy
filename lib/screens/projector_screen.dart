import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:async'; // For StreamSubscription

class ProjectorScreen extends StatefulWidget {
  final String sessionId;
  const ProjectorScreen({super.key, required this.sessionId});

  @override
  State<ProjectorScreen> createState() => _ProjectorScreenState();
}

class _ProjectorScreenState extends State<ProjectorScreen> {
  final DatabaseReference _sessionRef = FirebaseDatabase.instance.ref('sessions');
  Map<String, String> _connectedStudents = {}; // Map of studentId: nickname
  StreamSubscription? _studentListener;

  @override
  void initState() {
    super.initState();
    _listenForStudents();
  }

  @override
  void dispose() {
    _studentListener?.cancel();
    super.dispose();
  }

  void _listenForStudents() {
    final studentRef = _sessionRef.child(widget.sessionId).child('students');
    _studentListener = studentRef.onValue.listen((DatabaseEvent event) {
      final data = event.snapshot.value;
      final Map<String, String> updatedStudents = {};
      if (data != null && data is Map) {
        // Firebase Realtime DB often returns Map<Object?, Object?>
        data.forEach((key, value) {
          if (value is Map && value.containsKey('nickname') && value.containsKey('isOnline') && value['isOnline'] == true) {
             // Only add online students
             updatedStudents[key.toString()] = value['nickname'].toString();
          }
        });
      }
      if (mounted) { // Check if the widget is still in the tree
        setState(() {
          _connectedStudents = updatedStudents;
        });
      }
    }, onError: (error) {
      // Handle error
      print("Error listening to students: $error");
      if (mounted) {
        setState(() {
           _connectedStudents = {}; // Clear on error maybe?
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Construct the URL for the QR code
    // Get the current base URL (might need adjustment depending on hosting)
    final String baseUrl = Uri.base.toString();
    // Ensure clean base URL (remove trailing '#' or '/')
    final String cleanBaseUrl = baseUrl.endsWith('#/') ? baseUrl.substring(0, baseUrl.length - 2) : (baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl);
    final String joinUrl = '$cleanBaseUrl/#/student/join?sessionId=${widget.sessionId}';


    return Scaffold(
      appBar: AppBar(
        title: Text('Projector - Session: ${widget.sessionId}'),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Text(
                'Scan QR or Enter Code to Join:',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              // --- QR Code ---
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white, // QR code needs a light background
                  borderRadius: BorderRadius.circular(8),
                ),
                child: QrImageView(
                  data: joinUrl, // The data encoded in the QR code
                  version: QrVersions.auto,
                  size: 250.0,
                   foregroundColor: Colors.black, // Color of the QR code modules
                   errorCorrectionLevel: QrErrorCorrectLevel.L, // Error correction level
                 ),
              ),
              const SizedBox(height: 20),
              // --- Session Code ---
              Text(
                widget.sessionId,
                style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 5, // Add spacing for readability
                ),
              ),
              const SizedBox(height: 30),
              // --- Connected Students ---
              const Text(
                'Connected Students:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: _connectedStudents.isEmpty
                    ? const Text('No students connected yet.')
                    : ListView(
                        shrinkWrap: true,
                        children: _connectedStudents.entries.map((entry) {
                          return ListTile(
                            leading: const Icon(Icons.person_outline),
                            title: Text(entry.value), // Display nickname
                            // subtitle: Text(entry.key), // Optionally display student ID for debugging
                          );
                        }).toList(),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
