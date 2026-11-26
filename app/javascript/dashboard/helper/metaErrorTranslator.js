// diag/waba F4 (D7) — el error de Meta de un mensaje fallido, en palabras del usuario.
// Mismos códigos que Whatsapp::ErrorTranslator (servidor). Llega como «131047: título» (aviso de
// estado) o como el JSON de la respuesta del envío. Si el código no se reconoce se regresa el
// texto tal cual (no afecta errores de correo u otros canales).
const KEYS = {
  WINDOW_24H: [131047, 470],
  NOT_ON_WHATSAPP: [131026],
  PAYMENT: [131042],
  ECOSYSTEM: [131049, 131050],
  UNSUPPORTED: [131051],
  TEMPLATE: Array.from({ length: 17 }, (_, i) => 132000 + i),
  RATE_LIMIT: [130429, 131056, 80007],
  TOKEN: [190],
  BLOCKED: [131031, 368],
};

const CODE_TO_KEY = Object.entries(KEYS).reduce((map, [key, codes]) => {
  codes.forEach(code => {
    map[code] = key;
  });
  return map;
}, {});

export const parseMetaError = raw => {
  const text = String(raw || '').trim();
  if (text.startsWith('{')) {
    try {
      const error = JSON.parse(text).error || {};
      const details = error.error_data && error.error_data.details;
      return {
        code: Number(error.code) || null,
        title: details || error.message || '',
      };
    } catch {
      return { code: null, title: text };
    }
  }
  const match = text.match(/^(\d+)\s*:\s*([\s\S]*)$/);
  return match
    ? { code: Number(match[1]), title: match[2].trim() }
    : { code: null, title: text };
};

// t = this.$t. → texto claro + «(Meta <código>)», o el original si no se reconoce.
export const translateMetaError = (raw, t) => {
  if (!raw) return '';
  const { code, title } = parseMetaError(raw);
  const key = CODE_TO_KEY[code];
  if (!key) return String(raw);
  const message = t(`WHATSAPP_HEALTH.ERRORS.${key}`, { title });
  return `${message} ${t('WHATSAPP_HEALTH.ERRORS.META_CODE', { code })}`;
};
