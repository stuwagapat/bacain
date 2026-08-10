// Menguji bug yang dilaporkan: mengetuk kalimat di dalam pemutar membuatnya
// berhenti membaca. Mesin bicara tiruan di sini sengaja meniru DUA keanehan
// Chrome yang sungguhan:
//
//   1. cancel() TIDAK mencabut keadaan "paused".
//   2. speak() saat paused masuk antrean tapi tidak pernah berbunyi, dan
//      onend-nya juga tidak pernah datang.
//
// Tanpa perbaikan, pemutar akan tampak "memutar" tapi bisu setelah diketuk.

import { chromium } from 'playwright';

const URL = process.env.URL || 'http://127.0.0.1:8099/';

const mock = () => {
  const log = { spoken: [], events: [] };
  let speaking = false, paused = false, timer = null;

  class FakeSynth {
    get speaking() { return speaking; }
    get pending() { return false; }
    get paused() { return paused; }
    getVoices() {
      return [{ voiceURI: 'ayu', name: 'Ayu', lang: 'id-ID', default: true, localService: true }];
    }
    speak(u) {
      log.spoken.push(u.text);
      if (paused) { log.events.push('DITELAN(paused)'); return; }
      speaking = true;
      timer = setTimeout(() => {
        speaking = false;
        if (u.onend) u.onend(new Event('end'));
      }, 60);
    }
    cancel() { clearTimeout(timer); speaking = false; log.events.push('cancel'); }
    pause() { paused = true; clearTimeout(timer); speaking = false; log.events.push('pause'); }
    resume() { paused = false; log.events.push('resume'); }
  }

  Object.defineProperty(window, 'speechSynthesis', { value: new FakeSynth(), configurable: true });
  window.SpeechSynthesisUtterance = function (text) { this.text = text; this.onend = null; this.onerror = null; };
  window.__tts = log;
};

const b = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium-1194/chrome-linux/chrome' });
const page = await b.newPage();
page.on('pageerror', e => console.log('  ! pageerror:', String(e).slice(0, 200)));
await page.addInitScript(mock);
await page.goto(URL, { waitUntil: 'networkidle' });
await page.waitForTimeout(2500);

// Flutter hanya membangun pohon semantics kalau diminta.
const enable = page.locator('flt-semantics-placeholder, [aria-label="Enable accessibility"]');
if (await enable.count()) { await enable.first().click({ force: true }); await page.waitForTimeout(600); }

const tap = async (label, { exact = false } = {}) => {
  const el = page.getByText(label, { exact }).last();
  await el.waitFor({ timeout: 8000 });
  await el.click({ force: true });
  await page.waitForTimeout(700);
};

const shot = async n => page.screenshot({ path: `/tmp/claude-0/-home-user-bacain/4b328dfe-174d-5ea1-ac16-6a2dc5f31004/scratchpad/${n}.png` });

try {
  // Perkenalan → rak
  for (let i = 0; i < 4; i++) {
    const lanjut = page.getByText(/Lanjut|Selesai|Mulai/).last();
    if (await lanjut.count().catch(() => 0)) {
      await lanjut.click({ force: true }).catch(() => {});
      await page.waitForTimeout(600);
    }
  }
  await shot('01-rak');

  // Rak kosong menawarkan buku contoh langsung, tanpa lembar pilihan di
  // tengah. Kalau rak sudah terisi, jalurnya lewat petak "Tambah".
  const contoh = page.getByText(/Coba dengan buku contoh/i).last();
  if (await contoh.count().catch(() => 0)) {
    await contoh.click({ force: true });
  } else {
    await tap(/Tambah/i);
    await shot('02-sheet-sumber');
    await tap(/Buku contoh/i);
  }
  await page.waitForTimeout(1500);
  await shot('03-konfirmasi');

  await tap(/Masukkan ke rak|Simpan/i);
  await page.waitForTimeout(1200);
  await shot('04-daftar-bagian');

  // Buka bagian pertama
  await tap(/Sebuah Undangan/i);
  await page.waitForTimeout(1500);
  await shot('05-pemutar');

  const dump = async () => page.evaluate(() => window.__tts);
  const reset = async () => page.evaluate(() => { window.__tts.spoken.length = 0; window.__tts.events.length = 0; });

  const PUTAR = [640, 666];

  // 1. Putar
  await page.mouse.click(...PUTAR);
  await page.waitForTimeout(1200);
  const a = await dump();
  console.log('PUTAR  spoken=' + a.spoken.length + '  events=' + JSON.stringify(a.events.slice(0, 4)));
  if (a.spoken.length === 0) throw new Error('tombol putar tidak membacakan apa pun');

  // 2. Jeda — di sinilah Chrome menyisakan keadaan paused
  await page.mouse.click(...PUTAR);
  await page.waitForTimeout(700);
  console.log('JEDA   events=' + JSON.stringify((await dump()).events.slice(-3)));

  // 3. KETUK KALIMAT — jalur yang dilaporkan rusak
  await reset();
  await page.mouse.click(400, 336);
  await page.waitForTimeout(2000);

  const h = await dump();
  console.log('KETUK  spoken=' + JSON.stringify(h.spoken.slice(0, 2)));
  console.log('KETUK  events=' + JSON.stringify(h.events));
  await shot('06-setelah-ketuk');

  const ditelan = h.events.filter(e => e === 'DITELAN(paused)').length;
  console.log('');
  if (h.spoken.length === 0) {
    console.log('HASIL: GAGAL - mengetuk kalimat tidak memicu pembacaan sama sekali');
    process.exitCode = 1;
  } else if (ditelan > 0) {
    console.log('HASIL: GAGAL - ucapan ditelan karena mesin masih paused (' + ditelan + 'x)');
    process.exitCode = 1;
  } else {
    console.log('HASIL: LOLOS - ketuk kalimat langsung membacakan lagi, tidak ada yang ditelan');
  }
  await b.close();
} catch (e) {
  console.log('GAGAL menavigasi:', e.message.slice(0, 300));
  await shot('99-gagal');
  console.log('teks di layar:', (await page.locator('body').innerText().catch(() => '')).slice(0, 600));
  await b.close();
  process.exit(2);
}
