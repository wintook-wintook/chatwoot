// Academia Kontrolya — lo que calcula «Mi capacitación» con lo que manda el servidor.

// El primer módulo que no está terminado (el que «Sigue»); null si ya terminó todos.
export const nextModuleKey = modules => {
  const pending = (modules || []).find(mod => mod.status !== 'done');
  return pending ? pending.key : null;
};

export const percent = (done, total) =>
  total ? Math.round((Number(done) / Number(total)) * 100) : 0;

// Por qué no se puede hacer todavía (clave de ACADEMY.*), o null. `needs` lo manda el
// servidor: practice_contact (falta el Cliente de práctica) o practice_case (falta su caso).
export const stepBlockedKey = step => {
  if (!step || !step.blocked || step.status === 'done') return null;
  return step.needs === 'practice_case' ? 'BLOCKED_CASE' : 'BLOCKED';
};
