import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:readin_flutter/constants/ionicons.dart';

import '../../constants/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/pressable_opacity.dart';
import '../auth/providers/auth_providers.dart';
import 'onboarding_slide_view.dart';
import 'onboarding_slides.dart';

/// UI_SPEC §4.1 — 5-slide onboarding. Completion stores
/// `@readin/onboarding_complete = true`; the router then sends the user to
/// sign-in.
class WalkthroughScreen extends ConsumerStatefulWidget {
  const WalkthroughScreen({super.key});

  @override
  ConsumerState<WalkthroughScreen> createState() => _WalkthroughScreenState();
}

class _WalkthroughScreenState extends ConsumerState<WalkthroughScreen> {
  final PageController _pages = PageController();
  int _index = 0;

  OnboardingSlide get _slide => kOnboardingSlides[_index];
  bool get _isLast => _index == kOnboardingSlides.length - 1;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _complete() async {
    await ref.read(storageServiceProvider).setOnboardingComplete(true);
    if (!mounted) return;
    // Router listens to this provider and redirects to sign-in.
    ref.read(onboardingCompleteProvider.notifier).state = true;
  }

  void _next() {
    if (_isLast) {
      _complete();
      return;
    }
    _pages.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.of(context).padding;
    final bottomPad = insets.bottom > 24 ? insets.bottom : 24.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: PageView.builder(
                  controller: _pages,
                  // PageScrollPhysics = snapping; Clamping parent = no overscroll bounce
                  // (RN `bounces={false}`).
                  physics: const PageScrollPhysics(parent: ClampingScrollPhysics()),
                  itemCount: kOnboardingSlides.length,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (_, i) =>
                      OnboardingSlideView(slide: kOnboardingSlides[i]),
                ),
              ),
              Container(
                color: AppColors.background,
                padding: EdgeInsets.fromLTRB(24, 12, 24, bottomPad),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Dots(
                      count: kOnboardingSlides.length,
                      active: _index,
                      color: _slide.color,
                    ),
                    const SizedBox(height: 16),
                    PressableOpacity(
                      pressedOpacity: 0.85,
                      onTap: _next,
                      child: Container(
                        height: 56,
                        decoration: BoxDecoration(
                          color: _slide.color,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _isLast ? 'Get Started' : 'Continue',
                              style: AppTypography.label(
                                size: 16,
                                weight: FontWeight.w600,
                                color: AppColors.white,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Ionicons.arrow_forward,
                              size: 18,
                              color: AppColors.white,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '${_index + 1} of ${kOnboardingSlides.length}',
                        textAlign: TextAlign.center,
                        style: AppTypography.label(
                          size: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Positioned(
            top: 0,
            // RN: right 20, paddingTop inset+8, hitSlop 12 (hit area only).
            right: 8,
            child: Padding(
              padding: EdgeInsets.only(top: insets.top > 4 ? insets.top - 4 : 0),
              child: PressableOpacity(
                pressedOpacity: 0.7,
                onTap: _complete,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'Skip',
                    style: AppTypography.label(
                      size: 15,
                      weight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.active, required this.color});

  final int count;
  final int active;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Container(
            width: i == active ? 24 : 6,
            height: 4,
            decoration: BoxDecoration(
              color: i == active ? color : AppColors.borderLight,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ],
    );
  }
}
