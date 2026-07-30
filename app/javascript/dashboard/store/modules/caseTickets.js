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
import caseServicesAPI from '../../api/caseServices';
import caseCategoriesAPI from '../../api/caseCategories';
import caseFolioConfigAPI from '../../api/caseFolioConfig';
import caseSlaPoliciesAPI from '../../api/caseSlaPolicies';
import caseTypeFieldsAPI from '../../api/caseTypeFields';
import caseTypeColumnsAPI from '../../api/caseTypeColumns';
import caseAiConfigAPI from '../../api/caseAiConfig';
import casePortalsAPI from '../../api/casePortals';
import caseSettingsAPI from '../../api/caseSettings';
import caseTasksAPI from '../../api/caseTasks';
import {
  SET_CASE_TICKET_UI_FLAG,
  SET_ACTIVE_CASE_TICKET,
  SET_CONTACT_CASE_TICKETS,
  SET_CASE_TICKET_EVENTS,
  SET_CASE_TICKETS_LIST,
  SET_CASE_TICKETS_META,
  SET_CASE_RULES,
  SET_CASE_RULES_UI_FLAG,
  SET_CASE_METRICS,
  SET_CASE_TYPES,
  SET_CASE_TYPES_UI_FLAG,
  SET_CASE_SERVICES,
  SET_CASE_SERVICES_UI_FLAG,
  SET_CASE_CATEGORIES,
  SET_CASE_CATEGORIES_UI_FLAG,
  SET_CASE_BOARD,
  SET_CASE_BOARD_UI_FLAG,
  SET_CASE_FOLIO_CONFIG,
  SET_CASE_RELATIONS,
  SET_CASE_RELATIONS_UI_FLAG,
  SET_CASE_SLA_POLICIES,
  SET_CASE_SLA_POLICIES_UI_FLAG,
  SET_CASE_TYPE_FIELDS,
  SET_CASE_TYPE_FIELDS_UI_FLAG,
  SET_CASE_TYPE_COLUMNS,
  SET_CASE_TYPE_COLUMNS_UI_FLAG,
  SET_CASE_AI_CONFIG,
  SET_CASE_AI_CONFIG_UI_FLAG,
  SET_CASE_PORTALS,
  SET_CASE_PORTALS_UI_FLAG,
  SET_CASE_SETTINGS,
  SET_CASE_SETTINGS_UI_FLAG,
  SET_CASE_MY_TASKS,
  SET_CASE_MY_TASKS_UI_FLAG,
} from '../mutation-types';

const CLOSED_STATUSES = ['closed', 'cancelled'];

