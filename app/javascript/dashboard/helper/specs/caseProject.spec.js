// @tickets_cases — Plan-Clase-Proyecto P1.
import { isProjectType, projectPayload } from '../caseProject';
import {
  alertApplies,
  classAlertParams,
  fineFiltersToParams,
  emptyFineFilters,
  stageToParams,
} from '../caseFilters';

describe('caseProject', () => {
  beforeEach(() => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date(2026, 9, 20, 12, 0, 0)); // 20 oct 2026
  });
  afterEach(() => vi.useRealTimers());

  it('reconoce un tipo de proyecto y arma el payload', () => {
    expect(isProjectType({ case_class: 'project' })).toBe(true);
    const form = {
      project_start_on: '',
      project_due_on: '2027-01-31',
      budget_hours: '',
      budget_amount: 5000,
      progress: '',
    };
    expect(projectPayload(form)).toEqual({
      project_start_on: undefined,
      project_due_on: '2027-01-31',
      budget_hours: undefined,
      budget_amount: 5000,
    });
    expect(projectPayload(form, { clear: true })).toMatchObject({
      project_start_on: null,
      progress: null,
    });
  });

  it('fases, fecha objetivo y aviso de atrasados', () => {
    expect(stageToParams('execution', 'project')).toEqual({
      statuses: 'in_progress,escalated',
    });
    const f = {
      ...emptyFineFilters(),
      date_field: 'due',
      date_preset: 'overdue',
    };
    expect(
      fineFiltersToParams(f, 'project', 'mine', { stage: 'planning' })
    ).toEqual({ project_due_to: '2026-10-19' });
    expect(
      fineFiltersToParams(f, 'project', 'mine', { stage: 'closed' })
    ).toEqual({});
    expect(alertApplies({ caseClass: 'project', stage: 'delivery' })).toBe(
      false
    );
    expect(classAlertParams('project')).toEqual({
      project_due_to: '2026-10-19',
      status: 'pending',
    });
  });
});
