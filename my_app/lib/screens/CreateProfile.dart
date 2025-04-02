import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'refresh_helper.dart'; // Import the helper

String baseurl = dotenv.env['BASE_URL'] ?? 'http://default-url.com';

class CreateProfileScreen extends StatefulWidget {
  final String? value;
  // Constructor to accept the passed values
  CreateProfileScreen({this.value});
  @override
  _CreateProfileScreenState createState() => _CreateProfileScreenState();
}

class _CreateProfileScreenState extends State<CreateProfileScreen> {
  // Controllers
  final usernameController = TextEditingController();
  final phoneNumberController = TextEditingController();
  final nameController = TextEditingController();
  final dobController = TextEditingController();
  final bioController = TextEditingController();

  final TextEditingController haircontroller= TextEditingController();
  final TextEditingController eyecontroller=TextEditingController();
  final TextEditingController educationcontroller=TextEditingController();
  final TextEditingController occupationcontroller=TextEditingController();
  final TextEditingController industrycontroller=TextEditingController();
  final TextEditingController heightcontroller=TextEditingController();
  final TextEditingController LanguageSpokencontroller= TextEditingController(); 

  // Variables
  String? selectedGender;
  File? profilePicture;
  int ? minAge;
  int ? maxAge;
  String ? selectedGenderPreference;
  String? selectedRelationshipType;
  File? coverPicture;
  File? videoProfile;
    bool _isLoading = false;
  String? _error;
   String? _username;
  List<Map<String, dynamic>> interests = [];
  List<int> lookingForInterests = [];

  // additoional fields

String? sexualOrientation;
String? languageSpoken;
String? introvertOrExtrovert;
String? smokingHabits;
String? drinkingHabits;
String? relationshipGoal;
double? height;
String? relationshipStatus;
String? familyOrientation;
String? bodyType;
String? userRelationshipType;
String? hairColor;
String? eyeColor;
String? educationLevel;
String? occupation;
String? industry;

  final _apiEndpoint = '$baseurl/auth/create_profile/';

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

  //   Future _fetchUserDetails() async {
  //   setState(() {
  //     _isLoading = true;
  //     _error = null;
  //   });
  //   try {
  //     final prefs = await SharedPreferences.getInstance();
  //     final accessToken = prefs.getString('access_token');
  //     if (accessToken == null) {
  //       setState(() {
  //         _error = "Access token is missing. Please log in again.";
  //         _isLoading = false;
  //       });
  //       return;
  //     }
  //     final response = await http.get(
  //       Uri.parse('${baseurl}/auth/user-details/'),
  //       headers: {
  //         'Authorization': 'Bearer $accessToken',
  //       },
  //     );
  //     if (response.statusCode == 200) {
  //       final data = json.decode(response.body);
  //       if (data['user'] != null) {
  //         setState(() {
  //           _username = data['user']['username'];
  //         });
  //       } else {
  //         setState(() {
  //           _error = "User details not found in response";
  //         });
  //       }
  //     } else {
  //       setState(() {
  //         _error = "Failed to fetch user details. Status: ${response.statusCode}";
  //       });
  //     }
  //   } catch (e) {
  //     setState(() {
  //       _error = "Error fetching user details: $e";
  //     });
  //   } finally {
  //     setState(() {
  //       _isLoading = false;
  //     });
  //   }
  // }

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
    final url = Uri.parse('$baseurl/auth/interests/');
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
Future _createLookingForPreferences() async {
  final prefs = await SharedPreferences.getInstance();
  final accessToken = prefs.getString('access_token');
  if (accessToken == null) {
    setState(() {
      _error = "Access token is missing. Please log in again.";
    });
    return;
  }
  if (selectedGenderPreference == null ||
      minAge == null ||
      maxAge == null ||
      selectedRelationshipType == null ||
      interests.isEmpty) {
    setState(() {
      _error = "Please fill in all partner preference fields and select at least one interest.";
    });
    return;
  }

  try {
    // Fetch user details
    final userDetailsResponse = await http.get(
      Uri.parse('${baseurl}/auth/user-details/'),
      headers: {
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (userDetailsResponse.statusCode == 200) {
      final userDetails = json.decode(userDetailsResponse.body);
      final userId = userDetails['user']['id']; // Extract the user id

      // Prepare payload for looking-for endpoint
      final payload = {
     'user': userId, // Include only the user id
      'gender_preference': selectedGenderPreference,
      'min_age': minAge,
      'max_age': maxAge,
      'relationship_type': selectedRelationshipType,
      'interests': lookingForInterests // Use lookingForInterests instead of selectedInterests 
      };

      print('Sending LookingFor payload: $payload');

      // Send request to looking-for endpoint
      final response = await http.post(
        Uri.parse('${baseurl}/auth/looking-for/'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );

      print('LookingFor Response status: ${response.statusCode}');
      print('LookingFor Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'])),
        );
      } else {
        final errorData = json.decode(response.body);
        setState(() {
          _error = errorData.values.join('\n');
        });
      }
    } else {
      setState(() {
        _error = "Failed to fetch user details.";
      });
    }
  } catch (e) {
    setState(() {
      _error = "Error creating LookingFor preferences: $e";
    });
  }
}

  // Submit Form
