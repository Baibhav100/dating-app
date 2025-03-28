import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:path/path.dart' as p;

String baseurl = dotenv.env['BASE_URL'] ?? 'http://default-url.com';

class EditProfileScreen  extends StatefulWidget {
  @override
  _EditProfileScreenState  createState() => _EditProfileScreenState ();
}

class _EditProfileScreenState  extends State<EditProfileScreen> {
  Map<String, dynamic>? userProfile;
  Map<int, String> allInterests = {};
  List<String> userInterests = [];
  bool isLoading = true;
  List<File> _images = [];
  List<String> _descriptions = [];
  int _userProfileId = 1; // Replace with the actual user profile ID
  final ImagePicker _picker = ImagePicker();
  List<Map<String, dynamic>> _galleryImages = []; // Store full gallery items
  bool _isLoadingImages = false;
  

  @override
  void initState() {
    super.initState();
    fetchUserProfile();
    _fetchUserImages();
  }

  Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  Future<void> _fetchUserImages() async {
    setState(() {
      _isLoadingImages = true;
    });

    const String url = 'http://192.168.1.241:8000/auth/user-gallery/';
    final String? token = await getAccessToken(); // Your existing token method

    if (token == null || token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Access token is missing.')),
      );
      setState(() { _isLoadingImages = false; });
      return;
    }

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> imagesJson = jsonDecode(response.body);
        setState(() {
          _galleryImages = imagesJson.cast<Map<String, dynamic>>();
          _isLoadingImages = false;
        });
      } else {
        print('Failed to load images: ${response.body}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load images: ${response.body}')),
        );
        setState(() { _isLoadingImages = false; });
      }
    } catch (e) {
      print('Error fetching images: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching images: $e')),
      );
      setState(() { _isLoadingImages = false; });
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
            isLoading = false;
          });
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

  void showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _pickImage() async {
    if (_images.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('You can upload up to 5 images only.')),
      );
      return;
    }

    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _images.add(File(pickedFile.path));
        _descriptions.add(''); // Initialize description for the new image
      });
    }
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
                                                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFA2D2FF)),
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
  child: GestureDetector(
    onTap: () {
      if (userProfile!['profile_picture'] != null) {
        showDialog(
          context: context,
          builder: (context) => Dialog(
            backgroundColor: Colors.transparent,
            child: GestureDetector(
              onTap: () => Navigator.pop(context), // Tap to close
              child: Image.network(
                '$baseurl${userProfile!['profile_picture']}',
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey[300],
                    child: Center(child: Text('Image failed to load')),
                  );
                },
              ),
            ),
          ),
        );
      }
    },
    child: Image(
      image: userProfile!['profile_picture'] != null
          ? NetworkImage('$baseurl${userProfile!['profile_picture']}')
          : AssetImage('assets/placeholder.png') as ImageProvider,
      fit: BoxFit.cover,
    ),
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
                                                    color: Colors.white.withOpacity(0.9), size: 16),
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
                              SizedBox(height: 16),
                   
                            ],
                            // Relationship Status and Looking For Section
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
    fontWeight: FontWeight.bold, // Made the title bold for emphasis
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
      Divider(height: 20, color: Colors.grey[300], thickness: 0.5), // Lighter and thinner divider
      _buildInfoRow(Icons.cake, 'Birthday', userProfile!['date_of_birth']),
      Divider(height: 20, color: Colors.grey[300], thickness: 0.5),
      _buildInfoRow(Icons.favorite, 'Likes', '${userProfile!['likes_received']}'),
      Divider(height: 20, color: Colors.grey[300], thickness: 0.5),
      _buildInfoRow(Icons.star, 'Profile Score', '${userProfile!['profile_score']}'),
      Divider(height: 20, color: Colors.grey[300], thickness: 0.5),
      _buildInfoRow(Icons.thumb_down, 'Dislikes', '${userProfile!['dislikes_received']}'),
      Divider(height: 20, color: Colors.grey[300], thickness: 0.5),
      _buildInfoRow(Icons.online_prediction, 'Status', userProfile!['is_active'] == true ? 'Online' : 'Offline'),
      Divider(height: 20, color: Colors.grey[300], thickness: 0.5),
      _buildInfoRow(Icons.favorite_border, 'Orientation', userProfile!['sexual_orientation']),
      Divider(height: 20, color: Colors.grey[300], thickness: 0.5),
      _buildInfoRow(Icons.language, 'Language', userProfile!['language_spoken']),
      Divider(height: 20, color: Colors.grey[300], thickness: 0.5),
      _buildInfoRow(Icons.psychology, 'Personality', userProfile!['personality_type']),
      Divider(height: 20, color: Colors.grey[300], thickness: 0.5),
      _buildInfoRow(Icons.smoking_rooms, 'Smoking', userProfile!['smoking_habits']),
      Divider(height: 20, color: Colors.grey[300], thickness: 0.5),
      _buildInfoRow(Icons.local_bar, 'Drinking', userProfile!['drinking_habits']),
      Divider(height: 20, color: Colors.grey[300], thickness: 0.5),
      _buildInfoRow(Icons.favorite, 'Relationship Type', userProfile!['relationship_type']),
      Divider(height: 20, color: Colors.grey[300], thickness: 0.5),
      _buildInfoRow(Icons.flag, 'Relationship Goal', userProfile!['relationship_goal']),
      Divider(height: 20, color: Colors.grey[300], thickness: 0.5),
      _buildInfoRow(Icons.height, 'Height', '${userProfile!['height']} cm'),
      Divider(height: 20, color: Colors.grey[300], thickness: 0.5),
      _buildInfoRow(Icons.people, 'Relationship Status', userProfile!['relationship_status']),
      Divider(height: 20, color: Colors.grey[300], thickness: 0.5),
      _buildInfoRow(Icons.family_restroom, 'Family Orientation', userProfile!['family_orientation']),
      Divider(height: 20, color: Colors.grey[300], thickness: 0.5),
      _buildInfoRow(Icons.accessibility, 'Body Type', userProfile!['body_type']),
      Divider(height: 20, color: Colors.grey[300], thickness: 0.5),
      _buildInfoRow(Icons.brush, 'Hair Color', userProfile!['hair_color']),
      Divider(height: 20, color: Colors.grey[300], thickness: 0.5),
      _buildInfoRow(Icons.remove_red_eye, 'Eye Color', userProfile!['eye_color']),
      Divider(height: 20, color: Colors.grey[300], thickness: 0.5),
      _buildInfoRow(Icons.school, 'Education', userProfile!['education_level']),
      Divider(height: 20, color: Colors.grey[300], thickness: 0.5),
      _buildInfoRow(Icons.work, 'Occupation', userProfile!['occupation']),
      Divider(height: 20, color: Colors.grey[300], thickness: 0.5),
      _buildInfoRow(Icons.business, 'Industry', userProfile!['industry']),
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
  Color iconColor = Colors.grey.shade600; // Default color
  if (icon == Icons.favorite) {
    iconColor = Colors.red; // Red heart for Likes
  } else if (icon == Icons.star) {
    iconColor = Colors.amber; // Gold star for Profile Score
  }
  return Row(
    children: [
      Icon(icon, color: iconColor),
      SizedBox(width: 10),
      Expanded(
        flex: 2,
        child: Text(label, style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      Expanded(
        flex: 3,
        child: Text(
          value,
          style: TextStyle(color: Colors.grey[600]),
          textAlign: TextAlign.right,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ],
  );
}
}

