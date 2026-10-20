// @tickets_cases — Plan-Clase-Orden-de-Trabajo F2a: utilidades de órdenes de
// trabajo compartidas por el formulario, el panel de la ficha y el cierre.

export const WORK_ORDER_CLASS = 'work_order';

export const isWorkOrderType = type => type?.case_class === WORK_ORDER_CLASS;

// 2.5 → "2.5 h"; sin valor → '—'.
export const formatHours = hours => {
  if (hours === null || hours === undefined || hours === '') return '—';
  const n = Number(hours);
  return Number.isNaN(n)
    ? '—'
    : `${n.toLocaleString(undefined, { maximumFractionDigits: 2 })} h`;
};

// Payload de los datos de la orden para el alta/edición. `clear` = vacío se
// manda como null (edición); si no, vacío se omite (alta).
export const workOrderPayload = (form, { clear = false } = {}) => {
  const empty = clear ? null : undefined;
  const hours = value => (value === '' || value === null ? empty : value);
  const out = {
    work_address: String(form.work_address || '').trim() || empty,
    estimated_hours: hours(form.estimated_hours),
    billable: !!form.billable,
  };
  if (clear) out.actual_hours = hours(form.actual_hours);
  return out;
};
