// feat/plantillas_whatsapp_mejoras F6 — LA PANTALLA DE PLANTILLAS
// ============================================================================
// Plan: docs/plantillas_whatsapp_mejoras_plan.md §4 (F6). Funciones puras sobre una fila
// de whatsapp_templates (lo que devuelve el controlador) y su bandeja (inbox):
//
//   templateKinds    los tipos de la plantilla, para el filtro: texto, imagen, video,
//                    documento, con botones, copiar código
//   sendability      ¿se puede mandar? en la conversación (F2: las de archivo solo en
//                    WhatsApp Cloud) y en seguimientos/campañas (F5: las de archivo
//                    necesitan el archivo guardado)
//   metaManagerUrl   la página de plantillas de la cuenta en WhatsApp Manager
// ============================================================================
import { variableKeys } from 'dashboard/helper/whatsappTemplateValidator';

export const MEDIA_TYPES = ['image', 'video', 'document'];

export const KIND_OPTIONS = [
  { value: 'text', label: 'Solo texto' },
  { value: 'image', label: 'Con imagen' },
  { value: 'video', label: 'Con video' },
  { value: 'document', label: 'Con documento' },
  { value: 'buttons', label: 'Con botones' },
  { value: 'copy_code', label: 'Con copiar código' },
];

export function templateKinds(template) {
  const tipo = template.header_type || '';
  const botones = template.buttons || [];
  const kinds = [MEDIA_TYPES.includes(tipo) ? tipo : 'text'];
  if (botones.length) kinds.push('buttons');
  if (botones.some(b => (b.type || '').toUpperCase() === 'COPY_CODE'))
    kinds.push('copy_code');
  return kinds;
}

const hasFile = template =>
  Boolean(
    template.header_sample ||
      template.header_media_link ||
      template.header_media_url
  );

const VARIABLE_RE = /\{\{\s*[^{}]+?\s*\}\}/;
const templateIsNamed = text =>
  variableKeys(text).some(clave => !/^\d+$/.test(clave));

const hasHeaderVariable = template =>
  template.header_type === 'text' &&
  VARIABLE_RE.test(template.header_content || '');

const hasButtonData = template =>
  (template.buttons || []).some(b => {
    const tipo = (b.type || '').toUpperCase();
    return (
      tipo === 'COPY_CODE' || (tipo === 'URL' && VARIABLE_RE.test(b.url || ''))
    );
  });

// Lleva un dato fuera del cuerpo: variable en el encabezado de texto, liga con {{1}} o
// copiar código.
function needsMoreThanBody(template) {
  return hasHeaderVariable(template) || hasButtonData(template);
}

// { conversation: true|false|null,
//   trackings: 'ok'|'missing_file'|'needs_data'|'no'|null }
// null = todavía no se puede mandar por nada (no está aprobada).
// needs_data: pide un dato en el encabezado o en un botón que seguimientos y campañas no
// llenan (solo mandan el cuerpo y el archivo): Meta la rechazaría. El encabezado con nombres
// sí lo llenan (F9.3).
export function sendability(template, inbox) {
  if (template.status !== 'APPROVED')
    return { conversation: null, trackings: null };
  const conArchivo = MEDIA_TYPES.includes(template.header_type);
  const cloud = Boolean(inbox && inbox.provider === 'whatsapp_cloud');
  // Fuera de WhatsApp Cloud solo sale el cuerpo: las que piden un dato en el encabezado
  // o en un botón tampoco se pueden mandar (el selector las oculta).
  const pideDato = needsMoreThanBody(template);
  if (!cloud && (conArchivo || pideDato))
    return { conversation: false, trackings: 'no' };
  const encabezadoConNumero =
    hasHeaderVariable(template) &&
    !templateIsNamed(template.header_content || '');
  if (hasButtonData(template) || encabezadoConNumero)
    return { conversation: true, trackings: 'needs_data' };
  if (!conArchivo) return { conversation: true, trackings: 'ok' };
  return {
    conversation: true,
    trackings: hasFile(template) ? 'ok' : 'missing_file',
  };
}

// feat/plantillas_whatsapp_mejoras F10.4 — los pasos del estado en Meta para la ficha:
// [{ key, state: 'done' | 'current' | 'pending' | 'failed' | 'warning' }]
export function statusSteps(status) {
  const paso = (key, state) => ({ key, state });
  if (status === 'DRAFT')
    return [
      paso('DRAFT', 'current'),
      paso('PENDING', 'pending'),
      paso('RESULT', 'pending'),
    ];
  if (status === 'PENDING')
    return [
      paso('SUBMITTED', 'done'),
      paso('PENDING', 'current'),
      paso('RESULT', 'pending'),
    ];
  const tercero = {
    APPROVED: paso('APPROVED', 'done'),
    REJECTED: paso('REJECTED', 'failed'),
    PAUSED: paso('PAUSED', 'warning'),
    DISABLED: paso('DISABLED', 'failed'),
    IN_APPEAL: paso('IN_APPEAL', 'warning'),
    PENDING_DELETION: paso('PENDING_DELETION', 'warning'),
  }[status];
  return [
    paso('SUBMITTED', 'done'),
    paso('REVIEWED', 'done'),
    tercero || paso('RESULT', 'pending'),
  ];
}

// Los motivos de rechazo que manda Meta (rejected_reason) con explicación propia; el
// resto se muestra tal cual.
export const KNOWN_REJECTIONS = [
  'ABUSIVE_CONTENT',
  'INCORRECT_CATEGORY',
  'INVALID_FORMAT',
  'PROMOTIONAL',
  'SCAM',
  'TAG_CONTENT_MISMATCH',
];

export const rejectionKey = reason => {
  const clave = String(reason || '').toUpperCase();
  return KNOWN_REJECTIONS.includes(clave) ? clave : null;
};

export function metaManagerUrl(inbox) {
  const config = (inbox && inbox.provider_config) || {};
  const waba = config.business_account_id;
  if (!waba) return null;
  return `https://business.facebook.com/wa/manage/message-templates/?waba_id=${encodeURIComponent(
    waba
  )}`;
}

// feat/plantillas_whatsapp_mejoras F10 — ordenar la lista al hacer clic en una columna.
// key: 'name' | 'channel' | 'language' | 'category' | 'status' | 'created_at' | 'updated_at'
// (por omisión, la última actualización primero). channelName(t) da el nombre de su bandeja.
const DATE_KEYS = ['created_at', 'updated_at'];

export function sortTemplates(templates, { key, dir }, channelName = () => '') {
  const valor = t => {
    if (key === 'channel') return channelName(t) || '';
    if (DATE_KEYS.includes(key)) return t[key] ? new Date(t[key]).getTime() : 0;
    return String(t[key] || '');
  };
  const signo = dir === 'asc' ? 1 : -1;
  return [...templates].sort((a, b) => {
    const va = valor(a);
    const vb = valor(b);
    const cmp =
      typeof va === 'number'
        ? va - vb
        : va.localeCompare(vb, 'es', { sensitivity: 'base' });
    return cmp * signo || String(a.name).localeCompare(String(b.name));
  });
}

// ¿Hay algo que deje de funcionar al borrarla? (lo que devuelve GET templates/:id/usage)
export const templateInUse = usage =>
  Boolean(usage) &&
  (usage.agents.length > 0 ||
    usage.trackings_count > 0 ||
    usage.campaigns.length > 0 ||
    usage.scheduled_count > 0 ||
    usage.portals.length > 0);
