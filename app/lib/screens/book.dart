import 'package:flutter/material.dart';

import '../app_state.dart';
import '../ui/tokens.dart';
import 'mini_player.dart';
import 'player.dart';

/// Daftar bagian. Bagian yang belum terbuka sengaja tetap terlihat — user
/// perlu tahu bukunya masih sepanjang apa, bukan disembunyikan.
class BookPage extends StatelessWidget {
  final AppState state;
  const BookPage({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final book = state.active!;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          key: const Key('back-to-library'),
          icon: const Icon(Icons.arrow_back),
          onPressed: state.closeBook,
        ),
        title: Text(book.title, style: AppType.uiTitleSmall),
      ),
      bottomNavigationBar: MiniPlayer(state: state),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: QuotaBar(
              remainingMinutes: state.remainingMinutes,
              totalMinutes: state.settings.dailyMinutes,
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 28),
              itemCount: book.segments.length,
              itemBuilder: (context, i) {
                final s = book.segments[i];
                final done = i <= book.lastFinishedIndex;
                final open = state.canOpen(book, i);
                final isNext = i == book.lastFinishedIndex + 1;
                return ListTile(
                  key: Key('segment-$i'),
                  enabled: open,
                  leading: Icon(
                    done
                        ? Icons.check_circle
                        : isNext
                            ? Icons.play_circle_fill
                            : Icons.lock_outline,
                    // Status dibedakan BENTUK lebih dulu — centang, lingkaran
                    // penuh, gembok — supaya tetap terbaca tanpa warna.
                    color: done
                        ? warna.textDisabled
                        : (isNext ? warna.brandPrimary : warna.borderStrong),
                  ),
                  title: Text(
                    s.title.isEmpty ? 'Bagian ${i + 1}' : s.title,
                    style: AppType.uiTitleSmall.copyWith(
                      fontWeight: isNext ? FontWeight.w700 : FontWeight.w600,
                      color: open ? warna.textPrimary : warna.textDisabled,
                    ),
                  ),
                  subtitle: Text(
                    '${s.estimatedDuration().inMinutes} menit'
                    '${done ? ' · sudah didengar' : ''}',
                    style: bodyStyle.copyWith(fontSize: 12.5),
                  ),
                  onTap: open
                      ? () async {
                          await state.openSegment(i);
                          if (!context.mounted) return;
                          await openListening(context, state);
                        }
                      : null,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
