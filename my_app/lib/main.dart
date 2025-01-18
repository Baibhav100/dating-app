import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import './screens/Welcome.dart'; // Import your Welcome screen
import './screens/Home_screen.dart'; // Import your Home screen

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Your App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: _getInitialScreen(), // Determine the initial screen

      routes:{
        '/home':(context)=>HomePage(),
      }

    );
  }

  // Use FutureBuilder to handle the async task of checking token
  Widget _getInitialScreen() {
    return FutureBuilder<Widget>(
      future: _getInitialScreenFuture(), // Call the async method
      builder: (context, snapshot) {
        // Check if the Future has completed
        if (snapshot.connectionState == ConnectionState.waiting) {
          // Show a loading indicator while waiting for the Future to complete
          return Center(child: CircularProgressIndicator());
        }

        // If the Future has completed, return the appropriate screen
        if (snapshot.hasData) {
          return snapshot.data!;
        } else {
          // If there's no data or error, return a default screen
          return WelcomeScreen();
        }
      },
    );
  }

  // This function checks if the access token exists
  Future<Widget> _getInitialScreenFuture() async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('access_token'); // Get stored token

    // If the access token is found, return HomePage, else return WelcomeScreen
    if (accessToken != null && accessToken.isNotEmpty) {
      return HomePage(); // Navigate to the Home screen
    } else {
      return WelcomeScreen(); // Navigate to the Welcome screen
    }
  }
}
