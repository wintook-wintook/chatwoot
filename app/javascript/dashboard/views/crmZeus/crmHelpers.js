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
