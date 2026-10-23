// ================================================================================
// @campanas_vendedor — orden de la tabla de campañas (Campaigns.vue, en cliente)
// ================================================================================

export const progressPct = stats =>
  stats?.total ? Math.round((stats.completed / stats.total) * 100) : 0;

// Valor por el que se ordena cada columna (las fechas ISO ordenan como texto).
const SORT_VALUE = {
  name: c => (c.name || '').toLowerCase(),
  template_name: c => (c.template_name || '').toLowerCase(),
  inbox_name: c => (c.inbox_name || '').toLowerCase(),
  mode: c => c.mode || 'batch',
  scheduled_for: c => c.scheduled_for || '',
  created_at: c => c.created_at || '',
  status: c => c.status,
  progress: c => progressPct(c.stats),
};

// VeTable manda todas las columnas ({ name: 'asc', status: '' ... }); vale la que tiene orden.
export const sortFromParams = params => {
  const [field, order] =
    Object.entries(params || {}).find(([, value]) => value) || [];
  return field ? { [field]: order } : {};
};

// Sin orden (o columna desconocida) quedan como vienen: las más nuevas primero.
export const sortCampaigns = (campaigns, sortConfig) => {
  const [field, order] = Object.entries(sortConfig || {})[0] || [];
  const value = SORT_VALUE[field];
  if (!value) return campaigns;
  const direction = order === 'desc' ? -1 : 1;
  return [...campaigns].sort((a, b) => {
    const [x, y] = [value(a), value(b)];
    if (x === y) return 0;
    return x > y ? direction : -direction;
  });
};
