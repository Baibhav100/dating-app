import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:ui';

String baseurl = dotenv.env['BASE_URL'] ?? 'http://default-url.com';

class PremiumScreen extends StatefulWidget {
  final String? accessToken;
  final String? refreshToken;

  const PremiumScreen({super.key, this.accessToken, this.refreshToken});

  @override
  PremiumScreenState createState() => PremiumScreenState();
}

class PremiumScreenState extends State<PremiumScreen> {
  List<dynamic> profiles = [];
  bool isLoading = true;
  String? errorMessage;
  SharedPreferences? prefs;
  String? accessToken;
  String? refreshToken;
  bool shouldBlurAll = false;

  @override
  void initState() {
    super.initState();
    _initializeTokens();
  }

  Future<void> _initializeTokens() async {
    prefs = await SharedPreferences.getInstance();
    accessToken = widget.accessToken ?? prefs?.getString('access_token');
    refreshToken = widget.refreshToken ?? prefs?.getString('refresh_token');

    if (accessToken == null && refreshToken != null) {
      accessToken = await _refreshAccessToken(refreshToken!);
    }

    if (accessToken != null) {
      await fetchProfiles();
    } else {
      setState(() {
        errorMessage = 'Unable to obtain access token';
        isLoading = false;
      });
    }
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
      return '';
    }
  }

  Future<void> fetchProfiles() async {
    if (accessToken == null) {
      setState(() {
        errorMessage = 'No access token available';
        isLoading = false;
      });
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('$baseurl/auth/top-visibility/'),
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<dynamic> parsedProfiles = [];

        if (data is Map) {
          parsedProfiles = (data['top_visible_profiles'] as List?) ?? [];
        } else if (data is List) {
          parsedProfiles = data;
        }

        shouldBlurAll = parsedProfiles.any((profile) => profile['blurred'] == true);

        setState(() {
          profiles = parsedProfiles;
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = 'Failed to fetch profiles: ${response.statusCode}';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error fetching profiles: $e';
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Premium Profiles'),
 
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _buildProfileList(),
            ),
          ],
        ),
      ),
    );
  }

 Widget _buildProfileList() {
  if (isLoading) {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }

  if (errorMessage != null) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error, color: Colors.red, size: 60),
          Text(
            errorMessage!,
            style: const TextStyle(color: Colors.red),
            textAlign: TextAlign.center,
          ),
          ElevatedButton(
            onPressed: fetchProfiles,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  return RefreshIndicator(
    onRefresh: fetchProfiles,
    child: ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(8),
      itemCount: profiles.length,
      itemBuilder: (context, index) {
        final profile = profiles[index];
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Card(
            elevation: 5,
            margin: EdgeInsets.zero,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              leading: CircleAvatar(
                backgroundColor: Colors.blue[100],
                child: const Icon(Icons.person, color: Colors.blue),
              ),
              title: Text(
                profile['name'] ?? 'Unknown Name',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                'Profile Score: ${profile['profile_score'] ?? 'N/A'}',
                style: const TextStyle(color: Colors.black54),
              ),
              trailing: Chip(
                label: const Text('Premium', style: TextStyle(color: Colors.white)),
                backgroundColor: Colors.blue,
              ),
            ),
          ),
        );
      },
    ),
  );
}

}
