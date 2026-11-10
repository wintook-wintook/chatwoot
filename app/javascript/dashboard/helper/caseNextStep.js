// Siguiente paso de un caso (lista y tablero): lo más próximo entre sus tareas
// pendientes y sus tareas agendadas (Cases::NextSteps). Sin ninguno, el caso se
// queda sin continuidad: «Sin siguiente paso». null = cerrado/cancelado (no aplica).

export const NO_STEP_BADGE =
  'bg-amber-100 text-amber-800 dark:bg-amber-900/40 dark:text-amber-300';
const OVERDUE = 'text-red-600 dark:text-red-400 font-semibold';
const NORMAL = 'text-slate-600 dark:text-slate-300';
const MUTED = 'text-slate-400 dark:text-slate-500';

// En hora local (las fechas llegan en UTC): «12 nov» y, en lo agendado, la hora.
export const stepDate = (at, withTime = false) => {
  if (!at) return '';
  const date = new Date(at);
  const day = date.toLocaleDateString(undefined, {
    day: 'numeric',
    month: 'short',
  });
  if (!withTime) return day;
  const time = date.toLocaleTimeString(undefined, {
    hour: '2-digit',
    minute: '2-digit',
  });
  return `${day} ${time}`;
};

// → { label, cls, badge } o null. `t` = this.$t; las claves en CASE_TICKETS.NEXT_STEP.
export const nextStepView = (step, t) => {
  if (!step) return null;
  const T = key => `CASE_TICKETS.NEXT_STEP.${key}`;
  if (step.kind === 'none') {
    return { label: t(T('NONE')), cls: NO_STEP_BADGE, badge: true };
  }
  const meeting = step.kind === 'meeting';
  const more = step.more ? ` +${step.more}` : '';
  if (!step.at) return { label: t(T('TASK_NO_DATE')) + more, cls: MUTED };
  const date = stepDate(step.at, meeting);
  let key = meeting ? 'MEETING' : 'TASK';
  if (step.overdue) key = meeting ? 'MEETING_OVERDUE' : 'TASK_OVERDUE';
  return {
    label: t(T(key), { date }) + more,
    cls: step.overdue ? OVERDUE : NORMAL,
  };
};
