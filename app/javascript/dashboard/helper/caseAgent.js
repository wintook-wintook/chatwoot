// ¿Un agente atiende la conversación del caso? (lista y tablero, junto al siguiente
// paso; Cases::AgentStatus). Solo el robot, sin nombre: el detalle va en el título.
//   active          robot morado — está contestando
//   paused          robot ámbar  — hay agente, pero ahora no contesta (pausa)
//   none            robot gris tachado — nadie automático atiende la conversación
//   no_conversation robot gris tachado — el caso no tiene conversación
// null = cerrado/cancelado (no aplica).
import { stepDate } from './caseNextStep';

const COLORS = {
  active: 'text-violet-600 dark:text-violet-300',
  paused: 'text-amber-600 dark:text-amber-400',
  none: 'text-slate-400 dark:text-slate-500',
  no_conversation: 'text-slate-300 dark:text-slate-600',
};

// → { cls, crossed, title } o null. `t` = this.$t; claves en CASE_TICKETS.AGENT.
export const agentView = (agent, t) => {
  if (!agent || !COLORS[agent.state]) return null;
  const T = key => `CASE_TICKETS.AGENT.${key}`;
  const crossed = agent.state === 'none' || agent.state === 'no_conversation';
  if (crossed) {
    const key = agent.state === 'none' ? 'NONE' : 'NO_CONVERSATION';
    return { cls: COLORS[agent.state], crossed, title: t(T(key)) };
  }
  const parts = [
    t(T(agent.state === 'active' ? 'ACTIVE' : 'PAUSED'), { name: agent.name }),
  ];
  if (agent.objective) parts.push(agent.objective);
  if (agent.max_attempts) {
    parts.push(
      t(T('ATTEMPTS'), { n: agent.attempts, max: agent.max_attempts })
    );
  }
  if (agent.next_at && agent.state === 'active') {
    parts.push(t(T('NEXT'), { date: stepDate(agent.next_at, true) }));
  }
  return { cls: COLORS[agent.state], crossed, title: parts.join(' · ') };
};
