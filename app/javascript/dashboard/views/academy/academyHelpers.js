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

// La etiqueta del tipo de paso (clave de ACADEMY.*): lección, ejercicio, o el nivel de un
// paso de configuración (indispensable / recomendado / cuando estés listo).
export const stepTypeKey = step => {
  if (step.kind === 'lesson') return 'LESSON';
  if (step.kind === 'setup') return `LEVEL.${step.level || 'recommended'}`;
  return 'EXERCISE';
};

// ¿Algún módulo se hace con el Cliente de práctica? (si no, no se muestra su tarjeta).
export const usesPractice = modules =>
  (modules || []).some(mod =>
    mod.steps.some(step => step.needs || step.key === 'practica')
  );
