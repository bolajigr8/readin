import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:readin_flutter/constants/ionicons.dart';

import '../../../constants/app_colors.dart';
import '../../../core/services/routes.dart';
import '../../../theme/app_typography.dart';
import '../../../utils/book_visuals.dart';
import '../../../widgets/pressable_opacity.dart';
import '../providers/audio_controller.dart';
import 'audio_cover.dart';

/// RN `MiniPlayer` (UI_SPEC §4.15): floating card above the tab bar.
/// ([bottomOffset] = tab-bar height; RN floated at `inset + 8` over the bar.)
class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key, required this.bottomOffset});

  final double bottomOffset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = ref.watch(audioControllerProvider);
    final ctl = ref.read(audioControllerProvider.notifier);
    if (!a.miniVisible || a.title == null) return const SizedBox.shrink();

    final color = coverColor(a.title!);
    final pct = (a.progress * 100).round();

    return Positioned(
      left: 8,
      right: 8,
      bottom: bottomOffset + 8,
      child: Material(
        type: MaterialType.transparency,
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.elevated,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.borderLight),
            boxShadow: [
              BoxShadow(
                color: AppColors.black.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Progress (2 px)
              Container(
                height: 2,
                color: AppColors.borderDefault,
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: a.progress,
                  heightFactor: 1,
                  child: const ColoredBox(color: AppColors.primary500),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    PressableOpacity(
                      pressedOpacity: 0.8,
                      semanticLabel: 'Open audio player',
                      onTap: () => context.push(AppRoutes.audioPlayer),
                      child: AudioCover(
                        coverUrl: a.coverUrl,
                        color: color,
                        size: 40,
                        radius: 8,
                        icon: Ionicons.book,
                        iconSize: 18,
                        bordered: false,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: PressableOpacity(
                        pressedOpacity: 0.8,
                        onTap: () => context.push(AppRoutes.audioPlayer),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              a.title!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.label(size: 13, weight: FontWeight.w600),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              a.total > 0 ? '$pct% listened' : 'Listening...',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.label(
                                size: 11,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    PressableOpacity(
                      pressedOpacity: 0.8,
                      semanticLabel: a.isPlaying ? 'Pause' : 'Play',
                      onTap: a.isPlaying ? ctl.pause : ctl.play,
                      child: Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: AppColors.primary500,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          a.isPlaying ? Ionicons.pause : Ionicons.play,
                          size: 20,
                          color: AppColors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    PressableOpacity(
                      pressedOpacity: 0.7,
                      semanticLabel: 'Close player',
                      onTap: ctl.stop,
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(Ionicons.close, size: 18, color: AppColors.textMuted),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
