/// Bingkai HP untuk prototipe web.
///
/// Yang dijaga di sini: bingkainya **tidak pernah aktif di HP**. Kalau suatu
/// saat ambangnya salah geser, APK-nya ikut terpotong 390 dp di tengah layar
/// — kerusakan yang tidak akan terlihat dari sesi pengembangan di laptop.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bacain/ui/bingkai_ponsel.dart';

Widget isi() => const Scaffold(body: Center(child: Text('isi')));

Future<void> pasang(WidgetTester t, Size ukuran) async {
  t.view.physicalSize = ukuran;
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.reset);
  await t.pumpWidget(MaterialApp(
    builder: (context, child) =>
        BingkaiPonsel(child: child ?? const SizedBox.shrink()),
    home: isi(),
  ));
}

void main() {
  testWidgets('di lebar HP, tidak ada bingkai sama sekali', (t) async {
    await pasang(t, const Size(390, 844));
    expect(find.byType(ClipRRect), findsNothing);
    expect(t.getSize(find.byType(Scaffold)).width, 390);
  });

  testWidgets('HP terlebar pun masih lolos tanpa bingkai', (t) async {
    // Beberapa HP Android besar mencapai ~480 dp lebar logis. Ambangnya harus
    // di atas itu, kalau tidak APK di HP besar ikut terbingkai.
    await pasang(t, const Size(480, 1000));
    expect(find.byType(ClipRRect), findsNothing);
    expect(t.getSize(find.byType(Scaffold)).width, 480);
  });

  testWidgets('di jendela laptop, app dibatasi ke lebar artboard', (t) async {
    await pasang(t, const Size(1440, 900));
    expect(find.byType(ClipRRect), findsOneWidget);
    expect(t.getSize(find.byType(Scaffold)).width, BingkaiPonsel.lebar);
  });

  testWidgets('jendela pendek memakai tinggi yang ada, bukan terpotong',
      (t) async {
    await pasang(t, const Size(1440, 700));
    expect(t.getSize(find.byType(Scaffold)).height, 700);
  });

  testWidgets('MediaQuery ikut dipersempit, bukan cuma kotaknya', (t) async {
    late Size terlihat;
    t.view.physicalSize = const Size(1440, 900);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(
      builder: (context, child) =>
          BingkaiPonsel(child: child ?? const SizedBox.shrink()),
      home: Builder(builder: (context) {
        terlihat = MediaQuery.of(context).size;
        return isi();
      }),
    ));
    // Apa pun yang bertanya "selebar apa layarnya" harus dijawab lebar HP.
    // Kalau dijawab 1440, tata letak responsif akan memilih cabang desktop.
    expect(terlihat.width, BingkaiPonsel.lebar);
  });
}
