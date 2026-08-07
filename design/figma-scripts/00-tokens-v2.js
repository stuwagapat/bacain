// Bacain · 00 — Token v2 (hasil audit Hallmark)
// Menerapkan ramp netral hangat, tinta merek, aksen terakota, dan text style
// dengan pasangan Literata + Plus Jakarta Sans.
//
// Aman diulang. TIDAK menghapus text style v1 — frame v1 masih memakainya.
// Jalankan ini SEBELUM skrip 10 / 11 / 12.

const hex = (h) => { h = h.replace('#',''); const c=(i)=>parseInt(h.slice(i,i+2),16)/255;
  return { r:c(0), g:c(2), b:c(4) }; };

// ── 1 · Nilai warna primitif ────────────────────────────────────
const cols = await figma.variables.getLocalVariableCollectionsAsync();
const prim = cols.find(c => c.name === '1. Primitives');
if (!prim) throw new Error('Koleksi "1. Primitives" tidak ditemukan.');
const pmode = prim.modes[0].modeId;
const PV = {};
for (const v of await figma.variables.getLocalVariablesAsync('COLOR'))
  if (v.variableCollectionId === prim.id) PV[v.name] = v;

const NEW = {
  // Netral SENGAJA condong hangat. Tidak ada #ffffff / #000000 —
  // abu-abu netral sempurna terbaca sintetis (anti-pattern bernama).
  'neutral/0':'#fffefc','neutral/50':'#faf8f5','neutral/100':'#f3f1ed','neutral/200':'#e6e2dc',
  'neutral/300':'#d3cec6','neutral/400':'#a5a099','neutral/500':'#78736c','neutral/600':'#57534c',
  'neutral/700':'#423f39','neutral/800':'#2a2724','neutral/900':'#1a1816','neutral/1000':'#0e0d0c',
  // Tinta hangat — tombol utama terbaca seperti teks tercetak, bukan tombol SaaS.
  'brand/100':'#e8e3dd','brand/300':'#9a9086','brand/500':'#3b342c','brand/700':'#262019','brand/900':'#14100c',
  // Terakota — SATU-SATUNYA hue kromatik di luar status.
  'accent/100':'#f7e9e2','accent/300':'#e0ae97','accent/500':'#b5623f','accent/700':'#7e4029','accent/900':'#4a2517',
  // Sampul: tanah, indigo, lumut — bukan pastel generik.
  'cover/1':'#7d5a43','cover/2':'#3f4f63','cover/3':'#5b6b4a','cover/4':'#8a5c52',
  'cover/5':'#4a4459','cover/6':'#8a7248','cover/7':'#456063','cover/8':'#6b4f5e'
};
const touched = [];
for (const n of Object.keys(NEW)) {
  if (!PV[n]) continue;
  PV[n].setValueForMode(pmode, hex(NEW[n]));
  touched.push(PV[n].id);
}
if (PV['neutral/0'])    PV['neutral/0'].description    = 'Putih hangat, BUKAN #ffffff. Putih murni terbaca sintetis.';
if (PV['neutral/1000']) PV['neutral/1000'].description = 'Nyaris hitam hangat, BUKAN #000000.';
if (PV['accent/500'])   PV['accent/500'].description   = 'Terakota — satu-satunya hue kromatik di sistem ini, di luar status.';

// ── 2 · Resolusi typeface (tahan beda penamaan style) ───────────
const all = await figma.listAvailableFontsAsync();
const stylesOf = (fam) => all.filter(f => f.fontName.family === fam).map(f => f.fontName.style);
const resolve = (fams, wanted) => {
  for (const fam of fams) {
    const s = stylesOf(fam);
    if (!s.length) continue;
    for (const w of wanted) if (s.includes(w)) return { family: fam, style: w };
    return { family: fam, style: s.includes('Regular') ? 'Regular' : s[0] };
  }
  throw new Error('Tidak ada typeface yang cocok: ' + fams.join(', '));
};
const READ = ['Literata', 'Source Serif 4', 'Georgia', 'Inter'];
const UI   = ['Plus Jakarta Sans', 'Inter'];

const R_reg = resolve(READ, ['Regular']);
const R_sb  = resolve(READ, ['SemiBold', 'Semi Bold', 'Medium', 'Bold']);
const U_reg = resolve(UI,   ['Regular']);
const U_sb  = resolve(UI,   ['SemiBold', 'Semi Bold', 'Bold', 'Medium']);
for (const f of [R_reg, R_sb, U_reg, U_sb]) await figma.loadFontAsync(f);

// ── 3 · Text style v2 (upsert berdasarkan nama) ─────────────────
// Skala baca line-height longgar (±1,7) — teks ini dipandangi 15 menit.
const SPEC = [
  ['Reading/DisplayXL',  R_sb,  82, 82, -3.7, 'Angka jam di layar 02. Jamnya sendiri yang jadi elemen terbesar.'],
  ['Reading/Display',    R_sb,  44, 48, -1.3, 'Momen "18 hari mendengar" — satu-satunya kalimat yang menjelaskan app ini serial harian.'],
  ['Reading/Headline',   R_sb,  34, 38, -0.7, 'Judul layar bertipografi kuat (01, 10).'],
  ['Reading/Title',      R_sb,  26, 31, -0.4, 'Judul buku & judul layar sedang.'],
  ['Reading/TitleSmall', R_sb,  20, 25,    0, 'Judul bab.'],
  ['Reading/BodyLarge',  R_reg, 21, 36,    0, 'Teks recap & opsi huruf besar.'],
  ['Reading/Body',       R_reg, 18, 31,    0, 'Teks berjalan di player.'],
  ['Reading/Quote',      R_reg, 23, 37,    0, 'Kalimat tunggal di mode fokus.'],
  ['UI/Label',           U_sb, 14.5, 20, 0.1, 'Teks tombol & tautan.'],
  ['UI/Body',            U_reg,14.5, 22,   0, 'Teks antarmuka umum.'],
  ['UI/Small',           U_reg,12.5, 18,   0, 'Keterangan sekunder.'],
  ['UI/Micro',           U_reg,11.5, 16,   0, 'Metadata, keterangan kaki.'],
  ['UI/Group',           U_sb,   11, 15, 1.0, 'Judul grup — HURUF BESAR. Dipakai hemat: audit menemukan tik eyebrow di v1.']
];

const existing = {};
for (const s of await figma.getLocalTextStylesAsync()) existing[s.name] = s;

const styleIds = {};
for (const [name, font, size, lh, ls, desc] of SPEC) {
  const s = existing[name] || figma.createTextStyle();
  s.name = name;
  s.fontName = font;
  s.fontSize = size;
  s.lineHeight = { unit: 'PIXELS', value: lh };
  s.letterSpacing = { unit: 'PIXELS', value: ls };
  s.description = desc + ' [' + font.family + ' ' + font.style + ']';
  styleIds[name] = s.id;
}

return {
  primitivesUpdated: touched.length,
  fontsResolved: { reading: R_reg.family, readingBold: R_sb.style, ui: U_reg.family, uiBold: U_sb.style },
  textStyles: Object.keys(styleIds).length,
  note: stylesOf('Literata').length && stylesOf('Plus Jakarta Sans').length
    ? 'Kedua typeface tersedia.'
    : 'PERINGATAN: Literata dan/atau Plus Jakarta Sans tidak ada di Figma-mu — dipakai pengganti. Aktifkan lewat Google Fonts di Figma.'
};
