// Tareas que se repiten — valores por omisión, lo que se manda al servidor y el texto
// «Cada semana: lunes y jueves · 10:30».

export const UNITS = ['day', 'week', 'month'];
export const WEEKDAYS = [1, 2, 3, 4, 5, 6, 0]; // de lunes a domingo

export const defaultRecurrence = (date = new Date()) => ({
  mode: 'fixed',
  every: 1,
  unit: 'week',
  weekdays: [date.getDay()],
  ends: 'never',
  ends_on: '',
  max_count: 4,
});

// Desde una guardada (para editarla).
export const fromRecurrence = rec => ({
  mode: rec.mode,
  every: rec.every,
  unit: rec.unit,
  weekdays: [...(rec.weekdays || [])],
  ends: (rec.ends_on && 'on') || (rec.max_count && 'after') || 'never',
  ends_on: rec.ends_on || '',
  max_count: rec.max_count || 4,
});

export const recurrencePayload = value => ({
  mode: value.mode,
  every: Math.max(1, Number(value.every) || 1),
  unit: value.unit,
  weekdays:
    value.mode === 'fixed' && value.unit === 'week' ? value.weekdays : [],
  ends_on: value.ends === 'on' ? value.ends_on || null : null,
  max_count: value.ends === 'after' ? Number(value.max_count) || null : null,
  time_zone: Intl.DateTimeFormat().resolvedOptions().timeZone,
});

// El texto corto para la lista y la confirmación. `vm`: el componente (su $t y $tc).
export const describeRecurrence = (rec, vm) => {
  const t = (key, params) => vm.$t(key, params);
  const every = Number(rec.every) || 1;
  const unit = vm.$tc(`RECURRING_TASKS.UNIT_${rec.unit.toUpperCase()}`, every);
  let text;
  if (rec.mode === 'after_done') {
    text = t('RECURRING_TASKS.TEXT_AFTER', { every, unit });
  } else {
    text =
      every === 1
        ? t(`RECURRING_TASKS.TEXT_EVERY_${rec.unit.toUpperCase()}`)
        : t('RECURRING_TASKS.TEXT_EVERY_N', { every, unit });
    const days = WEEKDAYS.filter(d => (rec.weekdays || []).includes(d));
    if (rec.unit === 'week' && days.length) {
      const names = days.map(d => t(`RECURRING_TASKS.DAYS_LONG.${d}`));
      text += `: ${names.join(', ')}`;
    }
  }
  return rec.at_time ? `${text} · ${rec.at_time}` : text;
};
