import axios from 'axios';
import { actions } from '../../CaseReports';
import types from '../../../mutation-types';

const commit = vi.fn();
global.axios = axios;
vi.mock('axios');

describe('#actions', () => {
  afterEach(() => {
    commit.mockClear();
  });

  describe('#getFunnel', () => {
    it('sends correct mutations if API is success', async () => {
      const funnel = [{ id: 'open', label: 'open', count: 3 }];
      axios.get.mockResolvedValue({ data: funnel });

      await actions.getFunnel({ commit }, {});

      expect(commit.mock.calls).toEqual([
        [types.SET_CASE_REPORTS_UI_FLAG, { isFetchingFunnel: true }],
        [types.SET_CASE_REPORTS_FUNNEL, funnel],
        [types.SET_CASE_REPORTS_UI_FLAG, { isFetchingFunnel: false }],
      ]);
    });

    it('sends correct mutations if API errors, without raising', async () => {
      axios.get.mockRejectedValue(new Error('Network error'));

      await expect(actions.getFunnel({ commit }, {})).resolves.not.toThrow();

      expect(commit.mock.calls).toEqual([
        [types.SET_CASE_REPORTS_UI_FLAG, { isFetchingFunnel: true }],
        [types.SET_CASE_REPORTS_UI_FLAG, { isFetchingFunnel: false }],
      ]);
    });
  });

  describe('#getOutcome', () => {
    it('sends correct mutations if API is success', async () => {
      const outcome = { open: 1, won: 2, lost: 3, other_closed: 0 };
      axios.get.mockResolvedValue({ data: outcome });

      await actions.getOutcome({ commit }, {});

      expect(commit.mock.calls).toEqual([
        [types.SET_CASE_REPORTS_UI_FLAG, { isFetchingOutcome: true }],
        [types.SET_CASE_REPORTS_OUTCOME, outcome],
        [types.SET_CASE_REPORTS_UI_FLAG, { isFetchingOutcome: false }],
      ]);
    });

    it('sends correct mutations if API errors, without raising', async () => {
      axios.get.mockRejectedValue(new Error('Network error'));

      await expect(actions.getOutcome({ commit }, {})).resolves.not.toThrow();

      expect(commit.mock.calls).toEqual([
        [types.SET_CASE_REPORTS_UI_FLAG, { isFetchingOutcome: true }],
        [types.SET_CASE_REPORTS_UI_FLAG, { isFetchingOutcome: false }],
      ]);
    });
  });

  describe('#getTimeseries', () => {
    it('sends correct mutations if API is success', async () => {
      const timeseries = { created: [{ value: 1, timestamp: 1 }], closed: [] };
      axios.get.mockResolvedValue({ data: timeseries });

      await actions.getTimeseries({ commit }, {});

      expect(commit.mock.calls).toEqual([
        [types.SET_CASE_REPORTS_UI_FLAG, { isFetchingTimeseries: true }],
        [types.SET_CASE_REPORTS_TIMESERIES, timeseries],
        [types.SET_CASE_REPORTS_UI_FLAG, { isFetchingTimeseries: false }],
      ]);
    });

    it('sends correct mutations if API errors, without raising', async () => {
      axios.get.mockRejectedValue(new Error('Network error'));

      await expect(
        actions.getTimeseries({ commit }, {})
      ).resolves.not.toThrow();

      expect(commit.mock.calls).toEqual([
        [types.SET_CASE_REPORTS_UI_FLAG, { isFetchingTimeseries: true }],
        [types.SET_CASE_REPORTS_UI_FLAG, { isFetchingTimeseries: false }],
      ]);
    });
  });

  describe('#getAssignees', () => {
    it('sends correct mutations if API is success', async () => {
      const assignees = [{ assignee_id: 1, assignee_name: 'John', won: 2 }];
      axios.get.mockResolvedValue({ data: assignees });

      await actions.getAssignees({ commit }, {});

      expect(commit.mock.calls).toEqual([
        [types.SET_CASE_REPORTS_UI_FLAG, { isFetchingAssignees: true }],
        [types.SET_CASE_REPORTS_ASSIGNEES, assignees],
        [types.SET_CASE_REPORTS_UI_FLAG, { isFetchingAssignees: false }],
      ]);
    });

    it('sends correct mutations if API errors, without raising', async () => {
      axios.get.mockRejectedValue(new Error('Network error'));

      await expect(actions.getAssignees({ commit }, {})).resolves.not.toThrow();

      expect(commit.mock.calls).toEqual([
        [types.SET_CASE_REPORTS_UI_FLAG, { isFetchingAssignees: true }],
        [types.SET_CASE_REPORTS_UI_FLAG, { isFetchingAssignees: false }],
      ]);
    });
  });

  describe('#getVelocity', () => {
    it('sends correct mutations if API is success', async () => {
      const velocity = [{ status: 'open', avg_days: 1.5, count: 3 }];
      axios.get.mockResolvedValue({ data: velocity });

      await actions.getVelocity({ commit }, {});

      expect(commit.mock.calls).toEqual([
        [types.SET_CASE_REPORTS_UI_FLAG, { isFetchingVelocity: true }],
        [types.SET_CASE_REPORTS_VELOCITY, velocity],
        [types.SET_CASE_REPORTS_UI_FLAG, { isFetchingVelocity: false }],
      ]);
    });

    it('sends correct mutations if API errors, without raising', async () => {
      axios.get.mockRejectedValue(new Error('Network error'));

      await expect(actions.getVelocity({ commit }, {})).resolves.not.toThrow();

      expect(commit.mock.calls).toEqual([
        [types.SET_CASE_REPORTS_UI_FLAG, { isFetchingVelocity: true }],
        [types.SET_CASE_REPORTS_UI_FLAG, { isFetchingVelocity: false }],
      ]);
    });
  });

  describe('#getStalled', () => {
    it('sends correct mutations if API is success', async () => {
      const stalled = [{ id: 1, folio: 'COM-0001', stalled_days: 7 }];
      axios.get.mockResolvedValue({ data: stalled });

      await actions.getStalled({ commit }, {});

      expect(commit.mock.calls).toEqual([
        [types.SET_CASE_REPORTS_UI_FLAG, { isFetchingStalled: true }],
        [types.SET_CASE_REPORTS_STALLED, stalled],
        [types.SET_CASE_REPORTS_UI_FLAG, { isFetchingStalled: false }],
      ]);
    });

    it('sends correct mutations if API errors, without raising', async () => {
      axios.get.mockRejectedValue(new Error('Network error'));

      await expect(actions.getStalled({ commit }, {})).resolves.not.toThrow();

      expect(commit.mock.calls).toEqual([
        [types.SET_CASE_REPORTS_UI_FLAG, { isFetchingStalled: true }],
        [types.SET_CASE_REPORTS_UI_FLAG, { isFetchingStalled: false }],
      ]);
    });
  });
});
