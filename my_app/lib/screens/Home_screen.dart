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

  // Add variables to store user details
  String? _userName;
  String? _userEmail;
  String? _profilePicture;
  int? _creditScore;// Initialize with a default value

  // Function to fetch matches from the API
  Future<List<dynamic>> _fetchMatches() async {
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
        return data['matches'];
      } else {
        throw Exception('Failed to load matches');
      }
    } catch (e) {
      print('Error fetching matches: $e');
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
  _tabController = TabController(length: 3, vsync: this); // Initialize with the correct length

  // Set the system navigation bar color to red and icon color to white
  // SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
  //   systemNavigationBarColor: Color.fromARGB(255, 250, 16, 106), // Set the background color to red
  //   systemNavigationBarIconBrightness: Brightness.light, // Set the icon brightness to light
  // ));

  // Initialize with passed tokens if available
  if (widget.accessToken != null && widget.refreshToken != null) {
    accessToken = widget.accessToken;
    refreshToken = widget.refreshToken;

    // Fetch user details, matches, and credit score
    _fetchUserDetails().then((_) {
      _fetchMatches().then((matches) {
        setState(() {
          _matches = matches;
        });
      });
      _fetchCreditScore(); // Fetch credit score after user details
    });
    fetchCurrentUserId();
  } else {
    // Fallback to loading from SharedPreferences
    _loadTokens().then((_) {
      _fetchUserDetails().then((_) {
        _fetchMatches().then((matches) {
          setState(() {
            _matches = matches;
          });
        });
        _fetchCreditScore(); // Fetch credit score after user details
      });
      fetchCurrentUserId();
    });
  }
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
  void _showFilterScreen() {
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
                    items: ['Option 1', 'Option 2', 'Option 3']
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
        decoration: BoxDecoration(
          
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
child: ClipRRect(
  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
  child: BottomNavigationBar(
    items: [
      BottomNavigationBarItem(
        icon: _buildAnimatedIcon(Icons.favorite, 0),
        label: 'Discover',
      ),
      BottomNavigationBarItem(
        icon: Stack(
          children: [
            _buildAnimatedIcon(Icons.people, 1),
            // Notification badge for new matches
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(6),
                ),
                constraints: const BoxConstraints(
                  minWidth: 12,
                  minHeight: 12,
                ),
                child: const Text(
                  '2', // Replace with actual count
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
        label: 'Matches',
      ),
      BottomNavigationBarItem(
        icon: Stack(
          children: [
            _buildAnimatedIcon(Icons.chat_bubble, 2),
            // Notification badge for unread messages
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(6),
                ),
                constraints: const BoxConstraints(
                  minWidth: 12,
                  minHeight: 12,
                ),
                child: const Text(
                  '5', // Replace with actual count
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
        label: 'Messages',
      ),
      BottomNavigationBarItem(
        icon: _buildAnimatedIcon(Icons.person, 3),
        label: 'Profile',
      ),
    ],
    currentIndex: _currentIndex,
    selectedItemColor: Colors.red,
    unselectedItemColor: Colors.white,
    selectedFontSize: 12,
    unselectedFontSize: 12,
    type: BottomNavigationBarType.fixed,
    backgroundColor: const Color.fromARGB(255, 250, 16, 106),
    elevation: 0,
    onTap: (index) {
      setState(() {
        _currentIndex = index;
      });
    },
  ),
),
      ),
    drawer: Drawer(
    child: ListView(
      padding: EdgeInsets.zero,
      children: [
      DrawerHeader(
        decoration: BoxDecoration(
          color: primaryColor,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
        Row(
          children: [
            CircleAvatar(
          radius: 30,
          backgroundImage: _profilePicture != null
              ? NetworkImage('$baseurl$_profilePicture')
              : null,
            ),
            const SizedBox(width: 10),
            Text(
          'Settings',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          _userName ?? 'User',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          _userEmail ?? 'user@example.com',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 14,
          ),
        ),
          ],
        ),
      ),
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
        leading: Icon(Icons.privacy_tip, color: primaryColor),
        title: Text('Privacy Settings', style: TextStyle(color: textColor)),
        onTap: () {
        // Navigate to Privacy Settings Screen
        },
      ),
      ListTile(
        leading: Icon(Icons.notifications, color: primaryColor),
        title: Text('Notification Settings', style: TextStyle(color: textColor)),
        onTap: () {
        // Navigate to Notification Settings Screen
        },
      ),
      Divider(),
      ListTile(
        leading: Icon(Icons.logout, color: Colors.redAccent),
        title: Text('Logout', style: TextStyle(color: textColor)),
        onTap: () {
        _logout();
        },
      ),
      const SizedBox(height: 20),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        icon: Icon(Icons.star, color: Colors.white),
        label: Text(
          'Upgrade to Premium',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        onPressed: () {
          Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => PremiumScreen()),
          );
        },
        ),
      ),
      const SizedBox(height: 20),
      Image.asset('assets/sidebar_pic.jpg', height: 200, fit: BoxFit.cover),
      ],
    ),
    ),
    ),
  );
}


