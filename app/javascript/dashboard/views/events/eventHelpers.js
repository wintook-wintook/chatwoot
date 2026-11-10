// Plan-Eventos E1 — lo que comparten la lista, la página del evento y la pestaña del contacto.
import { areaLevel, getUserAccess } from 'dashboard/helper/accessHelper';

export const KINDS = ['fair', 'course', 'demo', 'webinar', 'other'];
export const STATUSES = ['draft', 'open', 'closed'];
export const ATTENDEE_STATUSES = [
  'invited',
  'confirmed',
  'attended',
  'no_show',
  'cancelled',
];

const ATTENDEE_CHIP = {
  invited: 'bg-slate-100 text-slate-600 dark:bg-slate-700 dark:text-slate-300',
  confirmed: 'bg-sky-50 text-sky-800 dark:bg-sky-900/40 dark:text-sky-300',
  attended:
    'bg-emerald-50 text-emerald-800 dark:bg-emerald-900/40 dark:text-emerald-300',
  no_show:
    'bg-amber-50 text-amber-800 dark:bg-amber-900/40 dark:text-amber-300',
  cancelled:
    'bg-slate-100 text-slate-500 line-through dark:bg-slate-700/60 dark:text-slate-400',
};

export const attendeeChipClass = status =>
  ATTENDEE_CHIP[status] || ATTENDEE_CHIP.invited;

// Lo mismo que el servidor: área Campañas; se cambian con «Todo» o «Solo lo suyo».
export const eventAccess = (user, accountId) => {
  const level = areaLevel(getUserAccess(user, accountId), 'campaigns');
  return { canEdit: ['own', 'all'].includes(level) };
};

export const formatDateTime = value =>
  value
    ? new Date(value).toLocaleString(undefined, {
        day: '2-digit',
        month: 'short',
        year: 'numeric',
        hour: '2-digit',
        minute: '2-digit',
      })
    : '';

// Para <input type="datetime-local">.
export const toLocalInput = value => {
  if (!value) return '';
  const date = new Date(value);
  const offset = date.getTimezoneOffset() * 60000;
  return new Date(date - offset).toISOString().slice(0, 16);
};
