// proyecto@diagrama_agente_ia — F2: EL CAMINO DE UNA PRUEBA SOBRE EL DIAGRAMA
// ============================================================================
// Plan: docs/diagrama_agente_ia_plan.md §4.2. Función pura: del resultado de una
// prueba a qué nodos y aristas del diagrama (agentDiagramLayout) se iluminan.
//
//   en vivo  la traza que dejó el motor en la respuesta (F0, §3.1)
//   en seco  el informe de DryRunService (ruta, fuente, fragmentos, etiqueta, caso)
//
// Lo que se devuelve son ids de nodo, nunca coordenadas, y solo los que existen en
// el diagrama ACTUAL: si el Entrenamiento cambió y la ruta ya no está, no se pinta
// nada inventado; se avisa con la nota.
//
//   { mode, nodes: [id], edges: [id], failed: [id], details: { id: { key, args } },
//     note: { key, args } | null }
//
// `failed` es un nodo por el que pasó y no resolvió: la fuente que no trajo nada y
// el turno cayó a la respuesta conversacional. Es el punto débil que el plan pide
// marcar (⚠), y casi siempre el que hay que corregir.
// ============================================================================

// Caminos del job que contestan antes de mirar las rutas (ver la traza, `camino`).
export const BEFORE_ROUTES = [
  'palabra_clave',
  'eleccion_horario',
  'correo_cita',
  'confirmar_servicio',
  'solicitudes',
  'estado_ticket',
  'rechazo',
  'interes',
  'botseller',
];

const ACTION_PATHS = ['ticket', 'agenda'];

const builder = (diagram, mode) => {
  const existe = new Set(diagram.nodes.map(n => n.id));
  const lit = new Set();
  const failed = new Set();
  const details = {};
  return {
    lit,
    failed,
    details,
    has: id => existe.has(id),
    add(id) {
      if (existe.has(id)) lit.add(id);
    },
    fail(id) {
      if (!existe.has(id)) return;
      lit.add(id);
      failed.add(id);
    },
    detail(id, key, args = {}) {
      if (existe.has(id)) details[id] = { key, args };
    },
    result(note = null) {
      lit.add('client');
      return {
        mode,
        nodes: [...lit],
        // Una arista se enciende si se encendieron sus dos puntas.
        edges: diagram.edges
          .filter(e => lit.has(e.from) && lit.has(e.to))
          .map(e => e.id),
        failed: [...failed],
        details,
        note,
      };
    },
  };
};

const bestSimilarity = items =>
  Math.max(...items.map(i => Number(i.similitud || i.similarity || 0)));

const fragmentDetail = (b, id, items) => {
  if (!items || !items.length) return;
  b.detail(id, 'PATH_FRAGMENTS', {
    count: items.length,
    best: bestSimilarity(items).toFixed(2),
  });
};

const nodeById = (diagram, id) => diagram.nodes.find(n => n.id === id);

const tagShown = (reply, tag) =>
  Boolean(tag) && (reply || '').toLowerCase().includes(tag.toLowerCase());

export function pathFromTrace(traza, diagram, reply = '') {
  const b = builder(diagram, 'live');
  if (!traza) return b.result({ key: 'PATH_NO_TRACE' });

  const camino = traza.camino || '';
  if (camino === 'bienvenida') {
    b.add('welcome');
    return b.result({ key: 'PATH_WELCOME' });
  }

  const ruta = traza.ruta && traza.ruta.nombre;
  if (!ruta) {
    if (BEFORE_ROUTES.includes(camino))
      return b.result({ key: 'PATH_BEFORE_ROUTES', args: { camino } });
    b.add('conversational');
    return b.result(
      diagram.routeCount ? { key: 'PATH_NO_ROUTE' } : { key: 'PATH_ANSWERED' }
    );
  }

  const nombre = ruta.toLowerCase();
  if (!b.has(`route:${nombre}`))
    return b.result({ key: 'PATH_ROUTE_GONE', args: { route: ruta } });

  b.add(`route:${nombre}`);
  if (traza.ruta.como === 'por_defecto')
    b.detail(`route:${nombre}`, 'PATH_BY_DEFAULT');

  const fuente = nodeById(diagram, `source:${nombre}`);
  if (fuente && fuente.muted) {
    b.add(fuente.id);
  } else if (fuente && camino === 'kbase') {
    b.add(fuente.id);
    fragmentDetail(b, fuente.id, traza.fragmentos);
  } else if (fuente && camino === 'conversacional') {
    // Tenía fuente y no resolvió: el turno cayó a la conversación.
    b.fail(fuente.id);
    b.detail(fuente.id, 'PATH_SOURCE_EMPTY');
  }

  if (ACTION_PATHS.includes(camino)) b.add(`action:${nombre}`);
  const tag = (nodeById(diagram, `tag:${nombre}`) || {}).title;
  if (tagShown(reply, tag) || traza.etiqueta_repuesta) b.add(`tag:${nombre}`);

  return b.result(
    BEFORE_ROUTES.includes(camino)
      ? { key: 'PATH_BEFORE_ROUTES', args: { camino } }
      : null
  );
}

