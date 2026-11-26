// Campaña con Vendedor IA por WhatsApp — de dónde sale cada variable de la plantilla (como
// TrackingCampaigns::TemplateVars) y con qué se ve llena en la pantalla.
export const VAR_SOURCES = [
  'contact_first_name',
  'contact_name',
  'contact_company',
  'offer_what',
  'event_name',
  'event_date',
  'event_place',
  'last_purchase',
  'due_what',
  'due_date',
  'due_amount',
  'text',
];

const VAR = /\{\{\s*([\w.]+)\s*\}\}/g;

// Las variables del texto de la plantilla, en orden y sin repetir: ['1', '2'] o ['nombre', 'fecha'].
export const templateVariables = text => [
  ...new Set([...(text || '').matchAll(VAR)].map(m => m[1])),
];

// Lo que la pantalla usa como ejemplo para cada origen.
export const sampleValues = (brief = {}, event = null) => ({
  contact_first_name: 'Mario',
  contact_name: 'Mario López',
  contact_company: 'Grúas del Norte',
  offer_what: (brief.offer_what || '').trim(),
  // De cada contacto (TrackingCampaigns::ContactFacts): ejemplos.
  last_purchase: 'Mantenimiento de minisplit',
  due_what: 'Póliza anual',
  due_date: '30 de noviembre',
  due_amount: '$1,800 MXN',
  event_name: event?.name || '',
  event_date: event?.starts_at
    ? new Date(event.starts_at).toLocaleString([], {
        weekday: 'long',
        day: 'numeric',
        month: 'long',
        hour: '2-digit',
        minute: '2-digit',
      })
    : '',
  event_place: event?.location || '',
});

// Una idea razonable de inicio: {{1}} o {{nombre}} es el nombre del contacto; las demás, texto fijo.
export const guessSource = (variable, index) => {
  const key = String(variable).toLowerCase();
  if (index === 0 || ['nombre', 'name', 'contacto'].includes(key))
    return 'contact_first_name';
  if (['empresa', 'company'].includes(key)) return 'contact_company';
  if (['oferta', 'producto', 'promo', 'promocion'].includes(key))
    return 'offer_what';
  if (['fecha', 'date'].includes(key)) return 'event_date';
  if (['lugar', 'place'].includes(key)) return 'event_place';
  if (['evento', 'event'].includes(key)) return 'event_name';
  if (['monto', 'saldo', 'importe'].includes(key)) return 'due_amount';
  if (['vence', 'vencimiento'].includes(key)) return 'due_date';
  if (['compra', 'ultima_compra', 'producto_anterior'].includes(key))
    return 'last_purchase';
  return 'text';
};

// El texto con sus variables llenas (las que no tienen dato quedan como [variable]).
// Sin regla todavía, la idea de inicio (guessSource): {{1}} es el nombre del contacto.
export const fillTemplate = (text, rules = {}, samples = {}) => {
  const order = templateVariables(text);
  return (text || '').replace(VAR, (_m, variable) => {
    const rule = rules[variable] || {
      source: guessSource(variable, order.indexOf(variable)),
    };
    const value =
      rule.source === 'text' || !rule.source ? rule.text : samples[rule.source];
    return value || `[${variable}]`;
  });
};

// {{contacto}}, {{empresa}}, {{oferta}} y, de cada contacto, {{ultima_compra}}, {{que_vence}}, {{vence}} y {{monto}}
// en la apertura escrita y en la información completa (como Motor2::CampaignTouch.fill).
export const fillCampaignText = (text, samples = {}) =>
  (text || '')
    .replace(/\{\{\s*contacto\s*\}\}/gi, samples.contact_first_name || '')
    .replace(/\{\{\s*empresa\s*\}\}/gi, samples.contact_company || '')
    .replace(/\{\{\s*oferta\s*\}\}/gi, samples.offer_what || '')
    .replace(/\{\{\s*ultima_compra\s*\}\}/gi, samples.last_purchase || '')
    .replace(/\{\{\s*que_vence\s*\}\}/gi, samples.due_what || '')
    .replace(/\{\{\s*vence\s*\}\}/gi, samples.due_date || '')
    .replace(/\{\{\s*monto\s*\}\}/gi, samples.due_amount || '');

// Una «huella» corta de lo que se prueba (la campaña en pantalla): si cambia, los Casos ya corridos quedan viejos.
export const signatureOf = value => {
  const text = JSON.stringify(value || {});
  let hash = 5381;
  for (let i = 0; i < text.length; i += 1) {
    // eslint-disable-next-line no-bitwise
    hash = ((hash << 5) + hash + text.charCodeAt(i)) | 0;
  }
  return String(hash);
};
