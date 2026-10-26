// @tickets_cases — Plan-Casos E1.1: filtros finos por clase → parámetros de la API.
import {
  COMMERCIAL_RESULTS,
  activeFineKeys,
  dateRange,
  emptyFineFilters,
  fineFiltersToParams,
  normalizeFineFilters,
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
        date_field: 'created',
        date_preset: 'custom',
        date_from: '2026-10-01',
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
      filters({
        origin: 'web',
        date_field: 'close',
        date_preset: 'this_month',
      }),
      'commercial',
      'mine'
    );
    expect(params).toEqual({
      expected_close_from: '2026-10-01',
      expected_close_to: '2026-10-31',
    });
  });

  it('una sola fecha: la que no aplica a lo que se ve no cuenta (ni salta a otra)', () => {
    const won = filters({ date_field: 'closed', date_preset: 'last_month' });
    expect(
      fineFiltersToParams(won, 'commercial', 'mine', { outcome: 'won' })
    ).toEqual({ closed_from: '2026-09-01', closed_to: '2026-09-30' });
    // «Ganada o perdida el» no aplica en En curso ni en el Tablero.
    expect(
      activeFineKeys(won, 'commercial', 'mine', { outcome: 'active' })
    ).toEqual([]);
    expect(activeFineKeys(won, 'commercial', 'mine', { board: true })).toEqual(
      []
    );
    const late = filters({ date_field: 'close', date_preset: 'overdue' });
    expect(
      fineFiltersToParams(late, 'commercial', 'mine', { outcome: 'active' })
    ).toEqual({ expected_close_to: '2026-10-19' });
  });

  it('Comercial: comprometidas esta semana / próxima semana / rango', () => {
    // 20 oct 2026 es martes: semana del lunes 19 al domingo 25.
    const week = filters({ date_field: 'close', date_preset: 'this_week' });
    expect(fineFiltersToParams(week, 'commercial', 'mine')).toEqual({
      expected_close_from: '2026-10-19',
      expected_close_to: '2026-10-25',
    });
    expect(dateRange('next_week')).toEqual({
      from: '2026-10-26',
      to: '2026-11-01',
    });
    expect(dateRange('custom', { from: '2026-09-01', to: '' })).toEqual({
      from: '2026-09-01',
      to: '',
    });
  });

  it('traduce los filtros guardados con una clave por fecha', () => {
    expect(
      normalizeFineFilters({ close: 'next_30', priority: 'high' })
    ).toEqual(
      filters({ date_field: 'close', date_preset: 'next_30', priority: 'high' })
    );
    expect(
      normalizeFineFilters({ created_from: '2026-10-01', created_to: '' })
    ).toEqual(
      filters({
        date_field: 'created',
        date_preset: 'custom',
        date_from: '2026-10-01',
      })
    );
    expect(
      normalizeFineFilters({ visit: 'overdue', closed: 'last_30' })
    ).toEqual(filters({ date_field: 'visit', date_preset: 'overdue' }));
    expect(normalizeFineFilters(null)).toEqual(filters({}));
  });

  it('Orden: etapa → estados; visita y facturable; cierre solo en etapas cerradas', () => {
    expect(stageToParams('open')).toEqual({ status: 'pending' });
    expect(stageToParams('scheduled')).toEqual({
      statuses: 'assigned,in_diagnosis',
    });
    expect(stageToParams('')).toEqual({});
    const f = filters({
      date_field: 'visit',
      date_preset: 'this_week',
      billable: 'no',
    });
    // 20 oct 2026 es martes: la semana va del lunes 19 al domingo 25.
    expect(
      fineFiltersToParams(f, 'work_order', 'mine', { stage: 'scheduled' })
    ).toEqual({
      visit_from: '2026-10-19',
      visit_to: '2026-10-25',
      billable: false,
    });
    // En Cerradas la visita no aplica; «Cerrado el» sí.
    expect(
      fineFiltersToParams(f, 'work_order', 'mine', { stage: 'closed' })
    ).toEqual({ billable: false });
    const closed = filters({ date_field: 'closed', date_preset: 'last_30' });
    expect(
      fineFiltersToParams(closed, 'work_order', 'mine', { stage: 'closed' })
    ).toEqual({ closed_from: '2026-09-20', closed_to: '2026-10-20' });
    // Visita vencida = sigue abierta con la hora de la visita pasada.
    const late = filters({ date_field: 'visit', date_preset: 'overdue' });
    expect(fineFiltersToParams(late, 'work_order', 'mine')).toEqual({
      visit_overdue: true,
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
    const f = filters({ date_field: 'closed', date_preset: 'last_30' });
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

  it('presets de fecha y alcance', () => {
    expect(dateRange('overdue')).toEqual({ from: '', to: '2026-10-19' });
    expect(dateRange('next_30')).toEqual({
      from: '2026-10-20',
      to: '2026-11-19',
    });
    expect(scopeToParams('mine', 3)).toEqual({ assignee_id: 3 });
    expect(scopeToParams('unassigned', 3)).toEqual({ assignee_id: 'null' });
    expect(scopeToParams('all', 3)).toEqual({});
  });
});
