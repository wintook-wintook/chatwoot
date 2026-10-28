// proyecto@diagrama_agente_ia — F1: EL DIBUJO DEL AGENTE, SIN ILUMINAR
// ============================================================================
// Plan: docs/diagrama_agente_ia_plan.md §4.2. Función pura: de la Estructura del
// Agente (los bloques que da training_preview) y los hallazgos del comprobador por
// nodo (nodeIssues) a nodos, aristas y medidas en px. AgentDiagram.vue solo dibuja.
//
// Una FILA por ruta, en el orden en que el motor las recorre en un turno:
//
//   Cliente ──► Ruta ──► Fuente ──► Acción ──► Etiqueta
//
// Las secciones NO son una columna: el Entrenamiento entra completo al prompt en
// cada respuesta (el motor no elige secciones; ver la traza de F0, §3.1). Se
// listan aparte, debajo del dibujo. La bienvenida sí es un ramal propio: contesta
// el primer mensaje diga lo que diga, antes que cualquier ruta.
//
// Un agente sin rutas es conversacional, un estilo válido (no un defecto): una
// sola fila «Sin rutas → contesta con el Entrenamiento».
//
// Los ids de nodo (`route:soporte`, `source:soporte`…) son los que F2 va a
// iluminar con la traza de una prueba, por eso son estables y por nombre.
// ============================================================================
import { routeLines, defaultRouteName } from './trainingBlocks';

export const NODE_W = 168;
export const NODE_H = 46;
export const COL_GAP = 44;
export const ROW_GAP = 14;
export const PAD = 16;
export const HEADER_H = 26;
export const MAX_LABEL = 22;

export const COLUMNS = ['client', 'route', 'source', 'action', 'tag'];

const WELCOME_RE = /BIENVENIDA/i;

export const truncate = (text, max = MAX_LABEL) => {
  const limpio = (text || '').trim();
  return limpio.length > max ? `${limpio.slice(0, max - 1)}…` : limpio;
};

// La fuente en palabras: la directiva cruda se queda para el tooltip.
const SOURCE_PATTERNS = [
  [/^@buscar_predefinidas(?:\(([^)]*)\))?/i, 'PREDEFINED'],
  [/^@buscar_articulo/i, 'ARTICLES'],
  [/^@buscar_foro\(([^)]*)\)/i, 'FORUM'],
  [/^@discourse/i, 'FORUM'],
  [/^\{\{\s*doc:\s*([^}]*)\}\}/i, 'DOC'],
  [/^\{\{\s*hoja:\s*([^}]*)\}\}/i, 'SHEET'],
  [/^\{\{\s*consulta:\s*([^}]*)\}\}/i, 'ERP'],
  [/^@contpaq/i, 'ERP'],
];

export const describeSource = source => {
  const crudo = (source || '').trim();
  if (!crudo) return { kind: 'NONE', name: '', raw: '' };
  const hallado = SOURCE_PATTERNS.find(([re]) => re.test(crudo));
  if (!hallado) return { kind: 'OTHER', name: crudo, raw: crudo };
  const [re, kind] = hallado;
  const nombre = (crudo.match(re)[1] || '').replace(/\?$/, '').trim();
  return { kind, name: nombre, raw: crudo };
};

export const describeAction = line => {
  const accion = (line.action || line.escalation || '').trim();
  if (!accion) return null;
  if (/^@crear_ticket/i.test(accion))
    return { kind: 'TICKET', name: line.case_type || '', raw: line.escalation };
  if (/^@agendar_calendar/i.test(accion))
    return { kind: 'CALENDAR', name: '', raw: line.escalation };
  return { kind: 'OTHER', name: accion, raw: line.escalation || accion };
};

// El peor hallazgo entre el del nodo y el del grupo de rutas entero ('route:').
const issueFor = (issues, ...claves) => {
  const hallados = claves.map(c => issues[c]).filter(Boolean);
  if (!hallados.length) return null;
  return {
    level: hallados.some(h => h.level === 'blocking')
      ? 'blocking'
      : 'degrading',
    messages: hallados.flatMap(h => h.messages || []),
  };
};

const colX = column => PAD + COLUMNS.indexOf(column) * (NODE_W + COL_GAP);
const rowY = row => PAD + HEADER_H + row * (NODE_H + ROW_GAP);

// Curva de salida por la derecha a entrada por la izquierda.
export const edgePath = (from, to) => {
  const x1 = from.x + from.w;
  const y1 = from.y + from.h / 2;
  const x2 = to.x;
  const y2 = to.y + to.h / 2;
  const mid = (x1 + x2) / 2;
  return `M${x1},${y1} C${mid},${y1} ${mid},${y2} ${x2},${y2}`;
};

