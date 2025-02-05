import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'ChatService.dart';

class ChatScreen extends StatefulWidget {
  final int user1Id;
  final int user2Id;

  const ChatScreen({Key? key, required this.user1Id, required this.user2Id}) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late ChatService _chatService;
  final TextEditingController _messageController = TextEditingController();
  List<Map<String, dynamic>> messages = [];
  final ImagePicker _picker = ImagePicker();
  late String chatKey;

  @override
  void initState() {
    super.initState();
    _chatService = ChatService(user1Id: widget.user1Id, user2Id: widget.user2Id);

    chatKey = "chat_messages_${widget.user1Id}_${widget.user2Id}";
    _loadMessages();

    _chatService.initializeWebSocket((messageData) {
      int senderId = messageData['sender_id'];
      String message = messageData['message'] ?? '';

      if (message.isNotEmpty && senderId != widget.user1Id) {
        setState(() {
          messages.add({
            'message': message,
            'isSent': false,
            'timestamp': DateTime.now().toIso8601String(),
            'seen': true,
          });
        });
        _saveMessages();
        _updateChatSessions(message);
      }
    });
  }

  void _sendMessage() {
    String message = _messageController.text.trim();
    if (message.isNotEmpty) {
      _chatService.sendMessage(message);
      setState(() {
        messages.add({
          'message': message,
          'isSent': true,
          'timestamp': DateTime.now().toIso8601String(),
          'seen': false,
        });
      });
      _messageController.clear();
      _saveMessages();
      _updateChatSessions(message);
    }
  }

  Future<void> _pickAndSendImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      File imageFile = File(image.path);
      setState(() {
        messages.add({
          'imagePath': imageFile.path,
          'isSent': true,
          'timestamp': DateTime.now().toIso8601String(),
          'seen': false,
        });
      });
      _saveMessages();
      _updateChatSessions("[Image]");
    }
  }

  Future<void> _saveMessages() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> messageStrings = messages.map((msg) => jsonEncode(msg)).toList();
    await prefs.setStringList(chatKey, messageStrings);
  }

  Future<void> _loadMessages() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? storedMessages = prefs.getStringList(chatKey);
    if (storedMessages != null) {
      setState(() {
        messages = storedMessages.map((msg) => jsonDecode(msg) as Map<String, dynamic>).toList();
      });
    }
  }

  Future<void> _updateChatSessions(String lastMessage) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? storedChats = prefs.getStringList("chat_sessions");

    List<Map<String, dynamic>> chatSessions = storedChats != null
        ? storedChats.map((chat) => jsonDecode(chat) as Map<String, dynamic>).toList()
        : [];

    int existingIndex = chatSessions.indexWhere((chat) => chat['chatKey'] == chatKey);

    Map<String, dynamic> newChat = {
      'chatKey': chatKey,
      'user1Id': widget.user1Id,
      'user2Id': widget.user2Id,
      'lastMessage': lastMessage,
      'timestamp': DateTime.now().toIso8601String(),
    };

    if (existingIndex != -1) {
      chatSessions[existingIndex] = newChat;
    } else {
      chatSessions.add(newChat);
    }

    chatSessions.sort((a, b) => b['timestamp'].compareTo(a['timestamp']));
    prefs.setStringList("chat_sessions", chatSessions.map((chat) => jsonEncode(chat)).toList());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Chat"), backgroundColor: Colors.pinkAccent),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: messages.length,
              itemBuilder: (context, index) {
                bool isSent = messages[index]['isSent'];
                String? message = messages[index]['message'];
                String? imagePath = messages[index]['imagePath'];
                DateTime timestamp = DateTime.parse(messages[index]['timestamp']);
                bool seen = messages[index]['seen'];

                return ChatBubble(
                  message: message,
                  imagePath: imagePath,
                  isSent: isSent,
                  timestamp: timestamp,
                  seen: seen,
                );
              },
            ),
          ),
          Row(
            children: [
              IconButton(icon: Icon(Icons.image, color: Colors.pinkAccent), onPressed: _pickAndSendImage),
              Expanded(
                child: TextField(controller: _messageController, decoration: InputDecoration(hintText: "Type a message...")),
              ),
              IconButton(icon: Icon(Icons.send, color: Colors.pinkAccent), onPressed: _sendMessage),
            ],
          ),
        ],
      ),
    );
  }
}

class ChatBubble extends StatelessWidget {
  final String? message;
  final String? imagePath;
  final bool isSent;
  final DateTime timestamp;
  final bool seen;

  const ChatBubble({
    Key? key,
    this.message,
    this.imagePath,
    required this.isSent,
    required this.timestamp,
    required this.seen,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isSent ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        decoration: BoxDecoration(
          color: isSent ? Colors.pinkAccent : Colors.grey[300],
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(isSent ? 20 : 0),
            topRight: Radius.circular(isSent ? 0 : 20),
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (message != null)
              Text(
                message!,
                style: TextStyle(
                  color: isSent ? Colors.white : Colors.black87,
                  fontSize: 16,
                ),
              ),
            if (imagePath != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  File(imagePath!),
                  width: 200,
                  height: 200,
                  fit: BoxFit.cover,
                ),
              ),
            const SizedBox(height: 4),
            Text(
              "${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}",
              style: TextStyle(
                color: isSent ? Colors.white70 : Colors.black54,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
