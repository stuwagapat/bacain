// Bacain · 11 — Wireframe v2, layar 04 · 05 · 06 · 07
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
  pa:'<path d="M8 4v16M16 4v16"/>', ck:'<path d="M4 12l5 5L20 6"/>',
  cl:'<path d="M18 6L6 18M6 6l12 12"/>', pen:'<path d="M4 20h4L20 8l-4-4L4 16v4z"/>',
  cam:'<path d="M3 8h3l2-3h8l2 3h3v12H3V8z"/><circle cx="12" cy="13" r="4"/>',
  doc:'<path d="M14 3H6v18h12V7l-4-4z"/><path d="M14 3v4h4"/>',
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

// ── 04 · Tambah buku (sheet) ────────────────────────────────────
// Dua opsi dengan bobot berbeda, bukan tiga baris kembar.
// Baris "segera hadir" dibuang — placeholder mati itu kebisingan di wireframe.
{
  const name = '04 · Tambah buku';
  const old = page.children.find(c => c.name === name); if (old) old.remove();
  const s = figma.createFrame();
  s.name = name; s.x = 1760; s.y = 0; s.resize(360, 800);
  s.clipsContent = true; s.fills = [pt(L,'bg/surfaceVariant')];

  const dim = rect(360, 800, L, 'bg/scrim');
  s.appendChild(dim); dim.x = 0; dim.y = 0; dim.name = 'Scrim';

  const sheet = box('VERTICAL', { itemSpacing:0, paddingLeft:24, paddingRight:24,
    paddingTop:26, paddingBottom:30 });
  sheet.fills = [pt(L,'bg/base')];
  s.appendChild(sheet);
  sheet.resize(360, sheet.height); sheet.counterAxisSizingMode = 'FIXED';

  const grabWrap = box('HORIZONTAL', { primaryAxisAlignItems:'CENTER', paddingBottom:24 });
  add(sheet, grabWrap);
  const grab = rect(34, 3, L, 'border/strong'); grab.cornerRadius = 999; grabWrap.appendChild(grab);

  add(sheet, await T(L, 'Reading/TitleSmall', 'Tambah buku', 'text/primary'));
  add(sheet, spacer(22), true);

  // Opsi utama — berat.
  const a = box('HORIZONTAL', { itemSpacing:15, paddingBottom:22 });
  add(sheet, a);
  a.appendChild(icon(L, PATH.cam, 26, 'text/primary'));
  const at = box('VERTICAL', { itemSpacing:3 });
  add(a, at); at.layoutGrow = 1;
  add(at, await T(L, 'Reading/TitleSmall', 'Foto buku fisik', 'text/primary'));
  add(at, await T(L, 'UI/Small', 'Scan satu bab, ±1 menit', 'text/secondary'));
  a.appendChild(icon(L, PATH.cr, 16, 'text/disabled'));

  const hr = rect(312, 1, L, 'border/default'); add(sheet, hr, true);

  // Opsi sekunder — ringan.
  const b = box('HORIZONTAL', { itemSpacing:15, counterAxisAlignItems:'CENTER', paddingTop:20 });
  add(sheet, b);
  b.appendChild(icon(L, PATH.doc, 17, 'text/secondary'));
  const bt = await T(L, 'UI/Body', 'Pilih file PDF atau EPUB', 'text/primary');
  add(b, bt); bt.layoutGrow = 1;
  b.appendChild(icon(L, PATH.cr, 16, 'text/disabled'));

  sheet.x = 0; sheet.y = 800 - sheet.height;
  made.push(s.id);
}