Future<void> submitForm() async {
  // Ensure all required fields are filled
  if (usernameController.text.isEmpty || phoneNumberController.text.isEmpty || nameController.text.isEmpty) {
    Fluttertoast.showToast(
      msg: 'Please fill in all required fields',
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
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
  print('Selected Interests: $selectedInterests');
  print('Gender Preferences: $selectedGenderPreference');
  print('min age $minAge');
  print('max_age: $maxAge');
  print('relationship_type: $selectedRelationshipType');
  print('Sexual Orientation: $sexualOrientation');
  print('Language Spoken: $languageSpoken');
  print('Personality Type: $introvertOrExtrovert');
  print('Smoking Habits: $smokingHabits');
  print('Drinking Habits: $drinkingHabits');
  print('Relationship Goal: $relationshipGoal');
  print('Height: $height');
  print('Relationship Status: $relationshipStatus');
  print('Family Orientation: $familyOrientation');
  print('Body Type: $bodyType');
  print('Hair Color: $hairColor');
  print('Eye Color: $eyeColor');
  print('Education Level: $educationLevel');
  print('Occupation: $occupation');
  print('Industry: $industry');

  // Print partner preferences
  print('Partner Preferences:');
  print('Gender Preference: $selectedGenderPreference');
  print('Minimum Age: $minAge');
  print('Maximum Age: $maxAge');
  print('Relationship Type: $selectedRelationshipType');
  print('Interests: $lookingForInterests'); // Ensure this is the correct variable

  var request = http.MultipartRequest('POST', Uri.parse(_apiEndpoint));

  // Populate request fields
  request.fields['username'] = usernameController.text.trim();
  request.fields['phone_number'] = phoneNumberController.text.trim();
  request.fields['name'] = nameController.text.trim();
  request.fields['date_of_birth'] = dobController.text.trim();
  request.fields['gender'] = selectedGender ?? '';
  request.fields['bio'] = bioController.text.trim();
  request.fields['sexual_orientation'] = sexualOrientation ?? '';
  request.fields['language_spoken'] = languageSpoken ?? '';
  request.fields['personality_type'] = introvertOrExtrovert ?? '';
  request.fields['smoking_habits'] = smokingHabits ?? '';
  request.fields['drinking_habits'] = drinkingHabits ?? '';
  request.fields['relationship_goal'] = relationshipGoal ?? '';
  request.fields['height'] = height?.toString() ?? '';
  request.fields['relationship_status'] = relationshipStatus ?? '';
  request.fields['relationship_type'] = userRelationshipType ?? '';
  request.fields['family_orientation'] = familyOrientation ?? '';
  request.fields['body_type'] = bodyType ?? '';
  request.fields['hair_color'] = hairColor ?? '';
  request.fields['eye_color'] = eyeColor ?? '';
  request.fields['education_level'] = educationLevel ?? '';
  request.fields['occupation'] = occupation ?? '';
  request.fields['industry'] = industry ?? '';

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

    if (response.statusCode == 201) {
      Fluttertoast.showToast(
        msg: 'Profile created successfully!',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );

      // Ensure we have the latest tokens before navigation
      final prefs = await SharedPreferences.getInstance();
      final latestAccessToken = prefs.getString('access_token');
      final latestRefreshToken = prefs.getString('refresh_token');
      print("Before checking the toekn");
      if (latestAccessToken != null && latestRefreshToken != null) {
        print("After checking the toekn");
        print("now callning the looking for endpoint");

        // Now submit the partner preferences to the /looking-for endpoint
        await _createLookingForPreferences();

        Navigator.pushReplacementNamed(
          context,
          '/home',
          arguments: {
            'accessToken': latestAccessToken,
            'refreshToken': latestRefreshToken,
          },
        );
      } else {
        throw Exception('Tokens not found after profile creation');
      }
    } else {
      var responseBody = await response.stream.bytesToString();
      print('Error: ${response.statusCode}, Response Body: $responseBody'); // Debugging output
      Fluttertoast.showToast(
        msg: 'Error: $responseBody',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
    }
  } catch (e) {
    print('An error occurred: $e'); // Debugging output
    Fluttertoast.showToast(
      msg: 'An error occurred: $e',
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
    );
  }
}


Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: Colors.transparent, // Set transparent to see SafeArea color
    body: SafeArea(
      child: Container(
        color: const Color.fromARGB(255, 255, 255, 255), // Set background color here
        width: double.infinity, // Ensure full width
        height: MediaQuery.of(context).size.height, // Ensure full height
        padding: EdgeInsets.all(16),
        child: RefreshIndicator(
          onRefresh: _fetchInterests, // Call _fetchInterests when refreshing
          child: SingleChildScrollView(
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
                // Directly use the conditional widget without Flexible
                currentStep == 0
                    ? _buildPersonalInfoSection()
                    : currentStep == 1
                        ? _buildInterestSection()
                    : currentStep == 2
                        ?   _buildAdditionalInfoSection() 
                    : currentStep == 3
                        ?  _buildPreferences()
                    : currentStep == 4
                        ? _buildPreferenceInterestSection()
                        : _buildMediaSection(),
                _buildNavigationButtons(),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
Widget _buildTextFieldWithIcon(
  TextEditingController controller,
  String label,
  IconData icon,
  bool isRequired,
  Function(String) onChanged,
) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Icon(icon, color: Colors.grey[700]),
          SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
      SizedBox(height: 8),
      TextFormField(
        controller: controller,
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.grey[200],
          contentPadding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
          border: OutlineInputBorder(
            borderSide: BorderSide.none,
            borderRadius: BorderRadius.circular(12.0),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide.none,
            borderRadius: BorderRadius.circular(12.0),
          ),
        ),
        onChanged: onChanged,
        validator: isRequired
            ? (value) {
                if (value == null || value.isEmpty) {
                  return '$label is required';
                }
                return null;
              }
            : null,
      ),
    ],
  );
}

Widget _buildDropdownWithIcon(
  String label,
  String? selectedValue,
  List<String> options,
  IconData icon,
  Function(String?) onChanged,
) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Icon(icon, color: Colors.grey[700]),
          SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
      SizedBox(height: 8),
      DropdownButtonFormField<String>(
        value: selectedValue,
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.grey[200],
          contentPadding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
          border: OutlineInputBorder(
            borderSide: BorderSide.none,
            borderRadius: BorderRadius.circular(12.0),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide.none,
            borderRadius: BorderRadius.circular(12.0),
          ),
        ),
        items: options.map((value) {
          return DropdownMenuItem<String>(
            value: value,
            child: Text(value),
          );
        }).toList(),
        onChanged: onChanged,
      ),
    ],
  );
}
Widget _buildAdditionalInfoSection() {
  return SingleChildScrollView(
    child: Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10.0),
              child: Text(
                'Additional Information',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                 color: Color(0xFFE91E63),
                ),
              ),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 5.0),
              child: Text(
                'Provide additional details to help us understand you better.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[700],
                ),
              ),
            ),
          ),
          SizedBox(height: 20),

          // Sexual Orientation
            _buildDropdownWithIcon(
            'Sexual Orientation',
            sexualOrientation,
            [
              'Straight',
              'Gay',
              'Bisexual',
              'Pansexual',
              'Other'
            ],
            Icons.directions_run,
            (value) {
              setState(() {
              sexualOrientation = value;
              });
            },
            ),
          SizedBox(height: 20),

          // Language Spoken
          _buildTextFieldWithIcon(
            LanguageSpokencontroller,
            'Language Spoken',
            Icons.language,
            false,
            (value) {
              languageSpoken = value;
            },
          ),
          SizedBox(height: 20),

          // Personality Type
          _buildDropdownWithIcon(
            'Personality Type',
            introvertOrExtrovert,
            [
              'Introvert',
              'Extrovert',
              'Ambivert'
            ],
            Icons.people,
            (value) {
              setState(() {
                introvertOrExtrovert = value;
              });
            },
          ),
          SizedBox(height: 20),

          // Hair Color
          _buildTextFieldWithIcon(
           haircontroller,
            'Hair Color',
            Icons.brush,
            false,
            (value) {
              hairColor = value;
            },
          ),
          SizedBox(height: 20),

          // Eye Color
          _buildTextFieldWithIcon(
             eyecontroller,
            'Eye Color',
            Icons.remove_red_eye,
            false,
            (value) {
              eyeColor = value;
            },
          ),
          SizedBox(height: 20),

          // Education Level
          _buildTextFieldWithIcon(
           educationcontroller,
            'Education Level',
            Icons.school,
            false,
            (value) {
              educationLevel = value;
            },
          ),
          SizedBox(height: 20),

          // Occupation
          _buildTextFieldWithIcon(
            occupationcontroller,
            'Occupation',
            Icons.work,
            false,
            (value) {
              occupation = value;
            },
          ),
          SizedBox(height: 20),

          // Industry
          _buildTextFieldWithIcon(
            industrycontroller,
            'Industry',
            Icons.business,
            false,
            (value) {
              industry = value;
            },
          ),
          SizedBox(height: 20),

          // Smoking Habits
          _buildDropdownWithIcon(
            'Smoking Habits',
            smokingHabits,
            [
              'Non-smoker',
              'Occasional smoker',
              'Regular smoker'
            ],
            Icons.smoking_rooms,
            (value) {
              setState(() {
                smokingHabits = value;
              });
            },
          ),
          SizedBox(height: 20),

          // Drinking Habits
          _buildDropdownWithIcon(
            'Drinking Habits',
            drinkingHabits,
            [
              'Non-drinker',
              'Occasional drinker',
              'Regular drinker'
            ],
            Icons.local_bar,
            (value) {
              setState(() {
                drinkingHabits = value;
              });
            },
          ),
          SizedBox(height: 20),

          // Relationship Goal
          _buildDropdownWithIcon(
            'Relationship Goal',
            relationshipGoal,
            [
              'Casual dating',
              'Long-term relationship',
              'Friendship',
              'Marriage'
            ],
            Icons.favorite,
            (value) {
              setState(() {
                relationshipGoal = value;
              });
            },
          ),

            SizedBox(height: 10),
        _buildDropdownWithIcon(
          'Relationship Type',
            userRelationshipType,
          [
            'Casual',
            'Serious',
            'Friendship',
            'Marriage',
            'Short-term',
            'Long-term',
            'One-night stand',
            'Any'
          ],
          Icons.favorite,
          (value) {
            setState(() {
              userRelationshipType = value;
            });
          },
        ),
          SizedBox(height: 20),

          // Height
          _buildTextFieldWithIcon(
            heightcontroller,
            'Height (cm)',
            Icons.height,
            false,
            (value) {
              height = double.tryParse(value);
            },
          ),
          SizedBox(height: 20),

          // Relationship Status
          _buildDropdownWithIcon(
            'Relationship Status',
            relationshipStatus,
            [
              'Single',
              'In relationship',
              'Divorced',
              'Widowed',
              'Separated'
            ],
            Icons.favorite_border,
            (value) {
              setState(() {
                relationshipStatus = value;
              });
            },
          ),
          SizedBox(height: 20),

          // Family Orientation
          _buildDropdownWithIcon(
            'Family Orientation',
            familyOrientation,
            [
              'Family-focused',
              'Independent',
              'Balanced'
            ],
            Icons.family_restroom,
            (value) {
              setState(() {
                familyOrientation = value;
              });
            },
          ),
          SizedBox(height: 20),

          // Body Type
          _buildDropdownWithIcon(
            'Body Type',
            bodyType,
            [
              'Slim',
              'Athletic',
              'Average',
              'Curvy',
              'Other'
            ],
            Icons.person,
            (value) {
              setState(() {
                bodyType = value;
              });
            },
          ),
        ],
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
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFE91E63),
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
                  fontSize: 21, // Bigger size for importance
                  fontWeight: FontWeight.bold,
                   color: Color(0xFFE91E63),
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
                            ? Color(0xFFE91E63)
                            : Color.fromARGB(255, 236, 236, 236),
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : Color(0xFFE91E63),
                        ),
                      ),
                    );
                  }).toList(),
                ),
        ],
      ),
    );
  }
