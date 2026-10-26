import {
  formatMinutes,
  addDays,
  localDay,
  plannedAfterDue,
  reasonTone,
  visibleReasons,
} from '../caseTaskPriority';

describe('caseTaskPriority', () => {
  it('formatMinutes', () => {
    expect(formatMinutes(45)).toBe('45 min');
    expect(formatMinutes(60)).toBe('1 h');
    expect(formatMinutes(90)).toBe('1 h 30 min');
    expect(formatMinutes(null)).toBe('');
    expect(formatMinutes(0)).toBe('');
  });

  it('reasonTone', () => {
    expect(reasonTone('overdue')).toBe('red');
    expect(reasonTone('due_today')).toBe('amber');
    expect(reasonTone('priority_medium')).toBe('slate');
  });

  it('visibleReasons: los que más suman, sin antigüedad ni restas', () => {
    const reasons = [
      { key: 'age', points: 5 },
      { key: 'priority_medium', points: 10 },
      { key: 'overdue', points: 46 },
      { key: 'waiting', points: -15 },
      { key: 'project_overdue', points: 30 },
      { key: 'due_week', points: 5 },
    ];
    expect(visibleReasons(reasons).map(r => r.key)).toEqual([
      'overdue',
      'project_overdue',
      'priority_medium',
    ]);
  });

  it('visibleReasons: solo antigüedad si no hay más', () => {
    expect(visibleReasons([{ key: 'age', points: 3 }])).toEqual([
      { key: 'age', points: 3 },
    ]);
  });

  it('localDay: fecha local', () => {
    expect(localDay(new Date(2026, 0, 5, 23, 30))).toBe('2026-01-05');
  });

  it('addDays: cruza meses', () => {
    expect(addDays('2026-10-31', 1)).toBe('2026-11-01');
    expect(addDays('2026-03-01', -1)).toBe('2026-02-28');
  });

  it('plannedAfterDue', () => {
    const due = new Date(2026, 9, 22, 18, 0).toISOString();
    expect(plannedAfterDue('2026-10-23', due)).toBe(true);
    expect(plannedAfterDue('2026-10-22', due)).toBe(false);
    expect(plannedAfterDue('', due)).toBe(false);
    expect(plannedAfterDue('2026-10-23', null)).toBe(false);
  });
});
