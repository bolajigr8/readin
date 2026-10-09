import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart';
import '../../library/providers/download_providers.dart';
import '../data/book_picker.dart';
import '../data/import_service.dart';

final bookPickerProvider = Provider<BookPicker>((ref) => const FilePickerBookPicker());

final importServiceProvider = Provider<ImportService>(
  (ref) => ImportService(
    api: ref.watch(apiClientProvider),
    downloads: ref.watch(downloadServiceProvider),
  ),
);
