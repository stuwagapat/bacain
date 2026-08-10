// Menguji bug yang dilaporkan: teks dan suara tidak sinkron di pemutar.
//
// Penyebabnya penjaga waktu di web_speech_engine yang MENYALIP `onend`.
// Penjaga itu menebak durasi ucapan dari jumlah huruf. Tebakan tidak mungkin
// selalu tepat, dan tiap kali ia kecepatan akibatnya menumpuk:
//
//   1. pemutar maju ke kalimat berikutnya — teks mendahului suara;
//   2. `speak()` berikutnya masuk ANTREAN di belakang ucapan yang masih
//      berjalan, bukan menggantikannya;
//   3. selisihnya bertambah di tiap kalimat sesudahnya.
//
// Mesin bicara tiruan di sini sengaja LEBIH LAMBAT dari tebakan penjaga:
// kalimat pendek (tebakan jatuh ke lantai 4 detik) tapi berbunyi 6 detik.
//
// Yang diukur bukan tampilan, tapi TUMPANG TINDIH: apakah `speak()` dipanggil
// selagi ucapan sebelumnya masih berjalan. Satu saja sudah berarti rusak.

import { chromium } from 'playwright';

const URL = process.env.URL || 'http://127.0.0.1:8099/bacain/';

// Lebih lama dari lantai penjaga (4000 ms), supaya penjaga pasti lebih dulu
// habis daripada ucapannya kalau ia tidak memeriksa keadaan mesin.
const DURASI_UCAP = 6000;

const mock = (durasi) => {
  const log = { spoken: [], tumpangTindih: 0, maksBersamaan: 0 };
  let speaking = false, paused = false, berjalan = 0;

  class FakeSynth {
    get speaking() { return speaking; }
    get pending() { return false; }
    get paused() { return paused; }
    getVoices() {
      return [{ voiceURI: 'ayu', name: 'Ayu', lang: 'id-ID', default: true, localService: true }];
    }
    speak(u) {
      if (berjalan > 0) log.tumpangTindih++;
      berjalan++;
      if (berjalan > log.maksBersamaan) log.maksBersamaan = berjalan;
      log.spoken.push(u.text);
      speaking = true;
      setTimeout(() => {
        berjalan--;
        if (berjalan === 0) speaking = false;
        if (u.onend) u.onend(new Event('end'));
      }, durasi);
    }
    cancel() { berjalan = 0; speaking = false; }
    pause() { paused = true; }
    resume() { paused = false; }
  }

  Object.defineProperty(window, 'speechSynthesis', { value: new FakeSynth(), configurable: true });
  window.SpeechSynthesisUtterance = function (text) { this.text = text; this.onend = null; this.onerror = null; };
  window.__tts = log;
};

const b = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium-1194/chrome-linux/chrome' });
const page = await b.newPage({ viewport: { width: 390, height: 844 } });
page.on('pageerror', e => console.log('  ! pageerror:', String(e).slice(0, 160)));
await page.addInitScript(mock, DURASI_UCAP);
await page.goto(URL, { waitUntil: 'networkidle' });
await page.waitForTimeout(2500);

const enable = page.locator('flt-semantics-placeholder, [aria-label="Enable accessibility"]');
if (await enable.count()) { await enable.first().click({ force: true }); await page.waitForTimeout(600); }

const tekanPutar = async () => {
  const b = page.getByLabel(/^(Putar|Jeda)$/).last();
  await b.waitFor({ timeout: 8000 });
  await b.click({ force: true });
};

const tap = async (label) => {
  const el = page.getByText(label).last();
  await el.waitFor({ timeout: 8000 });
  await el.click({ force: true });
  await page.waitForTimeout(700);
};

try {
  for (let i = 0; i < 4; i++) {
    const l = page.getByText(/Lanjut|Selesai/).last();
    if (await l.count().catch(() => 0)) { await l.click({ force: true }).catch(() => {}); await page.waitForTimeout(500); }
  }

  const contoh = page.getByText(/Coba dengan buku contoh/i).last();
  if (await contoh.count().catch(() => 0)) await contoh.click({ force: true });
  else { await tap(/Tambah/i); await tap(/Buku contoh/i); }
  await page.waitForTimeout(1600);

  await tap(/Masukkan ke rak/i);
  await page.waitForTimeout(1200);
  await tap(/Sebuah Undangan/i);
  await page.waitForTimeout(1500);

  await page.evaluate(() => { window.__tts.spoken.length = 0; window.__tts.tumpangTindih = 0; window.__tts.maksBersamaan = 0; });

  // Mulai membaca, lalu biarkan berjalan melewati beberapa kalimat. Dengan
  // penjaga lama, tiap 4 detik pemutar maju satu kalimat padahal ucapannya
  // baru habis di detik ke-6 — tiga kalimat sudah cukup untuk terlihat.
  await tekanPutar();
  await page.waitForTimeout(DURASI_UCAP * 3 + 2000);

  const h = await page.evaluate(() => window.__tts);
  console.log('diucapkan          :', h.spoken.length, 'kalimat dalam', (DURASI_UCAP * 3 + 2000) / 1000, 'detik');
  console.log('tumpang tindih     :', h.tumpangTindih);
  console.log('paling banyak      :', h.maksBersamaan, 'ucapan berjalan bersamaan');
  console.log('');

  if (h.spoken.length === 0) {
    console.log('HASIL: GAGAL - tidak membacakan apa pun');
    process.exitCode = 1;
  } else if (h.tumpangTindih > 0) {
    console.log(`HASIL: GAGAL - ${h.tumpangTindih}x ucapan baru dimulai selagi yang lama masih berjalan.`);
    console.log('        Teks akan mendahului suara, dan selisihnya menumpuk.');
    process.exitCode = 1;
  } else {
    console.log('HASIL: LOLOS - tidak ada ucapan yang tumpang tindih.');
    console.log('        Pemutar menunggu suaranya benar-benar habis, bukan menebak.');
  }
  await b.close();
} catch (e) {
  console.log('GAGAL menavigasi:', e.message.slice(0, 300));
  await b.close();
  process.exit(2);
}
