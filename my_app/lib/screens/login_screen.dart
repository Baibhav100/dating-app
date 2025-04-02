import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import './Home_screen.dart';
import 'CreateProfile.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:fluttertoast/fluttertoast.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool isEmailLogin = true; // To toggle between email and phone login

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          color: const Color.fromARGB(255, 223, 203, 211) // Use a single color for the background
        ),
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
                      color: Color.fromARGB(255, 255, 255, 255),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 10),

                  // Short paragraph
                  // Text(
                  //   "Your journey towards seamless authentication starts here. "
                  //   "Log in using your email or phone number to get started.",
                  //   style: TextStyle(
                  //     fontSize: 16,
                  //     color: Color.fromARGB(255, 241, 240, 240),
                  //   ),
                  //   textAlign: TextAlign.center,
                  // ),
                  SizedBox(height: 20),

                  // Toggle buttons for email and phone login
                    Column(
                    children: [
                      SizedBox(
                      width: double.infinity, // Make the button width to fill the device width
                      child: ElevatedButton(
                        onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => EmailLoginScreen()),
                        );
                        },
                        style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromARGB(255, 216, 57, 96),
                       foregroundColor: const Color.fromARGB(255, 255, 255, 255), // Text color
                        padding: EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        ),
                        child: Text(
                        'Login with Email',
                        style: TextStyle(fontSize: 18),
                        ),
                      ),
                      ),
                      SizedBox(height: 20),
                      SizedBox(
                      width: double.infinity, // Make the button width to fill the device width
                      child: ElevatedButton(
                        onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => PhoneLoginScreen()),
                        );
                        },
                        style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 216, 57, 96),
                       foregroundColor: const Color.fromARGB(255, 255, 255, 255), // Text color
                        padding: EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        ),
                        child: Text(
                        'Login with Phone',
                        style: TextStyle(fontSize: 18),
                        ),
                      ),
                      ),
                    ],
                    ),
                  SizedBox(height: 30),

                  // Divider
                  Row(
                    children: [
                      Expanded(child: Divider(color: Color.fromARGB(255, 255, 255, 255))),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text("OR", style: TextStyle(color: Color.fromARGB(255, 255, 244, 248))),
                      ),
                      Expanded(child: Divider(color: Color.fromARGB(255, 255, 248, 250))),
                    ],
                  ),
                    SizedBox(height: 30),

                    Column(
                    children: [
                      // Google Login Button
                      ElevatedButton.icon(
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
                        print("Google Sign-In successful. Account: ${googleUser}, Email: ${googleUser.email}");

                        // Obtain authentication details from Google
                        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

                        // Extract the Google ID Token and Access Token
                        final String? googleIdToken = googleAuth.idToken;
                        final String? googleAccessToken = googleAuth.accessToken;
                        print("Server Auth Code: ${googleUser.serverAuthCode}");
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
                        style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        minimumSize: Size(double.infinity, 50), // Set the width to fill the device width
                        ),
                      icon: FaIcon(
                        FontAwesomeIcons.google,
                        color: Colors.red,
                      ),
                      label: Text(
                        'Login with Google',
                        style: TextStyle(fontSize: 18),
                      ),
                      ),
                      SizedBox(height: 20),
                      // Facebook Login Button
                      ElevatedButton.icon(
                      onPressed: () async {
                        try {
                        String baseUrl = dotenv.env['BASE_URL'] ?? 'http://default-url.com';

                        // Trigger Facebook Sign-In
                        final LoginResult result = await FacebookAuth.instance.login(
                          permissions: ['public_profile', 'email'],
                        ); // Request email and public profile by default

                        if (result.status == LoginStatus.success) {
                          // User successfully logged in
                          final AccessToken accessToken = result.accessToken!;
                          print("Access Token: ${accessToken.token}");

                          // Send Facebook Access Token to the backend
                          final response = await http.post(
                          Uri.parse('$baseUrl/auth/social-login/'),
                          headers: {"Content-Type": "application/json"},
                          body: json.encode({
                            "provider": "facebook",
                            "code": accessToken.token, // Use the Facebook access token
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
                              MaterialPageRoute(builder: (context) => CreateProfileScreen(value: 'Facebook User')),
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
                        } else {
                          // Handle login failure
                          print("Login Status: ${result.status}");
                          print("Message: ${result.message}");
                          ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Login failed: ${result.message}')),
                          );
                        }
                        } catch (e) {
                        print("Error during Facebook login: $e");
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e')),
                        );
                        }
                        print("Facebook Login Clicked");
                      },
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                        shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        ),
                        minimumSize: Size(double.infinity, 50),
                      ),
                      icon: FaIcon(
                        FontAwesomeIcons.facebook,
                        color: const Color.fromARGB(255, 72, 70, 182),
                      ),
                      label: Text(
                        'Login with Facebook',
                        style: TextStyle(fontSize: 18),
                      ),
                      ),
                    ],
                    )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class EmailLoginScreen extends StatefulWidget {
  @override
  _EmailLoginScreenState createState() => _EmailLoginScreenState();
}

