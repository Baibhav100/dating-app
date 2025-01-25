import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
// ignore: unused_import
import 'ProfileScreen.dart';
import 'Welcome.dart';
import 'login_screen.dart';
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io';
import 'package:http/http.dart' as http;

class HomePage extends StatefulWidget {
  final String? accessToken;
  final String? refreshToken;

  const HomePage({super.key, this.accessToken, this.refreshToken});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
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

  // Function to fetch matches from the API
  Future<List<dynamic>> _fetchMatches() async {
    try {
      if (accessToken == null) {
        await _loadTokens();
        if (accessToken == null) {
          throw Exception('Access token not available');
        }
      }

      final response = await http.get(
        Uri.parse('http://192.168.1.76:8000/auth/connections/'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['matches'];
      } else if (response.statusCode == 401) {
        // Token expired, try refreshing
        await _loadTokens();
        return _fetchMatches(); // Retry after refresh
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
      refreshToken = prefs?.getString('refresh_token');

      if (accessToken == null && refreshToken != null) {
        // Try to refresh the token if access token is missing but we have refresh token
        accessToken = refreshToken;
      }
    } catch (e) {
      print('Error loading tokens: $e');
    }
  }

  Future<String> _refreshAccessToken(String refreshToken) async {
    try {
      final response = await http.post(
        Uri.parse('http://192.168.1.76:8000/auth/refresh/'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'refresh_token': refreshToken}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final newAccessToken = data['access'];
        await prefs?.setString('access_token', newAccessToken);
        return newAccessToken;
      } else {
        throw Exception('Failed to refresh token');
      }
    } catch (e) {
      print('Error refreshing token: $e');
      throw e;
    }
  }

  // Function to fetch user details from the API
  Future<void> _fetchUserDetails() async {
    try {
      final response = await http.get(
        Uri.parse('http://192.168.1.76:8000/auth/my-profile/'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
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

  @override
  void initState() {
    super.initState();
    // Initialize with passed tokens if available
    if (widget.accessToken != null && widget.refreshToken != null) {
      accessToken = widget.accessToken;
      refreshToken = widget.refreshToken;
      _fetchUserDetails().then((_) {
        _fetchMatches().then((matches) {
          setState(() {
            _matches = matches;
          });
        });
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
        });
         fetchCurrentUserId();
      });
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
                : IndexedStack(
                    index: _currentIndex,
                    children: [
                      _buildHomeScreen(),    // Swipe/Discover Tab
                      _buildMatchesScreen(), // Matches Tab
                      _buildChatScreen(),    // Messages Tab
                     ProfileScreen(), // Profile Tab
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
                    // Add notification badge for new matches
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
                    // Add notification badge for unread messages
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
            selectedItemColor: Colors.pinkAccent,
            unselectedItemColor: Colors.grey,
            selectedFontSize: 12,
            unselectedFontSize: 12,
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.white,
            elevation: 0,
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

  Widget _buildAnimatedIcon(IconData icon, int index) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: _currentIndex == index 
            ? Colors.pinkAccent.withOpacity(0.2) 
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Icon(
        icon,
        size: _currentIndex == index ? 28 : 24,
        color: _currentIndex == index ? Colors.pinkAccent : Colors.grey,
      ),
    );
  }

  // New method for Matches screen
  // Widget _buildMatchesScreen() {
  //   return Column(
  //     children: [
  //       // Header
  //       Padding(
  //         padding: const EdgeInsets.all(16.0),
  //         child: Text(
  //           'Your Matches',
  //           style: TextStyle(
  //             fontSize: 24,
  //             fontWeight: FontWeight.bold,
  //             color: Colors.grey[800],
  //           ),
  //         ),
  //       ),
  //       // Matches grid or list
  //       Expanded(
  //         child: GridView.builder(
  //           padding: const EdgeInsets.all(16),
  //           gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
  //             crossAxisCount: 2,
  //             childAspectRatio: 0.75,
  //             crossAxisSpacing: 16,
  //             mainAxisSpacing: 16,
  //           ),
  //           itemCount: _matches.length,
  //           itemBuilder: (context, index) {
  //             final match = _matches[index]['profile'];
  //             return _buildMatchCard(match);
  //           },
  //         ),
  //       ),
  //     ],
  //   );
  // }



Widget _buildMatchesScreen() {
  return DefaultTabController(
    length: 3, // Number of tabs
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
              color: Colors.grey[800],
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
        Expanded(
          child: TabBarView(
            children: [
              _buildMatchesTabContent('matches'), // Matches tab
              _buildMatchesTabContent('likes'), // Likes tab
              _buildMatchesTabContent('whoLikedMe'), // Who Liked Me tab
            ],
          ),
        ),
      ],
    ),
  );
}

// .....................................................................................................
// Matches Section
// ................................................................


Widget _buildMatchesTabContent(String tabType) {
  return FutureBuilder<List<dynamic>>(
    future: _Matches(), // Fetch matches asynchronously
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        // Show loading spinner while fetching data
        return const Center(child: CircularProgressIndicator());
      } else if (snapshot.hasError) {
        // Show error message if fetching fails
        return Center(
          child: Text(
            'Error: ${snapshot.error}',
            style: const TextStyle(color: Colors.red),
          ),
        );
      } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
        // Show a message if no matches are found
        return const Center(
          child: Text('No matches found'),
        );
      } else {
        // Display matches in a vertical list
        final matches = snapshot.data!;
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 12),
          itemCount: matches.length,
          itemBuilder: (context, index) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
              child: SizedBox(
                width: MediaQuery.of(context).size.width,
                child: _buildMatchCard(matches[index]),
              ),
            );
          },
        );
      }
    },
  );
}


