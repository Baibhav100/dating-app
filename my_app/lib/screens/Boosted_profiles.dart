import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter_dotenv/flutter_dotenv.dart';

String baseurl = dotenv.env['BASE_URL'] ?? 'http://default-url.com';

class BoostedProfilesScreen extends StatefulWidget {
  String? accessToken;
  String? refreshToken;
  BoostedProfilesScreen({super.key, this.accessToken, this.refreshToken});
  @override
  _BoostedProfilesScreenState createState() => _BoostedProfilesScreenState();
}

class _BoostedProfilesScreenState extends State<BoostedProfilesScreen> {
  SharedPreferences? prefs;
  String? accessToken;
  String? refreshToken;
  List<dynamic> boostedProfiles = [];
  bool hasBoost = false;

  @override
  void initState() {
    super.initState();
    fetchBoostedProfiles();
  }

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
        await prefs?.setString('access_token', newAccessToken);
        return newAccessToken;
      } else {
        throw Exception('Failed to refresh token');
      }
    } catch (e) {
      debugPrint('Error refreshing token: $e');
      rethrow;
    }
  }

  Future<void> _loadTokens() async {
    try {
      prefs = await SharedPreferences.getInstance();
      accessToken = prefs?.getString('access_token');
      refreshToken = prefs?.getString('refresh_token');

      if (accessToken == null && refreshToken != null) {
        // Try to refresh the token if access token is missing but we have refresh token
        accessToken = await _refreshAccessToken(refreshToken!);
      }
    } catch (e) {
      debugPrint('Error loading tokens: $e');
    }
  }

  Future<void> _fetchBoostedProfiles() async {
    await _loadTokens();
    if (accessToken == null) {
      debugPrint('Access token is null, cannot fetch boosted profiles');
      return;
    }

    final response = await http.get(
      Uri.parse('$baseurl/auth/boosted-profiles/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        boostedProfiles = data['boosted_profiles'];
        hasBoost = data['has_boost'];
      });
    } else if (response.statusCode == 401 && refreshToken != null) {
      // Token might be expired, try to refresh it
      try {
        accessToken = await _refreshAccessToken(refreshToken!);
        await _fetchBoostedProfiles(); // Retry fetching profiles with new token
      } catch (e) {
        debugPrint('Error refreshing token: $e');
      }
    } else {
      throw Exception('Failed to load boosted profiles');
    }
  }

  Future<void> fetchBoostedProfiles() async {
    await _fetchBoostedProfiles();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
     appBar: AppBar(
    
      title: Text(
        'Boosted Profiles',
        style: TextStyle(color:Colors.pinkAccent, fontWeight: FontWeight.bold),
      ),
      backgroundColor: const Color.fromARGB(255, 255, 255, 255),
    ),
      body: boostedProfiles.isEmpty
          ? Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: boostedProfiles.length,
              itemBuilder: (context, index) {
                final profile = boostedProfiles[index];
                return Card(
                  child: Stack(
                    children: [
                      ListTile(
                        leading: CircleAvatar(
                          backgroundImage: profile['profile_picture'] != null
                              ? NetworkImage(profile['profile_picture'])
                              : null,
                          child: profile['profile_picture'] == null
                              ? Icon(Icons.person)
                              : null,
                        ),
                        title: Text(profile['name'].trim().isEmpty ? 'No Name' : profile['name']),
                        subtitle: Text('Profile Score: ${profile['profile_score']}'),
                        trailing: hasBoost || !profile['blurred']
                            ? Icon(Icons.visibility)
                            : Icon(Icons.visibility_off),
                      ),
              if (!hasBoost && profile['blurred'])
  Positioned.fill(
    child: Container(
      width: double.infinity,
      height: double.infinity,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
        child: Container(
          color: Colors.black.withOpacity(0),
        ),
      ),
    ),
  ),

                    ],
                  ),
                );
              },
            ),
    );
  }
}