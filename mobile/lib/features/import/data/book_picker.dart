import 'dart:io';

import 'package:file_picker/file_picker.dart';

import 'import_models.dart';

/// Abstraction over the system picker (replaceable in tests).
abstract class BookPicker {
  /// `null` = the user closed the picker (silent). Throws [ImportException]
  /// when the choice is not importable.
  Future<PickedBook?> pick();
}

/// `file_picker` with `FileType.any` + **extension** validation — Android
/// labels many `.epub` files as `application/octet-stream`, so a MIME-filtered
/// picker would grey them out (the original RN "import is broken" bug).
class FilePickerBookPicker implements BookPicker {
  const FilePickerBookPicker();

  @override
  Future<PickedBook?> pick() async {
    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        withData: false,
      );
    } catch (_) {
      throw const ImportException('Could not open the file picker.');
    }

    if (result == null || result.files.isEmpty) return null;
    final f = result.files.single;
    final path = f.path;
    if (path == null) {
      throw const ImportException(
        'Could not read the selected file. Try copying it to your Downloads folder.',
      );
    }

    var size = f.size;
    if (size <= 0) {
      try {
        size = await File(path).length();
      } on FileSystemException {
        size = 0;
      }
    }
    return validatePicked(name: f.name, path: path, size: size);
  }
}
