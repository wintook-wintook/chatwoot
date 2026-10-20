// @tickets_cases — Plan-Casos E1.1: filtros finos por clase → parámetros de la API.
import {
  COMMERCIAL_RESULTS,
  activeFineKeys,
  closeRange,
  emptyFineFilters,
  fineFiltersToParams,
  alertApplies,
  classAlertParams,
  scopeToParams,
  stageToParams,
  statusForResult,
} from '../caseFilters';

describe('caseFilters', () => {
  beforeEach(() => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date(2026, 9, 20, 12, 0, 0)); // 20 oct 2026
  });
  afterEach(() => vi.useRealTimers());

  const filters = overrides => ({ ...emptyFineFilters(), ...overrides });

  it('Soporte: prioridad, origen y fechas de alta', () => {
    const params = fineFiltersToParams(
      filters({
        priority: 'high',
        origin: 'whatsapp',
        created_from: '2026-10-01',
      }),
      'support',
      'mine'
    );
    expect(params).toEqual({
      priority: 'high',
      origin: 'whatsapp',
      date_from: '2026-10-01',
    });
  });

  it('Comercial no usa origen y traduce el cierre estimado', () => {
    const params = fineFiltersToParams(
      filters({ origin: 'web', close: 'this_month' }),
      'commercial',
      'mine'
    );
    expect(params).toEqual({
      expected_close_from: '2026-10-01',
      expected_close_to: '2026-10-31',
    });
  });

  it('las fechas siguen al resultado: Ganadas usa la fecha de cierre', () => {
    const f = filters({ close: 'overdue', closed: 'last_month' });
    expect(
      fineFiltersToParams(f, 'commercial', 'mine', { outcome: 'won' })
    ).toEqual({ closed_from: '2026-09-01', closed_to: '2026-09-30' });
    expect(
      fineFiltersToParams(f, 'commercial', 'mine', { outcome: 'active' })
    ).toEqual({ expected_close_to: '2026-10-19' });
    // Todas: aplican las dos; en el Tablero nunca la fecha de cierre.
    expect(activeFineKeys(f, 'commercial', 'mine', { outcome: '' })).toEqual([
      'close',
      'closed',
    ]);
    expect(activeFineKeys(f, 'commercial', 'mine', { board: true })).toEqual([
      'close',
    ]);
  });

  it('Orden: etapa → estados; visita y facturable; cierre solo en etapas cerradas', () => {
    expect(stageToParams('open')).toEqual({ status: 'pending' });
    expect(stageToParams('scheduled')).toEqual({
      statuses: 'assigned,in_diagnosis',
    });
    expect(stageToParams('')).toEqual({});
    const f = filters({
      visit: 'this_week',
      billable: 'no',
      closed: 'last_30',
    });
    // 20 oct 2026 es martes: la semana va del lunes 19 al domingo 25.
    expect(
      fineFiltersToParams(f, 'work_order', 'mine', { stage: 'scheduled' })
    ).toEqual({
      visit_from: '2026-10-19',
      visit_to: '2026-10-25',
      billable: false,
    });
    expect(
      fineFiltersToParams(f, 'work_order', 'mine', { stage: 'closed' })
    ).toEqual({
      billable: false,
      closed_from: '2026-09-20',
      closed_to: '2026-10-20',
    });
  });

  it('aviso rojo por clase: dónde aplica y qué filtra', () => {
    expect(alertApplies({ caseClass: 'support', status: 'closed' })).toBe(
      false
    );
    expect(alertApplies({ caseClass: 'commercial', outcome: 'won' })).toBe(
      false
    );
    expect(alertApplies({ caseClass: 'work_order', stage: 'scheduled' })).toBe(
      true
    );
    expect(alertApplies({ caseClass: 'work_order', stage: 'closed' })).toBe(
      false
    );
    expect(classAlertParams('work_order')).toEqual({ visit_overdue: true });
    expect(classAlertParams('commercial')).toEqual({
      expected_close_to: '2026-10-19',
      status: 'pending',
    });
    expect(classAlertParams('support')).toEqual({});
  });

  it('Soporte: la fecha de cierre no aplica en Pendientes', () => {
    const f = filters({ closed: 'last_30' });
    expect(activeFineKeys(f, 'support', 'mine', { status: 'pending' })).toEqual(
      []
    );
    expect(
      fineFiltersToParams(f, 'support', 'mine', { status: 'closed' })
    ).toEqual({ closed_from: '2026-09-20', closed_to: '2026-10-20' });
  });

  it('En curso y Pospuestas son abiertas; las otras tres, cerradas', () => {
    expect(COMMERCIAL_RESULTS).toEqual([
      'active',
      'won',
      'lost',
      'postponed',
      'cancelled',
    ]);
    expect(statusForResult('active')).toBe('pending');
    expect(statusForResult('postponed')).toBe('pending');
    expect(statusForResult('lost')).toBe('closed');
  });

  it('el responsable solo cuenta en «Todos»; la naturaleza solo con ITIL', () => {
    const f = filters({ assignee_id: 7, ticket_kind: 'incident' });
    expect(activeFineKeys(f, 'support', 'mine')).toEqual([]);
    expect(activeFineKeys(f, 'support', 'all', { itil: true })).toEqual([
      'ticket_kind',
      'assignee_id',
    ]);
  });

  it('presets de cierre y alcance', () => {
    expect(closeRange('overdue')).toEqual({ from: '', to: '2026-10-19' });
    expect(closeRange('next_30')).toEqual({
      from: '2026-10-20',
      to: '2026-11-19',
    });
    expect(scopeToParams('mine', 3)).toEqual({ assignee_id: 3 });
    expect(scopeToParams('unassigned', 3)).toEqual({ assignee_id: 'null' });
    expect(scopeToParams('all', 3)).toEqual({});
  });
});
