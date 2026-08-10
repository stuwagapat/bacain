import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bacain/ui/tokens.dart';

/// Uji yang menjaga rantai desain→kode tetap tersambung.
///
/// Nilai warna dan huruf datang dari `design/tokens.json`. Begitu satu saja
/// hex ditulis tangan di Dart, rantainya putus diam-diam: desain mengubah
/// tokens.json, kode tidak ikut berubah, dan tidak ada yang menyadarinya
/// sampai layarnya terlihat salah di HP.
void main() {
  final lib = Directory('lib');
  final dart = lib
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      // Satu-satunya berkas yang MEMANG berisi hex — dan ia dihasilkan mesin.
      .where((f) => !f.path.endsWith('tokens.g.dart'))
      .toList();

  test('tidak ada satu pun hex ditulis tangan di lib/', () {
    final pelanggar = <String>[];
    for (final f in dart) {
      final baris = f.readAsLinesSync();
      for (var i = 0; i < baris.length; i++) {
        if (RegExp(r'Color\(0x').hasMatch(baris[i])) {
          pelanggar.add('${f.path}:${i + 1}  ${baris[i].trim()}');
        }
      }
    }
    expect(pelanggar, isEmpty,
        reason: 'Ubah nilainya di design/tokens.json lalu jalankan '
            'python3 tools/gen_tokens.py — jangan tulis hex di Dart.\n'
            '${pelanggar.join('\n')}');
  });

  test('berkas hasil generator tidak pernah diedit tangan', () {
    final g = File('lib/ui/tokens.g.dart').readAsStringSync();
    expect(g, startsWith('// DIHASILKAN OTOMATIS'));
  });

  test('tema bawaan gelap', () {
    // Bukan selera: app ini didengarkan menjelang tidur. Kalau suatu saat
    // nilai ini berbalik tanpa mode terang benar-benar ditata, uji ini yang
    // menahannya.
    expect(warna, same(AppColors.dark));
    expect(warna.bgBase.computeLuminance(), lessThan(0.1));
    expect(warna.textPrimary.computeLuminance(), greaterThan(0.5));
  });

  test('teks di atas bidang merek lolos WCAG AA', () {
    // Putih di atas coral cuma 3,0:1. Ambang 4,5:1 wajib di sini —
    // aksesibilitas adalah salah satu klaim produk ini.
    expect(_kontras(warna.brandOnPrimary, warna.brandPrimary),
        greaterThanOrEqualTo(4.5));
    expect(_kontras(Colors.white, warna.brandPrimary), lessThan(4.5),
        reason: 'kalau putih tiba-tiba lolos, palet mereknya berubah besar — '
            'periksa ulang, jangan langsung longgarkan uji ini');
  });

  test('teks bacaan lolos WCAG AA di atas latarnya masing-masing', () {
    expect(_kontras(warna.readingTextActive, warna.readingHighlightBg),
        greaterThanOrEqualTo(4.5));
    expect(_kontras(warna.readingTextFuture, warna.bgBase),
        greaterThanOrEqualTo(4.5));
    // textPast memang sengaja pudar — sudah lewat, tidak untuk dibaca lagi —
    // tapi tetap harus di atas ambang teks besar (3:1), bukan sekadar terlihat.
    expect(_kontras(warna.readingTextPast, warna.bgBase),
        greaterThanOrEqualTo(3.0));
  });

  test('tiga peran huruf punya family sendiri-sendiri', () {
    final family = {
      AppType.uiFamily,
      AppType.readingFamily,
      AppType.a11yFamily,
    };
    expect(family.length, 3);
  });

  test('setiap family yang dipakai kode terdaftar di pubspec', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    for (final f in [
      AppType.uiFamily,
      AppType.readingFamily,
      AppType.a11yFamily,
    ]) {
      // Kalau nama family di pubspec meleset satu huruf saja, Flutter jatuh ke
      // font sistem tanpa satu pun pesan error. Gejalanya cuma "kok hurufnya
      // beda" — uji ini yang menangkapnya lebih awal.
      expect(pubspec, contains('family: $f'), reason: 'family $f tidak ada di pubspec.yaml');
    }
  });

  test('berkas font yang didaftarkan pubspec benar-benar ada', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final aset = RegExp(r'asset: (assets/fonts/\S+)')
        .allMatches(pubspec)
        .map((m) => m.group(1)!);
    expect(aset, isNotEmpty);
    for (final a in aset) {
      expect(File(a).existsSync(), isTrue, reason: '$a tidak ada');
    }
  });

  test('teks bacaan memakai serif, antarmuka tidak', () {
    expect(AppType.readingBody.fontFamily, AppType.readingFamily);
    expect(AppType.uiBody.fontFamily, AppType.uiFamily);
  });

  test('warna sampul stabil lintas proses', () {
    // hashCode Dart TIDAK stabil antar-proses. Kalau sampul memakainya,
    // warna buku di rak berubah sendiri tiap app dibuka.
    expect(AppCover.forTitle('Filosofi Teras'),
        AppCover.forTitle('Filosofi Teras'));
    expect(AppCover.palette.length, 8);
  });
}

double _kontras(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final terang = la > lb ? la : lb, gelap = la > lb ? lb : la;
  return (terang + 0.05) / (gelap + 0.05);
}