// ── 05 · Tinjau hasil scan ──────────────────────────────────────
// Foto memenuhi lebar layar penuh — memecah irama kotak-berpadding.
{
  const s = screen(L, '05 · Tinjau hasil scan', 2200);

  const bar = box('HORIZONTAL', { itemSpacing:14, counterAxisAlignItems:'CENTER',
    paddingLeft:20, paddingRight:20, paddingTop:20, paddingBottom:16 });
  add(s, bar);
  bar.appendChild(icon(L, PATH.ar, 22, 'text/primary'));
  const bt = await T(L, 'UI/Label', 'Periksa hasil', 'text/primary');
  add(bar, bt); bt.layoutGrow = 1;
  const pg = await T(L, 'UI/Micro', '3 / 12', 'text/disabled');
  pg.textAlignHorizontal = 'RIGHT';
  add(bar, pg, true);

  const photo = box('VERTICAL', { primaryAxisAlignItems:'CENTER', counterAxisAlignItems:'CENTER' });
  photo.fills = [pt(L,'bg/surfaceVariant')];
  photo.strokes = [pt(L,'border/default')];
  photo.strokeTopWeight = 1; photo.strokeBottomWeight = 1;
  photo.strokeLeftWeight = 0; photo.strokeRightWeight = 0;
  add(s, photo); photo.resize(360, 236); photo.primaryAxisSizingMode = 'FIXED';
  add(photo, await T(L, 'UI/Micro', 'FOTO HALAMAN', 'text/disabled'), true);

  const body = box('VERTICAL', { paddingLeft:20, paddingRight:20, paddingTop:22, itemSpacing:0 });
  add(s, body);
  add(body, await T(L, 'Reading/Body', 'Manusia adalah makhluk sosial yang tidak bisa hidup sendiri. Ia tumbuh dari perjumpaan, bukan dari kesendirian.', 'text/primary'));
  add(body, spacer(18), true);
  // Peringatan OCR jadi satu baris beraksen, bukan chip berlatar kuning.
  const warn = box('HORIZONTAL', { itemSpacing:8, counterAxisAlignItems:'CENTER' });
  add(body, warn);
  warn.appendChild(icon(L, PATH.pen, 17, 'brand/accent'));
  add(warn, await T(L, 'UI/Label', '2 kata mungkin keliru — ketuk untuk perbaiki', 'brand/accent'), true);

  const sp = spacer(1); add(s, sp); sp.layoutSizingVertical = 'FILL';

  const foot = box('HORIZONTAL', { counterAxisAlignItems:'CENTER',
    paddingLeft:20, paddingRight:20, paddingBottom:26 });
  add(s, foot);
  const del = await T(L, 'UI/Body', 'Hapus halaman', 'text/secondary');
  add(foot, del); del.layoutGrow = 1;
  const nx = box('HORIZONTAL', { paddingLeft:22, paddingRight:22, paddingTop:14, paddingBottom:14 });
  nx.fills = [pt(L,'brand/primary')]; nx.cornerRadius = 2;
  add(foot, nx, true);
  add(nx, await T(L, 'UI/Label', 'Lanjut', 'brand/onPrimary'), true);
  made.push(s.id);
}

// ── 06 · Konfirmasi buku ────────────────────────────────────────
// "18 hari mendengar" naik ke skala display — satu-satunya kalimat
// yang menjelaskan bahwa app ini serial harian.
{
  const s = screen(L, '06 · Konfirmasi buku', 2640);
  s.paddingLeft = 26; s.paddingRight = 26; s.paddingTop = 20; s.paddingBottom = 32;
  s.appendChild(icon(L, PATH.ar, 22, 'text/primary'));
  add(s, spacer(44), true);
  add(s, await T(L, 'UI/Small', 'Filosofi Teras · 12 bab', 'text/secondary'));
  add(s, spacer(10), true);
  add(s, await T(L, 'Reading/Display', '18 hari', 'text/primary'));
  add(s, await T(L, 'Reading/Title', 'mendengar', 'text/secondary'));
  add(s, spacer(14), true);
  const b = await T(L, 'UI/Body', 'Satu bab tiap pagi jam 07.00. Kalau sedang senggang, boleh lanjut.', 'text/secondary');
  add(s, b); b.resize(276, b.height);

  const sp = spacer(1); add(s, sp); sp.layoutSizingVertical = 'FILL';

  add(s, await T(L, 'UI/Group', 'SUARA PEMBACA', 'text/disabled'));
  add(s, spacer(14), true);
  const voices = box('HORIZONTAL', { itemSpacing:10, counterAxisAlignItems:'CENTER' });
  add(s, voices);
  const v1 = box('HORIZONTAL', { paddingLeft:16, paddingRight:16, paddingTop:9, paddingBottom:9 });
  v1.fills = [pt(L,'brand/primary')]; v1.cornerRadius = 2;
  add(voices, v1, true);
  add(v1, await T(L, 'UI/Label', 'Ayu', 'brand/onPrimary'), true);
  const v2 = box('HORIZONTAL', { paddingLeft:16, paddingRight:16, paddingTop:9, paddingBottom:9 });
  v2.strokes = [pt(L,'border/strong')]; v2.strokeWeight = 1; v2.cornerRadius = 2;
  add(voices, v2, true);
  add(v2, await T(L, 'UI/Body', 'Bima', 'text/primary'), true);
  const sm = await T(L, 'UI/Small', 'Dengar contoh', 'text/secondary');
  sm.textAlignHorizontal = 'RIGHT';
  add(voices, sm); sm.layoutGrow = 1;

  add(s, spacer(26), true);
  const cta = box('HORIZONTAL', { primaryAxisAlignItems:'CENTER', paddingTop:14, paddingBottom:14 });
  cta.fills = [pt(L,'brand/primary')]; cta.cornerRadius = 2;
  add(s, cta);
  add(cta, await T(L, 'UI/Label', 'Masukkan ke rak', 'brand/onPrimary'), true);
  made.push(s.id);
}

