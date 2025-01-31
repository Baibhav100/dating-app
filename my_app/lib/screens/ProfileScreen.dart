import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

String baseurl = dotenv.env['BASE_URL'] ?? 'http://default-url.com';

class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? userProfile;
  Map<int, String> allInterests = {};
  List<String> userInterests = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchUserProfile();
  }

  /// Get access token from SharedPreferences
  Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  /// Get refresh token from SharedPreferences
  Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('refresh_token');
  }

  /// Refresh the access token if expired
  Future<void> refreshAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    final refreshToken = await getRefreshToken();

    if (refreshToken == null) {
      showErrorSnackBar('Session expired. Please log in again.');
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('$baseurl/auth/token/refresh/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh': refreshToken}),
      );

      if (response.statusCode == 200) {
        final newTokens = json.decode(response.body);
        await prefs.setString('access_token', newTokens['access']);

        // Retry fetching user profile with the new token
        fetchUserProfile();
      } else {
        showErrorSnackBar('Session expired. Please log in again.');
      }
    } catch (e) {
      showErrorSnackBar('Error refreshing token: $e');
    }
  }

  /// Fetch user profile details
  Future<void> fetchUserProfile() async {
    final accessToken = await getAccessToken();

    if (accessToken != null && accessToken.isNotEmpty) {
      try {
        final response = await http.get(
          Uri.parse('$baseurl/auth/my-profile/'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $accessToken',
          },
        );

        if (response.statusCode == 200) {
          setState(() {
            userProfile = json.decode(response.body);
          });

          fetchInterests();
        } else if (response.statusCode == 401) {
          // Token expired, try to refresh
          await refreshAccessToken();
        } else {
          showErrorSnackBar('Error fetching profile: ${response.body}');
        }
      } catch (e) {
        showErrorSnackBar('An error occurred: $e');
      }
    } else {
      showErrorSnackBar('Access token is missing or invalid.');
    }
  }

  /// Fetch interest names and map them
  Future<void> fetchInterests() async {
    final accessToken = await getAccessToken();

    if (accessToken == null) {
      showErrorSnackBar('Access token is missing.');
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('$baseurl/auth/interests/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );

      if (response.statusCode == 200) {
        List<dynamic> interestsData = json.decode(response.body);

        setState(() {
          allInterests = {for (var interest in interestsData) interest['id']: interest['name']};
          userInterests = userProfile!['interests']
              .map<String>((id) => allInterests[id] ?? 'Unknown')
              .toList();
          isLoading = false;
        });
      } else {
        showErrorSnackBar('Error fetching interests');
      }
    } catch (e) {
      showErrorSnackBar('An error occurred while fetching interests.');
    }
  }

  /// Show error snackbar
  void showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : userProfile != null
              ? SingleChildScrollView(
                  child: Column(
                    children: [
                      Stack(
                        alignment: Alignment.topLeft,
                        children: [
                          if (userProfile!['cover_picture'] != null)
                            Container(
                              height: 230,
                              decoration: BoxDecoration(
                                image: DecorationImage(
                                  image: NetworkImage('$baseurl${userProfile!['cover_picture']}'),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                        Positioned(
                                top: 110,
                                left: 10,
                                child: Container(
                                  width: 100,  // Set the width and height to match the CircleAvatar's size
                                  height: 100,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white, // White border color
                                      width: 5, // Border thickness
                                    ),
                                  ),
                                  child: CircleAvatar(
                                    radius: 50,
                                    backgroundImage: userProfile!['profile_picture'] != null
                                        ? NetworkImage('$baseurl${userProfile!['profile_picture']}')
                                        : AssetImage('assets/placeholder.png') as ImageProvider,
                                  ),
                                ),
                              ),

                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              userProfile!['name'] ?? 'No Name',
                              style: TextStyle(fontSize: 28, color: Colors.black87),
                            ),
                            SizedBox(height: 10),
                          if (userProfile!['bio'] != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'About',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          SizedBox(height: 8), // Adds some space between the "About" heading and the bio
                          Text(
                            userProfile!['bio'].toString(),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),

                            SizedBox(height: 16),
                            if (userInterests.isNotEmpty)
 Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    // Interests Section
    Text(
      'Interests',
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.black,
      ),
    ),
    SizedBox(height: 8), // Adds some space between the "Interests" heading and the interests
    Wrap(
      spacing: 8.0,
      children: userInterests.map((interest) {
        // You can define your colors here or use any logic to assign different colors.
        Color chipColor = Color.fromARGB(255, 223, 106, 155); // Default color

        return Chip(
          label: Text(interest, style: TextStyle(color: Colors.white)),
          backgroundColor: chipColor,
        );
      }).toList(),
    ),

    // Additional Information Section
    SizedBox(height: 16), // Adds space before the next section
    Text(
      'Other Information',
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.black,
      ),
    ),
    SizedBox(height: 8), // Adds space between "Other Information" and the actual details

    // Gender
    Row(
      children: [
        Icon(Icons.person, color: Colors.grey[700], size: 20),
        SizedBox(width: 8),
        Text(
          'Gender: ${userProfile!['gender']}',
          style: TextStyle(fontSize: 16, color: Colors.grey[700]),
        ),
      ],
    ),
    SizedBox(height: 8), // Adds space between gender and dob

    // Date of Birth
    Row(
      children: [
        Icon(Icons.calendar_today, color: Colors.grey[700], size: 20),
        SizedBox(width: 8),
        Text(
          'Date of Birth: ${userProfile!['date_of_birth']}',
          style: TextStyle(fontSize: 16, color: Colors.grey[700]),
        ),
      ],
    ),
    SizedBox(height: 8), // Adds space between dob and likes received

    // Likes Received
    Row(
      children: [
        Icon(Icons.thumb_up, color: Colors.grey[700], size: 20),
        SizedBox(width: 8),
        Text(
          'Likes Received: ${userProfile!['likes_received']}',
          style: TextStyle(fontSize: 16, color: Colors.grey[700]),
        ),
      ],
    ),
    SizedBox(height: 8), // Adds space between likes and dislikes

    // Dislikes Received
    Row(
      children: [
        Icon(Icons.thumb_down, color: Colors.grey[700], size: 20),
        SizedBox(width: 8),
        Text(
          'Dislikes Received: ${userProfile!['dislikes_received']}',
          style: TextStyle(fontSize: 16, color: Colors.grey[700]),
        ),
      ],
    ),
    SizedBox(height: 8), // Adds space between dislikes and profile score

    // Profile Score
    Row(
      children: [
        Icon(Icons.star, color: Colors.grey[700], size: 20),
        SizedBox(width: 8),
        Text(
          'Profile Score: ${userProfile!['profile_score']}',
          style: TextStyle(fontSize: 16, color: Colors.grey[700]),
        ),
      ],
    ),
  ],
)

                          ],
                        ),
                      ),
                    ],
                  ),
                )
              : Center(child: Text('No profile details found.')),
    );
  }
}
