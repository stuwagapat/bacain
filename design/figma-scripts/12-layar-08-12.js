// Bacain · 12 — Wireframe v2, layar 08 · 09 · 09b · 10 · 11 · 12
// Jalankan 00-tokens-v2.js dulu. Aman diulang.

// ══ preamble (identik di 10 / 11 / 12) ══════════════════════════
const TS = {};
for (const s of await figma.getLocalTextStylesAsync()) TS[s.name] = s;
const NEED = ['Reading/DisplayXL','Reading/Display','Reading/Headline','Reading/Title',
  'Reading/TitleSmall','Reading/BodyLarge','Reading/Body','Reading/Quote',
  'UI/Label','UI/Body','UI/Small','UI/Micro','UI/Group'];
for (const n of NEED) if (!TS[n]) throw new Error('Text style "' + n + '" belum ada — jalankan 00-tokens-v2.js dulu.');
const seen = new Set();
for (const n of NEED) { const f = TS[n].fontName, k = f.family + '|' + f.style;
  if (!seen.has(k)) { await figma.loadFontAsync(f); seen.add(k); } }

const cols = await figma.variables.getLocalVariableCollectionsAsync();
const cid = (nm) => (cols.find(c => c.name === nm) || {}).id;
const L = {}, D = {}, P = {};
for (const v of await figma.variables.getLocalVariablesAsync('COLOR')) {
  if (v.variableCollectionId === cid('2. Color · Light')) L[v.name] = v;
  else if (v.variableCollectionId === cid('3. Color · Dark')) D[v.name] = v;
  else if (v.variableCollectionId === cid('1. Primitives')) P[v.name] = v;
}
const pt = (M, n) => figma.variables.setBoundVariableForPaint(
  { type:'SOLID', color:{ r:0, g:0, b:0 } }, 'color', M[n]);

let page = figma.root.children.find(p => p.name === 'Wireframes v2');
if (!page) { page = figma.createPage(); page.name = 'Wireframes v2'; }
await figma.setCurrentPageAsync(page);

const box = (d, p) => { p = p || {}; if (p.itemSpacing === undefined) p.itemSpacing = 0;
  const f = figma.createAutoLayout(d, p); f.fills = []; return f; };
const add = (p, n, hug) => { p.appendChild(n);
  if (n.type === 'TEXT') n.textAutoResize = 'HEIGHT';
  if (!hug) n.layoutSizingHorizontal = 'FILL'; return n; };
const T = async (M, st, ch, col) => { const t = figma.createText(); t.characters = ch;
  await t.setTextStyleIdAsync(TS[st].id); if (col) t.fills = [pt(M, col)]; return t; };
const screen = (M, name, x) => { const old = page.children.find(c => c.name === name);
  if (old) old.remove();
  const f = box('VERTICAL', { name, x, y:0 }); f.fills = [pt(M,'bg/base')];
  f.resize(360, 800); f.primaryAxisSizingMode='FIXED'; f.counterAxisSizingMode='FIXED';
  f.clipsContent = true; return f; };
const rect = (w, h, M, tok) => { const r = figma.createRectangle(); r.resize(w, h);
  r.fills = [pt(M, tok)]; return r; };
const spacer = (h) => { const f = figma.createFrame(); f.resize(1, h); f.fills = [];
  f.name = 'jarak'; return f; };

const PATH = {
  ar:'<path d="M19 12H5M11 18l-6-6 6-6"/>', cr:'<path d="M9 6l6 6-6 6"/>',
  ch:'<path d="M6 9l6 6 6-6"/>', pl:'<path d="M6 4l14 8-14 8V4z"/>',
  pa:'<path d="M8 4v16M16 4v16"/>', cl:'<path d="M18 6L6 18M6 6l12 12"/>',
  b15:'<path d="M3 5v6h6"/><path d="M3.5 11a9 9 0 1 1 1.6 6"/>',
  f15:'<path d="M21 5v6h-6"/><path d="M20.5 11a9 9 0 1 0-1.6 6"/>',
  mv:'<circle cx="12" cy="5" r="1"/><circle cx="12" cy="12" r="1"/><circle cx="12" cy="19" r="1"/>'
};
const icon = (M, d, size, tok) => {
  const n = figma.createNodeFromSvg('<svg xmlns="http://www.w3.org/2000/svg" width="' + size +
    '" height="' + size + '" viewBox="0 0 24 24" fill="none" stroke="#000" stroke-width="1.5" ' +
    'stroke-linecap="round" stroke-linejoin="round">' + d + '</svg>');
  n.name = 'ikon';
  for (const c of n.findAll(x => 'strokes' in x)) if (c.strokes.length) c.strokes = [pt(M, tok)];
  return n;
};
// ══ akhir preamble ══════════════════════════════════════════════

