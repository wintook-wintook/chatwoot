#!/usr/bin/env python3
"""Genera docs/diagrama_agente_ia_flujo.svg

Uso: python3 docs/diagrama_agente_ia_flujo_gen.py docs/diagrama_agente_ia_flujo.svg
"""
import sys
from xml.sax.saxutils import escape

W, H = 1240, 1790
SANS = "ui-sans-serif, system-ui, -apple-system, 'Segoe UI', sans-serif"
MONO = "ui-monospace, Menlo, Consolas, monospace"
out = []
warnings = []

C = {  # tipo: (fill, stroke, chip)
    'entrada': ('#eef2ff', '#6366f1'),
    'ruby':    ('#f1f5f9', '#94a3b8'),
    'llm':     ('#fffbeb', '#f59e0b'),
    'agenda':  ('#eff6ff', '#3b82f6'),
    'ticket':  ('#fef2f2', '#ef4444'),
    'fuente':  ('#ecfdf5', '#22c55e'),
    'redacta': ('#f5f3ff', '#8b5cf6'),
}
INK, MUTED, SOFT = '#0f172a', '#475569', '#64748b'


def width(s, size, mono=False):
    return len(s) * size * (0.61 if mono else 0.55)


def text(x, y, s, size=11, weight=None, fill=INK, mono=False, anchor=None, maxw=None):
    if maxw and width(s, size, mono) > maxw:
        warnings.append(f'{s[:50]}… ~{width(s, size, mono):.0f}px > {maxw}')
    a = f' font-weight="{weight}"' if weight else ''
    a += f' text-anchor="{anchor}"' if anchor else ''
    fam = MONO if mono else SANS
    out.append(f'<text x="{x}" y="{y}" font-family="{fam}" font-size="{size}" fill="{fill}"{a}>{escape(s)}</text>')


def rect(x, y, w, h, fill='#fff', stroke='#cbd5e1', rx=8, sw=1.2, dash=None):
    d = f' stroke-dasharray="{dash}"' if dash else ''
    out.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{rx}" fill="{fill}" stroke="{stroke}" stroke-width="{sw}"{d}/>')


def arrow(d, color='#94a3b8', sw=1.5):
    out.append(f'<path d="{d}" fill="none" stroke="{color}" stroke-width="{sw}" marker-end="url(#arr)"/>')


def section(n, y, title, sub=None):
    out.append(f'<circle cx="54" cy="{y - 5}" r="14" fill="{INK}"/>')
    text(54, y - 1, str(n), 13, 700, '#fff', anchor='middle')
    text(78, y, title, 17, 700)
    if sub:
        text(78, y + 18, sub, 11.5, fill=SOFT)


# ------------------------------------------------------------------ cabecera
out.append(f'<rect x="0" y="0" width="{W}" height="{H}" fill="#ffffff"/>')
text(40, 46, 'Agente IA — cómo procesa un mensaje', 24, 700)
text(40, 70, 'Motor: ContactTrackingResponseAnalyzerJob. Ruby decide el orden de todo; el modelo (OpenAI) solo CLASIFICA (JSON corto) y REDACTA (texto).', 12.5, fill=MUTED)
text(40, 88, 'Base: develop 0111004a · 12/11/2026 · detalle en docs/motor_agentes_ia_manual.md', 11, fill=SOFT)

# ------------------------------------------------------------------ ① prompt
section(1, 130, 'El Entrenamiento: un solo texto, dos lectores',
        'El prompt generado mezcla configuración (la lee Ruby) y prosa (la lee el modelo). Cada parte va a un lugar distinto.')

