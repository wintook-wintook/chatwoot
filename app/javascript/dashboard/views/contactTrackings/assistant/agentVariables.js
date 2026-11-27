// proyecto@crear_agente_conversando — F1: LAS VARIABLES DEL AGENTE
// ============================================================================
// Plan: docs/creacion_conversacional_agentes_plan.md §3. No hay mecanismo nuevo: el
// motor ya guarda por conversación lo que declara la sección [VARIABLES]
// (ContactTrackings::ConversationVariables::Definition). Estas funciones leen y
// escriben ESA sección sobre los bloques de la Estructura, con las mismas reglas que
// el Ruby, así que escribirla a mano o con el modal es lo mismo:
//
//   [VARIABLES]
//   CARRERA = valor                 ← «valor» (o texto, dato): lo que diga el cliente
//   LIGA_ENTREGADA = NO | SÍ
//   Inicial: LIGA_ENTREGADA=NO
//
// Funciones PURAS: reciben bloques y devuelven bloques nuevos. Lo que no es una
// declaración ni el «Inicial:» (una nota, un comentario) se conserva al final.
// ============================================================================
import { updateBlock, withGaps, withUid } from './trainingBlocks';

const NAME = '[A-Za-zÁÉÍÓÚÑáéíóúñ_][A-Za-z0-9ÁÉÍÓÚÑáéíóúñ_]*';
const UPPER_NAME = '[A-ZÁÉÍÓÚÑ][A-ZÁÉÍÓÚÑ0-9_]{2,}';
const DECL_RE = new RegExp(
  `^[ \\t]*(?:[-*][ \\t]*)?(${NAME})[ \\t]*=[ \\t]*(.+?)[ \\t]*$`
);
const INITIAL_RE =
  /^[ \t]*(?:[-*][ \t]*)?inicial(?:es)?[ \t]*:[ \t]*(.+?)[ \t]*$/i;
const PAIR_RE = new RegExp(`(${NAME})[ \\t]*=[ \\t]*([^;\\n]+)`, 'g');
// La misma de VariableChecks::STRAY_RE: una declaración con al menos una barra.
const STRAY_RE = new RegExp(
  `^[ \\t]*(?:[-*•][ \\t]*)?(${UPPER_NAME})[ \\t]*=[ \\t]*([^|\\n]*\\|.*?)[ \\t]*$`
);
const STRAY_PART_RE = new RegExp(
  `(?:^|[^\\p{L}\\d_])(${UPPER_NAME})[ \\t]*=[ \\t]*([^;\\n]*\\|[^;\\n]*)`,
  'gu'
);

export const VARIABLES_TITLE = 'VARIABLES';
export const FREE_VALUES = ['VALOR', 'TEXTO', 'DATO'];
export const FREE_WORD = 'valor';

// Como ConversationVariables.key: sin acentos, en mayúsculas, espacios por «_».
export const variableKey = texto =>
  (texto || '')
    .trim()
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .toUpperCase()
    .replace(/\s+/g, '_');

// Un nombre que el motor acepta: sin espacios ni signos («Liga entregada» → LIGA_ENTREGADA).
export const cleanVariableName = texto =>
  (texto || '')
    .trim()
    .replace(/\s+/g, '_')
    .replace(/[^A-Za-z0-9ÁÉÍÓÚÑáéíóúñ_]/g, '')
    .replace(/^[0-9]+/, '')
    .toUpperCase();

const isVariablesBlock = b =>
  b.type === 'section' && /^\s*VARIABLES?\s*$/i.test(b.title || '');

export const variablesIndex = blocks =>
  (blocks || []).findIndex(isVariablesBlock);

const parseOptions = lista => {
  const opciones = lista
    .split('|')
    .map(o => o.trim())
    .filter(Boolean);
  const libre = opciones.some(o => FREE_VALUES.includes(variableKey(o)));
  return {
    options: opciones.filter(o => !FREE_VALUES.includes(variableKey(o))),
    free: libre,
  };
};

// { variables: [{ name, options, free, initial }], extra: [renglones que no son
// declaraciones] }. `initial` es el valor escrito en «Inicial:» ('' si no hay).
export const parseVariables = body => {
  const variables = [];
  const iniciales = {};
  const extra = [];
  (body || '').split('\n').forEach(linea => {
    const inicial = linea.match(INITIAL_RE);
    if (inicial) {
      [...inicial[1].matchAll(PAIR_RE)].forEach(([, nombre, valor]) => {
        iniciales[variableKey(nombre)] = valor.trim();
      });
      return;
    }
    const decl = linea.match(DECL_RE);
    if (decl) {
      variables.push({ name: decl[1].trim(), ...parseOptions(decl[2]) });
      return;
    }
    extra.push(linea);
  });
  // Los renglones en blanco de las orillas no son notas.
  while (extra.length && !extra[0].trim()) extra.shift();
  while (extra.length && !extra[extra.length - 1].trim()) extra.pop();
  return {
    variables: variables.map(v => ({
      ...v,
      initial: iniciales[variableKey(v.name)] || '',
    })),
    extra,
  };
};

