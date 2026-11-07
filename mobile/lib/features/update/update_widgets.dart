import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:readin_flutter/constants/ionicons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/app_version.dart';
import '../../constants/app_colors.dart';
import '../../core/distribution.dart';
import '../../theme/app_typography.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/pressable_opacity.dart';
import 'update_provider.dart';

/// Opens the download page (website APK) or the Play Store page in the phone's browser / Play Store app.
Future<void> openUpdateLink(String url) async {
  final uri = Uri.tryParse(url);
  final ok = uri != null && uri.scheme == 'https' && await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok) AppToast.error('Could not open the download page. Please try again.');
}

String _updateHint(Distribution d) => d == Distribution.play
    ? 'Opens Google Play, where you tap “Update”.'
    : 'Downloads the new version from readin.micbol.org. Open the file and tap “Update” — your books stay on your phone.';

/// Home screen: "Version 1.0.2 is ready" (optional update). Hidden when there is nothing new or after "Later".
class UpdateBanner extends ConsumerWidget {
  const UpdateBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(updateProvider);
    final info = s.info;
    if (!s.showBanner || info == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Container(
        key: const ValueKey('update-banner'),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.alpha(AppColors.primary500, 0x14),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.alpha(AppColors.primary500, 0x60)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Ionicons.cloud_download_outline, size: 20, color: AppColors.primary500),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'ReadIn ${info.latestVersion} is ready',
                    style: AppTypography.label(size: 15, weight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            if (info.releaseNotes.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                info.releaseNotes.take(3).map((n) => '• $n').join('\n'),
                style: AppTypography.label(size: 13, color: AppColors.textSecondary, lineHeight: 19),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: () => ref.read(updateProvider.notifier).later(), child: const Text('Later')),
                const SizedBox(width: 6),
                PressableOpacity(
                  pressedOpacity: 0.85,
                  semanticLabel: 'Update ReadIn',
                  onTap: () => openUpdateLink(info.downloadUrl),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    decoration: BoxDecoration(color: AppColors.primary500, borderRadius: BorderRadius.circular(10)),
                    child: Text(
                      info.sizeText.isEmpty ? 'Update' : 'Update (${info.sizeText})',
                      style: AppTypography.label(size: 14, weight: FontWeight.w700, color: AppColors.white),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Covers the app when an update is REQUIRED (admin: "Required update" or "oldest version still allowed").
/// Never shown while a book is open: it waits until the reader is closed.
class UpdateGate extends ConsumerWidget {
  const UpdateGate({super.key, required this.child, required this.router});

  final Widget child;
  final GoRouter router;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final must = ref.watch(updateProvider.select((s) => s.mustUpdate));
    // The tree shape never changes (the app's Navigator is never moved); only the cover appears/disappears.
    return Stack(
      fit: StackFit.passthrough, // the app gets exactly the constraints it had before
      children: [
        child,
        if (must) Positioned.fill(child: _ReaderAwareCover(router: router)),
      ],
    );
  }
}

/// Shows [UpdateRequiredScreen] except while the reader is open. Route changes are applied after the frame
/// (go_router announces its location while it is still building).
class _ReaderAwareCover extends StatefulWidget {
  const _ReaderAwareCover({required this.router});
  final GoRouter router;

  @override
  State<_ReaderAwareCover> createState() => _ReaderAwareCoverState();
}

class _ReaderAwareCoverState extends State<_ReaderAwareCover> {
  bool _reading = false;

  bool _isReading() {
    try {
      return widget.router.routerDelegate.currentConfiguration.uri.path.startsWith('/reader');
    } catch (_) {
      return false; // no route yet
    }
  }

  void _onRoute() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _isReading() != _reading) setState(() => _reading = _isReading());
    });
  }

  @override
  void initState() {
    super.initState();
    _reading = _isReading();
    widget.router.routerDelegate.addListener(_onRoute);
    _onRoute();
  }

  @override
  void dispose() {
    widget.router.routerDelegate.removeListener(_onRoute);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _reading ? const SizedBox.shrink() : const UpdateRequiredScreen();
}

class UpdateRequiredScreen extends ConsumerWidget {
  const UpdateRequiredScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(updateProvider).info;
    return Material(
      key: const ValueKey('update-required'),
      color: AppColors.background,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: Icon(Ionicons.cloud_download_outline, size: 56, color: AppColors.primary500)),
              const SizedBox(height: 18),
              Text('Please update ReadIn', textAlign: TextAlign.center, style: AppTypography.title22),
              const SizedBox(height: 10),
              Text(
                'A new version (${info?.latestVersion ?? ''}) is needed to keep reading. '
                'It takes a minute, and your books, notes and progress stay safe.',
                textAlign: TextAlign.center,
                style: AppTypography.label(size: 14, color: AppColors.textSecondary, lineHeight: 21),
              ),
              if (info != null && info.releaseNotes.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  info.releaseNotes.take(4).map((n) => '• $n').join('\n'),
                  style: AppTypography.label(size: 13, color: AppColors.textSecondary, lineHeight: 20),
                ),
              ],
              const SizedBox(height: 24),
              PressableOpacity(
                pressedOpacity: 0.85,
                onTap: info == null ? null : () => openUpdateLink(info.downloadUrl),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: AppColors.primary500, borderRadius: BorderRadius.circular(14)),
                  child: Text(
                    info == null || info.sizeText.isEmpty ? 'Update now' : 'Update now (${info.sizeText})',
                    style: AppTypography.label(size: 16, weight: FontWeight.w700, color: AppColors.white),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _updateHint(ref.watch(distributionProvider)),
                textAlign: TextAlign.center,
                style: AppTypography.label(size: 12, color: AppColors.textMuted, lineHeight: 17),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => ref.read(updateProvider.notifier).check(force: true),
                child: const Text('I have updated — check again'),
              ),
              Text(
                'You have version $kAppVersion',
                textAlign: TextAlign.center,
                style: AppTypography.label(size: 11, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
