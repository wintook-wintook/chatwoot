// feat/plantillas_whatsapp_mejoras F10 — EL FORMULARIO DEL EDITOR DE PLANTILLAS
// ============================================================================
// Plan: docs/plantillas_whatsapp_mejoras_plan.md §7.12. Funciones puras del editor a
// página completa (antes vivían en el modal de Index.vue): el formulario vacío, el que
// sale de una plantilla guardada, lo que se manda al servidor y los ejemplos de las
// variables. La validación sigue en dashboard/helper/whatsappTemplateValidator.js.
// ============================================================================
import { templateVariables } from 'dashboard/helper/whatsappTemplateValidator';

export const CATEGORIES = ['UTILITY', 'MARKETING', 'AUTHENTICATION'];
export const HEADER_TYPES = ['', 'text', 'image', 'video', 'document'];
export const MEDIA_HEADER_TYPES = ['image', 'video', 'document'];
export const BUTTON_TYPES = ['QUICK_REPLY', 'URL', 'PHONE_NUMBER', 'COPY_CODE'];
export const LANGUAGES = [
  'es',
  'es_MX',
  'es_AR',
  'es_ES',
  'en',
  'en_US',
  'pt_BR',
];
// Lo que Meta acepta como muestra del encabezado (Whatsapp::ResumableUploadService::LIMITS).
export const ACCEPTED_TYPES = {
  image: 'image/jpeg,image/png',
  video: 'video/mp4,video/3gpp',
  document: 'application/pdf',
};

export const emptyForm = () => ({
  inbox_id: null,
  name: '',
  language: 'es',
  category: 'UTILITY',
  header_type: 'text',
  header_content: '',
  header_media_url: '',
  // El archivo subido (signed_id que se manda), su nombre y una liga para la vista previa.
  header_sample: null,
  header_sample_name: '',
  header_preview_url: '',
  body_text: '',
  footer_text: '',
  buttons: [],
  sample_values: { body: [], header: [] },
});

export const emptyButton = (type = 'QUICK_REPLY') => ({
  type,
  text: '',
  url: '',
  phone_number: '',
  example: [],
});

// El formulario de una plantilla guardada: el archivo ya guardado se ve, pero solo se
// manda si se sube otro.
export const formFromTemplate = template => {
  const samples = template.sample_values || {};
  return {
    ...emptyForm(),
    ...template,
    header_type: template.header_type || '',
    header_content: template.header_content || '',
    header_media_url: template.header_media_url || '',
    footer_text: template.footer_text || '',
    sample_values: {
      body: samples.body || [],
      header: samples.header || [],
    },
    buttons: (template.buttons || []).map(b => ({ ...emptyButton(), ...b })),
    header_sample: null,
    header_sample_name:
      (template.header_sample && template.header_sample.filename) || '',
    header_preview_url: template.header_media_link || '',
  };
};

const SERVER_FIELDS = [
  'name',
  'category',
  'language',
  'header_type',
  'header_content',
  'header_media_url',
  'header_sample',
  'body_text',
  'footer_text',
  'buttons',
  'sample_values',
];

// Lo que se manda: solo los campos que acepta el servidor; el archivo subido solo si se
// subió uno nuevo (un null lo borraría).
export const templatePayload = form => {
  const payload = {};
  SERVER_FIELDS.forEach(campo => {
    payload[campo] = form[campo];
  });
  if (!payload.header_sample) delete payload.header_sample;
  return payload;
};

// La regla de Meta para el nombre: minúsculas, espacios → _, sin acentos ni símbolos.
export const sanitizeName = val =>
  String(val || '')
    .toLowerCase()
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .replace(/\s+/g, '_')
    .replace(/[^a-z0-9_]/g, '')
    .slice(0, 512);

// Un ejemplo por variable distinta, conservando los ya escritos.
export const syncSamples = (current, text) => {
  const count = new Set(templateVariables(text)).size;
  return Array.from({ length: count }, (_, i) => (current || [])[i] || '');
};

// Autenticación no se crea aquí (formato fijo de Meta); solo aparece si la plantilla ya la
// tiene, para que el validador diga por qué.
export const formCategories = category =>
  category === 'AUTHENTICATION'
    ? CATEGORIES
    : CATEGORIES.filter(c => c !== 'AUTHENTICATION');

// Los idiomas de Meta, más el de la plantilla si no está en la lista.
export const languageOptions = current =>
  current && !LANGUAGES.includes(current) ? [current, ...LANGUAGES] : LANGUAGES;

// Botones que Meta revisa con un ejemplo: copiar código y liga con {{1}}.
export const needsButtonExample = boton =>
  boton.type === 'COPY_CODE' ||
  (boton.type === 'URL' && templateVariables(boton.url).length > 0);

export const buttonExample = boton =>
  (Array.isArray(boton.example) ? boton.example[0] : boton.example) || '';

// Un borrador que nunca llegó a Meta: también se cambian nombre e idioma (la bandeja no).
export const isLocalDraft = template =>
  Boolean(template && template.status === 'DRAFT' && template.local_only);