const declarationLine = v => {
  const valores = [...v.options];
  if (v.free) valores.push(FREE_WORD);
  return `${v.name} = ${valores.join(' | ')}`;
};

// El cuerpo de la sección, desde la lista del modal.
export const serializeVariables = ({ variables, extra = [] }) => {
  const validas = (variables || []).filter(
    v => cleanVariableName(v.name) && (v.free || v.options.length)
  );
  const lineas = validas.map(declarationLine);
  const iniciales = validas
    .filter(v => (v.initial || '').trim())
    .map(v => `${v.name}=${v.initial.trim()}`);
  if (iniciales.length) lineas.push(`Inicial: ${iniciales.join('; ')}`);
  if (extra.length) lineas.push('', ...extra);
  return lineas.join('\n');
};

export const readVariables = blocks => {
  const i = variablesIndex(blocks);
  return i < 0 ? { variables: [], extra: [] } : parseVariables(blocks[i].body);
};

// La sección nueva va antes de las demás secciones (después del texto inicial y de las
// rutas): es lo primero que conviene leer de un agente, y el motor la lee esté donde esté.
const insertVariablesSection = (blocks, body) => {
  const nueva = withUid({
    type: 'section',
    title: VARIABLES_TITLE,
    body,
    gap: 1,
  });
  const primera = blocks.findIndex(b => b.type === 'section');
  const nuevos = [...blocks];
  nuevos.splice(primera < 0 ? nuevos.length : primera, 0, nueva);
  return withGaps(nuevos);
};

// Escribe la lista en [VARIABLES]: la crea si no existe y la quita si queda vacía.
export const writeVariables = (blocks, data) => {
  const body = serializeVariables(data);
  const i = variablesIndex(blocks);
  if (i < 0) return body ? insertVariablesSection(blocks, body) : blocks;
  if (!body) return withGaps(blocks.filter((_, n) => n !== i));
  return updateBlock(blocks, i, { body });
};

// ── V5: las que están escritas fuera de [VARIABLES] ────────────────────────────
const blockText = b => (b.type === 'preamble' ? b.text : b.body) || '';
const textField = b => (b.type === 'preamble' ? 'text' : 'body');

// Cada renglón suelto partido en sus declaraciones: «A=X|Y; B=NO|SÍ.» → dos.
const splitStray = linea =>
  [...linea.matchAll(STRAY_PART_RE)].map(([, nombre, valores]) => ({
    name: nombre,
    ...parseOptions(valores.replace(/[.\s]+$/, '')),
    initial: '',
  }));

// [{ index, name }] de los bloques que no son [VARIABLES] (ni las rutas).
export const strayVariables = blocks =>
  (blocks || []).flatMap((b, index) => {
    if (isVariablesBlock(b) || !['section', 'preamble'].includes(b.type))
      return [];
    return blockText(b)
      .split('\n')
      .filter(linea => STRAY_RE.test(linea))
      .flatMap(linea => splitStray(linea).map(v => ({ index, name: v.name })));
  });

// «Pasarlas a Variables»: quita esos renglones de donde estaban y los escribe, una
// variable por renglón, en [VARIABLES]. Si ya había una con ese nombre, gana la de
// [VARIABLES] (es la que el motor ya estaba leyendo).
export const moveStrayVariables = blocks => {
  const sueltas = [];
  let nuevos = (blocks || []).map((b, index) => {
    if (isVariablesBlock(b) || !['section', 'preamble'].includes(b.type))
      return b;
    const lineas = blockText(b).split('\n');
    const quedan = lineas.filter(linea => {
      if (!STRAY_RE.test(linea)) return true;
      sueltas.push(...splitStray(linea));
      return false;
    });
    return quedan.length === lineas.length
      ? b
      : { ...blocks[index], [textField(b)]: quedan.join('\n') };
  });
  if (!sueltas.length) return blocks;
  const actual = readVariables(nuevos);
  const ya = new Set(actual.variables.map(v => variableKey(v.name)));
  const agregar = sueltas.filter(v => {
    const clave = variableKey(v.name);
    if (ya.has(clave)) return false;
    ya.add(clave);
    return true;
  });
  nuevos = writeVariables(nuevos, {
    variables: [...actual.variables, ...agregar],
    extra: actual.extra,
  });
  return nuevos;
};
