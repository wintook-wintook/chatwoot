#!/usr/bin/env python3
"""Genera la versión self-contained de un .md incrustando los SVG en línea.

Las rutas relativas ![alt](img/...svg) se rompen cuando el documento se guarda en
una base de datos (proyectos.wintook.com) porque no hay contra qué resolverlas.
Este script sustituye cada referencia por el <svg> completo, de modo que el
documento viaje solo.

Hay dos modos, porque no todo lector acepta lo mismo:

  html    <p align="center"><svg …></svg></p>  → nítido y seleccionable, pero un
          sanitizador de HTML puede borrarlo entero.
  base64  ![alt](data:image/svg+xml;base64,…)  → es un ![]() de markdown normal,
          sobrevive a cualquier sanitizador; pesa ~33% más.

Uso:  python3 docs/img/contpaq-costos/build-inline.py docs/contpaq_costos_historicos.md [html|base64]
Sale: docs/contpaq_costos_historicos.inline.md   /   .b64.md
"""
import base64
import re
import sys
from pathlib import Path

IMG_RE = re.compile(r'^!\[([^\]]*)\]\(([^)]+\.svg)\)\s*$', re.MULTILINE)

SUFIJO = {'html': '.inline.md', 'base64': '.b64.md'}


def inline(md_path: Path, modo: str = 'html') -> Path:
    base = md_path.parent
    src = md_path.read_text(encoding='utf-8')

    def repl(m):
        alt, rel = m.group(1), m.group(2)
        svg_path = (base / rel).resolve()
        if not svg_path.is_file():
            raise SystemExit(f'falta el SVG: {svg_path}')
        svg = svg_path.read_text(encoding='utf-8').strip()
        # quita el prolog XML si lo hubiera; el <svg> se inserta tal cual
        svg = re.sub(r'^<\?xml[^>]*\?>\s*', '', svg)
        if modo == 'base64':
            b64 = base64.b64encode(svg.encode('utf-8')).decode('ascii')
            return f'![{alt}](data:image/svg+xml;base64,{b64})'
        # ancho fluido para que no desborde el contenedor del lector
        svg = svg.replace(
            '<svg xmlns=',
            '<svg role="img" aria-label="' + alt.replace('"', "'") + '" '
            'style="max-width:100%;height:auto" xmlns=', 1)
        return f'<p align="center">\n{svg}\n</p>'

    out = IMG_RE.sub(repl, src)
    dst = md_path.with_suffix(SUFIJO[modo])
    dst.write_text(out, encoding='utf-8')
    return dst


if __name__ == '__main__':
    if len(sys.argv) not in (2, 3):
        raise SystemExit(__doc__)
    modo = sys.argv[2] if len(sys.argv) == 3 else 'html'
    if modo not in SUFIJO:
        raise SystemExit(f'modo desconocido: {modo} (usa html o base64)')
    target = Path(sys.argv[1]).resolve()
    result = inline(target, modo)
    print(f'{result}  ({result.stat().st_size / 1024:.1f} KB)')