px, py, pw, ph = 40, 160, 530, 270
rect(px, py, pw, ph, '#f8fafc', '#cbd5e1', 10)
rect(px, py, pw, 30, '#e2e8f0', '#cbd5e1', 10)
out.append(f'<rect x="{px}" y="{py + 18}" width="{pw}" height="12" fill="#e2e8f0"/>')
text(px + 14, py + 20, 'Entrenamiento del Agente IA  (tracking_template → complementary_prompt)', 11, 700, maxw=pw - 20)
lines = [
    ('cfg', '@ruta(ventas #ventas: precios y planes): {{hoja:Precios}}'),
    ('cfg', '@ruta(soporte #soporte: fallas): @buscar_foro(Foro) -> @crear_ticket'),
    ('cfg', '@ruta(citas #cita: agendar visita): @agendar_calendar(duracion=60)'),
    ('cfg', '@ruta_por_defecto: ventas'),
    (None, ''),
    ('wel', '[MENSAJE DE BIENVENIDA]'),
    ('wel', '¡Hola! Soy Ana. ¿En qué le puedo ayudar?'),
    (None, ''),
    ('pro', '[ROL] Eres Ana, asesora de la empresa…'),
    ('pro', '[ALCANCE POR RAMA] VENTAS: da el precio directo…'),
    ('pro', '[ETIQUETAS] termina con #ventas, #soporte o #cita'),
    ('pro', '[ESTILO] Trate de usted. Si pide el catálogo,'),
    ('pro', 'escriba {{catalogo}} y el sistema lo adjunta.'),
]
col = {'cfg': '#4f46e5', 'wel': '#b45309', 'pro': '#6d28d9'}
ly = py + 54
spans = {}
for kind, s in lines:
    if kind:
        text(px + 24, ly, s, 10.5, fill=col[kind] if kind != 'pro' else INK, mono=True, maxw=pw - 34)
        spans.setdefault(kind, [ly, ly])[1] = ly
    ly += 17
for kind, (a, b) in spans.items():
    out.append(f'<rect x="{px + 10}" y="{a - 11}" width="4" height="{b - a + 15}" rx="2" fill="{col[kind]}"/>')

rx_ = 620
rw = 580
# R1 config
rect(rx_, 160, rw, 112, '#eef2ff', '#6366f1', 10)
text(rx_ + 16, 182, 'Ruby lo lee como CONFIGURACIÓN — nunca llega al modelo ni al cliente', 12, 700, maxw=rw - 30)
r1 = [
    ('@ruta', '→ RouteMap: rama, descripción, fuente, #etiqueta, escalamiento'),
    ('@agendar_calendar(…)', '→ CalendarOptions: duración, horario 24 h, modo tentativo'),
    ('{{hoja:}} {{doc:}} @buscar_*', '→ KnowledgeBase::Directives: UNA fuente por turno'),
    ('@crear_ticket / <PENDIENTE:>', '→ Cases (abre caso) / PendingSetup (no contesta)'),
]
yy = 203
for k, v in r1:
    text(rx_ + 16, yy, k, 10, mono=True, fill='#4f46e5')
    text(rx_ + 196, yy, v, 10.5, fill=MUTED, maxw=rw - 206)
    yy += 17
# R2 bienvenida
rect(rx_, 282, rw, 48, '#fffbeb', '#f59e0b', 10)
text(rx_ + 16, 302, '[MENSAJE DE BIENVENIDA] → WelcomeMessage', 12, 700)
text(rx_ + 16, 319, 'Se envía tal cual en el primer mensaje y se quita del prompt para que el modelo no lo repita.', 10.5, fill=MUTED, maxw=rw - 30)
# R3 prosa
rect(rx_, 340, rw, 90, '#f5f3ff', '#8b5cf6', 10)
text(rx_ + 16, 360, 'El MODELO lee solo la PROSA limpia + datos que pone el motor', 12, 700, maxw=rw - 30)
text(rx_ + 16, 378, 'Prosa (sin @ruta ni directivas): identidad, tono, alcance por rama, etiquetas, prohibiciones.', 10.5, fill=MUTED, maxw=rw - 30)
text(rx_ + 16, 395, '+ Objetivo · perfil (nota IA) · Contexto IA (800 car.) · estado de la cita · variables.', 10.5, fill=MUTED, maxw=rw - 30)
text(rx_ + 16, 412, 'Solo «ejecuta» lo que escribe: {{archivo}} → adjunto · #etiqueta → automatizaciones.', 10.5, fill=MUTED, maxw=rw - 30)

for kind, ty in (('cfg', 216), ('wel', 306), ('pro', 385)):
    a, b = spans[kind]
    sy = (a + b) // 2 - 4
    arrow(f'M{px + pw + 4},{sy} C{px + pw + 26},{sy} {rx_ - 26},{ty} {rx_ - 4},{ty}', col[kind])

