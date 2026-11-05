import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/formats.dart';
import '../../core/services/native_bridge.dart';
import '../import/data/import_models.dart';

/// A document found on the phone (kept where it is — nothing is copied).
class DeviceFile {
  const DeviceFile({
    required this.path,
    required this.name,
    required this.size,
    required this.modified,
  });

  final String path;
  final String name;
  final int size;
  final DateTime modified;

  String get ext => extensionOfName(name);
  String get title => titleFromFileName(name);

  /// Folder the file lives in, e.g. "Download" or "WhatsApp/Media/Documents".
  String get folder {
    final parts = path.replaceAll('\\', '/').split('/');
    final i = parts.indexOf('0'); // /storage/emulated/0/<folder>/…
    final tail = parts.sublist(0, parts.length - 1);
    final from = i >= 0 ? i + 1 : (tail.length > 3 ? 4 : 0);
    return tail.skip(from.clamp(0, tail.length).toInt()).join('/');
  }

  Map<String, dynamic> toJson() =>
      {'path': path, 'name': name, 'size': size, 'modified': modified.millisecondsSinceEpoch};

  factory DeviceFile.fromJson(Map<String, dynamic> j) => DeviceFile(
        path: '${j['path']}',
        name: '${j['name']}',
        size: (j['size'] as num?)?.toInt() ?? 0,
        modified: DateTime.fromMillisecondsSinceEpoch((j['modified'] as num?)?.toInt() ?? 0),
      );
}

class DeviceScanState {
  const DeviceScanState({
    this.files = const [],
    this.scanning = false,
    this.hasAccess = false,
    this.lastScan,
    this.error,
  });

  final List<DeviceFile> files;
  final bool scanning;
  final bool hasAccess;
  final DateTime? lastScan;
  final String? error;

  DeviceScanState copyWith({
    List<DeviceFile>? files,
    bool? scanning,
    bool? hasAccess,
    DateTime? lastScan,
    String? error,
    bool clearError = false,
  }) =>
      DeviceScanState(
        files: files ?? this.files,
        scanning: scanning ?? this.scanning,
        hasAccess: hasAccess ?? this.hasAccess,
        lastScan: lastScan ?? this.lastScan,
        error: clearError ? null : (error ?? this.error),
      );
}

/// Scan results are cached on the phone, so "On this phone" opens instantly;
/// "Scan now" refreshes it.
class DeviceFilesNotifier extends StateNotifier<DeviceScanState> {
  DeviceFilesNotifier({Future<Directory> Function()? documentsDir})
      : _documentsDir = documentsDir ?? getApplicationDocumentsDirectory,
        super(const DeviceScanState()) {
    _init();
  }

  final Future<Directory> Function() _documentsDir;

  Future<File> _file() async =>
      File('${(await _documentsDir()).path}${Platform.pathSeparator}device_scan.json');

  Future<void> _init() async {
    final access = await NativeFiles.hasAllFilesAccess();
    var s = DeviceScanState(hasAccess: access);
    try {
      final f = await _file();
      if (await f.exists()) {
        final j = Map<String, dynamic>.from(jsonDecode(await f.readAsString()) as Map);
        s = s.copyWith(
          files: [
            for (final e in (j['files'] as List? ?? const []))
              DeviceFile.fromJson(Map<String, dynamic>.from(e as Map)),
          ],
          lastScan: DateTime.fromMillisecondsSinceEpoch((j['at'] as num?)?.toInt() ?? 0),
        );
      }
    } catch (_) {}
    if (mounted) state = s;
  }

  /// Re-checks the permission (call when the app returns from Settings).
  Future<void> refreshAccess() async {
    final a = await NativeFiles.hasAllFilesAccess();
    if (mounted) state = state.copyWith(hasAccess: a);
  }

  Future<void> requestAccess() => NativeFiles.requestAllFilesAccess();

  Future<void> scan() async {
    if (state.scanning) return;
    state = state.copyWith(scanning: true, clearError: true);
    try {
      final raw = await NativeFiles.scanDevice();
      final files = [for (final m in raw) DeviceFile.fromJson(m)]
        ..sort((a, b) => b.modified.compareTo(a.modified));
      final now = DateTime.now();
      try {
        final f = await _file();
        await f.writeAsString(
          jsonEncode({'at': now.millisecondsSinceEpoch, 'files': files.map((e) => e.toJson()).toList()}),
          flush: true,
        );
      } catch (_) {}
      if (mounted) state = state.copyWith(files: files, scanning: false, lastScan: now, hasAccess: true);
    } on PlatformException catch (e) {
      if (mounted) {
        state = state.copyWith(
          scanning: false,
          hasAccess: e.code == 'NO_ACCESS' ? false : state.hasAccess,
          error: e.code == 'NO_ACCESS'
              ? 'Allow "All files access" to scan your phone.'
              : 'Could not scan the phone.',
        );
      }
    } catch (_) {
      if (mounted) state = state.copyWith(scanning: false, error: 'Could not scan the phone.');
    }
  }
}

final deviceFilesProvider =
    StateNotifierProvider<DeviceFilesNotifier, DeviceScanState>((ref) => DeviceFilesNotifier());

/// Library switch: 0 = My Library, 1 = On this phone.
final libraryModeProvider = StateProvider<int>((ref) => 0);
