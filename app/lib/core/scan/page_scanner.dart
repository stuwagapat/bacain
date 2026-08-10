/// Pemindai halaman buku fisik.
///
/// Antarmukanya ada di `core/` supaya layar dan `AppState` bisa memakainya
/// tanpa menarik ML Kit ke dalam uji. Penerapan sungguhannya di
/// `platform/page_scanner.dart`.
library;

class ScannedPage {
  /// Berkas gambar hasil pindaian, supaya layar tinjau bisa menampilkan
  /// halaman aslinya di sebelah teksnya. OCR tidak akan pernah sempurna —
  /// user harus bisa membandingkan, bukan disuruh percaya.
  final String imagePath;
  final String text;

  /// Skor keyakinan ML Kit per kata, kalau modelnya memberi. Sering kosong —
  /// model Latin bawaan mengembalikan null di banyak perangkat — jadi layar
  /// tinjau tidak boleh bergantung padanya, cuma memakainya kalau ada.
  final Map<String, double> keyakinan;

  const ScannedPage({
    required this.imagePath,
    required this.text,
    this.keyakinan = const {},
  });

  ScannedPage copyWith({String? text}) => ScannedPage(
        imagePath: imagePath,
        text: text ?? this.text,
        keyakinan: keyakinan,
      );
}

abstract class PageScanner {
  /// `false` di web dan di perangkat yang tidak punya pemindai. Layarnya
  /// tetap ditampilkan tapi dimatikan dengan alasan tertulis, supaya alur
  /// produknya utuh terlihat.
  bool get available;

  /// Membuka pemindai, lalu mengembalikan teks tiap halaman yang diambil.
  /// Daftar kosong berarti user membatalkan — bukan kegagalan.
  Future<List<ScannedPage>> scan();
}

class UnavailableScanner implements PageScanner {
  @override
  bool get available => false;
  @override
  Future<List<ScannedPage>> scan() async => const [];
}

class FakeScanner implements PageScanner {
  FakeScanner(this.pages, {this.available = true});

  final List<ScannedPage> pages;
  @override
  final bool available;
  int calls = 0;

  @override
  Future<List<ScannedPage>> scan() async {
    calls++;
    return pages;
  }
}
