// ================================================================================
// fix/campanas — AVISOS DE LAS FECHAS DE UNA CAMPAÑA
// ================================================================================
// Lo que conviene avisar de la ventana (inicio / fin) antes de guardar una campaña
// (CampaignForm) y antes de ponerla en curso (CampaignLaunchModal). Cada aviso:
//   { level: 'error' | 'warning' | 'info', key, date?, days?, hours? }
// `key` es la llave en TRACKING_CAMPAIGNS_VIEW.DATE_ALERTS. Un 'error' impide ponerla
// en curso (TrackingCampaigns::Launch también lo rechaza).
//
// Recordatorio de cómo corre la ventana (TrackingCampaigns::Launch y ::Schedule):
//   - inicio vacío o ya pasado → al ponerla en curso empieza en ese momento;
//   - después del fin ya no sale ningún envío.
// ================================================================================

const HOUR_MS = 36e5;
const DAY_MS = 24 * HOUR_MS;
// Más allá de esto, un inicio suele ser un error al escribir la fecha (mes o año).
export const FAR_START_DAYS = 60;
// Ventana más corta que esto: puede no alcanzar para enviar a todos.
export const SHORT_WINDOW_HOURS = 24;
// Fin dentro de este plazo: avisar que termina pronto.
export const ENDS_SOON_HOURS = 48;

const toDate = value => (value ? new Date(value) : null);

export const campaignDateAlerts = (
  { scheduledFor, endsAt } = {},
  now = new Date()
) => {
  const start = toDate(scheduledFor);
  const end = toDate(endsAt);

  if (end && end <= now)
    return [{ level: 'error', key: 'ENDS_PASSED', date: end }];
  if (end && start && end <= start) {
    return [{ level: 'error', key: 'ENDS_BEFORE_START' }];
  }

  const alerts = [];
  if (!start) {
    alerts.push({ level: 'info', key: 'NO_START' });
  } else if (start <= now) {
    alerts.push({ level: 'warning', key: 'START_PASSED', date: start });
  } else if (start - now > FAR_START_DAYS * DAY_MS) {
    alerts.push({
      level: 'warning',
      key: 'START_FAR',
      date: start,
      days: Math.round((start - now) / DAY_MS),
    });
  }

  if (end) {
    const effectiveStart = start && start > now ? start : now;
    const hours = (end - effectiveStart) / HOUR_MS;
    if (hours < SHORT_WINDOW_HOURS) {
      alerts.push({
        level: 'warning',
        key: 'SHORT_WINDOW',
        date: end,
        hours: Math.max(1, Math.round(hours)),
      });
    } else if (end - now < ENDS_SOON_HOURS * HOUR_MS) {
      alerts.push({ level: 'warning', key: 'ENDS_SOON', date: end });
    }
  }
  return alerts;
};

export const hasDateError = alerts => alerts.some(a => a.level === 'error');

// Misma forma que las fechas de la tabla de campañas (dd/mm/aaaa, hh:mm).
export const formatCampaignDate = value =>
  new Date(value).toLocaleString('es-MX', {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  });
