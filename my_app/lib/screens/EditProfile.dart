import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

String baseurl = dotenv.env['BASE_URL'] ?? 'http://default-url.com';

class EditProfileScreen extends StatefulWidget {
  @override
  _EditProfileScreenState createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  Map<String, dynamic>? userProfile;
  bool isLoading = true;
  final ImagePicker _picker = ImagePicker();
  String? profileImage; // 头像
  String? coverImage; // 封面图
  String? bio; // 个人简介
  String? location; // 位置
  String? name; // 用户名称

  @override
  void initState() {
    super.initState();
    fetchUserProfile();
  }

  Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
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
            profileImage = userProfile!['profile_picture'] ?? null;
            coverImage = userProfile!['cover_picture'] ?? null;
            bio = userProfile!['bio'] ?? '';
            location = userProfile!['location'] ?? 'No location set';
            name = userProfile!['name'] ?? 'No name set';
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

  final List<String> nonEditableFields = [
    'likes_received',
    'profile_score',
    'dislikes_received',
    'is_active',
  ];

  final Map<String, List<String>> fieldOptions = {
    'gender': ['Male', 'Female', 'Other'],
    'sexual_orientation': ['Straight', 'Gay', 'Bisexual', 'Pansexual', 'Other'],
    'personality_type': ['Introvert', 'Extrovert', 'Ambivert'],
    'smoking_habits': ['Non-smoker', 'Occasional smoker', 'Regular smoker'],
    'drinking_habits': ['Non-drinker', 'Occasional drinker', 'Regular drinker'],
    'relationship_type': [
      'Casual',
      'Serious',
      'Friendship',
      'Marriage',
      'Short-term',
      'Long-term',
      'One-night stand',
      'Any'
    ],
    'relationship_goal': [
      'Casual dating',
      'Long-term relationship',
      'Friendship',
      'Marriage'
    ],
    'relationship_status': [
      'Single',
      'In relationship',
      'Divorced',
      'Widowed',
      'Separated'
    ],
    'family_orientation': ['Family-focused', 'Independent', 'Balanced'],
    'body_type': ['Slim', 'Athletic', 'Average', 'Curvy', 'Other'],
  };

  final List<Map<String, dynamic>> basicInfoFields = [
    {'field': 'gender', 'icon': Icons.person, 'label': 'Gender'},
    {'field': 'date_of_birth', 'icon': Icons.cake, 'label': 'Birthday'},
    {'field': 'likes_received', 'icon': Icons.favorite, 'label': 'Likes'},
    {'field': 'profile_score', 'icon': Icons.star, 'label': 'Profile Score'},
    {'field': 'dislikes_received', 'icon': Icons.thumb_down, 'label': 'Dislikes'},
    {'field': 'is_active', 'icon': Icons.online_prediction, 'label': 'Status'},
    {
      'field': 'sexual_orientation',
      'icon': Icons.favorite_border,
      'label': 'Orientation'
    },
    {'field': 'language_spoken', 'icon': Icons.language, 'label': 'Language'},
    {'field': 'personality_type', 'icon': Icons.psychology, 'label': 'Personality'},
    {'field': 'smoking_habits', 'icon': Icons.smoking_rooms, 'label': 'Smoking'},
    {'field': 'drinking_habits', 'icon': Icons.local_bar, 'label': 'Drinking'},
    {
      'field': 'relationship_type',
      'icon': Icons.favorite,
      'label': 'Relationship Type'
    },
    {
      'field': 'relationship_goal',
      'icon': Icons.flag,
      'label': 'Relationship Goal'
    },
    {'field': 'height', 'icon': Icons.height, 'label': 'Height'},
    {
      'field': 'relationship_status',
      'icon': Icons.people,
      'label': 'Relationship Status'
    },
    {
      'field': 'family_orientation',
      'icon': Icons.family_restroom,
      'label': 'Family Orientation'
    },
    {'field': 'body_type', 'icon': Icons.accessibility, 'label': 'Body Type'},
    {'field': 'hair_color', 'icon': Icons.brush, 'label': 'Hair Color'},
    {'field': 'eye_color', 'icon': Icons.remove_red_eye, 'label': 'Eye Color'},
    {'field': 'education_level', 'icon': Icons.school, 'label': 'Education'},
    {'field': 'occupation', 'icon': Icons.work, 'label': 'Occupation'},
    {'field': 'industry', 'icon': Icons.business, 'label': 'Industry'},
  ];

