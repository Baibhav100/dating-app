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
      backgroundColor: Colors.transparent, // Set transparent to see SafeArea color
      body: SafeArea(
        child: Container(
          color: const Color.fromARGB(255, 255, 255, 255), // Set background color here
          width: double.infinity, // Ensure full width
          height: MediaQuery.of(context).size.height, // Ensure full height
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              // Show previous arrow only if we're not on the first step
              if (currentStep > 0)
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back),
                      onPressed: () {
                        setState(() {
                          currentStep--; // Move back to the previous section
                        });
                      },
                    ),
                  ],
                ),
              Expanded(
                child: currentStep == 0
                    ? _buildPersonalInfoSection()
                    : currentStep == 1
                        ? _buildInterestSection()
                        : _buildMediaSection(),
              ),
              _buildNavigationButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPersonalInfoSection() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0), // Adds padding around the content
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10.0),
                child: Text(
                  'Personal Information',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 29,
                    fontWeight: FontWeight.bold,
                    color: const Color.fromARGB(221, 207, 59, 116),
                  ),
                ),
              ),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 5.0),
                child: Text(
                  'Provide your personal details to help us personalize your profile and enhance your experience on our platform.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[700],
                  ),
                ),
              ),
            ),
            _buildTextField(usernameController, 'Username', true, isEditable: false),
            _buildTextField(phoneNumberController, 'Phone Number', true),
            _buildTextField(nameController, 'Name', true),
            _buildTextField(dobController, 'Date of Birth (YYYY-MM-DD)', true, isDateField: true),
            _buildDropdown('Gender', selectedGender, ['Male', 'Female', 'Other']),
            _buildTextField(bioController, 'Bio', false),
          ],
        ),
      ),
    );
  }

  // Interests Section
  Widget _buildInterestSection() {
    return SingleChildScrollView(  // Allow scrolling if content overflows
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween, // Justifies the space between the children
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10.0),
              child: Text(
                'Your Interests', // ✨ More engaging heading
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 29, // Bigger size for importance
                  fontWeight: FontWeight.bold,
                  color: const Color.fromARGB(221, 207, 59, 116),
                ),
              ),
            ),
          ),

          // Paragraph - Centered
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 5.0),
              child: Text(
                'Tell us more about your interests so we can personalize '
                'your experience and show you relevant content.',
                textAlign: TextAlign.justify, // Justifies the text
                style: TextStyle(
                  fontSize: 16, // Readable size
                  color: Colors.grey[700], // Softer text color
                ),
              ),
            ),
          ),
          SizedBox(height: 10),
          interests.isEmpty
              ? Text('No interests found')
              : Wrap(
                  spacing: 8.0,
                  runSpacing: 4.0,
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
                      child: Chip(
                        label: Text(name),
                        backgroundColor: isSelected
                            ? const Color.fromARGB(255, 177, 33, 93)
                            : Color.fromARGB(255, 236, 236, 236),
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : const Color.fromARGB(255, 172, 62, 95),
                        ),
                      ),
                    );
                  }).toList(),
                ),
        ],
      ),
    );
  }

  // Media Section
  Widget _buildMediaSection() {
    return Column(
      children: [
        // Eye-catching heading
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20.0),
          child: Center(
            child: Text(
              'Media Uploads', // The heading
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 32, // Larger font size for more emphasis
                fontWeight: FontWeight.bold,
                color: Color.fromARGB(221, 207, 59, 116), // Vibrant color
              ),
            ),
          ),
        ),
        
        // Attractive paragraph
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
          child: Center(
            child: Text(
              'Upload your profile and cover pictures to make your profile stand out. You can also upload a video to introduce yourself. Choose media that best represents you and your personality!',
              textAlign: TextAlign.center, // Centers text
              style: TextStyle(
                fontSize: 16, // Readable size
                color: Colors.grey[700], // Softer text color for better readability
              ),
            ),
          ),
        ),

        // Image and video upload components
        _buildImageUploadRow('Profile Picture', profilePicture, (image) {
          setState(() {
            profilePicture = image;
          });
        }),
        _buildImageUploadRow('Cover Picture', coverPicture, (image) {
          setState(() {
            coverPicture = image;
          });
        }),
        _buildVideoUploadRow(),
      ],
    );
  }

  // Next/Back Buttons
  Widget _buildNavigationDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) {
        return Container(
          margin: EdgeInsets.symmetric(horizontal: 4.0),
          height: 10.0,
          width: 10.0,
          decoration: BoxDecoration(
            color: currentStep == index ? Colors.pink : Colors.grey,
            shape: BoxShape.circle,
          ),
        );
      }),
    );
  }

  // Update the navigation buttons section.
  Widget _buildNavigationButtons() {
    return Stack(
      children: [
        // Center the dots in the column
        Align(
          alignment: Alignment.center,
          child: _buildNavigationDots(),
        ),
        // Align the button at the bottom right
        Align(
          alignment: Alignment.bottomRight,
          child: currentStep < 2
              ? OutlinedButton(
                  onPressed: () {
                    setState(() {
                      currentStep++;
                    });
                  },
                  child: Text('Next'),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: const Color.fromARGB(221, 207, 59, 116)), // Outline color
                  ),
                )
              : OutlinedButton(
                  onPressed: () {
                    // Ensure all data is validated and submitted
                      submitForm(); // Call submitForm if validation passes
                  },
                  child: Text('Submit'),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: const Color.fromARGB(221, 207, 59, 116)), // Outline color
                  ),
                ),
        ),
      ],
    );
  }

  // Helper method to build text input fields
  Future<void> _selectDate(BuildContext context, TextEditingController controller) async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900), // Earliest selectable date
      lastDate: DateTime.now(), // Latest selectable date
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: const Color.fromARGB(221, 207, 59, 116), // Header background color
            colorScheme: ColorScheme.light(
              primary: const Color.fromARGB(221, 207, 59, 116), // Selected date color
            ),
            buttonTheme: ButtonThemeData(
              textTheme: ButtonTextTheme.primary, // Button text color
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );

    // Update the text field with the selected date
    if (pickedDate != null) {
      controller.text = "${pickedDate.year}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')}";
    }
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    bool isRequired, {
    bool isEditable = true,
    bool isDateField = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        readOnly: isDateField || !isEditable,
        onTap: isDateField
            ? () async {
                await _selectDate(context, controller);
              }
            : null,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: Colors.grey[700], // Light label color
          ),
          filled: true,
          fillColor: Colors.grey[200], // Light background color
          contentPadding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
          border: OutlineInputBorder(
            borderSide: BorderSide.none, // Removes the border
            borderRadius: BorderRadius.circular(12.0), // Rounded corners
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide.none, // No outline on focus
            borderRadius: BorderRadius.circular(12.0),
          ),
          errorBorder: OutlineInputBorder(
            borderSide: BorderSide.none, // Removes error border
            borderRadius: BorderRadius.circular(12.0),
          ),
          disabledBorder: OutlineInputBorder(
            borderSide: BorderSide.none, // Removes disabled border
            borderRadius: BorderRadius.circular(12.0),
          ),
        ),
        validator: isRequired
            ? (value) {
                if (value == null || value.isEmpty) {
                  return '$label is required';
                }
                return null;
              }
            : null,
      ),
    );
  }

  // Helper method to build dropdown menu
  Widget _buildDropdown(String label, String? selectedValue, List<String> options) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.0),
      child: DropdownButtonFormField<String>(
        decoration: InputDecoration(labelText: label),
        value: selectedValue,
        onChanged: (newValue) {
          setState(() {
            selectedGender = newValue;
          });
        },
        items: options.map((value) {
          return DropdownMenuItem<String>(
            value: value,
            child: Text(value),
          );
        }).toList(),
      ),
    );
  }

  // Helper method to build image upload row
  Widget _buildImageUploadRow(String label, File? image, Function(File) onImagePicked) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          image == null
              ? DottedBorder(
                  borderType: BorderType.RRect,
                  radius: Radius.circular(8),
                  padding: EdgeInsets.all(8),
                  color: Colors.grey,
                  strokeWidth: 2,
                  child: Container(
                    width: 50,
                    height: 50,
                    alignment: Alignment.center,
                    child: IconButton(
                      icon: Icon(Icons.add, color: Colors.grey),
                      onPressed: () => pickImage(ImageSource.gallery, onImagePicked),
                    ),
                  ),
                )
              : Image.file(image, width: 50, height: 50, fit: BoxFit.cover),
          IconButton(
            icon: Icon(Icons.upload_file),
            onPressed: () => pickImage(ImageSource.gallery, onImagePicked),
          ),
          Text(label),
        ],
      ),
    );
  }

  // Helper method to build video upload row
  Widget _buildVideoUploadRow() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          videoProfile == null
              ? Icon(Icons.video_library, size: 50)
              : Icon(Icons.check_circle, color: Colors.green, size: 50),
          IconButton(
            icon: Icon(Icons.upload_file),
            onPressed: () => pickVideo(ImageSource.gallery),
          ),
          Text('Video Profile'),
        ],
      ),
    );
  }
}
