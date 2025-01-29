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
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchUserProfile();
  }

  Future<void> fetchUserProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('access_token');

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
            isLoading = false;
          });
        } else {
          setState(() {
            isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error fetching profile: ${response.body}'),
            ),
          );
        }
      } catch (e) {
        setState(() {
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('An error occurred: $e'),
          ),
        );
      }
    } else {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Access token is missing or invalid.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('User Profile', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.pinkAccent,
        elevation: 0,
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : userProfile != null
              ? SingleChildScrollView(
                  child: Column(
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          if (userProfile!['cover_picture'] != null)
                            Container(
                              height: 250,
                              decoration: BoxDecoration(
                                image: DecorationImage(
                                  image: NetworkImage('$baseurl/${userProfile!['cover_picture']}'),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          Positioned(
                            top: 150,
                            child: CircleAvatar(
                              radius: 60,
                              backgroundImage: userProfile!['profile_picture'] != null
                                  ? NetworkImage('$baseurl/${userProfile!['profile_picture']}')
                                  : AssetImage('assets/placeholder.png') as ImageProvider,
                            ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            Text(
                              userProfile!['name'] ?? 'No Name',
                              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.pinkAccent),
                            ),
                            SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildStatItem(Icons.favorite, userProfile!['likes_received'].toString()),
                                _buildStatItem(Icons.close, userProfile!['dislikes_received'].toString()),
                                _buildStatItem(Icons.star, userProfile!['profile_score'].toString()),
                              ],
                            ),
                            SizedBox(height: 20),
                            Card(
                              elevation: 4,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  children: [
                                    _buildDetailRow(Icons.phone, userProfile!['phone_number']?.toString() ?? 'N/A'),
                                    _buildDetailRow(Icons.cake, userProfile!['date_of_birth']?.toString() ?? 'N/A'),
                                    _buildDetailRow(Icons.people, userProfile!['gender']?.toString() ?? 'N/A'),
                                    if (userProfile!['bio'] != null)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 12.0),
                                        child: Text(
                                          userProfile!['bio'].toString(),
                                          textAlign: TextAlign.center,
                                          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
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

  Widget _buildDetailRow(IconData icon, String text) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: Colors.pinkAccent),
        SizedBox(width: 12),
        Text(text, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildStatItem(IconData icon, String value) {
    return Column(
      children: [
        Icon(icon, color: Colors.pinkAccent, size: 28),
        SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.pinkAccent)),
      ],
    );
  }
}
