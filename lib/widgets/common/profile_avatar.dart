import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../services/profile_picture_service.dart';

class ProfileAvatar extends StatefulWidget {
  final String deviceId;
  final String name;
  final double radius;
  final double fontSize;
  final String? ipAddress;
  final int? port;

  const ProfileAvatar({
    super.key,
    required this.deviceId,
    required this.name,
    this.radius = 24,
    this.fontSize = 18,
    this.ipAddress,
    this.port,
  });

  @override
  State<ProfileAvatar> createState() => _ProfileAvatarState();
}

class _ProfileAvatarState extends State<ProfileAvatar> {
  Uint8List? _imageBytes;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(ProfileAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.deviceId != widget.deviceId ||
        oldWidget.ipAddress != widget.ipAddress ||
        oldWidget.port != widget.port) {
      _loadImage();
    }
  }

  void _loadImage() {
    final cached = ProfilePictureService.instance.get(widget.deviceId);
    if (cached != null) {
      if (_imageBytes != cached) {
        setState(() {
          _imageBytes = cached;
          _loading = false;
        });
      }
      return;
    }
    if (widget.ipAddress != null && widget.port != null && !_loading) {
      _loading = true;
      ProfilePictureService.instance
          .fetch(widget.deviceId, widget.ipAddress!, widget.port!)
          .then((bytes) {
            if (mounted) {
              setState(() {
                _imageBytes = bytes;
                _loading = false;
              });
            }
          });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_imageBytes != null) {
      return CircleAvatar(
        radius: widget.radius,
        backgroundImage: MemoryImage(_imageBytes!),
      );
    }
    return CircleAvatar(
      radius: widget.radius,
      backgroundColor: AppColors.primaryGreenSurface,
      child: _loading
          ? SizedBox(
              width: widget.radius * 0.6,
              height: widget.radius * 0.6,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primaryGreen,
              ),
            )
          : Text(
              widget.name.isNotEmpty ? widget.name[0].toUpperCase() : '?',
              style: TextStyle(
                color: AppColors.primaryGreen,
                fontWeight: FontWeight.w600,
                fontSize: widget.fontSize,
              ),
            ),
    );
  }
}
