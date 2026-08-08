import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bacain/core/epub/epub_reader.dart';

/// Rakit EPUB sungguhan di memori, bukan tiruan. Kalau strukturnya salah,
/// yang diuji jadi tidak berarti — jadi berkasnya dibuat selengkap EPUB asli.
List<int> buildEpub({
  required List<({String file, String xhtml})> docs,
  String title = 'Filosofi Teras',
  String author = 'Henry Manampiring',
  List<({String href, String label})>? nav,
  List<({String href, String label})>? ncx,
  Set<String> nonLinear = const {},
}) {
  final archive = Archive();

  void add(String name, String content) {
    final bytes = utf8.encode(content);
    archive.addFile(ArchiveFile(name, bytes.length, bytes));
  }

  add('mimetype', 'application/epub+zip');
  add('META-INF/container.xml', '''
<?xml version="1.0"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles><rootfile full-path="OEBPS/content.opf"
    media-type="application/oebps-package+xml"/></rootfiles>
</container>''');

  final manifest = StringBuffer();
  final spine = StringBuffer();
  for (var i = 0; i < docs.length; i++) {
    final d = docs[i];
    add('OEBPS/${d.file}', d.xhtml);
    manifest.writeln(
        '<item id="c$i" href="${d.file}" media-type="application/xhtml+xml"/>');
    final linear = nonLinear.contains(d.file) ? ' linear="no"' : '';
    spine.writeln('<itemref idref="c$i"$linear/>');
  }

  if (nav != null) {
    final li = nav
        .map((e) => '<li><a href="${e.href}">${e.label}</a></li>')
        .join('\n');
    add('OEBPS/nav.xhtml', '''
<?xml version="1.0" encoding="utf-8"?>
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops">
<body><nav epub:type="toc"><ol>$li</ol></nav></body></html>''');
    manifest.writeln(
        '<item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>');
  }

  var tocAttr = '';
  if (ncx != null) {
    final points = ncx.asMap().entries.map((e) => '''
<navPoint id="n${e.key}" playOrder="${e.key + 1}">
  <navLabel><text>${e.value.label}</text></navLabel>
  <content src="${e.value.href}"/>
</navPoint>''').join('\n');
    add('OEBPS/toc.ncx', '''
<?xml version="1.0" encoding="UTF-8"?>
<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">
<navMap>$points</navMap></ncx>''');
    manifest.writeln(
        '<item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml"/>');
    tocAttr = ' toc="ncx"';
  }

  add('OEBPS/content.opf', '''
<?xml version="1.0" encoding="utf-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="uid">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:title>$title</dc:title>
    <dc:creator>$author</dc:creator>
  </metadata>
  <manifest>$manifest</manifest>
  <spine$tocAttr>$spine</spine>
</package>''');

  return ZipEncoder().encode(archive);
}

String doc(String heading, String body) => '''
<?xml version="1.0" encoding="utf-8"?>
<html xmlns="http://www.w3.org/1999/xhtml"><head><title>x</title>
<style>p { color: red; }</style></head>
<body><h1>$heading</h1><p>$body</p></body></html>''';

