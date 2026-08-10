/// Baris yang menempel di bawah layar utama selagi ada yang dibacakan.
///
/// Ada karena keluar dari daftar bagian tidak boleh mematikan suaranya:
/// skenario aslinya adalah memasukkan HP ke saku lalu jalan. Yang berhenti
/// cuma layarnya, dan baris ini yang membawanya ke layar berikutnya.
///
/// Tingginya persis `AppSize.miniPlayer` (64 dp), dan tiap layar utama sudah
/// memperhitungkan 64 dp itu terpotong dari bawah.
library;

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../ui/tokens.dart';
import 'player.dart';

class MiniPlayer extends StatelessWidget {
  final AppState state;
  const MiniPlayer({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    // Mendengarkan pemutar LANGSUNG, bukan cuma AppState. AppState hanya
    // memberi kabar saat satu bagian selesai — kalau baris ini bergantung
    // padanya saja, ikon jeda tidak akan pernah berubah saat ditekan.
    return AnimatedBuilder(
      animation: Listenable.merge([state, state.player]),
      builder: (context, _) => _baris(context),
    );
  }

  Widget _baris(BuildContext context) {
    final book = state.reading;
    if (book == null) return const SizedBox.shrink();

    final player = state.player;
    final bagian = book.currentSegment;

    return Material(
      color: warna.playerMiniBarBg,
      child: InkWell(
        key: const Key('mini-player'),
        onTap: () {
          // Membuka kembali bukunya DAN pemutarnya: user yang mengetuk baris
          // ini ingin kembali ke bacaannya, bukan ke daftar bagian.
          state.resumeReading();
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => PlayerPage(state: state)),
          );
        },
        child: Container(
          height: AppSize.miniPlayer,
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: warna.borderDefault)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 44,
                decoration: BoxDecoration(
                  color: AppCover.forTitle(book.title),
                  borderRadius: BorderRadius.circular(AppRadius.sm - 2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(book.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.uiCaption.copyWith(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: warna.textPrimary)),
                    const SizedBox(height: 2),
                    Text(
                      bagian == null
                          ? 'Siap dilanjutkan'
                          : '${bagian.title.isEmpty ? 'Bagian '
                              '${bagian.index + 1}' : bagian.title}'
                              ' · ${player.index + 1}/'
                              '${player.sentences.length}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.uiCaption.copyWith(
                          fontSize: 11, color: warna.textSecondary),
                    ),
                  ],
                ),
              ),
              IconButton(
                key: const Key('mini-toggle'),
                tooltip: player.isPlaying ? 'Jeda' : 'Lanjutkan',
                icon: Icon(player.isPlaying ? Icons.pause : Icons.play_arrow),
                color: warna.playerControlIcon == warna.brandOnPrimary
                    ? warna.brandPrimary
                    : warna.playerControlIcon,
                onPressed: player.toggle,
              ),
              IconButton(
                key: const Key('mini-stop'),
                tooltip: 'Hentikan',
                iconSize: 20,
                icon: const Icon(Icons.close),
                color: warna.textDisabled,
                onPressed: state.stopReading,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
