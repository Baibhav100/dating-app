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