  String getDisplayValue(String field) {
    if (field == 'height') {
      return '${userProfile!['height']} cm';
    } else if (field == 'is_active') {
      return userProfile!['is_active'] == true ? 'Online' : 'Offline';
    } else if (field == 'date_of_birth') {
      DateTime date = DateTime.tryParse(userProfile!['date_of_birth']) ?? DateTime.now();
      return DateFormat('MM/dd/yyyy').format(date);
    } else if (field == 'likes_received' ||
        field == 'profile_score' ||
        field == 'dislikes_received') {
      return userProfile![field].toString();
    } else {
      return userProfile![field];
    }
  }

  void _handleFieldEdit(String field) {
    if (fieldOptions.containsKey(field)) {
      _showSelectionDialog(field, fieldOptions[field]!);
    } else if (field == 'date_of_birth') {
      _showDatePickerDialog();
    } else if (!nonEditableFields.contains(field)) {
      _showTextInputDialog(field);
    }
  }

  void _showSelectionDialog(String field, List<String> options) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return SimpleDialog(
          title: Text('Select ${field.replaceAll('_', ' ')}'),
          children: options.map((option) {
            return SimpleDialogOption(
              onPressed: () {
                setState(() {
                  userProfile![field] = option;
                });
                Navigator.pop(context);
              },
              child: Text(option),
            );
          }).toList(),
        );
      },
    );
  }

  void _showTextInputDialog(String field) {
    TextEditingController controller =
        TextEditingController(text: userProfile![field].toString());
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Edit ${field.replaceAll('_', ' ')}'),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(hintText: 'Enter ${field.replaceAll('_', ' ')}'),
            keyboardType: field == 'height' ? TextInputType.number : TextInputType.text,
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() {
                  userProfile![field] = controller.text;
                });
                Navigator.pop(context);
              },
              child: Text('Save'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  void _showDatePickerDialog() {
    DateTime initialDate = DateTime.tryParse(userProfile!['date_of_birth']) ?? DateTime.now();
    showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    ).then((selectedDate) {
      if (selectedDate != null) {
        setState(() {
          userProfile!['date_of_birth'] = selectedDate.toIso8601String();
        });
      }
    });
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.grey.shade600),
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

  // 选择头像
  Future<void> _selectProfileImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        profileImage = image.path;
        userProfile!['profile_picture'] = image.path;
      });
    }
  }

  // 选择封面图
  Future<void> _selectCoverImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        coverImage = image.path;
        userProfile!['cover_picture'] = image.path;
      });
    }
  }

  // 编辑个人简介
  void _editBio() {
    TextEditingController controller = TextEditingController(text: bio);
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Edit Bio'),
          content: TextField(
            controller: controller,
            maxLines: 5,
            decoration: InputDecoration(hintText: 'Enter your bio'),
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() {
                  bio = controller.text;
                  userProfile!['bio'] = controller.text;
                });
                Navigator.pop(context);
              },
              child: Text('Save'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  // 编辑用户名称
  void _editName() {
    TextEditingController controller = TextEditingController(text: name);
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Edit Name'),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(hintText: 'Enter your name'),
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() {
                  name = controller.text;
                  userProfile!['name'] = controller.text;
                });
                Navigator.pop(context);
              },
              child: Text('Save'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  // 编辑位置
  void _editLocation() {
    TextEditingController controller = TextEditingController(text: location);
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Edit Location'),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(hintText: 'Enter your location'),
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() {
                  location = controller.text;
                  userProfile!['location'] = controller.text;
                });
                Navigator.pop(context);
              },
              child: Text('Save'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  // 保存资料
  Future<void> saveProfile() async {
  // 获取 SharedPreferences 实例
  final prefs = await SharedPreferences.getInstance();
  final username = prefs.getString('username') ?? ''; // 从 SharedPreferences 中读取用户名

  final accessToken = await getAccessToken();

  if (accessToken == null || accessToken.isEmpty) {
    showErrorSnackBar('Access token is missing or invalid.');
    return;
  }

  // Validate required fields
  if (name == null || name!.isEmpty) {
    showErrorSnackBar('Please fill in your name');
    return;
  }

  // Fetch user ID from the current profile
  String? userId = userProfile?['id']?.toString();
  if (userId == null || userId.isEmpty) {
    showErrorSnackBar('User ID is missing. Please log in again.');
    return;
  }

  // Create MultipartRequest
  var request = http.MultipartRequest('POST', Uri.parse('$baseurl/auth/create_profile/'));

  // Add text fields
  request.fields['id'] = userId; // Add user ID explicitly
  request.fields['name'] = name ?? '';
  request.fields['bio'] = bio ?? '';
  request.fields['location'] = location ?? '';
  request.fields['username'] = username; // 添加从 SharedPreferences 中读取的用户名

  // Add all other fields with null checks
  request.fields['profile_score'] = (userProfile!['profile_score'] ?? 0).toString();
  request.fields['date_of_birth'] = userProfile!['date_of_birth'] ?? '';
  request.fields['gender'] = userProfile!['gender'] ?? '';
  request.fields['sexual_orientation'] = userProfile!['sexual_orientation'] ?? '';
  request.fields['language_spoken'] = userProfile!['language_spoken'] ?? '';
  request.fields['personality_type'] = userProfile!['personality_type'] ?? '';
  request.fields['smoking_habits'] = userProfile!['smoking_habits'] ?? '';
  request.fields['drinking_habits'] = userProfile!['drinking_habits'] ?? '';
  request.fields['relationship_goal'] = userProfile!['relationship_goal'] ?? '';
  request.fields['height'] = (userProfile!['height'] ?? 0).toString();
  request.fields['relationship_status'] = userProfile!['relationship_status'] ?? '';
  request.fields['relationship_type'] = userProfile!['relationship_type'] ?? '';
  request.fields['family_orientation'] = userProfile!['family_orientation'] ?? '';
  request.fields['body_type'] = userProfile!['body_type'] ?? '';
  request.fields['hair_color'] = userProfile!['hair_color'] ?? '';
  request.fields['eye_color'] = userProfile!['eye_color'] ?? '';
  request.fields['education_level'] = userProfile!['education_level'] ?? '';
  request.fields['occupation'] = userProfile!['occupation'] ?? '';
  request.fields['industry'] = userProfile!['industry'] ?? '';

  // Add image files with validation
  // Only upload images if they are new and valid
  if (profileImage != null) {
    final file = File(profileImage!);
    if (await file.exists()) {
      request.files.add(await http.MultipartFile.fromPath('profile_picture', profileImage!));
    } else {
      // If the file doesn't exist, use the existing server URL
      request.fields['profile_picture_url'] = userProfile!['profile_picture'] ?? '';
    }
  } else {
    // If no new image is selected, use the existing server URL
    request.fields['profile_picture_url'] = userProfile!['profile_picture'] ?? '';
  }

  if (coverImage != null) {
    final file = File(coverImage!);
    if (await file.exists()) {
      request.files.add(await http.MultipartFile.fromPath('cover_picture', coverImage!));
    } else {
      // If the file doesn't exist, use the existing server URL
      request.fields['cover_picture_url'] = userProfile!['cover_picture'] ?? '';
    }
  } else {
    // If no new image is selected, use the existing server URL
    request.fields['cover_picture_url'] = userProfile!['cover_picture'] ?? '';
  }

  // Detailed logging for debugging
  print('Request URL: ${request.url}');
  print('Request Headers: ${request.headers}');
  print('Request Fields:');
  request.fields.forEach((key, value) {
    print('$key: $value');
  });
  print('Request Files:');
  request.files.forEach((file) {
    print('File Field: ${file.field}, Filename: ${file.filename}');
  });

  try {
    // Add authorization header
    request.headers['Authorization'] = 'Bearer $accessToken';
    request.headers['Content-Type'] = 'multipart/form-data';

    // Send the request
    var response = await request.send();

    // Read the response
    var responseBody = await response.stream.bytesToString();

    print('Response Status Code: ${response.statusCode}');
    print('Response Body: $responseBody');

    // Print the JSON response
    if (response.statusCode == 200 || response.statusCode == 201) {
      var responseData = json.decode(responseBody);
      print('JSON Response: $responseData'); // Print the JSON response

      setState(() {
        userProfile = responseData;
        showErrorSnackBar('Profile updated successfully!');
      });
    } else {
      // Parse and display more detailed error message
      var errorResponse = json.decode(responseBody);
      String errorMessage = errorResponse['error'] ?? 'Unknown error occurred';
      showErrorSnackBar('Error updating profile: $errorMessage');
    }
  } catch (e) {
    print('Exception in saveProfile: $e');
    showErrorSnackBar('An error occurred: $e');
  }
}

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // SliverAppBar for Profile Header
          SliverAppBar(
            expandedHeight: 250,
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
                  // Gradient overlays for depth
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
                                    child: Stack(
                                      children: [
                                        GestureDetector(
                                          onTap: () {
                                            if (userProfile!['profile_picture'] != null) {
                                              showDialog(
                                                context: context,
                                                builder: (context) => Dialog(
                                                  backgroundColor: Colors.transparent,
                                                  child: GestureDetector(
                                                    onTap: () => Navigator.pop(context),
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
                                          child: Container(
                                            width: 100,
                                            height: 100,
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
                                        // Edit Icon for Profile Picture
                                        Positioned(
                                          top: 0,
                                          right: 0,
                                          child: GestureDetector(
                                            onTap: _selectProfileImage,
                                            child: Container(
                                              width: 30,
                                              height: 30,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: Colors.white,
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black26,
                                                    blurRadius: 5,
                                                    spreadRadius: 1,
                                                  ),
                                                ],
                                              ),
                                              child: Icon(Icons.edit, color: Colors.blue, size: 16),
                                            ),
                                          ),
                                        ),
                                      ],
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
                                  GestureDetector(
                                    onTap: _editName,
                                    child: Text(
                                      name ?? 'No Name',
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
                                  ),
                                  SizedBox(height: 4),
                                  GestureDetector(
                                    onTap: _editLocation,
                                    child: Row(
                                      children: [
                                        Icon(Icons.location_on,
                                            color: Colors.white.withOpacity(0.9), size: 16),
                                        SizedBox(width: 4),
                                        Text(
                                          location ?? 'No location set',
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
          // Bio Section
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bio',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: Color.fromARGB(221, 65, 63, 63),
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
                    child: GestureDetector(
                      onTap: _editBio,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: 10),
                          Text(
                            bio ?? 'Tap to add a bio',
                            style: TextStyle(color: Colors.grey[600]),
                            textAlign: TextAlign.right,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 5,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Basic Info Section
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Basic Info',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: Color.fromARGB(221, 65, 63, 63),
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
                      children: basicInfoFields
                          .map((info) {
                            String field = info['field'];
                            IconData icon = info['icon'];
                            String label = info['label'];
                            String value = getDisplayValue(field);
                            Widget row = _buildInfoRow(icon, label, value);
                            if (!nonEditableFields.contains(field)) {
                              return GestureDetector(
                                onTap: () => _handleFieldEdit(field),
                                child: row,
                              );
                            }
                            return row;
                          })
                          .toList()
                          .expand((widget) => [
                                widget,
                                Divider(
                                    height: 20,
                                    color: Colors.grey[300],
                                    thickness: 0.5)
                              ])
                          .toList()
                        ..removeLast(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: saveProfile,
        label: Text(
          'Save',
          style: TextStyle(color: Colors.white),
        ),
        icon: Icon(Icons.save, color: Colors.white),
        backgroundColor: Colors.red,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}

void main() {
  runApp(MaterialApp(home: EditProfileScreen()));
}