const made = [];

// ── 08 · Recap ──────────────────────────────────────────────────
// v1 serba rata tengah + dekorasi waveform. Sekarang murni teks rata kiri —
// momen ini harus terbaca seperti halaman buku, bukan seperti antarmuka.
{
  const s = screen(L, '08 · Recap', 3520);
  s.paddingLeft = 30; s.paddingRight = 30; s.paddingTop = 22; s.paddingBottom = 36;
  s.appendChild(icon(L, PATH.cl, 22, 'text/secondary'));
  add(s, spacer(70), true);
  add(s, await T(L, 'UI/Group', 'SEBELUMNYA…', 'text/disabled'));
  add(s, spacer(22), true);
  add(s, await T(L, 'Reading/BodyLarge', 'Di bab lalu, penulis memperkenalkan gagasan bahwa sebagian hal ada di bawah kendali kita, dan sebagian lagi sama sekali tidak.', 'text/primary'));
  add(s, spacer(26), true);
  add(s, await T(L, 'UI/Small', 'Kamu terakhir mendengar empat hari lalu.', 'text/secondary'));

  const sp = spacer(1); add(s, sp); sp.layoutSizingVertical = 'FILL';

  const foot = box('HORIZONTAL', { itemSpacing:22, counterAxisAlignItems:'CENTER' });
  add(s, foot);
  const go = box('HORIZONTAL', { itemSpacing:9, counterAxisAlignItems:'CENTER',
    paddingLeft:18, paddingRight:22, paddingTop:14, paddingBottom:14 });
  go.fills = [pt(L,'brand/primary')]; go.cornerRadius = 2;
  add(foot, go, true);
  go.appendChild(icon(L, PATH.pl, 16, 'brand/onPrimary'));
  add(go, await T(L, 'UI/Label', 'Bab 4', 'brand/onPrimary'), true);
  add(foot, await T(L, 'UI/Body', 'Lewati', 'text/secondary'), true);
  made.push(s.id);
}

