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
