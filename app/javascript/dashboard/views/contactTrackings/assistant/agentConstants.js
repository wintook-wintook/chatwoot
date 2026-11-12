// proyecto@crear_agente_conversando — F2: LOS DATOS FIJOS DEL AGENTE
// ============================================================================
// Plan: docs/creacion_conversacional_agentes_plan.md §4. Valores que se escriben una
// vez y se citan con %NOMBRE% en cualquier parte. Estas funciones leen y escriben la
// sección [DATOS FIJOS] sobre los bloques de la Estructura, con las mismas reglas que
// ContactTrackings::PromptConstants (el motor es quien los sustituye, D1):
//
//   [DATOS FIJOS]
//   EMPRESA = Kontrolya
//   Q1 (pregunta) = ¿Qué sistemas utilizas hoy? → guarda en SISTEMA
//   CIERRE = Ahora que ya entendí 👌
//
//     Puedes agendar aquí 👇 %LIGA_AGENDA%      ← sangría: sigue el valor
//
// Funciones PURAS: reciben bloques y devuelven bloques nuevos.
// ============================================================================
import { updateBlock, withGaps, withUid } from './trainingBlocks';

const NAME = '[A-ZÁÉÍÓÚÑ][A-ZÁÉÍÓÚÑ0-9_]*';
const DECL_RE = new RegExp(
  `^[ \\t]*(?:[-*•][ \\t]*)?(${NAME})[ \\t]*(?:\\([ \\t]*(\\p{L}+)[ \\t]*\\))?[ \\t]*=[ \\t]?(.*?)[ \\t]*$`,
  'u'
);
const SAVES_RE = new RegExp(
  `[ \\t]*(?:→|->)[ \\t]*guarda(?:r)?[ \\t]+en[ \\t]+(${NAME})[ \\t]*$`,
  'i'
);
const CONTINUATION_RE = /^(?: {2,}|\t)(.*)$/;
const TITLE_RE = /^\s*(DATOS\s+FIJOS|CONSTANTES?)\s*$/i;

export const CONSTANTS_TITLE = 'DATOS FIJOS';
export const CONSTANT_TYPES = ['texto', 'pregunta', 'liga', 'numero'];
const TYPE_ALIASES = {
  número: 'numero',
  link: 'liga',
  url: 'liga',
  question: 'pregunta',
  text: 'texto',
  number: 'numero',
};

export const constantRef = name => `%${name}%`;

// Como lo acepta el motor: MAYÚSCULAS, dígitos y «_», empezando con letra.
export const cleanConstantName = texto =>
  (texto || '')
    .trim()
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .toUpperCase()
    .replace(/[^A-Z0-9]+/g, '_')
    .replace(/^[_0-9]+|_+$/g, '');

const isConstantsBlock = b =>
  b.type === 'section' && TITLE_RE.test(b.title || '');

export const constantsIndex = blocks =>
  (blocks || []).findIndex(isConstantsBlock);

const normalType = tipo => {
  const t = (tipo || '').toLowerCase();
  const alias = TYPE_ALIASES[t] || t;
  return CONSTANT_TYPES.includes(alias) ? alias : 'texto';
};

const declaration = match => {
  let value = match[3] || '';
  const guarda = value.match(SAVES_RE);
  if (guarda) value = value.replace(SAVES_RE, '');
  return {
    name: match[1],
    type: normalType(match[2]),
    value: value.trim(),
    savesTo: guarda ? guarda[1] : '',
  };
};

// { constants: [{ name, type, value, savesTo }], extra: [renglones que no son datos] }
export const parseConstants = body => {
  const constants = [];
  const extra = [];
  let actual = null;
  let blancos = 0;
  (body || '').split('\n').forEach(linea => {
    if (!linea.trim()) {
      if (actual) blancos += 1;
      return;
    }
    const cont = linea.match(CONTINUATION_RE);
    if (actual && cont && !DECL_RE.test(linea)) {
      actual.value = [
        actual.value,
        ...Array(blancos).fill(''),
        cont[1].trimEnd(),
      ].join('\n');
      blancos = 0;
      return;
    }
    const decl = linea.match(DECL_RE);
    blancos = 0;
    if (decl) {
      actual = declaration(decl);
      constants.push(actual);
      return;
    }
    actual = null;
    extra.push(linea);
  });
  return { constants, extra };
};

const declarationLines = c => {
  const tipo = c.type && c.type !== 'texto' ? ` (${c.type})` : '';
  const [primera, ...resto] = (c.value || '').split('\n');
  const guarda =
    c.type === 'pregunta' && c.savesTo ? ` → guarda en ${c.savesTo}` : '';
  return [
    `${c.name}${tipo} = ${primera}${guarda}`,
    ...resto.map(l => (l.trim() ? `  ${l}` : '')),
  ];
};

export const serializeConstants = ({ constants, extra = [] }) => {
  const lineas = (constants || [])
    .filter(c => cleanConstantName(c.name) && (c.value || '').trim())
    .flatMap(declarationLines);
  if (extra.length) lineas.push('', ...extra);
  return lineas.join('\n');
};

export const readConstants = blocks => {
  const i = constantsIndex(blocks);
  return i < 0 ? { constants: [], extra: [] } : parseConstants(blocks[i].body);
};

// La sección nueva va antes de las demás secciones (después de [VARIABLES] si existe).
const insertConstantsSection = (blocks, body) => {
  const nueva = withUid({
    type: 'section',
    title: CONSTANTS_TITLE,
    body,
    gap: 1,
  });
  const vars = blocks.findIndex(
    b => b.type === 'section' && /^\s*VARIABLES?\s*$/i.test(b.title || '')
  );
  const primera = blocks.findIndex(b => b.type === 'section');
  let lugar = vars >= 0 ? vars + 1 : primera;
  if (lugar < 0) lugar = blocks.length;
  const nuevos = [...blocks];
  nuevos.splice(lugar, 0, nueva);
  return withGaps(nuevos);
};

export const writeConstants = (blocks, data) => {
  const body = serializeConstants(data);
  const i = constantsIndex(blocks);
  if (i < 0) return body ? insertConstantsSection(blocks, body) : blocks;
  if (!body) return withGaps(blocks.filter((_, n) => n !== i));
  return updateBlock(blocks, i, { body });
};

// ── dónde se usa cada uno ──────────────────────────────────────────────────────
const blockText = b => b.text || b.body || '';

// El lugar, en palabras: «@demo», «BIENVENIDA», «texto inicial».
const placesIn = (b, ref) => {
  if (b.type === 'routes') {
    return (b.lines || [])
      .filter(l => (l.raw || '').includes(ref))
      .map(l => `@${l.name}`);
  }
  if (!blockText(b).includes(ref)) return [];
  return [b.type === 'preamble' ? '' : b.title];
};

// { EMPRESA: { count, places: ['@demo', 'BIENVENIDA'] } } — fuera de su propia sección,
// más las citas desde otro dato fijo (CIERRE cita %LIGA_AGENDA%).
export const constantUsage = (blocks, constants) => {
  const lista = blocks || [];
  return (constants || []).reduce((acc, c) => {
    const ref = constantRef(c.name);
    let count = 0;
    const places = [];
    lista.forEach(b => {
      if (isConstantsBlock(b)) return;
      const veces = blockText(b).split(ref).length - 1;
      if (!veces) return;
      count += veces;
      places.push(...placesIn(b, ref));
    });
    (constants || []).forEach(otro => {
      if (otro.name === c.name || !(otro.value || '').includes(ref)) return;
      count += 1;
      places.push(constantRef(otro.name));
    });
    acc[c.name] = { count, places };
    return acc;
  }, {});
};
