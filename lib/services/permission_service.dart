import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  // Request storage permission
  static Future<bool> requestStoragePermission() async {
    if (Platform.isAndroid) {
      if (await Permission.audio.isGranted) {
        return true;
      }
      final status = await Permission.audio.request();
      return status.isGranted;
    } else if (Platform.isIOS) {
      final status = await Permission.storage.request();
      return status.isGranted;
    }
    return false;
  }

  // Check if permission is granted
  static Future<bool> checkPermission() async {
    if (Platform.isAndroid) {
      return await Permission.audio.isGranted;
    } else if (Platform.isIOS) {
      return await Permission.storage.isGranted;
    }
    return false;
  }

  // Show permission dialog
  static Future<void> showPermissionDialog(BuildContext context) async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Permission Required'),
          content: const Text(
              'This app needs access to your music files to play local songs. '
                  'Please grant permission in settings.'
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                openAppSettings(); // This opens system settings
              },
              child: const Text('Open Settings'), // Fixed typo: Settings (plural)
            ),
          ],
        );
      },
    );
  }
}