/// Central route table (UI_SPEC §3).
class AppRoutes {
  AppRoutes._();

  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String signIn = '/sign-in';
  static const String signUp = '/sign-up';
  static const String forgot = '/forgot-password';

  // Tabs
  static const String home = '/home/dashboard';
  static const String libraryTab = '/home/library';
  static const String discover = '/home/discover';
  static const String profile = '/home/profile';

  // Detail / modal
  static const String bookDetail = '/book/:gutenbergId';
  static const String reader = '/reader/:bookId';
  static const String document = '/document/:bookId';
  static const String notes = '/notes';
  static const String badges = '/badges';
  static const String importBook = '/import';
  static const String upgrade = '/upgrade';
  static const String audioPlayer = '/audio-player';

  // Dev
  static const String gallery = '/dev/gallery';

  static String bookDetailPath(String gutenbergId) => '/book/$gutenbergId';
  static String readerPath(String bookId) => '/reader/$bookId';
  static String documentPath(String bookId) => '/document/$bookId';

  /// Routes reachable without a session.
  static const Set<String> publicRoutes = {onboarding, signIn, signUp, forgot};
}
