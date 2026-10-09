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
import '../widgets/audio_cover.dart';

/// UI_SPEC §4.15 — full audio player (modal).
class AudioPlayerScreen extends ConsumerWidget {
  const AudioPlayerScreen({super.key});

  void _close(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = ref.watch(audioControllerProvider);
    final ctl = ref.read(audioControllerProvider.notifier);
    final title = a.title ?? 'Unknown Book';
    final color = coverColor(a.title ?? 'Book');

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, box) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: box.maxHeight),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Row(
                      children: [
                        PressableOpacity(
                          pressedOpacity: 0.7,
                          semanticLabel: 'Close player',
                          onTap: () => _close(context),
                          child: const SizedBox(
                            width: 40,
                            height: 40,
                            child: Icon(
                              Ionicons.chevron_down,
                              size: 24,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'NOW LISTENING',
                            textAlign: TextAlign.center,
                            style: AppTypography.label(
                              size: 13,
                              weight: FontWeight.w500,
                              letterSpacing: 0.8,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                        const SizedBox(width: 40),
                      ],
                    ),
                  ),

                  // Cover
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: color.withValues(alpha: 0.5),
                              blurRadius: 24,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: AudioCover(
                          coverUrl: a.coverUrl,
                          color: color,
                          size: 220,
                          radius: 20,
                        ),
                      ),
                    ),
                  ),

                  // Info
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: AppTypography.label(
                            size: 22,
                            weight: FontWeight.w700,
                            lineHeight: 30,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Text-to-speech preview',
                          style: AppTypography.label(size: 14, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),

                  // Progress
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: Container(
                            height: 4,
                            color: AppColors.borderDefault,
                            alignment: Alignment.centerLeft,
                            child: FractionallySizedBox(
                              widthFactor: a.progress,
                              heightFactor: 1,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: AppColors.primary500,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${a.index}',
                              style: AppTypography.label(size: 12, color: AppColors.textMuted),
                            ),
                            Text(
                              '${a.total} sentences',
                              style: AppTypography.label(size: 12, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Speed
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                    child: Row(
                      children: [
                        Text(
                          'Speed',
                          style: AppTypography.label(
                            size: 13,
                            weight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final s in kSpeedOptions)
                                _SpeedChip(
                                  label: speedLabel(s),
                                  active: a.speed == s,
                                  onTap: () => ctl.setSpeed(s),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Sleep timer
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                    child: Row(
                      children: [
                        Text(
                          'Sleep',
                          style: AppTypography.label(
                            size: 13,
                            weight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              _SpeedChip(
                                label: 'Off',
                                active: a.sleepMinutes == null,
                                onTap: () => ctl.setSleepTimer(null),
                              ),
                              for (final m in const [15, 30, 60])
                                _SpeedChip(
                                  label: '$m min',
                                  active: a.sleepMinutes == m,
                                  onTap: () => ctl.setSleepTimer(m),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Controls
                  Padding(
                    padding: const EdgeInsets.only(top: 32),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        PressableOpacity(
                          pressedOpacity: 0.7,
                          semanticLabel: 'Back 5 sentences',
                          onTap: () => ctl.skip(-5),
                          child: const SizedBox(
                            width: 52,
                            height: 52,
                            child: Icon(
                              Ionicons.play_skip_back_outline,
                              size: 28,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 40),
                        PressableOpacity(
                          pressedOpacity: 0.85,
                          semanticLabel: a.isPlaying ? 'Pause' : 'Play',
                          onTap: a.isPlaying ? ctl.pause : ctl.play,
                          child: Container(
                            width: 72,
                            height: 72,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.primary500,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary500.withValues(alpha: 0.4),
                                  blurRadius: 12,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Icon(
                              a.isPlaying ? Ionicons.pause : Ionicons.play,
                              size: 30,
                              color: AppColors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 40),
                        PressableOpacity(
                          pressedOpacity: 0.7,
                          semanticLabel: 'Forward 5 sentences',
                          onTap: () => ctl.skip(5),
                          child: const SizedBox(
                            width: 52,
                            height: 52,
                            child: Icon(
                              Ionicons.play_skip_forward_outline,
                              size: 28,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Stop
                  Padding(
                    padding: const EdgeInsets.fromLTRB(40, 24, 40, 24),
                    child: PressableOpacity(
                      pressedOpacity: 0.8,
                      onTap: () {
                        ctl.stop();
                        _close(context);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.borderDefault),
                        ),
                        child: Text(
                          'Stop & Close',
                          style: AppTypography.label(
                            size: 14,
                            weight: FontWeight.w500,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SpeedChip extends StatelessWidget {
  const _SpeedChip({required this.label, required this.active, required this.onTap});

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableOpacity(
      pressedOpacity: 0.75,
      semanticLabel: 'Speed $label',
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active ? AppColors.alpha(AppColors.primary500, 0x15) : AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active ? AppColors.primary500 : AppColors.borderDefault,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.label(
            size: 13,
            weight: FontWeight.w500,
            color: active ? AppColors.primary500 : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
