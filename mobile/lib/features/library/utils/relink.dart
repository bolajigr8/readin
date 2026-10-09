import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formats.dart';
import '../../../widgets/app_toast.dart';
import '../../../widgets/confirm_dialog.dart';
import '../data/local_import_service.dart' show fingerprintOf;
import '../data/models/book.dart';
import '../providers/download_providers.dart';

/// "The file of this book is not on this phone": lets the user pick it again
/// (same file → same fingerprint) and stores it under the book's id.
/// Returns true when the book can be opened now.
Future<bool> relinkBookFile(BuildContext context, WidgetRef ref, Book book) async {
  FilePickerResult? res;
  try {
    res = await FilePicker.platform.pickFiles(type: FileType.any, allowMultiple: false);
  } catch (_) {
    AppToast.error('Could not open the file picker.');
    return false;
  }
  final path = res?.files.single.path;
  if (path == null) return false;

  final ext = extensionOfName(res!.files.single.name);
  if (formatForExtension(ext) == null) {
    AppToast.error('This file type is not supported.');
    return false;
  }

  final file = File(path);
  if (book.fingerprint.isNotEmpty) {
    final fp = await fingerprintOf(file);
    if (fp != book.fingerprint) {
      if (!context.mounted) return false;
      final ok = await showConfirmDialog(
        context,
        title: 'Different file',
        message:
            'This does not look like the file you imported for "${book.title}". Link it anyway?',
        confirmLabel: 'Link anyway',
      );
      if (!ok) return false;
    }
  }

  try {
    await ref.read(downloadServiceProvider).importLocalCopy(
          bookId: book.id,
          source: file,
          format: ext,
        );
    ref.invalidate(bookDownloadProvider(book.id));
    return true;
  } catch (e) {
    AppToast.error('Could not save the file.');
    return false;
  }
}
