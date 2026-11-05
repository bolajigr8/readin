import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:xml/xml.dart';

/// What an EPUB says about itself (read on the phone, no server).
class EpubMeta {
  const EpubMeta({
    this.title = '',
    this.author = '',
    this.description = '',
    this.language = '',
    this.cover,
  });

  final String title;
  final String author;
  final String description;
  final String language;

  /// Raw image bytes of the cover (jpg/png/…), if the book has one.
  final Uint8List? cover;
}

/// Reads title, author, description, language and cover image of an EPUB in a
/// background isolate. Returns null when the file is not a readable EPUB.
Future<EpubMeta?> readEpubMeta(String path) async {
  try {
    final m = await compute(_extract, path);
    if (m == null) return null;
    return EpubMeta(
      title: (m['title'] as String?) ?? '',
      author: (m['author'] as String?) ?? '',
      description: (m['description'] as String?) ?? '',
      language: (m['language'] as String?) ?? '',
      cover: m['cover'] as Uint8List?,
    );
  } catch (_) {
    return null;
  }
}

/// Pure helper (also used by tests): strips tags / entities from an OPF description.
String cleanDescription(String raw) {
  var s = raw.replaceAll(RegExp(r'<[^>]+>'), ' ');
  s = s
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'");
  return s.replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Resolves [href] (relative to the OPF folder [dir]) inside the zip.
String resolveEpubPath(String dir, String href) {
  final parts = <String>[];
  for (final p in '$dir${Uri.decodeComponent(href.split('#').first)}'.split('/')) {
    if (p == '..') {
      if (parts.isNotEmpty) parts.removeLast();
    } else if (p.isNotEmpty && p != '.') {
      parts.add(p);
    }
  }
  return parts.join('/');
}

Map<String, Object?>? _extract(String path) {
  final bytes = File(path).readAsBytesSync();
  final zip = ZipDecoder().decodeBytes(bytes);

  String? textOf(String name) {
    final f = zip.findFile(name);
    if (f == null) return null;
    return utf8.decode(f.content as List<int>, allowMalformed: true);
  }

  final containerXml = textOf('META-INF/container.xml');
  if (containerXml == null) return null;
  final root = XmlDocument.parse(containerXml)
      .descendants
      .whereType<XmlElement>()
      .where((e) => e.name.local == 'rootfile')
      .firstOrNull;
  final opfPath = root?.getAttribute('full-path');
  if (opfPath == null) return null;
  final opfText = textOf(opfPath);
  if (opfText == null) return null;

  final opf = XmlDocument.parse(opfText);
  final all = opf.descendants.whereType<XmlElement>().toList();
  String first(String local) =>
      all.where((e) => e.name.local == local).map((e) => e.innerText.trim()).firstWhere(
            (t) => t.isNotEmpty,
            orElse: () => '',
          );

  final dir = opfPath.contains('/') ? opfPath.substring(0, opfPath.lastIndexOf('/') + 1) : '';

  // Cover: <meta name="cover" content="id"> → manifest item; or properties="cover-image";
  // or any image item whose id/href mentions "cover".
  final manifest = all.where((e) => e.name.local == 'item').toList();
  XmlElement? coverItem;
  final coverId = all
      .where((e) => e.name.local == 'meta' && e.getAttribute('name') == 'cover')
      .map((e) => e.getAttribute('content'))
      .firstOrNull;
  if (coverId != null) {
    coverItem = manifest.where((e) => e.getAttribute('id') == coverId).firstOrNull;
  }
  coverItem ??= manifest
      .where((e) => (e.getAttribute('properties') ?? '').contains('cover-image'))
      .firstOrNull;
  coverItem ??= manifest.where((e) {
    final type = e.getAttribute('media-type') ?? '';
    final key = '${e.getAttribute('id')} ${e.getAttribute('href')}'.toLowerCase();
    return type.startsWith('image/') && key.contains('cover');
  }).firstOrNull;

  Uint8List? cover;
  final href = coverItem?.getAttribute('href');
  if (href != null) {
    final f = zip.findFile(resolveEpubPath(dir, href));
    if (f != null) {
      final data = f.content as List<int>;
      if (data.length > 1000) cover = Uint8List.fromList(data);
    }
  }

  return {
    'title': first('title'),
    'author': first('creator'),
    'description': cleanDescription(first('description')),
    'language': first('language'),
    'cover': cover,
  };
}
