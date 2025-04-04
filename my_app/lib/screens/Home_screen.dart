import 'dart:ui';
import 'package:photo_view/photo_view.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'package:http/http.dart' as http;
// ignore: unused_import
import 'ProfileScreen.dart';
import 'Welcome.dart';
import 'Boosted_profiles.dart';
import 'login_screen.dart';
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'refresh_helper.dart'; // Import the helper
import 'EditProfile.dart';
import 'package:my_app/screens/add_credits_screen.dart';
import 'ChatListScreen.dart';
import 'package:flutter/services.dart';  // Add this import at the top
import 'package:my_app/screens/UserProfileScreen.dart';
import 'premium.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'notification.dart';
import 'package:flutter_animated_dialog_updated/flutter_animated_dialog.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:fluttertoast/fluttertoast.dart';


String baseurl = dotenv.env['BASE_URL'] ?? 'http://default-url.com';


const Color primaryColor = Color(0xFFE91E63); // Vibrant pink
const Color secondaryColor = Color(0xFF81C784); // Soft pastel green
const Color accentColor = Color(0xFFFFEB3B); // Bright yellow
const Color backgroundColor = Color(0xFFF5F5F5); // Light neutral background
const Color textColor = Color(0xFF333333); // Dark text color

class HomePage extends StatefulWidget {
  final String? accessToken;
  final String? refreshToken;

  const HomePage({super.key, this.accessToken, this.refreshToken});

  @override
  State<HomePage> createState() => _HomePageState();
}

typedef CardSwiperOnSwipe = void Function(int previousIndex, int currentIndex, CardSwiperDirection direction);

class _HomePageState extends State<HomePage>with
SingleTickerProviderStateMixin {
   late TabController _tabController;
  int _currentIndex = 0;
  int _currentUserId=0;
  bool _isLoading = false;
  String? _error;
  bool isIncognitoModeEnabled=false;
  // Filter values
  double _age = 18;
  double _distance = 5;

  // Add token variables
  SharedPreferences? prefs;
  String? accessToken;
  String? refreshToken;
bool _isSwipingRight = false;
bool _isSwipingLeft = false;

  // Add variables to store user details
  String? _userName;
  String? _userEmail;
  String? _profilePicture;
  int? _creditScore;// Initialize with a default value
    Map<int, String> allInterests = {};

  // Function to fetch matches from the API


  // welcome bonus
  bool _hasCheckedBonus = false; // New flag to track if bonus check has been done
bool _showWelcomeBonusModal = false;
bool _isCheckingBonus = true;
bool _showGifAnimation = true;

// .....................................................
Future<void> _checkWelcomeBonus() async {
  if (_hasCheckedBonus) return; // Exit early if already checked

  setState(() {
    _isCheckingBonus = true;
  });

  try {
    final response = await _authenticatedRequest(
      '$baseurl/auth/credit-logs/',
      'GET',
    );

    if (response.statusCode == 200) {
      List<dynamic> creditLogs = json.decode(response.body);
      bool hasWelcomeBonus = creditLogs.any((log) => log['reason'] == 'Welcome Bonus');

      setState(() {
        _showWelcomeBonusModal = !hasWelcomeBonus;
        _isCheckingBonus = false;
        _hasCheckedBonus = true; // Mark as checked
      });
    } else {
      setState(() {
        _isCheckingBonus = false;
        _hasCheckedBonus = true; // Mark as checked even on failure
      });
      print('Failed to check welcome bonus: ${response.statusCode}');
    }
  } catch (e) {
    setState(() {
      _isCheckingBonus = false;
      _hasCheckedBonus = true; // Mark as checked even on failure
    });
    print('Error checking welcome bonus: $e');
  }
}


Future<void> _claimWelcomeBonus() async {
  if (_currentUserId == 0) {
    print('User ID is not loaded yet');
    return;
  }

  try {
    final response = await _authenticatedRequest(
      '$baseurl/auth/add-welcome-bonus/',
      'POST',
      body: jsonEncode({'user_id': _currentUserId}),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = json.decode(response.body);
      print(data['message']);

      // Update credit score
      await _fetchCreditScore();
      
      // Hide the modal and mark as checked
      setState(() {
        _showWelcomeBonusModal = false;
        _hasCheckedBonus = true;
      });

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(data['message'])),
      );
    } else {
      print('Failed to claim welcome bonus: ${response.statusCode}');
      print('Response body: ${response.body}');
    }
  } catch (e) {
    print('Error claiming welcome bonus: $e');
  }
}


// .........................................

Future<void> _fetchMatches() async {
  setState(() {
    _isLoading = true; // Start loading
  });

  try {
    if (accessToken == null) {
      await _loadTokens();
      if (accessToken == null) {
        throw Exception('Access token not available');
      }
    }

    final response = await _authenticatedRequest(
      '$baseurl/auth/connections/',
      'GET',
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        _matches = data['matches'] ?? [];
        _isLoading = false; // Stop loading
      });
    } else {
      print('Failed to load matches: ${response.statusCode}');
      throw Exception('Failed to load matches');
    }
  } catch (e) {
    print('Error fetching matches: $e');
    setState(() {
      _isLoading = false; // Stop loading
    });
    throw Exception('Failed to load matches');
  }
}

  // Add token loading function
  Future<void> _loadTokens() async {
    try {
      prefs = await SharedPreferences.getInstance();
      accessToken = prefs?.getString('access_token');
      print('Access Token: $accessToken');
      refreshToken = prefs?.getString('refresh_token');

      if (accessToken == null && refreshToken != null) {
        // Try to refresh the token
        try {
          accessToken = await _refreshAccessToken(refreshToken!);
          await prefs?.setString('access_token', accessToken!);
        } catch (e) {
          print('Error refreshing token: $e');
          // Token refresh failed, user needs to login again
          await _logout();
        }
      }
    } catch (e) {
      print('Error loading tokens: $e');
      throw Exception('Failed to load authentication tokens');
    }
  }


  // credit scores

  Future<void> _fetchCreditScore() async {
  try {
    final response = await _authenticatedRequest(
      '$baseurl/auth/user-credits/',
      'GET',
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        _creditScore = data['total_credits']; // Update the credit score
      });
    } else {
      print('Failed to fetch credit score: ${response.statusCode}');
    }
  } catch (e) {
    print('Error fetching credit score: $e');
  }
}

  Future<String> _refreshAccessToken(String refreshToken) async {
    try {
      final response = await http.post(
        Uri.parse('$baseurl/api/token/refresh/'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'refresh': refreshToken}), // Changed from refresh_token to refresh
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final newAccessToken = data['access'];
        await prefs?.setString('access_token', newAccessToken);
        return newAccessToken;
      } else if (response.statusCode == 401) {
        // Refresh token is invalid/expired
        await _logout(); // Force logout
        throw Exception('Session expired. Please login again.');
      } else {
        throw Exception('Failed to refresh token: ${response.statusCode}');
      }
    } catch (e) {
      print('Error refreshing token: $e');
      rethrow;
    }
  }

  // Helper method to handle API calls with token refresh
  Future<http.Response> _authenticatedRequest(
    String url,
    String method, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    try {
      if (accessToken == null) {
        await _loadTokens();
      }

      final Map<String, String> requestHeaders = {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
        ...?headers,
      };

      late http.Response response;
      switch (method.toUpperCase()) {
        case 'GET':
          response = await http.get(Uri.parse(url), headers: requestHeaders);
          break;
        case 'POST':
          response = await http.post(Uri.parse(url), headers: requestHeaders, body: body);
          break;
        case 'DELETE':
          response = await http.delete(Uri.parse(url), headers: requestHeaders);
          break;
        default:
          throw Exception('Unsupported HTTP method: $method');
      }

      if (response.statusCode == 401) {
        // Token expired, try refreshing
        if (refreshToken != null) {
          accessToken = await _refreshAccessToken(refreshToken!);
          // Retry the request with new token
          requestHeaders['Authorization'] = 'Bearer $accessToken';
          return _authenticatedRequest(url, method, headers: headers, body: body);
        } else {
          await _logout();
          throw Exception('Authentication failed. Please login again.');
        }
      }

      return response;
    } catch (e) {
      print('Error in authenticated request: $e');
      rethrow;
    }
  }

  // Function to fetch user details from the API
  Future<void> _fetchUserDetails() async {
    try {
      final response = await _authenticatedRequest(
        '$baseurl/auth/my-profile/',
        'GET',
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _userName = data['name'];
          _profilePicture = data['profile_picture'];
        });
      } else {
        throw Exception('Failed to load user details');
      }
    } catch (e) {
      print('Error fetching user details: $e');
    }
  }

  // Call this function in your initState or wherever appropriate
  List<dynamic> _matches = [];

  int? _loggedInUserId;

  Future<void> _initLoggedInUserId() async {
    _loggedInUserId = await _fetchLoggedInUserId();
  }

