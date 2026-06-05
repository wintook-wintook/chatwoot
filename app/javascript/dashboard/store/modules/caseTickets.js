// ================================================================================
// @tickets_cases
// ================================================================================
// Store Vuex: caseTickets
// Estado:
//   activeTickets[contactId] → CaseTicket más reciente no cerrado/cancelado (Fase 3)
//   events[ticketId]         → Array de CaseEvent (timeline)
//   ticketsList              → Array para la vista lista (Fase 4)
//   ticketsMeta              → Paginación de la lista
//   rules                    → Array de CaseRule
// ================================================================================

import caseTicketsAPI from '../../api/caseTickets';
import caseRulesAPI from '../../api/caseRules';
import caseTypesAPI from '../../api/caseTypes';
import caseFolioConfigAPI from '../../api/caseFolioConfig';
import {
  SET_CASE_TICKET_UI_FLAG,
  SET_ACTIVE_CASE_TICKET,
  SET_CASE_TICKET_EVENTS,
  SET_CASE_TICKETS_LIST,
  SET_CASE_TICKETS_META,
  SET_CASE_RULES,
  SET_CASE_RULES_UI_FLAG,
  SET_CASE_METRICS,
  SET_CASE_TYPES,
  SET_CASE_TYPES_UI_FLAG,
  SET_CASE_FOLIO_CONFIG,
} from '../mutation-types';

const CLOSED_STATUSES = ['closed', 'cancelled'];

const state = {
  // Fase 3 — panel derecho
  activeTickets: {},
  events: {},
  uiFlags: {
    isFetching: false,
    isCreating: false,
    isTransitioning: false,
    isFetchingEvents: false,
    isFetchingList: false,
  },
  // Fase 4 — vista lista
  ticketsList: [],
  ticketsMeta: {},
  // Fase 5 — métricas
  metrics: null,
  // Fase 4 — reglas
  rules: [],
  rulesUiFlags: {
    isFetching: false,
    isSaving: false,
    isDeleting: false,
  },
  // Tipos de caso configurables por cuenta
  types: [],
  typesUiFlags: {
    isFetching: false,
    isSaving: false,
    isDeleting: false,
  },
  // Configuración de folio
  folioConfig: null,
};

export const getters = {
  // Fase 3
  getActiveTicket: _state => contactId =>
    _state.activeTickets[contactId] || null,
  getTicketEvents: _state => ticketId =>
    _state.events[ticketId] || [],
  getUIFlags(_state) {
    return _state.uiFlags;
  },
  // Fase 4
  getTicketsList(_state) {
    return _state.ticketsList;
  },
  getTicketsMeta(_state) {
    return _state.ticketsMeta;
  },
  getTicketById: _state => id =>
    _state.ticketsList.find(t => t.id === Number(id)) || null,
  getRules(_state) {
    return _state.rules;
  },
  getRulesUIFlags(_state) {
    return _state.rulesUiFlags;
  },
  getMetrics(_state) {
    return _state.metrics;
  },
  getTypes(_state) {
    return _state.types;
  },
  getTypesUIFlags(_state) {
    return _state.typesUiFlags;
  },
  getFolioConfig(_state) {
    return _state.folioConfig;
  },
};