class _EmailLoginScreenState extends State<EmailLoginScreen> {
  final TextEditingController emailController = TextEditingController();

  bool isLoading = false; // Add a loading state

  Future<void> sendOtp(String endpoint, String value, BuildContext context) async {
    setState(() {
      isLoading = true; // Show loading indicator
    });

    try {
      final response = await http.post(
        Uri.parse(endpoint),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': value}),
      );

      if (response.statusCode == 200) {
        Fluttertoast.showToast(
          msg: "OTP sent successfully!",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.TOP,
          backgroundColor: Colors.green,
          textColor: Colors.white,
        );
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OtpVerificationScreen(value: value),
          ),
        );
      } else {
        Fluttertoast.showToast(
          msg: "Failed to send OTP: ${response.body}",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.TOP,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: "Error: $e",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.TOP,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    } finally {
      setState(() {
        isLoading = false; // Hide loading indicator
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: Colors.pinkAccent),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Email Login',
                  style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
                ),
                backgroundColor: const Color.fromARGB(255, 255, 255, 255),
              ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                labelText: "Email Address",
                prefixIcon: Icon(Icons.email, color: primaryColor),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: primaryColor),
                ),
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                String baseUrl = dotenv.env['BASE_URL'] ?? 'http://default-url.com';
                String endpoint = '$baseUrl/auth/send-email-otp/';
                sendOtp(endpoint, emailController.text, context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 216, 57, 96),
                foregroundColor: const Color.fromARGB(255, 255, 255, 255), // Text color
                padding: EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                "Send OTP",
                style: TextStyle(fontSize: 18, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PhoneLoginScreen extends StatelessWidget {
  final TextEditingController phoneController = TextEditingController();

  Future<void> sendOtp(String endpoint, String value, BuildContext context) async {
    try {
      final response = await http.post(
        Uri.parse(endpoint),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'phone': value}),
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
      appBar: AppBar(
        title: Text('Phone Login'),
        backgroundColor: Colors.redAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: "Phone Number",
                prefixIcon: Icon(Icons.phone, color: Colors.redAccent),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                String baseUrl = dotenv.env['BASE_URL'] ?? 'http://default-url.com';
                String endpoint = '$baseUrl/auth/send-otp/';
                sendOtp(endpoint, phoneController.text, context);
              },
              style: ElevatedButton.styleFrom(
               backgroundColor: const Color.fromARGB(255, 216, 57, 96),
              foregroundColor: const Color.fromARGB(255, 255, 255, 255), // Text color
                padding: EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                "Send OTP",
                style: TextStyle(fontSize: 18, color: Colors.white),
              ),
            ),
          ],
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
            await prefs.setString('username', value); // Store the username (email)

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
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: Colors.pinkAccent),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'OTP Verification',
                  style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
                ),
             
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
          PinCodeTextField(
  appContext: context,
  length: 6,
  controller: otpController,
  keyboardType: TextInputType.number,
  animationType: AnimationType.fade,
  pinTheme: PinTheme(
    shape: PinCodeFieldShape.box,
    borderRadius: BorderRadius.zero,
    fieldHeight: 50,
    fieldWidth: 40,
    activeFillColor: Color.fromARGB(255, 223, 203, 211), // Active background color
    selectedFillColor: Color.fromARGB(255, 223, 203, 211), // Selected background color
    inactiveFillColor: Color.fromARGB(255, 223, 203, 211), // Inactive background color
    activeColor: Colors.transparent, // Remove active border color
    selectedColor: Colors.transparent, // Remove selected border color
    inactiveColor: Colors.transparent, // Remove inactive border color
   
  ),
  animationDuration: Duration(milliseconds: 300),
  backgroundColor: Colors.transparent,
  enableActiveFill: true,
  onCompleted: (v) {
    print("Completed");
  },
  onChanged: (value) {
    print(value);
  },
),           SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                verifyOtp(context);
              },
                style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromARGB(255, 216, 57, 96),
                       foregroundColor: const Color.fromARGB(255, 255, 255, 255), // Text color
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
