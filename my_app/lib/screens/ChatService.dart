import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChatService {
  final int user1Id;
  final int user2Id;
  late WebSocketChannel _channel;

  ChatService({required this.user1Id, required this.user2Id});

  void initializeWebSocket(Function(Map<String, dynamic>) onMessageReceived) async {
    final prefs = await SharedPreferences.getInstance();
    final authToken = prefs.getString('access_token');

    final url = Uri.parse('ws://192.168.1.76:8000/ws/chat/$user2Id/?token=$authToken');
    _channel = WebSocketChannel.connect(url);
    _channel.stream.listen((data) {
      print('Raw WebSocket Data: $data'); // Debugging
      final messageData = json.decode(data);
      onMessageReceived(messageData);
    });
  }

  void sendMessage(String message, {String? imageBase64}) {
    if (_channel != null && _channel!.sink != null) {
      final Map<String, dynamic> messageData = {
        'message': message,
        'userId': user1Id,
        'timestamp': DateTime.now().toIso8601String(),
      };

      // Add image data if present
      if (imageBase64 != null) {
        messageData['image'] = imageBase64;
      }

      _channel!.sink.add(jsonEncode(messageData));
    }
  }

  void dispose() {
    _channel.sink.close();
  }
}