// Plan-Contratos R1 — lo que comparten la lista, la pestaña del contacto y los formularios.
import { formatMoney } from 'dashboard/helper/caseCommercial';
import { areaLevel, canDo, getUserAccess } from 'dashboard/helper/accessHelper';

export const STATES = [
  'active',
  'renewal_due',
  'overdue',
  'ended',
  'suspended',
  'cancelled',
];
export const UNITS = ['day', 'week', 'month', 'year'];
export const STATUSES = ['active', 'suspended', 'cancelled'];

// Color del estado: verde al corriente, ámbar por renovar, rojo pago vencido…
const STATE_CHIP = {
  active: 'bg-green-50 text-green-700 dark:bg-green-900/30 dark:text-green-300',
  renewal_due:
    'bg-amber-50 text-amber-700 dark:bg-amber-900/30 dark:text-amber-300',
  overdue: 'bg-red-50 text-red-700 dark:bg-red-900/30 dark:text-red-300',
  ended: 'bg-slate-100 text-slate-600 dark:bg-slate-800 dark:text-slate-300',
  suspended:
    'bg-orange-50 text-orange-700 dark:bg-orange-900/30 dark:text-orange-300',
  cancelled:
    'bg-slate-100 text-slate-500 dark:bg-slate-800 dark:text-slate-400',
};

export const stateChipClass = state => STATE_CHIP[state] || STATE_CHIP.ended;

// «Mensual», «Cada 3 meses»…
export const everyLabel = (t, every, unit) =>
  Number(every) === 1
    ? t(`CONTRACTS.EVERY_ONE.${unit}`)
    : t(`CONTRACTS.EVERY_MANY.${unit}`, { n: every });

// Las fechas llegan como «AAAA-MM-DD»: se leen en la zona del navegador sin correrse un día.
export const formatDate = value => {
  if (!value) return '';
  const [year, month, day] = String(value).slice(0, 10).split('-').map(Number);
  return new Date(year, month - 1, day).toLocaleDateString(undefined, {
    day: 'numeric',
    month: 'short',
    year: 'numeric',
  });
};

export const contractAmount = contract =>
  contract.amount === null || contract.amount === undefined
    ? ''
    : formatMoney(contract.amount, contract.currency);

// Lo mismo que decide el servidor: se cambian con «Todo» o «Solo lo suyo» en Clientes o
// en Ventas; el precio solo con «Ver montos»; los tipos, el Administrador.
const WRITE_LEVELS = ['own', 'all'];
export const contractAccess = (user, accountId) => {
  const access = getUserAccess(user, accountId);
  return {
    canEdit: ['clients', 'sales'].some(area =>
      WRITE_LEVELS.includes(areaLevel(access, area))
    ),
    showAmounts: canDo(access, 'see_amounts'),
    isAdmin: access.role === 'administrator',
  };
};