const node = (id, column, row, props) => ({
  id,
  column,
  x: colX(column),
  y: rowY(row),
  w: NODE_W,
  h: NODE_H,
  issue: null,
  ...props,
});

const routeRow = (line, row, { isDefault, issues }) => {
  const nombre = line.name;
  const fuente = describeSource(line.source);
  const accion = describeAction(line);
  const nodos = [
    node(`route:${nombre}`, 'route', row, {
      kind: 'route',
      label: truncate(nombre),
      sub: truncate(line.description, 26),
      title: [nombre, line.description].filter(Boolean).join(' — '),
      isDefault,
      broken: line.kind === 'broken',
      target: { type: 'route', name: nombre },
      issue: issueFor(issues, `route:${nombre}`, 'route:'),
    }),
    node(`source:${nombre}`, 'source', row, {
      kind: 'source',
      sourceKind: fuente.kind,
      label: truncate(fuente.name),
      title: fuente.raw,
      muted: fuente.kind === 'NONE',
      target: { type: 'route', name: nombre },
    }),
  ];
  if (accion)
    nodos.push(
      node(`action:${nombre}`, 'action', row, {
        kind: 'action',
        actionKind: accion.kind,
        label: truncate(accion.name),
        title: accion.raw,
        target: { type: 'route', name: nombre },
      })
    );
  nodos.push(
    node(`tag:${nombre}`, 'tag', row, {
      kind: 'tag',
      label: line.tag ? truncate(`#${line.tag}`) : '',
      title: line.tag ? `#${line.tag}` : '',
      missing: !line.tag,
      target: { type: 'route', name: nombre },
    })
  );
  // Cada nodo de la fila apunta al siguiente; sin acción, la fuente va directo a
  // la etiqueta.
  const aristas = nodos.slice(1).map((destino, i) => ({
    id: `${nodos[i].id}->${destino.id}`,
    from: nodos[i].id,
    to: destino.id,
    dashed: fuente.kind === 'NONE' && i === 0,
  }));
  return { nodos, aristas };
};

export function buildDiagram(blocks = [], issues = {}) {
  const lineas = routeLines(blocks);
  const porDefecto = defaultRouteName(blocks);
  const secciones = blocks
    .map((block, index) => ({ ...block, index }))
    .filter(b => b.type === 'section');
  const bienvenida = secciones.find(b => WELCOME_RE.test(b.title || ''));

  const nodes = [];
  const edges = [];
  let fila = 0;

  if (bienvenida) {
    nodes.push(
      node('welcome', 'route', fila, {
        kind: 'welcome',
        label: truncate(bienvenida.title),
        title: bienvenida.title,
        target: { type: 'section', index: bienvenida.index },
        issue: issueFor(issues, `section:${bienvenida.index}`),
      })
    );
    fila += 1;
  }

  if (lineas.length) {
    lineas.forEach(linea => {
      const { nodos, aristas } = routeRow(linea, fila, {
        isDefault: linea.name === porDefecto,
        issues,
      });
      nodes.push(...nodos);
      edges.push(...aristas);
      fila += 1;
    });
  } else {
    nodes.push(
      node('conversational', 'route', fila, {
        kind: 'conversational',
        label: '',
        title: '',
        muted: true,
        target: null,
      })
    );
    fila += 1;
  }

  const filas = Math.max(fila, 1);
  const altoFilas = filas * NODE_H + (filas - 1) * ROW_GAP;
  const cliente = {
    id: 'client',
    column: 'client',
    kind: 'client',
    x: colX('client'),
    y: PAD + HEADER_H + (altoFilas - NODE_H) / 2,
    w: NODE_W,
    h: NODE_H,
    label: '',
    title: '',
    issue: null,
    target: null,
  };
  nodes.unshift(cliente);
  nodes
    .filter(n => n.column === 'route')
    .forEach(n =>
      edges.unshift({
        id: `client->${n.id}`,
        from: 'client',
        to: n.id,
        dashed: n.kind === 'welcome',
      })
    );

  const porId = Object.fromEntries(nodes.map(n => [n.id, n]));
  edges.forEach(e => {
    e.d = edgePath(porId[e.from], porId[e.to]);
  });

  // Hasta dónde llega el dibujo: sin rutas, solo dos columnas.
  const ultima = Math.max(...nodes.map(n => COLUMNS.indexOf(n.column)));
  return {
    width: colX(COLUMNS[ultima]) + NODE_W + PAD,
    height: PAD + HEADER_H + altoFilas + PAD,
    columns: COLUMNS.slice(0, ultima + 1).map(id => ({
      id,
      x: colX(id),
      center: colX(id) + NODE_W / 2,
    })),
    nodes,
    edges,
    sections: secciones.map(s => ({
      index: s.index,
      title: s.title,
      issue: issueFor(issues, `section:${s.index}`),
    })),
    routeCount: lineas.length,
  };
}
