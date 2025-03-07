import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class NotificationScreen extends StatefulWidget {
  @override
  _NotificationScreenState createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final List<String> notifications = [
    'You have a new message from John Doe',
    'Your post has received 10 likes',
    'You have a new follower',
  ];

  @override
  void initState() {
    super.initState();
    // Simulate fetching notifications with a delay
    SchedulerBinding.instance.addPostFrameCallback((_) {
      Future.delayed(Duration(seconds: 1), () {
        setState(() {
          // Simulate fetching notifications
          notifications.addAll([
            'You have a new message from Jane Doe',
            'Your post has received 5 likes',
            'You have a new follower',
          ]);
        });
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
appBar: AppBar(
  leading: IconButton(
    icon: Icon(Icons.arrow_back_ios, color: Colors.pinkAccent),
    onPressed: () => Navigator.pop(context),
  ),
  title: Text(
    'Notifications',
    style: TextStyle(color: Colors.red,fontWeight: FontWeight.bold),
  ),
  
  elevation: 0,
),
      body: notifications.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: EdgeInsets.symmetric(vertical: 16.0),
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                return _buildNotificationItem(notifications[index]);
              },
            ),
    );
  }

  Widget _buildNotificationItem(String notification) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      padding: EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.0),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 2,
            blurRadius: 5,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            Icons.notifications,
            color: Colors.red
            
            ,
            size: 24.0,
          ),
          SizedBox(width: 16.0),
          Expanded(
            child: Text(
              notification,
              style: TextStyle(
                fontSize: 16.0,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            'assets/empty_notifications.png', // Replace with your empty state image
            width: 200,
            height: 200,
          ),
          SizedBox(height: 20),
          Text(
            'No notifications yet!',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          SizedBox(height: 10),
          Text(
            'Check back later for updates.',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }
}