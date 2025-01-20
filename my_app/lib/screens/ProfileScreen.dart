import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dotted_border/dotted_border.dart';

class ProfileScreen extends StatefulWidget {
  final String? value;
  // Constructor to accept the passed values
  ProfileScreen({this.value});
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Controllers
  final usernameController = TextEditingController();
  final phoneNumberController = TextEditingController();
  final nameController = TextEditingController();
  final dobController = TextEditingController();
  final bioController = TextEditingController();

  // Variables
  String? selectedGender;
  File? profilePicture;
  File? coverPicture;
  File? videoProfile;
  List<Map<String, dynamic>> interests = [];

  final _apiEndpoint = 'http://192.168.1.76:8000/auth/create_profile/';

  // Shared Preferences
  SharedPreferences? prefs;
  String? accessToken;
  String? refreshToken;

  int currentStep = 0; // Track the current step in the multi-step form

  // Update the interests declaration to store both id and name
  List<int> selectedInterests = []; // Store just the IDs of selected interests

  @override
  void initState() {
    super.initState();
    // Set the value of usernameController to widget.value if it's not null
    if (widget.value != null) {
      usernameController.text = widget.value!;
    }
    _loadTokens().then((_) {
      _fetchInterests();  // Fetch the interests after tokens are loaded
    });
  }

  // Fetch tokens from SharedPreferences
  Future<void> _loadTokens() async {
    prefs = await SharedPreferences.getInstance();
    accessToken = prefs?.getString('access_token');
    refreshToken = prefs?.getString('refresh_token');
    print('Access Token: $accessToken');
    print('Refresh Token: $refreshToken');

    if (accessToken == null || refreshToken == null) {
      // If tokens are missing, show an error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Access token or refresh token is missing')),
      );
    }
  }

  // Fetch interest names from the correct endpoint
  Future<void> _fetchInterests() async {
    // Ensure the token is loaded before proceeding
    if (accessToken == null) {
      print('Access token not found');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Access token is missing')),
      );
      return;
    }

    // Check if the URL is valid
    final url = Uri.parse('http://192.168.1.76:8000/auth/interests/');
    if (url.isAbsolute == false) {
      print('Invalid URL');
      return;
    }

    print('Access Token: $accessToken'); // Debugging access token

    try {
      // Sending the GET request with authorization headers
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $accessToken', // Add authorization token
        },
      );

      if (response.statusCode == 200) {
        var data = json.decode(response.body);
        setState(() {
          interests = List<Map<String, dynamic>>.from(data.map((item) => {
                'id': item['id'], // Store ID as integer
                'name': item['name'],
              }));
        });
      } else {
        // Handle non-200 response
        print('Error: ${response.statusCode}, Response Body: ${response.body}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load interests: ${response.statusCode}')),
        );
      }
    } catch (e) {
      // Handle error in case of network issues or other exceptions
      print('Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred while fetching interests')),
      );
    }
  }

  // Image Picker
  Future<void> pickImage(ImageSource source, Function(File) onImagePicked) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);
    if (pickedFile != null) {
      onImagePicked(File(pickedFile.path));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No image selected')),
      );
    }
  }

  // Video Picker
  Future<void> pickVideo(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickVideo(source: source);
    if (pickedFile != null) {
      setState(() {
        videoProfile = File(pickedFile.path);
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No video selected')),
      );
    }
  }

  // Submit Form
  Future<void> submitForm() async {
    // Ensure all required fields are filled
    if (usernameController.text.isEmpty || phoneNumberController.text.isEmpty || nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please fill in all required fields')),
      );
      return; // Exit if validation fails
    }

    // Debugging output to check values before submission
    print('Username: ${usernameController.text}');
    print('Phone Number: ${phoneNumberController.text}');
    print('Name: ${nameController.text}');
    print('Date of Birth: ${dobController.text}');
    print('Gender: $selectedGender');
    print('Bio: ${bioController.text}');
    print('Selected Interests: $selectedInterests'); // Ensure this is populated

    var request = http.MultipartRequest('POST', Uri.parse(_apiEndpoint));

    // Populate request fields
    request.fields['username'] = usernameController.text.trim();
    request.fields['phone_number'] = phoneNumberController.text.trim();
    request.fields['name'] = nameController.text.trim();
    request.fields['date_of_birth'] = dobController.text.trim();
    request.fields['gender'] = selectedGender ?? '';
    request.fields['bio'] = bioController.text.trim();

    // Add interests to request
    if (selectedInterests.isNotEmpty) {
      request.fields['interests'] = selectedInterests.join(','); // Ensure IDs are sent
    }

    // Add files to the request if they exist
    if (profilePicture != null) {
        request.files.add(await http.MultipartFile.fromPath(
            'profile_picture', profilePicture!.path));
    }
    if (coverPicture != null) {
        request.files.add(await http.MultipartFile.fromPath(
            'cover_picture', coverPicture!.path));
    }
    if (videoProfile != null) {
        request.files.add(await http.MultipartFile.fromPath(
            'video_profile', videoProfile!.path));
    }

    try {
        request.headers['Authorization'] = 'Bearer $accessToken';
        var response = await request.send();

        // Handle response
        if (response.statusCode == 201) {
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Profile created successfully!')),
            );
            Navigator.pushReplacementNamed(context, '/home');
        } else {
            var responseBody = await response.stream.bytesToString();
            print('Error: ${response.statusCode}, Response Body: $responseBody'); // Debugging output
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error: $responseBody')),
            );
        }
    } catch (e) {
        print('An error occurred: $e'); // Debugging output
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('An error occurred: $e')),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Cover Image Section
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.bottomCenter,
              children: [
                // Cover Image
                Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    image: coverPicture != null
                        ? DecorationImage(
                            image: FileImage(coverPicture!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: coverPicture == null
                      ? Center(
                          child: IconButton(
                            icon: Icon(Icons.add_a_photo, size: 30),
                            onPressed: () => pickImage(
                              ImageSource.gallery,
                              (image) => setState(() => coverPicture = image),
                            ),
                          ),
                        )
                      : null,
                ),
                // Profile Picture
                Positioned(
                  bottom: -50,
                  child: GestureDetector(
                    onTap: () => pickImage(
                      ImageSource.gallery,
                      (image) => setState(() => profilePicture = image),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white,
                          width: 4,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.grey[300],
                        backgroundImage: profilePicture != null
                            ? FileImage(profilePicture!)
                            : null,
                        child: profilePicture == null
                            ? Icon(Icons.add_a_photo, size: 30)
                            : null,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            
            SizedBox(height: 60), // Space for profile picture overflow
            
            // Name and Bio Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  // Name Field
                  TextField(
                    controller: nameController,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Your Name',
                      border: InputBorder.none,
                    ),
                  ),
                  
                  SizedBox(height: 10),
                  
                  // Bio Field
                  TextField(
                    controller: bioController,
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                    decoration: InputDecoration(
                      hintText: 'Write something about yourself...',
                      border: InputBorder.none,
                    ),
                  ),
                ],
              ),
            ),
            
            SizedBox(height: 20),
            
            // Interests Section
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Interests',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: interests.map((interest) {
                      final id = interest['id'] as int;
                      final name = interest['name'] as String;
                      bool isSelected = selectedInterests.contains(id);

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              selectedInterests.remove(id);
                            } else {
                              selectedInterests.add(id);
                            }
                          });
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Theme.of(context).primaryColor
                                : Colors.grey[200],
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            name,
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            
          
          ],
        ),
      ),
    );
  }
}