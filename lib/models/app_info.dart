import 'dart:convert';
import 'dart:typed_data';

import 'package:equatable/equatable.dart';

class AppInfo extends Equatable {
  final String appName;
  final String packageName;
  final Uint8List? icon; // Decoded icon bytes

  const AppInfo({
    required this.appName,
    required this.packageName,
    this.icon,
  });

  factory AppInfo.fromMap(Map<String, dynamic> map) {
    Uint8List? iconBytes;
    if (map['icon'] != null && map['icon'] is String) {
      try {
        // Assuming icon is Base64 encoded string from native
        iconBytes = base64Decode(map['icon']);
      } catch (e) {
        // Handle Base64 decode error, iconBytes remains null
        print('Error decoding app icon for ${map['packageName']}: $e');
      }
    }

    return AppInfo(
      appName: map['appName'] ?? 'Unknown App',
      packageName: map['packageName'] ?? 'unknown.package',
      icon: iconBytes,
    );
  }

  @override
  List<Object?> get props => [appName, packageName, icon];

  @override
  String toString() => 'AppInfo(appName: $appName, packageName: $packageName, hasIcon: ${icon != null})';
}
