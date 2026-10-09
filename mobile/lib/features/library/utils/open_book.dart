import 'package:go_router/go_router.dart';

import '../../../core/formats.dart';
import '../../../core/services/routes.dart';
import '../data/models/book.dart';

/// Opens [book] with the right screen: the reader for EPUB/PDF, the document
/// viewer (or "open with another app") for everything else.
void openBookWith(GoRouter router, Book book) {
  final kind = book.kind;
  if (kind == ViewerKind.epub || kind == ViewerKind.pdf) {
    router.push(AppRoutes.readerPath(book.id), extra: book);
  } else {
    router.push(AppRoutes.documentPath(book.id), extra: book);
  }
}
