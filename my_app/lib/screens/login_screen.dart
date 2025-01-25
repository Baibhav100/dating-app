import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import './Home_screen.dart';
import 'CreateProfile.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}


class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController inputController = TextEditingController();
  bool isEmailLogin = true; // To toggle between email and phone login

  Future<void> sendOtp(String endpoint, String value, BuildContext context) async {
    try {
      final response = await http.post(
        Uri.parse(endpoint),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': value}), // change 'email' here if the API expects it
      );

      if (response.statusCode == 200) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OtpVerificationScreen(value: value),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send OTP: ${response.body}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
 Widget build(BuildContext context) {
  return Scaffold(
    body: Container(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Attractive Heading
                Text(
                  'Login',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Color.fromARGB(255, 204, 22, 92),
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 10),
                
                // Short paragraph
                Text(
                  "Your journey towards seamless authentication starts here. "
                  "Log in using your email or phone number to get started.",
                  style: TextStyle(
                    fontSize: 16,
                    color: Color.fromARGB(255, 44, 44, 44),
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 20),

                // Small image at the top (Replace with your asset path)
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(60), // Ensure it's half of width/height
                  child: Image.asset(
                    'assets/image4.png', // Replace with your image path
                    height: 120, // Adjust size as needed
                    width: 120,
                    fit: BoxFit.cover, // Ensures the image fills the circular shape
                  ),
                ),
              ),
                              SizedBox(height: 40),

                // Toggle buttons for email and phone login
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          isEmailLogin = true;
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isEmailLogin ? Colors.pinkAccent : Colors.grey,
                        foregroundColor: Colors.white, // Text color
                      ),
                      child: Text('Email'),
                    ),
                    SizedBox(width: 20),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          isEmailLogin = false;
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: !isEmailLogin ? Colors.pinkAccent : Colors.grey,
                        foregroundColor: const Color.fromARGB(255, 148, 99, 99), // Text color
                      ),
                      child: Text('Phone'),
                    ),
                  ],
                ),
                SizedBox(height: 20),

                // Input Field (Email or Phone)
                TextField(
                  controller: inputController,
                  keyboardType:
                      isEmailLogin ? TextInputType.emailAddress : TextInputType.phone,
                  style: TextStyle(color: Color.fromARGB(255, 44, 44, 44)), // Text color
                  decoration: InputDecoration(
                    labelText: isEmailLogin ? "Email Address" : "Phone Number",
                    labelStyle: TextStyle(color: Color.fromARGB(255, 204, 22, 92)),
                    prefixIcon: Icon(
                      isEmailLogin ? Icons.email : Icons.phone,
                      color: Color.fromARGB(255, 204, 22, 92),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Color.fromARGB(255, 212, 35, 35)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Color.fromARGB(255, 204, 22, 92)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Color.fromARGB(255, 204, 22, 92)),
                    ),
                  ),
                ),
                SizedBox(height: 20),

                // Login Button 
                ElevatedButton(
                  onPressed: () {
                    print(dotenv.env['BASE_URL']);
                    String baseUrl = dotenv.env['BASE_URL'] ?? 'http://default-url.com';
                    String endpoint = isEmailLogin
                        ? '$baseUrl/auth/send-email-otp/'
                        : '$baseUrl/auth/send-otp/';
                    sendOtp(endpoint, inputController.text, context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color.fromARGB(255, 253, 183, 212),
                    padding: EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    isEmailLogin ? "Login with Email" : "Login with Phone",
                    style: TextStyle(fontSize: 18, color: Color.fromARGB(255, 204, 22, 92)),
                  ),
                ),
                SizedBox(height: 30),

                // Divider
                Row(
                  children: [
                    Expanded(child: Divider(color: Color.fromARGB(255, 204, 22, 92))),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text("OR", style: TextStyle(color: Color.fromARGB(255, 204, 22, 92))),
                    ),
                    Expanded(child: Divider(color: Color.fromARGB(255, 204, 22, 92))),
                  ],
                ),
                SizedBox(height: 30),

                // Social Login Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                   // Google Login Button
                    TextButton.icon(
                      onPressed: () async {
                        try {
                          String baseUrl = dotenv.env['BASE_URL'] ?? 'http://default-url.com';
                          
                          // Trigger Google Sign-In
                          final GoogleSignIn googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);
                          final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

                          if (googleUser == null) {
                            print("Google Sign-In canceled by the user.");
                            return;
                          }

                          print("Google Sign-In successful. Account: ${googleUser.displayName}, Email: ${googleUser.email}");

                          // Obtain authentication details from Google
                          final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

                          // Extract the Google ID Token and Access Token
                          final String? googleIdToken = googleAuth.idToken;
                          final String? googleAccessToken = googleAuth.accessToken;

                          if (googleIdToken == null || googleAccessToken == null) {
                            print("Failed to retrieve Google ID Token or Access Token.");
                            return;
                          }

                          print("Google ID Token: $googleIdToken");

                          // Send Google ID Token to the backend
                          final response = await http.post(
                            Uri.parse('$baseUrl/auth/social-login/'),
                            headers: {"Content-Type": "application/json"},
                            body: json.encode({
                              "provider": "google",
                              "code": googleIdToken, // Use id_token instead of code
                            }),
                          );

                          // Check the response from the backend
                          if (response.statusCode == 200) {

                            final data = json.decode(response.body);

                            if (data.containsKey('access_token') && data.containsKey('refresh_token')) {
                              final accessToken = data['access_token'];
                              final refreshToken = data['refresh_token'];

                              if (accessToken.isNotEmpty && refreshToken.isNotEmpty) {
                                final prefs = await SharedPreferences.getInstance();
                                await prefs.setString('access_token', accessToken);
                                await prefs.setString('refresh_token', refreshToken);

                                // Fetch user details to check if the profile exists
                                final userDetailsResponse = await http.get(
                                  Uri.parse('$baseUrl/auth/my-profile/'),
                                  headers: {
                                    'Content-Type': 'application/json',
                                    'Authorization': 'Bearer $accessToken',
                                  },
                                );

                                print("User details response status: ${userDetailsResponse.statusCode}");

                                if (userDetailsResponse.statusCode == 200) {
                                  // Profile exists
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Login Successful!')),
                                  );
                                  
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => HomePage(
                                        accessToken: accessToken,
                                        refreshToken: refreshToken,
                                      ),
                                    ),
                                  );
                                } else if (userDetailsResponse.statusCode == 404) {
                                  // Profile doesn't exist
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(builder: (context) => CreateProfileScreen(value: googleUser.email)),
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Error fetching user profile: ${userDetailsResponse.body}')),
                                  );
                                }
                              }
                            } else {
                              print("Response does not contain 'access' or 'refresh' token");
                            }
                          } else {
                            print("Login failed: ${response.body}");
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Login failed: ${response.body}')),
                            );
                          }
                        } catch (e) {
                          print("Error during Google Sign-In: $e");
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e')),
                          );
                        }
                      },
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: FaIcon(
                        FontAwesomeIcons.google,
                        color: Color.fromARGB(255, 204, 22, 92),
                        size: 30,
                      ),
                      label: SizedBox.shrink(),
                    ),
                    SizedBox(width: 20),
                    // Facebook Login Button
                    TextButton.icon(
                      onPressed: () {
                        print("Facebook Login Clicked");
                      },
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: FaIcon(
                        FontAwesomeIcons.facebook,
                        color: Color.fromARGB(255, 204, 22, 92),
                        size: 30,
                      ),
                      label: SizedBox.shrink(),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

}

