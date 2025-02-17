import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'ChatScreen.dart';
import 'dart:async';

class MessageService {
  static final MessageService _instance = MessageService._internal();
  factory MessageService() => _instance;
  MessageService._internal();

  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;
  
  void updateMessage(Map<String, dynamic> messageData) {
    _messageController.add(messageData);
  }

  void dispose() {
    _messageController.close();
  }
}

class ChatListScreen extends StatefulWidget {
  @override
  _ChatListScreenState createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  List<Map<String, dynamic>> chatSessions = [];
  final String baseUrl = "http://192.168.1.241:8000";
  bool _isLoading = true;
  late Stream<dynamic> _messageStream;
  Map<String, int> unreadCounts = {};
  StreamSubscription? _messageSubscription;
  String? _currentChatId;

  @override
  void initState() {
    super.initState();
    _loadChatSessions();
    _initializeMessageStream();
    _startMessageListener();
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    super.dispose();
  }

  void _startMessageListener() {
    final messageService = MessageService();
    _messageSubscription = messageService.messageStream.listen((messageData) {
      _handleNewMessage(messageData);
    });
  }

  void _handleNewMessage(Map<String, dynamic> messageData) {
    if (!mounted) return;

    setState(() {
      bool chatExists = false;
      String? chatKey;

      for (var chat in chatSessions) {
        if ((chat['user1Id'] == messageData['sender_id'] && 
             chat['user2Id'] == messageData['receiver_id']) ||
            (chat['user1Id'] == messageData['receiver_id'] && 
             chat['user2Id'] == messageData['sender_id'])) {
          
          chatKey = '${chat['user1Id']}_${chat['user2Id']}';
          chat['lastMessage'] = messageData['message'];
          chat['timestamp'] = DateTime.now().toIso8601String();
          
          if (_currentChatId != chatKey && messageData['sender_id'] != chat['user1Id']) {
            unreadCounts[chatKey] = (unreadCounts[chatKey] ?? 0) + 1;
          }
          
          chatExists = true;
          break;
        }
      }

      if (!chatExists) {
        Map<String, dynamic> newChat = {
          'user1Id': messageData['receiver_id'],
          'user2Id': messageData['sender_id'],
          'lastMessage': messageData['message'],
          'timestamp': DateTime.now().toIso8601String(),
        };
        chatSessions.add(newChat);
        _fetchMatchDetails(newChat);

        chatKey = '${messageData['receiver_id']}_${messageData['sender_id']}';
        if (messageData['sender_id'] != messageData['receiver_id']) {
          unreadCounts[chatKey] = 1;
        }
      }

      _sortChatSessions();
    });
  }

  void _sortChatSessions() {
    chatSessions.sort((a, b) {
      DateTime timeA = DateTime.parse(a['timestamp'] ?? DateTime.now().toIso8601String());
      DateTime timeB = DateTime.parse(b['timestamp'] ?? DateTime.now().toIso8601String());
      return timeB.compareTo(timeA);
    });
  }

  void _initializeMessageStream() {
    _messageStream = Stream.periodic(Duration(seconds: 5), (_) async {
   
      return null;
    }).asyncMap((event) async => await event);

    _messageStream.listen((event) {
      if (event != null) {
        _updateChatSessions(event);
      }
    });
  }

  void _updateChatSessions(dynamic messageData) {
    setState(() {
      for (var chat in chatSessions) {
        if ((chat['user1Id'] == messageData['sender_id'] && 
             chat['user2Id'] == messageData['receiver_id']) ||
            (chat['user1Id'] == messageData['receiver_id'] && 
             chat['user2Id'] == messageData['sender_id'])) {
          chat['lastMessage'] = messageData['message'];
          chat['timestamp'] = messageData['timestamp'];
          
          if (messageData['sender_id'] != chat['user1Id']) {
            String chatKey = '${chat['user1Id']}_${chat['user2Id']}';
            unreadCounts[chatKey] = (unreadCounts[chatKey] ?? 0) + 1;
          }
          break;
        }
      }
    });
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
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

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

  Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('refresh_token');
  }

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
        return newTokens['access'];
      } else {
        showErrorSnackBar('Session expired. Please log in again.');
        return null;
      }
    } catch (e) {
      showErrorSnackBar('Error refreshing token: $e');
      return null;
    }
  }

  void showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Messages"),
        backgroundColor: Colors.pinkAccent,
        elevation: 2,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : chatSessions.isEmpty
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
                    String chatKey = '${chat['user1Id']}_${chat['user2Id']}';
                    int unreadCount = unreadCounts[chatKey] ?? 0;

                    String name = chat['name'] ?? 'Unknown User';
                    String profilePic = chat['profilePic'] ?? '';
                    String lastMessage = chat['lastMessage'] ?? 'No messages yet';
                    String timestamp = _formatTimestamp(chat['timestamp']);

                    return ListTile(
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: Stack(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundImage: profilePic.isNotEmpty
                                ? NetworkImage(profilePic)
                                : AssetImage('assets/default_profile.png') as ImageProvider,
                          ),
                          if (unreadCount > 0)
                            Positioned(
                              right: 0,
                              top: 0,
                              child: Container(
                                padding: EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  unreadCount.toString(),
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      title: Text(
                        name,
                        style: TextStyle(
                          fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                          fontSize: 16,
                        ),
                      ),
                      subtitle: Text(
                        lastMessage,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          color: unreadCount > 0 ? Colors.black87 : Colors.grey[600],
                          fontWeight: unreadCount > 0 ? FontWeight.w500 : FontWeight.normal,
                        ),
                      ),
                      trailing: Text(
                        timestamp,
                        style: TextStyle(
                          fontSize: 12,
                          color: unreadCount > 0 ? Colors.pinkAccent : Colors.grey[500],
                        ),
                      ),
                      onTap: () {
                        // _setCurrentChat(chatKey);
                  
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatScreen(
                              user1Id: chat['user1Id'],
                              user2Id: chat['user2Id'],
                            ),
                          ),
                        ).then((_) {
                          setState(() {
                            _currentChatId = null;
                          });
                          _loadChatSessions();
                        });
                      },
                    );
                  },
                ),
    );
  }

  String _formatTimestamp(String? timestamp) {
    if (timestamp == null) return '--:--';
    
    DateTime messageTime = DateTime.parse(timestamp);
    DateTime now = DateTime.now();
    Duration difference = now.difference(messageTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d';
    } else {
      return '${messageTime.day}/${messageTime.month}';
    }
  }
}
