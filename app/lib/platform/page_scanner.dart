/// Pemindai halaman buku fisik: kamera Google + OCR, dua-duanya di perangkat.
///
/// UI kameranya milik Google — deteksi sudut, potong otomatis, koreksi
/// perspektif, mode banyak halaman. Tidak ada gunanya menulis ulang itu, dan
/// hasilnya jauh lebih baik daripada kamera polos.
///
/// Semuanya berjalan di HP: tidak ada gambar yang dikirim ke mana pun, dan
/// tidak ada biaya per halaman. Satu-satunya tekanan biaya di produk ini tetap
/// di TTS.
library;

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../core/scan/page_scanner.dart';

PageScanner createPageScanner() {
  // Pemindai dokumen ML Kit hanya ada di Android. Di tempat lain layarnya
  // tetap tampil tapi dimatikan dengan alasan tertulis.
  if (kIsWeb) return UnavailableScanner();
  return defaultTargetPlatform == TargetPlatform.android
      ? MlKitPageScanner()
      : UnavailableScanner();
}

class MlKitPageScanner implements PageScanner {
  @override
  bool get available => true;

  /// Satu sesi memindai maksimal sebanyak ini. Memfoto satu buku utuh
  /// (±250 jepretan) tidak realistis — dan memang tidak perlu: satu bab saja
  /// sudah cukup untuk jatah dengar beberapa hari. Memfoto jadi ritual kecil,
  /// bukan kerja rodi di awal.
  static const maxPages = 40;

  @override
  Future<List<ScannedPage>> scan() async {
    final scanner = DocumentScanner(
      options: DocumentScannerOptions(
        documentFormats: const {DocumentFormat.jpeg},
        mode: ScannerMode.base,
        pageLimit: maxPages,
        isGalleryImport: true,
      ),
    );

    List<String> images;
    try {
      final result = await scanner.scanDocument();
      images = result.images ?? const [];
    } catch (_) {
      // Dibatalkan user, atau pemindai tidak tersedia di HP ini.
      return const [];
    } finally {
      await scanner.close();
    }

    if (images.isEmpty) return const [];

    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final out = <ScannedPage>[];
      for (final path in images) {
        try {
          final hasil =
              await recognizer.processImage(InputImage.fromFilePath(path));
          out.add(ScannedPage(
            imagePath: path,
            text: hasil.text,
            keyakinan: _skorPerKata(hasil),
          ));
        } catch (_) {
          // Satu halaman gagal dibaca tetap masuk daftar dengan teks kosong,
          // supaya user melihatnya di layar tinjau dan bisa mengetik sendiri
          // atau membuangnya — bukan hilang diam-diam.
          out.add(ScannedPage(imagePath: path, text: ''));
        }
      }
      return out;
    } finally {
      await recognizer.close();
    }
  }
}

/// Skor keyakinan per kata, untuk menandai kata yang mungkin salah baca.
///
/// Kalau satu kata muncul beberapa kali dengan skor berbeda, yang TERENDAH
/// yang dipakai: satu kemunculan yang meragukan sudah cukup alasan untuk
/// meminta user melihatnya.
Map<String, double> _skorPerKata(RecognizedText hasil) {
  final out = <String, double>{};
  for (final blok in hasil.blocks) {
    for (final baris in blok.lines) {
      for (final kata in baris.elements) {
        final skor = kata.confidence;
        if (skor == null) continue;
        final ada = out[kata.text];
        if (ada == null || skor < ada) out[kata.text] = skor;
      }
    }
  }
  return out;
}
