// proyecto@asistente_agentes_ia — OPERACIONES SOBRE LOS BLOQUES DEL ENTRENAMIENTO
// ============================================================================
// Plan: docs/estructura_agente_arbol_plan.md. Las mismas operaciones las piden dos
// pantallas —el árbol (Estructura del Agente) y las tarjetas— y tenerlas dos veces
// es tener dos formas distintas de armar el mismo texto.
//
// Son funciones PURAS: reciben la lista de bloques y devuelven una nueva. No arman
// ni separan texto —eso vive solo en Ruby (TrainingStructure)— solo mueven bloques
// y campos, y conservan `header` y `gap` tal como llegaron, que es lo que hace que
// guardar sin tocar nada no cambie ni un carácter del prompt.
// ============================================================================

// La sección que lleva una línea por rama. El nombre del contrato es
// "[ALCANCE POR RAMA]", pero los agentes de la cuenta la escriben de varias formas.
export const SCOPE_RE = /ALCANCE|SCOPE/i;
export const SCOPE_TITLE = 'ALCANCE POR RAMA';

let uidCounter = 0;
export const withUid = block => {
  if (block.uid) return { ...block };
  uidCounter += 1;
  return { ...block, uid: `b${uidCounter}` };
};

export const withUids = blocks => (blocks || []).map(withUid);

// Entre bloques, un renglón en blanco como mínimo; el último, sin colgar.
export const withGaps = blocks =>
  blocks.map((b, i) => ({
    ...b,
    gap: i === blocks.length - 1 ? b.gap || 0 : Math.max(b.gap || 0, 1),
  }));

export const updateBlock = (blocks, index, changes) => {
  const nuevos = [...blocks];
  nuevos[index] = { ...nuevos[index], ...changes };
  return nuevos;
};

export const moveBlock = (blocks, index, delta) => {
  const destino = index + delta;
  if (destino < 0 || destino >= blocks.length) return blocks;
  const nuevos = [...blocks];
  [nuevos[index], nuevos[destino]] = [nuevos[destino], nuevos[index]];
  return withGaps(nuevos);
};

// Mover una SECCIÓN de lugar. No usa el vecino de al lado sino la sección vecina, y
// por dos razones:
//   · el bloque de ramas no se mueve: sus líneas las lee el motor esté donde estén,
//     pero cruzarlo de lado no cambia nada y desordena el texto;
//   · el "texto inicial" no lleva rótulo, así que es SIEMPRE el primero: si una
//     sección quedara arriba de él, al volver a separar el texto ese texto pasaría a
//     ser parte del cuerpo de la sección anterior, en silencio.
// Devuelve la misma lista si esa sección ya es la primera o la última.
export const moveSection = (blocks, index, delta) => {
  const hermanas = blocks
    .map((b, i) => (b.type === 'section' ? i : null))
    .filter(i => i !== null);
  const lugar = hermanas.indexOf(index);
  const destino = hermanas[lugar + delta];
  if (lugar < 0 || destino === undefined) return blocks;
  const nuevos = [...blocks];
  [nuevos[index], nuevos[destino]] = [nuevos[destino], nuevos[index]];
  return withGaps(nuevos);
};

// Si esa sección puede moverse en esa dirección (para apagar la flecha).
export const canMoveSection = (blocks, index, delta) =>
  moveSection(blocks, index, delta) !== blocks;

export const removeBlock = (blocks, index) =>
  withGaps(blocks.filter((_, i) => i !== index));

// Un título con corchetes o saltos de línea rompería el rótulo.
export const cleanTitle = title =>
  (title || '').replace(/[[\]\n\r]/g, ' ').trim();

export const newSection = title =>
  withUid({ type: 'section', title: cleanTitle(title), body: '', gap: 1 });

export const addSection = (blocks, title) => {
  if (!cleanTitle(title)) return blocks;
  return withGaps([...blocks, newSection(title)]);
};