// ── 09 · Player ─────────────────────────────────────────────────
// Teks menguasai layar. Kalimat aktif ditandai PITA MELEBAR PENUH dengan rule
// aksen di kiri — bukan chip membulat, yang cuma naluri "kartu" lagi.
// Kuota dicabut dari sini: kecemasan di tempat yang salah.
{
  const s = screen(L, '09 · Player', 3960);
  s.paddingTop = 20; s.paddingBottom = 26;

  const bar = box('HORIZONTAL', { itemSpacing:12, counterAxisAlignItems:'CENTER',
    paddingLeft:22, paddingRight:22, paddingBottom:26 });
  add(s, bar);
  bar.appendChild(icon(L, PATH.ch, 22, 'text/primary'));
  const bt = await T(L, 'UI/Small', 'Dikotomi Kendali', 'text/secondary');
  add(bar, bt); bt.layoutGrow = 1;
  bar.appendChild(icon(L, PATH.mv, 17, 'text/disabled'));

  const para = box('VERTICAL', { itemSpacing:0 });
  add(s, para); para.layoutSizingVertical = 'FILL'; para.clipsContent = true;

  const past = box('VERTICAL', { paddingLeft:22, paddingRight:22 });
  add(para, past);
  add(past, await T(L, 'Reading/Body', 'Kegelisahan sering lahir dari satu sebab yang sederhana. Kita mencoba mengendalikan hal yang bukan urusan kita.', 'reading/textPast'));

  add(para, spacer(14), true);
  const now = box('VERTICAL', { paddingLeft:20, paddingRight:22, paddingTop:12, paddingBottom:12 });
  now.fills = [pt(L,'reading/highlightBg')];
  now.strokes = [pt(L,'brand/accent')]; now.strokeLeftWeight = 2;
  now.strokeTopWeight = 0; now.strokeBottomWeight = 0; now.strokeRightWeight = 0;
  add(para, now);
  add(now, await T(L, 'Reading/Body', 'Sebagian hal ada dalam kendali kita, sebagian lagi tidak sama sekali.', 'reading/textActive'));
  add(para, spacer(14), true);

  const fut = box('VERTICAL', { paddingLeft:22, paddingRight:22 });
  add(para, fut);
  add(fut, await T(L, 'Reading/Body', 'Yang bisa kita kendalikan hanyalah penilaian dan tindakan sendiri. Selebihnya — cuaca, pendapat orang, hasil akhir — berada di luar itu.', 'reading/textFuture'));

  const ctl = box('VERTICAL', { paddingLeft:22, paddingRight:22, paddingTop:20, itemSpacing:0 });
  add(s, ctl);
  const track = figma.createFrame();
  track.name = 'Scrubber'; track.resize(316, 2); track.clipsContent = true;
  track.fills = [pt(L,'progress/track')];
  const done = rect(142, 2, L, 'progress/filled');
  track.appendChild(done); done.x = 0; done.y = 0;
  add(ctl, track, true);
  add(ctl, spacer(9), true);
  const times = box('HORIZONTAL', {});
  add(ctl, times);
  const t1 = await T(L, 'UI/Micro', '6:12', 'text/disabled');
  add(times, t1); t1.layoutGrow = 1;
  const t2 = await T(L, 'UI/Micro', '14:03', 'text/disabled');
  t2.textAlignHorizontal = 'RIGHT'; add(times, t2, true);
  add(ctl, spacer(20), true);

  // Kontrol digeser asimetris ke kiri — bukan trio rata tengah.
  const row = box('HORIZONTAL', { itemSpacing:24, counterAxisAlignItems:'CENTER' });
  add(ctl, row);
  const pp = box('HORIZONTAL', { primaryAxisAlignItems:'CENTER', counterAxisAlignItems:'CENTER' });
  pp.fills = [pt(L,'player/controlBg')]; pp.cornerRadius = 999;
  row.appendChild(pp); pp.resize(58, 58);
  pp.primaryAxisSizingMode = 'FIXED'; pp.counterAxisSizingMode = 'FIXED';
  pp.appendChild(icon(L, PATH.pa, 26, 'player/controlIcon'));
  row.appendChild(icon(L, PATH.b15, 22, 'text/primary'));
  row.appendChild(icon(L, PATH.f15, 22, 'text/primary'));
  const sp = await T(L, 'UI/Micro', '1,0×', 'text/disabled');
  sp.textAlignHorizontal = 'RIGHT'; add(row, sp); sp.layoutGrow = 1;
  made.push(s.id);
}

// ── 09b · Mode fokus (gelap) ────────────────────────────────────
// Hanya kalimat yang sedang dibacakan. Latar nyaris hitam hangat, bukan #000000.
{
  const s = screen(D, '09b · Mode fokus', 4400);
  s.paddingLeft = 30; s.paddingRight = 30; s.paddingTop = 44; s.paddingBottom = 40;
  s.primaryAxisAlignItems = 'SPACE_BETWEEN';
  add(s, await T(D, 'UI/Group', 'FILOSOFI TERAS · BAB 4', 'text/disabled'));
  add(s, await T(D, 'Reading/Quote', 'Sebagian hal ada dalam kendali kita, sebagian lagi tidak sama sekali.', 'reading/textActive'));

  const bot = box('VERTICAL', { itemSpacing:0 });
  add(s, bot);
  const row = box('HORIZONTAL', { itemSpacing:26, counterAxisAlignItems:'CENTER' });
  add(bot, row);
  row.appendChild(icon(D, PATH.pa, 26, 'text/primary'));
  row.appendChild(icon(D, PATH.b15, 22, 'text/disabled'));
  row.appendChild(icon(D, PATH.f15, 22, 'text/disabled'));
  add(bot, spacer(26), true);
  const tr = figma.createFrame();
  tr.name = 'Scrubber'; tr.resize(300, 1); tr.clipsContent = true;
  tr.fills = [pt(D,'progress/track')];
  const dn = rect(135, 1, D, 'progress/filled');
  tr.appendChild(dn); dn.x = 0; dn.y = 0;
  add(bot, tr, true);
  made.push(s.id);
}

