// DIHASILKAN OTOMATIS dari design/tokens.json — jangan diedit tangan.
// Jalankan: python3 tools/gen_tokens.py
//
// Nama token adalah kontrak antara desain dan kode. Nilainya boleh berubah
// kapan saja lewat tokens.json; namanya tidak.

import 'package:flutter/material.dart';

@immutable
class AppColors {
  final Color bgBase;
  final Color bgScrim;
  final Color bgSurface;
  final Color bgSurfaceVariant;
  final Color borderDefault;
  final Color borderStrong;
  final Color brandAccent;
  final Color brandOnPrimary;
  final Color brandPrimary;
  final Color playerControlBg;
  final Color playerControlIcon;
  final Color playerMiniBarBg;
  final Color progressFilled;
  final Color progressTrack;
  final Color quotaFilled;
  final Color quotaTrack;
  final Color readingHighlightBg;
  final Color readingTextActive;
  final Color readingTextFuture;
  final Color readingTextPast;
  final Color statusError;
  final Color statusErrorBg;
  final Color statusSuccess;
  final Color statusSuccessBg;
  final Color statusWarning;
  final Color statusWarningBg;
  final Color textDisabled;
  final Color textOnBrand;
  final Color textPrimary;
  final Color textSecondary;
  const AppColors({
    required this.bgBase,
    required this.bgScrim,
    required this.bgSurface,
    required this.bgSurfaceVariant,
    required this.borderDefault,
    required this.borderStrong,
    required this.brandAccent,
    required this.brandOnPrimary,
    required this.brandPrimary,
    required this.playerControlBg,
    required this.playerControlIcon,
    required this.playerMiniBarBg,
    required this.progressFilled,
    required this.progressTrack,
    required this.quotaFilled,
    required this.quotaTrack,
    required this.readingHighlightBg,
    required this.readingTextActive,
    required this.readingTextFuture,
    required this.readingTextPast,
    required this.statusError,
    required this.statusErrorBg,
    required this.statusSuccess,
    required this.statusSuccessBg,
    required this.statusWarning,
    required this.statusWarningBg,
    required this.textDisabled,
    required this.textOnBrand,
    required this.textPrimary,
    required this.textSecondary,
  });

  static const dark = AppColors(
    bgBase: Color(0xFF0A0C0A),
    bgScrim: Color(0xB3000000),
    bgSurface: Color(0xFF141712),
    bgSurfaceVariant: Color(0xFF1E221B),
    borderDefault: Color(0xFF1E221B),
    borderStrong: Color(0xFF2A2F27),
    brandAccent: Color(0xFFD8E6B4),
    brandOnPrimary: Color(0xFF001E03),
    brandPrimary: Color(0xFFF2685A),
    playerControlBg: Color(0xFFF2685A),
    playerControlIcon: Color(0xFF001E03),
    playerMiniBarBg: Color(0xFF0A0C0A),
    progressFilled: Color(0xFFF2685A),
    progressTrack: Color(0xFF1E221B),
    quotaFilled: Color(0xFFF2685A),
    quotaTrack: Color(0xFF1E221B),
    readingHighlightBg: Color(0xFF2F1B17),
    readingTextActive: Color(0xFFFFFEFB),
    readingTextFuture: Color(0xFFA8AC9F),
    readingTextPast: Color(0xFF7C837A),
    statusError: Color(0xFFFF4A21),
    statusErrorBg: Color(0xFF1E221B),
    statusSuccess: Color(0xFFC6DA8B),
    statusSuccessBg: Color(0xFF1E221B),
    statusWarning: Color(0xFFF2C438),
    statusWarningBg: Color(0xFF1E221B),
    textDisabled: Color(0xFF5A6058),
    textOnBrand: Color(0xFF001E03),
    textPrimary: Color(0xFFEFEADA),
    textSecondary: Color(0xFF8E9489),
  );

  static const light = AppColors(
    bgBase: Color(0xFFF7F5EC),
    bgScrim: Color(0x80000000),
    bgSurface: Color(0xFFFFFEFB),
    bgSurfaceVariant: Color(0xFFEFEADA),
    borderDefault: Color(0xFFD6D2C2),
    borderStrong: Color(0xFFA8AC9F),
    brandAccent: Color(0xFFC6DA8B),
    brandOnPrimary: Color(0xFF001E03),
    brandPrimary: Color(0xFFF2685A),
    playerControlBg: Color(0xFFF2685A),
    playerControlIcon: Color(0xFFFFFEFB),
    playerMiniBarBg: Color(0xFFFFFEFB),
    progressFilled: Color(0xFFF2685A),
    progressTrack: Color(0xFFD6D2C2),
    quotaFilled: Color(0xFFC6DA8B),
    quotaTrack: Color(0xFFD6D2C2),
    readingHighlightBg: Color(0xFFEEF4DE),
    readingTextActive: Color(0xFF0A0C0A),
    readingTextFuture: Color(0xFF2A2F27),
    readingTextPast: Color(0xFF8E9489),
    statusError: Color(0xFFFF4A21),
    statusErrorBg: Color(0xFFFFE4DC),
    statusSuccess: Color(0xFFC6DA8B),
    statusSuccessBg: Color(0xFFEEF4DE),
    statusWarning: Color(0xFFF2C438),
    statusWarningBg: Color(0xFFFCF0D0),
    textDisabled: Color(0xFF8E9489),
    textOnBrand: Color(0xFF001E03),
    textPrimary: Color(0xFF141712),
    textSecondary: Color(0xFF7C837A),
  );

}