# ------------------------------------------------------------------ ② cascada
section(2, 478, 'Un turno: cascada de guardias — el primer paso que contesta, corta',
        'Orden real de process_message_for_tracking y try_kbase_then_conversational. Cada fila puede responder y terminar el turno.')

# leyenda
lx = 78
for key, lab in (('ruby', 'Ruby, sin IA'), ('llm', 'LLM clasifica → JSON'), ('agenda', 'Agenda'),
                 ('ticket', 'Tickets / casos'), ('fuente', 'Fuentes (KBase)'), ('redacta', 'LLM redacta')):
    f, s = C[key]
    rect(lx, 508, 14, 14, f, s, 3, 1.5)
    text(lx + 20, 519, lab, 10.5, fill=MUTED)
    lx += 30 + width(lab, 10.5) + 14

rows = [
    ('entrada', 'Mensaje entrante → job en Sidekiq', '¿entrante? ¿con contenido? ¿el bot no contestó ya?'),
    ('ruby', 'Pidió no ser contactado (OptOut)', 'baja + cancela sus seguimientos; no contesta'),
    ('ruby', 'Un vendedor ya atiende', 'la IA no contesta (handoff)'),
    ('ruby', '<PENDIENTE:> en el Entrenamiento', 'el agente no contesta hasta completarlo'),
    ('ticket', 'Hook Gestor de Tickets', 'anota el mensaje en el caso abierto y evalúa reglas (no responde)'),
    ('ruby', '[MENSAJE DE BIENVENIDA]', 'primer mensaje: texto fijo; si además pregunta, sigue'),
    ('ruby', 'Palabras clave', 'cancel · pause · objective_met — coincidencia exacta'),
    ('agenda', '[PENDING_SLOT]', 'el cliente está eligiendo uno de los horarios ofrecidos'),
    ('agenda', '[PENDING_EMAIL]', 'falta el correo para la invitación de la cita'),
    ('agenda', 'Servicio apartado / @solicitudes', 'confirma o pide pago; cada servicio pedido = un caso'),
    ('llm', 'RouterService', 'hoy apagado (TRACKING_DETECT_INTENT=false) → ruta :tracking'),
    ('agenda', 'Acción de cita ya clasificada', 'el calendario gana sobre la búsqueda'),
    ('ticket', '@estado_ticket', '«¿cómo va mi caso?» — consultar nunca abre uno nuevo'),
    ('llm', 'Rama del turno — BranchClassifier', '1 llamada → {"rama"}; fija fuente y escalamiento'),
    ('ticket', '@crear_ticket', 'si la rama no tiene fuente / no es fallback: pide datos y abre caso'),
    ('agenda', '@agendar_calendar', 'el LLM ve la cita actual → consultar / agendar / mover / cancelar'),
    ('fuente', 'KBase — la fuente de la rama', 'Ruby busca; si hay resultados, el LLM redacta (ver sección 3)'),
    ('ticket', 'Ticket como último recurso', '@crear_ticket(fallback=true) o el escalamiento de la rama'),
    ('redacta', 'Conversacional', 'SIEMPRE responde: prosa + objetivo + historial (20 mensajes)'),
    ('ruby', 'Ningún seguimiento contestó', '→ BotSeller, si la cuenta lo tiene configurado'),
]
cx, cw, rh, step = 40, 650, 30, 35
base = 540


def row_y(i):
    return base + i * step + (26 if i >= 3 else 0) + (18 if i >= 19 else 0)


g_top = row_y(3) - 26
g_bot = row_y(18) + rh + 8
rect(cx - 8, g_top, cw + 16, g_bot - g_top, '#ffffff', '#cbd5e1', 12, 1.2, '5 4')
text(cx + 6, g_top + 17, 'Por cada seguimiento activo de la conversación (también pausados)', 10.5, 700, SOFT)

