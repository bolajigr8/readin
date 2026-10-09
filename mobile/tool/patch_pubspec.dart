// Adds the lines this update needs to YOUR pubspec.yaml (idempotent), without
// touching anything else (e.g. your generated Ionicons font entry).
//
//   dart run tool/patch_pubspec.dart
import 'dart:io';

void main() {
  final file = File('pubspec.yaml');
  if (!file.existsSync()) {
    stderr.writeln('Run this from the project root (pubspec.yaml not found).');
    exit(64);
  }
  var text = file.readAsStringSync().replaceAll('\r\n', '\n');
  final changes = <String>[];

  bool has(String s) => text.contains(s);

  void insertAfterLine(String anchorPrefix, String add, String label) {
    if (has(add.trim())) return;
    final lines = text.split('\n');
    final i = lines.indexWhere((l) => l.startsWith(anchorPrefix));
    if (i < 0) {
      stderr.writeln('Could not find "$anchorPrefix" — add this line yourself: ${add.trim()}');
      return;
    }
    lines.insert(i + 1, add);
    text = lines.join('\n');
    changes.add(label);
  }

  insertAfterLine('  flutter_tts:', '  just_audio: ^0.9.40', 'just_audio (focus sounds)');
  insertAfterLine('  uuid:', '  crypto: ^3.0.3', 'crypto (file fingerprints)');
  insertAfterLine('    - assets/reader/', '    - assets/audio/', 'assets/audio/');
  insertAfterLine('    - assets/icons/', '    - assets/audio/', 'assets/audio/');

  if (changes.isEmpty) {
    stdout.writeln('pubspec.yaml already up to date.');
  } else {
    file.writeAsStringSync(text);
    stdout.writeln('Updated pubspec.yaml: ${changes.toSet().join(', ')}');
  }
  stdout.writeln('Next: flutter pub get');
}
