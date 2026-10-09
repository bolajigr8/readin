/// Every file format ReadIn knows, and HOW it is opened.
///
/// * [ViewerKind.epub] / [ViewerKind.pdf] — the full reader (progress, highlights…)
/// * [ViewerKind.document] — rendered on the phone in the document viewer
///   (Word, Excel, PowerPoint, text, Markdown, HTML, CSV, FB2, ODT)
/// * [ViewerKind.comic] — image archives (CBZ)
/// * [ViewerKind.external] — handed to another app ("Open with…")
enum ViewerKind { epub, pdf, document, comic, external }

class FormatInfo {
  const FormatInfo(this.ext, this.label, this.kind, this.mime);

  final String ext;
  final String label;
  final ViewerKind kind;
  final String mime;
}

const List<FormatInfo> kFormats = [
  FormatInfo('epub', 'EPUB', ViewerKind.epub, 'application/epub+zip'),
  FormatInfo('pdf', 'PDF', ViewerKind.pdf, 'application/pdf'),
  FormatInfo('docx', 'Word', ViewerKind.document,
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document'),
  FormatInfo('xlsx', 'Excel', ViewerKind.document,
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'),
  FormatInfo('pptx', 'PowerPoint', ViewerKind.document,
      'application/vnd.openxmlformats-officedocument.presentationml.presentation'),
  FormatInfo('odt', 'OpenDocument', ViewerKind.document,
      'application/vnd.oasis.opendocument.text'),
  FormatInfo('txt', 'Text', ViewerKind.document, 'text/plain'),
  FormatInfo('md', 'Markdown', ViewerKind.document, 'text/markdown'),
  FormatInfo('html', 'HTML', ViewerKind.document, 'text/html'),
  FormatInfo('htm', 'HTML', ViewerKind.document, 'text/html'),
  FormatInfo('csv', 'CSV', ViewerKind.document, 'text/csv'),
  FormatInfo('fb2', 'FictionBook', ViewerKind.document, 'application/x-fictionbook+xml'),
  FormatInfo('cbz', 'Comic (CBZ)', ViewerKind.comic, 'application/vnd.comicbook+zip'),
  FormatInfo('cbr', 'Comic (CBR)', ViewerKind.external, 'application/vnd.comicbook-rar'),
  FormatInfo('mobi', 'Kindle (MOBI)', ViewerKind.external, 'application/x-mobipocket-ebook'),
  FormatInfo('azw3', 'Kindle (AZW3)', ViewerKind.external, 'application/vnd.amazon.ebook'),
  FormatInfo('doc', 'Word (old)', ViewerKind.external, 'application/msword'),
  FormatInfo('rtf', 'Rich text', ViewerKind.external, 'application/rtf'),
  FormatInfo('xls', 'Excel (old)', ViewerKind.external, 'application/vnd.ms-excel'),
  FormatInfo('ppt', 'PowerPoint (old)', ViewerKind.external, 'application/vnd.ms-powerpoint'),
];

final Map<String, FormatInfo> _byExt = {for (final f in kFormats) f.ext: f};

/// Lower-case extension without the dot ('' if none).
String extensionOfName(String fileName) {
  final base = fileName.split(RegExp(r'[\\/]')).last;
  final dot = base.lastIndexOf('.');
  if (dot < 0 || dot == base.length - 1) return '';
  return base.substring(dot + 1).toLowerCase();
}

FormatInfo? formatForExtension(String ext) => _byExt[ext.toLowerCase()];

bool isSupportedFileName(String fileName) =>
    _byExt.containsKey(extensionOfName(fileName));

/// A format name the app and the server understand (`other` for the unknown).
String normalizeFormat(String? format) {
  final f = (format ?? '').toLowerCase().trim();
  return _byExt.containsKey(f) ? f : 'other';
}

ViewerKind kindOfFormat(String? format) =>
    _byExt[(format ?? '').toLowerCase()]?.kind ?? ViewerKind.external;

String mimeOfFormat(String? format) =>
    _byExt[(format ?? '').toLowerCase()]?.mime ?? 'application/octet-stream';

String labelOfFormat(String? format) =>
    _byExt[(format ?? '').toLowerCase()]?.label ?? (format ?? 'File').toUpperCase();

/// Formats that are zip containers (cheap sanity check on import).
const Set<String> kZipFormats = {'epub', 'docx', 'xlsx', 'pptx', 'odt', 'cbz'};

/// File extension used on disk for [format] (`bin` for unknown formats).
String storageExtension(String? format) {
  final f = normalizeFormat(format);
  return f == 'other' ? 'bin' : f;
}