@override
void initState() {
  super.initState();
  fetchInterests();
  _loadIncognitoMode();
  _tabController = TabController(length: 3, vsync: this);

  if (widget.accessToken != null && widget.refreshToken != null) {
    accessToken = widget.accessToken;
    refreshToken = widget.refreshToken;
  } else {
    _loadTokens();
  }

  _fetchUserDetails().then((_) async {
    await _fetchMatches();
    await _fetchCreditScore();
    await _checkWelcomeBonus(); // Check welcome bonus after user details are loaded
  });
  fetchCurrentUserId();
}

  // incognito mode
Future<void> _loadIncognitoMode() async {
  try {
    final accessToken = await _getAccessToken();
    if (accessToken == null) {
      throw Exception('Access token not found');
    }
    bool incognitoActive = await checkIncognitoMode(accessToken);
    setState(() {
      isIncognitoModeEnabled = incognitoActive;
    });
  } catch (error) {
    print('Error loading incognito mode: $error');
  }
}
// checking the incognito mode
Future<bool> checkIncognitoMode(String accessToken) async {
  final response = await http.get(
    Uri.parse('http://192.168.1.241:8000/auth/incognito/'),
    headers: {
      'Authorization': 'Bearer $accessToken',
    },
  );

  if (response.statusCode == 200) {
    final data = json.decode(response.body);
    return data['incognito_active'] ?? false;
  } else {
    throw Exception('Failed to load incognito mode status');
  }
}

// update the incognito mode
Future<void> updateIncognitoMode(bool active, String accessToken, BuildContext context) async {
  final response = await http.put(
    Uri.parse('http://192.168.1.241:8000/auth/incognito/'),
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $accessToken',
    },
    body: json.encode({'active': active}),
  );

  if (response.statusCode == 403) {
    final data = json.decode(response.body);
    if (data['error'] == "You don't have incognito mode privileges in any of your active plans. Please upgrade.") {
      // Show a popup to the user
      _showSubscriptionRequiredDialog(context);
    }
  } else if (response.statusCode != 200) {
    throw Exception('Failed to update incognito mode');
  }
}

void _showSubscriptionRequiredDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (BuildContext context) => AlertDialog(
      backgroundColor: Colors.transparent, // Make the AlertDialog background transparent
      content: Container(
        width: double.maxFinite,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black87, // Darker color at the top
              Colors.grey.shade800, // Lighter color at the bottom
            ],
          ),
          borderRadius: BorderRadius.circular(16), // Rounded corners
        ),
        
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 16), // Add some space at the top
            Image.asset(
    'assets/incognito.png',
    color: const Color.fromARGB(255, 255, 255, 255),
    width: 24,
    height: 24,
  ),
            SizedBox(height: 16), // Add some space below the icon
            Text(
              'Subscription Required',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16), // Add some space below the title
            Text(
              'You have not subscribed to any plans. Please subscribe in order to enable incognito mode.',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24), // Add some space below the content
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                'OK',
                style: TextStyle(
                  color: Colors.blue,
                  fontSize: 18,
                ),
              ),
            ),
            SizedBox(height: 16), // Add some space at the bottom
          ],
        ),
      ),
    ),
  );
}

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LoginScreen()),
    );
  }

  // Function to show the filter bottom sheet
void _showFilterScreen() async {
  // Check current permission status first
  PermissionStatus currentStatus = await Permission.location.status;
  print('Current location permission status: $currentStatus');

  // Request location permission
  PermissionStatus status = await Permission.location.request();
  print('After request, location permission status: $status');
  
  if (status.isGranted) {
    print('Location permission is granted, updating location...');
    await updateUserLocation(); // Update location when permission is granted
    
    // Show filter screen after location is updated
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        double localAge = _age; // Create local copies of the state variables
        double localDistance = _distance;

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: StatefulBuilder(
            builder: (BuildContext context, StateSetter setModalState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Filter Options',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Interested In dropdown
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Interested In'),
                    items: ['Casual dating','Serious Relationship', 'Friendship']
                        .map((String value) {
                      return DropdownMenuItem<String>(
                          value: value, child: Text(value));
                    }).toList(),
                    onChanged: (String? value) {
                      // Handle the change
                    },
                  ),
                  const SizedBox(height: 16),

                  // Age Slider
                  const Text(
                    'Age',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  Slider(
                    value: localAge,
                    min: 18,
                    max: 100,
                    divisions: 82,
                    label: localAge.round().toString(),
                    onChanged: (double value) {
                      setModalState(() {
                        localAge = value;
                      });
                    },
                  ),
                  Text(
                    'Age: ${localAge.round()} years',
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 16),

                  // Distance Slider
                  const Text(
                    'Distance (in km)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  Slider(
                    value: localDistance,
                    min: 1,
                    max: 100,
                    divisions: 100,
                    label: localDistance.round().toString(),
                    onChanged: (double value) {
                      setModalState(() {
                        localDistance = value;
                      });
                    },
                  ),
                  Text(
                    'Distance: ${localDistance.round()} km',
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 16),

                  // Apply filter button
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        // Update the parent state
                        _age = localAge;
                        _distance = localDistance;
                      });
                      Navigator.pop(context); // Close the filter screen
                    },
                    child: const Text('Apply Filter'),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  } else {
    print('Location permission denied, showing permission dialog');
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Location Permission Required'),
          content: const Text(
            'We need location permission to show you matches in your area. Please grant location permission to use filters.'
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => openAppSettings(),
              child: const Text('Open Settings'),
            ),
          ],
        );
      },
    );
  }
}

// Inside your build method
final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

