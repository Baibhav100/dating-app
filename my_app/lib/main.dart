import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import './screens/Welcome.dart'; // Import your Welcome screen
import './screens/Home_screen.dart'; // Import your Home screen
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(); // Initialize Firebase
  await dotenv.load(fileName: ".env"); // Load environment variables
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();

    // Listen for FCM Token Refresh
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('fcm_token', newToken);
      print("Updated FCM Token: $newToken");
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Your App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: FutureBuilder<Widget>(
        future: _getInitialScreen(), // Async function to determine initial screen
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            // Show loading indicator while waiting for the Future to complete
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasData) {
            // Return the screen determined by the Future
            return snapshot.data!;
          }

          // Fallback in case of error or no data
          return WelcomeScreen();
        },
      ),
      routes: {
        '/home': (context) => const HomePage(),
      },
    );
  }

  // Async method to check if the access token exists
  Future<Widget> _getInitialScreen() async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('access_token'); // Retrieve stored token

    // Get FCM token
    String? fcmToken = await FirebaseMessaging.instance.getToken();
    print("FCM Token: $fcmToken");

    // Store FCM token in SharedPreferences
    if (fcmToken != null) {
      await prefs.setString('fcm_token', fcmToken);
    }

    if (accessToken != null && accessToken.isNotEmpty) {
      return const HomePage(); // Navigate to HomePage if token exists
    } else {
      return WelcomeScreen(); // Navigate to WelcomeScreen otherwise
    }
  }
}
