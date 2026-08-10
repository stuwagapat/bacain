#!/usr/bin/env python3
"""Membaca design/tokens.json, menulis app/lib/ui/tokens.g.dart.

Menulis file TERPISAH dari tokens.dart supaya widget buatan tangan
(PrimaryButton, QuotaBar, dsb.) tidak pernah tertimpa.

Pakai:  python3 tools/gen_tokens.py
        python3 tools/gen_tokens.py --check     # gagal kalau keluaran basi
"""
import json, re, sys, pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / 'design' / 'tokens.json'
OUT = ROOT / 'app' / 'lib' / 'ui' / 'tokens.g.dart'

# Nama family di tokens.json -> nama family di pubspec.yaml.
# Keduanya harus cocok; kalau tidak, Flutter diam-diam jatuh ke font sistem.
FAMILY = {
    'Plus Jakarta Sans': 'Jakarta',
    'Literata': 'Literata',
    'Atkinson Hyperlegible': 'AtkinsonHyperlegible',
}


def load():
    with open(SRC) as f:
        return json.load(f)


def resolve(d, value, seen=None):
    """Telusuri alias {a.b.c} sampai ketemu nilai mentah."""
    seen = seen or set()
    while isinstance(value, str) and value.startswith('{') and value.endswith('}'):
        path = value[1:-1]
        if path in seen:
            raise SystemExit(f'alias melingkar: {path}')
        seen.add(path)
        node = d
        for part in path.split('.'):
            node = node[part]
        value = node['$value']
    return value


def walk(d, node, prefix=''):
    """Hasilkan (nama_datar, nilai_terselesaikan) untuk setiap token."""
    if isinstance(node, dict):
        if '$value' in node:
            yield prefix, resolve(d, node['$value'])
            return
        for k, v in node.items():
            if k.startswith('$'):
                continue
            yield from walk(d, v, f'{prefix}.{k}' if prefix else k)


def camel(name):
    """a/b-c -> aBC. Segmen pertama selalu huruf kecil supaya lolos lint Dart
       (UI.Display -> uiDisplay, bukan UIDisplay)."""
    parts = [p for p in re.split(r'[./\-_]', name) if p]
    head = parts[0]
    # 'UI' -> 'ui', tapi 'touchMin' tetap 'touchMin' — jangan makan camelCase
    # yang memang sudah ada di nama tokennya.
    head = head.lower() if head.isupper() else head[0].lower() + head[1:]
    return head + ''.join(p[:1].upper() + p[1:] for p in parts[1:])


def color(hexv):
    h = hexv.lstrip('#')
    if len(h) == 6:
        h = 'ff' + h
    elif len(h) == 8:          # #rrggbbaa (DTCG) -> 0xAARRGGBB (Flutter)
        h = h[6:8] + h[0:6]
    return f'Color(0x{h.upper()})'


def px(v):
    return float(str(v).replace('px', '').strip())