@override
Widget build(BuildContext context) {
  return WillPopScope(
    onWillPop: () async {
      // Show a confirmation dialog
      bool? shouldPop = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Exit App'),
          content: Text('Do you want to exit the app?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('No'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(true);
                SystemNavigator.pop();  // This will close the app
              },
              child: Text('Yes'),
            ),
          ],
        ),
      );
      return shouldPop ?? false;
    },
    child: Scaffold(
      backgroundColor: Colors.white,
      key: _scaffoldKey, // Add the scaffold key
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
                : IndexedStack(
                    index: _currentIndex,
                    children: [
                      // Home screen with refresh
                      RefreshIndicator(
                        onRefresh: () async {
                          await RefreshHelper.onHomeRefresh(context); // Call refresh logic for home
                          // You can also add other home-specific refresh logic here if needed
                          await _fetchUserDetails();
                          await _fetchMatches();
                          await _fetchCreditScore();
                        },
                        child: _buildHomeScreen(),
                      ),
                      // Matches screen with refresh
                   

                        RefreshIndicator(
                        onRefresh: () => RefreshHelper.onMatchesRefresh(context),
                        child: _buildMatchesScreen(),
                      ),

                         RefreshIndicator(
                        onRefresh: () => RefreshHelper.onMatchesRefresh(context),
                        child: _buildVIPContent(),
                      ),
                      // Chat screen with refresh
                      RefreshIndicator(
                        onRefresh: () => RefreshHelper.onChatRefresh(context),
                        child: _buildChatScreen(),
                      ),
                      // Profile screen with refresh
                      RefreshIndicator(
                        onRefresh: () => RefreshHelper.onProfileRefresh(context),
                        child: ProfileScreen(),
                      ),
                    ],
                  ),
      ),
      bottomNavigationBar: Container(
        height: 56, // Set the desired height for the BottomNavigationBar
        child: BottomNavigationBar(
          items: [
            BottomNavigationBarItem(
              icon: _buildAnimatedIcon(Icons.favorite, 0),
              label: '', // Remove the label
            ),
            BottomNavigationBarItem(
              icon: Stack(
                children: [
                  _buildAnimatedIcon(Icons.people, 1),
                  // Notification badge for new matches
                ],
              ),
              label: '', // Remove the label
            ),
                BottomNavigationBarItem(
              icon: Stack(
                children: [
                   _buildAnimatedIcon(Icons.star, 2),
                  // Notification badge for new matches
                ],
              ),
              label: '', // Remove the label
            ),
            
            
            BottomNavigationBarItem(
              icon: Stack(
                children: [
                  _buildAnimatedIcon(Icons.chat_bubble, 3),
                  // Notification badge for unread messages
                ],
              ),
              label: '', // Remove the label
            ),
            BottomNavigationBarItem(
              icon: _buildAnimatedIcon(Icons.person, 4),
              label: '', // Remove the label
            ),
          ],
          currentIndex: _currentIndex,
          selectedItemColor: Colors.red,
          unselectedItemColor: const Color.fromARGB(255, 52, 49, 49),
          selectedFontSize: 0,
          unselectedFontSize: 0,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          iconSize: 23, // Ensure all icons are the same size
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
        ),
      ),

    ),
  );
}
void _showSettingsBottomSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.9 - MediaQuery.of(context).padding.bottom,
            child: Scaffold(
              appBar: AppBar(
                leading: IconButton(
                  icon: Icon(Icons.arrow_back_ios, color: Colors.pinkAccent),
                  onPressed: () => Navigator.pop(context),
                ),
                title: Text(
                  'Discover Settings',
                  style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
                ),
                backgroundColor: const Color.fromARGB(255, 255, 255, 255),
              ),
              body: ListView(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                children: [
                  ListTile(
                    leading: Icon(Icons.person, color: primaryColor),
                    title: Text('Edit Profile', style: TextStyle(color: textColor)),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EditProfileScreen(),
                        ),
                      );
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.credit_card, color: primaryColor),
                    title: Text('Add Credits', style: TextStyle(color: textColor)),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => AddCreditsScreen()),
                      );
                    },
                  ),
                  // ListTile(
                  //   leading: Icon(Icons.favorite, color: primaryColor),
                  //   title: Text('Likes & Matches', style: TextStyle(color: textColor)),
                  //   onTap: () {
                  //     // Navigate to Likes & Matches Screen
                  //   },
                  // ),
                  ListTile(
                    leading: Icon(Icons.people, color: primaryColor),
                    title: Text('Preferences', style: TextStyle(color: textColor)),
                    onTap: () {
                      // Navigate to Preferences Screen
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.notifications,  color: Color(0xFFE91E63),),
                    title: Text('Notification settings', style: TextStyle(color: textColor)),
                    onTap: () {
                     _showOptionBottomSheet(context, 'notifications'); // Navigate to Notifications Screen
                    },
                  ),
                              ListTile(
                  leading: Image.asset(
                    'assets/incognito.png',
                    color: primaryColor,
                    width: 24,
                    height: 24,
                  ),
                  title: Text('Incognito mode', style: TextStyle(color: textColor)),
                  trailing: Switch(
                    value: isIncognitoModeEnabled,
                    onChanged: (bool value) async {
                      try {
                        // Fetch the current access token
                        String? accessToken = await _getAccessToken();
                        if (accessToken == null) {
                          throw Exception('Access token not found');
                        }
                        // Update the incognito mode
                        await updateIncognitoMode(value, accessToken, context);
                        setState(() {
                          isIncognitoModeEnabled = value;
                        });
                      } catch (error) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: ${error.toString()}')),
                        );
                      }
                    },
                    activeColor: primaryColor,
                  ),
                  onTap: () {
                    // Navigate to Privacy Screen or handle tap action
                  },
                ),
                  // Divider(),
                  // ListTile(
                  //   leading: Icon(Icons.person_search, color: primaryColor),
                  //   title: Text('Looking For', style: TextStyle(color: textColor)),
                  //   trailing: Icon(Icons.arrow_forward_ios, color: primaryColor),
                  //   onTap: () {
                  //     _showOptionBottomSheet(context, 'lookingFor');
                  //     // Navigate to Looking For Screen
                  //   },
                  // ),
                  // ListTile(
                  //   leading: Icon(Icons.open_with, color: primaryColor),
                  //   title: Text('Open To', style: TextStyle(color: textColor)),
                  //   trailing: Icon(Icons.arrow_forward_ios, color: primaryColor),
                  //   onTap: () {
                  //     _showOptionBottomSheet(context, 'openTo');
                  //   },
                  // ),
                  // // ListTile(
                  // //   leading: Icon(Icons.language, color: primaryColor),
                  // //   title: Text('Add Languages', style: TextStyle(color: textColor)),
                  // //   trailing: Icon(Icons.arrow_forward_ios, color: primaryColor),
                  // //   onTap: () {
                  // //     _showOptionBottomSheet(context, 'addLanguages');
                  // //   },
                  // // ),
                  // Divider(),
                  ListTile(
                    leading: Icon(Icons.help_outline, color: primaryColor),
                    title: Text('Help & Support', style: TextStyle(color: textColor)),
                    onTap: () {
                      // Navigate to Help & Support Screen
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.info_outline, color: primaryColor),
                    title: Text('About', style: TextStyle(color: textColor)),
                    onTap: () {
                      // Navigate to About Screen
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.logout, color: Colors.redAccent),
                    title: Text('Logout', style: TextStyle(color: textColor)),
                    onTap: () {
                      _logout();
                    },
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
void _showOptionBottomSheet(BuildContext context, String option) {
  switch (option) {
    case 'lookingFor':
      _showLookingForBottomSheet(context);
      break;
    case 'openTo':
      _showOpenToBottomSheet(context);
      break;
    case 'addLanguages':
      _showAddLanguagesBottomSheet(context);
      break;
    case 'notifications':
      _showAddNotificationsBottomSheet(context);
      break;
    default:
      // Handle unknown option
      break;
  }
}
bool  _enableNotifications=false;
bool  _enableSound=false;
bool  _enableVibration=false;
bool  _enablePushNotifications=false;
bool  _showNotificationsOnLockScreen=false;
bool  _showRemindersOnLockScreen=false;
bool  _allowNotificationsToPlaySounds=false;
bool  _doNotDisturb=false;
bool  _showPreviews=false;
bool  _showNotificationBanners=false;
bool  _showNotificationsInActionCenter=false;
bool  _privateNotificationsInPublic=false;

void _showAddNotificationsBottomSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
              title: Text('Enable Notifications'),
              value: _enableNotifications,
              onChanged: (bool value) {
                setState(() {
                  _enableNotifications = value;
                });
              },
            ),
            SwitchListTile(
              title: Text('Sound'),
              value: _enableSound,
              onChanged: (bool value) {
                setState(() {
                  _enableSound = value;
                });
              },
            ),
            SwitchListTile(
              title: Text('Vibration'),
              value: _enableVibration,
              onChanged: (bool value) {
                setState(() {
                  _enableVibration = value;
                });
              },
            ),
            SwitchListTile(
              title: Text('Push Notifications'),
              value: _enablePushNotifications,
              onChanged: (bool value) {
                setState(() {
                  _enablePushNotifications = value;
                });
              },
            ),
            SwitchListTile(
              title: Text('Show Notifications on Lock Screen'),
              value: _showNotificationsOnLockScreen,
              onChanged: (bool value) {
                setState(() {
                  _showNotificationsOnLockScreen = value;
                });
              },
            ),
            SwitchListTile(
              title: Text('Show Reminders on Lock Screen'),
              value: _showRemindersOnLockScreen,
              onChanged: (bool value) {
                setState(() {
                  _showRemindersOnLockScreen = value;
                });
              },
            ),
            SwitchListTile(
              title: Text('Allow Notifications to Play Sounds'),
              value: _allowNotificationsToPlaySounds,
              onChanged: (bool value) {
                setState(() {
                  _allowNotificationsToPlaySounds = value;
                });
              },
            ),
            SwitchListTile(
              title: Text('Do Not Disturb'),
              value: _doNotDisturb,
              onChanged: (bool value) {
                setState(() {
                  _doNotDisturb = value;
                });
              },
            ),
            SwitchListTile(
              title: Text('Show Previews'),
              value: _showPreviews,
              onChanged: (bool value) {
                setState(() {
                  _showPreviews = value;
                });
              },
            ),
            SwitchListTile(
              title: Text('Show Notification Banners'),
              value: _showNotificationBanners,
              onChanged: (bool value) {
                setState(() {
                  _showNotificationBanners = value;
                });
              },
            ),
            SwitchListTile(
              title: Text('Show Notifications in Action Center'),
              value: _showNotificationsInActionCenter,
              onChanged: (bool value) {
                setState(() {
                  _showNotificationsInActionCenter = value;
                });
              },
            ),
            SwitchListTile(
              title: Text('Private Notifications in Public'),
              value: _privateNotificationsInPublic,
              onChanged: (bool value) {
                setState(() {
                  _privateNotificationsInPublic = value;
                });
              },
            ),
          ],
        ),
      );
    },
  );
}