// ── 10 · Jatah habis ────────────────────────────────────────────
// Satu angka dipertahankan — yang ini pujian, bukan pengukuran.
// Kotak ilustrasi dibuang. Rata kiri, bukan rata tengah.
{
  const s = screen(L, '10 · Jatah habis', 4840);
  s.paddingLeft = 28; s.paddingRight = 28; s.paddingTop = 22; s.paddingBottom = 36;
  s.appendChild(icon(L, PATH.ar, 22, 'text/primary'));
  const sp = spacer(1); add(s, sp); sp.layoutSizingVertical = 'FILL';

  const h = await T(L, 'Reading/Headline', 'Sampai di sini dulu hari ini.', 'text/primary');
  add(s, h); h.resize(268, h.height);
  add(s, spacer(16), true);
  const b1 = await T(L, 'UI/Body', 'Kamu mendengar 32 menit hari ini. Lumayan.', 'text/secondary');
  add(s, b1); b1.resize(268, b1.height);
  add(s, spacer(8), true);
  const b2 = await T(L, 'UI/Body', 'Bab 5 sudah kami siapkan untuk besok pagi.', 'text/secondary');
  add(s, b2); b2.resize(268, b2.height);

  const sp2 = spacer(1); add(s, sp2); sp2.layoutSizingVertical = 'FILL';

  const foot = box('VERTICAL', { itemSpacing:10, paddingTop:22 });
  foot.strokes = [pt(L,'border/default')]; foot.strokeTopWeight = 1;
  foot.strokeBottomWeight = 0; foot.strokeLeftWeight = 0; foot.strokeRightWeight = 0;
  add(s, foot);
  const lnk = box('HORIZONTAL', { paddingBottom:4 });
  lnk.strokes = [pt(L,'brand/accent')]; lnk.strokeBottomWeight = 1.5;
  lnk.strokeTopWeight = 0; lnk.strokeLeftWeight = 0; lnk.strokeRightWeight = 0;
  add(foot, lnk, true);
  add(lnk, await T(L, 'UI/Label', 'Dengar ulang bab lama', 'text/primary'), true);
  add(foot, await T(L, 'UI/Micro', 'Bab yang sudah dibuat tidak memakan jatah.', 'text/disabled'));
  made.push(s.id);
}

