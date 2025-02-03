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

  void sendMessage(String message) {
    final payload = {
      'message': message,
      'image': null,
      'sender_id': user1Id,
      'receiver_id': user2Id,
    };
    _channel.sink.add(json.encode(payload));
  }

  void sendImage(String base64Image) {
    final payload = {
      'message': '',
      'image': 'data:image/png;base64,$base64Image',
      'sender_id': user1Id,
      'receiver_id': user2Id,
    };
    _channel.sink.add(json.encode(payload));
  }

  void dispose() {
    _channel.sink.close();
  }
}