Future<List<dynamic>> _Matches() async {
  const url = 'http://192.168.1.76:8000/auth/matches/';
  try {
    final response = await http.get(
      Uri.parse(url),
      headers: {
     'Authorization': 'Bearer $accessToken', // Replace with your actual access token
      },
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to fetch matches. Status code: ${response.statusCode}');
    }
  } catch (e) {
    throw Exception('Failed to fetch matches: $e');
  }
}
Widget _buildMatchCard(Map<String, dynamic> match) {
  return Container(
    width: double.infinity, // Ensures the card spans the full width of the device
    margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8), // Reduce horizontal margin
    child: Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User profiles and love symbol
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // User 1 profile
                Column(
                  children: [
                    CircleAvatar(
                      radius: 35, // Slightly larger profile picture
                      backgroundImage: CachedNetworkImageProvider(
                        match['user1_profile_pic'] ??
                            'https://via.placeholder.com/150', // Fallback image
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      match['user1_username'] ?? 'User 1',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),

                // Love symbol
                const Icon(
                  Icons.favorite,
                  color: Colors.pinkAccent,
                  size: 50,
                ),

                // User 2 profile
                Column(
                  children: [
                    CircleAvatar(
                      radius: 35,
                      backgroundImage: CachedNetworkImageProvider(
                        match['user2_profile_pic'] ??
                            'https://via.placeholder.com/150', // Fallback image
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      match['user2_username'] ?? 'User 2',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Match details
            Text(
              'Matched on: ${match['created_at'] ?? 'Unknown date'}',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 12),

            // Delete button
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await _deleteMatch(match['id'], context);
                },
                icon: const Icon(
                  Icons.delete,
                  color: Colors.white,
                  size: 18,
                ),
                label: const Text('Delete Match'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}


Future<void> _deleteMatch(int matchId, BuildContext context) async {
  final url = 'http://192.168.1.76:8000/auth/matches/$matchId/remove/';
  try {
    final response = await http.delete(
      Uri.parse(url),
      headers: {
         'Authorization': 'Bearer $accessToken', // Replace with your actual access token
      },
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
        // Header with Circular Image and Name
        Container(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // User Info and Notification Section
              Row(
                children: [
                  // Circular Image
                  CircleAvatar(
                    radius: 30,
                    backgroundImage: _profilePicture != null
                        ? NetworkImage('http://192.168.1.76:8000${_profilePicture}')
                        : null,
                    backgroundColor: Colors.grey[200],
                    child: _profilePicture == null
                        ? Icon(Icons.person, color: Colors.grey[400])
                        : null,
                  ),
                  const SizedBox(width: 16),
                  // User Details
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _userName ?? 'Loading...', // Display the user's name
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color.fromARGB(255, 36, 35, 35),
                        ),
                      ),
                      Text(
                        _userEmail ?? 'Loading...', // Display the user's email
                        style: TextStyle(
                          fontSize: 14,
                          color: Color.fromARGB(179, 59, 58, 58),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Notification Bell Icon
                  IconButton(
                    icon: const Icon(Icons.notifications, color: Colors.pinkAccent),
                    onPressed: () {
                      // Add notification functionality here
                    },
                  ),
                  // Logout Icon
                  IconButton(
                    icon: const Icon(Icons.logout, color: Colors.black),
                    onPressed: _logout,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Search Bar and Filter Button
              Row(
                children: [
                  // Search Bar
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Search...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey[200],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Filter Button
                  IconButton(
                    onPressed: () {
                      // Show filter screen sliding from the bottom
                      _showFilterScreen();
                    },
                    icon: const Icon(Icons.filter_list, color: Colors.black),
                    tooltip: 'Filter',
                  ),
                ],
              ),
            ],
          ),
        ),
        // Suggested Matches Section
        _buildSuggestedMatches(),

      ],
    );
  }


  Future<void> fetchCurrentUserId() async {
    final url = Uri.parse('http://192.168.1.76:8000/auth/user-details/');
    try {
      // Load tokens
      await _loadTokens(); // This will load accessToken and refreshToken

      if (accessToken != null) {
        // Include the access token in the Authorization header
        final response = await http.get(
          url,
          headers: {
            'Authorization': 'Bearer $accessToken',
          },
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          setState(() {
            _currentUserId = data['user']['id']; // Extract the user ID
          });
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

  const url = 'http://192.168.1.76:8000/auth/swipe/';

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
      iconSize: 30,
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
        const Text(
          'Suggested Matches',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 400,
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
                      height: 400,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Profile Image
                          ClipRRect(
                            borderRadius: BorderRadius.circular(15),
                            child: Image.network(
                              'http://192.168.1.76:8000${profile['profile_picture']}',
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
                          // User Info
                          Positioned(
                            bottom: 70,
                            left: 16,
                            right: 16,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  profile['name'],
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  profile['bio'] ?? 'No bio available',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 16,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          // Action Buttons
                          Positioned(
                            bottom: 16,
                            left: 16,
                            right: 16,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
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
                                  Colors.green,
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
    return const Center(
      child: Text('Chat Screen'),
    );
  }

  // Add the missing profile screen method
 
}
