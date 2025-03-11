import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AuthService {
  static final String baseUrl = dotenv.env['BASE_URL'] ?? 'http://default-url.com';
  
  static Future<String?> refreshAccessToken(String refreshToken) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/token/refresh/'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'refresh': refreshToken // Changed from refresh_token to refresh
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final newAccessToken = data['access'];
        
        // Store new token
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('access_token', newAccessToken);
        
        return newAccessToken;
      } else {
        debugPrint('Failed to refresh token: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('Error refreshing token: $e');
      return null;
    }
  }
}
