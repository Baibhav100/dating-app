import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class FCMService {
  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  static const String _tokenKey = 'fcm_token';
  static String baseUrl = dotenv.env['BASE_URL'] ?? 'http://default-url.com';

  static Future<void> initialize() async {
    try {
      await _initializeLocalNotifications();
      // Request permission
      NotificationSettings settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        // Configure foreground notification presentation
        await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );

        // Always get and sync token on startup
        String? token = await _firebaseMessaging.getToken();
        if (token != null) {
          // Directly sync with backend without checking if it's new
          await _syncTokenWithBackend(token);
          // Save locally after successful sync
          await _saveTokenLocally(token);
        }

        // Listen to token refresh
        _firebaseMessaging.onTokenRefresh.listen((newToken) async {
          await _syncTokenWithBackend(newToken);
          await _saveTokenLocally(newToken);
        });

        // Set up message handlers with notification display
        FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
        FirebaseMessaging.onBackgroundMessage(_handleBackgroundMessage);
        FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);
      }
    } catch (e) {
      print('Error initializing FCM: $e');
    }
  }

  static Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        // Handle notification tap
        print('Notification tapped with payload: ${details.payload}');
        // Add navigation logic here
      },
    );

    // Create high importance notification channel for Android
    await _createNotificationChannel();
  }

  static Future<void> _createNotificationChannel() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel',
      'High Importance Notifications',
      description: 'This channel is used for important notifications.',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    await _localNotifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(channel);
  }

  static Future<void> _saveTokenLocally(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, token);
    } catch (e) {
      print('Error saving FCM token locally: $e');
    }
  }

  static Future<void> _syncTokenWithBackend(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final authToken = prefs.getString('access_token');
      final userId = prefs.getString('user_id');

      print('Syncing FCM token with backend...');
      print('User ID: $userId');
      print('FCM Token: $token');
      print('Base URL: $baseUrl');

      if (authToken == null || userId == null) {
        throw Exception('No auth token or user ID found');
      }

      final Map<String, dynamic> requestBody = {
        'device_token': token,
      };

      print('Request body: ${jsonEncode(requestBody)}');

      final response = await http.post(
        Uri.parse('$baseUrl/auth/fcm/register/'),
        headers: {
          'Authorization': 'Bearer $authToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      ).timeout(
        Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Request timed out');
        },
      );

      print('Response status code: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('Successfully synced FCM token with backend');
        // Store sync status
        await prefs.setBool('fcm_token_synced', true);
      } else {
        throw Exception(
          'Failed to sync FCM token with backend. Status: ${response.statusCode}, Body: ${response.body}',
        );
      }
    } catch (e, stackTrace) {
      print('Error syncing FCM token with backend: $e');
      print('Stack trace: $stackTrace');
      
      // Store sync status
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('fcm_token_synced', false);
      
      // Retry logic
      await _scheduleRetry(token);
    }
  }

  static Future<void> _scheduleRetry(String token) async {
    // Wait for 5 seconds before retrying
    await Future.delayed(Duration(seconds: 5));
    try {
      await _syncTokenWithBackend(token);
    } catch (e) {
      print('Retry failed: $e');
    }
  }

  // Add method to manually trigger token sync
  static Future<void> resyncToken() async {
    try {
      String? token = await _firebaseMessaging.getToken();
      if (token != null) {
        await _syncTokenWithBackend(token);
      }
    } catch (e) {
      print('Error resyncing token: $e');
    }
  }

  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print('Handling foreground message: ${message.messageId}');
    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;

    // Show local notification
    if (notification != null) {
      await _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'high_importance_channel',
            'High Importance Notifications',
            channelDescription: 'This channel is used for important notifications.',
            importance: Importance.high,
            priority: Priority.high,
            icon: android?.smallIcon,
            playSound: true,
            enableVibration: true,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: jsonEncode(message.data),
      );
    }
  }

  static Future<void> _handleBackgroundMessage(RemoteMessage message) async {
    print('Handling background message: ${message.messageId}');
    // Show notification even in background
    await _handleForegroundMessage(message);
  }

  static Future<void> _handleMessageOpenedApp(RemoteMessage message) async {
    print('Handling message opened app: ${message.messageId}');
    // Handle navigation when notification is tapped
    // You can use a NavigationService or similar to handle navigation
    final data = message.data;
    if (data.containsKey('route')) {
      // Handle navigation to specific route
      print('Should navigate to: ${data['route']}');
    }
  }

  static Future<void> deleteToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
      await _firebaseMessaging.deleteToken();
    } catch (e) {
      print('Error deleting FCM token: $e');
    }
  }
}
