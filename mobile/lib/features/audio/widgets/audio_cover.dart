import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:readin_flutter/constants/ionicons.dart';

import '../../../constants/app_colors.dart';

/// Cover image for the audio UI; falls back to a tinted tile with an icon.
class AudioCover extends StatelessWidget {
  const AudioCover({
    super.key,
    required this.coverUrl,
    required this.color,
    required this.size,
    required this.radius,
    this.icon = Ionicons.headset,
    this.iconSize = 60,
    this.bordered = true,
  });

  final String coverUrl;
  final Color color;
  final double size;
  final double radius;
  final IconData icon;
  final double iconSize;
  final bool bordered;

  @override
  Widget build(BuildContext context) {
    Widget fallback() => Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.alpha(color, 0x25),
            borderRadius: BorderRadius.circular(radius),
            border: bordered ? Border.all(color: AppColors.borderDefault) : null,
          ),
          child: Icon(icon, size: iconSize, color: color),
        );

    if (coverUrl.isEmpty) return fallback();
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: CachedNetworkImage(
        imageUrl: coverUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (_, _) => SizedBox(width: size, height: size),
        errorWidget: (_, _, _) => fallback(),
      ),
    );
  }
}