class AppSpacing {
  const AppSpacing._();
  static const space0 = 0.0;
  static const space1 = 4.0;
  static const space2 = 8.0;
  static const space3 = 12.0;
  static const space4 = 16.0;
  static const space5 = 24.0;
  static const space6 = 32.0;
  static const space7 = 48.0;
  static const space8 = 64.0;
}

class AppRadius {
  const AppRadius._();
  static const none = 0.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const full = 999.0;
}

class AppSize {
  const AppSize._();
  static const touchMin = 48.0;
  static const icon = 24.0;
  static const miniPlayer = 64.0;
  static const coverSm = 56.0;
  static const coverMd = 96.0;
  static const coverLg = 120.0;
}

class AppType {
  const AppType._();
  static const uiFamily = 'Jakarta';  // Plus Jakarta Sans
  static const readingFamily = 'Literata';  // Literata
  static const a11yFamily = 'AtkinsonHyperlegible';  // Atkinson Hyperlegible

  static const uiDisplay = TextStyle(
    fontFamily: 'Literata',
    fontWeight: FontWeight.w700,
    fontSize: 32.0,
    height: 1.25,
    letterSpacing: -0.5,
  );
  static const uiHeadline = TextStyle(
    fontFamily: 'Literata',
    fontWeight: FontWeight.w700,
    fontSize: 24.0,
    height: 1.333,
    letterSpacing: -0.25,
  );
  static const uiTitle = TextStyle(
    fontFamily: 'Jakarta',
    fontWeight: FontWeight.w600,
    fontSize: 20.0,
    height: 1.4,
    letterSpacing: 0.0,
  );
  static const uiTitleSmall = TextStyle(
    fontFamily: 'Jakarta',
    fontWeight: FontWeight.w600,
    fontSize: 16.0,
    height: 1.5,
    letterSpacing: 0.0,
  );
  static const uiBody = TextStyle(
    fontFamily: 'Jakarta',
    fontWeight: FontWeight.w400,
    fontSize: 15.0,
    height: 1.467,
    letterSpacing: 0.0,
  );
  static const uiBodySmall = TextStyle(
    fontFamily: 'Jakarta',
    fontWeight: FontWeight.w400,
    fontSize: 13.0,
    height: 1.385,
    letterSpacing: 0.0,
  );
  static const uiLabel = TextStyle(
    fontFamily: 'Jakarta',
    fontWeight: FontWeight.w600,
    fontSize: 14.0,
    height: 1.429,
    letterSpacing: 0.1,
  );
  static const uiCaption = TextStyle(
    fontFamily: 'Jakarta',
    fontWeight: FontWeight.w400,
    fontSize: 12.0,
    height: 1.333,
    letterSpacing: 0.2,
  );
  static const readingBody = TextStyle(
    fontFamily: 'Literata',
    fontWeight: FontWeight.w400,
    fontSize: 19.0,
    height: 1.684,
    letterSpacing: 0.0,
  );
  static const readingBodyLarge = TextStyle(
    fontFamily: 'Literata',
    fontWeight: FontWeight.w400,
    fontSize: 22.0,
    height: 1.636,
    letterSpacing: 0.0,
  );
  static const readingChapterTitle = TextStyle(
    fontFamily: 'Literata',
    fontWeight: FontWeight.w600,
    fontSize: 24.0,
    height: 1.333,
    letterSpacing: -0.25,
  );
  static const readingRecap = TextStyle(
    fontFamily: 'Literata',
    fontWeight: FontWeight.w400,
    fontSize: 18.0,
    height: 1.667,
    letterSpacing: 0.0,
  );
}

/// Warna sampul untuk buku tanpa gambar sampul — hasil scan dan sebagian
/// besar PDF tidak punya. Dipilih dari hash judul dan SENGAJA tanpa makna:
/// jangan pernah dipakai untuk menandai status.
class AppCover {
  const AppCover._();
  static const palette = <Color>[
    Color(0xFFF2EFE4),
    Color(0xFFDBE3D8),
    Color(0xFFC6DA8B),
    Color(0xFFF2C438),
    Color(0xFFA9A2C4),
    Color(0xFFF2685A),
    Color(0xFFFF4A21),
    Color(0xFF948B12),
  ];

  /// Stabil lintas sesi dan lintas perangkat — hashCode Dart TIDAK stabil,
  /// jadi jumlah kode unit dipakai supaya sampul buku tidak berubah warna.
  static Color forTitle(String title) {
    var h = 0;
    for (final c in title.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return palette[h % palette.length];
  }
}
