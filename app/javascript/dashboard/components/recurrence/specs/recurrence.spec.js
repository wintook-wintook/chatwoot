import {
  caseRecurrencePayload,
  defaultRecurrence,
  describeRecurrence,
  fromRecurrence,
  recurrencePayload,
} from '../recurrence';

const es = {
  'RECURRING_TASKS.TEXT_EVERY_WEEK': 'Cada semana',
  'RECURRING_TASKS.TEXT_EVERY_DAY': 'Cada día',
  'RECURRING_TASKS.TEXT_EVERY_N': 'Cada {every} {unit}',
  'RECURRING_TASKS.TEXT_AFTER': '{every} {unit} después de hacerla',
  'RECURRING_TASKS.DAYS_LONG.1': 'lunes',
  'RECURRING_TASKS.DAYS_LONG.4': 'jueves',
};
const units = { DAY: ['día', 'días'], WEEK: ['semana', 'semanas'] };
const vm = {
  $t: (key, params = {}) =>
    (es[key] || key).replace(/\{(\w+)\}/g, (_, k) => params[k]),
  $tc: (key, n) => units[key.split('_').pop()][n === 1 ? 0 : 1],
};

describe('recurrence', () => {
  it('describe fecha fija, varios días y la hora', () => {
    const rec = { mode: 'fixed', every: 1, unit: 'week', weekdays: [4, 1] };
    expect(describeRecurrence(rec, vm)).toBe('Cada semana: lunes, jueves');
    expect(describeRecurrence({ ...rec, every: 2, at_time: '10:30' }, vm)).toBe(
      'Cada 2 semanas: lunes, jueves · 10:30'
    );
  });

  it('describe «después de hacerla»', () => {
    const rec = { mode: 'after_done', every: 30, unit: 'day', weekdays: [] };
    expect(describeRecurrence(rec, vm)).toBe('30 días después de hacerla');
  });

  it('manda los días solo en fecha fija semanal y el fin elegido', () => {
    const value = { ...defaultRecurrence(), weekdays: [1], ends: 'after' };
    expect(recurrencePayload(value)).toMatchObject({
      weekdays: [1],
      max_count: 4,
      ends_on: null,
    });
    const after = { ...value, mode: 'after_done', ends: 'never' };
    expect(recurrencePayload(after)).toMatchObject({
      weekdays: [],
      max_count: null,
    });
  });

  it('al editar recupera cómo termina', () => {
    expect(
      fromRecurrence({ ...defaultRecurrence(), ends_on: '2027-01-01' }).ends
    ).toBe('on');
    expect(fromRecurrence({ ...defaultRecurrence(), max_count: 3 }).ends).toBe(
      'after'
    );
  });

  it('dentro de un caso: ligada al caso y empieza el día «Programada para» (o hoy)', () => {
    const rec = { ...defaultRecurrence(new Date(2026, 10, 23)), unit: 'day' };
    const form = {
      title: ' Revisar ',
      priority: 'high',
      assignee_id: 7,
      planned_on: '',
    };
    expect(caseRecurrencePayload(form, rec, 42, '2026-11-23')).toMatchObject({
      title: 'Revisar',
      case_ticket_id: 42,
      starts_on: '2026-11-23',
      priority: 'high',
      assignee_id: 7,
      unit: 'day',
    });
  });
});
