// Proyecto: DEV0001
// app/javascript/dashboard/store/modules/scheduledMessages.js

import * as MutationHelpers from 'shared/helpers/vuex/mutationHelpers';
import types from '../mutation-types';
import scheduledMessagesAPI from '../../api/scheduledMessages';

export const state = {
  records: [],
  uiFlags: {
    isFetching: false,
    isCreating: false,
    isUpdating: false,
    isDeleting: false,
  },
};

export const getters = {
  getUIFlags(_state) {
    return _state.uiFlags;
  },
  getScheduledMessages: _state => conversationId => {
    return _state.records.filter(
      message => message.conversation_id === Number(conversationId)
    );
  },
  getAllScheduledMessages(_state) {
    return _state.records;
  },
};

export const actions = {
  get: async ({ commit, rootState }, { conversationId }) => {
    commit(types.SET_SCHEDULED_MESSAGES_UI_FLAG, { isFetching: true });
    try {
      const response = await scheduledMessagesAPI.get(conversationId, rootState.auth.currentAccountId);
      commit(types.SET_SCHEDULED_MESSAGES, response.data);
    } catch (error) {
      console.error('Error fetching scheduled messages:', error);
      throw new Error(error.response?.data?.errors || error.message);
    } finally {
      commit(types.SET_SCHEDULED_MESSAGES_UI_FLAG, { isFetching: false });
    }
  },

  create: async ({ commit, rootState }, data) => {
    commit(types.SET_SCHEDULED_MESSAGES_UI_FLAG, { isCreating: true });
    try {
      // Agregar el accountId explícitamente
      const requestData = {
        conversation_id: data.conversationId,
        content: data.content,
        scheduled_at: data.scheduled_at,
        timezone: data.timezone,
        accountId: rootState.auth.currentAccountId
      };
      
      console.log('Creating scheduled message with data:', requestData);
      
      const response = await scheduledMessagesAPI.create(requestData);
      
      commit(types.ADD_SCHEDULED_MESSAGE, response.data);
      return response.data;
    } catch (error) {
      console.error('Error creating scheduled message:', error);
      throw new Error(error.response?.data?.errors || error.message);
    } finally {
      commit(types.SET_SCHEDULED_MESSAGES_UI_FLAG, { isCreating: false });
    }
  },

  update: async ({ commit }, { id, ...data }) => {
    commit(types.SET_SCHEDULED_MESSAGES_UI_FLAG, { isUpdating: true });
    try {
      const response = await scheduledMessagesAPI.update(id, data);
      commit(types.UPDATE_SCHEDULED_MESSAGE, response.data);
      return response.data;
    } catch (error) {
      console.error('Error updating scheduled message:', error);
      throw new Error(error.response?.data?.errors || error.message);
    } finally {
      commit(types.SET_SCHEDULED_MESSAGES_UI_FLAG, { isUpdating: false });
    }
  },

  delete: async ({ commit }, id) => {
    commit(types.SET_SCHEDULED_MESSAGES_UI_FLAG, { isDeleting: true });
    try {
      await scheduledMessagesAPI.delete(id);
      commit(types.REMOVE_SCHEDULED_MESSAGE, id);
    } catch (error) {
      console.error('Error deleting scheduled message:', error);
      throw new Error(error.response?.data?.errors || error.message);
    } finally {
      commit(types.SET_SCHEDULED_MESSAGES_UI_FLAG, { isDeleting: false });
    }
  },
};

export const mutations = {
  [types.SET_SCHEDULED_MESSAGES_UI_FLAG](_state, data) {
    _state.uiFlags = {
      ..._state.uiFlags,
      ...data,
    };
  },

  [types.SET_SCHEDULED_MESSAGES]: MutationHelpers.set,
  
  [types.ADD_SCHEDULED_MESSAGE]: MutationHelpers.create,
  
  [types.UPDATE_SCHEDULED_MESSAGE]: MutationHelpers.update,
  
  [types.REMOVE_SCHEDULED_MESSAGE]: MutationHelpers.destroy,
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};