for i, (kind, title, det) in enumerate(rows):
    y = row_y(i)
    f, s = C[kind]
    rect(cx, y, cw, rh, f, s, 7, 1.2)
    num = str(i) if i else 'E'
    out.append(f'<circle cx="{cx + 17}" cy="{y + rh / 2}" r="10" fill="{s}"/>')
    text(cx + 17, y + rh / 2 + 4, num, 10, 700, '#fff', anchor='middle')
    text(cx + 36, y + 19, title, 11, 700, maxw=250)
    tx = cx + 36 + max(width(title, 11) + 14, 0)
    tx = max(tx, cx + 250)
    text(tx, y + 19, det, 10.5, fill=MUTED, maxw=cx + cw - tx - 8)
    if i < len(rows) - 1:
        ny = row_y(i + 1)
        if ny - (y + rh) > 6:
            pass
# flecha vertical a la izquierda (sentido)
out.append(f'<line x1="{cx - 22}" y1="{row_y(0) + 6}" x2="{cx - 22}" y2="{row_y(19) + 20}" stroke="#cbd5e1" stroke-width="2" marker-end="url(#arr)"/>')

# columna derecha
qx, qw = 720, 480
y0 = row_y(0)
rect(qx, y0, qw, 178, '#fffbeb', '#f59e0b', 10)
text(qx + 16, y0 + 22, 'Dónde entra el modelo (OpenAI, gpt-4o-mini por omisión)', 12, 700, maxw=qw - 30)
txt = [
    ('b', 'Clasifica — llamadas cortas con response_format json_object:'),
    ('', '· BranchClassifier → {"rama": "soporte"}'),
    ('', '· cita → {"appointment_action", fecha/hora pedida}'),
    ('', '· hoja → {op, columna, filtros}: Ruby calcula el resultado exacto'),
    ('b', 'Redacta — texto para el cliente:'),
    ('', '· KBase con el contexto recuperado · conversacional · avisos de agenda'),
    ('w', 'Sin tool calling: el modelo no decide buscar; cuando habla, Ruby ya buscó.'),
]
yy = y0 + 44
for k, s in txt:
    text(qx + 16, yy, s, 10.5, 700 if k == 'b' else None, '#b45309' if k == 'w' else MUTED, maxw=qw - 30)
    yy += 18

y1 = y0 + 194
rect(qx, y1, qw, 196, '#ffffff', '#94a3b8', 10)
text(qx + 16, y1 + 22, 'Estado entre turnos (no hay «memoria» de agente)', 12, 700, maxw=qw - 30)
st = [
    ('kb_history', 'conversación', 'últimos 6 turnos de la KBase'),
    ('[PENDING_SLOT]', 'tracking.ai_context', 'horarios ofrecidos'),
    ('[PENDING_EMAIL]', 'tracking.ai_context', 'slot elegido, falta correo'),
    ('intake de caso', 'Redis, TTL 1 h', 'campos que faltan para el ticket'),
    ('cita', 'tracking', 'appointment_at · appointment_event_id'),
    ('variables', 'conversación', 'p. ej. CARRERA, las guarda el motor'),
    ('historial', 'mensajes', 'conversacional ve los últimos 20'),
]
yy = y1 + 44
for a, b, c in st:
    text(qx + 16, yy, a, 10, mono=True, fill='#4f46e5')
    text(qx + 140, yy, b, 10, fill=SOFT)
    text(qx + 262, yy, c, 10, fill=MUTED, maxw=qw - 272)
    yy += 20

y2 = y1 + 212
rect(qx, y2, qw, 196, '#ecfdf5', '#22c55e', 10)
text(qx + 16, y2 + 22, 'Salida — Ruby retoca la respuesta antes de enviarla', 12, 700, maxw=qw - 30)
so = [
    '1  repone la #etiqueta de la rama si el modelo no puso ninguna',
    '2  {{nombre}} → se borra y se adjunta ese archivo del agente (máx. 5)',
    '3  KBase: firma de la fuente al pie · borra links inventados',
    '4  correo: firma del agente',
    '5  MessageBuilder → sentiment_auto_reply = true',
    '    (así el mismo mensaje nunca se contesta dos veces)',
    '6  EngineTrace guarda qué paso contestó el turno',
]
yy = y2 + 44
for s in so:
    text(qx + 16, yy, s, 10.5, fill=MUTED, maxw=qw - 30)
    yy += 20

