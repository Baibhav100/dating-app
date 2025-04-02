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

class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
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
Future<void> _uploadImages() async {
  print('_uploadImages function called');
  final accessToken = await getAccessToken();
  if (accessToken == null || accessToken.isEmpty) {
    setState(() {
      isLoading = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Access token is missing.')),
    );
    return;
  }

  setState(() {
    isLoading = true;
  });

  print('Selected images in gallery:');
  if (_images.isEmpty) {
    print('  No images selected.');
  } else {
    for (int i = 0; i < _images.length; i++) {
      print('  Image $i: ${_images[i].path} (Exists: ${_images[i].existsSync()}, Size: ${_images[i].lengthSync()} bytes)');
    }
  }

  try {
    for (int i = 0; i < _images.length; i++) {
      print('--- Uploading image $i ---');
      print('Image path: ${_images[i].path}');
      print('Image exists: ${_images[i].existsSync()}');
      print('Image size: ${_images[i].lengthSync()} bytes');

      final userId = userProfile?['id'];
      final parsedUserId = int.tryParse(userId?.toString() ?? '');
      if (parsedUserId == null) {
        setState(() {
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('User ID must be a valid integer. Found: $userId')),
        );
        return;
      }
      print('User ID: $parsedUserId');

      if (!_images[i].existsSync() || _images[i].lengthSync() == 0) {
        setState(() {
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Image file is invalid: ${_images[i].path}')),
        );
        return;
      }

      // Read the image file and convert to base64
      final imageFile = _images[i];
      final imageBytes = await imageFile.readAsBytes(); // Read file as bytes
      final base64Image = base64Encode(imageBytes); // Encode to base64
      final mimeType = imageFile.path.endsWith('.png') ? 'image/png' : 'image/jpeg'; // Determine MIME type
      final base64String = 'data:$mimeType;base64,$base64Image'; // Full base64 string

      print('Base64 image length: ${base64String.length} characters');

      // Create JSON request body
      final requestBody = {
        'user_profile': parsedUserId,
        'image': base64String,
        'description': (_descriptions[i] ?? '').trim().isEmpty ? 'No description' : _descriptions[i]!.trim(),
      };

      // Send as JSON, not multipart
      final response = await http.post(
        Uri.parse('$baseurl/auth/add_gallery/'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json', // JSON instead of multipart
        },
        body: jsonEncode(requestBody), // Encode body as JSON
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode != 201) {
        setState(() {
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload image: ${response.body}')),
        );
        return;
      }
    }
    setState(() {
      isLoading = false;
      _images.clear();
      _descriptions.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('All images uploaded successfully')),
    );
  } catch (e) {
    setState(() {
      isLoading = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error uploading images: $e')),
    );
    print('Upload error details: $e');
  }
}
  void _showAddPhotoBottomSheet() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return AddPhotoBottomSheet(
          images: _images,
          descriptions: _descriptions,
          onImagePicked: (File image) {
            setState(() {
              _images.add(image);
              _descriptions.add('');
            });
          },
          onDescriptionChanged: (int index, String description) {
            setState(() {
              _descriptions[index] = description;
            });
          },
          onImageRemoved: (int index) {
            setState(() {
              _images.removeAt(index);
              _descriptions.removeAt(index);
            });
          },
          onUploadImages: _uploadImages,
        );
      },
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
                          Text(
  'Gallery',
  style: TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
    color: Colors.black87,
  ),
),
SizedBox(height: 12), // Minimal spacing after title
// Gallery images section
_isLoadingImages
    ? Center(child: CircularProgressIndicator())
    : _galleryImages.isEmpty
        ? Text('No images found in your gallery.')
        : SizedBox(
  height: 160, // Fixed height for the gallery section
  child: ListView.builder(
    scrollDirection: Axis.horizontal,
    itemCount: _galleryImages.length,
    itemBuilder: (context, index) {
      final imageData = _galleryImages[index];
      return Padding(
        padding: const EdgeInsets.only(right: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => Dialog(
                    backgroundColor: Colors.transparent,
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context), // Tap to close
                      child: Image.network(
                        imageData['image_url'],
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
              },
              child: Image.network(
                imageData['image_url'],
                width: 120,
                height: 120,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 120,
                    height: 120,
                    color: Colors.grey[300],
                    child: Center(child: Text('Image failed')),
                  );
                },
              ),
            ),
            SizedBox(height: 4), // Minimal spacing for description (if added later)
          ],
        ),
      );
    },
  ),
),
ElevatedButton(
  onPressed: _showAddPhotoBottomSheet,
  child: Text('Add Photos'),
),
SizedBox(height: 10), // Minimal spacing after button
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
                                    child: Column(
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
                                    ),
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
                                            fontSize: 10,
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

class AddPhotoBottomSheet extends StatefulWidget {
  final List<File> images;
  final List<String> descriptions;
  final Function(File) onImagePicked;
  final Function(int, String) onDescriptionChanged;
  final Function(int) onImageRemoved;
  final Function() onUploadImages;

  AddPhotoBottomSheet({
    required this.images,
    required this.descriptions,
    required this.onImagePicked,
    required this.onDescriptionChanged,
    required this.onImageRemoved,
    required this.onUploadImages,
  });

  @override
  _AddPhotoBottomSheetState createState() => _AddPhotoBottomSheetState();
}

class _AddPhotoBottomSheetState extends State<AddPhotoBottomSheet> {
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    if (widget.images.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('You can upload up to 5 images only.')),
      );
      return;
    }

    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      widget.onImagePicked(File(pickedFile.path));
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.0),
      height: MediaQuery.of(context).size.height * 0.8, // Set a specific height
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Add Photos',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: widget.images.length + 1,
              itemBuilder: (context, index) {
                if (index == widget.images.length) {
                  return ElevatedButton(
                    onPressed: _pickImage,
                    child: Text('Add Photo'),
                  );
                }
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Image.file(
                            widget.images[index],
                            width: 200,
                            height: 200,
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.delete),
                          onPressed: () {
                            widget.onImageRemoved(index);
                            setState(() {});
                          },
                        ),
                      ],
                    ),
                    TextField(
                      decoration: InputDecoration(labelText: 'Description'),
                      onChanged: (value) {
                        widget.onDescriptionChanged(index, value);
                      },
                    ),
                  ],
                );
              },
            ),
          ),
          ElevatedButton(
            onPressed: () {
              // Close the bottom sheet first
              Navigator.of(context).pop();
              
              // Then trigger the upload
              widget.onUploadImages();
            },
            child: Text('Submit'),
          ),
        ],
      ),
    );
  }
}