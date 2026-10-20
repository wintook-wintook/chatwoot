// @tickets_cases — Plan-Clase-Orden-de-Trabajo F2a.
import {
  formatHours,
  isWorkOrderType,
  workOrderPayload,
} from '../caseWorkOrder';

describe('caseWorkOrder', () => {
  it('reconoce un tipo de orden', () => {
    expect(isWorkOrderType({ case_class: 'work_order' })).toBe(true);
    expect(isWorkOrderType({ case_class: 'support' })).toBe(false);
  });

  it('formatea horas', () => {
    expect(formatHours('')).toBe('—');
    expect(formatHours(2.5)).toMatch(/^2[.,]5 h$/);
  });

  it('alta omite vacíos; edición los manda como null', () => {
    const form = { work_address: '  ', estimated_hours: '', billable: false };
    expect(workOrderPayload(form)).toEqual({
      work_address: undefined,
      estimated_hours: undefined,
      billable: false,
    });
    expect(
      workOrderPayload({ ...form, actual_hours: '' }, { clear: true })
    ).toEqual({
      work_address: null,
      estimated_hours: null,
      billable: false,
      actual_hours: null,
    });
  });
});
