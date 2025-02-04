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

  Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('refresh_token');
  }

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
        fetchUserProfile();
      } else {
        showErrorSnackBar('Session expired. Please log in again.');
      }
    } catch (e) {
      showErrorSnackBar('Error refreshing token: $e');
    }
  }

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
                      // Profile Header Section
                      Container(
                        height: 230,
                        child: Stack(
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
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 5),
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
                                  SizedBox(height: 8),
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
                                  Text(
                                    'Interests',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Container(
                                    constraints: BoxConstraints(
                                      maxHeight: 200,
                                    ),
                                    child: SingleChildScrollView(
                                      child: Wrap(
                                        spacing: 8.0,
                                        runSpacing: 4.0, // Allow items to wrap properly
                                        children: userInterests.map((interest) {
                                          return Chip(
                                            label: Text(interest, style: TextStyle(color: Colors.white)),
                                            backgroundColor: Colors.pinkAccent,
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: 16),
                                ],
                              ),
                            Text(
                              'Other Information',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                            SizedBox(height: 8),
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
                            SizedBox(height: 8),
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
                            SizedBox(height: 8),
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
                            SizedBox(height: 8),
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
                            SizedBox(height: 8),
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
                        ),
                      ),
                    ],
                  ),
                )
              : Center(child: Text('No profile details found.')),
    );
  }
}
