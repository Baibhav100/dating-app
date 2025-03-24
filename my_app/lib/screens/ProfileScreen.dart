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
              ? CustomScrollView(
                    slivers: [
                    // Profile Header with Cover Image and Profile Picture
                    SliverAppBar(
                      expandedHeight: 250, // Reduced height
                      floating: false,
                      pinned: true,
                      backgroundColor: Colors.transparent,
                      flexibleSpace: FlexibleSpaceBar(
                      background: Stack(
                        fit: StackFit.expand,
                        children: [
                        // Cover Image with Hero animation
                        if (userProfile!['cover_picture'] != null)
                          Hero(
                          tag: 'cover_${userProfile!['id']}',
                          child: Image.network(
                            '$baseurl${userProfile!['cover_picture']}',
                            fit: BoxFit.cover,
                          ),
                          ),
                        // Multiple gradient overlays for better depth
                        Container(
                          decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                            Colors.black.withOpacity(0.0),
                            Colors.black.withOpacity(0.3),
                            Colors.black.withOpacity(0.7),
                            ],
                            stops: [0.0, 0.5, 1.0],
                          ),
                          ),
                        ),
                        // Side gradients for depth
                        Container(
                          decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                            Colors.black.withOpacity(0.3),
                            Colors.transparent,
                            Colors.transparent,
                            Colors.black.withOpacity(0.3),
                            ],
                            stops: [0.0, 0.2, 0.8, 1.0],
                          ),
                          ),
                        ),
                        // Profile Picture and Name
                        Positioned(
                          bottom: 20,
                          left: 20,
                          right: 20,
                          child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                            children: [
                              // Profile picture with hero animation and progress indicator
                              Hero(
                              tag: 'profile_${userProfile!['id']}',
                              child: Stack(
                                children: [
                                Container(
                                  width: 100,
                                  height: 100,
                                  child: CircularProgressIndicator(
                                  value: (num.parse(userProfile!['profile_score'].toString())) / 100,
                                  strokeWidth: 6,
                                  backgroundColor: Colors.white,
                                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFA2D2FF),),
                                  ),
                                ),
                                Positioned(
                                  top: 6,
                                  left: 6,
                                  right: 6,
                                  bottom: 6,
                                  child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 3),
                                    boxShadow: [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 10,
                                      spreadRadius: 2,
                                      offset: Offset(0, 2),
                                    ),
                                    ],
                                  ),
                                  child: ClipOval(
                                    child: Image(
                                    image: userProfile!['profile_picture'] != null
                                      ? NetworkImage('$baseurl${userProfile!['profile_picture']}')
                                      : AssetImage('assets/placeholder.png') as ImageProvider,
                                    fit: BoxFit.cover,
                                    ),
                                  ),
                                  ),
                                ),
                                ],
                              ),
                              ),
                              SizedBox(width: 20),
                              Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                Text(
                                  userProfile!['name'] ?? 'No Name',
                                  style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  shadows: [
                                    Shadow(
                                    blurRadius: 10,
                                    color: Colors.black.withOpacity(0.5),
                                    offset: Offset(0, 2),
                                    ),
                                  ],
                                  ),
                                ),
                                SizedBox(height: 4),
                                Row(
                                  children: [
                                  Icon(Icons.location_on, 
                                    color: Colors.white.withOpacity(0.9), 
                                    size: 16),
                                  SizedBox(width: 4),
                                  Text(
                                    'Location',
                                    style: TextStyle(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 16,
                                    shadows: [
                                      Shadow(
                                      blurRadius: 8,
                                      color: Colors.black.withOpacity(0.5),
                                      offset: Offset(0, 1),
                                      ),
                                    ],
                                    ),
                                  ),
                                  ],
                                ),
                                ],
                              ),
                              ),
                            ],
                            ),
                          ],
                          ),
                        ),
                        ],
                      ),
                      ),
                    ),

                    // Profile Content
                    SliverToBoxAdapter(
                      child: Container(
                      padding: EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                        // About Section
                        if (userProfile!['bio'] != null) ...[
                          Text(
                          'About',
                                    style: TextStyle(
                            fontSize: 19,
                            color: const Color.fromARGB(221, 65, 63, 63),
                          ),
                          ),
                          SizedBox(height: 12),
                          Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              spreadRadius: 0,
                            ),
                            ],
                          ),
                          child: Text(
                            userProfile!['bio'].toString(),
                            style: TextStyle(
                            fontSize: 16,
                            color: Colors.black87,
                            height: 1.5,
                            ),
                          ),
                          ),
                          SizedBox(height: 24),
                        ],

                        // Relationship Status and Looking For Section
                        Row(
                          children: [
                          Expanded(
                            child: Container(
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                                color: Color.fromARGB(255, 255, 255, 255),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                spreadRadius: 0,
                              ),
                              ],
                            ),
                            child:Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Row(
      children: [
        Icon(
          Icons.favorite, // Heart icon
          size: 16,
          color: const Color.fromARGB(221, 102, 101, 101),
        ),
        SizedBox(width: 4), // Add some space between the icon and text
        Text(
          'Relationship Status',
          style: TextStyle(
            fontSize: 10,
            color: const Color.fromARGB(221, 102, 101, 101),
          ),
        ),
      ],
    ),
    SizedBox(height: 8),
    Text(
      userProfile!['relationship_status'] ?? 'Not specified',
      style: TextStyle(
        fontSize: 16,
        color: Colors.black87,
        height: 1.5,
      ),
    ),
  ],
)
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Container(
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                                color: Color.fromARGB(255, 255, 255, 255),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                spreadRadius: 0,
                              ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                              Text(
                                'Looking For',
                                style: TextStyle(
                                fontSize:10,
                                color: const Color.fromARGB(221, 99, 98, 98),
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                userProfile!['looking_for'] ?? 'Not specified',
                                style: TextStyle(
                                fontSize: 16,
                                color: Colors.black87,
                                height: 1.5,
                                ),
                              ),
                              ],
                            ),
                            ),
                          ),
                          ],
                        ),
                        SizedBox(height: 24),

                        // Interests Section
                        if (userInterests.isNotEmpty) ...[
                          Text(
                          'Interests',
                            style: TextStyle(
                            fontSize: 19,
                            color: const Color.fromARGB(221, 65, 63, 63),
                          ),
                          ),
                          SizedBox(height: 12),
                          Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: userInterests.map((interest) {
                            return Container(
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color.fromARGB(255, 223, 219, 219).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                        
                            ),
                            child: Text(
                              interest,
                              style: TextStyle(
                              color: Colors.pinkAccent,
                              fontWeight: FontWeight.w500,
                              ),
                            ),
                            );
                          }).toList(),
                          ),
                          SizedBox(height: 24),
                        ],

                        // Basic Info Section
                        Text(
                          'Basic Info',
                                 style: TextStyle(
                            fontSize: 19,
                            color: const Color.fromARGB(221, 65, 63, 63),
                          ),
                        ),
                        SizedBox(height: 12),
                        Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            spreadRadius: 0,
                            ),
                          ],
                          ),
                          child: Column(
                          children: [
                            _buildInfoRow(Icons.person, 'Gender', userProfile!['gender']),
                            Divider(height: 20),
                            _buildInfoRow(Icons.cake, 'Birthday', userProfile!['date_of_birth']),
                            Divider(height: 20),
                            _buildInfoRow(Icons.favorite, 'Likes', '${userProfile!['likes_received']}'),
                            Divider(height: 20),
                            _buildInfoRow(Icons.star, 'Profile Score', '${userProfile!['profile_score']}'),
                          ],
                          ),
                        ),
                        ],
                      ),
                      ),
                    ),
                  ],
                )
              : Center(child: Text('No profile details found.')),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.pinkAccent.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.pinkAccent, size: 20),
        ),
        SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                color: Colors.black87,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
