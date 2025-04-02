import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:image_picker/image_picker.dart';

// Model for GalleryImage
class GalleryImage {
  final int user_profile;
  final String image;
  final String description;
  final DateTime uploaded_at;

  GalleryImage({
    required this.user_profile,
    required this.image,
    required this.description,
    required this.uploaded_at,
  });

  factory GalleryImage.fromJson(Map<String, dynamic> json) {
    return GalleryImage(
      user_profile: json['user_profile'],
      image: json['image'],
      description: json['description'],
      uploaded_at: DateTime.parse(json['uploaded_at']),
    );
  }
}

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gallery App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: GalleryScreen(),
    );
  }
}

class GalleryScreen extends StatefulWidget {
  @override
  _GalleryScreenState createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  List<GalleryImage> _galleryImages = [];

  @override
  void initState() {
    super.initState();
    _fetchGalleryImages();
  }

  Future<void> _fetchGalleryImages() async {
    try {
      List<GalleryImage> images = await fetchGalleryImages();
      setState(() {
        _galleryImages = images;
      });
    } catch (e) {
      print('Error fetching gallery images: $e');
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      File imageFile = File(pickedFile.path);
      await uploadImage(imageFile, 'Description'); // Add description as needed
      _fetchGalleryImages();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Gallery'),
      ),
      body: Column(
        children: [
          SizedBox(height: 16),
          Text(
            'Gallery',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 8),
          Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: GridView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: _galleryImages.length + 1,
              itemBuilder: (context, index) {
                if (index == _galleryImages.length) {
                  return GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      color: Colors.grey[300],
                      child: Icon(
                        Icons.add,
                        size: 30,
                        color: Colors.grey[600],
                      ),
                    ),
                  );
                }
                return Image.network(
                  _galleryImages[index].image,
                  fit: BoxFit.cover,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// Function to upload image
Future<void> uploadImage(File imageFile, String description) async {
  var request = http.MultipartRequest(
    'POST',
    Uri.parse('YOUR_BACKEND_API_URL'), // Replace with your backend API URL
  );

  request.files.add(
    await http.MultipartFile.fromPath(
      'image',
      imageFile.path,
    ),
  );

  request.fields['description'] = description;

  var response = await request.send();
  if (response.statusCode == 201) {
    print('Image uploaded successfully');
  } else {
    print('Failed to upload image');
  }
}

// Function to fetch gallery images
Future<List<GalleryImage>> fetchGalleryImages() async {
  final response = await http.get(
    Uri.parse('YOUR_BACKEND_API_URL'), // Replace with your backend API URL
  );

  if (response.statusCode == 200) {
    List<dynamic> data = json.decode(response.body);
    return data.map((item) => GalleryImage.fromJson(item)).toList();
  } else {
    throw Exception('Failed to load gallery images');
  }
}