export const routesIndex = blocks => blocks.findIndex(b => b.type === 'routes');

export const routeLines = blocks =>
  blocks
    .filter(b => b.type === 'routes')
    .flatMap(b => b.lines || [])
    .filter(l => l.kind === 'route');

export const routeNames = blocks => routeLines(blocks).map(l => l.name);

// El nombre con el que se crea la sección del alcance: el del contrato que manda el
// backend en las sugerencias, y si no el del contrato tal cual.
export const scopeTitleFrom = suggested =>
  (suggested || []).find(t => SCOPE_RE.test(t)) || SCOPE_TITLE;

export const scopeIndex = blocks =>
  blocks.findIndex(b => b.type === 'section' && SCOPE_RE.test(b.title || ''));

// La línea de una rama en [ALCANCE POR RAMA]. Si la sección no está, se crea después
// de la primera sección (o al final si el Entrenamiento no tiene ninguna).
export const withScopeLine = (
  blocks,
  name,
  scope,
  scopeTitle = SCOPE_TITLE
) => {
  if (!scope) return blocks;
  const linea = `${name}: ${scope}`;
  const indice = scopeIndex(blocks);
  if (indice >= 0) {
    const cuerpo = (blocks[indice].body || '').replace(/\n+$/, '');
    return updateBlock(blocks, indice, {
      body: cuerpo ? `${cuerpo}\n${linea}` : linea,
    });
  }
  const seccion = withUid({
    type: 'section',
    title: scopeTitle,
    body: linea,
    gap: 1,
  });
  const primera = blocks.findIndex(b => b.type === 'section');
  const donde = primera < 0 ? blocks.length : primera + 1;
  return [...blocks.slice(0, donde), seccion, ...blocks.slice(donde)];
};

// Saca de [ALCANCE POR RAMA] la línea que empieza con el nombre de la rama. Se llama
// al quitar una rama: las dos mitades se escriben juntas, así que se van juntas.
export const withoutScopeLine = (blocks, name) => {
  const indice = scopeIndex(blocks);
  if (indice < 0 || !name) return blocks;
  const inicio = new RegExp(`^\\s*${name}\\s*:`, 'i');
  const cuerpo = (blocks[indice].body || '').split('\n');
  const quedan = cuerpo.filter(l => !inicio.test(l));
  if (quedan.length === cuerpo.length) return blocks;
  return updateBlock(blocks, indice, { body: quedan.join('\n') });
};

// La línea de alcance de una rama que ya existía: se saca la vieja —que puede estar
// escrita con el nombre anterior si se renombró— y se escribe la nueva. Sin texto,
// queda sin línea.
export const setScopeLine = (
  blocks,
  { previousName, name, scope },
  scopeTitle = SCOPE_TITLE
) => {
  const limpios = withoutScopeLine(
    previousName && previousName !== name
      ? withoutScopeLine(blocks, previousName)
      : blocks,
    name
  );
  return withScopeLine(limpios, name, scope, scopeTitle);
};

// La línea de alcance escrita hoy para esa rama, sin el "nombre: " del principio.
export const scopeTextFor = (blocks, name) => {
  const indice = scopeIndex(blocks);
  if (indice < 0 || !name) return '';
  const inicio = new RegExp(`^\\s*${name}\\s*:\\s*`, 'i');
  const linea = (blocks[indice].body || '')
    .split('\n')
    .find(l => inicio.test(l));
  return linea ? linea.replace(inicio, '').trim() : '';
};