Widget _buildPreferences() {
  return SingleChildScrollView(
    child: Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10.0),
              child: Text(
                'Partner Preferences',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                 color: Color(0xFFE91E63),
                ),
              ),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 5.0),
              child: Text(
                'Tell us more about your preferences so we can help you find the perfect match.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[700],
                ),
              ),
            ),
          ),
          SizedBox(height: 20),

          // Gender Preference
          DropdownButtonFormField<String>(
            value: selectedGenderPreference,
            decoration: InputDecoration(
              labelText: 'Gender Preference',
              labelStyle: TextStyle(color: Colors.grey[700]),
              filled: true,
              fillColor: Colors.grey[200],
              contentPadding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
              border: OutlineInputBorder(
                borderSide: BorderSide.none,
                borderRadius: BorderRadius.circular(12.0),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide.none,
                borderRadius: BorderRadius.circular(12.0),
              ),
            ),
            items: ['Male', 'Female', 'Other'].map((gender) {
              return DropdownMenuItem<String>(
                value: gender,
                child: Text(gender),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                selectedGenderPreference = value;
              });
            },
          ),
          SizedBox(height: 20),

          // Min Age
          TextFormField(
            decoration: InputDecoration(
              labelText: 'Minimum Age',
              labelStyle: TextStyle(color: Colors.grey[700]),
              filled: true,
              fillColor: Colors.grey[200],
              contentPadding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
              border: OutlineInputBorder(
                borderSide: BorderSide.none,
                borderRadius: BorderRadius.circular(12.0),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide.none,
                borderRadius: BorderRadius.circular(12.0),
              ),
            ),
            keyboardType: TextInputType.number,
            onChanged: (value) {
              setState(() {
                minAge = int.tryParse(value);
              });
            },
          ),
          SizedBox(height: 20),

          // Max Age
          TextFormField(
            decoration: InputDecoration(
              labelText: 'Maximum Age',
              labelStyle: TextStyle(color: Colors.grey[700]),
              filled: true,
              fillColor: Colors.grey[200],
              contentPadding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
              border: OutlineInputBorder(
                borderSide: BorderSide.none,
                borderRadius: BorderRadius.circular(12.0),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide.none,
                borderRadius: BorderRadius.circular(12.0),
              ),
            ),
            keyboardType: TextInputType.number,
            onChanged: (value) {
              setState(() {
                maxAge = int.tryParse(value);
              });
            },
          ),
          SizedBox(height: 20),

          // Relationship Type
          DropdownButtonFormField<String>(
            value: selectedRelationshipType,
            decoration: InputDecoration(
              labelText: 'Relationship Type',
              labelStyle: TextStyle(color: Colors.grey[700]),
              filled: true,
              fillColor: Colors.grey[200],
              contentPadding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
              border: OutlineInputBorder(
                borderSide: BorderSide.none,
                borderRadius: BorderRadius.circular(12.0),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide.none,
                borderRadius: BorderRadius.circular(12.0),
              ),
            ),
            items: ['Casual', 'Serious', 'Friendship','Marriage','Short-term','Long-term','One-night stand','Any'].map((type) {
              return DropdownMenuItem<String>(
                value: type,
                child: Text(type),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                selectedRelationshipType = value;
              });
            },
          ),
        ],
      ),
    ),
  );
}

