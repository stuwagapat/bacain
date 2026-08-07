// Bacain · 10 — Wireframe v2, layar 01 · 02 · 03a · 03b
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

// box() SELALU mengosongkan fills — frame Figma default-nya putih.
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

// Satu suara ikon: stroke 1,5px, ujung bulat. v1 mencampur glyph teks + kotak abu-abu.
const PATH = {
  ar:'<path d="M19 12H5M11 18l-6-6 6-6"/>', cr:'<path d="M9 6l6 6-6 6"/>',
  ch:'<path d="M6 9l6 6 6-6"/>', pl:'<path d="M6 4l14 8-14 8V4z"/>',
  pa:'<path d="M8 4v16M16 4v16"/>', ck:'<path d="M4 12l5 5L20 6"/>',
  cl:'<path d="M18 6L6 18M6 6l12 12"/>', pen:'<path d="M4 20h4L20 8l-4-4L4 16v4z"/>',
  cam:'<path d="M3 8h3l2-3h8l2 3h3v12H3V8z"/><circle cx="12" cy="13" r="4"/>',
  doc:'<path d="M14 3H6v18h12V7l-4-4z"/><path d="M14 3v4h4"/>',
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

// ── 01 · Onboarding ─────────────────────────────────────────────
// Tipografi yang bekerja, bukan kotak ilustrasi. Teks menggantung di bawah-kiri.
// Tanpa tombol lebar penuh, tanpa rata tengah.
{
  const s = screen(L, '01 · Onboarding', 0);
  s.paddingLeft = 28; s.paddingRight = 28; s.paddingTop = 56; s.paddingBottom = 44;
  add(s, await T(L, 'UI/Group', 'BACAIN', 'text/secondary'));
  const sp = spacer(1); add(s, sp); sp.layoutSizingVertical = 'FILL';

  const h = await T(L, 'Reading/Headline', 'Buku yang menumpuk, akhirnya kebaca.', 'text/primary');
  add(s, h); h.resize(250, h.height);
  add(s, spacer(20), true);
  const b = await T(L, 'UI/Body', 'Foto bukumu. Tiap pagi satu bab menunggu, sepanjang perjalananmu.', 'text/secondary');
  add(s, b); b.resize(272, b.height);
  add(s, spacer(38), true);

  const foot = box('HORIZONTAL', { counterAxisAlignItems:'CENTER', itemSpacing:8 });
  add(s, foot);
  const lnk = box('HORIZONTAL', { itemSpacing:7, counterAxisAlignItems:'CENTER', paddingBottom:4 });
  lnk.strokes = [pt(L,'brand/accent')]; lnk.strokeBottomWeight = 1.5;
  lnk.strokeTopWeight = 0; lnk.strokeLeftWeight = 0; lnk.strokeRightWeight = 0;
  add(foot, lnk, true);
  add(lnk, await T(L, 'UI/Label', 'Lanjut', 'text/primary'), true);
  lnk.appendChild(icon(L, PATH.cr, 16, 'text/primary'));
  const gap = spacer(1); add(foot, gap); gap.layoutSizingHorizontal = 'FILL';
  // Indikator halaman jadi strip, bukan titik — titik adalah default.
  const dots = box('HORIZONTAL', { itemSpacing:6, counterAxisAlignItems:'CENTER' });
  add(foot, dots, true);
  dots.appendChild(rect(16, 2, L, 'brand/accent'));
  dots.appendChild(rect(6, 2, L, 'border/strong'));
  dots.appendChild(rect(6, 2, L, 'border/strong'));
  made.push(s.id);
}

// ── 02 · Pilih jam dengar ───────────────────────────────────────
// Jamnya sendiri jadi elemen terbesar — bukan dibungkus kartu picker.
{
  const s = screen(L, '02 · Pilih jam dengar', 440);
  s.paddingLeft = 28; s.paddingRight = 28; s.paddingTop = 24; s.paddingBottom = 40;
  s.appendChild(icon(L, PATH.ar, 22, 'text/primary'));
  add(s, spacer(52), true);
  add(s, await T(L, 'UI/Body', 'Kapan kamu mau dengar?', 'text/secondary'));
  add(s, spacer(6), true);

  const clock = box('HORIZONTAL', { itemSpacing:0, counterAxisAlignItems:'CENTER' });
  add(s, clock);
  add(clock, await T(L, 'Reading/DisplayXL', '07', 'text/primary'), true);
  add(clock, await T(L, 'Reading/DisplayXL', ':', 'brand/accent'), true);
  add(clock, await T(L, 'Reading/DisplayXL', '00', 'text/primary'), true);

  add(s, spacer(8), true);
  const n = await T(L, 'UI/Small', 'Tiap hari, sekali. Bisa diubah kapan saja.', 'text/secondary');
  add(s, n); n.resize(240, n.height);
  add(s, spacer(40), true);

  const presets = box('HORIZONTAL', { itemSpacing:26, paddingTop:18 });
  presets.strokes = [pt(L,'border/default')]; presets.strokeTopWeight = 1;
  presets.strokeBottomWeight = 0; presets.strokeLeftWeight = 0; presets.strokeRightWeight = 0;
  add(s, presets);
  const on = box('HORIZONTAL', { paddingBottom:4 });
  on.strokes = [pt(L,'brand/accent')]; on.strokeBottomWeight = 1.5;
  on.strokeTopWeight = 0; on.strokeLeftWeight = 0; on.strokeRightWeight = 0;
  add(presets, on, true);
  add(on, await T(L, 'UI/Label', 'Pagi', 'text/primary'), true);
  add(presets, await T(L, 'UI/Body', 'Siang', 'text/secondary'), true);
  add(presets, await T(L, 'UI/Body', 'Malam', 'text/secondary'), true);

  const sp = spacer(1); add(s, sp); sp.layoutSizingVertical = 'FILL';
  const done = box('HORIZONTAL', { itemSpacing:7, counterAxisAlignItems:'CENTER', paddingBottom:4 });
  done.strokes = [pt(L,'brand/accent')]; done.strokeBottomWeight = 1.5;
  done.strokeTopWeight = 0; done.strokeLeftWeight = 0; done.strokeRightWeight = 0;
  add(s, done, true);
  add(done, await T(L, 'UI/Label', 'Selesai', 'text/primary'), true);
  done.appendChild(icon(L, PATH.cr, 16, 'text/primary'));
  made.push(s.id);
}

// ── 03a · Beranda kosong ────────────────────────────────────────
// Dua aksi dengan BOBOT BERBEDA — bukan dua kartu ikon kembar (anti-pattern v1).
{
  const s = screen(L, '03a · Beranda kosong', 880);
  s.paddingLeft = 24; s.paddingRight = 24; s.paddingTop = 22; s.paddingBottom = 32;

  const bar = box('HORIZONTAL', { counterAxisAlignItems:'CENTER' });
  add(s, bar);
  const bn = await T(L, 'UI/Group', 'BACAIN', 'text/secondary');
  add(bar, bn); bn.layoutGrow = 1;
  bar.appendChild(icon(L, PATH.mv, 17, 'text/disabled'));
  add(s, spacer(64), true);

  const h = await T(L, 'Reading/Title', 'Raknya masih kosong.', 'text/primary');
  add(s, h); h.resize(230, h.height);
  add(s, spacer(12), true);
  const b = await T(L, 'UI/Body', 'Mulai dari buku yang paling lama kamu tunda. Satu bab dulu, tidak perlu semuanya.', 'text/secondary');
  add(s, b); b.resize(268, b.height);
  const sp = spacer(1); add(s, sp); sp.layoutSizingVertical = 'FILL';

  // Aksi utama: blok tinta pekat.
  const blk = box('VERTICAL', { paddingLeft:22, paddingRight:22, paddingTop:22, paddingBottom:24, itemSpacing:0 });
  blk.fills = [pt(L,'brand/primary')];
  add(s, blk);
  blk.appendChild(icon(L, PATH.cam, 26, 'brand/onPrimary'));
  add(blk, spacer(26), true);
  add(blk, await T(L, 'Reading/TitleSmall', 'Foto buku fisik', 'brand/onPrimary'));
  add(blk, await T(L, 'UI/Small', 'Satu bab saja sudah cukup untuk mulai', 'brand/onPrimary'));
  blk.children[blk.children.length - 1].opacity = 0.7;

  add(s, spacer(18), true);
  // Aksi sekunder: satu baris teks, bukan kartu kedua.
  const sec = box('HORIZONTAL', { itemSpacing:10, counterAxisAlignItems:'CENTER' });
  add(s, sec);
  sec.appendChild(icon(L, PATH.doc, 17, 'text/secondary'));
  const q = await T(L, 'UI/Body', 'Punya PDF atau EPUB?', 'text/secondary');
  add(sec, q); q.layoutGrow = 1;
  const pick = box('HORIZONTAL', { paddingBottom:3 });
  pick.strokes = [pt(L,'brand/accent')]; pick.strokeBottomWeight = 1.5;
  pick.strokeTopWeight = 0; pick.strokeLeftWeight = 0; pick.strokeRightWeight = 0;
  add(sec, pick, true);
  add(pick, await T(L, 'UI/Label', 'Pilih file', 'text/primary'), true);
  made.push(s.id);
}

// ── 03b · Beranda terisi ────────────────────────────────────────
// Persentase, bar progres, durasi DICABUT — diganti satu kalimat manusia.
// Rak sengaja terpotong tepi kanan untuk memberi sinyal geser.
{
  const s = screen(L, '03b · Beranda terisi', 1320);

  const top = box('VERTICAL', { paddingLeft:24, paddingRight:24, paddingTop:22 });
  add(s, top);
  const bar = box('HORIZONTAL', { counterAxisAlignItems:'CENTER' });
  add(top, bar);
  const bn = await T(L, 'UI/Group', 'BACAIN', 'text/secondary');
  add(bar, bn); bn.layoutGrow = 1;
  bar.appendChild(icon(L, PATH.mv, 17, 'text/disabled'));

  const hero = box('HORIZONTAL', { itemSpacing:18, paddingLeft:24, paddingRight:24, paddingTop:30 });
  add(s, hero);
  const cov = rect(104, 142, P, 'cover/1'); cov.cornerRadius = 2; cov.name = 'Sampul (dibangkitkan otomatis)';
  hero.appendChild(cov);
  const info = box('VERTICAL', { itemSpacing:0, paddingTop:4 });
  add(hero, info); info.layoutGrow = 1;
  add(info, await T(L, 'UI/Group', 'HARI INI', 'text/disabled'));
  add(info, spacer(7), true);
  add(info, await T(L, 'Reading/TitleSmall', 'Dikotomi Kendali', 'text/primary'));
  add(info, await T(L, 'UI/Small', 'Filosofi Teras', 'text/secondary'));
  add(info, spacer(16), true);
  const btn = box('HORIZONTAL', { itemSpacing:9, counterAxisAlignItems:'CENTER',
    paddingLeft:18, paddingRight:20, paddingTop:12, paddingBottom:12 });
  btn.fills = [pt(L,'brand/primary')]; btn.cornerRadius = 2;
  add(info, btn, true);
  btn.appendChild(icon(L, PATH.pl, 16, 'brand/onPrimary'));
  add(btn, await T(L, 'UI/Label', 'Dengarkan', 'brand/onPrimary'), true);

  const line = box('VERTICAL', { paddingLeft:24, paddingRight:24, paddingTop:16 });
  add(s, line);
  add(line, await T(L, 'UI/Small', 'Tinggal 8 bab lagi.', 'text/secondary'));

  add(s, spacer(34), true);
  const shelfHead = box('VERTICAL', { paddingLeft:24, paddingRight:24, paddingBottom:12 });
  add(s, shelfHead);
  add(shelfHead, await T(L, 'UI/Group', 'RAK KAMU', 'text/disabled'));

  const shelf = box('HORIZONTAL', { itemSpacing:12, paddingLeft:24 });
  add(s, shelf);
  for (const [title, ci] of [['Atomic Habits','cover/2'], ['Sapiens','cover/3'], ['Laut Bercerita','cover/4']]) {
    const it = box('VERTICAL', { itemSpacing:7 });
    add(shelf, it, true);
    const c = rect(88, 118, P, ci); c.cornerRadius = 2; it.appendChild(c);
    const t = await T(L, 'UI/Micro', title, 'text/secondary');
    add(it, t, true); t.resize(88, t.height);
  }
  const plus = box('VERTICAL', { primaryAxisAlignItems:'CENTER', counterAxisAlignItems:'CENTER' });
  plus.strokes = [pt(L,'border/strong')]; plus.strokeWeight = 1; plus.dashPattern = [4,4];
  add(shelf, plus, true); plus.resize(88, 118);
  plus.primaryAxisSizingMode = 'FIXED'; plus.counterAxisSizingMode = 'FIXED';
  add(plus, await T(L, 'Reading/TitleSmall', '+', 'text/disabled'), true);

  const sp = spacer(1); add(s, sp); sp.layoutSizingVertical = 'FILL';

  // Mini player: strip garis rambut, bukan kartu.
  const mini = box('HORIZONTAL', { itemSpacing:11, counterAxisAlignItems:'CENTER',
    paddingLeft:20, paddingRight:20, paddingTop:13, paddingBottom:13 });
  mini.fills = [pt(L,'player/miniBarBg')];
  mini.strokes = [pt(L,'border/default')]; mini.strokeTopWeight = 1;
  mini.strokeBottomWeight = 0; mini.strokeLeftWeight = 0; mini.strokeRightWeight = 0;
  add(s, mini);
  const mc = rect(34, 34, P, 'cover/1'); mc.cornerRadius = 2; mini.appendChild(mc);
  const mt = box('VERTICAL', { itemSpacing:1 });
  add(mini, mt); mt.layoutGrow = 1;
  add(mt, await T(L, 'UI/Label', 'Dikotomi Kendali', 'text/primary'));
  add(mt, await T(L, 'UI/Micro', 'Filosofi Teras', 'text/secondary'));
  mini.appendChild(icon(L, PATH.pa, 22, 'text/primary'));
  made.push(s.id);
}

return { createdNodeIds: made, count: made.length, page: page.name };
