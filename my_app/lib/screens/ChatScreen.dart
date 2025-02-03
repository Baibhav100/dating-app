import 'package:flutter/material.dart';
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
  
  // List to hold the messages and their type (sent or received)
  List<Map<String, dynamic>> messages = [];

  @override
  void initState() {
    super.initState();
    _chatService = ChatService(user1Id: widget.user1Id, user2Id: widget.user2Id);
    
    // Initialize WebSocket
    _chatService.initializeWebSocket((messageData) {
      // Debugging: Check the received message data
      print("Received message data: $messageData");

      // Get the sender's ID and the message content
      int senderId = messageData['sender_id'];
      String message = messageData['message'] ?? '';
      
      // Debug print to check if your ID matches the sender_id
      print("Current user's ID: ${widget.user1Id}");
      print("Sender's ID from message: $senderId");

      // Check if the sender is not the current user
      if (message.isNotEmpty && senderId != widget.user1Id) {
        // Treat received messages as from the other user
        setState(() {
          messages.add({'message': message, 'isSent': false}); // isSent = false for received messages
        });
      } else {
        print("Message from the current user (not adding to received list).");
      }
    });
  }

  void _sendMessage() {
    String message = _messageController.text.trim();
    if (message.isNotEmpty) {
      // Send message using the ChatService
      _chatService.sendMessage(message);
      print("Sent: $message");

      // Add the sent message to the list
      setState(() {
        messages.add({'message': message, 'isSent': true}); // isSent = true for sent messages
      });
      _messageController.clear();
    }
  }

  @override
  void dispose() {
    _chatService.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Chat")),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: messages.length,
              itemBuilder: (context, index) {
                bool isSent = messages[index]['isSent']; // Determine if the message is sent or received
                String message = messages[index]['message']; // Get the message content

                return Align(
                  alignment: isSent ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                    decoration: BoxDecoration(
                      color: isSent ? Colors.blue : Colors.grey,
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: Text(
                      message,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: "Type a message...",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _sendMessage,
                  child: const Text("Send"),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
