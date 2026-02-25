// KANBAN0725
// app/javascript/dashboard/store/modules/kanbanTypeProcesses.js
/* global axios */
import KanbanTypeProcessAPI from '../../api/kanbanTypeProcesses';

// ✅ DEFINIR TIPOS PRIMERO
export const types = {
  SET_KANBAN_TYPE_PROCESS_UI_FLAG: 'SET_KANBAN_TYPE_PROCESS_UI_FLAG',
  SET_KANBAN_TYPE_PROCESSES: 'SET_KANBAN_TYPE_PROCESSES',
  SET_KANBAN_TYPE_PROCESS_ITEM: 'SET_KANBAN_TYPE_PROCESS_ITEM',
  ADD_KANBAN_TYPE_PROCESS: 'ADD_KANBAN_TYPE_PROCESS',
  EDIT_KANBAN_TYPE_PROCESS: 'EDIT_KANBAN_TYPE_PROCESS',
  DELETE_KANBAN_TYPE_PROCESS: 'DELETE_KANBAN_TYPE_PROCESS',
  CLEAR_KANBAN_TYPE_PROCESSES: 'CLEAR_KANBAN_TYPE_PROCESSES',
  // 🆕 NUEVO TIPO
  SET_CONVERSATION_KANBAN_INFO: 'SET_CONVERSATION_KANBAN_INFO',
};

const state = {
  records: {},
  uiFlags: {
    isFetching: false,
    isFetchingItem: false,
    isCreating: false,
    isUpdating: false,
    isDeleting: false,
    // 🆕 NUEVO FLAG
    isFetchingConversationInfo: false,
  },
  // 🆕 NUEVO ESTADO
  conversationKanbanInfo: {},
};

export const getters = {
  getKanbanTypeProcesses($state) {
    return Object.values($state.records).sort((a, b) => a.id - b.id);
  },
  getKanbanTypeProcess: $state => id => {
    return $state.records[id];
  },
  getDefaultKanbanTypeProcess($state) {
    return Object.values($state.records).find(process => process.default);
  },
  getSystemKanbanTypeProcesses($state) {
    return Object.values($state.records).filter(process => process.is_system);
  },
  getCustomKanbanTypeProcesses($state) {
    return Object.values($state.records).filter(process => !process.is_system);
  },
  getUIFlags($state) {
    return $state.uiFlags;
  },
  // 🆕 NUEVO GETTER
  getConversationKanbanInfo: $state => conversationId => {
    return $state.conversationKanbanInfo[conversationId];
  },
};

