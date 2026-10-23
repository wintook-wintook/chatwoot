// @tickets_cases — Plan-Metricas-Comercial: memoria del botón «Calcular».
// Un cálculo a pedido se guarda en el navegador con su hora y la llave de los
// filtros con que se hizo; vale el mismo día. Así no se recalcula solo al volver
// a la pestaña, y si los filtros cambiaron se puede avisar en vez de mostrar
// números de otros filtros como si fueran los actuales.

const PREFIX = 'case_metrics_calc';
const keyOf = (accountId, name) => `${PREFIX}::${accountId}::${name}`;
const today = () => new Date().toDateString();

// Llave estable de unos filtros (sin importar el orden ni los vacíos).
export const filtersKey = filters =>
  JSON.stringify(
    Object.keys(filters || {})
      .filter(
        k =>
          filters[k] !== undefined && filters[k] !== '' && filters[k] !== null
      )
      .sort()
      .map(k => [k, String(filters[k])])
  );

export const loadCalc = (accountId, name) => {
  try {
    const entry = JSON.parse(
      window.localStorage.getItem(keyOf(accountId, name))
    );
    return entry && entry.day === today() ? entry : null;
  } catch (_e) {
    return null;
  }
};

export const saveCalc = (accountId, name, key, data) => {
  const entry = { key, data, at: Date.now(), day: today() };
  try {
    window.localStorage.setItem(keyOf(accountId, name), JSON.stringify(entry));
  } catch (_e) {
    // sin almacenamiento: el resultado vive solo mientras la página esté abierta.
  }
  return entry;
};

// «hace 5 min» / «hace 2 h» / «hace un momento».
export const timeAgo = (at, now = Date.now()) => {
  const minutes = Math.floor((now - at) / 60000);
  const rtf = new Intl.RelativeTimeFormat(undefined, { numeric: 'auto' });
  if (minutes < 1) return rtf.format(0, 'second');
  if (minutes < 60) return rtf.format(-minutes, 'minute');
  return rtf.format(-Math.floor(minutes / 60), 'hour');
};
