// proyecto@metricas_casos
import types from '../mutation-types';
import CaseReportsAPI from '../../api/caseReports';

export const state = {
  funnel: [],
  outcome: { open: 0, won: 0, lost: 0, other_closed: 0 },
  timeseries: { created: [], closed: [] },
  assignees: [],
  velocity: [],
  stalled: [],
  uiFlags: {
    isFetchingFunnel: false,
    isFetchingOutcome: false,
    isFetchingTimeseries: false,
    isFetchingAssignees: false,
    isFetchingVelocity: false,
    isFetchingStalled: false,
  },
};

export const getters = {
  getFunnel(_state) {
    return _state.funnel;
  },
  getOutcome(_state) {
    return _state.outcome;
  },
  getTimeseries(_state) {
    return _state.timeseries;
  },
  getAssignees(_state) {
    return _state.assignees;
  },
  getVelocity(_state) {
    return _state.velocity;
  },
  getStalled(_state) {
    return _state.stalled;
  },
  getUIFlags(_state) {
    return _state.uiFlags;
  },
};

export const actions = {
  getFunnel: async function getFunnel({ commit }, params) {
    commit(types.SET_CASE_REPORTS_UI_FLAG, { isFetchingFunnel: true });
    try {
      const response = await CaseReportsAPI.getFunnel(params);
      commit(types.SET_CASE_REPORTS_FUNNEL, response.data);
    } catch (error) {
      // Ignore error, la UI muestra el estado vacío
    } finally {
      commit(types.SET_CASE_REPORTS_UI_FLAG, { isFetchingFunnel: false });
    }
  },
  getOutcome: async function getOutcome({ commit }, params) {
    commit(types.SET_CASE_REPORTS_UI_FLAG, { isFetchingOutcome: true });
    try {
      const response = await CaseReportsAPI.getOutcome(params);
      commit(types.SET_CASE_REPORTS_OUTCOME, response.data);
    } catch (error) {
      // Ignore error, la UI muestra el estado vacío
    } finally {
      commit(types.SET_CASE_REPORTS_UI_FLAG, { isFetchingOutcome: false });
    }
  },
  getTimeseries: async function getTimeseries({ commit }, params) {
    commit(types.SET_CASE_REPORTS_UI_FLAG, { isFetchingTimeseries: true });
    try {
      const response = await CaseReportsAPI.getTimeseries(params);
      commit(types.SET_CASE_REPORTS_TIMESERIES, response.data);
    } catch (error) {
      // Ignore error, la UI muestra el estado vacío
    } finally {
      commit(types.SET_CASE_REPORTS_UI_FLAG, { isFetchingTimeseries: false });
    }
  },
  getAssignees: async function getAssignees({ commit }, params) {
    commit(types.SET_CASE_REPORTS_UI_FLAG, { isFetchingAssignees: true });
    try {
      const response = await CaseReportsAPI.getAssignees(params);
      commit(types.SET_CASE_REPORTS_ASSIGNEES, response.data);
    } catch (error) {
      // Ignore error, la UI muestra el estado vacío
    } finally {
      commit(types.SET_CASE_REPORTS_UI_FLAG, { isFetchingAssignees: false });
    }
  },
  getVelocity: async function getVelocity({ commit }, params) {
    commit(types.SET_CASE_REPORTS_UI_FLAG, { isFetchingVelocity: true });
    try {
      const response = await CaseReportsAPI.getVelocity(params);
      commit(types.SET_CASE_REPORTS_VELOCITY, response.data);
    } catch (error) {
      // Ignore error, la UI muestra el estado vacío
    } finally {
      commit(types.SET_CASE_REPORTS_UI_FLAG, { isFetchingVelocity: false });
    }
  },
  getStalled: async function getStalled({ commit }, params) {
    commit(types.SET_CASE_REPORTS_UI_FLAG, { isFetchingStalled: true });
    try {
      const response = await CaseReportsAPI.getStalled(params);
      commit(types.SET_CASE_REPORTS_STALLED, response.data);
    } catch (error) {
      // Ignore error, la UI muestra el estado vacío
    } finally {
      commit(types.SET_CASE_REPORTS_UI_FLAG, { isFetchingStalled: false });
    }
  },
};

export const mutations = {
  [types.SET_CASE_REPORTS_UI_FLAG](_state, data) {
    _state.uiFlags = {
      ..._state.uiFlags,
      ...data,
    };
  },
  [types.SET_CASE_REPORTS_FUNNEL](_state, funnel) {
    _state.funnel = funnel;
  },
  [types.SET_CASE_REPORTS_OUTCOME](_state, outcome) {
    _state.outcome = outcome;
  },
  [types.SET_CASE_REPORTS_TIMESERIES](_state, timeseries) {
    _state.timeseries = timeseries;
  },
  [types.SET_CASE_REPORTS_ASSIGNEES](_state, assignees) {
    _state.assignees = assignees;
  },
  [types.SET_CASE_REPORTS_VELOCITY](_state, velocity) {
    _state.velocity = velocity;
  },
  [types.SET_CASE_REPORTS_STALLED](_state, stalled) {
    _state.stalled = stalled;
  },
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};