// ── 07 · Detail buku ────────────────────────────────────────────
// Sampul memenuhi tepi atas seperti poster. Bar progres & persentase dibuang —
// bab berjalan ditandai rule aksen di kiri, bukan kotak berlatar.
{
  const s = screen(L, '07 · Detail buku', 3080);

  const cov = box('VERTICAL', {});
  cov.fills = [pt(P,'cover/1')];
  add(s, cov); cov.resize(360, 186); cov.primaryAxisSizingMode = 'FIXED';
  const back = icon(L, PATH.ar, 22, 'brand/onPrimary');
  s.appendChild(back); back.x = 20; back.y = 20;
  const more = icon(L, PATH.mv, 17, 'brand/onPrimary');
  s.appendChild(more); more.x = 323; more.y = 23;

  const head = box('VERTICAL', { paddingLeft:22, paddingRight:22, paddingTop:20, itemSpacing:0 });
  add(s, head);
  add(head, await T(L, 'Reading/Title', 'Filosofi Teras', 'text/primary'));
  add(head, await T(L, 'UI/Small', 'Henry Manampiring', 'text/secondary'));
  add(head, spacer(18), true);
  add(head, await T(L, 'UI/Body', 'Kamu di bab 4. Tinggal 8 bab lagi.', 'text/primary'));
  add(head, spacer(20), true);

  const list = box('VERTICAL', { paddingLeft:22, paddingRight:22, itemSpacing:0 });
  add(s, list);
  const CH = [
    ['Sebuah Undangan', 'done'], ['Sekelumit Filsafat', 'done'],
    ['Hidup Selaras Alam', 'done'], ['Dikotomi Kendali', 'now'],
    ['Memperjelas Nilai', 'next'], ['Hidup Berkebajikan', 'next']
  ];
  for (const [title, st] of CH) {
    const r = box('HORIZONTAL', { itemSpacing:12, counterAxisAlignItems:'CENTER',
      paddingTop: st === 'now' ? 14 : 12, paddingBottom: st === 'now' ? 14 : 12 });
    r.strokes = [pt(L, st === 'now' ? 'brand/accent' : 'border/default')];
    r.strokeTopWeight = 1; r.strokeBottomWeight = 0; r.strokeRightWeight = 0;
    r.strokeLeftWeight = st === 'now' ? 2 : 0;
    if (st === 'now') r.paddingLeft = 12;
    add(list, r);
    if (st === 'done') r.appendChild(icon(L, PATH.ck, 17, 'text/disabled'));
    if (st === 'now')  r.appendChild(icon(L, PATH.pl, 17, 'brand/accent'));
    add(r, await T(L, st === 'now' ? 'UI/Label' : 'UI/Body', title,
      st === 'done' ? 'text/disabled' : st === 'now' ? 'text/primary' : 'text/secondary'), true);
  }

  const sp = spacer(1); add(s, sp); sp.layoutSizingVertical = 'FILL';

  const mini = box('HORIZONTAL', { itemSpacing:11, counterAxisAlignItems:'CENTER',
    paddingLeft:20, paddingRight:20, paddingTop:13, paddingBottom:13 });
  mini.fills = [pt(L,'player/miniBarBg')];
  mini.strokes = [pt(L,'border/default')]; mini.strokeTopWeight = 1;
  mini.strokeBottomWeight = 0; mini.strokeLeftWeight = 0; mini.strokeRightWeight = 0;
  add(s, mini);
  const mc = rect(34, 34, P, 'cover/1'); mc.cornerRadius = 2; mini.appendChild(mc);
  const mt = await T(L, 'UI/Label', 'Dikotomi Kendali', 'text/primary');
  add(mini, mt); mt.layoutGrow = 1;
  mini.appendChild(icon(L, PATH.pa, 22, 'text/primary'));
  made.push(s.id);
}

return { createdNodeIds: made, count: made.length, page: page.name };