export const actions = {
  // ── Fase 3 ──────────────────────────────────────────────────
  async fetchActiveTicket({ commit }, { contactId }) {
    commit(SET_CASE_TICKET_UI_FLAG, { isFetching: true });
    try {
      const { data } = await caseTicketsAPI.getAll({
        contact_id: contactId,
        per_page: 10,
      });
      const ticket =
        (data.case_tickets || []).find(
          t => !CLOSED_STATUSES.includes(t.status)
        ) || null;
      commit(SET_ACTIVE_CASE_TICKET, { contactId, ticket });
    } catch (_e) {
      commit(SET_ACTIVE_CASE_TICKET, { contactId, ticket: null });
    } finally {
      commit(SET_CASE_TICKET_UI_FLAG, { isFetching: false });
    }
  },

  async createTicket({ commit }, payload) {
    commit(SET_CASE_TICKET_UI_FLAG, { isCreating: true });
    try {
      const { data } = await caseTicketsAPI.create({ case_ticket: payload });
      const ticket = data.case_ticket;
      commit(SET_ACTIVE_CASE_TICKET, { contactId: ticket.contact_id, ticket });
      return ticket;
    } finally {
      commit(SET_CASE_TICKET_UI_FLAG, { isCreating: false });
    }
  },

  async transitionTicket({ commit }, { ticketId, contactId, status, reason }) {
    commit(SET_CASE_TICKET_UI_FLAG, { isTransitioning: true });
    try {
      const { data } = await caseTicketsAPI.transition(ticketId, status, reason);
      const ticket = data.case_ticket;
      if (contactId) commit(SET_ACTIVE_CASE_TICKET, { contactId, ticket });
      // Actualizar en la lista si está cargada
      commit(SET_CASE_TICKETS_LIST, null); // forzar refetch en el próximo acceso
      return ticket;
    } finally {
      commit(SET_CASE_TICKET_UI_FLAG, { isTransitioning: false });
    }
  },

  async fetchEvents({ commit }, { ticketId }) {
    commit(SET_CASE_TICKET_UI_FLAG, { isFetchingEvents: true });
    try {
      const { data } = await caseTicketsAPI.getEvents(ticketId);
      commit(SET_CASE_TICKET_EVENTS, { ticketId, events: data.case_events || [] });
    } finally {
      commit(SET_CASE_TICKET_UI_FLAG, { isFetchingEvents: false });
    }
  },

  // ── Fase 4 — Lista ──────────────────────────────────────────
  async fetchTickets({ commit }, filters = {}) {
    commit(SET_CASE_TICKET_UI_FLAG, { isFetchingList: true });
    try {
      const { data } = await caseTicketsAPI.getAll({ per_page: 25, ...filters });
      commit(SET_CASE_TICKETS_LIST, data.case_tickets || []);
      commit(SET_CASE_TICKETS_META, data.meta || {});
    } finally {
      commit(SET_CASE_TICKET_UI_FLAG, { isFetchingList: false });
    }
  },

  // ── Fase 5 — Métricas ───────────────────────────────────────
  async fetchMetrics({ commit }, params = {}) {
    commit(SET_CASE_TICKET_UI_FLAG, { isFetchingList: true });
    try {
      const { data } = await caseTicketsAPI.getMetrics(params);
      commit(SET_CASE_METRICS, data);
    } finally {
      commit(SET_CASE_TICKET_UI_FLAG, { isFetchingList: false });
    }
  },

  // ── Fase 4 — Reglas ─────────────────────────────────────────
  async fetchRules({ commit }) {
    commit(SET_CASE_RULES_UI_FLAG, { isFetching: true });
    try {
      const { data } = await caseRulesAPI.getAll();
      commit(SET_CASE_RULES, data.case_rules || []);
    } finally {
      commit(SET_CASE_RULES_UI_FLAG, { isFetching: false });
    }
  },

  async createRule({ commit, state: s }, payload) {
    commit(SET_CASE_RULES_UI_FLAG, { isSaving: true });
    try {
      const { data } = await caseRulesAPI.create({ case_rule: payload });
      commit(SET_CASE_RULES, [...s.rules, data.case_rule]);
      return data.case_rule;
    } finally {
      commit(SET_CASE_RULES_UI_FLAG, { isSaving: false });
    }
  },

  async updateRule({ commit, state: s }, { id, ...payload }) {
    commit(SET_CASE_RULES_UI_FLAG, { isSaving: true });
    try {
      const { data } = await caseRulesAPI.update(id, { case_rule: payload });
      commit(
        SET_CASE_RULES,
        s.rules.map(r => (r.id === id ? data.case_rule : r))
      );
      return data.case_rule;
    } finally {
      commit(SET_CASE_RULES_UI_FLAG, { isSaving: false });
    }
  },

  async deleteRule({ commit, state: s }, id) {
    commit(SET_CASE_RULES_UI_FLAG, { isDeleting: true });
    try {
      await caseRulesAPI.delete(id);
      commit(SET_CASE_RULES, s.rules.filter(r => r.id !== id));
    } finally {
      commit(SET_CASE_RULES_UI_FLAG, { isDeleting: false });
    }
  },

  // ── Tipos de caso ───────────────────────────────────────────
  async fetchTypes({ commit }) {
    commit(SET_CASE_TYPES_UI_FLAG, { isFetching: true });
    try {
      const { data } = await caseTypesAPI.getAll();
      commit(SET_CASE_TYPES, data.case_types || []);
    } finally {
      commit(SET_CASE_TYPES_UI_FLAG, { isFetching: false });
    }
  },

  async createType({ commit, state: s }, payload) {
    commit(SET_CASE_TYPES_UI_FLAG, { isSaving: true });
    try {
      const { data } = await caseTypesAPI.create({ case_type: payload });
      commit(SET_CASE_TYPES, [...s.types, data.case_type]);
      return data.case_type;
    } finally {
      commit(SET_CASE_TYPES_UI_FLAG, { isSaving: false });
    }
  },

  async updateType({ commit, state: s }, { id, ...payload }) {
    commit(SET_CASE_TYPES_UI_FLAG, { isSaving: true });
    try {
      const { data } = await caseTypesAPI.update(id, { case_type: payload });
      commit(
        SET_CASE_TYPES,
        s.types.map(t => (t.id === id ? data.case_type : t))
      );
      return data.case_type;
    } finally {
      commit(SET_CASE_TYPES_UI_FLAG, { isSaving: false });
    }
  },

  async deleteType({ commit, state: s }, id) {
    commit(SET_CASE_TYPES_UI_FLAG, { isDeleting: true });
    try {
      await caseTypesAPI.delete(id);
      commit(SET_CASE_TYPES, s.types.filter(t => t.id !== id));
    } finally {
      commit(SET_CASE_TYPES_UI_FLAG, { isDeleting: false });
    }
  },

  // ── Configuración de folio ──────────────────────────────────
  async fetchFolioConfig({ commit }) {
    const { data } = await caseFolioConfigAPI.get();
    commit(SET_CASE_FOLIO_CONFIG, data.case_folio_config);
  },

  async updateFolioConfig({ commit }, payload) {
    const { data } = await caseFolioConfigAPI.updateConfig(payload);
    commit(SET_CASE_FOLIO_CONFIG, data.case_folio_config);
    return data.case_folio_config;
  },
};

