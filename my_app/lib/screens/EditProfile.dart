import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class EditProfileScreen extends StatefulWidget {
  @override
  _EditProfileScreenState createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final String baseurl = dotenv.env['BASE_URL'] ?? 'http://default-url.com';
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  Map<String, dynamic>? userProfile;
  List<String> userInterests = [];
  Map<int, String> allInterests = {};
  bool isLoading = true;

  late TextEditingController _nameController;
  late TextEditingController _bioController;
  late TextEditingController _genderController;
  late TextEditingController _dobController;

  File? _profileImage;
  File? _coverImage;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _fetchUserProfile();
  }

  void _initializeControllers() {
    _nameController = TextEditingController();
    _bioController = TextEditingController();
    _genderController = TextEditingController();
    _dobController = TextEditingController();
  }

  Future<String?> _getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  Future<void> _fetchUserProfile() async {
    final accessToken = await _getAccessToken();

    if (accessToken == null) {
      _showErrorSnackBar('Authentication required. Please log in.');
      return;
    }

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
          _nameController.text = userProfile?['name'] ?? '';
          _bioController.text = userProfile?['bio'] ?? '';
          _genderController.text = userProfile?['gender'] ?? '';
          _dobController.text = userProfile?['date_of_birth'] ?? '';
        });
        _fetchInterests();
      } else {
        _showErrorSnackBar('Error fetching profile: ${response.body}');
      }
    } catch (e) {
      _showErrorSnackBar('An error occurred: $e');
    }
  }

  Future<void> _fetchInterests() async {
    final accessToken = await _getAccessToken();

    if (accessToken == null) {
      _showErrorSnackBar('Access token is missing.');
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
        _showErrorSnackBar('Error fetching interests');
      }
    } catch (e) {
      _showErrorSnackBar('An error occurred while fetching interests.');
    }
  }

  Future<void> _pickProfileImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _profileImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _pickCoverImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _coverImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final accessToken = await _getAccessToken();
    if (accessToken == null) {
      _showErrorSnackBar('Authentication required. Please log in.');
      return;
    }

    try {
      // Prepare multipart request for profile update
      var request = http.MultipartRequest(
        'POST', 
        Uri.parse('$baseurl/auth/update_profile/')
      );

      // Add headers
      request.headers['Authorization'] = 'Bearer $accessToken';

      // Add text fields
      request.fields['name'] = _nameController.text.trim();
      request.fields['bio'] = _bioController.text.trim();
      request.fields['gender'] = _genderController.text.trim();
      request.fields['date_of_birth'] = _dobController.text.trim();

      // Add profile image if selected
      if (_profileImage != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'profile_picture', 
            _profileImage!.path
          )
        );
      }

      // Add cover image if selected
      if (_coverImage != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'cover_picture', 
            _coverImage!.path
          )
        );
      }

      // Send the request
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        _showErrorSnackBar('Profile updated successfully');
        Navigator.pop(context, true);
      } else {
        _showErrorSnackBar('Failed to update profile: $responseBody');
      }
    } catch (e) {
      _showErrorSnackBar('Error updating profile: $e');
    }
  }

  void _showErrorSnackBar(String message) {
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
                      expandedHeight: 400,
                      floating: false,
                      pinned: true,
                      backgroundColor: Colors.transparent,
                      actions: [
                        IconButton(
                          icon: Icon(Icons.save, color: Colors.white),
                          onPressed: _updateProfile,
                        ),
                      ],
                      flexibleSpace: FlexibleSpaceBar(
                        background: Stack(
                          fit: StackFit.expand,
                          children: [
                            // Cover Image with Hero animation
                            GestureDetector(
                              onTap: _pickCoverImage,
                              child: _coverImage != null
                                  ? Image.file(_coverImage!, fit: BoxFit.cover)
                                  : userProfile!['cover_picture'] != null
                                      ? Hero(
                                          tag: 'cover_${userProfile!['id']}',
                                          child: Image.network(
                                            '$baseurl${userProfile!['cover_picture']}',
                                            fit: BoxFit.cover,
                                          ),
                                        )
                                      : Container(color: Colors.pinkAccent),
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
                                      GestureDetector(
                                        onTap: _pickProfileImage,
                                        child: Stack(
                                          children: [
                                            CircleAvatar(
                                              radius: 50,
                                              backgroundColor: Colors.white,
                                              backgroundImage: _profileImage != null
                                                  ? FileImage(_profileImage!)
                                                  : userProfile?['profile_picture'] != null
                                                      ? NetworkImage('$baseurl${userProfile!['profile_picture']}')
                                                      : null,
                                              child: _profileImage == null && userProfile?['profile_picture'] == null
                                                  ? Icon(Icons.person, size: 50, color: Colors.pinkAccent)
                                                  : null,
                                            ),
                                            Positioned(
                                              bottom: 0,
                                              right: 0,
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  color: Colors.pinkAccent,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Icon(
                                                  Icons.edit, 
                                                  color: Colors.white, 
                                                  size: 20
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      SizedBox(width: 16),
                                      Expanded(
                                        child: TextFormField(
                                          controller: _nameController,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          decoration: InputDecoration(
                                            hintText: 'Enter your name',
                                            hintStyle: TextStyle(
                                              color: Colors.white.withOpacity(0.7),
                                            ),
                                            border: UnderlineInputBorder(
                                              borderSide: BorderSide(color: Colors.white),
                                            ),
                                            enabledBorder: UnderlineInputBorder(
                                              borderSide: BorderSide(color: Colors.white),
                                            ),
                                            focusedBorder: UnderlineInputBorder(
                                              borderSide: BorderSide(color: Colors.white, width: 2),
                                            ),
                                          ),
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
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // About Section
                              Text(
                                'About',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
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
                                child: TextFormField(
                                  controller: _bioController,
                                  maxLines: 4,
                                  decoration: InputDecoration(
                                    hintText: 'Tell us about yourself...',
                                    border: InputBorder.none,
                                  ),
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.black87,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                              SizedBox(height: 24),

                              // Interests Section
                              Text(
                                'Interests',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
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
                                      color: Colors.pinkAccent.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: Colors.pinkAccent.withOpacity(0.3),
                                      ),
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

                              // Basic Info Section
                              Text(
                                'Basic Info',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
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
                                    _buildEditableInfoRow(
                                      icon: Icons.person, 
                                      label: 'Gender', 
                                      controller: _genderController
                                    ),
                                    Divider(height: 20),
                                    _buildEditableInfoRow(
                                      icon: Icons.cake, 
                                      label: 'Birthday', 
                                      controller: _dobController,
                                      keyboardType: TextInputType.datetime,
                                    ),
                                    Divider(height: 20),
                                    // Likes and Profile Score are typically read-only
                                    _buildReadOnlyInfoRow(
                                      icon: Icons.favorite, 
                                      label: 'Likes', 
                                      value: '${userProfile!['likes_received']}',
                                    ),
                                    Divider(height: 20),
                                    _buildReadOnlyInfoRow(
                                      icon: Icons.star, 
                                      label: 'Profile Score', 
                                      value: '${userProfile!['profile_score']}',
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              : Center(child: Text('No profile details found.')),
    );
  }

  Widget _buildEditableInfoRow({
    required IconData icon, 
    required String label, 
    required TextEditingController controller,
    TextInputType? keyboardType,
  }) {
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
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
              TextFormField(
                controller: controller,
                keyboardType: keyboardType,
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  hintText: 'Enter $label',
                  border: InputBorder.none,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReadOnlyInfoRow({
    required IconData icon, 
    required String label, 
    required String value,
  }) {
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