export const actions = {
  get: async function getKanbanTypeProcesses({ commit, state }) {
    // ✅ PREVENIR LLAMADAS DUPLICADAS
    if (state.uiFlags.isFetching) {
      console.log('🔄 Already fetching kanban type processes, skipping...');
      return;
    }

    commit(types.SET_KANBAN_TYPE_PROCESS_UI_FLAG, { isFetching: true });
    try {
      console.log('📡 Fetching kanban type processes...');
      const response = await KanbanTypeProcessAPI.get();
      console.log('✅ Received data:', response.data);
      
      // ✅ LIMPIAR ANTES DE SETEAR
      commit(types.CLEAR_KANBAN_TYPE_PROCESSES);
      commit(types.SET_KANBAN_TYPE_PROCESSES, response.data);
      commit(types.SET_KANBAN_TYPE_PROCESS_UI_FLAG, { isFetching: false });
    } catch (error) {
      console.error('❌ Error fetching kanban type processes:', error);
      commit(types.SET_KANBAN_TYPE_PROCESS_UI_FLAG, { isFetching: false });
      throw error;
    }
  },

  show: async function showKanbanTypeProcess({ commit }, { id }) {
    commit(types.SET_KANBAN_TYPE_PROCESS_UI_FLAG, { isFetchingItem: true });
    try {
      const response = await KanbanTypeProcessAPI.show(id);
      commit(types.SET_KANBAN_TYPE_PROCESS_ITEM, response.data);
      commit(types.SET_KANBAN_TYPE_PROCESS_UI_FLAG, { isFetchingItem: false });
    } catch (error) {
      commit(types.SET_KANBAN_TYPE_PROCESS_UI_FLAG, { isFetchingItem: false });
      throw error;
    }
  },

  create: async function createKanbanTypeProcess({ commit }, kanbanTypeProcessObj) {
    commit(types.SET_KANBAN_TYPE_PROCESS_UI_FLAG, { isCreating: true });
    try {
      console.log('📝 Creating kanban type process:', kanbanTypeProcessObj);
      const response = await KanbanTypeProcessAPI.create(kanbanTypeProcessObj);
      console.log('✅ Created successfully:', response.data);
      commit(types.ADD_KANBAN_TYPE_PROCESS, response.data);
      commit(types.SET_KANBAN_TYPE_PROCESS_UI_FLAG, { isCreating: false });
      return response.data;
    } catch (error) {
      console.error('❌ Error creating kanban type process:', error);
      commit(types.SET_KANBAN_TYPE_PROCESS_UI_FLAG, { isCreating: false });
      throw error;
    }
  },

  update: async function updateKanbanTypeProcess({ commit }, { id, ...kanbanTypeProcessObj }) {
    commit(types.SET_KANBAN_TYPE_PROCESS_UI_FLAG, { isUpdating: true });
    try {
      console.log('📝 Updating kanban type process:', id, kanbanTypeProcessObj);
      const response = await KanbanTypeProcessAPI.update(id, kanbanTypeProcessObj);
      console.log('✅ Updated successfully:', response.data);
      commit(types.EDIT_KANBAN_TYPE_PROCESS, response.data);
      commit(types.SET_KANBAN_TYPE_PROCESS_UI_FLAG, { isUpdating: false });
      return response.data;
    } catch (error) {
      console.error('❌ Error updating kanban type process:', error);
      commit(types.SET_KANBAN_TYPE_PROCESS_UI_FLAG, { isUpdating: false });
      throw error;
    }
  },

  delete: async function deleteKanbanTypeProcess({ commit }, id) {
    commit(types.SET_KANBAN_TYPE_PROCESS_UI_FLAG, { isDeleting: true });
    try {
      console.log('🗑️ Deleting kanban type process:', id);
      await KanbanTypeProcessAPI.delete(id);
      console.log('✅ Deleted successfully');
      commit(types.DELETE_KANBAN_TYPE_PROCESS, id);
      commit(types.SET_KANBAN_TYPE_PROCESS_UI_FLAG, { isDeleting: false });
    } catch (error) {
      console.error('❌ Error deleting kanban type process:', error);
      commit(types.SET_KANBAN_TYPE_PROCESS_UI_FLAG, { isDeleting: false });
      throw error;
    }
  },
  // 🆕 NUEVA ACTION
  getConversationKanbanInfo: async function getConversationKanbanInfo({ commit }, conversationId) {
    commit(types.SET_KANBAN_TYPE_PROCESS_UI_FLAG, { isFetchingConversationInfo: true });
    try {
      const response = await KanbanTypeProcessAPI.getConversationKanbanInfo(conversationId);
      commit(types.SET_CONVERSATION_KANBAN_INFO, { 
        conversationId, 
        data: response.data 
      });
      commit(types.SET_KANBAN_TYPE_PROCESS_UI_FLAG, { isFetchingConversationInfo: false });
      return response.data;
    } catch (error) {
      commit(types.SET_KANBAN_TYPE_PROCESS_UI_FLAG, { isFetchingConversationInfo: false });
      throw error;
    }
  },
};

export const mutations = {
  // 🆕 NUEVA MUTATION
  [types.SET_CONVERSATION_KANBAN_INFO]($state, { conversationId, data }) {
    $state.conversationKanbanInfo = {
      ...$state.conversationKanbanInfo,
      [conversationId]: data,
    };
  },
  
  [types.SET_KANBAN_TYPE_PROCESS_UI_FLAG]($state, data) {
    $state.uiFlags = {
      ...$state.uiFlags,
      ...data,
    };
  },

  // ✅ LIMPIAR COMPLETAMENTE
  [types.CLEAR_KANBAN_TYPE_PROCESSES]($state) {
    console.log('🧹 Clearing kanban type processes');
    $state.records = {};
  },

  // ✅ SETEAR DATOS LIMPIOS
  [types.SET_KANBAN_TYPE_PROCESSES]($state, data) {
    console.log('📋 Setting kanban type processes:', data);
    $state.records = {};
    
    if (Array.isArray(data)) {
      data.forEach(item => {
        if (item && item.id) {
          $state.records[item.id] = { ...item };
        }
      });
    }
    
    console.log('📊 Final records state:', Object.keys($state.records).length, 'items');
  },

  [types.SET_KANBAN_TYPE_PROCESS_ITEM]($state, item) {
    if (item && item.id) {
      $state.records[item.id] = { ...item };
    }
  },

  [types.ADD_KANBAN_TYPE_PROCESS]($state, item) {
    if (item && item.id) {
      $state.records[item.id] = { ...item };
    }
  },

  [types.EDIT_KANBAN_TYPE_PROCESS]($state, item) {
    if (item && item.id && $state.records[item.id]) {
      $state.records[item.id] = { ...$state.records[item.id], ...item };
    }
  },

  [types.DELETE_KANBAN_TYPE_PROCESS]($state, id) {
    if ($state.records[id]) {
      delete $state.records[id];
    }
  },
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};