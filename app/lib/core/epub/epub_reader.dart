/// Pembaca EPUB.
///
/// EPUB dipilih sebagai jalur masuk pertama karena strukturnya jujur: daftar
/// isinya eksplisit di dalam file. Kalau pemecahan segmen salah, ketahuan
/// bahwa penyebabnya memang segmentasi — bukan OCR yang meleset.
///
/// Bekerja dari byte, bukan dari path, supaya sama saja dipakai di Android
/// (file_picker) maupun di web (input file).
library;

import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import '../model/book.dart';
import '../text/normalizer.dart';

class EpubException implements Exception {
  final String message;
  EpubException(this.message);
  @override
  String toString() => 'EpubException: $message';
}

class EpubReader {
  final Normalizer normalizer;
  const EpubReader({this.normalizer = const Normalizer()});

  Book read(List<int> bytes, {required String id}) {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (e) {
      throw EpubException('Berkas ini bukan EPUB yang bisa dibuka ($e).');
    }

    final files = <String, ArchiveFile>{};
    for (final f in archive.files) {
      if (f.isFile) files[_normalizePath(f.name)] = f;
    }

    final opfPath = _findOpfPath(files);
    final opfDir = _dirOf(opfPath);
    final opf = XmlDocument.parse(_utf8(files[opfPath]!));

    final title = _metaText(opf, 'title') ?? 'Tanpa judul';
    final author = _metaText(opf, 'creator') ?? '';

    // manifest: id -> item
    final manifest = <String, _Item>{};
    for (final el in opf.findAllElements('item', namespace: '*')) {
      final itemId = el.getAttribute('id');
      final href = el.getAttribute('href');
      if (itemId == null || href == null) continue;
      manifest[itemId] = _Item(
        href: _resolve(opfDir, href),
        mediaType: el.getAttribute('media-type') ?? '',
        properties: el.getAttribute('properties') ?? '',
      );
    }

    final spine = <_Item>[];
    String? ncxId;
    for (final spineEl in opf.findAllElements('spine', namespace: '*')) {
      ncxId = spineEl.getAttribute('toc');
      for (final ref in spineEl.findAllElements('itemref', namespace: '*')) {
        final idref = ref.getAttribute('idref');
        if (idref == null) continue;
        final item = manifest[idref];
        // linear="no" menandai halaman sisipan (hak cipta, iklan) — dilewati.
        if (item == null || ref.getAttribute('linear') == 'no') continue;
        if (!item.isDocument) continue;
        spine.add(item);
      }
      break;
    }
    if (spine.isEmpty) {
      throw EpubException('EPUB ini tidak punya isi yang bisa dibaca.');
    }

    final toc = _readToc(files, manifest, ncxId);

    final chapters = <Chapter>[];
    for (final item in spine) {
      final file = files[item.href];
      if (file == null) continue;
      final raw = _utf8(file);
      final text = normalizer.clean(_htmlToText(raw));
      if (text.isEmpty) continue;
      chapters.add(Chapter(
        index: chapters.length,
        title: toc[item.href] ?? _headingOf(raw) ?? '',
        text: text,
      ));
    }
    if (chapters.isEmpty) {
      throw EpubException('Isi EPUB terbaca kosong setelah dibersihkan.');
    }

    return Book(id: id, title: title, author: author, chapters: chapters);
  }

  // ── lokasi berkas ────────────────────────────────────────────────

  String _findOpfPath(Map<String, ArchiveFile> files) {
    final container = files['META-INF/container.xml'];
    if (container != null) {
      final doc = XmlDocument.parse(_utf8(container));
      for (final el in doc.findAllElements('rootfile', namespace: '*')) {
        final path = el.getAttribute('full-path');
        if (path != null && files.containsKey(_normalizePath(path))) {
          return _normalizePath(path);
        }
      }
    }
    // Sebagian EPUB hasil ekspor alat tertentu tidak punya container.xml
    // yang benar. Cari .opf mana pun sebelum menyerah.
    final fallback = files.keys.firstWhere(
      (k) => k.toLowerCase().endsWith('.opf'),
      orElse: () => '',
    );
    if (fallback.isEmpty) {
      throw EpubException('Tidak menemukan berkas .opf di dalam EPUB.');
    }
    return fallback;
  }

  Map<String, String> _readToc(
    Map<String, ArchiveFile> files,
    Map<String, _Item> manifest,
    String? ncxId,
  ) {
    // EPUB 3: item dengan properties="nav".
    for (final item in manifest.values) {
      if (item.properties.split(RegExp(r'\s+')).contains('nav')) {
        final f = files[item.href];
        if (f != null) {
          final map = _readNavToc(_utf8(f), _dirOf(item.href));
          if (map.isNotEmpty) return map;
        }
      }
    }
    // EPUB 2: NCX.
    final ncx = ncxId != null ? manifest[ncxId] : null;
    if (ncx != null) {
      final f = files[ncx.href];
      if (f != null) return _readNcxToc(_utf8(f), _dirOf(ncx.href));
    }
    return const {};
  }

  Map<String, String> _readNavToc(String xhtml, String baseDir) {
    final out = <String, String>{};
    try {
      final doc = XmlDocument.parse(xhtml);
      for (final a in doc.findAllElements('a', namespace: '*')) {
        final href = a.getAttribute('href');
        if (href == null) continue;
        final text = a.innerText.trim();
        if (text.isEmpty) continue;
        out.putIfAbsent(_resolve(baseDir, _stripFragment(href)), () => text);
      }
    } catch (_) {
      // Daftar isi rusak bukan alasan menolak seluruh buku — bab tetap
      // terbaca, hanya judulnya jatuh ke cadangan.
    }
    return out;
  }

