import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
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

class _HomePageState extends State<HomePage>with
SingleTickerProviderStateMixin {
   late TabController _tabController;
  int _currentIndex = 0;
  int _currentUserId=0;
  bool _isLoading = false;
  String? _error;
  
  // Filter values
  double _age = 18;
  double _distance = 5;

  // Add token variables
  SharedPreferences? prefs;
  String? accessToken;
  String? refreshToken;
   bool _isLikeOverlayVisible = false;

  // Add variables to store user details
  String? _userName;
  String? _userEmail;
  String? _profilePicture;
  int? _creditScore;// Initialize with a default value

  // Function to fetch matches from the API


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
  _tabController = TabController(length: 3, vsync: this);

  if (widget.accessToken != null && widget.refreshToken != null) {
    accessToken = widget.accessToken;
    refreshToken = widget.refreshToken;
  } else {
    _loadTokens();
  }

  _fetchUserDetails().then((_) {
    _fetchMatches().then((_) {
      _fetchCreditScore();
    });
  });
  fetchCurrentUserId();
}

  @override
  void dispose() {
    _tabController.dispose(); // Properly dispose of the TabController
    super.dispose();
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
                  _buildAnimatedIcon(Icons.chat_bubble, 2),
                  // Notification badge for unread messages
                ],
              ),
              label: '', // Remove the label
            ),
            BottomNavigationBarItem(
              icon: _buildAnimatedIcon(Icons.person, 3),
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
      return Container(
        height: MediaQuery.of(context).size.height * 0.9 - MediaQuery.of(context).padding.bottom,
        child: Scaffold(
          appBar: AppBar(
            title: Text(
              'Discover Settings',
              style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold), // Set the text color to primaryColor
            ),
            backgroundColor: const Color.fromARGB(255, 255, 255, 255), // White background
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
              ListTile(
                leading: Icon(Icons.favorite, color: primaryColor),
                title: Text('Likes & Matches', style: TextStyle(color: textColor)),
                onTap: () {
                  // Navigate to Likes & Matches Screen
                },
              ),
              ListTile(
                leading: Icon(Icons.people, color: primaryColor),
                title: Text('Preferences', style: TextStyle(color: textColor)),
                onTap: () {
                  // Navigate to Preferences Screen
                },
              ),
              ListTile(
                leading: Icon(Icons.notifications, color: primaryColor),
                title: Text('Notifications', style: TextStyle(color: textColor)),
                onTap: () {
                  // Navigate to Notifications Screen
                },
              ),
              ListTile(
                leading: Icon(Icons.privacy_tip, color: primaryColor),
                title: Text('Privacy', style: TextStyle(color: textColor)),
                onTap: () {
                  // Navigate to Privacy Screen
                },
              ),
              Divider(),
                 ListTile(
                leading: Icon(Icons.person_search, color: primaryColor),
                title: Text('Looking For', style: TextStyle(color: textColor)),
                trailing: Icon(Icons.arrow_forward_ios, color: primaryColor),
                onTap: () {
                  _showOptionBottomSheet(context, 'lookingFor');
                },
              ),
              ListTile(
                leading: Icon(Icons.open_with, color: primaryColor),
                title: Text('Open To', style: TextStyle(color: textColor)),
                trailing: Icon(Icons.arrow_forward_ios, color: primaryColor),
                onTap: () {
                  _showOptionBottomSheet(context, 'openTo');
                },
              ),
              ListTile(
                leading: Icon(Icons.language, color: primaryColor),
                title: Text('Add Languages', style: TextStyle(color: textColor)),
                trailing: Icon(Icons.arrow_forward_ios, color: primaryColor),
                onTap: () {
                  _showOptionBottomSheet(context, 'addLanguages');
                },
              ),
              Divider(),
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
              // New ListTiles for Looking For, Open To, and Add Languages
           
            ],
          ),
        ),
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
    default:
      // Handle unknown option
      break;
  }
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
  return DefaultTabController(
    length: 3, // Number of tabs
    child: RefreshIndicator(
      onRefresh: () => RefreshHelper.onMatchesRefresh(context),
      child: SingleChildScrollView(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Your Matches',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.pinkAccent,
                ),
              ),
            ),
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

      return FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchLikedByUsers(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text('No one has liked your profile yet'),
            );
          } else {
            final likedByUsers = snapshot.data!;
            return ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 12),
              itemCount: likedByUsers.length,
              itemBuilder: (context, index) {
                final user = likedByUsers[index];
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

                    return GestureDetector(
                      onTap: shouldBlurAll ? null : () {
                        _checkAndNavigateToProfile(
                          context, 
                          userDetails, 
                          user['swiper']
                        );
                      },
                      child: Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(15),
                          child: Stack(
                            children: [
                              CachedNetworkImage(
                                imageUrl: profilePicUrl ?? '',
                                height: 200,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  height: 200,
                                  color: Colors.grey[200],
                                  child: const Center(child: CircularProgressIndicator()),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  height: 200,
                                  color: Colors.grey[200],
                                  child: const Icon(Icons.person, size: 50),
                                ),
                              ),
                              Positioned.fill(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  userDetails['name'] ?? user['swiper_username'],
                                                  style: const TextStyle(
                                                    fontSize: 20,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                                if (userDetails['bio'] != null && !shouldBlurAll)
                                                  Padding(
                                                    padding: const EdgeInsets.only(top: 4),
                                                    child: Text(
                                                      userDetails['bio'],
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        color: Colors.grey[200],
                                                      ),
                                                      maxLines: 2,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          if (!shouldBlurAll)
                                            IconButton(
                                              icon: const Icon(
                                                Icons.favorite,
                                                color: Colors.pinkAccent,
                                                size: 32,
                                              ),
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
                                                  ),
                                                );
                                              },
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Liked you on ${_formatTimestamp(user['timestamp'])}',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey[200],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              if (shouldBlurAll)
                                Positioned.fill(
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                                    child: Container(
                                      color: Colors.black.withOpacity(0.4),
                                      child: const Center(
                                        child: Text(
                                          'Unlock to see details',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
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
    print('Fetching user details for ID: $userId');
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
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.white,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      backgroundColor: Colors.white, // Customize the background color
      leading: Row(
        mainAxisSize: MainAxisSize.min, // Ensure the row takes only the necessary space
        children: [
          Container(
            width: 45, // Set the desired width
            height: 45, // Set the desired height
            margin: EdgeInsets.all(6), // Optional: Add some margin if needed
            child: CircleAvatar(
              radius: 24, // Adjust the radius as needed
              backgroundImage: _profilePicture != null
                  ? NetworkImage('$baseurl$_profilePicture')
                  : null,
            ),
          ),
          SizedBox(width: 6), // Add some spacing between the profile picture and the credit value
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
              icon: const Icon(Icons.filter_alt, color: Colors.pinkAccent, size: 20), // Add filter button
              onPressed: _showFilterScreen,
            ),
        IconButton(
          icon: Icon(Icons.notifications),
          onPressed: () {
            // Handle notification icon tap
          },
        ),
        IconButton(
          icon: Icon(Icons.settings),
         onPressed: () {
          _showSettingsBottomSheet(context);
        },
        ),
      ],
    ),
    body: Column(
      children: [
        // Uncomment the TabBar if you want to use it
        // Container(
        //   child: TabBar(
        //     controller: _tabController,
        //     indicatorColor: Colors.pinkAccent,
        //     labelColor: Colors.pinkAccent,
        //     unselectedLabelColor: Colors.grey,
        //     labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        //     unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        //     tabs: const [
        //       Tab(child: Text('All')),
        //       Tab(child: Text('Boosted')),
        //       Tab(child: Text('Premium')),
        //     ],
        //   ),
        // ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: 0,
                    maxHeight: MediaQuery.of(context).size.height * 0.8,
                  ),
                  child: _buildSuggestedMatches(),
                ),
              ),
              SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: 0,
                    maxHeight: MediaQuery.of(context).size.height * 0.8,
                  ),
                  child: _buildVIPContent(),
                ),
              ),
              SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: 0,
                    maxHeight: MediaQuery.of(context).size.height * 0.8,
                  ),
                  child: _buildPremiumContent(),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

  Widget _buildVIPContent() {
    return BoostedProfilesScreen();
 
  }

  Widget _buildViewsContent() {
    return Center(
      child: Text('Views Content'),
    );
  }

  Widget _buildPremiumContent() {
    return PremiumScreen();
  }

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
                title: const Text(
                  'Unlock Profiles', 
                  style: TextStyle(
                    fontWeight: FontWeight.bold, 
                    color: Colors.pinkAccent
                  ),
                  textAlign: TextAlign.center,
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'To view full profiles, you need an active subscription.',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.pinkAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () {
                        Navigator.of(context).pop(); // Close the dialog
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AddCreditsScreen(), // Navigate to subscription screen
                          ),
                        );
                      },
                      child: const Text(
                        'View Subscription Plans',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
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

Future<void> handleSwipe({
  required int swipedUserId,
  required int swipedOnId,
  required String swipeType,
}) async {
  // Validate input parameters
  if (swipedUserId <= 0) {
    print('Invalid swiper user ID');
    return;
  }

  final url = '$baseurl/auth/swipe/';

  try {
    await _loadTokens();

    if (accessToken == null) {
      print('Error: Access token is null.');
      return;
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

    final response = await _authenticatedRequest(
      url,
      'POST',
      body: body,
    );

    if (response.statusCode == 201) {
      print('Swipe action recorded successfully for ID: $swipedOnId');
    } else {
      print('Swipe action failed. Status: ${response.statusCode}');
    }
  } catch (e) {
    print('Error sending swipe action: $e');
  }
}


// Helper function for building action buttons
Widget _buildActionButtons(IconData icon, Color color, VoidCallback onPressed) {
  return Container(
    decoration: BoxDecoration(
      color: Colors.white,
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
      icon: Icon(icon, color: color),
      onPressed: onPressed,
      iconSize: 38,
    ),
  );
}


// Call fetchCurrentUserId on the widget's initState
  // Update the Suggested Matches section
Widget _buildSuggestedMatches() {
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

  return Container(
    padding: const EdgeInsets.all(16.0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        Expanded(
          child: SizedBox(
            height: 500, // Increased height from 400 to 500
            child: Stack(
              clipBehavior: Clip.none,
              children: List.generate(_matches.length, (index) {
                final match = _matches[index];
                final profile = match['profile'];
                final userId = match['user_id'];

                return Dismissible(
                  key: Key(userId.toString()),
                  direction: DismissDirection.horizontal,
                  onUpdate: (details) {
                    if (details.direction == DismissDirection.startToEnd) {
                      setState(() {
                        _isLikeOverlayVisible = true;
                      });
                    } else {
                      setState(() {
                        _isLikeOverlayVisible = false;
                      });
                    }
                  },
                  onDismissed: (direction) async {
                    if (_currentUserId != 0) {
                      final isLiked = direction == DismissDirection.startToEnd;
                      final swipeType = isLiked ? 'like' : 'dislike';

                      try {
                        await handleSwipe(
                          swipeType: swipeType,
                          swipedUserId: _currentUserId,
                          swipedOnId: userId,
                        );

                        setState(() {
                          _matches.removeAt(index);
                        });

                        print('$swipeType: ${profile['name']}');
                      } catch (error) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: ${error.toString()}')),
                        );
                      }
                    } else {
                      print('Current user ID is not available');
                    }
                  },
                  background: Container(
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: EdgeInsets.only(left: 20),
                        child: Icon(Icons.favorite, color: Colors.green, size: 40),
                      ),
                    ),
                  ),
                  secondaryBackground: Container(
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: EdgeInsets.only(right: 20),
                        child: Icon(Icons.close, color: Colors.red, size: 40),
                      ),
                    ),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    alignment: Alignment.topCenter,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: Image.network(
                          '$baseurl${profile['profile_picture']}',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Image.asset(
                            'assets/default_profile_picture.png',
                            fit: BoxFit.cover,
                          ),
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
                        bottom: 70,
                        left: 16,
                        right: 16,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              profile['name'] ?? 'No Name',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
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
                                  profile['location'] ?? 'Location not specified',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white70,
                                    fontStyle: profile['location'] == null ? FontStyle.italic : FontStyle.normal,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        left: 16,
                        right: 16,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildActionButtons(
                              Icons.close,
                              Colors.red,
                              () async {
                                if (_currentUserId != 0) {
                                  await handleSwipe(
                                    swipeType: 'dislike',
                                    swipedUserId: _currentUserId,
                                    swipedOnId: userId,
                                  );
                                  setState(() {
                                    _matches.removeAt(index);
                                  });
                                }
                              },
                            ),
                            _buildActionButtons(
                              Icons.favorite,
                              Colors.red,
                              () async {
                                if (_currentUserId != 0) {
                                  await handleSwipe(
                                    swipeType: 'like',
                                    swipedUserId: _currentUserId,
                                    swipedOnId: userId,
                                  );
                                  setState(() {
                                    _matches.removeAt(index);
                                  });
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                      // New Like Image Overlay
                      Positioned(
                        top: 0,
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return AnimatedOpacity(
                              opacity: _isLikeOverlayVisible ? 1.0 : 0.0,
                              duration: Duration(milliseconds: 300),
                              child: Center(
                                child: _isLikeOverlayVisible
                                    ? Image.asset(
                                        'assets/like.png',
                                        width: constraints.maxWidth * 0.6,
                                        height: constraints.maxHeight * 0.6,
                                      )
                                    : Container(),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              }),
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

    if (response.statusCode == 200) {
      print('Location updated successfully');
    } else {
      print('Failed to update location: ${response.statusCode}');
      print('Response body: ${response.body}');
    }
  } catch (e) {
    print('Error updating location: $e');
  }
}
}
