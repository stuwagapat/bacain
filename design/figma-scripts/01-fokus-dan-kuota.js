// Bacain — wireframe 09b (Player mode fokus, koleksi Dark) & 10 (Kuota habis).
// Jalankan lewat use_figma pada file 509ex6znf0rrktS8oouOwd. Aman diulang.

for (const s of ['Regular', 'Semi Bold', 'Bold']) await figma.loadFontAsync({ family: 'Inter', style: s });
const page = figma.root.children.find(p => p.name === 'Wireframes');
await figma.setCurrentPageAsync(page);

const cols = await figma.variables.getLocalVariableCollectionsAsync();
const lc = cols.find(c => c.name === '2. Color · Light').id;
const dc = cols.find(c => c.name === '3. Color · Dark').id;
const CV = {}, DV = {};
for (const v of await figma.variables.getLocalVariablesAsync('COLOR')) {
  if (v.variableCollectionId === lc) CV[v.name] = v;
  if (v.variableCollectionId === dc) DV[v.name] = v;
}
const TS = {};
(await figma.getLocalTextStylesAsync()).forEach(s => { TS[s.name] = s; });

const mk = (m, n) => figma.variables.setBoundVariableForPaint(
  { type: 'SOLID', color: { r: 0, g: 0, b: 0 } }, 'color', m[n]);
// box() SELALU mengosongkan fills — frame Figma default-nya putih dan akan menutupi latar induk.
const box = (d, p) => { const f = figma.createAutoLayout(d, p || {}); f.fills = []; return f; };
const add = (p, n, hug) => {
  p.appendChild(n);
  if (n.type === 'TEXT') n.textAutoResize = 'HEIGHT';
  if (!hug) n.layoutSizingHorizontal = 'FILL';
  return n;
};
const mkScreen = (M) => (name, x) => {
  const f = box('VERTICAL', { name, x, y: 0 });
  f.fills = [mk(M, 'bg/base')]; f.resize(360, 800);
  f.primaryAxisSizingMode = 'FIXED'; f.counterAxisSizingMode = 'FIXED'; f.clipsContent = true;
  return f;
};
const mkTxt = (M) => async (st, c, col) => {
  const t = figma.createText(); t.characters = c;
  await t.setTextStyleIdAsync(TS[st].id);
  if (col) t.fills = [mk(M, col)];
  return t;
};

// ─── 09b · Player · mode fokus (koleksi Dark) ──────────────────
const D = mkTxt(DV);
const s9b = mkScreen(DV)('09b · Player · mode fokus', 4400);
s9b.paddingLeft = 28; s9b.paddingRight = 28; s9b.paddingTop = 48; s9b.paddingBottom = 40;
s9b.itemSpacing = 32; s9b.primaryAxisAlignItems = 'SPACE_BETWEEN';

const hd9 = box('VERTICAL', { itemSpacing: 4, counterAxisAlignItems: 'CENTER' });
add(s9b, hd9);
add(hd9, await D('UI/Caption', 'FILOSOFI TERAS', 'text/secondary'), true);
add(hd9, await D('UI/BodySmall', 'Bab 4 · Dikotomi Kendali', 'text/secondary'), true);

const only = await D('Reading/BodyLarge',
  'Sebagian hal ada dalam kendali kita, sebagian lagi tidak sama sekali.', 'reading/textActive');
add(s9b, only); only.textAlignHorizontal = 'CENTER';

const bot9 = box('VERTICAL', { itemSpacing: 24 });
add(s9b, bot9);
const ct9 = box('HORIZONTAL', { itemSpacing: 32, primaryAxisAlignItems: 'CENTER', counterAxisAlignItems: 'CENTER' });
add(bot9, ct9);
add(ct9, await D('UI/Title', '↺ 15', 'text/secondary'), true);
const pp9 = box('HORIZONTAL', { primaryAxisAlignItems: 'CENTER', counterAxisAlignItems: 'CENTER' });
pp9.fills = [mk(DV, 'player/controlBg')]; pp9.cornerRadius = 999;
ct9.appendChild(pp9); pp9.resize(60, 60);
pp9.primaryAxisSizingMode = 'FIXED'; pp9.counterAxisSizingMode = 'FIXED';
add(pp9, await D('UI/Title', '▮▮', 'player/controlIcon'), true);
add(ct9, await D('UI/Title', '15 ↻', 'text/secondary'), true);