  Map<String, String> _readNcxToc(String xml, String baseDir) {
    final out = <String, String>{};
    try {
      final doc = XmlDocument.parse(xml);
      for (final p in doc.findAllElements('navPoint', namespace: '*')) {
        final src = p
            .findElements('content', namespace: '*')
            .firstOrNull
            ?.getAttribute('src');
        final label =
            p.findElements('navLabel', namespace: '*').firstOrNull?.innerText.trim() ??
                '';
        if (src == null || label.isEmpty) continue;
        out.putIfAbsent(_resolve(baseDir, _stripFragment(src)), () => label);
      }
    } catch (_) {}
    return out;
  }

  // ── HTML ke teks ─────────────────────────────────────────────────

  /// Sengaja pakai regex, bukan parser XML: banyak EPUB di alam liar tidak
  /// benar-benar XHTML yang sah, dan parser ketat akan menolak seluruh bab
  /// hanya karena satu tag tak tertutup.
  String _htmlToText(String html) {
    var t = html;
    final body = RegExp(r'<body[^>]*>(.*?)</body>', dotAll: true, caseSensitive: false)
        .firstMatch(t);
    if (body != null) t = body.group(1)!;

    t = t.replaceAll(
        RegExp(r'<(script|style)[^>]*>.*?</\1>', dotAll: true, caseSensitive: false), '');
    t = t.replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');
    t = t.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
    t = t.replaceAll(
        RegExp(r'</(p|div|h[1-6]|li|tr|blockquote|section|article|figcaption)>',
            caseSensitive: false),
        '\n\n');
    t = t.replaceAll(RegExp(r'<[^>]+>'), '');
    t = _decodeEntities(t);
    return t;
  }

  String? _headingOf(String html) {
    final m = RegExp(r'<h[1-3][^>]*>(.*?)</h[1-3]>',
            dotAll: true, caseSensitive: false)
        .firstMatch(html);
    if (m == null) return null;
    final text = _decodeEntities(m.group(1)!.replaceAll(RegExp(r'<[^>]+>'), ''))
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return text.isEmpty ? null : text;
  }

  static const _named = {
    'amp': '&', 'lt': '<', 'gt': '>', 'quot': '"', 'apos': "'",
    'nbsp': ' ', 'ndash': '–', 'mdash': '—', 'hellip': '…',
    'lsquo': '‘', 'rsquo': '’', 'ldquo': '“', 'rdquo': '”',
    'laquo': '«', 'raquo': '»', 'shy': '', 'middot': '·', 'bull': '•',
  };

  String _decodeEntities(String t) => t.replaceAllMapped(
        RegExp(r'&(#x?[0-9a-fA-F]+|[a-zA-Z]+);'),
        (m) {
          final e = m.group(1)!;
          if (e.startsWith('#')) {
            final isHex = e[1] == 'x' || e[1] == 'X';
            final code =
                int.tryParse(isHex ? e.substring(2) : e.substring(1), radix: isHex ? 16 : 10);
            if (code == null || code < 0 || code > 0x10FFFF) return m.group(0)!;
            return String.fromCharCode(code);
          }
          return _named[e.toLowerCase()] ?? m.group(0)!;
        },
      );

  // ── util ─────────────────────────────────────────────────────────

  String _utf8(ArchiveFile f) {
    final data = f.content as List<int>;
    // allowMalformed: satu byte rusak tidak boleh menggagalkan satu buku.
    return const Utf8Decoder(allowMalformed: true).convert(data);
  }

  String? _metaText(XmlDocument opf, String name) {
    // namespace '*' mencocokkan nama lokal apa pun prefiksnya — metadata
    // EPUB ditulis <dc:title>, jadi pencarian nama berkualifikasi meleset.
    for (final el in opf.findAllElements(name, namespace: '*')) {
      final t = el.innerText.trim();
      if (t.isNotEmpty) return t;
    }
    return null;
  }

  String _stripFragment(String href) {
    final i = href.indexOf('#');
    return i < 0 ? href : href.substring(0, i);
  }

  String _dirOf(String path) {
    final i = path.lastIndexOf('/');
    return i < 0 ? '' : path.substring(0, i);
  }

  String _resolve(String baseDir, String href) {
    final decoded = Uri.decodeFull(href);
    if (decoded.startsWith('/')) return _normalizePath(decoded.substring(1));
    return _normalizePath(baseDir.isEmpty ? decoded : '$baseDir/$decoded');
  }

  String _normalizePath(String path) {
    final parts = <String>[];
    for (final p in path.split('/')) {
      if (p.isEmpty || p == '.') continue;
      if (p == '..') {
        if (parts.isNotEmpty) parts.removeLast();
        continue;
      }
      parts.add(p);
    }
    return parts.join('/');
  }
}

class _Item {
  final String href;
  final String mediaType;
  final String properties;
  const _Item({
    required this.href,
    required this.mediaType,
    required this.properties,
  });

  bool get isDocument =>
      mediaType.contains('xhtml') ||
      mediaType.contains('html') ||
      href.toLowerCase().endsWith('.xhtml') ||
      href.toLowerCase().endsWith('.html') ||
      href.toLowerCase().endsWith('.htm');
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
