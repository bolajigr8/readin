import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Keys stored in the platform keystore.
enum SecureStorageKey {
  accessToken('readin_access_token'),
  refreshToken('readin_refresh_token');

  const SecureStorageKey(this.key);
  final String key;
}

/// Keys stored in SharedPreferences.
enum StorageKey {
  onboardingComplete('@readin/onboarding_complete'),
  userJson('@readin/user'),
  readerFontSize('@readin/reader_font_size'),
  readerFontFamily('@readin/reader_font_family'),
  readerTheme('@readin/reader_theme'),
  notificationsEnabled('@readin/notifications_enabled'),
  autoDownloadEpub('@readin/auto_download_epub'),
  readerLineHeight('@readin/reader_line_height'),
  readerMargin('@readin/reader_margin'),
  readerAlign('@readin/reader_align'),
  readerFlow('@readin/reader_flow'),
  readerBrightness('@readin/reader_brightness'),
  volumeKeysNav('@readin/volume_keys_nav'),
  readerWarmth('@readin/reader_warmth'),
  readerAutoNight('@readin/reader_auto_night'),
  dailyGoalMinutes('@readin/daily_goal_minutes');

  const StorageKey(this.key);
  final String key;
}

/// Typed access to secure storage + shared prefs. No raw strings elsewhere.
class StorageService {
  StorageService({
    required SharedPreferences prefs,
    FlutterSecureStorage? secure,
  })  : _prefs = prefs,
        _secure = secure ?? const FlutterSecureStorage();

  final SharedPreferences _prefs;
  final FlutterSecureStorage _secure;

  // ── secure (overridable in tests) ──────────────────────────────────────────
  Future<String?> readSecure(SecureStorageKey k) => _secure.read(key: k.key);

  Future<void> writeSecure(SecureStorageKey k, String value) =>
      _secure.write(key: k.key, value: value);

  Future<void> deleteSecure(SecureStorageKey k) => _secure.delete(key: k.key);

  Future<String?> get accessToken => readSecure(SecureStorageKey.accessToken);
  Future<String?> get refreshToken => readSecure(SecureStorageKey.refreshToken);

  Future<void> setAccessToken(String v) =>
      writeSecure(SecureStorageKey.accessToken, v);
  Future<void> setRefreshToken(String v) =>
      writeSecure(SecureStorageKey.refreshToken, v);

  Future<void> clearSecure() async {
    await deleteSecure(SecureStorageKey.accessToken);
    await deleteSecure(SecureStorageKey.refreshToken);
  }

  // ── prefs ──────────────────────────────────────────────────────────────────
  bool get onboardingComplete =>
      _prefs.getBool(StorageKey.onboardingComplete.key) ?? false;
  Future<void> setOnboardingComplete(bool v) =>
      _prefs.setBool(StorageKey.onboardingComplete.key, v);

  String? get userJson => _prefs.getString(StorageKey.userJson.key);
  Future<void> setUserJson(String v) =>
      _prefs.setString(StorageKey.userJson.key, v);
  Future<void> clearUser() async {
    await _prefs.remove(StorageKey.userJson.key);
  }

  double get readerFontSize =>
      _prefs.getDouble(StorageKey.readerFontSize.key) ?? 17;
  Future<void> setReaderFontSize(double v) =>
      _prefs.setDouble(
        StorageKey.readerFontSize.key,
        v.clamp(12.0, 28.0).toDouble(),
      );

  String get readerFontFamily =>
      _prefs.getString(StorageKey.readerFontFamily.key) ?? 'sans-serif';
  Future<void> setReaderFontFamily(String v) =>
      _prefs.setString(StorageKey.readerFontFamily.key, v);

  String get readerTheme =>
      _prefs.getString(StorageKey.readerTheme.key) ?? 'dark';
  Future<void> setReaderTheme(String v) =>
      _prefs.setString(StorageKey.readerTheme.key, v);

  bool get notificationsEnabled =>
      _prefs.getBool(StorageKey.notificationsEnabled.key) ?? true;
  Future<void> setNotificationsEnabled(bool v) =>
      _prefs.setBool(StorageKey.notificationsEnabled.key, v);

  double get readerLineHeight =>
      _prefs.getDouble(StorageKey.readerLineHeight.key) ?? 1.6;
  Future<void> setReaderLineHeight(double v) =>
      _prefs.setDouble(StorageKey.readerLineHeight.key, v);

  /// Horizontal page margin in px.
  double get readerMargin => _prefs.getDouble(StorageKey.readerMargin.key) ?? 16;
  Future<void> setReaderMargin(double v) =>
      _prefs.setDouble(StorageKey.readerMargin.key, v);

  /// `'left'` | `'justify'`.
  String get readerAlign => _prefs.getString(StorageKey.readerAlign.key) ?? 'left';
  Future<void> setReaderAlign(String v) =>
      _prefs.setString(StorageKey.readerAlign.key, v);

  /// `'paged'` | `'scroll'`.
  String get readerFlow => _prefs.getString(StorageKey.readerFlow.key) ?? 'paged';
  Future<void> setReaderFlow(String v) =>
      _prefs.setString(StorageKey.readerFlow.key, v);

  /// Software dimmer: 1.0 = off, 0.3 = darkest.
  double get readerBrightness =>
      _prefs.getDouble(StorageKey.readerBrightness.key) ?? 1.0;
  Future<void> setReaderBrightness(double v) =>
      _prefs.setDouble(StorageKey.readerBrightness.key, v);

  /// Warm (blue-light) filter strength 0–0.5.
  double get readerWarmth => _prefs.getDouble(StorageKey.readerWarmth.key) ?? 0.0;
  Future<void> setReaderWarmth(double v) => _prefs.setDouble(StorageKey.readerWarmth.key, v);

  /// Switch to the Night theme automatically between 20:00 and 06:00.
  bool get readerAutoNight => _prefs.getBool(StorageKey.readerAutoNight.key) ?? false;
  Future<void> setReaderAutoNight(bool v) => _prefs.setBool(StorageKey.readerAutoNight.key, v);

  bool get volumeKeysNav => _prefs.getBool(StorageKey.volumeKeysNav.key) ?? true;
  Future<void> setVolumeKeysNav(bool v) =>
      _prefs.setBool(StorageKey.volumeKeysNav.key, v);

  int get dailyGoalMinutes => _prefs.getInt(StorageKey.dailyGoalMinutes.key) ?? 20;
  Future<void> setDailyGoalMinutes(int v) =>
      _prefs.setInt(StorageKey.dailyGoalMinutes.key, v);

  /// Seconds read on [day] (`yyyy-MM-dd`), kept locally for the daily goal.
  int readSecondsOn(String day) => _prefs.getInt('@readin/read_seconds_$day') ?? 0;
  Future<void> setReadSecondsOn(String day, int v) =>
      _prefs.setInt('@readin/read_seconds_$day', v);

  // ── small generic helpers (shelves JSON, badge counters) ────────────────────
  String? readString(String key) => _prefs.getString(key);
  Future<void> writeString(String key, String v) => _prefs.setString(key, v);
  int readInt(String key) => _prefs.getInt(key) ?? 0;
  Future<void> writeInt(String key, int v) => _prefs.setInt(key, v);

  bool get autoDownloadEpub =>
      _prefs.getBool(StorageKey.autoDownloadEpub.key) ?? true;
  Future<void> setAutoDownloadEpub(bool v) =>
      _prefs.setBool(StorageKey.autoDownloadEpub.key, v);
}