// El informe de la prueba en seco (DryRunService): no redacta, así que la etiqueta
// es la de la ruta y la acción es el pronóstico del caso.
export function pathFromDryRun(informe, diagram) {
  const b = builder(diagram, 'dry');
  if (!informe) return b.result({ key: 'PATH_NO_TRACE' });

  const rutas = informe.routes || {};
  if (rutas.none_declared) {
    b.add('conversational');
    return b.result({ key: 'PATH_ANSWERED' });
  }
  const ruta = rutas.chosen;
  if (!ruta) return b.result({ key: 'PATH_NO_ROUTE' });
  const nombre = ruta.toLowerCase();
  if (!b.has(`route:${nombre}`))
    return b.result({ key: 'PATH_ROUTE_GONE', args: { route: ruta } });

  b.add(`route:${nombre}`);
  if (rutas.default === ruta) b.detail(`route:${nombre}`, 'PATH_IS_DEFAULT');

  const fuente = informe.source || {};
  const id = `source:${nombre}`;
  const motivo = fuente.reason;
  if (!motivo || motivo === 'no_source') {
    const items = fuente.items || [];
    if (motivo === 'no_source' || items.length) {
      b.add(id);
      fragmentDetail(b, id, items);
    } else {
      b.fail(id);
      b.detail(id, 'PATH_SOURCE_EMPTY');
    }
  } else if (motivo === 'live_source') {
    b.add(id);
    b.detail(id, 'PATH_SOURCE_LIVE');
  } else {
    b.fail(id);
    b.detail(id, 'PATH_SOURCE_BROKEN');
  }

  if (informe.case && informe.case.creates) b.add(`action:${nombre}`);
  if (informe.tag) b.add(`tag:${nombre}`);
  return b.result();
}

// proyecto@diagrama_agente_ia F3 — la ruta por la que pasó una prueba de la pila: la
// de su última corrida en vivo (la traza), si no la de su última en seco, y si nunca
// corrió, la que se esperaba (la de su ruta, en las generadas).
export const caseRoute = caso => {
  const vivo = caso.last_live || {};
  const traza = vivo.traza || {};
  if (traza.ruta && traza.ruta.nombre) return traza.ruta.nombre.toLowerCase();
  const seco = (caso.last_dry && caso.last_dry.informe) || {};
  if (seco.routes && seco.routes.chosen)
    return seco.routes.chosen.toLowerCase();
  return (caso.expected_route || '').toLowerCase();
};

// El mapa de calor (§4.3): por ruta, cuántas pruebas de la pila pasan por ahí y
// cuántas fallaron en vivo. Una ruta que no aparece no tiene pruebas.
export function heatFromCases(cases = []) {
  return cases.reduce((mapa, caso) => {
    const ruta = caseRoute(caso);
    if (!ruta) return mapa;
    const actual = mapa[ruta] || { total: 0, failed: 0 };
    const fallo = caso.last_live && caso.last_live.cumple === false;
    return {
      ...mapa,
      [ruta]: {
        total: actual.total + 1,
        failed: actual.failed + (fallo ? 1 : 0),
      },
    };
  }, {});
}