export const mutations = {
  [SET_CASE_TICKET_UI_FLAG](_state, flags) {
    _state.uiFlags = { ..._state.uiFlags, ...flags };
  },
  [SET_ACTIVE_CASE_TICKET](_state, { contactId, ticket }) {
    _state.activeTickets = { ..._state.activeTickets, [contactId]: ticket };
  },
  [SET_CASE_TICKET_EVENTS](_state, { ticketId, events }) {
    _state.events = { ..._state.events, [ticketId]: events };
  },
  [SET_CASE_TICKETS_LIST](_state, list) {
    _state.ticketsList = list || [];
  },
  [SET_CASE_TICKETS_META](_state, meta) {
    _state.ticketsMeta = meta;
  },
  [SET_CASE_RULES](_state, rules) {
    _state.rules = rules;
  },
  [SET_CASE_RULES_UI_FLAG](_state, flags) {
    _state.rulesUiFlags = { ..._state.rulesUiFlags, ...flags };
  },
  [SET_CASE_METRICS](_state, data) {
    _state.metrics = data;
  },
  [SET_CASE_TYPES](_state, types) {
    _state.types = types;
  },
  [SET_CASE_TYPES_UI_FLAG](_state, flags) {
    _state.typesUiFlags = { ..._state.typesUiFlags, ...flags };
  },
  [SET_CASE_FOLIO_CONFIG](_state, config) {
    _state.folioConfig = config;
  },
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};