// ---- Botones (F10.3) --------------------------------------------------------
// Los topes de Meta por tipo (además del total de 10). Las respuestas rápidas van
// siempre antes que las acciones: el editor las muestra en dos grupos y así se guardan.
export const MAX_BUTTONS = 10;
export const BUTTON_LIMITS = { URL: 2, PHONE_NUMBER: 1, COPY_CODE: 1 };
export const MAX_BUTTON_TEXT = 25;
const VARIABLE_RE = /\{\{\s*\d+\s*\}\}/g;

export const isQuickReply = boton => boton.type === 'QUICK_REPLY';

// ¿Se puede agregar otro de este tipo? null = sí; si no, el motivo ('TOTAL' o el tipo).
export const addButtonBlocker = (buttons, type) => {
  if (buttons.length >= MAX_BUTTONS) return 'TOTAL';
  const tope = BUTTON_LIMITS[type];
  if (tope && buttons.filter(b => b.type === type).length >= tope) return type;
  return null;
};

// Un botón nuevo del tipo, con lo que ya se sabe (el teléfono arranca con la lada de México).
export const newButton = type => ({
  ...emptyButton(type),
  phone_number: type === 'PHONE_NUMBER' ? '+52' : '',
});

// Las respuestas rápidas primero (lo que pide Meta), cada grupo en su orden.
export const orderButtons = buttons => [
  ...buttons.filter(isQuickReply),
  ...buttons.filter(b => !isQuickReply(b)),
];

// Liga «fija» o «termina con un dato del cliente» ({{1}} al final, como pide Meta).
export const isDynamicUrl = boton =>
  templateVariables(boton.url || '').length > 0;

export const urlBase = boton =>
  String(boton.url || '').replace(VARIABLE_RE, '');

export const buildUrl = (base, dynamic) =>
  dynamic ? `${String(base || '').replace(VARIABLE_RE, '')}{{1}}` : base;

// El teléfono debe llevar la lada del país (+52…).
export const phoneNeedsCountryCode = telefono =>
  Boolean(telefono) && !/^\+\d{6,}$/.test(String(telefono).replace(/\s/g, ''));

// ---- Mensaje (F10.2) --------------------------------------------------------
// La siguiente variable libre: {{1}} si no hay, si no la mayor + 1 (sin huecos que Meta
// rechace).
export const nextVariable = text => {
  const nums = templateVariables(text);
  return `{{${nums.length ? Math.max(...nums) + 1 : 1}}}`;
};

// Pone `snippet` en lugar de la selección [start, end) y deja el cursor después.
export const insertAt = (text, start, end, snippet) => {
  const base = String(text || '');
  return {
    text: base.slice(0, start) + snippet + base.slice(end),
    cursor: start + snippet.length,
  };
};

// Formato de WhatsApp: *negrita*, _cursiva_, ~tachado~, ```código```.
export const FORMAT_MARKERS = {
  BOLD: '*',
  ITALIC: '_',
  STRIKE: '~',
  CODE: '```',
};

// Envuelve la selección con la marca; sin selección deja las dos marcas y el cursor en medio.
export const wrapSelection = (text, start, end, marker) => {
  const base = String(text || '');
  const elegido = base.slice(start, end);
  return {
    text: base.slice(0, start) + marker + elegido + marker + base.slice(end),
    selectionStart: start + marker.length,
    selectionEnd: end + marker.length,
  };
};

// «Lista para Meta» por pestaña: los errores del validador según su prefijo.
export const errorsByTab = errors => {
  const pestanas = { content: [], buttons: [], variables: [] };
  errors.forEach(error => {
    if (/^Bot(ón|ones)/.test(error)) pestanas.buttons.push(error);
    else if (/^Ejemplos/.test(error)) pestanas.variables.push(error);
    else pestanas.content.push(error);
  });
  return pestanas;
};

// ---- Aviso al salir (F10.3) -------------------------------------------------
// Lo que importa para saber si hay cambios sin guardar: lo que se manda y la bandeja.
export const formSnapshot = form =>
  JSON.stringify({ ...templatePayload(form), inbox_id: form.inbox_id });

// ---- Duplicar (F10.4) -------------------------------------------------------
// La copia de una plantilla: todo igual (también el archivo subido) con «_copia» en el
// nombre, en la misma bandeja, como plantilla nueva.
export const duplicateForm = (template, inboxId) => {
  const form = formFromTemplate(template);
  const archivo = template.header_sample || {};
  const copia = { ...emptyForm(), inbox_id: inboxId || null };
  SERVER_FIELDS.forEach(campo => {
    copia[campo] = form[campo];
  });
  return {
    ...copia,
    name: sanitizeName(`${template.name}_copia`),
    header_sample: archivo.signed_id || null,
    header_sample_name: form.header_sample_name,
    header_preview_url: form.header_preview_url,
  };
};

// ---- Nombre repetido (F10.5) ------------------------------------------------
// Otra plantilla con ese nombre e idioma en la misma bandeja: Meta la rechazaría y el
// servidor reutiliza esa fila, así que una aprobada podría quedar como borrador.
export const nameTaken = (templates, { id, name, language, channelId }) =>
  templates.some(
    t =>
      t.id !== id &&
      t.name === name &&
      t.language === language &&
      t.channel_whatsapp_id === channelId
  );
