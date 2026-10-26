// feat/bandejas_por_tipo — BANDEJAS AGRUPADAS POR TIPO EN EL MENÚ DE CONVERSACIONES
// ============================================================================
// Cada bandeja cae en un grupo según su canal; los grupos salen en el orden que el
// agente eligió en «Ordenar bandejas…» (ui_settings.inbox_group_order[accountId]) o,
// si no eligió, en DEFAULT_INBOX_GROUP_ORDER.
// Plan: docs/chat_interno_plan.md §10 (parte B)
// ============================================================================
import { INBOX_TYPES } from 'shared/mixins/inboxMixin';

export const INBOX_GROUPS = Object.freeze({
  INTERNAL: 'internal', // feat/chat_interno: las salas del chat interno
  WHATSAPP: 'whatsapp',
  TELEGRAM: 'telegram',
  EMAIL: 'email',
  META: 'meta',
  WEB: 'web',
  TIKTOK: 'tiktok',
  OTHERS: 'others',
});

// Orden por omisión: Interno (chat entre agentes), WhatsApp, Telegram, Correo, Meta y
// después todos los demás. «Interno» es la bandeja del chat entre agentes.
export const DEFAULT_INBOX_GROUP_ORDER = Object.freeze([
  INBOX_GROUPS.INTERNAL,
  INBOX_GROUPS.WHATSAPP,
  INBOX_GROUPS.TELEGRAM,
  INBOX_GROUPS.EMAIL,
  INBOX_GROUPS.META,
  INBOX_GROUPS.WEB,
  INBOX_GROUPS.TIKTOK,
  INBOX_GROUPS.OTHERS,
]);

export const UI_SETTINGS_KEY = 'inbox_group_order';

const GROUP_BY_TYPE = {
  [INBOX_TYPES.WHATSAPP]: INBOX_GROUPS.WHATSAPP,
  [INBOX_TYPES.TELEGRAM]: INBOX_GROUPS.TELEGRAM,
  [INBOX_TYPES.EMAIL]: INBOX_GROUPS.EMAIL,
  [INBOX_TYPES.FB]: INBOX_GROUPS.META,
  [INBOX_TYPES.INSTAGRAM]: INBOX_GROUPS.META,
  [INBOX_TYPES.WEB]: INBOX_GROUPS.WEB,
  [INBOX_TYPES.TIKTOK]: INBOX_GROUPS.TIKTOK,
  [INBOX_TYPES.INTERNAL]: INBOX_GROUPS.INTERNAL, // feat/chat_interno: la bandeja «Interno»
};

// Twilio es WhatsApp o SMS según su número («whatsapp:+52…»), igual que el icono.
export const inboxGroupFor = inbox => {
  const type = inbox && inbox.channel_type;
  if (type === INBOX_TYPES.TWILIO) {
    const phone = (inbox.phone_number || '').toString();
    const isWhatsapp =
      inbox.medium === 'whatsapp' || phone.startsWith('whatsapp');
    return isWhatsapp ? INBOX_GROUPS.WHATSAPP : INBOX_GROUPS.OTHERS;
  }
  return GROUP_BY_TYPE[type] || INBOX_GROUPS.OTHERS;
};

// Un orden guardado puede venir viejo o roto: se quitan los grupos que ya no existen
// y los que falten se agregan al final. «Interno» llegó después: si falta, va primero.
export const normalizeGroupOrder = saved => {
  const known = Object.values(INBOX_GROUPS);
  const valid = (Array.isArray(saved) ? saved : []).filter(
    (group, index, list) =>
      known.includes(group) && list.indexOf(group) === index
  );
  const missing = DEFAULT_INBOX_GROUP_ORDER.filter(
    group => !valid.includes(group) && group !== INBOX_GROUPS.INTERNAL
  );
  const internal = valid.includes(INBOX_GROUPS.INTERNAL)
    ? []
    : [INBOX_GROUPS.INTERNAL];
  return [...internal, ...valid, ...missing];
};

// El orden del agente para esta cuenta (o el de omisión).
export const groupOrderFromUISettings = (uiSettings, accountId) => {
  const byAccount = (uiSettings && uiSettings[UI_SETTINGS_KEY]) || {};
  return normalizeGroupOrder(byAccount[accountId]);
};

// [{ key, inboxes: [...] }] en el orden pedido, sin grupos vacíos; dentro de cada
// grupo las bandejas siguen ordenadas por nombre (como antes).
export const groupInboxes = (inboxes, order) => {
  const buckets = {};
  (inboxes || []).forEach(inbox => {
    const key = inboxGroupFor(inbox);
    (buckets[key] = buckets[key] || []).push(inbox);
  });
  const byName = (a, b) =>
    (a.name || '').toLowerCase().localeCompare((b.name || '').toLowerCase());
  return normalizeGroupOrder(order)
    .filter(key => buckets[key] && buckets[key].length)
    .map(key => ({ key, inboxes: buckets[key].sort(byName) }));
};

// ── Acordeón del menú: un solo grupo abierto ─────────────────────────────────
// chosen: '' = el agente aún no elige (abre el primero), null = todos cerrados,
// 'meta' = el que abrió.
export const resolveOpenGroup = (chosen, groups) => {
  if (chosen !== '') return chosen;
  return groups && groups.length ? groups[0].key : null;
};

// Abrir uno cierra los demás; volver a tocar el abierto lo cierra.
export const toggleOpenGroup = (openKey, clickedKey) =>
  openKey === clickedKey ? null : clickedKey;
