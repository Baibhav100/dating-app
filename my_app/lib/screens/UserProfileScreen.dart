import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'ChatScreen.dart';

String baseurl = dotenv.env['BASE_URL'] ?? 'http://default-url.com';

class UserProfileScreen extends StatelessWidget {
  final Map<String, dynamic> user;
  final int user1Id; // Changed to int
  final int user2Id; 

  UserProfileScreen({required this.user,required this.user1Id,required this.user2Id});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
  
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stack for Cover Image and Profile Image
            Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                // Cover Picture
                CachedNetworkImage(
                  imageUrl: '$baseurl${user['cover_picture'] ?? ''}',
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorWidget: (context, url, error) => const Icon(Icons.error),
                ),

                // Profile Image Positioned on Top
                Positioned(
                  bottom: -50, // Adjust this value to position the profile image
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white, // White border color
                        width: 5, // Border thickness
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 10,
                          spreadRadius: 2,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 50,
                      backgroundImage: user['profile_picture'] != null && user['profile_picture'] != ''
                          ? CachedNetworkImageProvider(baseurl + user['profile_picture'])
                          : const AssetImage('assets/placeholder.png') as ImageProvider,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 60), // Space for profile image overlap

            // Name and Chat Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    user['name'] ?? 'No Name',
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                    overflow: TextOverflow.ellipsis, // Handles long names
                  ),
                ),
            ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatScreen(user: user,
                  user1Id: user1Id, 
                  user2Id: user2Id,),
                ),
              );
            },
            icon: const Icon(Icons.chat, size: 20),
            label: const Text('Chat'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.pinkAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),

              ],
            ),
            const SizedBox(height: 8),

            // About Section (Bio)
            const Text(
              'About:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              user['bio'] ?? 'No bio available',
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.left,
            ),
            const SizedBox(height: 16),

            // Interests Section
            if (user['interests'] != null && user['interests'].isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Interests:',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8.0,
                    children: user['interests']
                        .map<Widget>((interest) => Chip(
                              label: Text(interest.toString()),
                              backgroundColor: Colors.pinkAccent[100],
                              labelStyle: TextStyle(color: Colors.white),
                            ))
                        .toList(),
                  ),
                ],
              ),
            const SizedBox(height: 16),

            // Other Information Section
            const Text(
              'Other Information:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.phone, 'Phone', user['phone_number']),
            _buildInfoRow(Icons.date_range, 'Date of Birth', user['date_of_birth']),
            _buildInfoRow(Icons.female, 'Gender', user['gender']),
            _buildInfoRow(Icons.star, 'Profile Score', user['profile_score']),
          ],
        ),
      ),
    );
  }

  // Helper Widget for Displaying User Info with Icons
  Widget _buildInfoRow(IconData icon, String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.pinkAccent),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black54,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            value?.toString() ?? 'Not Available',
            style: const TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }
}
