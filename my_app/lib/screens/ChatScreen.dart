import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class ChatScreen extends StatefulWidget {
  final Map<String, dynamic> user; // Receiver's user data
  final int user1Id; // Logged-in user's ID (sender)
  final int user2Id; // Receiver's user ID

  const ChatScreen({
    Key? key,
    required this.user,
    required this.user1Id,
    required this.user2Id,
  }) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late WebSocketChannel _channel;
  final TextEditingController _messageController = TextEditingController();
  List<dynamic> _messages = [];
  String? _authToken;

  @override
  void initState() {
    super.initState();
    _initializeWebSocket();
  }

  void _initializeWebSocket() async {
    final prefs = await SharedPreferences.getInstance();
    _authToken = prefs.getString('access_token');

    // Connect to the WebSocket channel using the receiver's ID
    final url = Uri.parse(
      'ws://192.168.1.76:8000/ws/chat/${widget.user2Id}/?token=$_authToken',
    );

    _channel = WebSocketChannel.connect(url);

    // Listen for incoming messages
    _channel.stream.listen(
      (data) {
        final messageData = json.decode(data);
        if (messageData['type'] == 'previous_messages') {
          setState(() {
            _messages = messageData['messages'];
          });
        } else if (messageData['type'] == 'chat_message') {
          setState(() {
            _messages.add({
              'message': messageData['message'],
              'image': messageData['image'],
              'sender_id': messageData['sender_id'],
              'timestamp': messageData['timestamp'],
            });
          });
        } else if (messageData['type'] == 'error') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(messageData['message'])),
          );
        }
      },
      onError: (error) => print("WebSocket Error: $error"),
      onDone: () => print("WebSocket Connection Closed"),
    );
  }

  void _sendMessage() async {
    if (_messageController.text.isEmpty) return;

    try {
      final message = {
        'message': _messageController.text,
        'image': null,
        'sender_id': widget.user1Id, // Include sender ID
        'receiver_id': widget.user2Id, // Include receiver ID
      };

      // Send the message via WebSocket
      _channel.sink.add(json.encode(message));

      // Add the message locally for immediate display
      setState(() {
        _messages.add({
          'message': _messageController.text,
          'image': null,
          'sender_id': widget.user1Id,
          'timestamp': DateTime.now().toIso8601String(),
        });
      });

      _messageController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send message: $e')),
      );
    }
  }

  Future<void> _sendImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      try {
        final bytes = await File(pickedFile.path).readAsBytes();
        final base64Image = base64Encode(bytes);

        final message = {
          'message': '',
          'image': 'data:image/png;base64,$base64Image',
          'sender_id': widget.user1Id, // Include sender ID
          'receiver_id': widget.user2Id, // Include receiver ID
        };

        _channel.sink.add(json.encode(message));

        // Add the image locally for immediate display
        setState(() {
          _messages.add({
            'message': '',
            'image': base64Image,
            'sender_id': widget.user1Id,
            'timestamp': DateTime.now().toIso8601String(),
          });
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send image: $e')),
        );
      }
    }
  }

  Widget _buildMessageBubble(dynamic message) {
    final isCurrentUser = message['sender_id'] == widget.user1Id;
    final profileImage = isCurrentUser
        ? 'https://your-domain/media/${widget.user['profile_image']}' // Sender's profile image
        : 'https://your-domain/media/${widget.user['profile_image']}'; // Receiver's profile image

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment:
          isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        if (!isCurrentUser)
          CircleAvatar(
            backgroundImage: NetworkImage(profileImage),
            radius: 16,
          ),
        Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.7,
          ),
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isCurrentUser ? Colors.pinkAccent : Colors.grey[300],
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: isCurrentUser ? const Radius.circular(16) : Radius.zero,
              bottomRight: isCurrentUser ? Radius.zero : const Radius.circular(16),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (message['image'] != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    'data:image/png;base64,${message['image']}',
                    width: 200,
                    height: 200,
                    fit: BoxFit.cover,
                  ),
                ),
              if (message['message'].isNotEmpty)
                Text(
                  message['message'],
                  style: TextStyle(
                    color: isCurrentUser ? Colors.white : Colors.black,
                    fontSize: 16,
                  ),
                ),
              const SizedBox(height: 4),
              Text(
                _formatTimestamp(message['timestamp']),
                style: TextStyle(
                  color: isCurrentUser ? Colors.white70 : Colors.black54,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        if (isCurrentUser)
          CircleAvatar(
            backgroundImage: NetworkImage(profileImage),
            radius: 16,
          ),
      ],
    );
  }

  String _formatTimestamp(String timestamp) {
    try {
      final dateTime = DateTime.parse(timestamp);
      return '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return '';
    }
  }

  @override
  void dispose() {
    _channel.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.user['name']),
        backgroundColor: Colors.pinkAccent,
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? const Center(child: Text('Start a conversation!'))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    reverse: true,
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages.reversed.toList()[index];
                      return _buildMessageBubble(message);
                    },
                  ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.image, color: Colors.pinkAccent),
              onPressed: _sendImage,
            ),
            Expanded(
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey[200],
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: Colors.pinkAccent,
              child: IconButton(
                icon: const Icon(Icons.send, color: Colors.white),
                onPressed: _sendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }
}