import 'package:flutter/widgets.dart';
import 'package:readin_flutter/constants/ionicons.dart';

import '../../constants/app_colors.dart';

/// One onboarding slide (UI_SPEC §4.1).
class OnboardingSlide {
  const OnboardingSlide({
    required this.icon,
    required this.color,
    required this.badge,
    required this.headline,
    required this.description,
    required this.caption,
  });

  final IconData icon;
  final Color color;
  final String badge;
  final String headline;
  final String description;
  final String caption;
}

/// Copy is the RN copy, except slide 2 which uses the updated import copy.
const List<OnboardingSlide> kOnboardingSlides = [
  OnboardingSlide(
    icon: Ionicons.book,
    color: AppColors.primary500,
    badge: 'Welcome',
    headline: 'Read More,\nRead Better',
    description:
        'Your personal library that fits in your pocket. Upload documents, discover classics, and build a reading habit that lasts.',
    caption: 'The smarter way to read.',
  ),
  OnboardingSlide(
    icon: Ionicons.cloud_upload,
    color: AppColors.amber400,
    badge: 'Upload',
    headline: 'Any Format,\nPerfect Reading',
    description: 'Import PDFs and EPUBs from your phone and read them instantly.',
    caption: 'PDF and EPUB, right on your phone.',
  ),
  OnboardingSlide(
    icon: Ionicons.compass,
    color: AppColors.success500,
    badge: 'Discover',
    headline: '10,000+ Books,\nAll Free',
    description:
        'Explore the entire Project Gutenberg library. Every classic ever written — from Jane Austen to Dostoevsky — completely free.',
    caption: 'No subscription needed for classics.',
  ),
  OnboardingSlide(
    icon: Ionicons.create_outline,
    color: AppColors.blue500,
    badge: 'Annotate',
    headline: 'Never Lose\na Thought',
    description:
        'Highlight passages, write notes, and bookmark pages. Your annotations sync automatically and stay with you forever.',
    caption: 'Your reading, your way.',
  ),
  OnboardingSlide(
    icon: Ionicons.headset,
    color: AppColors.purple500,
    badge: 'Listen',
    headline: 'Read With\nYour Ears',
    description:
        'Turn any book into an audiobook with built-in text-to-speech. Perfect for commutes, workouts, and multitasking.',
    caption: 'Available on every book in your library.',
  ),
];
