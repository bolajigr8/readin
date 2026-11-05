import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:readin_flutter/features/device/device_files.dart';
import 'package:readin_flutter/features/library/data/book_meta_store.dart';
import 'package:readin_flutter/features/library/data/epub_meta.dart';
import 'package:readin_flutter/features/library/data/models/book.dart';
import 'package:readin_flutter/features/reader/data/reader_models.dart';
import 'package:readin_flutter/features/shelves/shelf_models.dart';
import 'package:readin_flutter/features/shelves/shelf_providers.dart';

Book _b(String id) => Book.fromJson({
      '_id': id,
      'title': 'T$id',
      'originalFormat': 'epub',
      'status': 'ready',
      'createdAt': '2026-01-01T00:00:00Z',
      'updatedAt': '2026-01-01T00:00:00Z',
    });

void main() {
  group('reader look (copied from the reference reader)', () {
    test('new defaults', () {
      const p = ReaderPrefs(fontSize: 15, fontFamily: 'merriweather', theme: 'sepia');
      expect(p.align, 'justify');
      expect(p.hyphenate, isTrue);
      expect(p.fontWeight, 700); // bold by default
      expect(p.margin, 32);
      expect(p.lineHeight, 1.5);
      expect(p.copyWith(hyphenate: false) == p, isFalse);
      expect(p.copyWith(fontWeight: 400) == p, isFalse);
      expect(p.pageAnim, 'slide');
      expect(p.copyWith(pageAnim: 'none') == p, isFalse);
    });
  });

  group('reader fonts and spacing', () {
    test('every bundled font is a valid choice (the old code turned all but "serif" into sans)', () {
      for (final f in ['merriweather', 'literata', 'lora', 'lexend', 'atkinson', 'opendyslexic', 'serif', 'sans-serif']) {
        expect(isReaderFont(f), isTrue, reason: f);
      }
      expect(isReaderFont('comic-sans'), isFalse);
      expect(kReaderFonts.first.id, 'merriweather');
      expect(readerFontLabel('atkinson'), 'Atkinson Hyperlegible');
    });

    test('thickness steps and line spacing percentage', () {
      expect(kFontWeights, [300, 400, 700, 900]);
      expect(fontWeightLabel(300), 'Light');
      expect(fontWeightLabel(900), 'Extra bold');
      expect(fontWeightLabel(700), 'Bold');
      expect(lineSpacingPercent(1.5), 100);
      expect(lineSpacingPercent(1.8), 120);
      expect(lineSpacingPercent(1.2), 80);
    });
  });

  group('EPUB metadata', () {
    test('cleanDescription strips tags and entities', () {
      expect(cleanDescription('<p>Hello &amp; <b>welcome</b></p>\n  again'), 'Hello & welcome again');
      expect(cleanDescription(''), '');
    });

    test('resolveEpubPath handles folders and ../', () {
      expect(resolveEpubPath('OEBPS/', 'Images/cover.jpg'), 'OEBPS/Images/cover.jpg');
      expect(resolveEpubPath('OEBPS/text/', '../Images/c%20x.jpg'), 'OEBPS/Images/c x.jpg');
      expect(resolveEpubPath('', 'cover.png#x'), 'cover.png');
    });

    test('reads title, author, description, language and cover from a real zip', () async {
      final tmp = Directory.systemTemp.createTempSync('readin_epub_');
      addTearDown(() => tmp.deleteSync(recursive: true));
      final cover = List<int>.generate(2000, (i) => i % 251);
      final a = Archive()
        ..addFile(ArchiveFile.bytes('mimetype', 'application/epub+zip'.codeUnits))
        ..addFile(ArchiveFile.bytes(
          'META-INF/container.xml',
          '<?xml version="1.0"?><container xmlns="urn:oasis:names:tc:opendocument:xmlns:container"><rootfiles><rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/></rootfiles></container>'
              .codeUnits,
        ))
        ..addFile(ArchiveFile.bytes(
          'OEBPS/content.opf',
          '''<?xml version="1.0"?><package xmlns="http://www.idpf.org/2007/opf" version="2.0"><metadata xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:opf="http://www.idpf.org/2007/opf"><dc:title>Outwitting the Devil</dc:title><dc:creator>Napoleon Hill</dc:creator><dc:description>&lt;p&gt;A conversation with &amp;amp; the Devil.&lt;/p&gt;</dc:description><dc:language>en</dc:language><meta name="cover" content="cov"/></metadata><manifest><item id="cov" href="Images/cover.jpg" media-type="image/jpeg"/></manifest></package>'''
              .codeUnits,
        ))
        ..addFile(ArchiveFile.bytes('OEBPS/Images/cover.jpg', cover));
      final bytes = ZipEncoder().encode(a);
      final f = File('${tmp.path}/book.epub')..writeAsBytesSync(List<int>.from(bytes as Iterable));

      final m = await readEpubMeta(f.path);
      expect(m, isNotNull);
      expect(m!.title, 'Outwitting the Devil');
      expect(m.author, 'Napoleon Hill');
      expect(m.language, 'en');
      expect(m.description, contains('conversation'));
      expect(m.description, isNot(contains('<')));
      expect(m.cover, isNotNull);
      expect(m.cover!.length, 2000);

      expect(await readEpubMeta('${tmp.path}/missing.epub'), isNull);
      File('${tmp.path}/junk.epub').writeAsStringSync('not a zip');
      expect(await readEpubMeta('${tmp.path}/junk.epub'), isNull);
    });
  });

  group('BookMetaStore', () {
    test('meta + cover round trip, rename and delete', () async {
      final tmp = Directory.systemTemp.createTempSync('readin_meta_');
      addTearDown(() => tmp.deleteSync(recursive: true));
      final s = BookMetaStore(documentsDir: () async => tmp);
      expect(await s.read('x'), isNull);
      expect(await s.coverFile('x'), isNull);

      await s.write('local_a', const BookMeta(description: 'About it', language: 'en'));
      await s.saveCover('local_a', Uint8List.fromList([1, 2, 3, 4]));
      expect((await s.read('local_a'))!.description, 'About it');
      expect(await s.coverFile('local_a'), isNotNull);

      await s.rename('local_a', 'srv1');
      expect(await s.read('local_a'), isNull);
      expect((await s.read('srv1'))!.language, 'en');
      expect(await s.coverFile('srv1'), isNotNull);
      expect(await s.coverFile('local_a'), isNull);

      // survives a restart (new store instance reads the file)
      final s2 = BookMetaStore(documentsDir: () async => tmp);
      expect((await s2.read('srv1'))!.description, 'About it');

      await s.delete('srv1');
      expect(await s.read('srv1'), isNull);
      expect(await s.coverFile('srv1'), isNull);
    });
  });

  group('favourites', () {
    test('encode/decode and filter', () {
      const d = ShelfData(favorites: {'1', '3'});
      final back = ShelfData.decode(d.encode());
      expect(back.favorites, {'1', '3'});
      final books = [_b('1'), _b('2'), _b('3')];
      final fav = applyShelfFilter(books, back, const ShelfFilter.favorites());
      expect(fav.map((b) => b.id), ['1', '3']);
      expect(applyShelfFilter(books, back, const ShelfFilter.all()).length, 3);
    });
  });

  group('device files', () {
    test('title, extension and folder', () {
      final f = DeviceFile(
        path: '/storage/emulated/0/Download/My_Report-final.docx',
        name: 'My_Report-final.docx',
        size: 1234,
        modified: DateTime(2026, 1, 1),
      );
      expect(f.ext, 'docx');
      expect(f.title, 'My Report-final');
      expect(f.folder, 'Download');
      final w = DeviceFile(
        path: '/storage/emulated/0/WhatsApp/Media/WhatsApp Documents/a.pdf',
        name: 'a.pdf',
        size: 10,
        modified: DateTime(2026, 1, 1),
      );
      expect(w.folder, 'WhatsApp/Media/WhatsApp Documents');
    });

    test('json round trip', () {
      final f = DeviceFile(path: '/a/b.pdf', name: 'b.pdf', size: 5, modified: DateTime.fromMillisecondsSinceEpoch(1000));
      final back = DeviceFile.fromJson(f.toJson());
      expect(back.path, '/a/b.pdf');
      expect(back.size, 5);
      expect(back.modified.millisecondsSinceEpoch, 1000);
    });
  });
}