y3 = y2 + 212
rect(qx, y3, qw, row_y(19) + rh - y3, '#f8fafc', '#cbd5e1', 10)
text(qx + 16, y3 + 22, 'Cómo leer la cascada', 12, 700)
tips = [
    'Agenda y tickets siempre le ganan a la KBase.',
    'La KBase es el último recurso antes de conversar.',
    'Si nada resolvió, el conversacional responde igual:',
    'improvisa con la prosa, por eso la prosa importa.',
    'Una directiva mal escrita no da error: no existe.',
]
yy = y3 + 44
for s in tips:
    text(qx + 16, yy, s, 10.5, fill=MUTED, maxw=qw - 30)
    yy += 18

# ------------------------------------------------------------------ ③ recursos
s3 = row_y(19) + rh + 58
section(3, s3, 'Recursos: fuentes de datos y calendario',
        'Cómo se usan las herramientas que el Entrenamiento declara. En ambos casos Ruby ejecuta y el modelo solo interpreta o redacta.')

ky = s3 + 32
kx, kw = 40, 590
kh = 470
rect(kx, ky, kw, kh, '#ffffff', '#22c55e', 12, 1.5)
text(kx + 16, ky + 26, 'Fuentes de datos (KBase) — KnowledgeBaseResponseService', 13, 700, maxw=kw - 30)
# mini flujo
fy = ky + 42
boxes = [('Rama del turno', 'BranchClassifier'), ('Directives.detect', 'UNA fuente'), ('Búsqueda', 'Ruby, antes del LLM')]
bx = kx + 16
for i, (a, b) in enumerate(boxes):
    rect(bx, fy, 170, 40, '#ecfdf5', '#bbf7d0', 7)
    text(bx + 12, fy + 17, a, 11, 700)
    text(bx + 12, fy + 32, b, 10, fill=SOFT)
    if i < 2:
        arrow(f'M{bx + 172},{fy + 20} L{bx + 190},{fy + 20}', '#22c55e')
    bx += 192
src = [
    ('{{hoja:nombre}}', 'Google Sheet', 'filas parecidas o cálculo exacto (suma)'),
    ('{{hoja_buscar: h | col=? | …}}', 'Google Sheet', 'la fila del valor que nombró el cliente'),
    ('{{doc:nombre}}', 'Google Doc', 'secciones indexadas en pgvector'),
    ('@buscar_predefinidas(G)', 'Predefinidas', 'pgvector, filtrado por grupo'),
    ('@buscar_articulo', 'Centro de Ayuda', 'artículos en pgvector'),
    ('@buscar_foro(n) · @discourse', 'Foro Discourse', 'búsqueda semántica (plugin discourse-ai)'),
    ('{{consulta:nombre}}', 'ERP externo', 'SQL determinista (saldo, pedidos…)'),
    ('@soporte_contpaq(n)', 'API CONTPAQi', 'devuelve la respuesta ya escrita'),
]
ty = fy + 62
text(kx + 16, ty, 'directiva', 10, 700, SOFT)
text(kx + 236, ty, 'origen', 10, 700, SOFT)
text(kx + 340, ty, 'cómo busca', 10, 700, SOFT)
ty += 8
for i, (d, o, c) in enumerate(src):
    if i % 2 == 0:
        rect(kx + 8, ty, kw - 16, 26, '#f8fafc', '#f8fafc', 4, 0)
    text(kx + 16, ty + 17, d, 10, mono=True, fill='#15803d', maxw=214)
    text(kx + 236, ty + 17, o, 10.5, 700, maxw=100)
    text(kx + 340, ty + 17, c, 10, fill=MUTED, maxw=kw - 350)
    ty += 26
ty += 14
rect(kx + 16, ty, kw - 32, 58, '#f5f3ff', '#c4b5fd', 8)
text(kx + 30, ty + 20, 'Con resultados → el LLM redacta', 11, 700)
text(kx + 30, ty + 37, 'fragmentos encontrados + kb_history (6 turnos) + prosa limpia + «rama ya', 10.5, fill=MUTED, maxw=kw - 60)
text(kx + 30, ty + 52, 'decidida, no reclasifiques» → respuesta + firma de la fuente al pie', 10.5, fill=MUTED, maxw=kw - 60)
ty += 68
rect(kx + 16, ty, kw - 32, 42, '#fef2f2', '#fecaca', 8)
text(kx + 30, ty + 18, 'Sin resultados → la KBase no contesta y sigue la cascada:', 11, 700, '#b91c1c', maxw=kw - 60)
text(kx + 30, ty + 34, 'ticket como último recurso (paso 17) o conversacional (paso 18)', 10.5, fill=MUTED, maxw=kw - 60)
kh_real = ty + 42 + 16 - ky

