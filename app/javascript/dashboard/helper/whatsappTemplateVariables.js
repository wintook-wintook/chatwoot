// feat/plantillas_variables_resolver F9.2 — DE UNA VARIABLE CON NOMBRE A SU DATO
// ============================================================================
// Réplica de Whatsapp::TemplateVariableResolver para llenar la conversación antes de mandar.
// Las dos pasan los mismos casos: spec/fixtures/whatsapp_template_variables.json.
//
// context: {
//   contact,                 meta.sender o el contacto del store
//   conversation,            la del store: su `id` es el número de conversación
//   inbox,                   { name, timezone }
//   agent,                   opcional: sin él, el asignado de la conversación
//   now,                     opcional: hoy
// }
// ============================================================================
const VALID_NAME = /^[a-z][a-z0-9_]*$/;
const ONLY_DATE = /^(\d{4})-(\d{2})-(\d{2})$/;
const DATE_TIME =
  /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?(Z|[+-]\d{2}:\d{2})$/;
const HAS_LETTER = /\p{L}/u;

const timezoneOf = context => (context.inbox || {}).timezone || 'UTC';

const formatDate = (date, context) =>
  new Intl.DateTimeFormat('en-GB', {
    timeZone: timezoneOf(context),
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
  }).format(date);

// Los atributos de tipo fecha se guardan como 2026-10-31T06:00:00.000Z.
const dateText = (text, context) => {
  if (!DATE_TIME.test(text)) return text.replace(ONLY_DATE, '$3/$2/$1');
  const fecha = new Date(text);
  return Number.isNaN(fecha.getTime()) ? text : formatDate(fecha, context);
};

// Meta rechaza saltos de línea, tabuladores y varios espacios seguidos en una variable.
const plainText = (value, context) => {
  if (value === true) return 'Sí';
  if (value === false) return 'No';
  if (typeof value !== 'string' && typeof value !== 'number') return '';
  return dateText(String(value).replace(/\s+/g, ' ').trim(), context);
};

// Sin letras (el nombre que quedó como teléfono) no es un nombre: no se le saluda con eso.
const fullName = ({ contact }) => {
  const nombre = String((contact || {}).name || '')
    .replace(/\s+/g, ' ')
    .trim();
  return HAS_LETTER.test(nombre) ? nombre : '';
};

const agentOf = ({ agent, conversation }) =>
  agent || ((conversation || {}).meta || {}).assignee || {};

const RESERVED = {
  nombre: fullName,
  primer_nombre: context => fullName(context).split(' ')[0],
  apellido: context => {
    const palabras = fullName(context).split(' ');
    return palabras.length > 1 ? palabras[palabras.length - 1] : '';
  },
  correo: ({ contact }) => (contact || {}).email,
  telefono: ({ contact }) => (contact || {}).phone_number,
  empresa: ({ contact }) =>
    ((contact || {}).additional_attributes || {}).company_name,
  agente: context => {
    const agente = agentOf(context);
    return agente.available_name || agente.name;
  },
  conversacion: ({ conversation }) => (conversation || {}).id,
  bandeja: ({ inbox }) => (inbox || {}).name,
  fecha_hoy: context => formatDate(context.now || new Date(), context),
};

export const RESERVED_FIELDS = Object.keys(RESERVED);

// Primero el del contacto, luego el de la conversación.
const attribute = (key, context) =>
  [context.contact, context.conversation]
    .map(dueno =>
      plainText(((dueno || {}).custom_attributes || {})[key], context)
    )
    .find(Boolean) || '';

// El texto que va en el mensaje, o '' si no hay dato. Un reservado sin dato no busca atributos,
// y las variables numeradas ({{1}}) no se reconocen por nombre.
export const resolveVariable = (key, context = {}) => {
  if (!VALID_NAME.test(key)) return '';
  return RESERVED_FIELDS.includes(key)
    ? plainText(RESERVED[key](context), context)
    : attribute(key, context);
};

// { values: { edad: '34' }, missing: ['plan'] }, cada variable una vez.
export const resolveVariables = (keys, context = {}) => {
  const result = { values: {}, missing: [] };
  [...new Set(keys)].forEach(key => {
    const valor = resolveVariable(key, context);
    if (valor) result.values[key] = valor;
    else result.missing.push(key);
  });
  return result;
};
