import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'ChatService.dart';

class ChatScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final int user1Id;
  final int user2Id;

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
  final TextEditingController _messageController = TextEditingController();
  List<dynamic> _messages = [];
  final StreamController<List<dynamic>> _messageStreamController = StreamController<List<dynamic>>.broadcast();
  late ChatService _chatService;

  @override
  void initState() {
    super.initState();
    _chatService = ChatService(user1Id: widget.user1Id, user2Id: widget.user2Id);
    _initializeWebSocket();
  }

  void _initializeWebSocket() {
    print("Connected to the websocket");
    _chatService.initializeWebSocket((messageData) {
      print('Decoded Message Data: $messageData'); // Debugging
       print('onMessageReceived Triggered: $messageData'); // Debugging
      setState(() {
      _messages.add({
        'message': messageData['message'],
        'image': messageData['image'],
        'sender_id': messageData['sender_id'],
        'timestamp': messageData['timestamp'],
      });
      _messageStreamController.add(_messages);
    });
      if (messageData['type'] == 'previous_messages') {
        setState(() {
          _messages = messageData['messages'];
          _messageStreamController.add(_messages);
        });
      } else if (messageData['type'] == 'chat_message') {
        setState(() {
          _messages.add({
            'message': messageData['message'],
            'image': messageData['image'],
            'sender_id': messageData['sender_id'],
            'timestamp': messageData['timestamp'],
          });
          _messageStreamController.add(_messages);
        });
      } else if (messageData['type'] == 'error') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(messageData['message'])),
        );
      }
    });
  }

  void _sendMessage() {
    if (_messageController.text.isEmpty) return;
    _chatService.sendMessage(_messageController.text);

    // Add the message locally for immediate display
    setState(() {
      _messages.add({
        'message': _messageController.text,
        'image': null,
        'sender_id': widget.user1Id,
        'timestamp': DateTime.now().toIso8601String(),
      });
      _messageStreamController.add(_messages);
    });

    _messageController.clear();
  }

  Future<void> _sendImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      try {
        final bytes = await File(pickedFile.path).readAsBytes();
        final base64Image = base64Encode(bytes);
        _chatService.sendImage(base64Image);

        // Add the image locally for immediate display
        setState(() {
          _messages.add({
            'message': '',
            'image': base64Image,
            'sender_id': widget.user1Id,
            'timestamp': DateTime.now().toIso8601String(),
          });
          _messageStreamController.add(_messages);
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
        ? 'http://192.168.1.76:8000/media/${widget.user['profile_image']}'
        : 'http://192.168.1.76:8000/media/${widget.user['profile_image']}';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
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
    _chatService.dispose();
    _messageStreamController.close();
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
            child: StreamBuilder<List<dynamic>>(
              stream: _messageStreamController.stream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('Start a conversation!'));
                } else {
                  final messages = snapshot.data!;
                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    reverse: true,
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages.reversed.toList()[index];
                      return _buildMessageBubble(message);
                    },
                  );
                }
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