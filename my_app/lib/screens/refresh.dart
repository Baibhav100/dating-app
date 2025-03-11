  
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter_dotenv/flutter_dotenv.dart';

String baseurl = dotenv.env['BASE_URL'] ?? 'http://default-url.com';
  
  Future<String> _refreshAccessToken(String refreshToken) async {
    try {
      final response = await http.post(
        Uri.parse('$baseurl/api/token/refresh/'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'refresh_token': refreshToken}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final newAccessToken = data['access'];
        // await prefs?.setString('access_token', newAccessToken);
        return newAccessToken;
      } else {
        throw Exception('Failed to refresh token');
      }
    } catch (e) {
      debugPrint('Error refreshing token: $e');
      rethrow;
    }
  }
