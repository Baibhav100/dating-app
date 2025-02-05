import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'ChatScreen.dart';

class ChatListScreen extends StatefulWidget {
  @override
  _ChatListScreenState createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  List<Map<String, dynamic>> chatSessions = [];
  final String baseUrl = "http://192.168.1.76:8000";

  @override
  void initState() {
    super.initState();
    _loadChatSessions();
  }

  /// Get access token from SharedPreferences
  Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  /// Get refresh token from SharedPreferences
  Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('refresh_token');
  }

  /// Refresh the access token if expired
  Future<String?> refreshAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    final refreshToken = await getRefreshToken();

    if (refreshToken == null) {
      showErrorSnackBar('Session expired. Please log in again.');
      return null;
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/token/refresh/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh': refreshToken}),
      );

      if (response.statusCode == 200) {
        final newTokens = json.decode(response.body);
        await prefs.setString('access_token', newTokens['access']);
        return newTokens['access']; // Return the new access token
      } else {
        showErrorSnackBar('Session expired. Please log in again.');
        return null;
      }
    } catch (e) {
      showErrorSnackBar('Error refreshing token: $e');
      return null;
    }
  }

  Future<void> _loadChatSessions() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? storedChats = prefs.getStringList("chat_sessions");

    if (storedChats != null) {
      List<Map<String, dynamic>> loadedChats = storedChats
          .map((chat) => jsonDecode(chat) as Map<String, dynamic>)
          .toList();

      for (var chat in loadedChats) {
        await _fetchMatchDetails(chat);
      }

      setState(() {
        chatSessions = loadedChats;
      });
    }
  }

  /// Fetch match details dynamically
  Future<void> _fetchMatchDetails(Map<String, dynamic> chat) async {
    try {
      String? accessToken = await getAccessToken();
      if (accessToken == null) {
        accessToken = await refreshAccessToken();
        if (accessToken == null) return;
      }

      int userId = chat['user2Id'];
      var response = await http.get(
        Uri.parse("$baseUrl/auth/api/users/$userId/"),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );

      if (response.statusCode == 200) {
        var userData = jsonDecode(response.body);
        chat['name'] = userData['name'] ?? 'Unknown User';
        chat['profilePic'] = userData['profile_picture'] != null
            ? "$baseUrl${userData['profile_picture']}"
            : '';
      } else if (response.statusCode == 401) {
        // Token expired, refresh and retry
        accessToken = await refreshAccessToken();
        if (accessToken != null) {
          await _fetchMatchDetails(chat);
        }
      } else {
        print("Failed to fetch user details for User ID: $userId");
      }
    } catch (e) {
      print("Error fetching match details: $e");
    }
  }

  /// Show error snackbar
  void showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
     appBar: AppBar(title: Text("Messages"), backgroundColor: Colors.pinkAccent),
      body: chatSessions.isEmpty
          ? Center(
              child: Text(
                "No chats yet",
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            )
          : ListView.builder(
              itemCount: chatSessions.length,
              itemBuilder: (context, index) {
                var chat = chatSessions[index];

                String name = chat['name'] ?? 'Unknown User';
                String profilePic = chat['profilePic'] ?? '';
                String lastMessage = chat['lastMessage'] ?? 'No messages yet';
                String timestamp = chat['timestamp'] != null
                    ? chat['timestamp'].substring(11, 16)
                    : '--:--';

                return ListTile(
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    radius: 28,
                    backgroundImage: profilePic.isNotEmpty
                        ? NetworkImage(profilePic)
                        : AssetImage('assets/default_profile.png') as ImageProvider,
                  ),
                  title: Text(
                    name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Text(
                    lastMessage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  trailing: Text(
                    timestamp,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatScreen(
                          user1Id: chat['user1Id'],
                          user2Id: chat['user2Id'],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
