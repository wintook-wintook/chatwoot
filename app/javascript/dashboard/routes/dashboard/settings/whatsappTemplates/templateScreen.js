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

const VARIABLE_RE = /\{\{\s*\d+\s*\}\}/;

// Lleva un dato fuera del cuerpo: variable en el encabezado de texto, liga con {{1}} o
// copiar código.
function needsMoreThanBody(template) {
  const botones = template.buttons || [];
  return (
    (template.header_type === 'text' &&
      VARIABLE_RE.test(template.header_content || '')) ||
    botones.some(b => {
      const tipo = (b.type || '').toUpperCase();
      return (
        tipo === 'COPY_CODE' ||
        (tipo === 'URL' && VARIABLE_RE.test(b.url || ''))
      );
    })
  );
}

// { conversation: true|false|null, trackings: 'ok'|'missing_file'|'no'|null }
// null = todavía no se puede mandar por nada (no está aprobada).
export function sendability(template, inbox) {
  if (template.status !== 'APPROVED')
    return { conversation: null, trackings: null };
  const conArchivo = MEDIA_TYPES.includes(template.header_type);
  const cloud = Boolean(inbox && inbox.provider === 'whatsapp_cloud');
  // Fuera de WhatsApp Cloud solo sale el cuerpo: las que piden un dato en el encabezado
  // o en un botón tampoco se pueden mandar (el selector las oculta).
  if (!conArchivo && (cloud || !needsMoreThanBody(template)))
    return { conversation: true, trackings: 'ok' };
  if (!cloud) return { conversation: false, trackings: 'no' };
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
