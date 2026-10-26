import { getters } from '../../CaseReports';

describe('#getters', () => {
  it('getFunnel', () => {
    const state = { funnel: [{ id: 'open', count: 3 }] };
    expect(getters.getFunnel(state)).toEqual([{ id: 'open', count: 3 }]);
  });

  it('getOutcome', () => {
    const state = { outcome: { open: 1, won: 2, lost: 3, other_closed: 0 } };
    expect(getters.getOutcome(state)).toEqual({
      open: 1,
      won: 2,
      lost: 3,
      other_closed: 0,
    });
  });

  it('getTimeseries', () => {
    const state = {
      timeseries: { created: [{ value: 1, timestamp: 1 }], closed: [] },
    };
    expect(getters.getTimeseries(state)).toEqual({
      created: [{ value: 1, timestamp: 1 }],
      closed: [],
    });
  });

  it('getAssignees', () => {
    const state = { assignees: [{ assignee_id: 1, assignee_name: 'John' }] };
    expect(getters.getAssignees(state)).toEqual([
      { assignee_id: 1, assignee_name: 'John' },
    ]);
  });

  it('getVelocity', () => {
    const state = { velocity: [{ status: 'open', avg_days: 1.5 }] };
    expect(getters.getVelocity(state)).toEqual([
      { status: 'open', avg_days: 1.5 },
    ]);
  });

  it('getStalled', () => {
    const state = { stalled: [{ id: 1, stalled_days: 7 }] };
    expect(getters.getStalled(state)).toEqual([{ id: 1, stalled_days: 7 }]);
  });

  it('getUIFlags', () => {
    const state = { uiFlags: { isFetchingFunnel: true } };
    expect(getters.getUIFlags(state)).toEqual({ isFetchingFunnel: true });
  });
});
