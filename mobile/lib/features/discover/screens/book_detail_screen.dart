import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:readin_flutter/constants/ionicons.dart';

import '../../../constants/app_colors.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/services/routes.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/app_toast.dart';
import '../../../widgets/confirm_dialog.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/loading_spinner.dart';
import '../../../widgets/pressable_opacity.dart';
import '../../audio/providers/audio_controller.dart';
import '../../library/data/models/book.dart';
import '../../library/providers/download_providers.dart';
import '../../library/providers/library_providers.dart';
import '../../library/screens/home_screen.dart' show openBook;
import '../../library/widgets/book_cover.dart';
import '../data/gutenberg_models.dart';
import '../providers/add_to_library_provider.dart';
import '../providers/discover_providers.dart';

/// TTS "Listen Preview" (Phase 10).
const bool kListenPreviewEnabled = true;

/// UI_SPEC §4.10 — Book detail for a Gutenberg book.
class BookDetailScreen extends ConsumerWidget {
  const BookDetailScreen({super.key, required this.gutenbergId});

  final String gutenbergId;

  void _back(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.discover);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = int.tryParse(gutenbergId) ?? 0;
    final async = ref.watch(gutenbergBookProvider(id));

    return async.when(
      loading: () => const Scaffold(
        body: LoadingSpinner(fullScreen: true, label: 'Loading book...'),
      ),
      error: (e, _) => _notFound(context),
      data: (book) => _Content(book: book, onBack: () => _back(context)),
    );
  }

  Widget _notFound(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: EmptyState(
              icon: Ionicons.alert_circle_outline,
              title: 'Book not found',
              description: 'This book could not be loaded from Project Gutenberg.',
              actionLabel: 'Go Back',
              onAction: () => _back(context),
            ),
          ),
        ),
      );
}

class _Content extends ConsumerWidget {
  const _Content({required this.book, required this.onBack});

  final GutenbergBook book;
  final VoidCallback onBack;

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    if (epubUrl(book.formats) == null) {
      await showConfirmDialog(
        context,
        title: 'Not Available',
        message: 'This book does not have an EPUB version available for download.',
        confirmLabel: 'OK',
        cancelLabel: 'Close',
      );
      return;
    }

    // Capture everything we need BEFORE any await: the user may leave this
    // screen while the book is being added / downloaded, and `ref` must not be
    // used after the widget is disposed.
    final container = ProviderScope.containerOf(context, listen: false);
    final autoDownload = autoDownloadEnabled(ref);
    final router = GoRouter.of(context);

    final res = await container.read(addToLibraryProvider.notifier).add(book);

