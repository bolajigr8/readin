import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/providers/auth_providers.dart';
import '../../features/auth/providers/auth_state.dart';
import '../../features/auth/screens/forgot_password_screen.dart';
import '../../features/auth/screens/signin_screen.dart';
import '../../features/auth/screens/signup_screen.dart';
import '../../features/audio/screens/audio_player_screen.dart';
import '../../features/dev/design_gallery_screen.dart';
import '../../features/premium/screens/upgrade_screen.dart';
import '../../features/discover/screens/book_detail_screen.dart';
import '../../features/documents/document_screen.dart';
import '../../features/notes/notes_screen.dart';
import '../../features/shelves/badges_screen.dart';
import '../../features/discover/screens/discover_screen.dart';
import '../../features/import/data/import_models.dart';
import '../../features/import/screens/import_screen.dart';
import '../../features/library/data/models/book.dart';
import '../../features/reader/providers/reader_controller.dart';
import '../../features/reader/screens/reader_screen.dart';
import '../../features/library/screens/home_screen.dart';
import '../../features/library/screens/library_screen.dart';
import '../../features/onboarding/walkthrough_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/shell/home_shell.dart';
import '../widgets/app_loader.dart';
import 'navigator_keys.dart';
import 'routes.dart';

/// Bridges Riverpod state to GoRouter's `refreshListenable`.
class RouterNotifier extends ChangeNotifier {
  RouterNotifier(this._ref) {
    _ref.listen<AuthState>(authProvider, (prev, next) {
      if (prev?.isHydrated != next.isHydrated ||
          prev?.isAuthenticated != next.isAuthenticated) {
        notifyListeners();
      }
    });
    _ref.listen<bool>(onboardingCompleteProvider, (_, _) => notifyListeners());
  }

  final Ref _ref;

  /// Auth gate:
  /// * not hydrated → splash
  /// * authenticated → leave splash / public routes for home
  /// * not onboarded → onboarding
  /// * signed out → sign-in (public auth routes stay reachable)
  String? redirect(BuildContext context, GoRouterState state) {
    final auth = _ref.read(authProvider);
    final loc = state.matchedLocation;

    if (!auth.isHydrated) return loc == AppRoutes.splash ? null : AppRoutes.splash;

    if (auth.isAuthenticated) {
      final leave = loc == AppRoutes.splash || AppRoutes.publicRoutes.contains(loc);
      return leave ? AppRoutes.home : null;
    }

    final onboarded = _ref.read(onboardingCompleteProvider);
    if (!onboarded) return loc == AppRoutes.onboarding ? null : AppRoutes.onboarding;

    // Signed out and onboarded.
    if (loc == AppRoutes.signIn ||
        loc == AppRoutes.signUp ||
        loc == AppRoutes.forgot) {
      return null;
    }
    return AppRoutes.signIn;
  }
}

CustomTransitionPage<void> _page(
  GoRouterState state,
  Widget child, {
  required RouteTransitionsBuilder builder,
  Duration duration = const Duration(milliseconds: 280),
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: duration,
    reverseTransitionDuration: duration,
    transitionsBuilder: builder,
  );
}

CustomTransitionPage<void> slideUpPage(GoRouterState s, Widget child) => _page(
      s,
      child,
      builder: (context, anim, _, c) => SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
            .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
        child: c,
      ),
    );

CustomTransitionPage<void> slideRightPage(GoRouterState s, Widget child) => _page(
      s,
      child,
      builder: (context, anim, _, c) => SlideTransition(
        position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
            .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
        child: c,
      ),
    );

CustomTransitionPage<void> fadePage(GoRouterState s, Widget child) => _page(
      s,
      child,
      duration: const Duration(milliseconds: 200),
      builder: (context, anim, _, c) => FadeTransition(opacity: anim, child: c),
    );

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = RouterNotifier(ref);
  ref.onDispose(notifier.dispose);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppRoutes.splash,
    refreshListenable: notifier,
    redirect: notifier.redirect,
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        pageBuilder: (c, s) =>
            fadePage(s, const AppLoader(fullScreen: true)),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        pageBuilder: (c, s) => fadePage(s, const WalkthroughScreen()),
      ),
      GoRoute(
        path: AppRoutes.signIn,
        pageBuilder: (c, s) => fadePage(s, const SignInScreen()),
      ),
      GoRoute(
        path: AppRoutes.signUp,
        pageBuilder: (c, s) => slideRightPage(s, const SignUpScreen()),
      ),
      GoRoute(
        path: AppRoutes.forgot,
        pageBuilder: (c, s) => slideRightPage(s, const ForgotPasswordScreen()),
      ),

      // Tabs: 4 preserved branches inside the shell (tab bar + drawer).
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            HomeShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (c, s) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.libraryTab,
                builder: (c, s) => const LibraryScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.discover,
                builder: (c, s) => const DiscoverScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.profile,
                builder: (c, s) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),

      // Detail + modals
      GoRoute(
        path: AppRoutes.bookDetail,
        pageBuilder: (c, s) => slideRightPage(
          s,
          BookDetailScreen(gutenbergId: s.pathParameters['gutenbergId'] ?? '0'),
        ),
      ),
      GoRoute(
        path: AppRoutes.reader,
        pageBuilder: (c, s) {
          // `extra`: the Book (opened from Library/Home/Discover) or a
          // LocalReadRequest ("read without saving"); null on a deep link,
          // in which case the reader loads GET /library/:id itself.
          final extra = s.extra;
          final id = s.pathParameters['bookId'] ?? '';
          return fadePage(
            s,
            ReaderScreen(
              args: ReaderArgs(
                bookId: id,
                book: extra is Book ? extra : null,
                local: extra is LocalReadRequest ? extra : null,
              ),
            ),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.document,
        pageBuilder: (c, s) {
          final extra = s.extra;
          return fadePage(
            s,
            DocumentScreen(
              bookId: s.pathParameters['bookId'] ?? '',
              book: extra is Book ? extra : null,
              local: extra is LocalReadRequest ? extra : null,
            ),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.notes,
        pageBuilder: (c, s) => slideUpPage(s, const NotesScreen()),
      ),
      GoRoute(
        path: AppRoutes.badges,
        pageBuilder: (c, s) => slideUpPage(s, const BadgesScreen()),
      ),
      GoRoute(
        path: AppRoutes.importBook,
        pageBuilder: (c, s) => slideUpPage(s, const ImportScreen()),
      ),
      GoRoute(
        path: AppRoutes.upgrade,
        pageBuilder: (c, s) =>
            slideUpPage(s, const UpgradeScreen()),
      ),
      GoRoute(
        path: AppRoutes.audioPlayer,
        pageBuilder: (c, s) => slideUpPage(s, const AudioPlayerScreen()),
      ),

      if (kDebugMode)
        GoRoute(
          path: AppRoutes.gallery,
          pageBuilder: (c, s) => fadePage(s, const DesignGalleryScreen()),
        ),
    ],
  );
});
