// CrmZeus — lo común de las pantallas de organizaciones y catálogos.
import { areaLevel, getUserAccess } from 'dashboard/helper/accessHelper';

export const LOOKUP_KINDS = [
  'customer_type',
  'rating',
  'industry',
  'origin',
  'zone',
  'collector',
];

// Catálogos de crm_lookups que usan los artículos (no salen en el formulario de organizaciones).
export const ARTICLE_LOOKUP_KINDS = ['price_list', 'line_group'];

export const ADDRESS_FIELDS = [
  'street',
  'exterior_number',
  'interior_number',
  'neighborhood',
  'town',
  'reference',
  'postal_code',
];

// Lo mismo que el backend: Ventas para ver, Ventas con escritura para editar.
export const crmAccess = (user, accountId) => {
  const access = getUserAccess(user, accountId);
  return {
    canEdit: ['own', 'all'].includes(areaLevel(access, 'sales')),
    isAdmin: access.role === 'administrator',
  };
};

export const errorMessage = (error, fallback) =>
  error?.response?.data?.message || error?.response?.data?.error || fallback;

export const defaultId = items =>
  (items.find(item => item.is_default) || {}).id || null;

export const blankAddress = () => ({
  consignee_name: '',
  street: '',
  exterior_number: '',
  interior_number: '',
  neighborhood: '',
  town: '',
  reference: '',
  city_id: null,
  city: '',
  postal_code: '',
  tax_id: '',
  phone: '',
  phone2: '',
  email: '',
  contact_name: '',
  for_billing: false,
});

// CrmZeus Q2 — color del estatus de una cotización (N/E/P/C de CRMZeus).
export const QUOTE_STATUS_BADGES = {
  pending:
    'bg-amber-50 text-amber-800 dark:bg-amber-900/30 dark:text-amber-300',
  won: 'bg-green-50 text-green-800 dark:bg-green-900/30 dark:text-green-300',
  lost: 'bg-red-50 text-red-800 dark:bg-red-900/30 dark:text-red-300',
  cancelled:
    'bg-slate-100 text-slate-600 dark:bg-slate-700 dark:text-slate-300',
};

// 'YYYY-MM-DD' + días, sin brincos por zona horaria.
export const addDays = (isoDate, days) => {
  if (!isoDate) return '';
  const date = new Date(`${isoDate}T00:00:00`);
  date.setDate(date.getDate() + Number(days || 0));
  const pad = n => String(n).padStart(2, '0');
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(
    date.getDate()
  )}`;
};

// CrmZeus Q3 — kits en la cotización. Como CRMZeus: solo un kit NO almacenable se desglosa
// (rol kit); un kit almacenable se cotiza como artículo normal. Cada componente guarda sus
// unidades totales (unidades por kit × cantidad del kit); `units_per_kit` vive solo en el
// navegador para recalcularlas cuando cambia la cantidad del kit.
export const isQuotableKit = article =>
  Boolean(article && article.is_kit && !article.is_stockable);

const round5 = value => Math.round(Number(value) * 100000) / 100000;

export const kitComponentRows = (article, kitQuantity) =>
  (article.components || []).map(row => ({
    role: 'component',
    article_id: row.component_id,
    key: row.key || '',
    description: row.name,
    unit: row.unit || '',
    units_per_kit: Number(row.quantity),
    quantity: round5(Number(row.quantity) * Number(kitQuantity || 0)),
    replaceable: Boolean(row.replaceable),
    units_editable: Boolean(row.units_editable),
    tax_ids: [],
  }));

// Componentes que vienen de la API (sin `units_per_kit`): se deduce de la cantidad del kit.
export const withUnitsPerKit = (components, kitQuantity) =>
  (components || []).map(row => ({
    ...row,
    units_per_kit:
      row.units_per_kit ??
      (Number(kitQuantity) ? round5(row.quantity / Number(kitQuantity)) : 0),
  }));

export const scaleComponents = (components, kitQuantity) =>
  (components || []).map(row => ({
    ...row,
    quantity: round5(Number(row.units_per_kit) * Number(kitQuantity || 0)),
  }));

// Q3.1 — de los impuestos de un artículo, los que aplican a la organización: los
// trasladados solo si cobra impuestos y las retenciones solo si retiene.
export const isWithholding = tax => tax.tax_type.endsWith('withholding');

const round2 = value =>
  Math.round((Number(value) + Number.EPSILON) * 100) / 100;

// Q3.1 — precio e importe con impuesto que enseña el modal, como CRMZeus (`config.js`
// PRECIO_IMPTO / IMPORTE_IMPTO). Solo informativos: los importes guardados los calcula el
// servidor. Solo suman los trasladados, sin restar retenciones, y redondean la base y el
// impuesto por separado. El importe no considera el descuento extra del encabezado.
const transferredPercent = (taxIds, taxes) =>
  taxes
    .filter(tax => taxIds.includes(tax.id) && !isWithholding(tax))
    .reduce((sum, tax) => sum + Number(tax.percent), 0);

const withTaxes = (base, percent) =>
  (base + round2((base * percent) / 100)).toFixed(2);

export const priceWithTaxes = (price, taxIds, taxes) =>
  withTaxes(round2(price || 0), transferredPercent(taxIds, taxes));

// Importe de la partida como `Crm::QuoteCalculator#line_amounts`: cantidad × precio a 2
// decimales, menos el descuento (también a 2 decimales).
export const lineAmounts = (
  { quantity, unit_price, discount_percent },
  taxes,
  taxIds
) => {
  const gross = round2(Number(quantity || 0) * Number(unit_price || 0));
  const net = gross - round2((gross * Number(discount_percent || 0)) / 100);
  return {
    amount: net.toFixed(2),
    amountWithTaxes: withTaxes(net, transferredPercent(taxIds, taxes)),
  };
};

export const applicableTaxIds = (taxIds, taxes, organization) => {
  if (!organization) return [...taxIds];
  return taxIds.filter(id => {
    const tax = taxes.find(item => item.id === id);
    if (!tax) return false;
    return isWithholding(tax)
      ? !!organization.withholds_taxes
      : organization.charge_taxes !== false;
  });
};
