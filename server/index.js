// Perantara ke Google Cloud TTS.
//
// Ada karena satu alasan: KUNCI TIDAK BOLEH ADA DI DALAM APK. Siapa pun yang
// memegang APK bisa mengekstrak kuncinya dan memakainya atas tagihanmu. Di
// sini kuncinya tinggal di server, dan app hanya tahu alamat ini.
//
// Tugasnya cuma tiga: memeriksa pemanggilnya berhak, menjaga pagu biaya, lalu
// meneruskan ke Google. Sengaja tidak lebih dari itu.

const express = require('express');

const app = express();
app.use(express.json({ limit: '256kb' }));

const KEY = process.env.GOOGLE_TTS_API_KEY;
const SECRET = process.env.BACAIN_SHARED_SECRET;

// Pagu karakter GLOBAL per hari, untuk seluruh pemakai layanan ini.
// Ini killswitch, bukan mekanik produk: satu bug perulangan di app bisa
// menghabiskan kuota gratis — bahkan menembusnya — dalam semalam.
const MAX_CHARS_PER_DAY = Number(process.env.BACAIN_MAX_CHARS_PER_DAY || 500000);

const GOOGLE = 'https://texttospeech.googleapis.com/v1';

// Penghitung ini hilang saat instance dingin dimulai ulang, jadi pagunya
// bersifat usaha-terbaik. Penjaga yang sesungguhnya adalah Budget Alert di
// Google Cloud Console — pasang itu, jangan hanya mengandalkan angka ini.
let hari = '';
let terpakai = 0;

function hariIni() {
  return new Date().toISOString().slice(0, 10);
}

function pakai(chars) {
  const h = hariIni();
  if (h !== hari) {
    hari = h;
    terpakai = 0;
  }
  if (terpakai + chars > MAX_CHARS_PER_DAY) return false;
  terpakai += chars;
  return true;
}

app.use((req, res, next) => {
  // Build web dilayani dari domain lain, jadi CORS perlu dibuka.
  res.set('Access-Control-Allow-Origin', process.env.BACAIN_ALLOW_ORIGIN || '*');
  res.set('Access-Control-Allow-Headers', 'Content-Type, X-Bacain-Secret');
  if (req.method === 'OPTIONS') return res.status(204).end();

  if (!KEY) {
    return res.status(500).json({
      error: { message: 'GOOGLE_TTS_API_KEY belum dipasang di server.' },
    });
  }
  // Tanpa ini alamatnya jadi layanan TTS gratis untuk siapa pun yang
  // menemukannya — dan tagihannya tetap atas namamu.
  // Diterima lewat header ATAU parameter `?s=`. Yang kedua membuat alamatnya
  // bisa ditempel apa adanya ke Pengaturan, tanpa kolom tambahan di app.
  const dikirim = req.get('X-Bacain-Secret') || req.query.s;
  if (SECRET && dikirim !== SECRET) {
    return res.status(403).json({ error: { message: 'Tidak berhak.' } });
  }
  next();
});

app.get('/voices', async (req, res) => {
  const lang = req.query.languageCode || 'id-ID';
  try {
    const r = await fetch(`${GOOGLE}/voices?languageCode=${encodeURIComponent(lang)}&key=${KEY}`);
    res.status(r.status).json(await r.json());
  } catch (e) {
    res.status(502).json({ error: { message: String(e) } });
  }
});

app.post('/text:synthesize', async (req, res) => {
  const text = req.body?.input?.text ?? '';
  if (!text) {
    return res.status(400).json({ error: { message: 'Teks kosong.' } });
  }

  if (!pakai(text.length)) {
    return res.status(429).json({
      error: {
        message: `Pagu harian layanan ini habis (${MAX_CHARS_PER_DAY} karakter).`,
      },
    });
  }

  try {
    const r = await fetch(`${GOOGLE}/text:synthesize?key=${KEY}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(req.body),
    });
    res.status(r.status).json(await r.json());
  } catch (e) {
    res.status(502).json({ error: { message: String(e) } });
  }
});

app.get('/', (_req, res) =>
  res.json({ ok: true, terpakaiHariIni: terpakai, pagu: MAX_CHARS_PER_DAY }));

const port = process.env.PORT || 8080;
app.listen(port, () => console.log(`Bacain TTS di :${port}`));
