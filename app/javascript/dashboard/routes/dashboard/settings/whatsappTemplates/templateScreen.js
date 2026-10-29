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

// { conversation: true|false|null, trackings: 'ok'|'missing_file'|'no'|null }
// null = todavía no se puede mandar por nada (no está aprobada).
export function sendability(template, inbox) {
  if (template.status !== 'APPROVED')
    return { conversation: null, trackings: null };
  const conArchivo = MEDIA_TYPES.includes(template.header_type);
  if (!conArchivo) return { conversation: true, trackings: 'ok' };

  const cloud = Boolean(inbox && inbox.provider === 'whatsapp_cloud');
  if (!cloud) return { conversation: false, trackings: 'no' };
  return {
    conversation: true,
    trackings: hasFile(template) ? 'ok' : 'missing_file',
  };
}

export function metaManagerUrl(inbox) {
  const config = (inbox && inbox.provider_config) || {};
  const waba = config.business_account_id;
  if (!waba) return null;
  return `https://business.facebook.com/wa/manage/message-templates/?waba_id=${encodeURIComponent(
    waba
  )}`;
}
