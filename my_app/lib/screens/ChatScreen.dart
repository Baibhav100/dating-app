import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:base64/base64.dart';
import 'ChatService.dart';
import 'MessageService.dart'; // Import MessageService

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
      String? imageBase64 = messageData['image']; // Image data

      if (message.isNotEmpty && senderId != widget.user1Id) {
        setState(() {
          messages.add({
            'message': message,
            'image': null,  // No image if it's just a message
            'isSent': false,
            'timestamp': DateTime.now().toIso8601String(),
            'seen': true,
          });
        });
        _saveMessages();
        _updateChatSessions(message);
      }

      if (imageBase64 != null && imageBase64.isNotEmpty) {
        setState(() {
          messages.add({
            'message': null,  // No text message if it's just an image
            'image': imageBase64,  // Store the base64-encoded image
            'isSent': false,
            'timestamp': DateTime.now().toIso8601String(),
            'seen': true,
          });
        });
        _saveMessages();
        _updateChatSessions('[Image]');
      }
    });
  }

  Future<String> _imageToBase64(String imagePath) async {
    File imageFile = File(imagePath);
    List<int> imageBytes = await imageFile.readAsBytes();
    String base64Image = base64Encode(imageBytes);
    return base64Image;
  }

  Future<void> _sendMessage() async {
    String message = _messageController.text.trim();
    String? base64Image;

    // Check if there's a pending image to send
    if (messages.isNotEmpty && messages.last['imagePath'] != null && !messages.last['sent']) {
      base64Image = await _imageToBase64(messages.last['imagePath']);
      
      // Send message with image through WebSocket
      _chatService.sendMessage(message, imageBase64: base64Image);
      
      setState(() {
        messages.last['sent'] = true;
        messages.last['image'] = base64Image;  // Store the base64 image
      });

      // Notify MessageService about the new image message
      MessageService().updateMessage({
        'sender_id': widget.user1Id,
        'receiver_id': widget.user2Id,
        'message': '[Image]',
        'timestamp': DateTime.now().toIso8601String(),
      });
    } else if (message.isNotEmpty) {
      // Send text-only message
      _chatService.sendMessage(message);
      setState(() {
        messages.add({
          'message': message,
          'image': null,
          'isSent': true,
          'timestamp': DateTime.now().toIso8601String(),
          'seen': false,
        });
      });
      _messageController.clear();

      // Notify MessageService about the new text message
      MessageService().updateMessage({
        'sender_id': widget.user1Id,
        'receiver_id': widget.user2Id,
        'message': message,
        'timestamp': DateTime.now().toIso8601String(),
      });
    }
    
    _saveMessages();
    _updateChatSessions(message.isNotEmpty ? message : '[Image]');
  }

  Future<void> _pickAndSendImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,  // Limit image size
      maxHeight: 1024,
      imageQuality: 85,  // Compress image
    );
    
    if (image != null) {
      File imageFile = File(image.path);
      setState(() {
        messages.add({
          'imagePath': imageFile.path,
          'isSent': true,
          'timestamp': DateTime.now().toIso8601String(),
          'seen': false,
          'sent': false,  // Track if image has been sent
        });
      });
      
      // Automatically trigger send
      await _sendMessage();
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
      appBar: AppBar(
        elevation: 1,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: Colors.pinkAccent),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: Colors.grey[200],
              child: Icon(Icons.person, color: Colors.grey[400]),
            ),
            SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Chat",
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  "Online",
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.more_vert, color: Colors.grey[600]),
            onPressed: () {},
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          color: Colors.grey[100],
        ),
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 20),
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
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    offset: Offset(0, -2),
                    blurRadius: 6,
                    color: Colors.black.withOpacity(0.08),
                  ),
                ],
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                  child: Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: IconButton(
                          icon: Icon(Icons.image_outlined, color: Colors.pinkAccent),
                          onPressed: _pickAndSendImage,
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(25),
                          ),
                          child: TextField(
                            controller: _messageController,
                            decoration: InputDecoration(
                              hintText: "Type a message...",
                              hintStyle: TextStyle(color: Colors.grey[500]),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 10,
                              ),
                            ),
                            maxLines: null,
                            textCapitalization: TextCapitalization.sentences,
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.pinkAccent,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: Icon(Icons.send_rounded, color: Colors.white, size: 20),
                          onPressed: _sendMessage,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
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
    return Padding(
      padding: EdgeInsets.only(
        left: isSent ? 60 : 10,
        right: isSent ? 10 : 60,
        bottom: 15,
      ),
      child: Column(
        crossAxisAlignment: isSent ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: isSent ? Colors.pinkAccent : Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomLeft: Radius.circular(isSent ? 20 : 5),
                bottomRight: Radius.circular(isSent ? 5 : 20),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (message != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                    child: Text(
                      message!,
                      style: TextStyle(
                        color: isSent ? Colors.white : Colors.black87,
                        fontSize: 16,
                      ),
                    ),
                  ),
                if (imagePath != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: Image.file(
                      File(imagePath!),
                      width: 200,
                      height: 200,
                      fit: BoxFit.cover,
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}",
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
              if (isSent) ...[
                SizedBox(width: 3),
                Icon(
                  seen ? Icons.done_all : Icons.done,
                  size: 14,
                  color: seen ? Colors.blue : Colors.grey[400],
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