const state = {
  // Fase 3 — panel derecho
  activeTickets: {},
  // Panel de contacto — todos los tickets en proceso por contactId
  contactTickets: {},
  events: {},
  uiFlags: {
    isFetching: false,
    isCreating: false,
    isSaving: false, // @tickets_cases — edición del ticket desde el modal
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
  // User Portal — portales públicos del cliente
  portals: [],
  portalsUiFlags: {
    isFetching: false,
    isSaving: false,
    isDeleting: false,
  },
  // Modo simple (osTicket) vs ITIL + reglas de reapertura — ajustes del módulo
  settings: {
    itil_enabled: false,
    reopen_window_days: 30,
    reopen_on_customer_reply: true,
  },
  settingsUiFlags: {
    isFetching: false,
    isSaving: false,
  },
  // 2B — Servicios afectados configurables por cuenta
  services: [],
  servicesUiFlags: {
    isFetching: false,
    isSaving: false,
    isDeleting: false,
  },
  // 2B — Categorías (con subcategorías) configurables por cuenta
  categories: [],
  categoriesUiFlags: {
    isFetching: false,
    isSaving: false,
    isDeleting: false,
  },
  // 2C — Tablero Kanban (lista plana, se agrupa por estado en el front)
  boardTickets: [],
  boardSlaOverdue: 0, // conteo global de vencidos para el badge del tab
  boardUiFlags: {
    isFetching: false,
  },
  // Configuración de folio
  folioConfig: null,
  // 2E — Relaciones entre tickets, indexadas por ticketId
  relations: {},
  relationsUiFlags: {
    isFetching: false,
    isSaving: false,
    isDeleting: false,
  },
  // 2I — Políticas SLA configurables por cuenta
  slaPolicies: [],
  slaPoliciesUiFlags: {
    isFetching: false,
    isSaving: false,
    isDeleting: false,
  },
  // 2K — Campos personalizados por tipo de caso, indexados por caseTypeId
  typeFields: {},
  typeFieldsUiFlags: {
    isFetching: false,
    isSaving: false,
    isDeleting: false,
  },
  // Columnas del Kanban por tipo de caso (Opción A+), indexadas por caseTypeId
  typeColumns: {},
  typeColumnsUiFlags: {
    isFetching: false,
    isSaving: false,
  },
  // 3A — Configuración de IA por cuenta
  aiConfig: null,
  aiConfigUiFlags: {
    isFetching: false,
    isSaving: false,
  },
  // Bandeja de tareas — índice a nivel cuenta ("¿qué tengo asignado?")
  myTasks: [],
  myTasksMeta: {},
  myTasksUiFlags: {
    isFetching: false,
  },
};

export const getters = {
  // Fase 3
  getActiveTicket: _state => contactId =>
    _state.activeTickets[contactId] || null,
  // Tickets en proceso del contacto (panel de conversación)
  getContactTickets: _state => contactId =>
    _state.contactTickets[contactId] || [],
  getTicketEvents: _state => ticketId => _state.events[ticketId] || [],
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
  // User Portal
  getPortals(_state) {
    return _state.portals;
  },
  getPortalsUIFlags(_state) {
    return _state.portalsUiFlags;
  },
  // Modo simple/ITIL + reapertura
  getItilEnabled(_state) {
    return _state.settings.itil_enabled;
  },
  getCaseSettings(_state) {
    return _state.settings;
  },
  getSettingsUIFlags(_state) {
    return _state.settingsUiFlags;
  },
  // 2K — campos personalizados de un tipo de caso
  getTypeFields: _state => caseTypeId => _state.typeFields[caseTypeId] || [],
  getTypeFieldsUIFlags(_state) {
    return _state.typeFieldsUiFlags;
  },
  // Columnas del Kanban de un tipo de caso (Opción A+)
  getTypeColumns: _state => caseTypeId => _state.typeColumns[caseTypeId] || [],
  getTypeColumnsUIFlags(_state) {
    return _state.typeColumnsUiFlags;
  },
  // 3A — configuración de IA
  getAiConfig(_state) {
    return _state.aiConfig;
  },
  getAiConfigUIFlags(_state) {
    return _state.aiConfigUiFlags;
  },
  getServices(_state) {
    return _state.services;
  },
  getServicesUIFlags(_state) {
    return _state.servicesUiFlags;
  },
  getCategories(_state) {
    return _state.categories;
  },
  getCategoriesUIFlags(_state) {
    return _state.categoriesUiFlags;
  },
  getBoardTickets(_state) {
    return _state.boardTickets;
  },
  getBoardSlaOverdue(_state) {
    return _state.boardSlaOverdue;
  },
  getBoardUIFlags(_state) {
    return _state.boardUiFlags;
  },
  getFolioConfig(_state) {
    return _state.folioConfig;
  },
  getTicketRelations: _state => ticketId => _state.relations[ticketId] || [],
  getRelationsUIFlags(_state) {
    return _state.relationsUiFlags;
  },
  getSlaPolicies(_state) {
    return _state.slaPolicies;
  },
  getSlaPoliciesUIFlags(_state) {
    return _state.slaPoliciesUiFlags;
  },
  getMyTasks(_state) {
    return _state.myTasks;
  },
  getMyTasksMeta(_state) {
    return _state.myTasksMeta;
  },
  getMyTasksUIFlags(_state) {
    return _state.myTasksUiFlags;
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

  // Lista de tickets en proceso (no cerrados/cancelados) del contacto.
  async fetchContactTickets({ commit }, { contactId }) {
    commit(SET_CASE_TICKET_UI_FLAG, { isFetching: true });
    try {
      const { data } = await caseTicketsAPI.getAll({
        contact_id: contactId,
        per_page: 50,
      });
      const tickets = (data.case_tickets || []).filter(
        t => !CLOSED_STATUSES.includes(t.status)
      );
      commit(SET_CONTACT_CASE_TICKETS, { contactId, tickets });
    } catch (_e) {
      commit(SET_CONTACT_CASE_TICKETS, { contactId, tickets: [] });
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

  async transitionTicket(
    { commit },
    { ticketId, contactId, status, reason, propagateToIncidents, closure }
  ) {
    commit(SET_CASE_TICKET_UI_FLAG, { isTransitioning: true });
    try {
      const extra = {};
      if (propagateToIncidents) extra.propagate_to_incidents = true;
      if (closure) extra.closure = closure;
      const { data } = await caseTicketsAPI.transition(
        ticketId,
        status,
        reason,
        extra
      );
      const ticket = data.case_ticket;
      if (contactId) commit(SET_ACTIVE_CASE_TICKET, { contactId, ticket });
      // Actualizar en la lista si está cargada
      commit(SET_CASE_TICKETS_LIST, null); // forzar refetch en el próximo acceso
      return data;
    } finally {
      commit(SET_CASE_TICKET_UI_FLAG, { isTransitioning: false });
    }
  },

  // @tickets_cases — mueve un ticket a otra columna del Kanban por tipo (A+).
  async moveTicketColumn({ commit }, { ticketId, caseTypeColumnId }) {
    commit(SET_CASE_TICKET_UI_FLAG, { isTransitioning: true });
    try {
      const { data } = await caseTicketsAPI.move(ticketId, caseTypeColumnId);
      return data;
    } finally {
      commit(SET_CASE_TICKET_UI_FLAG, { isTransitioning: false });
    }
  },

  // @tickets_cases P3 — acción en lote (assign/transition) sobre varios tickets.
  async bulkAction({ commit }, params) {
    commit(SET_CASE_TICKET_UI_FLAG, { isTransitioning: true });
    try {
      const { data } = await caseTicketsAPI.bulk(params);
      return data;
    } finally {
      commit(SET_CASE_TICKET_UI_FLAG, { isTransitioning: false });
    }
  },

  // @tickets_cases 2D — escalamiento por niveles
  async escalateTicket(
    { commit },
    { ticketId, contactId, teamId, assigneeId, reason }
  ) {
    commit(SET_CASE_TICKET_UI_FLAG, { isTransitioning: true });
    try {
      const { data } = await caseTicketsAPI.escalate(ticketId, {
        team_id: teamId,
        assignee_id: assigneeId,
        reason,
      });
      const ticket = data.case_ticket;
      if (contactId) commit(SET_ACTIVE_CASE_TICKET, { contactId, ticket });
      return ticket;
    } finally {
      commit(SET_CASE_TICKET_UI_FLAG, { isTransitioning: false });
    }
  },

  // @tickets_cases Fase A — asignación manual a agente y/o equipo (coexisten).
  // Envía solo las claves presentes en el payload; '' / null limpia ese campo.
  // @tickets_cases — reabre un ticket cerrado y refresca ficha + timeline.
  async reopenTicket({ commit }, { ticketId, contactId, reason }) {
    const { data } = await caseTicketsAPI.reopen(ticketId, reason);
    const ticket = data.case_ticket;
    if (contactId) commit(SET_ACTIVE_CASE_TICKET, { contactId, ticket });
    commit(SET_CASE_TICKETS_LIST, null); // forzar refetch de la cola
    return ticket;
  },

  async assignTicket({ commit }, { ticketId, contactId, assigneeId, teamId }) {
    commit(SET_CASE_TICKET_UI_FLAG, { isTransitioning: true });
    try {
      const params = {};
      if (assigneeId !== undefined) params.assignee_id = assigneeId ?? '';
      if (teamId !== undefined) params.team_id = teamId ?? '';
      const { data } = await caseTicketsAPI.assign(ticketId, params);
      const ticket = data.case_ticket;
      if (contactId) commit(SET_ACTIVE_CASE_TICKET, { contactId, ticket });
      return ticket;
    } finally {
      commit(SET_CASE_TICKET_UI_FLAG, { isTransitioning: false });
    }
  },

  // @tickets_cases 2F — edita campos ITIL (Problema/Cambio) y aprueba/rechaza cambios.
  mergeTicket({ commit, state: s }, ticket) {
    const exists = s.ticketsList.some(t => t.id === ticket.id);
    const list = exists
      ? s.ticketsList.map(t => (t.id === ticket.id ? ticket : t))
      : [...s.ticketsList, ticket];
    commit(SET_CASE_TICKETS_LIST, list);
  },

  async updateTicketDetails({ dispatch }, { ticketId, details }) {
    const { data } = await caseTicketsAPI.update(ticketId, {
      case_ticket: { custom_attributes: details },
    });
    dispatch('mergeTicket', data.case_ticket);
    return data.case_ticket;
  },

  // @tickets_cases — edición completa del ticket desde el modal (título,
  // descripción, clasificación). Manda solo los campos que envía el modal.
  async editTicket({ commit, dispatch }, { ticketId, contactId, fields }) {
    commit(SET_CASE_TICKET_UI_FLAG, { isSaving: true });
    try {
      const { data } = await caseTicketsAPI.update(ticketId, {
        case_ticket: fields,
      });
      const ticket = data.case_ticket;
      dispatch('mergeTicket', ticket);
      if (contactId) commit(SET_ACTIVE_CASE_TICKET, { contactId, ticket });
      return ticket;
    } finally {
      commit(SET_CASE_TICKET_UI_FLAG, { isSaving: false });
    }
  },

  // @tickets_cases P1 — cambio de prioridad inline (acción rápida estilo osTicket).
  async updatePriority(
    { commit, dispatch },
    { ticketId, contactId, priority }
  ) {
    commit(SET_CASE_TICKET_UI_FLAG, { isTransitioning: true });
    try {
      const { data } = await caseTicketsAPI.update(ticketId, {
        case_ticket: { priority },
      });
      const ticket = data.case_ticket;
      dispatch('mergeTicket', ticket);
      if (contactId) commit(SET_ACTIVE_CASE_TICKET, { contactId, ticket });
      return ticket;
    } finally {
      commit(SET_CASE_TICKET_UI_FLAG, { isTransitioning: false });
    }
  },

  // @tickets_cases P4 — vencimiento inline (osTicket "Due Date"). dueAt ISO o null (limpiar).
  async updateDueAt({ commit, dispatch }, { ticketId, contactId, dueAt }) {
    const { data } = await caseTicketsAPI.update(ticketId, {
      case_ticket: { due_at: dueAt },
    });
    const ticket = data.case_ticket;
    dispatch('mergeTicket', ticket);
    if (contactId) commit(SET_ACTIVE_CASE_TICKET, { contactId, ticket });
    return ticket;
  },

  async changeApproval({ dispatch }, { ticketId, status, reason }) {
    const { data } = await caseTicketsAPI.changeApproval(ticketId, {
      status,
      reason,
    });
    dispatch('mergeTicket', data.case_ticket);
    return data.case_ticket;
  },

  // @tickets_cases 2H — base de conocimiento
  async fetchKbPortals() {
    const { data } = await caseTicketsAPI.getKbPortals();
    return data.portals || [];
  },

  async generateArticle({ dispatch }, { ticketId, ...params }) {
    const { data } = await caseTicketsAPI.generateArticle(ticketId, params);
    dispatch('mergeTicket', data.case_ticket);
    return data.article;
  },

  async fetchEvents({ commit }, { ticketId }) {
    commit(SET_CASE_TICKET_UI_FLAG, { isFetchingEvents: true });
    try {
      const { data } = await caseTicketsAPI.getEvents(ticketId);
      commit(SET_CASE_TICKET_EVENTS, {
        ticketId,
        events: data.case_events || [],
      });
    } finally {
      commit(SET_CASE_TICKET_UI_FLAG, { isFetchingEvents: false });
    }
  },

  // ── Fase 4 — Lista ──────────────────────────────────────────
  async fetchTickets({ commit }, filters = {}) {
    commit(SET_CASE_TICKET_UI_FLAG, { isFetchingList: true });
    try {
      const { data } = await caseTicketsAPI.getAll({
        per_page: 25,
        ...filters,
      });
      commit(SET_CASE_TICKETS_LIST, data.case_tickets || []);
      commit(SET_CASE_TICKETS_META, data.meta || {});
    } finally {
      commit(SET_CASE_TICKET_UI_FLAG, { isFetchingList: false });
    }
  },

  // @tickets_cases — carga un ticket individual por id y lo fusiona en la lista
  // (necesario para que el detalle funcione al entrar por URL directa, no solo vía SPA).
  async fetchTicket({ commit, state: s }, id) {
    commit(SET_CASE_TICKET_UI_FLAG, { isFetchingList: true });
    try {
      const { data } = await caseTicketsAPI.show(id);
      const ticket = data.case_ticket;
      const exists = s.ticketsList.some(t => t.id === ticket.id);
      const list = exists
        ? s.ticketsList.map(t => (t.id === ticket.id ? ticket : t))
        : [...s.ticketsList, ticket];
      commit(SET_CASE_TICKETS_LIST, list);
      return ticket;
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
      commit(
        SET_CASE_RULES,
        s.rules.filter(r => r.id !== id)
      );
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
      commit(
        SET_CASE_TYPES,
        s.types.filter(t => t.id !== id)
      );
    } finally {
      commit(SET_CASE_TYPES_UI_FLAG, { isDeleting: false });
    }
  },

  // ── User Portal — portales públicos del cliente ─────────────
  async fetchPortals({ commit }) {
    commit(SET_CASE_PORTALS_UI_FLAG, { isFetching: true });
    try {
      const { data } = await casePortalsAPI.get();
      commit(SET_CASE_PORTALS, data.case_portals || []);
    } finally {
      commit(SET_CASE_PORTALS_UI_FLAG, { isFetching: false });
    }
  },
  async createPortal({ commit, state: s }, payload) {
    commit(SET_CASE_PORTALS_UI_FLAG, { isSaving: true });
    try {
      const { data } = await casePortalsAPI.create({ case_portal: payload });
      commit(SET_CASE_PORTALS, [...s.portals, data.case_portal]);
      return data.case_portal;
    } finally {
      commit(SET_CASE_PORTALS_UI_FLAG, { isSaving: false });
    }
  },
  async updatePortal({ commit, state: s }, { id, ...payload }) {
    commit(SET_CASE_PORTALS_UI_FLAG, { isSaving: true });
    try {
      const { data } = await casePortalsAPI.update(id, {
        case_portal: payload,
      });
      commit(
        SET_CASE_PORTALS,
        s.portals.map(p => (p.id === id ? data.case_portal : p))
      );
      return data.case_portal;
    } finally {
      commit(SET_CASE_PORTALS_UI_FLAG, { isSaving: false });
    }
  },
  async deletePortal({ commit, state: s }, id) {
    commit(SET_CASE_PORTALS_UI_FLAG, { isDeleting: true });
    try {
      await casePortalsAPI.delete(id);
      commit(
        SET_CASE_PORTALS,
        s.portals.filter(p => p.id !== id)
      );
    } finally {
      commit(SET_CASE_PORTALS_UI_FLAG, { isDeleting: false });
    }
  },

  // ── Modo simple (osTicket) vs ITIL ──────────────────────────
  async fetchSettings({ commit }) {
    commit(SET_CASE_SETTINGS_UI_FLAG, { isFetching: true });
    try {
      const { data } = await caseSettingsAPI.show();
      commit(SET_CASE_SETTINGS, data);
    } finally {
      commit(SET_CASE_SETTINGS_UI_FLAG, { isFetching: false });
    }
  },
  async updateSettings({ commit }, payload) {
    commit(SET_CASE_SETTINGS_UI_FLAG, { isSaving: true });
    try {
      const { data } = await caseSettingsAPI.updateSettings({
        case_setting: payload,
      });
      commit(SET_CASE_SETTINGS, data);
      return data;
    } finally {
      commit(SET_CASE_SETTINGS_UI_FLAG, { isSaving: false });
    }
  },

  // ── 2K — Campos personalizados por tipo de caso ─────────────
  async fetchTypeFields({ commit }, caseTypeId) {
    commit(SET_CASE_TYPE_FIELDS_UI_FLAG, { isFetching: true });
    try {
      const { data } = await caseTypeFieldsAPI.getAll(caseTypeId);
      commit(SET_CASE_TYPE_FIELDS, {
        caseTypeId,
        fields: data.case_type_fields || [],
      });
    } finally {
      commit(SET_CASE_TYPE_FIELDS_UI_FLAG, { isFetching: false });
    }
  },

  async createTypeField({ commit, state: s }, { caseTypeId, ...payload }) {
    commit(SET_CASE_TYPE_FIELDS_UI_FLAG, { isSaving: true });
    try {
      const { data } = await caseTypeFieldsAPI.createField(caseTypeId, payload);
      commit(SET_CASE_TYPE_FIELDS, {
        caseTypeId,
        fields: [...(s.typeFields[caseTypeId] || []), data.case_type_field],
      });
      return data.case_type_field;
    } finally {
      commit(SET_CASE_TYPE_FIELDS_UI_FLAG, { isSaving: false });
    }
  },

  async updateTypeField({ commit, state: s }, { caseTypeId, id, ...payload }) {
    commit(SET_CASE_TYPE_FIELDS_UI_FLAG, { isSaving: true });
    try {
      const { data } = await caseTypeFieldsAPI.updateField(
        caseTypeId,
        id,
        payload
      );
      commit(SET_CASE_TYPE_FIELDS, {
        caseTypeId,
        fields: (s.typeFields[caseTypeId] || []).map(f =>
          f.id === id ? data.case_type_field : f
        ),
      });
      return data.case_type_field;
    } finally {
      commit(SET_CASE_TYPE_FIELDS_UI_FLAG, { isSaving: false });
    }
  },

  async deleteTypeField({ commit, state: s }, { caseTypeId, id }) {
    commit(SET_CASE_TYPE_FIELDS_UI_FLAG, { isDeleting: true });
    try {
      await caseTypeFieldsAPI.deleteField(caseTypeId, id);
      commit(SET_CASE_TYPE_FIELDS, {
        caseTypeId,
        fields: (s.typeFields[caseTypeId] || []).filter(f => f.id !== id),
      });
    } finally {
      commit(SET_CASE_TYPE_FIELDS_UI_FLAG, { isDeleting: false });
    }
  },

  // ── Columnas del Kanban por tipo (Opción A+) ─────────────────
  async fetchTypeColumns({ commit }, caseTypeId) {
    commit(SET_CASE_TYPE_COLUMNS_UI_FLAG, { isFetching: true });
    try {
      const { data } = await caseTypeColumnsAPI.getAll(caseTypeId);
      commit(SET_CASE_TYPE_COLUMNS, {
        caseTypeId,
        columns: data.case_type_columns || [],
      });
    } finally {
      commit(SET_CASE_TYPE_COLUMNS_UI_FLAG, { isFetching: false });
    }
  },

  // Guarda el set completo del tipo (crea/actualiza/borra en una transacción).
  async replaceTypeColumns({ commit }, { caseTypeId, columns }) {
    commit(SET_CASE_TYPE_COLUMNS_UI_FLAG, { isSaving: true });
    try {
      const { data } = await caseTypeColumnsAPI.replaceColumns(
        caseTypeId,
        columns
      );
      commit(SET_CASE_TYPE_COLUMNS, {
        caseTypeId,
        columns: data.case_type_columns || [],
      });
      return data.case_type_columns;
    } finally {
      commit(SET_CASE_TYPE_COLUMNS_UI_FLAG, { isSaving: false });
    }
  },

  // ── 3A — Configuración de IA ────────────────────────────────
  async fetchAiConfig({ commit }) {
    commit(SET_CASE_AI_CONFIG_UI_FLAG, { isFetching: true });
    try {
      const { data } = await caseAiConfigAPI.get();
      commit(SET_CASE_AI_CONFIG, data.case_ai_config);
    } finally {
      commit(SET_CASE_AI_CONFIG_UI_FLAG, { isFetching: false });
    }
  },

  async updateAiConfig({ commit }, payload) {
    commit(SET_CASE_AI_CONFIG_UI_FLAG, { isSaving: true });
    try {
      const { data } = await caseAiConfigAPI.updateConfig(payload);
      commit(SET_CASE_AI_CONFIG, data.case_ai_config);
      return data.case_ai_config;
    } finally {
      commit(SET_CASE_AI_CONFIG_UI_FLAG, { isSaving: false });
    }
  },

  // ── 3B — Sugerencia de clasificación IA ─────────────────────
  async applyAiSuggestion({ commit, state: s }, { ticketId, fields }) {
    const { data } = await caseTicketsAPI.applyAiSuggestion(ticketId, fields);
    commit(
      SET_CASE_TICKETS_LIST,
      s.ticketsList.map(t =>
        t.id === data.case_ticket.id ? data.case_ticket : t
      )
    );
    return data.case_ticket;
  },

  async dismissAiSuggestion({ commit, state: s }, ticketId) {
    const { data } = await caseTicketsAPI.dismissAiSuggestion(ticketId);
    commit(
      SET_CASE_TICKETS_LIST,
      s.ticketsList.map(t =>
        t.id === data.case_ticket.id ? data.case_ticket : t
      )
    );
    return data.case_ticket;
  },

  // ── 3C — Respuesta sugerida desde KB (efímera, no se persiste) ──
  async suggestReply(_ctx, ticketId) {
    const { data } = await caseTicketsAPI.suggestReply(ticketId);
    return data.suggestion;
  },

  // ── 3E — Resumen + causa raíz sugerida (efímera) ────────────
  async summarizeTicket(_ctx, ticketId) {
    const { data } = await caseTicketsAPI.summarize(ticketId);
    return data.summary;
  },

  // ── 3D — Detección de incidentes repetidos (efímera) ────────
  async detectDuplicates(_ctx, ticketId) {
    const { data } = await caseTicketsAPI.detectDuplicates(ticketId);
    return data.duplicates;
  },

  // ── 3F — Seguimiento sugerido al cliente (efímero) ──────────
  async followUp(_ctx, ticketId) {
    const { data } = await caseTicketsAPI.followUp(ticketId);
    return data.follow_up;
  },

  // ── 2B — Servicios afectados ────────────────────────────────
  async fetchServices({ commit }) {
    commit(SET_CASE_SERVICES_UI_FLAG, { isFetching: true });
    try {
      const { data } = await caseServicesAPI.getAll();
      commit(SET_CASE_SERVICES, data.case_services || []);
    } finally {
      commit(SET_CASE_SERVICES_UI_FLAG, { isFetching: false });
    }
  },

  async createService({ commit, state: s }, payload) {
    commit(SET_CASE_SERVICES_UI_FLAG, { isSaving: true });
    try {
      const { data } = await caseServicesAPI.create({ case_service: payload });
      commit(SET_CASE_SERVICES, [...s.services, data.case_service]);
      return data.case_service;
    } finally {
      commit(SET_CASE_SERVICES_UI_FLAG, { isSaving: false });
    }
  },

  async updateService({ commit, state: s }, { id, ...payload }) {
    commit(SET_CASE_SERVICES_UI_FLAG, { isSaving: true });
    try {
      const { data } = await caseServicesAPI.update(id, {
        case_service: payload,
      });
      commit(
        SET_CASE_SERVICES,
        s.services.map(x => (x.id === id ? data.case_service : x))
      );
      return data.case_service;
    } finally {
      commit(SET_CASE_SERVICES_UI_FLAG, { isSaving: false });
    }
  },

  async deleteService({ commit, state: s }, id) {
    commit(SET_CASE_SERVICES_UI_FLAG, { isDeleting: true });
    try {
      await caseServicesAPI.delete(id);
      commit(
        SET_CASE_SERVICES,
        s.services.filter(x => x.id !== id)
      );
    } finally {
      commit(SET_CASE_SERVICES_UI_FLAG, { isDeleting: false });
    }
  },

  // ── 2B — Categorías ─────────────────────────────────────────
  async fetchCategories({ commit }) {
    commit(SET_CASE_CATEGORIES_UI_FLAG, { isFetching: true });
    try {
      const { data } = await caseCategoriesAPI.getAll();
      commit(SET_CASE_CATEGORIES, data.case_categories || []);
    } finally {
      commit(SET_CASE_CATEGORIES_UI_FLAG, { isFetching: false });
    }
  },

  async createCategory({ commit, dispatch }, payload) {
    commit(SET_CASE_CATEGORIES_UI_FLAG, { isSaving: true });
    try {
      const { data } = await caseCategoriesAPI.create({
        case_category: payload,
      });
      // refetch para mantener el árbol (raíces + subcategorías) consistente
      await dispatch('fetchCategories');
      return data.case_category;
    } finally {
      commit(SET_CASE_CATEGORIES_UI_FLAG, { isSaving: false });
    }
  },

  async updateCategory({ commit, dispatch }, { id, ...payload }) {
    commit(SET_CASE_CATEGORIES_UI_FLAG, { isSaving: true });
    try {
      const { data } = await caseCategoriesAPI.update(id, {
        case_category: payload,
      });
      await dispatch('fetchCategories');
      return data.case_category;
    } finally {
      commit(SET_CASE_CATEGORIES_UI_FLAG, { isSaving: false });
    }
  },

  async deleteCategory({ commit, dispatch }, id) {
    commit(SET_CASE_CATEGORIES_UI_FLAG, { isDeleting: true });
    try {
      await caseCategoriesAPI.delete(id);
      await dispatch('fetchCategories');
    } finally {
      commit(SET_CASE_CATEGORIES_UI_FLAG, { isDeleting: false });
    }
  },

  // ── 2C — Tablero Kanban ─────────────────────────────────────
  async fetchBoardTickets({ commit }, filters = {}) {
    commit(SET_CASE_BOARD_UI_FLAG, { isFetching: true });
    try {
      const { data } = await caseTicketsAPI.getAll({
        per_page: 100,
        ...filters,
      });
      commit(SET_CASE_BOARD, {
        tickets: data.case_tickets || [],
        slaOverdue: (data.meta && data.meta.sla_overdue_count) || 0,
      });
    } finally {
      commit(SET_CASE_BOARD_UI_FLAG, { isFetching: false });
    }
  },

  // ── Bandeja de tareas ("¿qué tengo asignado?") ──────────────
  async fetchMyTasks({ commit }, filters = {}) {
    commit(SET_CASE_MY_TASKS_UI_FLAG, { isFetching: true });
    try {
      const { data } = await caseTasksAPI.getMine(filters);
      commit(SET_CASE_MY_TASKS, {
        tasks: data.case_tasks || [],
        meta: data.meta || {},
      });
    } finally {
      commit(SET_CASE_MY_TASKS_UI_FLAG, { isFetching: false });
    }
  },

  // ── 2E — Relaciones entre tickets ───────────────────────────
  async fetchRelations({ commit }, ticketId) {
    commit(SET_CASE_RELATIONS_UI_FLAG, { isFetching: true });
    try {
      const { data } = await caseTicketsAPI.getRelations(ticketId);
      commit(SET_CASE_RELATIONS, {
        ticketId,
        relations: data.case_ticket_relations || [],
      });
    } finally {
      commit(SET_CASE_RELATIONS_UI_FLAG, { isFetching: false });
    }
  },

  async createRelation(
    { commit, dispatch },
    { ticketId, relatedTicketId, relationType }
  ) {
    commit(SET_CASE_RELATIONS_UI_FLAG, { isSaving: true });
    try {
      await caseTicketsAPI.createRelation(ticketId, {
        related_ticket_id: relatedTicketId,
        relation_type: relationType,
      });
      await dispatch('fetchRelations', ticketId);
    } finally {
      commit(SET_CASE_RELATIONS_UI_FLAG, { isSaving: false });
    }
  },

  async deleteRelation({ commit, dispatch }, { ticketId, relationId }) {
    commit(SET_CASE_RELATIONS_UI_FLAG, { isDeleting: true });
    try {
      await caseTicketsAPI.deleteRelation(ticketId, relationId);
      await dispatch('fetchRelations', ticketId);
    } finally {
      commit(SET_CASE_RELATIONS_UI_FLAG, { isDeleting: false });
    }
  },

  // Búsqueda ligera de tickets (para el selector de relaciones) sin tocar la lista.
  async searchTickets(_ctx, params = {}) {
    const { data } = await caseTicketsAPI.getAll({ per_page: 10, ...params });
    return data.case_tickets || [];
  },

  // ── 2I — Políticas SLA ──────────────────────────────────────
  async fetchSlaPolicies({ commit }) {
    commit(SET_CASE_SLA_POLICIES_UI_FLAG, { isFetching: true });
    try {
      const { data } = await caseSlaPoliciesAPI.getAll();
      commit(SET_CASE_SLA_POLICIES, data.case_sla_policies || []);
    } finally {
      commit(SET_CASE_SLA_POLICIES_UI_FLAG, { isFetching: false });
    }
  },

  async createSlaPolicy({ commit, state: s }, payload) {
    commit(SET_CASE_SLA_POLICIES_UI_FLAG, { isSaving: true });
    try {
      const { data } = await caseSlaPoliciesAPI.create({
        case_sla_policy: payload,
      });
      commit(SET_CASE_SLA_POLICIES, [...s.slaPolicies, data.case_sla_policy]);
      return data.case_sla_policy;
    } finally {
      commit(SET_CASE_SLA_POLICIES_UI_FLAG, { isSaving: false });
    }
  },

  async updateSlaPolicy({ commit, state: s }, { id, ...payload }) {
    commit(SET_CASE_SLA_POLICIES_UI_FLAG, { isSaving: true });
    try {
      const { data } = await caseSlaPoliciesAPI.update(id, {
        case_sla_policy: payload,
      });
      commit(
        SET_CASE_SLA_POLICIES,
        s.slaPolicies.map(p => (p.id === id ? data.case_sla_policy : p))
      );
      return data.case_sla_policy;
    } finally {
      commit(SET_CASE_SLA_POLICIES_UI_FLAG, { isSaving: false });
    }
  },

  async deleteSlaPolicy({ commit, state: s }, id) {
    commit(SET_CASE_SLA_POLICIES_UI_FLAG, { isDeleting: true });
    try {
      await caseSlaPoliciesAPI.delete(id);
      commit(
        SET_CASE_SLA_POLICIES,
        s.slaPolicies.filter(p => p.id !== id)
      );
    } finally {
      commit(SET_CASE_SLA_POLICIES_UI_FLAG, { isDeleting: false });
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
  [SET_CONTACT_CASE_TICKETS](_state, { contactId, tickets }) {
    _state.contactTickets = {
      ..._state.contactTickets,
      [contactId]: tickets || [],
    };
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
  [SET_CASE_PORTALS](_state, portals) {
    _state.portals = portals;
  },
  [SET_CASE_PORTALS_UI_FLAG](_state, flags) {
    _state.portalsUiFlags = { ..._state.portalsUiFlags, ...flags };
  },
  [SET_CASE_SETTINGS](_state, settings) {
    _state.settings = { ..._state.settings, ...settings };
  },
  [SET_CASE_SETTINGS_UI_FLAG](_state, flags) {
    _state.settingsUiFlags = { ..._state.settingsUiFlags, ...flags };
  },
  [SET_CASE_SERVICES](_state, services) {
    _state.services = services;
  },
  [SET_CASE_SERVICES_UI_FLAG](_state, flags) {
    _state.servicesUiFlags = { ..._state.servicesUiFlags, ...flags };
  },
  [SET_CASE_CATEGORIES](_state, categories) {
    _state.categories = categories;
  },
  [SET_CASE_CATEGORIES_UI_FLAG](_state, flags) {
    _state.categoriesUiFlags = { ..._state.categoriesUiFlags, ...flags };
  },
  [SET_CASE_BOARD](_state, { tickets, slaOverdue }) {
    _state.boardTickets = tickets;
    _state.boardSlaOverdue = slaOverdue;
  },
  [SET_CASE_BOARD_UI_FLAG](_state, flags) {
    _state.boardUiFlags = { ..._state.boardUiFlags, ...flags };
  },
  [SET_CASE_FOLIO_CONFIG](_state, config) {
    _state.folioConfig = config;
  },
  [SET_CASE_RELATIONS](_state, { ticketId, relations }) {
    _state.relations = { ..._state.relations, [ticketId]: relations };
  },
  [SET_CASE_RELATIONS_UI_FLAG](_state, flags) {
    _state.relationsUiFlags = { ..._state.relationsUiFlags, ...flags };
  },
  [SET_CASE_TYPE_FIELDS](_state, { caseTypeId, fields }) {
    _state.typeFields = { ..._state.typeFields, [caseTypeId]: fields };
  },
  [SET_CASE_TYPE_FIELDS_UI_FLAG](_state, flags) {
    _state.typeFieldsUiFlags = { ..._state.typeFieldsUiFlags, ...flags };
  },
  [SET_CASE_TYPE_COLUMNS](_state, { caseTypeId, columns }) {
    _state.typeColumns = { ..._state.typeColumns, [caseTypeId]: columns };
  },
  [SET_CASE_TYPE_COLUMNS_UI_FLAG](_state, flags) {
    _state.typeColumnsUiFlags = { ..._state.typeColumnsUiFlags, ...flags };
  },
  [SET_CASE_AI_CONFIG](_state, config) {
    _state.aiConfig = config;
  },
  [SET_CASE_AI_CONFIG_UI_FLAG](_state, flags) {
    _state.aiConfigUiFlags = { ..._state.aiConfigUiFlags, ...flags };
  },
  [SET_CASE_SLA_POLICIES](_state, policies) {
    _state.slaPolicies = policies;
  },
  [SET_CASE_SLA_POLICIES_UI_FLAG](_state, flags) {
    _state.slaPoliciesUiFlags = { ..._state.slaPoliciesUiFlags, ...flags };
  },
  [SET_CASE_MY_TASKS](_state, { tasks, meta }) {
    _state.myTasks = tasks;
    _state.myTasksMeta = meta;
  },
  [SET_CASE_MY_TASKS_UI_FLAG](_state, flags) {
    _state.myTasksUiFlags = { ..._state.myTasksUiFlags, ...flags };
  },
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};
