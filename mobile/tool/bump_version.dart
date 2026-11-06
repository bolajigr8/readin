// Raises the app version in pubspec.yaml (`version: x.y.z+N`).
//
//   dart run tool/bump_version.dart patch    1.0.0+1 -> 1.0.1+2   (bug fixes)
//   dart run tool/bump_version.dart minor    1.0.1+2 -> 1.1.0+3   (new features)
//   dart run tool/bump_version.dart major    1.1.0+3 -> 2.0.0+4   (big change)
//   dart run tool/bump_version.dart build    1.1.0+3 -> 1.1.0+4   (same version, new build)
//   dart run tool/bump_version.dart show     prints the current version
//   add --dry-run to see the result without saving
//
// N (the build number) is Android's versionCode. It goes up by exactly 1 every
// time and NEVER goes down: Android refuses to install an update whose
// versionCode is not higher than the installed one.
import 'dart:io';

final _versionLine = RegExp(
  // [ \t] (not \s) so the line ending is never part of the match.
  r'^version:[ \t]*(\d+)\.(\d+)\.(\d+)\+(\d+)[ \t]*(?=\r?$)',
  multiLine: true,
);

void main(List<String> args) {
  final dryRun = args.contains('--dry-run');
  final kinds = args.where((a) => !a.startsWith('--')).toList();
  const allowed = ['patch', 'minor', 'major', 'build', 'show'];
  if (kinds.length != 1 || !allowed.contains(kinds.single)) {
    stderr.writeln('Usage: dart run tool/bump_version.dart '
        '<patch|minor|major|build|show> [--dry-run]');
    exit(64);
  }
  final kind = kinds.single;

  final file = File('pubspec.yaml');
  if (!file.existsSync()) {
    stderr.writeln('Run this from project/mobile (pubspec.yaml not found).');
    exit(66);
  }
  final text = file.readAsStringSync();
  final matches = _versionLine.allMatches(text).toList();
  if (matches.length != 1) {
    stderr.writeln('pubspec.yaml needs exactly one line like "version: 1.0.0+1" '
        '(found ${matches.length}).');
    exit(65);
  }
  final m = matches.single;
  var major = int.parse(m.group(1)!);
  var minor = int.parse(m.group(2)!);
  var patch = int.parse(m.group(3)!);
  var build = int.parse(m.group(4)!);
  final before = '$major.$minor.$patch+$build';

  if (kind == 'show') {
    stdout.writeln('version $before (versionName $major.$minor.$patch, '
        'versionCode $build)');
    return;
  }

  switch (kind) {
    case 'major':
      major++;
      minor = 0;
      patch = 0;
    case 'minor':
      minor++;
      patch = 0;
    case 'patch':
      patch++;
  }
  build++;
  final after = '$major.$minor.$patch+$build';

  if (!dryRun) {
    // Keep the rest of the file (and its line endings) exactly as it was.
    final updated = text.replaceRange(m.start, m.end, 'version: $after');
    file.writeAsStringSync(updated);
  }
  stdout.writeln('${dryRun ? '(dry run) ' : ''}version $before -> $after '
      '(versionCode $build)');
}