void _showLookingForBottomSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text('Casual'),
              onTap: () {
                // Handle selection of Option 1
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: Text('Serious'),
              onTap: () {
                // Handle selection of Option 2
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: Text('Friendship'),
              onTap: () {
                // Handle selection of Option 3
                Navigator.pop(context);
              },
            ),
          ],
        ),
      );
    },
  );
}

void _showOpenToBottomSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text('Option A'),
              onTap: () {
                // Handle selection of Option A
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: Text('Option B'),
              onTap: () {
                // Handle selection of Option B
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: Text('Option C'),
              onTap: () {
                // Handle selection of Option C
                Navigator.pop(context);
              },
            ),
          ],
        ),
      );
    },
  );
}

void _showAddLanguagesBottomSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text('English'),
              onTap: () {
                // Handle selection of English
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: Text('Spanish'),
              onTap: () {
                // Handle selection of Spanish
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: Text('French'),
              onTap: () {
                // Handle selection of French
                Navigator.pop(context);
              },
            ),
          ],
        ),
      );
    },
  );
}

Widget _buildAnimatedIcon(IconData icon, int index) {
  return AnimatedContainer(
    duration: const Duration(milliseconds: 200),
    decoration: BoxDecoration(
      color: _currentIndex == index ? Colors.white : Colors.transparent,
      borderRadius: BorderRadius.circular(20.0),
    ),
    child: Icon(
      icon,
      size: _currentIndex == index ? 28 : 24,
      color: _currentIndex == index ? Color.fromARGB(255, 250, 16, 106) : const Color.fromARGB(255, 171, 171, 171),
    ),
  );
}
Widget _buildMatchesScreen() {
  return Scaffold(
    appBar: AppBar(

      title: Text(
        'Your Matches',
        style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
      ),
      backgroundColor: const Color.fromARGB(255, 255, 255, 255),
    ),
    body: DefaultTabController(
      length: 3, // Number of tabs
      child: RefreshIndicator(
        onRefresh: () => RefreshHelper.onMatchesRefresh(context),
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Header
              // TabBar for Matches, Likes, Who Liked Me
              TabBar(
                labelColor: Colors.pinkAccent,
                unselectedLabelColor: Colors.grey,
                indicatorColor: Colors.pinkAccent,
                tabs: const [
                  Tab(text: 'Matches'),
                  Tab(text: 'Likes'),
                  Tab(text: 'Who Liked Me'),
                ],
              ),
              // Tab content
              Container(
                height: 500, // Adjust height based on your content
                child: TabBarView(
                  children: [
                    _buildMatchesTabContent('matches'), // Matches tab
                    _buildLikedTabContent('likes'), // Likes tab
                    _buildWhoLikedMeTabContent('whoLikedMe'), // Who Liked Me tab
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
// .....................................................................................................
// Matches Section
// ................................................................

Future<int> _fetchLoggedInUserId() async {
  final url = 'http://192.168.1.241:8000/auth/user-details/';
  try {
    final response = await _authenticatedRequest(
      url,
      'GET',
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['user']['id']; // Extract and return the logged-in user's ID
    } else {
      throw Exception('Failed to fetch logged-in user details. Status code: ${response.statusCode}');
    }
  } catch (e) {
    throw Exception('Error fetching logged-in user details: $e');
  }
}

Widget _buildMatchesTabContent(String tabType) {
  return FutureBuilder<int>(
    future: _fetchLoggedInUserId(), // Fetch the logged-in user's ID
    builder: (context, userIdSnapshot) {
      if (userIdSnapshot.connectionState == ConnectionState.waiting) {
        // Show loading spinner while fetching the logged-in user's ID
        return const Center(child: CircularProgressIndicator());
      } else if (userIdSnapshot.hasError) {
        // Show error message if fetching the logged-in user's ID fails
        return Center(
          child: Text(
            'Error: ${userIdSnapshot.error}',
            style: const TextStyle(color: Colors.red),
          ),
        );
      } else if (!userIdSnapshot.hasData) {
        // Show a message if the logged-in user's ID is not found
        return const Center(
          child: Text('Unable to fetch logged-in user details'),
        );
      } else {
        // Once the logged-in user's ID is fetched, fetch matches
        final loggedInUserId = userIdSnapshot.data!;
        return FutureBuilder<List<dynamic>>(
          future: _Matches(), // Fetch matches asynchronously
          builder: (context, matchesSnapshot) {
            if (matchesSnapshot.connectionState == ConnectionState.waiting) {
              // Show loading spinner while fetching matches
              return const Center(child: CircularProgressIndicator());
            } else if (matchesSnapshot.hasError) {
              // Show error message if fetching matches fails
              return Center(
                child: Text(
                  'Error: ${matchesSnapshot.error}',
                  style: const TextStyle(color: Colors.red),
                ),
              );
            } else if (!matchesSnapshot.hasData || matchesSnapshot.data!.isEmpty) {
              // Show a message if no matches are found
              return const Center(
                child: Text('No matches found'),
              );
            } else {
              // Display matches in a vertical list
              final matches = matchesSnapshot.data!;
              return ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 12),
                itemCount: matches.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                    child: SizedBox(
                      width: MediaQuery.of(context).size.width,
                      child: _buildMatchCard(matches[index], loggedInUserId), // Pass logged-in user ID
                    ),
                  );
                },
              );
            }
          },
        );
      }
    },
  );
}

// Liked

Widget _buildLikedTabContent(String tabType) {
  return FutureBuilder<List<dynamic>>(
    future: _fetchLikes(),
    builder: (context, likesSnapshot) {
      if (likesSnapshot.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator());
      } else if (likesSnapshot.hasError) {
        return Center(
          child: Text(
            'Error: ${likesSnapshot.error}',
            style: const TextStyle(color: Colors.red),
          ),
        );
      } else if (!likesSnapshot.hasData || likesSnapshot.data!.isEmpty) {
        return const Center(
          child: Text('No likes found'),
        );
      } else {
        final likes = likesSnapshot.data!;
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 12),
          itemCount: likes.length,
          itemBuilder: (context, index) {
            final like = likes[index];
            return FutureBuilder<Map<String, dynamic>>(
              future: _fetchUserById(like['swiped_on_user_id']),
              builder: (context, userSnapshot) {
                if (userSnapshot.connectionState == ConnectionState.waiting) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                    child: Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    ),
                  );
                }

                final userData = userSnapshot.data ?? {};
                return GestureDetector(
                  onTap: () {
                    _checkAndNavigateToProfile(
                      context, 
                      userData, 
                      like['swiped_on_user_id']
                    );
                  },
                  child: Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 25,
                                backgroundColor: Colors.pinkAccent,
                                backgroundImage: userData['profile_picture'] != null
                                    ? NetworkImage('http://192.168.1.241:8000${userData['profile_picture']}')
                                    : null,
                                child: userData['profile_picture'] == null
                                    ? const Icon(Icons.person, color: Colors.white)
                                    : null,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      userData['name'] ?? like['swiped_on_username'],
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Liked by: ${like['swiper_username']}',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.pink[50],
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      }
    },
  );
}

Future<List<dynamic>> _fetchLikes() async {
  try {
    final response = await http.get(
      Uri.parse('http://192.168.1.241:8000/auth/likes/'),
      headers:{
          'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to fetch likes');
    }
  } catch (e) {
    throw Exception('Error fetching likes: $e');
  }
}

int _calculateAge(DateTime birthDate) {
  final now = DateTime.now();
  int age = now.year - birthDate.year;
  if (now.month < birthDate.month || 
      (now.month == birthDate.month && now.day < birthDate.day)) {
    age--;
  }
  return age;
}

// build WhoLkedMetab

Future<List<Map<String, dynamic>>> _fetchLikedByUsers() async {
  try {
    final response = await _authenticatedRequest(
      'http://192.168.1.241:8000/auth/liked-by/',
      'GET',
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      return List<Map<String, dynamic>>.from(data['liked_by']);
    } else {
      throw Exception('Failed to fetch liked-by users');
    }
  } catch (e) {
    throw Exception('Error: $e');
  }
}

Future<Map<String, dynamic>> _fetchUserwholiked(int userId) async {
  try {
    final response = await _authenticatedRequest(
      'http://192.168.1.241:8000/auth/api/users/$userId/',
      'GET',
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to fetch user details');
    }
  } catch (e) {
    throw Exception('Error: $e');
  }
}

Future<String> _fetchLikeViewStatus() async {
  try {
    final response = await http.get(
      Uri.parse('http://192.168.1.241:8000/auth/viewlikes/'),
      headers: {
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode == 200) {
      final decodedResponse = json.decode(response.body);

      if (decodedResponse is! List) return 'none'; // Ensure response is a list

      final List<dynamic> data = decodedResponse;
      
      // Check if the current user is in the likes list
      final userDetailsResponse = await http.get(
        Uri.parse('http://192.168.1.241:8000/auth/user-details/'),
        headers: {
          'Authorization': 'Bearer $accessToken',
        },
      );

      if (userDetailsResponse.statusCode == 200) {
        final userDetails = json.decode(userDetailsResponse.body);
        final currentUserId = userDetails['user']['id'].toString();

        // Check if any entry matches the current user and has like_view as 'none'
        final isBlurRequired = data.any((like) => 
          like['user'].toString() == currentUserId && 
          like['like_view'] == 'none'
        );

        return isBlurRequired ? 'blur' : 'none';
      }
      
      return 'none'; // Default to none if user details fetch fails
    }
    return 'none'; // Default to none if request fails
  } catch (e) {
    print('Error fetching like view status: $e');
    return 'none'; // Default to none in case of an error
  }
}
Widget _buildWhoLikedMeTabContent(String tabType) {
  return FutureBuilder<String>(
    future: _fetchLikeViewStatus(),
    builder: (context, likeViewSnapshot) {
      if (likeViewSnapshot.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator());
      }
      
      final shouldBlurAll = likeViewSnapshot.data == 'blur';
      print('Like view status: ${likeViewSnapshot.data}'); // Log like view status

      return FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchLikedByUsers(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            print('Error fetching liked by users: ${snapshot.error}');
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            print('No users have liked your profile');
            return const Center(
              child: Text('No one has liked your profile yet'),
            );
          } else {
            final likedByUsers = snapshot.data!;
            print('Users who interacted with your profile (Total: ${likedByUsers.length}):');
            
            final superlikedUsers = likedByUsers.where((user) => user['swipe_type'] == 'superlike').toList();
            final likedUsers = likedByUsers.where((user) => user['swipe_type'] == 'like').toList();
            final allUsers = [...superlikedUsers, ...likedUsers];

            for (var user in allUsers) {
              print('User ID: ${user['swiper']}');
              print('Username: ${user['swiper_username']}');
              print('Interaction Type: ${user['swipe_type']}');
              print('Timestamp: ${user['timestamp']}');
            }

            return ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              itemCount: allUsers.length,
              itemBuilder: (context, index) {
                final user = allUsers[index];
                return FutureBuilder<Map<String, dynamic>>(
                  future: _fetchUserwholiked(user['swiper']),
                  builder: (context, userDetailsSnapshot) {
                    if (userDetailsSnapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                        child: Card(
                          child: ListTile(
                            leading: CircularProgressIndicator(),
                            title: Text('Loading...'),
                          ),
                        ),
                      );
                    }

                    final userDetails = userDetailsSnapshot.data ?? {};
                    final profilePicUrl = userDetails['profile_picture'] != null
                        ? 'http://192.168.1.241:8000${userDetails['profile_picture']}'
                        : null;

                    print('Detailed info for user ${user['swiper_username']}:');
                    print('Name: ${userDetails['name'] ?? 'N/A'}');
                    print('Bio: ${userDetails['bio'] ?? 'N/A'}');
                    print('Profile Picture URL: $profilePicUrl');

                    final isSuperlike = user['swipe_type'] == 'superlike';

                    return GestureDetector(
                      onTap: shouldBlurAll ? null : () {
                        _checkAndNavigateToProfile(context, userDetails, user['swiper']);
                      },
                      child: Card(
                        elevation: 4,
                        shadowColor: Colors.black.withOpacity(0.1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Container(
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width - 32, // Account for horizontal padding
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: isSuperlike
                                  ? [Colors.blueGrey[50]!, Colors.blueGrey[100]!]
                                  : [Colors.white, Colors.grey[50]!],
                            ),
                          ),
                          child: IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Profile Image
                                Container(
                                  width: 100,
                                  decoration: BoxDecoration(
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(12),
                                      bottomLeft: Radius.circular(12),
                                    ),
                                    border: Border.all(
                                      color: isSuperlike ? Colors.blueGrey[300]! : Colors.grey[300]!,
                                      width: 1,
                                    ),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(11),
                                      bottomLeft: Radius.circular(11),
                                    ),
                                    child: CachedNetworkImage(
                                      imageUrl: profilePicUrl ?? '',
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => Container(
                                        color: Colors.grey[200],
                                        child: const Center(child: CircularProgressIndicator()),
                                      ),
                                      errorWidget: (context, url, error) => Container(
                                        color: Colors.grey[200],
                                        child: Icon(
                                          Icons.person,
                                          size: 40,
                                          color: Colors.grey[400],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                // User Info
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Flexible(
                                              child: Text(
                                                userDetails['name'] ?? user['swiper_username'],
                                                style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.grey[900],
                                                  letterSpacing: 0.2,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: isSuperlike ? Colors.blueGrey[600] : Colors.grey[600],
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    isSuperlike ? Icons.star : Icons.favorite,
                                                    size: 14,
                                                    color: Colors.white,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    isSuperlike ? 'Superlike' : 'Like',
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.white,
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (userDetails['bio'] != null && !shouldBlurAll)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 6),
                                            child: Text(
                                              userDetails['bio'],
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey[600],
                                                height: 1.4,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        Padding(
                                          padding: const EdgeInsets.only(top: 8),
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.access_time,
                                                size: 14,
                                                color: Colors.grey[500],
                                              ),
                                              const SizedBox(width: 4),
                                              Flexible(
                                                child: Text(
                                                  ' ${_formatTimestamp(user['timestamp'])}',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey[500],
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (!shouldBlurAll)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 8),
                                            child: ElevatedButton(
                                              onPressed: () {
                                                handleSwipe(
                                                  swipedUserId: user['swiper'],
                                                  swipedOnId: _currentUserId,
                                                  swipeType: 'like',
                                                );
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                    content: Text('You liked ${userDetails['name'] ?? user['swiper_username']} back!'),
                                                    backgroundColor: Colors.green,
                                                    behavior: SnackBarBehavior.floating,
                                                  ),
                                                );
                                              },
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: isSuperlike ? Colors.blueGrey[700] : Colors.grey[700],
                                                foregroundColor: Colors.white,
                                                minimumSize: const Size(100, 36),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                              ),
                                              child: const Text(
                                                'Like Back',
                                                style: TextStyle(fontSize: 14),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            );
          }
        },
      );
    },
  );
}

String _formatTimestamp(String timestamp) {
  final DateTime dateTime = DateTime.parse(timestamp);
  final DateTime localDateTime = dateTime.toLocal();
  return '${localDateTime.day}/${localDateTime.month}/${localDateTime.year}';
}

// fetching user by id
Future<Map<String, dynamic>> _fetchUserById(int userId) async {
  try {
    final response = await http.get(
      Uri.parse('http://192.168.1.241:8000/auth/api/users/$userId/'),
      headers: {
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode == 200) {
      final userData = json.decode(response.body);
      // print('Successfully fetched user data: $userData');
      return userData;
    } else {
      print('Failed to fetch user data. Status: ${response.statusCode}, Body: ${response.body}');
      throw Exception('Failed to fetch user details');
    }
  } catch (e) {
    print('Error fetching user details: $e');
    throw Exception('Error fetching user details: $e');
  }
}

// ..................................................

Future<List<Map<String, dynamic>>> _Matches() async {
  final url = '$baseurl/auth/matches/';
  try {
    final response = await _authenticatedRequest(
      url,
      'GET',
    );

    if (response.statusCode == 200) {
      List<dynamic> matches = json.decode(response.body);
      
      // Fetch user details for each match
      List<Map<String, dynamic>> enrichedMatches = [];
      for (var match in matches) {
        var user1Details = await _fetchUserById(match['user1']);
        var user2Details = await _fetchUserById(match['user2']);

        enrichedMatches.add({
          'user1': user1Details,
          'user2': user2Details,
          'user1_id': match['user1'],
          'user2_id': match['user2'],
          'created_at': match['created_at'],
          'match_id': match['id'],
        });
      }

      return enrichedMatches;
    } else {
      throw Exception('Failed to fetch matches. Status code: ${response.statusCode}');
    }
  } catch (e) {
    throw Exception('Failed to fetch matches: $e');
  }
}

// .....................................................................................
// .....................................................................................
Widget _buildMatchCard(Map<String, dynamic> match, int loggedInUserId) {
  final bool isUser1LoggedIn = match['user1_id'] == loggedInUserId;
  final Map<String, dynamic> loggedInUser = isUser1LoggedIn ? match['user1'] : match['user2'];
  final int matchedUserId = isUser1LoggedIn ? match['user2_id'] : match['user1_id'];
  final Map<String, dynamic> matchedUser = isUser1LoggedIn ? match['user2'] : match['user1'];

  // Function to trim names if too long
  String trimName(String name) {
    return (name.length > 10) ? '${name.substring(0, 10)}…' : name;
  }

  return Container(
    width: double.infinity,
    margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
    child: GestureDetector(
      onTap: () {
        if (loggedInUserId == null || matchedUserId == null) {
          print('Error: Logged-in user ID or matched user ID is null');
          return;
        }

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => UserProfileScreen(
              user: matchedUser,
              user1Id: loggedInUserId,
              user2Id: matchedUserId,
            ),
          ),
        );
      },
      child: Stack(
        children: [
          // Main Card
          Card(
            elevation: 6,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logged-in user profile
                      Expanded(
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 35,
                              backgroundImage: CachedNetworkImageProvider(
                                '$baseurl${loggedInUser['profile_picture']}' ?? 'https://via.placeholder.com/150',
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Me',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),

                      // Love symbol centered
                      const Spacer(),
                      const Icon(Icons.favorite, color: Colors.pinkAccent, size: 50),
                      const Spacer(),

                      // Matched user profile
                      Expanded(
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 35,
                              backgroundImage: CachedNetworkImageProvider(
                                '$baseurl${matchedUser['profile_picture']}' ?? 'https://via.placeholder.com/150',
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              trimName(matchedUser['name'] ?? 'User 2'),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),

          // Delete Button at the top-right corner
          Positioned(
            top: 8,
            right: 8,
            child: IconButton(
              onPressed: () async {
                await _deleteMatch(match['match_id'], context);
              },
              icon: const Icon(Icons.delete, color: Colors.redAccent, size: 30),
              tooltip: 'Delete Match',
            ),
          ),
        ],
      ),
    ),
  );
}


Future<void> _deleteMatch(int matchId, BuildContext context) async {
  final url = '$baseurl/auth/matches/$matchId/remove/';
  try {
    final response = await _authenticatedRequest(
      url,
      'DELETE',
    );

    if (response.statusCode == 204) {
      // Success: Match deleted
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Match deleted successfully!')),
      );
    } else {
      // Handle error
      final errorMessage = json.decode(response.body)['detail'] ?? 'Error deleting match.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete match: $errorMessage')),
      );
    }
  } catch (e) {
    // Handle exceptions
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Failed to delete match: $e')),
    );
  }
}
// Home tab with header
Widget _buildHomeScreen() {
  return Scaffold(
    appBar: AppBar(
      backgroundColor: Colors.white,
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 36,
            height: 36,
            margin: EdgeInsets.all(3),
            child: ClipOval(
              child: CircleAvatar(
                radius: 18,
                backgroundImage: _profilePicture != null
                    ? NetworkImage('$baseurl$_profilePicture')
                    : null,
              ),
            ),
          ),
          SizedBox(width: 6),
          TweenAnimationBuilder<int>(
            tween: IntTween(begin: 0, end: _creditScore ?? 0),
            duration: const Duration(seconds: 2),
            builder: (context, value, child) {
              return Text(
                '$value',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color.fromARGB(255, 112, 117, 120),
                ),
              );
            },
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.filter_alt, size: 20),
          onPressed: _showFilterScreen,
        ),
        IconButton(
          icon: Image.asset(
            'assets/settings.png',
            width: 20,
            height: 20,
          ),
          onPressed: () {
            _showSettingsBottomSheet(context);
          },
        )
      ],
    ),
    body: Stack(
      children: [
        Column(
          children: [
            Expanded(
              child: _buildSuggestedMatches(),
            ),
          ],
        ),
        if (_isCheckingBonus)
          const Center(child: CircularProgressIndicator()),
        // 添加背景遮罩层
        if (_showWelcomeBonusModal)
          AnimatedOpacity(
            opacity: _showWelcomeBonusModal ? 0.5 : 0.0,
            duration: const Duration(milliseconds: 500),
            child: GestureDetector(
              onTap: _closeWelcomeBonusModal, // 点击遮罩层关闭弹窗
              child: Container(
                color: Colors.black.withOpacity(0.5), // 半透明黑色背景
              ),
            ),
          ),
        // 弹窗
        if (_showWelcomeBonusModal)
          _buildWelcomeBonusModal(),
      ],
    ),
  );
}
Widget _buildWelcomeBonusModal() {
  return Center(
    child: AnimatedOpacity(
      opacity: _showWelcomeBonusModal ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 500),
      child: Transform.scale(
        scale: _showWelcomeBonusModal ? 1.0 : 0.8,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          backgroundColor: Colors.transparent,
          contentPadding: EdgeInsets.zero,
          content: SizedBox(
            width: double.infinity,
            height: MediaQuery.of(context).size.height * 0.6,
            child: Stack(
              children: [
                // 弹窗内容
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        const Color(0xFF1B263B),
                        const Color(0xFF4A5568),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 60), // 为图标和图片留出空间
                        // const Icon(
                        //   Icons.card_giftcard,
                        //   size: 48,
                        //   color: Colors.white,
                        // ),
                        const SizedBox(height: 24),
                        const Text(
                          'Welcome Bonus!',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 1.2,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'You have a welcome bonus of 1000 credits waiting for you!',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white70,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),
                        ElevatedButton(
                          onPressed: _claimWelcomeBonuses,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 32),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(32),
                              side: BorderSide(color: Colors.white, width: 1),
                            ),
                            elevation: 0,
                            shadowColor: Colors.transparent,
                          ),
                          child: const Text(
                            'Claim Bonus',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Limited time offer!',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white54,
                            fontStyle: FontStyle.italic,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
                // 关闭按钮，部分在弹窗外面
                Positioned(
                  top: 12,
                  right: 12,
                  child: IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 32,
                    ),
                    style: ButtonStyle(
                      backgroundColor: MaterialStateProperty.all(Colors.transparent),
                      padding: MaterialStateProperty.all(EdgeInsets.zero),
                      minimumSize: MaterialStateProperty.all(Size.zero),
                    ),
                    onPressed: _closeWelcomeBonusModal,
                  ),
                ),
                // 添加图片，部分在弹窗外面
                Positioned(
                  top: 40, // 图片顶部位置
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Image.asset(
                      'assets/money.png', // 替换为你的图片路径
                      width: 100,
                      height: 100,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

// 显示吐司消息的方法
void _showToastMessage(BuildContext context) {
  final snackBar = SnackBar(
    content: Row(
      children: [
        const Icon(
          Icons.check_circle_outline,
          color: Colors.white,
          size: 24,
        ),
        const SizedBox(width: 12),
        const Text(
          'Bonus claimed successfully!',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
      ],
    ),
    backgroundColor: Colors.green,
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(24),
    ),
    elevation: 8,
    duration: const Duration(seconds: 2),
  );

  ScaffoldMessenger.of(context).showSnackBar(snackBar);
}

// 点击“Claim Bonus”按钮的方法
void _claimWelcomeBonuses() {
  // 这里可以添加你的逻辑，例如处理奖励领取
  _claimWelcomeBonus(); // 先关闭弹窗
  _showToastMessage(context); // 然后显示吐司消息
}
// 关闭弹窗的方法
void _closeWelcomeBonusModal() {
  setState(() {
    _showWelcomeBonusModal = false;
  });
}
  Widget _buildVIPContent() {
    return BoostedProfilesScreen();
 
  }

  // Widget _buildViewsContent() {
  //   return Center(
  //     child: Text('Views Content'),
  //   );
  // }

  // Widget _buildPremiumContent() {
  //   return PremiumScreen();
  // }

  Future<void> fetchCurrentUserId() async {
    final url = Uri.parse('$baseurl/auth/user-details/');
    try {
      // Load tokens
      await _loadTokens(); // This will load accessToken and refreshToken

      if (accessToken != null) {
        // Include the access token in the Authorization header
        final response = await _authenticatedRequest(
          url.toString(),
          'GET',
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          setState(() {
            _currentUserId = data['user']['id']; // Extract the user ID
          });
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_id', _currentUserId.toString());
          print('Logged-in User ID: $_currentUserId');
        } else {
          print('Failed to fetch user details: ${response.statusCode}');
        }
      } else {
        print('Access token is null, unable to fetch user details.');
      }
    } catch (e) {
      print('Error fetching user details: $e');
    }
  }

  Future<void> _checkAndNavigateToProfile(BuildContext context, Map<String, dynamic> userData, int userId) async {
    try {
      final accessToken = await _getAccessToken();
      if (accessToken == null) {
        _showErrorSnackBar('Access token is missing');
        return;
      }

      final response = await http.get(
        Uri.parse('$baseurl/auth/unlocked-profiles/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );

      if (response.statusCode == 200) {
        // Profile is unlocked, navigate to user profile
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => UserProfileScreen(
              user: userData,
              user1Id: _loggedInUserId ?? 0,
              user2Id: userId,
            ),
          ),
        );
      } else {
        // Check the response body
        final responseBody = json.decode(response.body);
        if (responseBody['detail'] == 'Subscription plan not found.') {
          // Show subscription plans popup
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: Text('Unlock Profiles'), 
                content: Text('To view full profiles, you need an active subscription.'),
                actions: <Widget>[
                  TextButton(
                    child: Text('OK'),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              );
            },
          );
        } else {
          // Handle other error cases
          _showErrorSnackBar('Unable to unlock profile');
        }
      }
    } catch (e) {
      _showErrorSnackBar('Error checking profile: $e');
    }
  }

  Future<String?> _getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

// Function to send swipe action to the backend

Future<http.Response> handleSwipe({
  required int swipedUserId,
  required int swipedOnId,
  required String swipeType,
}) async {
  // Validate input parameters
  if (swipedUserId <= 0) {
    print('Invalid swiper user ID');
    return http.Response('Invalid user ID', 400);
  }

  final url = '$baseurl/auth/swipe/';

  try {
    await _loadTokens();

    if (accessToken == null) {
      print('Error: Access token is null.');
      return http.Response('Access token is null', 401);
    }

    final headers = {
      'Authorization': 'Bearer $accessToken',
      'Content-Type': 'application/json',
    };

    final body = jsonEncode({
      'swiped_by': swipedUserId,
      'swiped_user_id': swipedOnId,
      'swipe_type': swipeType,
    });

    // Print the body to console
    print('Request Body: $body');

    final response = await http.post(
      Uri.parse(url),
      headers: headers,
      body: body,
    );

    if (response.statusCode == 201) {
      print('Swipe action recorded successfully for ID: $swipedOnId');
    } else {
      print('Swipe action failed. Status: ${response.statusCode}');
    }

    return response;
  } catch (e) {
    print('Error sending swipe action: $e');
    return http.Response('Error sending swipe action', 500);
  }
}

// Helper function for building action buttons
Widget _buildActionButtons(Widget buttonChild, Color color, VoidCallback onPressed) {
  return Container(
    decoration: BoxDecoration(
      color: Colors.white, // White background color
      shape: BoxShape.circle,
      boxShadow: [
        BoxShadow(
          color: Colors.grey.withOpacity(0.3),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: IconButton(
      icon: buttonChild,
      onPressed: onPressed,
      iconSize: 38,
    ),
  );
}

 void showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

Future<void> fetchInterests() async {
   final accessToken = await _getAccessToken();

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
      });
    } else {
      showErrorSnackBar('Error fetching interests');
    }
  } catch (e) {
    showErrorSnackBar('An error occurred while fetching interests.');
  }
}
// Call fetchCurrentUserId on the widget's initStat
Widget _buildSuggestedMatches() {
  // Remove duplicates
  final uniqueMatches = Set.from(_matches.map((match) => match['user_id']));
  _matches = _matches.where((match) => uniqueMatches.contains(match['user_id'])).toList();

  // Check if data is still loading
  if (_isLoading) {
    return Center(child: CircularProgressIndicator());
  }

  // Check if _matches is empty
  if (_matches.isEmpty) {
    print('_matches is empty'); // Debug print
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.swipe, // Icon to signify swiping
            size: 70,
            color: Colors.grey[700],
          ),
          SizedBox(height: 20), // Add some space between the icon and text
          Text(
            'You have run out of people to swipe on !',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }
  print('_matches: $_matches');

  return Container(
    color: const Color.fromARGB(255, 247, 244, 246), // Use a single color for the background
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: SizedBox(
            width: MediaQuery.of(context).size.width,
            height: MediaQuery.of(context).size.height * 0.8, // 80% of the screen height
            child: Stack(
              children: [
                CardSwiper(
                  cards: List.generate(_matches.length, (index) {
                    final match = _matches[index];
                    final profile = match['profile'];
                    final userId = match['user_id'];
                    

                    return ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: Stack(
                        fit: StackFit.expand,
                        alignment: Alignment.topCenter,
                        children: [
                          Image.network(
                            '$baseurl${profile['profile_picture']}',
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Image.asset(
                              'assets/default_profile_picture.png',
                              fit: BoxFit.cover,
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(15),
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withOpacity(0.7),
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            top: 16,
                            left: 16,
                            child: GestureDetector(
                              onTap: () {
                                // Handle profile tap
                              },
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white24,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.person,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 46,
                            left: 16,
                            right: 16,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  profile['name'] ?? 'No Name',
                                  style: TextStyle(
                                    fontSize: 29,
                                    
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                    shadows: [
                                      Shadow(
                                        blurRadius: 10.0,
                                        color: Colors.black45,
                                        offset: Offset(1.0, 1.0),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  width: double.infinity,
                                  height: 2,
                                  color: Colors.white30,
                                  margin: const EdgeInsets.symmetric(vertical: 4),
                                ),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.location_on_outlined,
                                      color: Colors.white70,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 4),
                               Text(
                                  match['distance_km'] != null ? match['distance_km'].toString() : 'Location not specified',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: const Color.fromARGB(179, 255, 255, 255),
                                    fontStyle: profile['location'] == null ? FontStyle.italic : FontStyle.normal,
                                  ),
                                ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                             Wrap(
  spacing: 6,
  children: (profile['interests'] as List<dynamic>?)
      ?.map((interestId) => Chip(
            label: Text(
              allInterests[interestId] ?? 'Unknown',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.black, // Set the background color to black\
            
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16), // Adjust the radius as needed
              side: BorderSide.none, // Ensure there is no border
            ),
          ))
      .toList() ??
      [],
)
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),

   
onSwipe: (int index, CardSwiperDirection direction) {
  setState(() {
    _isSwipingLeft = direction == CardSwiperDirection.left;
    _isSwipingRight = direction == CardSwiperDirection.right;
  });

  if (direction == CardSwiperDirection.right) {
    Fluttertoast.showToast(msg: '🔥', backgroundColor: Colors.white, fontSize: 28);
    handleSwipe(
      swipeType: 'like',
      swipedUserId: _currentUserId,
      swipedOnId: _matches[index]['user_id'],
    );
  } else if (direction == CardSwiperDirection.left) {
    Fluttertoast.showToast(msg: '😖', backgroundColor: Colors.white, fontSize: 28);
    handleSwipe(
      swipeType: 'dislike',
      swipedUserId: _currentUserId,
      swipedOnId: _matches[index]['user_id'],
    );
  }

  // Delay to hide the swipe indicators after a short time
  Future.delayed(Duration(milliseconds: 300), () {
    setState(() {
      _isSwipingLeft = false;
      _isSwipingRight = false;
    });
  });

  setState(() {
    _matches.removeAt(index);
  });
},
                ),
                // Buttons overlay
                Positioned(
                  bottom:0, // Adjust the position to partially overlap the cards
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildActionButtons(
                        Image.asset(
                          'assets/dislike.png', // Replace with your close icon asset path
                          width: 40, // Adjust the size as needed
                          height: 40,
                        ),
                        Colors.red,
                        () async {
                          if (_currentUserId != 0) {
                            await handleSwipe(
                              swipeType: 'dislike',
                              swipedUserId: _currentUserId,
                              swipedOnId: _matches.last['user_id'],
                            );
                            setState(() {
                              _matches.removeLast();
                            });
                          }
                        },
                      ),
                      _buildActionButtons(
                        Image.asset(
                          'assets/superlike.png',
                          color: const Color.fromARGB(255, 191, 110, 216),
                          width: 42,
                          height: 42,
                        ),
                        Colors.blue,
                        () async {
                          if (_currentUserId != 0) {
                            // Perform the superlike action
                            final response = await handleSwipe(
                              swipeType: 'superlike',
                              swipedUserId: _currentUserId,
                              swipedOnId: _matches.last['user_id'],
                            );

                            // Check if the response status is 200
                            if (response != null && response.statusCode == 200) {
                              // Show a popup indicating superlike
                              await showDialog(
                                context: context,
                                builder: (BuildContext context) {
                                  return AlertDialog(
                                    title: Text('Superlike!'),
                                    content: Text('You have superliked ${_matches.last['profile']['name']}'),
                                    actions: <Widget>[
                                      TextButton(
                                        child: Text('OK'),
                                        onPressed: () {
                                          Navigator.of(context).pop();
                                        },
                                      ),
                                    ],
                                  );
                                },
                              );

                              // Remove the card from the list
                              setState(() {
                                _matches.removeLast();
                              });
                            } else if (response != null && response.statusCode == 403) {
                              // Show a popup indicating the user is not subscribed to any plans
                              await showDialog(
                                context: context,
                                builder: (BuildContext context) {
                                  return AlertDialog(
                                    backgroundColor: Colors.black, // Dark theme background
                                    title: Text(
                                      'Subscription Required',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    content: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        SizedBox(height: 16),
                                        Text(
                                          'You are not subscribed to any plans. Please get one.',
                                          style: TextStyle(
                                            color: Colors.grey,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ],
                                    ),  
                                    actions: <Widget>[
                                      TextButton(
                                        child: Text(
                                          'OK',
                                          style: TextStyle(
                                            color: Colors.blue,
                                            fontSize: 16,
                                          ),
                                        ),
                                        onPressed: () {
                                          Navigator.of(context).pop();
                                        },
                                      ),
                                    ],
                                  );
                                },
                              );
                            } else {
                              // Handle other status codes if necessary
                              print('Swipe action failed. Status: ${response?.statusCode}');
                            }
                          }
                        },
                      ),
                      _buildActionButtons(
                        Image.asset(
                          'assets/likes.png',
                          width: 40,
                          height: 40,
                        ),
                        Colors.red,
                        () async {
                          if (_currentUserId != 0) {
                            await handleSwipe(
                              swipeType: 'like',
                              swipedUserId: _currentUserId,
                              swipedOnId: _matches.last['user_id'],
                            );
                            setState(() {
                              _matches.removeLast();
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ),
                // Swipe indicator image
           Positioned(
  left: 0,
  bottom: 0,
  child: Visibility(
    visible: _isSwipingLeft,
    child: Image.asset(
      'assets/dislike.png',
      width: 100,
      height: 100,
    ),
  ),
),
Positioned(
  right: 0,
  bottom: 0,
  child: Visibility(
    visible: _isSwipingRight,
    child: Image.asset(
      'assets/like.png',
      width: 100,
      height: 100,
    ),
  ),
),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
// Placeholder for Search tab
Widget _buildSearchScreen() {
  return const Center(
    child: Text('Search Screen'),
  );
}

// Placeholder for Chat tab
Widget _buildChatScreen() {
  return ChatListScreen(); // This will render the list of all chats
}

  // Add the missing profile screen method
 
Future<void> updateUserLocation() async {
  try {
    // Show loading dialog with improved design
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          elevation: 5,
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 50,
                  height: 50,
                  child: CircularProgressIndicator(
                    strokeWidth: 3.0,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).primaryColor,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Updating Location',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Please wait while we update your location',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high
    );

    print('Retrieved Location: ${position.latitude}, ${position.longitude}');

    final response = await http.post(
      Uri.parse('$baseurl/auth/store_location/'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        "lat": position.latitude,
        "long": position.longitude,
      }),
    );

    // Hide loading dialog
    Navigator.of(context).pop();

    if (response.statusCode == 200) {
      print('Location updated successfully');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Location updated successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      print('Failed to update location: ${response.statusCode}');
      print('Response body: ${response.body}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update location'),
          backgroundColor: Colors.red,
        ),
      );
    }
  } catch (e) {
    // Hide loading dialog in case of error
    Navigator.of(context).pop();
    print('Error updating location: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error updating location: $e'),
        backgroundColor: Colors.red,
      ),
    );
  }
}
}