// Una rama entra con su línea de alcance: las dos mitades juntas (ver RouteModal).
// Va al bloque de ramas —creándolo si es la primera— antes de la rama por defecto,
// que por convención va al final del bloque.
export const addRoute = (blocks, route, scope, scopeTitle = SCOPE_TITLE) => {
  let nuevos = [...blocks];
  let indice = routesIndex(nuevos);
  if (indice < 0) {
    nuevos = [
      withUid({ type: 'routes', text: '', gap: 1, lines: [] }),
      ...nuevos,
    ];
    indice = 0;
  }
  const lineas = [...(nuevos[indice].lines || [])];
  const corte = lineas.findIndex(l => l.kind === 'default');
  lineas.splice(corte < 0 ? lineas.length : corte, 0, route);
  nuevos = updateBlock(nuevos, indice, { lines: lineas });
  return withGaps(withScopeLine(nuevos, route.name, scope, scopeTitle));
};

// Reemplaza una rama por la editada. `position` es su lugar entre las ramas (no en
// la lista de líneas, que también lleva la rama por defecto y lo que no se reconoce).
export const replaceRoute = (blocks, position, route) => {
  const indice = routesIndex(blocks);
  if (indice < 0) return blocks;
  const lineas = [...(blocks[indice].lines || [])];
  let vistas = -1;
  const donde = lineas.findIndex(l => {
    if (l.kind !== 'route') return false;
    vistas += 1;
    return vistas === position;
  });
  if (donde < 0) return blocks;
  lineas[donde] = { ...lineas[donde], ...route };
  return updateBlock(blocks, indice, { lines: lineas });
};

// Quita una rama, y con ella su línea de alcance si se pide.
export const removeRoute = (blocks, position, { withScope = true } = {}) => {
  const indice = routesIndex(blocks);
  if (indice < 0) return blocks;
  const lineas = blocks[indice].lines || [];
  let vistas = -1;
  const donde = lineas.findIndex(l => {
    if (l.kind !== 'route') return false;
    vistas += 1;
    return vistas === position;
  });
  if (donde < 0) return blocks;
  const nombre = lineas[donde].name;
  const nuevos = updateBlock(blocks, indice, {
    lines: lineas.filter((_, i) => i !== donde),
  });
  return withScope ? withoutScopeLine(nuevos, nombre) : nuevos;
};

// Cambiar de lugar una rama. Como en las secciones, se cambia con la RAMA vecina y
// no con la línea vecina: el bloque también lleva la rama por defecto y lo que el
// parser no reconoce, y esas líneas se quedan donde están.
export const moveRoute = (blocks, position, delta) => {
  const indice = routesIndex(blocks);
  if (indice < 0) return blocks;
  const lineas = blocks[indice].lines || [];
  const lugares = lineas
    .map((l, i) => (l.kind === 'route' ? i : null))
    .filter(i => i !== null);
  const desde = lugares[position];
  const hasta = lugares[position + delta];
  if (desde === undefined || hasta === undefined) return blocks;
  const nuevas = [...lineas];
  [nuevas[desde], nuevas[hasta]] = [nuevas[hasta], nuevas[desde]];
  return updateBlock(blocks, indice, { lines: nuevas });
};

export const canMoveRoute = (blocks, position, delta) =>
  moveRoute(blocks, position, delta) !== blocks;

// La rama por defecto: la línea @ruta_por_defecto del bloque. Sin nombre, se quita.
export const setDefaultRoute = (blocks, name) => {
  const indice = routesIndex(blocks);
  if (indice < 0) return blocks;
  const lineas = [...(blocks[indice].lines || [])];
  const donde = lineas.findIndex(l => l.kind === 'default');
  if (!name) {
    if (donde < 0) return blocks;
    return updateBlock(blocks, indice, {
      lines: lineas.filter((_, i) => i !== donde),
    });
  }
  if (donde < 0) lineas.push({ kind: 'default', name, raw: '' });
  else lineas[donde] = { ...lineas[donde], name };
  return updateBlock(blocks, indice, { lines: lineas });
};

export const defaultRouteName = blocks => {
  const indice = routesIndex(blocks);
  if (indice < 0) return '';
  const linea = (blocks[indice].lines || []).find(l => l.kind === 'default');
  return linea ? linea.name : '';
};