Widget _buildAnimatedIcon(IconData icon, int index) {
  return AnimatedContainer(
    duration: const Duration(milliseconds: 200),
    padding: const EdgeInsets.all(8.0),
    decoration: BoxDecoration(
      color: _currentIndex == index ? Colors.white : Colors.transparent,
      borderRadius: BorderRadius.circular(20.0),
    ),
    child: Icon(
      icon,
      size: _currentIndex == index ? 28 : 24,
      color: _currentIndex == index ? Color.fromARGB(255, 250, 16, 106) : Colors.white,
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
  return Column(
    children: [
      Container(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            CircleAvatar(
              radius: 25,
              backgroundImage: _profilePicture != null
                  ? NetworkImage('$baseurl$_profilePicture')
                  : null,
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TweenAnimationBuilder<int>(
                tween: IntTween(begin: 0, end: _creditScore ?? 0),
                duration: const Duration(seconds: 2),
                builder: (context, value, child) {
                  return Row(
                  children: [
                    Text(
                    'Credits: $value',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                    Icons.monetization_on,
                    color: Color.fromARGB(255, 175, 152, 76),
                    size: 20,
                    ),
                  ],
                  );
                },
                ),
              
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => AddCreditsScreen()),
                );
                },
                child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                  const Text(
                    'Add Credits',
                    style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color.fromARGB(255, 255, 255, 255),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.add, color: Colors.green, size: 20),
                  ],
                ),
                ),
              ),
              ],
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.notifications, color: Colors.pinkAccent, size: 20),
              onPressed: () {
                // Add notification functionality here
              },
            ),
            IconButton(
              icon: const Icon(Icons.menu, color: Colors.black, size: 20),
              onPressed: () {
                _scaffoldKey.currentState?.openDrawer();
              },
            ),
          ],
        ),
      ),
      Container(
        child: TabBar(
          controller: _tabController,
          indicatorColor: Colors.pinkAccent,
          labelColor: Colors.pinkAccent,
          unselectedLabelColor: Colors.grey,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          tabs: const [
        Tab(child: Text('All')),
        Tab(child: Text('Boosted')),
        Tab(child: Text('Premium')),
          ],
        ),
      ),
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
Widget _buildActionButton(IconData icon, Color color, VoidCallback onPressed) {
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
Container _buildSuggestedMatches() {
  return Container(
    padding: const EdgeInsets.all(16.0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
 
        const SizedBox(height: 10),
        SizedBox(
          height: 500, // Increased height from 400 to 500
          child: Stack(
            clipBehavior: Clip.none,
            children: List.generate(_matches.length, (index) {
              final match = _matches[index]; // Access the top-level match object
              final profile = match['profile']; // Access the profile details
              final userId = match['user_id']; // Extract user_id directly

              return Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Dismissible(
                  key: Key(userId.toString()), // Use user_id as the key
                  onDismissed: (direction) async {
                    if (_currentUserId != 0) {
                      // Determine swipe direction
                      final isLiked = direction == DismissDirection.startToEnd;
                      final swipeType = isLiked ? 'like' : 'dislike';

                      try {
                        // Pass the correct user_id to handleSwipe
                        await handleSwipe(
                          swipeType: swipeType,
                          swipedUserId: _currentUserId,
                          swipedOnId: userId, // Use the extracted user_id
                        );

                        // Remove the swiped profile from UI
                        setState(() {
                          _matches.removeAt(index);
                        });

                        // Display feedback
                        print('$swipeType: ${profile['name']}');
                      } catch (error) {
                        // Handle errors
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: ${error.toString()}')),
                        );
                      }
                    } else {
                      print('Current user ID is not available');
                    }
                  },
                  background: Container(
                    // Right swipe (like)
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
                    // Left swipe (dislike)
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
                  child: GestureDetector(
                    child: Container(
                      height: 500, // Increased height from 400 to 500
                      alignment: Alignment.topCenter, // Add alignment to top
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        // boxShadow: [
                        //   BoxShadow(
                        //     color: Colors.grey.withOpacity(0.3),
                        //     blurRadius: 8,
                        //     offset: const Offset(0, 4),
                        //   ),
                        // ],
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        alignment: Alignment.topCenter, // Ensure stack content is at top
                        children: [
                          // Profile Image
                          ClipRRect(
                            borderRadius: BorderRadius.circular(15),
                            child: Image.network(
                              '$baseurl${profile['profile_picture']}',
                              fit: BoxFit.cover,
                            ),
                          ),
                          // Gradient overlay
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
                          // Profile Icon
                          Positioned(
                            top: 16,
                            left: 16,
                            child: GestureDetector(
                              onTap: () async {
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
                                          user: profile,
                                          user1Id: _currentUserId,
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
                          // User Info
                          Positioned(
                            bottom: 70,
                            left: 16,
                            right: 16,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    // User Details
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            profile['name'],
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
                                          Row(
                                            children: [
                                           
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  profile['bio'] ?? 'No bio available',
                                                  style: TextStyle(
                                                    fontSize: 15,
                                                    color: Colors.white70,
                                                    fontStyle: profile['bio'] == null ? FontStyle.italic : FontStyle.normal,
                                                    fontWeight: FontWeight.w300,
                                                  ),
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
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
                                  ],
                                ),
                                const SizedBox(height: 12),
                                // Action Buttons
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    _buildActionButton(
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
                                    _buildActionButton(
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
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
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
 
}
