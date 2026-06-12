// ================================================================================
// proyecto@contact_tracking
// ================================================================================
// Store: contactTrackings
// Descripción: Gestión de estado para seguimientos de contactos
// ⭐ MODIFICADO: Usa accountId desde rootGetters.getCurrentAccountId (más robusto)
// ================================================================================
import Vue from 'vue';
import * as MutationHelpers from 'shared/helpers/vuex/mutationHelpers';
import * as types from '../mutation-types';
import ContactTrackingsAPI from '../../api/contactTrackings';

export const state = {
  records: {},
  uiFlags: {
    isFetching: false,
    isCreating: false,
    isUpdating: false,
    isDeleting: false,
  },
  // proyecto@contact_tracking — Dashboard
  metrics: null,
  metricsFlags: { isFetching: false },
};

export const getters = {
  getTrackings: $state => contactId => {
    return Object.values($state.records).filter(
      tracking => tracking.contact_id === contactId
    );
  },
  getUIFlags: $state => $state.uiFlags,
  getTrackingById: $state => id => $state.records[id],
  // proyecto@contact_tracking — Dashboard
  getMetrics: $state => $state.metrics,
  getMetricsFlags: $state => $state.metricsFlags,
};

export const actions = {
  // proyecto@contact_tracking — Dashboard: agregados a nivel cuenta
  async fetchMetrics({ commit, rootGetters }, params = {}) {
    const accountId = rootGetters.getCurrentAccountId;
    commit('SET_TRACKING_METRICS_FLAG', { isFetching: true });
    try {
      const { data } = await ContactTrackingsAPI.getOverview(accountId, params);
      commit('SET_TRACKING_METRICS', data);
      return data;
    } finally {
      commit('SET_TRACKING_METRICS_FLAG', { isFetching: false });
    }
  },

  async fetch({ commit, rootGetters }, { contactId, conversationId = null }) {
    // ⭐ Obtener desde currentChat primero (más confiable), con fallback
    const currentChat = rootGetters.getSelectedChat;
    const accountId = currentChat?.account_id || rootGetters.getCurrentAccountId;
    const resolvedContactId = contactId || currentChat?.meta?.sender?.id;
    const resolvedConversationId = conversationId || currentChat?.id;

    // Validar que tenemos los IDs necesarios
    if (!accountId || !resolvedContactId) {
      console.warn('[ContactTrackings] ⚠️ IDs no disponibles:', { accountId, resolvedContactId });
      return [];
    }

    commit(types.SET_CONTACT_TRACKING_UI_FLAG, { isFetching: true });
    try {
      const params = resolvedConversationId ? { conversation_id: resolvedConversationId } : {};

      console.log('📡 API Call:', { accountId, contactId: resolvedContactId, conversationId: resolvedConversationId, params });

      const response = await ContactTrackingsAPI.get(accountId, resolvedContactId, params);

      console.log('📥 API Response:', response.data);

      // Convertir array a objeto { id: tracking } para que el getter funcione correctamente
      const trackingsList = response.data.trackings || (Array.isArray(response.data) ? response.data : []);
      const trackingsObj = {};
      trackingsList.forEach(t => {
        if (t && t.id) trackingsObj[t.id] = t;
      });
      commit(types.SET_CONTACT_TRACKINGS, trackingsObj);

      return trackingsList;

    } catch (error) {
      console.error('[ContactTrackings] Error fetching:', error);
      throw error;
    } finally {
      commit(types.SET_CONTACT_TRACKING_UI_FLAG, { isFetching: false });
    }
  },

  async create({ commit, state, rootGetters }, { contactId, contact_tracking }) {
    // ⭐ Obtener desde currentChat primero, con fallback
    const currentChat = rootGetters.getSelectedChat;
    const accountId = currentChat?.account_id || rootGetters.getCurrentAccountId;
    const resolvedContactId = contactId || currentChat?.meta?.sender?.id;
    const resolvedConversationId = contact_tracking.conversation_id || currentChat?.id;

    if (!accountId || !resolvedContactId) {
      console.error('[ContactTrackings] ⚠️ IDs no disponibles para create');
      throw new Error('accountId o contactId no disponibles');
    }

    // Asegurar que conversation_id esté en el payload
    const trackingPayload = {
      ...contact_tracking,
      conversation_id: resolvedConversationId,
    };

    commit(types.SET_CONTACT_TRACKING_UI_FLAG, { isCreating: true });

    try {
      console.log('📡 API Create:', { accountId, contactId: resolvedContactId, conversationId: resolvedConversationId });
      const response = await ContactTrackingsAPI.create(accountId, resolvedContactId, { contact_tracking: trackingPayload });

      const tracking = response.data.tracking || response.data;

      if (tracking && tracking.id) {
        Vue.set(state.records, tracking.id, tracking);
      } else {
        throw new Error('Invalid tracking object');
      }

      return tracking;

    } catch (error) {
      console.error('❌ [Store Action] create error:', error);
      throw error;

    } finally {
      commit(types.SET_CONTACT_TRACKING_UI_FLAG, { isCreating: false });
    }
  },

  async update({ commit, rootGetters }, { contactId, trackingId, contact_tracking }) {
    // ⭐ Obtener desde currentChat primero, con fallback
    const currentChat = rootGetters.getSelectedChat;
    const accountId = currentChat?.account_id || rootGetters.getCurrentAccountId;
    const resolvedContactId = contactId || currentChat?.meta?.sender?.id;

    commit(types.SET_CONTACT_TRACKING_UI_FLAG, { isUpdating: true });
    try {
      const response = await ContactTrackingsAPI.update(accountId, resolvedContactId, trackingId, { contact_tracking });
      const tracking = response.data.tracking || response.data;
      commit(types.EDIT_CONTACT_TRACKING, tracking);
      return tracking;
    } catch (error) {
      console.error('❌ [Store Action] update error:', error);
      throw error;
    } finally {
      commit(types.SET_CONTACT_TRACKING_UI_FLAG, { isUpdating: false });
    }
  },

  async pause({ commit, rootGetters }, { contactId, trackingId }) {
    // ⭐ Obtener desde currentChat primero, con fallback
    const currentChat = rootGetters.getSelectedChat;
    const accountId = currentChat?.account_id || rootGetters.getCurrentAccountId;
    const resolvedContactId = contactId || currentChat?.meta?.sender?.id;

    try {
      const response = await ContactTrackingsAPI.pause(accountId, resolvedContactId, trackingId);
      const tracking = response.data.tracking || response.data;
      commit(types.EDIT_CONTACT_TRACKING, tracking);
      return tracking;
    } catch (error) {
      console.error('❌ [Store Action] pause error:', error);
      throw error;
    }
  },

  async resume({ commit, rootGetters }, { contactId, trackingId, scheduledFor = null }) {
    // ⭐ Obtener desde currentChat primero, con fallback
    const currentChat = rootGetters.getSelectedChat;
    const accountId = currentChat?.account_id || rootGetters.getCurrentAccountId;
    const resolvedContactId = contactId || currentChat?.meta?.sender?.id;

    try {
      const data = scheduledFor ? { scheduled_for: scheduledFor } : {};
      const response = await ContactTrackingsAPI.resume(accountId, resolvedContactId, trackingId, data);
      const tracking = response.data.tracking || response.data;
      commit(types.EDIT_CONTACT_TRACKING, tracking);
      return tracking;
    } catch (error) {
      console.error('❌ [Store Action] resume error:', error);
      throw error;
    }
  },

  async cancel({ commit, rootGetters }, { contactId, trackingId }) {
    // ⭐ Obtener desde currentChat primero, con fallback
    const currentChat = rootGetters.getSelectedChat;
    const accountId = currentChat?.account_id || rootGetters.getCurrentAccountId;
    const resolvedContactId = contactId || currentChat?.meta?.sender?.id;

    try {
      const response = await ContactTrackingsAPI.cancel(accountId, resolvedContactId, trackingId);
      const tracking = response.data.tracking || response.data;
      commit(types.EDIT_CONTACT_TRACKING, tracking);
      return tracking;
    } catch (error) {
      console.error('❌ [Store Action] cancel error:', error);
      throw error;
    }
  },

  async improveText({ rootGetters }, { contactId, text, mode, context, objective }) {
    // ⭐ Obtener desde currentChat primero, con fallback
    const currentChat = rootGetters.getSelectedChat;
    const accountId = currentChat?.account_id || rootGetters.getCurrentAccountId;
    const resolvedContactId = contactId || currentChat?.meta?.sender?.id;

    try {
      const response = await ContactTrackingsAPI.improveText(accountId, resolvedContactId, text, mode, context, objective);
      return response.data;
    } catch (error) {
      console.error('❌ [Store Action] improveText error:', error);
      throw error;
    }
  },
};

export const mutations = {
  [types.SET_CONTACT_TRACKINGS]: MutationHelpers.set,
  [types.ADD_CONTACT_TRACKING]: MutationHelpers.create,

  [types.EDIT_CONTACT_TRACKING]: ($state, data) => {
    if (data && data.id) {
      Vue.set($state.records, data.id, data);
    }
  },

  [types.DELETE_CONTACT_TRACKING]: MutationHelpers.destroy,

  [types.SET_CONTACT_TRACKING_UI_FLAG]($state, uiFlags) {
    $state.uiFlags = { ...$state.uiFlags, ...uiFlags };
  },

  // proyecto@contact_tracking — Dashboard
  SET_TRACKING_METRICS($state, data) {
    Vue.set($state, 'metrics', data);
  },
  SET_TRACKING_METRICS_FLAG($state, flags) {
    $state.metricsFlags = { ...$state.metricsFlags, ...flags };
  },
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};