// ── 11 · Pengaturan ─────────────────────────────────────────────
// Card-in-card dibuang — grup dipisahkan garis rambut, bukan kotak di dalam kotak.
{
  const s = screen(L, '11 · Pengaturan', 5280);
  s.paddingLeft = 22; s.paddingRight = 22; s.paddingTop = 20; s.paddingBottom = 26;

  const bar = box('HORIZONTAL', { itemSpacing:14, counterAxisAlignItems:'CENTER' });
  add(s, bar);
  bar.appendChild(icon(L, PATH.ar, 22, 'text/primary'));
  add(bar, await T(L, 'UI/Label', 'Pengaturan', 'text/primary'), true);
  add(s, spacer(34), true);

  const row = async (label, value, toggleOn) => {
    const r = box('HORIZONTAL', { counterAxisAlignItems:'CENTER', paddingTop:13, paddingBottom:13 });
    r.strokes = [pt(L,'border/default')]; r.strokeTopWeight = 1;
    r.strokeBottomWeight = 0; r.strokeLeftWeight = 0; r.strokeRightWeight = 0;
    add(s, r);
    const lt = await T(L, 'UI/Body', label, 'text/primary');
    add(r, lt); lt.layoutGrow = 1;
    if (toggleOn === undefined) {
      const vt = await T(L, 'UI/Small', value, 'text/secondary');
      vt.textAlignHorizontal = 'RIGHT'; add(r, vt, true);
    } else {
      const tg = figma.createFrame();
      tg.name = 'Toggle'; tg.resize(38, 22); tg.cornerRadius = 999;
      tg.fills = [pt(L, toggleOn ? 'brand/primary' : 'border/strong')];
      const k = figma.createEllipse(); k.resize(16, 16); k.fills = [pt(L,'bg/base')];
      tg.appendChild(k); k.x = toggleOn ? 19 : 3; k.y = 3;
      r.appendChild(tg);
    }
    return r;
  };
  const group = async (title) => {
    add(s, await T(L, 'UI/Group', title, 'text/disabled'));
    add(s, spacer(6), true);
  };

  await group('KEBIASAAN');
  await row('Pengingat harian', '07.00');
  await row('Notifikasi', null, true);
  add(s, spacer(26), true);
  await group('SUARA');
  await row('Suara pembaca', 'Ayu');
  await row('Kecepatan', '1,0×');
  // Membuat klaim aksesibilitas jadi nyata, bukan sekadar disebut.
  await row('Huruf mudah dibaca', 'Mati');
  add(s, spacer(26), true);
  await group('PENYIMPANAN');
  await row('Kelola unduhan', '124 MB');

  const sp = spacer(1); add(s, sp); sp.layoutSizingVertical = 'FILL';
  const foot = box('VERTICAL', { itemSpacing:9, paddingTop:18 });
  foot.strokes = [pt(L,'border/default')]; foot.strokeTopWeight = 1;
  foot.strokeBottomWeight = 0; foot.strokeLeftWeight = 0; foot.strokeRightWeight = 0;
  add(s, foot);
  const lnk = box('HORIZONTAL', { paddingBottom:4 });
  lnk.strokes = [pt(L,'brand/accent')]; lnk.strokeBottomWeight = 1.5;
  lnk.strokeTopWeight = 0; lnk.strokeLeftWeight = 0; lnk.strokeRightWeight = 0;
  add(foot, lnk, true);
  add(lnk, await T(L, 'UI/Label', 'Amankan progres', 'text/primary'), true);
  add(foot, await T(L, 'UI/Micro', 'Masuk dengan Google supaya progresmu tidak hilang.', 'text/disabled'));
  made.push(s.id);
}

// ── 12 · Notifikasi harian ──────────────────────────────────────
{
  const name = '12 · Notifikasi harian';
  const old = page.children.find(c => c.name === name); if (old) old.remove();
  const s = box('VERTICAL', { name, x:5720, y:0, itemSpacing:16,
    paddingLeft:20, paddingRight:20, paddingTop:24, paddingBottom:24 });
  s.fills = [pt(L,'bg/surfaceVariant')];
  s.resize(360, 220); s.counterAxisSizingMode = 'FIXED'; s.primaryAxisSizingMode = 'FIXED';
  s.clipsContent = true;

  const card = box('VERTICAL', { itemSpacing:3, paddingLeft:17, paddingRight:17,
    paddingTop:15, paddingBottom:15 });
  card.fills = [pt(L,'bg/base')];
  card.strokes = [pt(L,'border/default')]; card.strokeWeight = 1;
  add(s, card);
  const top = box('HORIZONTAL', { itemSpacing:8, counterAxisAlignItems:'CENTER', paddingBottom:5 });
  add(card, top);
  // Android mewajibkan siluet putih polos di atas transparan — aset terpisah dari logo berwarna.
  const ni = rect(15, 15, L, 'text/disabled'); ni.cornerRadius = 3;
  ni.name = 'Ikon notifikasi (siluet monokrom)';
  top.appendChild(ni);
  const app = await T(L, 'UI/Micro', 'Bacain', 'text/secondary');
  add(top, app); app.layoutGrow = 1;
  const hh = await T(L, 'UI/Micro', '07.00', 'text/disabled');
  hh.textAlignHorizontal = 'RIGHT'; add(top, hh, true);
  add(card, await T(L, 'Reading/TitleSmall', 'Dikotomi Kendali menunggu', 'text/primary'));
  add(card, await T(L, 'UI/Small', '14 menit · pas untuk perjalanan pagi', 'text/secondary'));

  add(s, await T(L, 'UI/Micro', 'Butuh 8–10 varian teks. Kalimat yang sama tiap pagi selama sebulan akan berubah jadi kebisingan yang dimatikan — dan begitu notifikasi mati, mekanik serial hariannya ikut mati.', 'text/disabled'));
  made.push(s.id);
}

return { createdNodeIds: made, count: made.length, page: page.name };
