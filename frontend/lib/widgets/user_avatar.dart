import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../config/api_config.dart';

class UserAvatar extends StatelessWidget {
  final String? fullName;
  final String? photoUrl;
  final Uint8List? memoryBytes;
  final double radius;
  final Color backgroundColor;
  final Color textColor;
  final double? fontSize;

  const UserAvatar({
    super.key,
    this.fullName,
    this.photoUrl,
    this.memoryBytes,
    this.radius = 20,
    this.backgroundColor = const Color(0xFF1E88E5),
    this.textColor = Colors.white,
    this.fontSize,
  });

  String get _resolvedInitials {
    final name = (fullName ?? '').trim();
    if (name.isEmpty) return 'U';

    final parts =
        name.split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();

    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }

    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  String? get _resolvedPhotoUrl {
    if (photoUrl == null || photoUrl!.isEmpty) {
      return null;
    }

    if (photoUrl!.startsWith('http://') || photoUrl!.startsWith('https://')) {
      return photoUrl;
    }

    return '${ApiConfig.baseUrl}$photoUrl';
  }

  Widget _buildFallback() {
    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor,
      child: Text(
        _resolvedInitials,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.bold,
          fontSize: fontSize ?? (radius * 0.62),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (memoryBytes != null) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: backgroundColor,
        child: ClipOval(
          child: SizedBox(
            width: radius * 2,
            height: radius * 2,
            child: Image.memory(memoryBytes!, fit: BoxFit.cover),
          ),
        ),
      );
    }

    final resolvedPhotoUrl = _resolvedPhotoUrl;
    if (resolvedPhotoUrl == null) {
      return _buildFallback();
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor,
      child: ClipOval(
        child: SizedBox(
          width: radius * 2,
          height: radius * 2,
          child: Image.network(
            resolvedPhotoUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) {
              return Container(
                color: backgroundColor,
                alignment: Alignment.center,
                child: Text(
                  _resolvedInitials,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: fontSize ?? (radius * 0.62),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
