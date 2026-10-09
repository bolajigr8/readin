import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:readin_flutter/constants/ionicons.dart';
import 'package:just_audio/just_audio.dart';

import '../../constants/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/bottom_sheet_scaffold.dart';
import '../profile/widgets/settings_row.dart' show AppSwitch;

class AmbientSound {
  const AmbientSound(this.id, this.label, this.icon);
  final String id;
  final String label;
  final IconData icon;

  String get asset => 'assets/audio/$id.mp3';
}

/// Focus sounds, generated for ReadIn (loop seamlessly, ~200 KB each).
/// Drop a recorded `cafe.mp3` into assets/audio to replace the synthetic café.
const List<AmbientSound> kAmbientSounds = [
  AmbientSound('rain', 'Rain', Ionicons.rainy_outline),
  AmbientSound('ocean', 'Ocean waves', Ionicons.water_outline),
  AmbientSound('wind', 'Wind', Ionicons.cloudy_outline),
  AmbientSound('fireplace', 'Fireplace', Ionicons.flame_outline),
  AmbientSound('cafe', 'Café murmur', Ionicons.cafe_outline),
  AmbientSound('brown', 'Brown noise', Ionicons.pulse_outline),
  AmbientSound('pink', 'Pink noise', Ionicons.radio_outline),
];

class AmbientState {
  const AmbientState({this.active = const {}});

  /// id → volume (0–1) of the sounds that are playing.
  final Map<String, double> active;

  bool isOn(String id) => active.containsKey(id);
}

/// Mix of looping sounds that can play while you read (several at once).
class AmbientController extends StateNotifier<AmbientState> {
  AmbientController() : super(const AmbientState());

  final Map<String, AudioPlayer> _players = {};

  Future<void> toggle(String id) async {
    if (state.isOn(id)) {
      await _stop(id);
      return;
    }
    const volume = 0.6;
    try {
      final p = _players[id] ?? AudioPlayer();
      _players[id] = p;
      await p.setAsset('assets/audio/$id.mp3');
      await p.setLoopMode(LoopMode.one);
      await p.setVolume(volume);
      state = AmbientState(active: {...state.active, id: volume});
      p.play(); // never completes while looping — do not await
    } catch (_) {
      state = AmbientState(active: {...state.active}..remove(id));
    }
  }

  Future<void> setVolume(String id, double v) async {
    if (!state.isOn(id)) return;
    state = AmbientState(active: {...state.active, id: v});
    try {
      await _players[id]?.setVolume(v);
    } catch (_) {}
  }

  Future<void> _stop(String id) async {
    state = AmbientState(active: {...state.active}..remove(id));
    try {
      await _players[id]?.stop();
    } catch (_) {}
  }

  Future<void> stopAll() async {
    for (final id in state.active.keys.toList()) {
      await _stop(id);
    }
  }

  @override
  void dispose() {
    for (final p in _players.values) {
      p.dispose();
    }
    super.dispose();
  }
}

final ambientProvider =
    StateNotifierProvider<AmbientController, AmbientState>((ref) => AmbientController());

Future<void> showAmbientSheet(BuildContext context) {
  return showAppBottomSheet<void>(
    context,
    builder: (ctx) => Consumer(
      builder: (ctx, ref, _) {
        final st = ref.watch(ambientProvider);
        final ctl = ref.read(ambientProvider.notifier);
        return BottomSheetScaffold(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Focus sounds', style: AppTypography.section17),
                const SizedBox(height: 4),
                Text(
                  'Mix several. They stop when you leave the book.',
                  style: AppTypography.label(size: 12, color: AppColors.textMuted),
                ),
                const SizedBox(height: 8),
                for (final s in kAmbientSounds) ...[
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: st.isOn(s.id)
                              ? AppColors.alpha(AppColors.primary500, 0x20)
                              : AppColors.surface,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          s.icon,
                          size: 19,
                          color: st.isOn(s.id) ? AppColors.primary500 : AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(s.label, style: AppTypography.label(size: 15, weight: FontWeight.w500)),
                      ),
                      AppSwitch(value: st.isOn(s.id), onChanged: (_) => ctl.toggle(s.id)),
                    ],
                  ),
                  if (st.isOn(s.id))
                    SliderTheme(
                      data: SliderTheme.of(ctx).copyWith(
                        trackHeight: 3,
                        activeTrackColor: AppColors.primary500,
                        inactiveTrackColor: AppColors.borderLight,
                        thumbColor: AppColors.primary500,
                      ),
                      child: Slider(
                        value: st.active[s.id] ?? 0.6,
                        onChanged: (v) => ctl.setVolume(s.id, v),
                      ),
                    ),
                ],
                if (st.active.isNotEmpty)
                  TextButton(
                    onPressed: ctl.stopAll,
                    child: Text(
                      'Stop all',
                      style: AppTypography.label(size: 14, weight: FontWeight.w600, color: AppColors.error500),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