const tr9 = figma.createFrame();
tr9.name = 'Track'; tr9.resize(304, 3); tr9.cornerRadius = 999;
tr9.fills = [mk(DV, 'progress/track')];
const dn9 = figma.createRectangle(); dn9.resize(135, 3); dn9.cornerRadius = 999;
dn9.fills = [mk(DV, 'progress/filled')];
tr9.appendChild(dn9); dn9.x = 0; dn9.y = 0;
add(bot9, tr9, true);
const hint = await D('UI/Caption', 'ketuk untuk keluar dari mode fokus', 'text/disabled');
add(bot9, hint); hint.textAlignHorizontal = 'CENTER';

// ─── 10 · Kuota habis ──────────────────────────────────────────
const L = mkTxt(CV);
const s10 = mkScreen(CV)('10 · Kuota habis', 4840);
s10.paddingLeft = 28; s10.paddingRight = 28; s10.paddingTop = 16; s10.paddingBottom = 32;
s10.itemSpacing = 24; s10.primaryAxisAlignItems = 'SPACE_BETWEEN';

add(s10, await L('UI/Title', '←', 'text/primary'));

const mid10 = box('VERTICAL', { itemSpacing: 16, counterAxisAlignItems: 'CENTER' });
add(s10, mid10);
const ill10 = box('VERTICAL', { primaryAxisAlignItems: 'CENTER', counterAxisAlignItems: 'CENTER' });
ill10.fills = [mk(CV, 'bg/surfaceVariant')]; ill10.cornerRadius = 24;
add(mid10, ill10); ill10.resize(ill10.width, 160); ill10.primaryAxisSizingMode = 'FIXED';
add(ill10, await L('UI/Caption', 'ILUSTRASI GARIS FINIS', 'text/disabled'), true);

const h10 = await L('UI/Headline', 'Jatah hari ini habis', 'text/primary');
add(mid10, h10); h10.textAlignHorizontal = 'CENTER';
const p10 = await L('UI/Body', 'Kamu sudah dengar 32 menit hari ini. Lumayan!', 'text/secondary');
add(mid10, p10); p10.textAlignHorizontal = 'CENTER';

const next = box('VERTICAL', {
  itemSpacing: 4, counterAxisAlignItems: 'CENTER',
  paddingLeft: 16, paddingRight: 16, paddingTop: 14, paddingBottom: 14
});
next.cornerRadius = 16; next.fills = [mk(CV, 'bg/surfaceVariant')];
add(mid10, next);
const n1 = await L('UI/BodySmall', 'Bab 5 kami siapkan', 'text/secondary');
add(next, n1); n1.textAlignHorizontal = 'CENTER';
const n2 = await L('UI/Title', 'besok jam 07.00', 'text/primary');
add(next, n2); n2.textAlignHorizontal = 'CENTER';

const bot10 = box('VERTICAL', { itemSpacing: 14, counterAxisAlignItems: 'CENTER' });
add(s10, bot10);
// Tombol bergaris, bukan tombol utama — mendengar ulang itu jalan keluar, bukan ajakan utama.
const c10 = box('HORIZONTAL', { paddingTop: 15, paddingBottom: 15, primaryAxisAlignItems: 'CENTER' });
c10.cornerRadius = 16; c10.strokes = [mk(CV, 'border/strong')]; c10.strokeWeight = 1;
add(bot10, c10);
add(c10, await L('UI/Label', 'Dengar ulang bab lama', 'text/primary'), true);
const free = await L('UI/Caption', 'Bab yang sudah dibuat tidak memakan kuota.', 'text/secondary');
add(bot10, free); free.textAlignHorizontal = 'CENTER';
add(bot10, await L('UI/Label', 'Tutup', 'text/secondary'), true);

return { createdNodeIds: [s9b.id, s10.id] };