# calendario
gx, gw = 650, 550
rect(gx, ky, gw, kh, '#ffffff', '#3b82f6', 12, 1.5)
text(gx + 16, ky + 26, 'Calendario — @agendar_calendar', 13, 700)
steps = [
    ('llm', '¿Habla de una cita?', 'el LLM ve el ESTADO real de la cita → consultar · agendar · mover · cancelar · null'),
    ('agenda', '¿Ya tiene cita?', 'se la recuerda con fecha y hora; ofrece moverla o cancelarla'),
    ('agenda', 'En qué calendarios', 'los Google Calendar del agente; {{hoja_buscar}} elige cuál (SheetCalendars)'),
    ('agenda', 'Horarios libres — AvailabilitySlotService', 'ocupado en Google (freebusy) + horario del canal (9–18 L-V) + duración'),
    ('agenda', '¿Pidió día u hora?', 'sí: ese horario si está libre, o los más cercanos · no: los primeros libres'),
    ('agenda', 'Oferta numerada', 'formato según slots_presentation → guarda [PENDING_SLOT]'),
    ('agenda', 'El cliente elige o negocia', 'número, u otra hora que se vuelve a buscar → [PENDING_EMAIL] (opcional)'),
    ('fuente', 'GoogleCalendarService', 'crea o mueve el evento → appointment_at; si falla, escala a un humano'),
]
sy = ky + 44
for i, (k, a, b) in enumerate(steps):
    f, s = C[k]
    rect(gx + 16, sy, gw - 32, 38, f, s, 7)
    out.append(f'<circle cx="{gx + 34}" cy="{sy + 19}" r="10" fill="{s}"/>')
    text(gx + 34, sy + 23, str(i + 1), 10, 700, '#fff', anchor='middle')
    text(gx + 52, sy + 16, a, 11, 700, maxw=gw - 80)
    text(gx + 52, sy + 31, b, 10, fill=MUTED, maxw=gw - 80)
    if i < len(steps) - 1:
        arrow(f'M{gx + 34},{sy + 39} L{gx + 34},{sy + 47}', s)
    sy += 48
rect(gx + 16, sy + 2, gw - 32, 36, '#fef2f2', '#fecaca', 7)
text(gx + 30, sy + 18, 'Sin horarios libres o sin calendario configurado:', 10.5, 700, '#b91c1c')
text(gx + 30, sy + 32, 'pausa el seguimiento + nota privada + aviso al administrador', 10, fill=MUTED, maxw=gw - 60)
cal_end = sy + 38 + 16 - ky

# ajustar altura real de paneles
real = max(kh_real, cal_end)
out = [o.replace(f'height="{kh}" rx="12"', f'height="{real}" rx="12"') for o in out]

foot = ky + real + 32
text(40, foot, 'Código: app/jobs/contact_tracking_response_analyzer_job.rb (process_message_for_tracking, try_kbase_then_conversational) · '
     'app/services/knowledge_base_response_service.rb · app/services/contact_trackings/', 10, fill=SOFT)
H = foot + 24

svg = [f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" width="{W}" height="{H}" role="img" '
       f'aria-label="Diagrama del motor de Agentes IA: lectura del Entrenamiento, cascada de un turno, fuentes de datos y calendario">',
       '<title>Agente IA — cómo procesa un mensaje</title>',
       '<defs><marker id="arr" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse">'
       '<path d="M0,0 L10,5 L0,10 z" fill="#64748b"/></marker></defs>']
out[0] = f'<rect x="0" y="0" width="{W}" height="{H}" fill="#ffffff"/>'
svg += out + ['</svg>']
open(sys.argv[1], 'w').write('\n'.join(svg) + '\n')
for w in warnings:
    print('WARN', w)
print('ok', W, H)
