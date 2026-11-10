import { nextStepView, NO_STEP_BADGE } from '../caseNextStep';

const t = (key, params) =>
  params ? `${key.split('.').pop()}:${params.date}` : key.split('.').pop();

describe('caseNextStep', () => {
  it('cerrado: no aplica', () => {
    expect(nextStepView(null, t)).toBeNull();
  });

  it('sin tareas ni agenda: la etiqueta «Sin siguiente paso»', () => {
    expect(nextStepView({ kind: 'none' }, t)).toEqual({
      label: 'NONE',
      cls: NO_STEP_BADGE,
      badge: true,
    });
  });

  it('tarea vencida en rojo, con cuántos más', () => {
    const view = nextStepView(
      { kind: 'task', at: '2026-11-02T18:00:00Z', overdue: true, more: 2 },
      t
    );
    expect(view.label).toMatch(/^TASK_OVERDUE:.+ \+2$/);
    expect(view.cls).toContain('text-red-600');
  });

  it('tarea sin fecha y tarea agendada', () => {
    expect(nextStepView({ kind: 'task', at: null, more: 0 }, t).label).toBe(
      'TASK_NO_DATE'
    );
    expect(
      nextStepView(
        { kind: 'meeting', at: '2026-11-14T16:00:00Z', overdue: false },
        t
      ).label
    ).toMatch(/^MEETING:/);
  });
});
