// @tickets_cases — Modo simple (osTicket) vs ITIL
// Mapa de los 13 estados ITIL a los 6 estados "simples" estilo osTicket, y los
// conjuntos de estados que la UI ofrece/filtra cuando el modo simple está activo.
// El backend NO se restringe: esto es solo presentación.

// Estado real (DB) → estado simple equivalente (para mostrar etiquetas/badges).
export const SIMPLE_STATUS_MAP = {
  open: 'open',
  classified: 'in_progress',
  assigned: 'in_progress',
  in_diagnosis: 'in_progress',
  in_progress: 'in_progress',
  escalated: 'in_progress',
  waiting_on_customer: 'waiting_on_customer',
  waiting_on_third_party: 'waiting_on_customer',
  waiting_on_internal: 'waiting_on_customer',
  resolved: 'resolved',
  validating: 'resolved',
  closed: 'closed',
  cancelled: 'cancelled',
};

// Estados visibles en filtros (listado) en modo simple.
export const SIMPLE_FILTER_STATUSES = [
  'open',
  'in_progress',
  'waiting_on_customer',
  'resolved',
  'closed',
  'cancelled',
];

// Estados que el dropdown de "cambiar estado" ofrece como destino en modo simple.
export const SIMPLE_TRANSITION_TARGETS = [
  'in_progress',
  'waiting_on_customer',
  'resolved',
  'closed',
  'cancelled',
];

// Colapsa un estado real a su equivalente simple (o lo deja igual si no mapea).
export const toSimpleStatus = status => SIMPLE_STATUS_MAP[status] || status;