def main():
    d = load()
    colors = {}
    for theme in ('light', 'dark'):
        colors[theme] = {camel(n): color(v) for n, v in walk(d, d[f'color/{theme}'])}
    assert colors['light'].keys() == colors['dark'].keys(), 'nama token terang & gelap tidak sama'

    fields = sorted(colors['dark'])
    L = []
    L.append('// DIHASILKAN OTOMATIS dari design/tokens.json — jangan diedit tangan.')
    L.append('// Jalankan: python3 tools/gen_tokens.py')
    L.append('//')
    L.append('// Nama token adalah kontrak antara desain dan kode. Nilainya boleh berubah')
    L.append('// kapan saja lewat tokens.json; namanya tidak.')
    L.append('')
    L.append("import 'package:flutter/material.dart';")
    L.append('')

    # ---- warna ----
    L.append('@immutable')
    L.append('class AppColors {')
    for f in fields:
        L.append(f'  final Color {f};')
    L.append('  const AppColors({')
    for f in fields:
        L.append(f'    required this.{f},')
    L.append('  });')
    L.append('')
    for theme in ('dark', 'light'):
        L.append(f'  static const {theme} = AppColors(')
        for f in fields:
            L.append(f'    {f}: {colors[theme][f]},')
        L.append('  );')
        L.append('')
    L.append('}')
    L.append('')

    # ---- spasi, radius, ukuran ----
    # 'strip' membuang segmen pertama supaya tidak menggagap: AppRadius.md,
    # bukan AppRadius.radiusMd. Spasi dikecualikan — AppSpacing.space4 justru
    # lebih terbaca daripada AppSpacing.x4.
    for setname, cls, strip in (('spacing', 'AppSpacing', False),
                                ('radius', 'AppRadius', True),
                                ('size', 'AppSize', True)):
        L.append(f'class {cls} {{')
        L.append(f'  const {cls}._();')
        for n, v in walk(d, d[setname]):
            ident = camel(n.split('.', 1)[1] if strip and '.' in n else n)
            L.append(f'  static const {ident} = {px(v)};')
        L.append('}')
        L.append('')

    # ---- tipografi ----
    t = d['typography']
    L.append('class AppType {')
    L.append('  const AppType._();')
    for role, node in t['font']['family'].items():
        if role.startswith('$'):
            continue
        raw = node['$value']
        mapped = FAMILY.get(raw)
        if mapped is None:
            raise SystemExit(f"family '{raw}' belum dipetakan ke nama di pubspec.yaml (lihat FAMILY)")
        L.append(f"  static const {role}Family = '{mapped}';  // {raw}")
    L.append('')
    for group in ('UI', 'Reading'):
        for name, node in t[group].items():
            if name.startswith('$'):
                continue
            v = node['$value']
            fam = FAMILY[resolve(d, v['fontFamily'])]
            weight = int(resolve(d, v['fontWeight']))
            size, lh = px(v['fontSize']), px(v['lineHeight'])
            ls = px(v['letterSpacing'])
            ident = camel(f'{group}.{name}')
            L.append(f'  static const {ident} = TextStyle(')
            L.append(f"    fontFamily: '{fam}',")
            L.append(f'    fontWeight: FontWeight.w{weight},')
            L.append(f'    fontSize: {size},')
            L.append(f'    height: {round(lh / size, 3)},')
            L.append(f'    letterSpacing: {ls},')
            L.append('  );')
    L.append('}')
    L.append('')

    # ---- palet sampul ----
    covers = [color(v) for _, v in walk(d, d['primitives']['cover'])]
    L.append('/// Warna sampul untuk buku tanpa gambar sampul — hasil scan dan sebagian')
    L.append('/// besar PDF tidak punya. Dipilih dari hash judul dan SENGAJA tanpa makna:')
    L.append('/// jangan pernah dipakai untuk menandai status.')
    L.append('class AppCover {')
    L.append('  const AppCover._();')
    L.append('  static const palette = <Color>[')
    for c in covers:
        L.append(f'    {c},')
    L.append('  ];')
    L.append('')
    L.append('  /// Stabil lintas sesi dan lintas perangkat — hashCode Dart TIDAK stabil,')
    L.append('  /// jadi jumlah kode unit dipakai supaya sampul buku tidak berubah warna.')
    L.append('  static Color forTitle(String title) {')
    L.append('    var h = 0;')
    L.append('    for (final c in title.codeUnits) {')
    L.append('      h = (h * 31 + c) & 0x7fffffff;')
    L.append('    }')
    L.append('    return palette[h % palette.length];')
    L.append('  }')
    L.append('}')
    L.append('')

    out = '\n'.join(L)
    if '--check' in sys.argv:
        current = OUT.read_text() if OUT.exists() else ''
        if current != out:
            sys.exit('tokens.g.dart basi — jalankan python3 tools/gen_tokens.py')
        print('tokens.g.dart mutakhir')
        return
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(out)
    print(f'{OUT.relative_to(ROOT)} ditulis — {len(fields)} warna, {len(covers)} sampul')


if __name__ == '__main__':
    main()
