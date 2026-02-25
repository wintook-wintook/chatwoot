// KANBAN0725
// app/javascript/dashboard/store/modules/kanbanConversations.js
import * as MutationHelpers from 'shared/helpers/vuex/mutationHelpers';
import types from '../mutation-types';
import KanbanAPI from '../../api/kanban';

export const state = {
  records: {},
  uiFlags: {
    isFetching: false,
    isFetchingFilteredConversations: false,
  },
  chatList: [],
  currentFilters: {
    kanban_type_process_id: null,
    kanban_process_id: null,
    status: null,
    assignee_id: null,
  },
  meta: {
    count: 0,
    current_page: 1,
  },
};

export const getters = {
  getKanbanConversations: $state => $state.chatList,
  getUIFlags: $state => $state.uiFlags,
  getCurrentFilters: $state => $state.currentFilters,
  getMeta: $state => $state.meta,
  
  getConversationsByKanbanType: $state => kanbanTypeId => {
    return $state.chatList.filter(
      conversation => conversation.kanban_type_process_id === kanbanTypeId
    );
  },
  
  getConversationsByKanbanProcess: $state => kanbanProcessId => {
    return $state.chatList.filter(
      conversation => conversation.kanban_process_id === kanbanProcessId
    );
  },
};

export const actions = {
  fetchFilteredConversations: async ({ commit }, filters) => {
    commit(types.SET_KANBAN_CONVERSATIONS_UI_FLAG, {
      isFetchingFilteredConversations: true,
    });
    
    try {
      const response = await KanbanAPI.getFilteredConversations(filters);
      commit(types.SET_KANBAN_CONVERSATIONS, response.data.data);
      commit(types.SET_KANBAN_CONVERSATIONS_META, response.data.meta);
      commit(types.SET_KANBAN_CURRENT_FILTERS, filters);
    } catch (error) {
      // Handle error
      console.error('Error fetching filtered conversations:', error);
    } finally {
      commit(types.SET_KANBAN_CONVERSATIONS_UI_FLAG, {
        isFetchingFilteredConversations: false,
      });
    }
  },

  filterByKanbanType: async ({ commit }, { kanbanTypeId, additionalFilters = {} }) => {
    commit(types.SET_KANBAN_CONVERSATIONS_UI_FLAG, {
      isFetchingFilteredConversations: true,
    });

    try {
      const filters = {
        kanban_type_process_id: kanbanTypeId,
        ...additionalFilters,
      };
      
      const response = await KanbanAPI.filterByKanbanType(filters);
      commit(types.SET_KANBAN_CONVERSATIONS, response.data.data);
      commit(types.SET_KANBAN_CONVERSATIONS_META, response.data.meta);
      commit(types.SET_KANBAN_CURRENT_FILTERS, filters);
    } catch (error) {
      console.error('Error filtering by kanban type:', error);
    } finally {
      commit(types.SET_KANBAN_CONVERSATIONS_UI_FLAG, {
        isFetchingFilteredConversations: false,
      });
    }
  },

  filterByKanbanProcess: async ({ commit }, { kanbanProcessId, additionalFilters = {} }) => {
    commit(types.SET_KANBAN_CONVERSATIONS_UI_FLAG, {
      isFetchingFilteredConversations: true,
    });

    try {
      const filters = {
        kanban_process_id: kanbanProcessId,
        ...additionalFilters,
      };
      
      const response = await KanbanAPI.filterByKanbanProcess(filters);
      commit(types.SET_KANBAN_CONVERSATIONS, response.data.data);
      commit(types.SET_KANBAN_CONVERSATIONS_META, response.data.meta);
      commit(types.SET_KANBAN_CURRENT_FILTERS, filters);
    } catch (error) {
      console.error('Error filtering by kanban process:', error);
    } finally {
      commit(types.SET_KANBAN_CONVERSATIONS_UI_FLAG, {
        isFetchingFilteredConversations: false,
      });
    }
  },

  filterByBothKanban: async ({ commit }, filters) => {
    commit(types.SET_KANBAN_CONVERSATIONS_UI_FLAG, {
      isFetchingFilteredConversations: true,
    });

    try {
      const response = await KanbanAPI.filterByBothKanban(filters);
      commit(types.SET_KANBAN_CONVERSATIONS, response.data.data);
      commit(types.SET_KANBAN_CONVERSATIONS_META, response.data.meta);
      commit(types.SET_KANBAN_CURRENT_FILTERS, filters);
      return response
    } catch (error) {
      console.error('Error filtering by both kanban fields:', error);
    } finally {
      commit(types.SET_KANBAN_CONVERSATIONS_UI_FLAG, {
        isFetchingFilteredConversations: false,
      });
    }
  },

  clearFilters: ({ commit }) => {
    commit(types.CLEAR_KANBAN_CONVERSATIONS);
    commit(types.SET_KANBAN_CURRENT_FILTERS, {
      kanban_type_process_id: null,
      kanban_process_id: null,
      status: null,
      assignee_id: null,
    });
  },
};

export const mutations = {
  [types.SET_KANBAN_CONVERSATIONS_UI_FLAG]($state, data) {
    $state.uiFlags = {
      ...$state.uiFlags,
      ...data,
    };
  },

  [types.SET_KANBAN_CONVERSATIONS]: MutationHelpers.set,
  [types.SET_KANBAN_CONVERSATIONS_META]: MutationHelpers.set,
  [types.SET_KANBAN_CURRENT_FILTERS]: MutationHelpers.set,

  [types.SET_KANBAN_CONVERSATIONS]($state, conversations) {
    $state.chatList = conversations;
  },

  [types.SET_KANBAN_CONVERSATIONS_META]($state, meta) {
    $state.meta = meta;
  },

  [types.SET_KANBAN_CURRENT_FILTERS]($state, filters) {
    $state.currentFilters = filters;
  },

  [types.CLEAR_KANBAN_CONVERSATIONS]($state) {
    $state.chatList = [];
    $state.meta = {
      count: 0,
      current_page: 1,
    };
  },
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};