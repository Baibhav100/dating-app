import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'ChatScreen.dart';

String baseurl = dotenv.env['BASE_URL'] ?? 'http://default-url.com';

class UserProfileScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final int user1Id;
  final int user2Id;

  UserProfileScreen({required this.user, required this.user1Id, required this.user2Id});

  @override
  _UserProfileScreenState createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  Map<int, String> allInterests = {};
  List<String> userInterests = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchInterests();
  }
    Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
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
          userInterests = widget.user['interests']
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
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stack for Cover Image and Profile Image
            Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                // Cover Picture
                CachedNetworkImage(
                  imageUrl: '$baseurl${widget.user['cover_picture'] ?? ''}',
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorWidget: (context, url, error) => const Icon(Icons.error),
                ),

                // Profile Image Positioned on Top
                Positioned(
                  bottom: -50,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white,
                        width: 5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 10,
                          spreadRadius: 2,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 50,
                      backgroundImage: widget.user['profile_picture'] != null && widget.user['profile_picture'] != ''
                          ? CachedNetworkImageProvider(baseurl + widget.user['profile_picture'])
                          : const AssetImage('assets/placeholder.png') as ImageProvider,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 60),

            // Name and Chat Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    widget.user['name'] ?? 'No Name',
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatScreen(
                          user1Id: widget.user1Id,
                          user2Id: widget.user2Id,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.chat, size: 20),
                  label: const Text('Chat'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.pinkAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // About Section (Bio)
            const Text(
              'About:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.user['bio'] ?? 'No bio available',
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.left,
            ),
            const SizedBox(height: 16),

            // Interests Section
            if (widget.user['interests'] != null && widget.user['interests'].isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Interests:',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  isLoading
                      ? CircularProgressIndicator()
                      : Wrap(
                          spacing: 8.0,
                          children: userInterests
                              .map<Widget>((interest) => Chip(
                                    label: Text(interest),
                                    backgroundColor: Colors.pinkAccent[100],
                                    labelStyle: TextStyle(color: Colors.white),
                                  ))
                              .toList(),
                        ),
                ],
              ),
            const SizedBox(height: 16),

            // Other Information Section
            const Text(
              'Other Information:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.phone, 'Phone', widget.user['phone_number']),
            _buildInfoRow(Icons.date_range, 'Date of Birth', widget.user['date_of_birth']),
            _buildInfoRow(Icons.female, 'Gender', widget.user['gender']),
            _buildInfoRow(Icons.star, 'Profile Score', widget.user['profile_score']),
          ],
        ),
      ),
    );
  }

  // Helper Widget for Displaying User Info with Icons
  Widget _buildInfoRow(IconData icon, String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.pinkAccent),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black54,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            value?.toString() ?? 'Not Available',
            style: const TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }
}