class OtpVerificationScreen extends StatelessWidget {
  final String value; // Email or identifier passed to this screen
  final TextEditingController otpController = TextEditingController();

  OtpVerificationScreen({required this.value});

  Future<void> verifyOtp(BuildContext context) async {
    try {
      String baseUrl = dotenv.env['BASE_URL'] ?? 'http://default-url.com';
      final response = await http.post(
        Uri.parse('$baseUrl/auth/email-otp-login/'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': value, 'otp': otpController.text}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data.containsKey('access') && data.containsKey('refresh')) {
          final accessToken = data['access'];
          final refreshToken = data['refresh'];

          if (accessToken.isNotEmpty && refreshToken.isNotEmpty) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('access_token', accessToken);
            await prefs.setString('refresh_token', refreshToken);

            // Fetch user details to check if the profile exists
            final userDetailsResponse = await http.get(
              Uri.parse('$baseUrl/auth/my-profile/'),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $accessToken',
              },
            );

            if (userDetailsResponse.statusCode == 200) {
              // Profile exists
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Login Successful!')),
              );
              
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => HomePage(
                    accessToken: accessToken,
                    refreshToken: refreshToken,
                  ),
                ),
              );
            } else if (userDetailsResponse.statusCode == 404) {
              // Profile doesn't exist
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => CreateProfileScreen(value: value)),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error fetching user profile: ${userDetailsResponse.body}')),
              );
            }
          }
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invalid OTP: ${response.body}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Verify OTP'),
        backgroundColor: Colors.redAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: 20),
            Text(
              "Enter the OTP sent to your phone or email.",
              style: TextStyle(fontSize: 16, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 40),
            TextField(
              controller: otpController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: "OTP",
                prefixIcon: Icon(Icons.lock, color: Colors.redAccent),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                verifyOtp(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                padding: EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                "Verify OTP",
                style: TextStyle(fontSize: 18, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

