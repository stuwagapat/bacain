// Bacain — wireframe 11 (Pengaturan) & 12 (kartu Notifikasi harian).
// Jalankan lewat use_figma pada file 509ex6znf0rrktS8oouOwd. Aman diulang.

for (const s of ['Regular', 'Semi Bold', 'Bold']) await figma.loadFontAsync({ family: 'Inter', style: s });
const page = figma.root.children.find(p => p.name === 'Wireframes');
await figma.setCurrentPageAsync(page);

const cols = await figma.variables.getLocalVariableCollectionsAsync();
const lc = cols.find(c => c.name === '2. Color · Light').id;
const pc = cols.find(c => c.name === '1. Primitives').id;
const CV = {}, PV = {};
for (const v of await figma.variables.getLocalVariablesAsync('COLOR')) {
  if (v.variableCollectionId === lc) CV[v.name] = v;
  if (v.variableCollectionId === pc) PV[v.name] = v;
}
const TS = {};
(await figma.getLocalTextStylesAsync()).forEach(s => { TS[s.name] = s; });

const mk = (m, n) => figma.variables.setBoundVariableForPaint(
  { type: 'SOLID', color: { r: 0, g: 0, b: 0 } }, 'color', m[n]);
const P = (n) => mk(CV, n), Pp = (n) => mk(PV, n);
// box() SELALU mengosongkan fills — frame Figma default-nya putih.
const box = (d, p) => { const f = figma.createAutoLayout(d, p || {}); f.fills = []; return f; };
const add = (p, n, hug) => {
  p.appendChild(n);
  if (n.type === 'TEXT') n.textAutoResize = 'HEIGHT';
  if (!hug) n.layoutSizingHorizontal = 'FILL';
  return n;
};
const txt = async (st, c, col) => {
  const t = figma.createText(); t.characters = c;
  await t.setTextStyleIdAsync(TS[st].id);
  if (col) t.fills = [P(col)];
  return t;
};
const toggle = (on) => {
  const t = figma.createFrame();
  t.name = 'Toggle'; t.resize(44, 26); t.cornerRadius = 999;
  t.fills = [P(on ? 'brand/primary' : 'border/default')];
  const k = figma.createEllipse(); k.resize(20, 20);
  k.fills = [P('bg/surface')];
  t.appendChild(k); k.x = on ? 21 : 3; k.y = 3;
  return t;
};

// ─── 11 · Pengaturan ───────────────────────────────────────────
const s11 = box('VERTICAL', { name: '11 · Pengaturan', x: 5280, y: 0 });
s11.fills = [P('bg/base')]; s11.resize(360, 800);
s11.primaryAxisSizingMode = 'FIXED'; s11.counterAxisSizingMode = 'FIXED'; s11.clipsContent = true;
s11.paddingLeft = 16; s11.paddingRight = 16; s11.paddingTop = 16; s11.paddingBottom = 24;
s11.itemSpacing = 24;

const bar11 = box('HORIZONTAL', { itemSpacing: 12, counterAxisAlignItems: 'CENTER' });
add(s11, bar11);
add(bar11, await txt('UI/Title', '←', 'text/primary'), true);
add(bar11, await txt('UI/TitleSmall', 'Pengaturan', 'text/primary'), true);

// [judul seksi, [label, nilai, tipe]]  — tipe: 'nav' | 'on' | 'off'
const SECTIONS = [
  ['KEBIASAAN', [
    ['Pengingat harian', '07.00', 'nav'],
    ['Notifikasi', '', 'on']
  ]],
  ['SUARA', [
    ['Suara pembaca', 'Ayu', 'nav'],
    ['Kecepatan', '1.0×', 'nav']
  ]],
  ['PENYIMPANAN', [
    ['Unduh otomatis', '', 'on'],
    ['Kelola unduhan', '124 MB', 'nav']
  ]],
  ['AKUN', [
    ['Amankan progres', 'Masuk dengan Google', 'nav']
  ]],
  ['', [
    ['Tentang Bacain', '', 'nav']
  ]]
];

for (const [heading, rows] of SECTIONS) {
  const sec = box('VERTICAL', { itemSpacing: 8, name: heading || 'Lainnya' });
  add(s11, sec);
  if (heading) add(sec, await txt('UI/Caption', heading, 'text/secondary'));

  const group = box('VERTICAL', { itemSpacing: 0 });
  group.fills = [P('bg/surface')];
  group.strokes = [P('border/default')]; group.strokeWeight = 1;
  group.cornerRadius = 16;
  group.paddingLeft = 14; group.paddingRight = 14;
  add(sec, group);

  for (let i = 0; i < rows.length; i++) {
    const [label, value, kind] = rows[i];
    const r = box('HORIZONTAL', {
      itemSpacing: 12, counterAxisAlignItems: 'CENTER',
      paddingTop: 14, paddingBottom: 14, name: label
    });
    add(group, r);
    const lt = await txt('UI/Body', label, 'text/primary');
    add(r, lt); lt.layoutGrow = 1;
    if (kind === 'nav') {
      if (value) add(r, await txt('UI/BodySmall', value, 'text/secondary'), true);
      add(r, await txt('UI/BodySmall', '›', 'text/disabled'), true);
    } else {
      r.appendChild(toggle(kind === 'on'));
    }
    if (i < rows.length - 1) {
      const line = figma.createRectangle();
      line.resize(100, 1); line.fills = [P('border/default')]; line.name = 'Garis';
      add(group, line);
    }
  }
}

// ─── 12 · Notifikasi harian ────────────────────────────────────
const s12 = box('VERTICAL', { name: '12 · Notifikasi harian', x: 5720, y: 0, itemSpacing: 12 });
s12.fills = [P('bg/surfaceVariant')];
s12.resize(360, 240);
s12.primaryAxisSizingMode = 'FIXED'; s12.counterAxisSizingMode = 'FIXED';
s12.paddingLeft = 16; s12.paddingRight = 16; s12.paddingTop = 16; s12.paddingBottom = 16;
s12.clipsContent = true;

const card = box('VERTICAL', {
  itemSpacing: 6, name: 'Kartu notifikasi',
  paddingLeft: 14, paddingRight: 14, paddingTop: 12, paddingBottom: 12
});
card.fills = [P('bg/surface')]; card.cornerRadius = 20;
add(s12, card);

const top = box('HORIZONTAL', { itemSpacing: 8, counterAxisAlignItems: 'CENTER' });
add(card, top);
// Ikon notifikasi Android WAJIB siluet putih polos di atas transparan — butuh aset khusus,
// bukan logo berwarna. Kotak ini penampungnya.
const ni = figma.createRectangle();
ni.resize(18, 18); ni.cornerRadius = 4; ni.fills = [P('text/secondary')];
ni.name = 'Ikon notifikasi (siluet monokrom)';
top.appendChild(ni);
const app = await txt('UI/Caption', 'Bacain', 'text/secondary');
add(top, app); app.layoutGrow = 1;
add(top, await txt('UI/Caption', '07.00', 'text/secondary'), true);

add(card, await txt('UI/Label', 'Bab 4 sudah siap', 'text/primary'));
add(card, await txt('UI/BodySmall', 'Dikotomi Kendali · 14 menit', 'text/secondary'));

const note = await txt('UI/Caption',
  'Butuh 8–10 varian teks. Kalimat yang sama tiap pagi selama sebulan akan berubah jadi kebisingan yang dimatikan user — dan begitu notifikasi mati, mekanik serial hariannya ikut mati.',
  'text/secondary');
add(s12, note);

return { createdNodeIds: [s11.id, s12.id] };
