/// All ReadIn API paths (see API_CONTRACT.md).
class ApiEndpoints {
  ApiEndpoints._();

  /// Override at build time:
  /// `flutter run --dart-define=API_BASE_URL=https://<host>/api/v1`
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://readin-ehzw.onrender.com/api/v1',
  );

  // Auth
  static const String register = '/auth/register';
  static const String login = '/auth/login';
  static const String google = '/auth/google';
  static const String refresh = '/auth/refresh';
  static const String logout = '/auth/logout';
  static const String forgotPassword = '/auth/forgot-password';
  static const String health = '/health';

  // Library
  static const String libraryList = '/library';
  static String libraryBook(String id) => '/library/$id';
  static const String libraryDiscover = '/library/discover';
  static const String libraryLocal = '/library/local';

  // Files
  static const String filesUpload = '/files/upload';

  // Progress
  static String progress(String bookId) => '/progress/$bookId';
  static const String progressStats = '/progress/stats/me';

  // Annotations / bookmarks
  static const String annotations = '/annotations';
  static String annotationsForBook(String bookId) => '/annotations/book/$bookId';
  static String annotation(String id) => '/annotations/$id';
  static const String bookmarks = '/bookmarks';
  static String bookmarksForBook(String bookId) => '/bookmarks/book/$bookId';
  static String bookmark(String id) => '/bookmarks/$id';
}
