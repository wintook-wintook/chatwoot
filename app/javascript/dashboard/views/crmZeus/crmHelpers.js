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
