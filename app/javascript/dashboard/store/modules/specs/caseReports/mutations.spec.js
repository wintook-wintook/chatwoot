import { mutations } from '../../CaseReports';
import types from '../../../mutation-types';

describe('#mutations', () => {
  describe(`#${types.SET_CASE_REPORTS_UI_FLAG}`, () => {
    it('merges new ui flags into state', () => {
      const state = { uiFlags: { isFetchingFunnel: false } };
      mutations[types.SET_CASE_REPORTS_UI_FLAG](state, {
        isFetchingFunnel: true,
      });
      expect(state.uiFlags).toEqual({ isFetchingFunnel: true });
    });
  });

  describe(`#${types.SET_CASE_REPORTS_FUNNEL}`, () => {
    it('replaces the funnel data', () => {
      const state = { funnel: [] };
      const funnel = [{ id: 'open', count: 3 }];
      mutations[types.SET_CASE_REPORTS_FUNNEL](state, funnel);
      expect(state.funnel).toEqual(funnel);
    });
  });

  describe(`#${types.SET_CASE_REPORTS_OUTCOME}`, () => {
    it('replaces the outcome data', () => {
      const state = { outcome: {} };
      const outcome = { open: 1, won: 2, lost: 3, other_closed: 0 };
      mutations[types.SET_CASE_REPORTS_OUTCOME](state, outcome);
      expect(state.outcome).toEqual(outcome);
    });
  });

  describe(`#${types.SET_CASE_REPORTS_TIMESERIES}`, () => {
    it('replaces the timeseries data', () => {
      const state = { timeseries: {} };
      const timeseries = { created: [{ value: 1, timestamp: 1 }], closed: [] };
      mutations[types.SET_CASE_REPORTS_TIMESERIES](state, timeseries);
      expect(state.timeseries).toEqual(timeseries);
    });
  });

  describe(`#${types.SET_CASE_REPORTS_ASSIGNEES}`, () => {
    it('replaces the assignees data', () => {
      const state = { assignees: [] };
      const assignees = [{ assignee_id: 1, assignee_name: 'John' }];
      mutations[types.SET_CASE_REPORTS_ASSIGNEES](state, assignees);
      expect(state.assignees).toEqual(assignees);
    });
  });

  describe(`#${types.SET_CASE_REPORTS_VELOCITY}`, () => {
    it('replaces the velocity data', () => {
      const state = { velocity: [] };
      const velocity = [{ status: 'open', avg_days: 1.5 }];
      mutations[types.SET_CASE_REPORTS_VELOCITY](state, velocity);
      expect(state.velocity).toEqual(velocity);
    });
  });

  describe(`#${types.SET_CASE_REPORTS_STALLED}`, () => {
    it('replaces the stalled data', () => {
      const state = { stalled: [] };
      const stalled = [{ id: 1, stalled_days: 7 }];
      mutations[types.SET_CASE_REPORTS_STALLED](state, stalled);
      expect(state.stalled).toEqual(stalled);
    });
  });
});
