// Plan-Trabajo-Campo R5 — sin señal: «Llegué», las notas y «Terminé» se
// guardan en el celular (localStorage) con la hora en que pasaron y se mandan
// en orden cuando vuelve la señal. Las fotos sí necesitan señal.
import FieldVisitsAPI from 'dashboard/api/fieldVisits';
import ServiceReportsAPI from 'dashboard/api/serviceReports';

const KEY = 'wintook_field_queue';

const read = () => {
  try {
    return JSON.parse(window.localStorage.getItem(KEY)) || [];
  } catch {
    return [];
  }
};

const write = items => {
  try {
    window.localStorage.setItem(KEY, JSON.stringify(items));
  } catch {
    // Sin espacio o sin almacenamiento: la acción se pierde y se avisa al intentar.
  }
};

// Sin respuesta del servidor = sin señal (un 4xx/5xx sí respondió).
export const isOffline = error => !navigator.onLine || !error?.response;

export const pending = ticketId =>
  read().filter(item => !ticketId || item.ticketId === ticketId);

export const enqueue = (ticketId, kind, payload) => {
  const item = {
    id: `${Date.now()}-${Math.random().toString(36).slice(2, 8)}`,
    ticketId,
    kind,
    payload: { ...payload, occurred_at: new Date().toISOString() },
  };
  write([...read(), item]);
  return item;
};

const SENDERS = {
  arrive: item => FieldVisitsAPI.arrive(item.ticketId, item.payload),
  finish: item => FieldVisitsAPI.finish(item.ticketId, item.payload),
  note: item =>
    ServiceReportsAPI.addLog(item.ticketId, {
      kind: 'note',
      content: item.payload.content,
    }),
};

// Manda lo pendiente en orden. Se detiene si sigue sin señal; lo que el
// servidor rechaza (p. ej. faltan requisitos para terminar) se quita y se
// devuelve en `rejected` para avisar.
export const flush = async () => {
  const rejected = [];
  let sent = 0;
  // eslint-disable-next-line no-restricted-syntax
  for (const item of read()) {
    try {
      // eslint-disable-next-line no-await-in-loop
      await SENDERS[item.kind](item);
      sent += 1;
    } catch (error) {
      if (isOffline(error)) break;
      rejected.push({ item, message: error?.response?.data?.error });
    }
    write(read().filter(other => other.id !== item.id));
  }
  return { sent, rejected };
};
