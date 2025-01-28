import 'package:flutter/material.dart';

class RefreshHelper {
  // General method to handle the refresh logic
  static Future<void> onRefresh({
    required BuildContext context,
    required String message,
    required Function callback,
  }) async {
    await Future.delayed(const Duration(seconds: 2));
    callback();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // You can call this for home, matches, chat, or profile refresh
  static Future<void> onHomeRefresh(BuildContext context) async {
    await onRefresh(
      context: context,
      message: 'Home Refreshed',
      callback: () => {}, // Put any logic you need for Home here
    );
  }

  static Future<void> onMatchesRefresh(BuildContext context) async {
    await onRefresh(
      context: context,
      message: 'Matches Refreshed',
      callback: () => {}, // Put any logic you need for Matches here
    );
  }

  static Future<void> onChatRefresh(BuildContext context) async {
    await onRefresh(
      context: context,
      message: 'Chat Refreshed',
      callback: () => {}, // Put any logic you need for Chat here
    );
  }

  static Future<void> onProfileRefresh(BuildContext context) async {
    await onRefresh(
      context: context,
      message: 'Profile Refreshed',
      callback: () => {}, // Put any logic you need for Profile here
    );
  }
}