void main() {
  const reader = EpubReader();

  test('membaca judul, penulis, dan urutan bab dari EPUB 3', () {
    final bytes = buildEpub(
      docs: [
        (file: 'c1.xhtml', xhtml: doc('Sebuah Undangan', 'Isi bab satu.')),
        (file: 'c2.xhtml', xhtml: doc('Sekelumit Filsafat', 'Isi bab dua.')),
        (file: 'c3.xhtml', xhtml: doc('Hidup Selaras Alam', 'Isi bab tiga.')),
      ],
      nav: [
        (href: 'c1.xhtml', label: 'Sebuah Undangan'),
        (href: 'c2.xhtml', label: 'Sekelumit Filsafat'),
        (href: 'c3.xhtml', label: 'Hidup Selaras Alam'),
      ],
    );

    final book = reader.read(bytes, id: 'x');
    expect(book.title, 'Filosofi Teras');
    expect(book.author, 'Henry Manampiring');
    expect(book.chapters.map((c) => c.title).toList(),
        ['Sebuah Undangan', 'Sekelumit Filsafat', 'Hidup Selaras Alam']);
    expect(book.chapters.first.text, contains('Isi bab satu.'));
    for (var i = 0; i < book.chapters.length; i++) {
      expect(book.chapters[i].index, i);
    }
  });

  test('judul diambil dari NCX kalau EPUB-nya versi 2', () {
    final bytes = buildEpub(
      docs: [
        (file: 'a.xhtml', xhtml: doc('x', 'Isi A.')),
        (file: 'b.xhtml', xhtml: doc('x', 'Isi B.')),
      ],
      ncx: [
        (href: 'a.xhtml#top', label: 'Bab Pertama'),
        (href: 'b.xhtml', label: 'Bab Kedua'),
      ],
    );
    final book = reader.read(bytes, id: 'x');
    expect(book.chapters.map((c) => c.title).toList(),
        ['Bab Pertama', 'Bab Kedua']);
  });

  test('tanpa daftar isi, judul jatuh ke heading di dalam bab', () {
    final bytes = buildEpub(
      docs: [(file: 'a.xhtml', xhtml: doc('Dikotomi Kendali', 'Isi.'))],
    );
    expect(reader.read(bytes, id: 'x').chapters.first.title, 'Dikotomi Kendali');
  });

  test('membuang style dan tag, menerjemahkan entitas', () {
    final bytes = buildEpub(docs: [
      (
        file: 'a.xhtml',
        xhtml: doc('Judul',
            'Kata &amp; kalimat &#8212; dengan &quot;kutip&quot; dan&nbsp;spasi.')
      ),
    ]);
    final text = reader.read(bytes, id: 'x').chapters.first.text;
    expect(text, contains('Kata & kalimat — dengan "kutip" dan spasi.'));
    expect(text, isNot(contains('color: red')));
    expect(text, isNot(contains('<')));
  });

  test('paragraf tetap terpisah supaya bisa jadi titik potong', () {
    final bytes = buildEpub(docs: [
      (
        file: 'a.xhtml',
        xhtml: '<html><body><p>Satu.</p><p>Dua.</p><p>Tiga.</p></body></html>'
      ),
    ]);
    final text = reader.read(bytes, id: 'x').chapters.first.text;
    expect(text.split(RegExp(r'\n{2,}')).length, 3);
  });

  test('halaman sisipan linear="no" dilewati', () {
    final bytes = buildEpub(
      docs: [
        (file: 'cover.xhtml', xhtml: doc('Sampul', 'Hak cipta dan sebagainya.')),
        (file: 'a.xhtml', xhtml: doc('Bab Satu', 'Isi sungguhan.')),
      ],
      nonLinear: {'cover.xhtml'},
    );
    final book = reader.read(bytes, id: 'x');
    expect(book.chapters.length, 1);
    expect(book.chapters.first.text, contains('Isi sungguhan.'));
  });

  test('bab kosong tidak jadi bab', () {
    final bytes = buildEpub(docs: [
      (file: 'a.xhtml', xhtml: '<html><body><p>   </p></body></html>'),
      (file: 'b.xhtml', xhtml: doc('Ada', 'Isi.')),
    ]);
    expect(reader.read(bytes, id: 'x').chapters.length, 1);
  });

  test('berkas yang bukan EPUB ditolak dengan pesan yang bisa dibaca', () {
    expect(
      () => reader.read(utf8.encode('ini bukan zip sama sekali'), id: 'x'),
      throwsA(isA<EpubException>()),
    );
  });

  test('EPUB tanpa isi ditolak, bukan menghasilkan buku hampa', () {
    final bytes = buildEpub(docs: [
      (file: 'a.xhtml', xhtml: '<html><body></body></html>'),
    ]);
    expect(() => reader.read(bytes, id: 'x'), throwsA(isA<EpubException>()));
  });
}
