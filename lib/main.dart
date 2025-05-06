import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Import FirebaseAuth for auth checks
import 'dart:math' as math; // For session ID generation
import 'package:flutter/foundation.dart'; // For kDebugMode
import 'package:url_launcher/url_launcher.dart'; // Import url_launcher

// Import Firebase options
import 'firebase_options.dart';

// Import Screens
import 'screens/projector_screen.dart';
import 'screens/student_screen.dart';
import 'screens/student_join_screen.dart';
import 'screens/admin_login_screen.dart';
import 'screens/admin_session_selection_screen.dart'; // Import the new selection screen
import 'screens/admin_screen.dart';

// --- Global Navigator Key (Optional but can be useful) ---
// final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

// --- Router Setup ---
// Using a function to create the router allows accessing auth state
GoRouter createRouter() {
  final auth = FirebaseAuth.instance;

  return GoRouter(
    // navigatorKey: _navigatorKey, // Assign key if using
    initialLocation: '/', // Start at the mode selection screen
    debugLogDiagnostics: kDebugMode, // Log routing info in debug mode

    // --- Redirect Logic for Auth --- 
    redirect: (BuildContext context, GoRouterState state) {
      final bool loggedIn = auth.currentUser != null;
      final bool loggingIn = state.matchedLocation == '/admin'; // Path for the login screen
      final bool accessingAdminArea = state.matchedLocation.startsWith('/admin/');

      // If not logged in and trying to access any admin path other than login itself, redirect to login
      if (!loggedIn && accessingAdminArea && !loggingIn) {
        return '/admin'; // Redirect to login
      }

      // If logged in and trying to access the login page, redirect to admin session selection
      if (loggedIn && loggingIn) {
        return '/admin/select-session';
      }

      // No redirection needed
      return null;
    },

    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const ModeSelectionScreen(),
      ),
      GoRoute(
        path: '/projector/:sessionId',
        builder: (context, state) {
          final sessionId = state.pathParameters['sessionId'];
          if (sessionId == null) return ErrorScreen(message: 'Missing Session ID for Projector');
          return ProjectorScreen(sessionId: sessionId);
        },
      ),
      GoRoute(
        path: '/student/join',
        builder: (context, state) => StudentJoinScreen(
          sessionIdFromUrl: state.uri.queryParameters['sessionId'],
        ),
      ),
      GoRoute(
        path: '/student/:sessionId',
        builder: (context, state) {
          final sessionId = state.pathParameters['sessionId'];
          if (sessionId == null) return ErrorScreen(message: 'Missing Session ID for Student');
          return StudentScreen(sessionId: sessionId);
        },
      ),
      // --- Admin Routes --- 
      GoRoute(
        path: '/admin', // Login Path
        builder: (context, state) => const AdminLoginScreen(),
      ),
      GoRoute(
        path: '/admin/select-session', // Session Selection Path
        builder: (context, state) {
          // This route is protected by the redirect logic
          return const AdminSessionSelectionScreen();
        },
      ),
      GoRoute(
        path: '/admin/:sessionId', // Admin Control Path
        builder: (context, state) {
          final sessionId = state.pathParameters['sessionId'];
          if (sessionId == null) return ErrorScreen(message: 'Missing Session ID for Admin');
          // This route is also protected by the redirect logic
          return AdminScreen(sessionId: sessionId);
        },
      ),
      // --- Error Route --- 
      GoRoute(
        path: '/error',
        builder: (context, state) => ErrorScreen(message: state.extra as String? ?? 'An unknown error occurred.'),
      ),
    ],
    // Error handler for routes not found
    errorBuilder: (context, state) => ErrorScreen(
      message: 'Page not found: ${state.uri.toString()}',
    ),
  );
}


// --- Main Application Widget ---
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final spaceGroteskTheme = GoogleFonts.spaceGroteskTextTheme(textTheme).apply(
      bodyColor: Colors.white,
      displayColor: Colors.white,
    );

    return MaterialApp.router(
      title: 'ENG 1302 Interactive',
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.cyanAccent,
          brightness: Brightness.dark,
        ),
        textTheme: spaceGroteskTheme,
        useMaterial3: true,
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            textStyle: const TextStyle(fontSize: 16, fontFamily: 'SpaceGrotesk'), // Ensure font here too
          ),
        ),
         inputDecorationTheme: const InputDecorationTheme(
           border: OutlineInputBorder(),
           filled: true,
         ),
         // Corrected: Use CardThemeData instead of CardTheme
         cardTheme: CardThemeData(
           elevation: 2,
           shape: RoundedRectangleBorder(
             borderRadius: BorderRadius.circular(12),
           ),
           margin: const EdgeInsets.symmetric(vertical: 8.0), // Add some default margin if desired
         )
      ),
      routerConfig: createRouter(), // Use the router creation function
      debugShowCheckedModeBanner: false,
    );
  }
}

// --- Initial Mode Selection Screen ---
class ModeSelectionScreen extends StatelessWidget {
  const ModeSelectionScreen({super.key});

  String _generateSessionId() {
    final random = math.Random();
    return random.nextInt(0x100000000).toRadixString(16).padLeft(8, '0').toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Mode'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch, // Make buttons stretch
                  children: <Widget>[
                    ElevatedButton.icon(
                      icon: const Icon(Icons.monitor),
                      label: const Text('Projector Mode'),
                      onPressed: () {
                        final sessionId = _generateSessionId();
                        FirebaseDatabase.instance.ref('sessions').child(sessionId).set({
                          'createdAt': ServerValue.timestamp,
                          'currentStep': 0,
                          'students': {},
                        }).then((_) {
                          // Use context only if widget is still mounted after async gap
                          if (context.mounted) {
                            context.go('/projector/$sessionId');
                          }
                        }).catchError((error) {
                          if (kDebugMode) {
                            print("Error creating session: $error");
                          }
                          // Use context only if widget is still mounted after async gap
                          if (context.mounted) {
                             ScaffoldMessenger.of(context).showSnackBar(
                               const SnackBar(content: Text('Error creating session. Please try again.')),
                             );
                          }
                        });
                      },
                       style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15)),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.school),
                      label: const Text('Student Mode'),
                      onPressed: () {
                        context.go('/student/join');
                      },
                       style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15)),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.admin_panel_settings),
                      label: const Text('Admin Mode'),
                      onPressed: () {
                        context.go('/admin');
                      },
                       style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15)),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
          // --- Project Info Footer ---
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              margin: const EdgeInsets.only(bottom: 18, top: 24),
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.grey[900]?.withOpacity(0.92),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/images/ttu.png',
                        height: 38,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(width: 12),
                      const Text('🇨🇷', style: TextStyle(fontSize: 32)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Proudly Open Source',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () async {
                      final url = Uri.parse('https://github.com/sangaritta/digital_privacy');
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url, mode: LaunchMode.externalApplication);
                      }
                    },
                    child: Text(
                      'github.com/sangaritta/digital_privacy',
                      style: TextStyle(
                        color: Colors.blue.shade200,
                        decoration: TextDecoration.underline,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'A project by Texas Tech University Costa Rica',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white70,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Developed by Sander Garita',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white38,
                          fontStyle: FontStyle.italic,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'MIT License 2025',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.white24,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- Simple Error Screen ---
class ErrorScreen extends StatelessWidget {
  final String message;
  const ErrorScreen({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Error')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
              const SizedBox(height: 16),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => context.go('/'),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
