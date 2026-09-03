#!/usr/bin/env python3
"""Valida un Entrenamiento de Agente IA contra el contrato del motor.
Uso: python3 validar_entrenamiento.py entrenamiento.txt"""
import re, sys

RUTA_OK   = re.compile(r'^[ \t]*@ruta\([ \t]*([a-z0-9_-]+)[ \t]*(?:#([a-z0-9_]+))?[ \t]*(?::[ \t]*([^)]*))?\)[ \t]*:[ \t]*(.*)$', re.I)
RUTA_ANY  = re.compile(r'@ruta\s*\(', re.I)
DEFAULT   = re.compile(r'^[ \t]*@ruta_por_defecto[ \t]*:[ \t]*([a-z0-9_-]+)[ \t]*$', re.I)
BUSQUEDA  = re.compile(r'@buscar_predefinidas\b|@buscar_art[ií]culo\b|@buscar_foro\b|@discourse\b|\{\{doc:|\{\{hoja:', re.I)
FUENTES   = [re.compile(p, re.I) for p in (
    r'@buscar_predefinidas\b(?:\s*\([^)]*\))?', r'@buscar_art[ií]culo\b',
    r'@buscar_foro\([^)]+\)', r'@discourse\b', r'\{\{doc:[^}]+\}\}', r'\{\{hoja:[^}]+\}\}')]
FORO_MAL  = re.compile(r'@buscar_foro(?!\s*\()', re.I)
CONSULTA  = re.compile(r'\{\{consulta:', re.I)
CONOCIDAS = re.compile(r'@(?:ruta|ruta_por_defecto|buscar_predefinidas|buscar_art[ií]culo|buscar_foro|discourse|crear_ticket|estado_ticket|agendar_calendar)\b', re.I)
CUALQUIER = re.compile(r'@[a-záéíóúñ_][a-z0-9áéíóúñ_]*', re.I)
SIN_FUENTE = {'-', '–', '—', ''}

def validar(texto):
    errores, avisos = [], []
    lineas = texto.splitlines()
    rutas, default_line = {}, None

    for n, linea in enumerate(lineas, 1):
        m = RUTA_OK.match(linea)
        if RUTA_ANY.search(linea) and not m:
            errores.append((n, 'Línea @ruta mal formada (revisá paréntesis y los dos puntos finales)'))
            continue
        if not m:
            d = DEFAULT.match(linea)
            if d:
                default_line = (n, d.group(1).lower())
            elif BUSQUEDA.search(linea):
                errores.append((n, 'Directiva de búsqueda FUERA de una línea @ruta: el motor descarta todo el Entrenamiento'))
            continue

        nombre, tag, desc, cuerpo = m.group(1).lower(), m.group(2), m.group(3), m.group(4).strip()
        if nombre in rutas:
            errores.append((n, f'Rama "{nombre}" duplicada: solo se conserva la primera'))
        rutas[nombre] = True
        fuente, _, escal = cuerpo.partition('->')
        if not _:
            fuente, _, escal = cuerpo.partition('→')
        fuente, escal = fuente.strip(), escal.strip()

        encontradas = sum(1 for f in FUENTES if f.search(fuente))
        if encontradas > 1:
            errores.append((n, f'Rama "{nombre}": {encontradas} fuentes en la misma rama, solo se usa una'))
        if encontradas == 0 and fuente not in SIN_FUENTE:
            errores.append((n, f'Rama "{nombre}": "{fuente}" no es una fuente del catálogo (usá "-" si no consulta nada)'))
        if FORO_MAL.search(fuente):
            errores.append((n, f'Rama "{nombre}": @buscar_foro necesita paréntesis con el nombre exacto'))
        if escal and not re.search(r'@crear_ticket\b', escal, re.I):
            errores.append((n, f'Rama "{nombre}": después de la flecha solo se admite @crear_ticket(...)'))
        if not tag:
            avisos.append((n, f'Rama "{nombre}" sin #etiqueta: si el agente la olvida, no se dispara la automatización'))
        if not desc or not desc.strip():
            avisos.append((n, f'Rama "{nombre}" sin descripción: el clasificador no tiene con qué elegirla'))

    if rutas and CONSULTA.search(texto):
        errores.append((0, '{{consulta:}} no convive con líneas @ruta: el motor enviaría el Entrenamiento completo al cliente'))
    if rutas and not default_line:
        avisos.append((0, 'Falta @ruta_por_defecto: un mensaje que no encaje se queda sin rama'))
    if default_line and default_line[1] not in rutas:
        errores.append((default_line[0], f'@ruta_por_defecto apunta a "{default_line[1]}", que no es una rama declarada'))
    inventadas = {t.lower() for t in CUALQUIER.findall(texto) if not CONOCIDAS.match(t)}
    for t in sorted(inventadas):
        errores.append((0, f'Directiva inexistente: {t} — el motor la ignora en silencio'))
    return errores, avisos

if __name__ == '__main__':
    texto = open(sys.argv[1], encoding='utf-8').read()
    errores, avisos = validar(texto)
    for n, msg in errores: print(f'ERROR  línea {n or "-"}: {msg}')
    for n, msg in avisos:  print(f'AVISO  línea {n or "-"}: {msg}')
    if not errores and not avisos: print('OK — el Entrenamiento cumple el contrato')
    sys.exit(1 if errores else 0)
