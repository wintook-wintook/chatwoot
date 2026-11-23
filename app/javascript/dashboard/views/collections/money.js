// Cobranza: montos como «$15,000.00 MXN».
export const money = (amount, currency = 'MXN') =>
  `${new Intl.NumberFormat('es-MX', {
    style: 'currency',
    currency: 'MXN',
    minimumFractionDigits: 2,
  }).format(amount || 0)} ${currency}`;

export const BUCKETS = [
  'not_due',
  'd1_15',
  'd16_30',
  'd31_60',
  'd61_90',
  'd90_plus',
];

export const FIELDS = [
  'customer_key',
  'customer_name',
  'rfc',
  'contact_name',
  'phone',
  'email',
  'folio',
  'issued_on',
  'due_on',
  'total',
  'balance',
  'currency',
  'collector_email',
];

export const REQUIRED = ['customer_name', 'folio', 'due_on', 'balance'];

export const shortDate = value =>
  value
    ? new Date(
        String(value).length === 10 ? `${value}T12:00:00` : value
      ).toLocaleDateString('es-MX', {
        day: '2-digit',
        month: '2-digit',
        year: 'numeric',
      })
    : '—';
