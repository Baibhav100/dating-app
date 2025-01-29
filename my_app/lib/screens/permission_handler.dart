import 'package:permission_handler/permission_handler.dart';

class PermissionHelper {
  static Future<void> requestPermissions() async {
    // Request location permissions (foreground)
    var locationStatus = await Permission.locationWhenInUse.request();
    if (locationStatus.isDenied || locationStatus.isPermanentlyDenied) {
      // Handle denied permission
    }

    // Request background location permissions
    var backgroundLocationStatus = await Permission.locationAlways.request();
    if (backgroundLocationStatus.isDenied || backgroundLocationStatus.isPermanentlyDenied) {
      // Handle denied permission
    }

    // Request camera permissions
    var cameraStatus = await Permission.camera.request();
    if (cameraStatus.isDenied || cameraStatus.isPermanentlyDenied) {
      // Handle denied permission
    }

    // Request gallery (storage) permissions
    var galleryStatus = await Permission.photos.request();
    if (galleryStatus.isDenied || galleryStatus.isPermanentlyDenied) {
      // Handle denied permission
    }

    // Request notification permissions
    var notificationStatus = await Permission.notification.request();
    if (notificationStatus.isDenied) {
      // Handle denied permission
    }
  }
}