Widget _buildPreferenceInterestSection() {
  return SingleChildScrollView(  // Allow scrolling if content overflows
    child: Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween, // Justifies the space between the children
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10.0),
            child: Text(
              'Preferred Interests', // ✨ More engaging heading
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 21, // Bigger size for importance
                fontWeight: FontWeight.bold,
               color: Color(0xFFE91E63),
              ),
            ),
          ),
        ),

        // Paragraph - Centered
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 5.0),
            child: Text(
              'Select the interests you prefer in a partner to help us find better matches.',
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
                  bool isSelected = lookingForInterests.contains(id);

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          lookingForInterests.remove(id);
                        } else {
                          lookingForInterests.add(id);
                        }
                      });
                    },
                    child: Chip(
                      label: Text(name),
                      backgroundColor: isSelected
                          ? Color(0xFFE91E63)
                          : Color.fromARGB(255, 236, 236, 236),
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Color(0xFFE91E63),
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
                fontSize: 21, // Larger font size for more emphasis
                fontWeight: FontWeight.bold,
               color: Color(0xFFE91E63),
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
      children: List.generate(4, (index) {
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
          child: currentStep < 5
              ? OutlinedButton(
                  onPressed: () {
                    setState(() {
                      currentStep++;
                    });
                  },
                    child: Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                     color: Color(0xFFE91E63),// Background color
                    ),
                    child: Icon(
                      Icons.arrow_forward,
                      color: Colors.white, // Icon color
                    ),
                    ),
                    style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.transparent), // No outline
                    ),
                )
              : OutlinedButton(
                  onPressed: () {
                    // Ensure all data is validated and submitted
                      submitForm(); // Call submitForm if validation passes
                  },
                    child: Text('Submit', style: TextStyle(color: Colors.white)),
                    style: OutlinedButton.styleFrom(
                    backgroundColor: Color(0xFFE91E63), // Background color
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
