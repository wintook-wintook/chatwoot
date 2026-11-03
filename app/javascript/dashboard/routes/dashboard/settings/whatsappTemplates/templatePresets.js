// feat/plantillas_whatsapp_mejoras F10.5 — EMPEZAR DESDE UN EJEMPLO
// ============================================================================
// Plan: docs/plantillas_whatsapp_mejoras_plan.md §7.12 (D10a). Plantillas de arranque para
// el editor; todo se puede cambiar. Las ligas y los archivos van vacíos a propósito: los
// pone el usuario (el validador los pide), para que no llegue a Meta nada inventado.
// Son funciones: cada uso arranca con objetos nuevos.
// ============================================================================
import { emptyButton, emptyForm } from './templateEditor';

const boton = (type, datos) => ({ ...emptyButton(type), ...datos });

export const PRESETS = {
  PAYMENT: () => ({
    name: 'recordatorio_pago',
    category: 'UTILITY',
    header_type: 'document',
    body_text:
      'Hola {{1}}, tu pago de {{2}} vence el {{3}}. Si ya lo hiciste, ignora este mensaje.',
    footer_text: '',
    buttons: [boton('URL', { text: 'Ver estado de cuenta' })],
    sample_values: { body: ['Juan', '$1,250', '5 de noviembre'], header: [] },
  }),
  APPOINTMENT: () => ({
    name: 'confirmacion_cita',
    category: 'UTILITY',
    header_type: 'text',
    header_content: 'Confirma tu cita',
    body_text:
      'Hola {{1}}, te recordamos tu cita del {{2}} a las {{3}}. ¿Nos confirmas tu asistencia?',
    footer_text: '',
    buttons: [
      boton('QUICK_REPLY', { text: 'Confirmar' }),
      boton('QUICK_REPLY', { text: 'Cambiar fecha' }),
    ],
    sample_values: { body: ['Juan', '5 de noviembre', '10:00'], header: [] },
  }),
  PROMO: () => ({
    name: 'promocion_imagen',
    category: 'MARKETING',
    header_type: 'image',
    body_text:
      'Hola {{1}}, tienes {{2}} de descuento en tu próxima compra. Usa el código del botón antes de que termine el mes.',
    footer_text: '',
    buttons: [boton('COPY_CODE', { example: ['PROMO10'] })],
    sample_values: { body: ['Juan', '10%'], header: [] },
  }),
};

export const PRESET_KEYS = Object.keys(PRESETS);

// El formulario del ejemplo, conservando la bandeja y el idioma ya elegidos.
export const applyPreset = (form, clave) => ({
  ...emptyForm(),
  inbox_id: form.inbox_id,
  language: form.language,
  ...(PRESETS[clave] ? PRESETS[clave]() : {}),
});
