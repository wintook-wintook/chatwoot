// Vencimiento de una TAREA (sin agendar): solo fecha. Vence al final de ese día (23:59 hora
// local); la hora es solo de las tareas agendadas. Las tareas viejas con hora se ven con su día.

const pad = n => String(n).padStart(2, '0');

// ISO → 'YYYY-MM-DD' local (para <input type="date">).
export const dueDateInput = iso => {
  if (!iso) return '';
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return '';
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
};

// 'YYYY-MM-DD' → ISO del final de ese día en hora local (o null).
export const dueToIso = date => {
  if (!date) return null;
  const d = new Date(`${date}T23:59:59`);
  return Number.isNaN(d.getTime()) ? null : d.toISOString();
};

// ISO → «12 nov 2026» (sin hora).
export const formatDueDay = iso => {
  if (!iso) return '';
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return '';
  return d.toLocaleDateString(undefined, {
    day: '2-digit',
    month: 'short',
    year: 'numeric',
  });
};