    await res.when<Future<void>>(
      success: (added) async {
        AppToast.success('"${book.title}" added to your library!');
        // Honour the "auto-download" setting (default on).
        if (autoDownload) {
          final file =
              await container.read(bookDownloadProvider(added.id).notifier).start(added);
          if (file == null) {
            final msg = container.read(bookDownloadProvider(added.id)).error;
            if (msg != null) AppToast.warning('Saved to library. $msg');
          }
        }
      },
      failure: (e) async {
        if (e.statusCode == 409) {
          AppToast.info('This book is already in your library.');
        } else if (e.statusCode == 403) {
          if (!context.mounted) return;
          final upgrade = await showConfirmDialog(
            context,
            title: 'Library Limit Reached',
            message: e.message,
            confirmLabel: 'Upgrade',
            cancelLabel: 'Not now',
          );
          if (upgrade) router.go(AppRoutes.profile);
        } else if (e is NetworkException || e is RequestTimeoutException) {
          AppToast.error('Could not add book. Check your connection.');
        } else {
          AppToast.error(e.message.isEmpty
              ? 'Could not add book. Check your connection.'
              : e.message);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gid = book.id.toString();
    final libraryBook = ref.watch(libraryBookByGutenbergIdProvider(gid));
    final isInLibrary = libraryBook != null;
    final isAdding = ref.watch(addToLibraryProvider);
    final epubAvailable = epubUrl(book.formats) != null;
    final top = MediaQuery.paddingOf(context).top;

    final cover = coverUrl(book.formats, book.id);
    final authors = authorsLine(book);

    return Scaffold(
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Hero
                Container(
                  padding: const EdgeInsets.only(top: 80, bottom: 24),
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    border: Border(
                      bottom: BorderSide(color: AppColors.borderDefault),
                    ),
                  ),
                  child: Center(
                    child: Container(
                      width: 160,
                      height: 210,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.black.withValues(alpha: 0.4),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: BookCover(
                        title: book.title,
                        coverUrl: cover,
                        width: 160,
                        height: 210,
                        radius: 12,
                        initialsSize: 40,
                        showGlow: false,
                        showIcon: false,
                        initials: book.title.length >= 2
                            ? book.title.substring(0, 2).toUpperCase()
                            : book.title.toUpperCase(),
                      ),
                    ),
                  ),
                ),

                // Content
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    24,
                    24,
                    24,
                    24 + MediaQuery.paddingOf(context).bottom,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        book.title,
                        style: AppTypography.label(
                          size: 24,
                          weight: FontWeight.w700,
                          lineHeight: 32,
                        ),
                      ),
                      if (authors.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(
                          authors,
                          style: AppTypography.label(
                            size: 16,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: [
                          _Stat(
                            icon: Ionicons.cloud_download_outline,
                            text: '${downloadsK(book.downloadCount)} downloads',
                          ),
                          _Stat(
                            icon: Ionicons.language_outline,
                            text: book.languages.isNotEmpty
                                ? book.languages.first.toUpperCase()
                                : 'EN',
                          ),
                          const _Stat(
                            icon: Ionicons.shield_checkmark_outline,
                            text: 'Free Forever',
                            color: AppColors.success500,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Actions
                      _AddButton(
                        isInLibrary: isInLibrary,
                        isAdding: isAdding,
                        epubAvailable: epubAvailable,
                        onTap: () => _add(context, ref),
                      ),
                      if (libraryBook != null) ...[
                        const SizedBox(height: 10),
                        _ReadNowButton(
                          onTap: () => openBook(context, libraryBook),
                        ),
                        const SizedBox(height: 10),
                        _OfflineSection(bookId: libraryBook.id, book: libraryBook),
                      ],
                      if (kListenPreviewEnabled) ...[
                        const SizedBox(height: 10),
                        _ListenButton(
                          onTap: () {
                            ref.read(audioControllerProvider.notifier).load(
                                  bookId: book.id.toString(),
                                  title: book.title,
                                  coverUrl: cover,
                                  text: listenPreviewText(book),
                                );
                            context.push(AppRoutes.audioPlayer);
                          },
                        ),
                      ],

                      if (book.subjects.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _Section(
                          label: 'SUBJECTS',
                          children: [
                            for (final s in book.subjects.take(6))
                              _Tag(text: s.split('--').first.trim()),
                          ],
                        ),
                      ],
                      if (book.bookshelves.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _Section(
                          label: 'SHELVES',
                          children: [
                            for (final s in book.bookshelves.take(4))
                              _Tag(text: s, accent: true),
                          ],
                        ),
                      ],

                      // Attribution
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 2),
                              child: Icon(
                                Ionicons.information_circle_outline,
                                size: 14,
                                color: AppColors.textMuted,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'This book is from Project Gutenberg — public domain, free to read and share.',
                                style: AppTypography.label(
                                  size: 12,
                                  color: AppColors.textMuted,
                                  lineHeight: 18,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Floating back button
          Positioned(
            left: 16,
            top: top + 8,
            child: PressableOpacity(
              pressedOpacity: 0.7,
              onTap: onBack,
              child: Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.surface.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Ionicons.arrow_back,
                  size: 20,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.text, this.color});

  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textMuted;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: c),
        const SizedBox(width: 5),
        Text(text, style: AppTypography.label(size: 13, color: c)),
      ],
    );
  }
}

/// Primary "Add to Library" button with the RN state machine.
class _AddButton extends StatelessWidget {
  const _AddButton({
    required this.isInLibrary,
    required this.isAdding,
    required this.epubAvailable,
    required this.onTap,
  });

  final bool isInLibrary;
  final bool isAdding;
  final bool epubAvailable;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final disabled = !epubAvailable || isInLibrary;
    final label = isAdding
        ? 'Adding...'
        : isInLibrary
            ? 'In Library'
            : !epubAvailable
                ? 'No EPUB Available'
                : 'Add to Library';
    final textColor = isInLibrary ? AppColors.success500 : AppColors.white;

    return PressableOpacity(
      pressedOpacity: 0.85,
      onTap: (disabled || isAdding) ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: disabled ? AppColors.surface : AppColors.primary500,
          borderRadius: BorderRadius.circular(12),
          border: disabled ? Border.all(color: AppColors.borderDefault) : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isInLibrary
                  ? Ionicons.checkmark_circle
                  : Ionicons.add_circle_outline,
              size: 20,
              color: textColor,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: AppTypography.label(
                size: 16,
                weight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReadNowButton extends StatelessWidget {
  const _ReadNowButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableOpacity(
      pressedOpacity: 0.85,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.primary500,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Ionicons.book_outline, size: 20, color: AppColors.white),
            const SizedBox(width: 8),
            Text(
              'Read Now',
              style: AppTypography.label(
                size: 16,
                weight: FontWeight.w600,
                color: AppColors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Download for offline" with progress / "Available offline" / retry.
class _OfflineSection extends ConsumerWidget {
  const _OfflineSection({required this.bookId, required this.book});

  final String bookId;
  final Book book;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(bookDownloadProvider(bookId));

    if (st.isDownloaded) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Ionicons.checkmark_circle,
            size: 16,
            color: AppColors.success500,
          ),
          const SizedBox(width: 6),
          Text(
            'Available offline',
            style: AppTypography.label(
              size: 13,
              weight: FontWeight.w500,
              color: AppColors.success500,
            ),
          ),
        ],
      );
    }

    final downloading = st.isDownloading;
    final pct = st.progress;
    final label = downloading
        ? (pct == null ? 'Downloading...' : 'Downloading... ${(pct * 100).round()}%')
        : st.status == DownloadStatus.error
            ? 'Retry download'
            : 'Download for offline';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PressableOpacity(
          pressedOpacity: 0.8,
          onTap: downloading
              ? null
              : () async {
                  final file = await ref
                      .read(bookDownloadProvider(bookId).notifier)
                      .start(book);
                  if (file == null && context.mounted) {
                    final msg = ref.read(bookDownloadProvider(bookId)).error;
                    if (msg != null) AppToast.error(msg);
                  } else if (file != null) {
                    AppToast.success('Saved for offline reading.');
                  }
                },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.alpha(AppColors.primary500, 0x50),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (downloading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary500,
                    ),
                  )
                else
                  const Icon(
                    Ionicons.cloud_download_outline,
                    size: 18,
                    color: AppColors.primary500,
                  ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: AppTypography.label(
                    size: 15,
                    weight: FontWeight.w600,
                    color: AppColors.primary500,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (downloading) ...[
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: SizedBox(
              height: 4,
              child: LinearProgressIndicator(
                value: pct,
                backgroundColor: AppColors.borderLight,
                color: AppColors.primary500,
              ),
            ),
          ),
        ],
        if (st.status == DownloadStatus.error && st.error != null) ...[
          const SizedBox(height: 8),
          Text(
            st.error!,
            textAlign: TextAlign.center,
            style: AppTypography.label(
              size: 12,
              color: AppColors.error400,
              lineHeight: 16,
            ),
          ),
        ],
      ],
    );
  }
}

class _ListenButton extends StatelessWidget {
  const _ListenButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableOpacity(
      pressedOpacity: 0.8,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.alpha(AppColors.primary500, 0x50)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Ionicons.headset_outline,
              size: 18,
              color: AppColors.primary500,
            ),
            const SizedBox(width: 8),
            Text(
              'Listen Preview',
              style: AppTypography.label(
                size: 15,
                weight: FontWeight.w600,
                color: AppColors.primary500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.label, required this.children});

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.label(
            size: 10,
            weight: FontWeight.w600,
            letterSpacing: 1,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: children),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text, this.accent = false});

  final String text;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 200),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: accent
              ? AppColors.alpha(AppColors.primary500, 0x10)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: accent
                ? AppColors.alpha(AppColors.primary500, 0x40)
                : AppColors.borderDefault,
          ),
        ),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.label(
            size: 12,
            color: accent ? AppColors.primary500 : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
