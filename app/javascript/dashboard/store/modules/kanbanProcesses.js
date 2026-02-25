// KANBAN0725
// app/javascript/dashboard/store/modules/kanbanProcesses.js
/* global axios */
import KanbanProcessAPI from '../../api/kanbanProcesses';

// ✅ DEFINIR TIPOS PRIMERO
export const types = {
  SET_KANBAN_PROCESS_UI_FLAG: 'SET_KANBAN_PROCESS_UI_FLAG',
  SET_KANBAN_PROCESSES: 'SET_KANBAN_PROCESSES',
  SET_KANBAN_PROCESS_ITEM: 'SET_KANBAN_PROCESS_ITEM',
  ADD_KANBAN_PROCESS: 'ADD_KANBAN_PROCESS',
  EDIT_KANBAN_PROCESS: 'EDIT_KANBAN_PROCESS',
  DELETE_KANBAN_PROCESS: 'DELETE_KANBAN_PROCESS',
  REORDER_KANBAN_PROCESSES: 'REORDER_KANBAN_PROCESSES',
};

const state = {
  records: {},
  uiFlags: {
    isFetching: false,
    isFetchingItem: false,
    isCreating: false,
    isUpdating: false,
    isDeleting: false,
    isReordering: false,
  },
};

export const getters = {
  getKanbanProcesses($state) {
    return Object.values($state.records).sort((a, b) => a.position - b.position);
  },
  getKanbanProcess: $state => id => {
    return $state.records[id];
  },
  getKanbanProcessesByType: $state => typeProcessId => {
    return Object.values($state.records)
      .filter(process => process.kanban_type_process_id === typeProcessId)
      .sort((a, b) => a.position - b.position);
  },
  getDefaultKanbanProcess: $state => typeProcessId => {
    return Object.values($state.records).find(
      process => process.kanban_type_process_id === typeProcessId && process.default
    );
  },
  getSystemKanbanProcesses($state) {
    return Object.values($state.records).filter(process => process.is_system);
  },
  getCustomKanbanProcesses($state) {
    return Object.values($state.records).filter(process => !process.is_system);
  },
  getUIFlags($state) {
    return $state.uiFlags;
  },
};

export const actions = {
  get: async function getKanbanProcesses({ commit }, { kanbanTypeProcessId }) {
    commit(types.SET_KANBAN_PROCESS_UI_FLAG, { isFetching: true });
    try {
      const response = await KanbanProcessAPI.get(kanbanTypeProcessId);
      commit(types.SET_KANBAN_PROCESSES, response.data);
      commit(types.SET_KANBAN_PROCESS_UI_FLAG, { isFetching: false });
    } catch (error) {
      commit(types.SET_KANBAN_PROCESS_UI_FLAG, { isFetching: false });
      throw error;
    }
  },

  show: async function showKanbanProcess({ commit }, { id }) {
    commit(types.SET_KANBAN_PROCESS_UI_FLAG, { isFetchingItem: true });
    try {
      const response = await KanbanProcessAPI.show(id);
      commit(types.SET_KANBAN_PROCESS_ITEM, response.data);
      commit(types.SET_KANBAN_PROCESS_UI_FLAG, { isFetchingItem: false });
    } catch (error) {
      commit(types.SET_KANBAN_PROCESS_UI_FLAG, { isFetchingItem: false });
      throw error;
    }
  },

  create: async function createKanbanProcess({ commit }, kanbanProcessObj) {
    commit(types.SET_KANBAN_PROCESS_UI_FLAG, { isCreating: true });
    try {
      const response = await KanbanProcessAPI.create(
        kanbanProcessObj.kanban_type_process_id,
        kanbanProcessObj
      );
      commit(types.ADD_KANBAN_PROCESS, response.data);
      commit(types.SET_KANBAN_PROCESS_UI_FLAG, { isCreating: false });
      return response.data;
    } catch (error) {
      commit(types.SET_KANBAN_PROCESS_UI_FLAG, { isCreating: false });
      throw error;
    }
  },

  // update: async function updateKanbanProcess({ commit }, { id, ...kanbanProcessObj }) {
  //   commit(types.SET_KANBAN_PROCESS_UI_FLAG, { isUpdating: true });
  //   try {
  //     const response = await KanbanProcessAPI.update(id, kanbanProcessObj);
  //     commit(types.EDIT_KANBAN_PROCESS, response.data);
  //     commit(types.SET_KANBAN_PROCESS_UI_FLAG, { isUpdating: false });
  //     return response.data;
  //   } catch (error) {
  //     commit(types.SET_KANBAN_PROCESS_UI_FLAG, { isUpdating: false });
  //     throw error;
  //   }
  // },
  // En app/javascript/dashboard/store/modules/kanbanProcesses.js

  update: async function updateKanbanProcess({ commit }, payload) {
    console.log('🔍 STORE UPDATE received payload:', payload);
    console.log('🔍 STORE UPDATE payload type:', typeof payload);
    console.log('🔍 STORE UPDATE payload keys:', Object.keys(payload || {}));

    // Opción 1: Si recibes { kanbanTypeProcessId, id, ...otherFields }
    const { kanbanTypeProcessId, id, ...kanbanProcessObj } = payload;

    console.log('🔍 STORE UPDATE after destructuring:');
    console.log('- kanbanTypeProcessId:', kanbanTypeProcessId, typeof kanbanTypeProcessId);
    console.log('- id:', id, typeof id);
    console.log('- kanbanProcessObj:', kanbanProcessObj);

    // Validar parámetros
    if (!kanbanTypeProcessId || !id) {
      const error = `STORE UPDATE: Missing required params - kanbanTypeProcessId: ${kanbanTypeProcessId}, id: ${id}`;
      console.error('❌', error);
      throw new Error(error);
    }

    commit(types.SET_KANBAN_PROCESS_UI_FLAG, { isUpdating: true });

    try {
      console.log('🚀 STORE UPDATE: Calling API with validated params');
      const response = await KanbanProcessAPI.update(kanbanTypeProcessId, id, kanbanProcessObj);

      console.log('✅ STORE UPDATE: API response:', response.data);
      commit(types.EDIT_KANBAN_PROCESS, response.data);
      commit(types.SET_KANBAN_PROCESS_UI_FLAG, { isUpdating: false });

      return response.data;
    } catch (error) {
      console.error('❌ STORE UPDATE: API call failed:', error);
      commit(types.SET_KANBAN_PROCESS_UI_FLAG, { isUpdating: false });
      throw error;
    }
  },

  // delete: async function deleteKanbanProcess({ commit }, id) {
  //   commit(types.SET_KANBAN_PROCESS_UI_FLAG, { isDeleting: true });
  //   try {
  //     await KanbanProcessAPI.delete(id);
  //     commit(types.DELETE_KANBAN_PROCESS, id);
  //     commit(types.SET_KANBAN_PROCESS_UI_FLAG, { isDeleting: false });
  //   } catch (error) {
  //     commit(types.SET_KANBAN_PROCESS_UI_FLAG, { isDeleting: false });
  //     throw error;
  //   }
  // },
  //   delete: async function deleteKanbanProcess({ commit }, { kanbanTypeProcessId, id }) {
  //   commit(types.SET_KANBAN_PROCESS_UI_FLAG, { isDeleting: true });
  //   try {
  //     await KanbanProcessAPI.delete(kanbanTypeProcessId, id);
  //     commit(types.DELETE_KANBAN_PROCESS, id);
  //     commit(types.SET_KANBAN_PROCESS_UI_FLAG, { isDeleting: false });
  //   } catch (error) {
  //     commit(types.SET_KANBAN_PROCESS_UI_FLAG, { isDeleting: false });
  //     throw error;
  //   }
  // },
  // En app/javascript/dashboard/store/modules/kanbanProcesses.js

  // En app/javascript/dashboard/store/modules/kanbanProcesses.js

  delete: async function deleteKanbanProcess({ commit }, id) {
    console.log('🔍 STORE DELETE (simple) called with id:', id);
    console.log('🔍 STORE DELETE - Type of id:', typeof id);

    if (!id) {
      console.error('❌ STORE DELETE - Missing id parameter!');
      throw new Error(`Missing id parameter: ${id}`);
    }

    commit(types.SET_KANBAN_PROCESS_UI_FLAG, { isDeleting: true });
    try {
      console.log('🚀 STORE DELETE - Calling API with id:', id);
      await KanbanProcessAPI.delete(id);
      commit(types.DELETE_KANBAN_PROCESS, id);
      commit(types.SET_KANBAN_PROCESS_UI_FLAG, { isDeleting: false });
      console.log('✅ STORE DELETE - Success');
    } catch (error) {
      console.error('❌ STORE DELETE - API call failed:', error);
      commit(types.SET_KANBAN_PROCESS_UI_FLAG, { isDeleting: false });
      throw error;
    }
  },

  reorder: async function reorderKanbanProcesses({ commit }, { kanbanTypeProcessId, kanbanProcesses }) {
    commit(types.SET_KANBAN_PROCESS_UI_FLAG, { isReordering: true });
    try {
      await KanbanProcessAPI.reorder(kanbanTypeProcessId, { kanban_processes: kanbanProcesses });
      commit(types.REORDER_KANBAN_PROCESSES, kanbanProcesses);
      commit(types.SET_KANBAN_PROCESS_UI_FLAG, { isReordering: false });
    } catch (error) {
      commit(types.SET_KANBAN_PROCESS_UI_FLAG, { isReordering: false });
      throw error;
    }
  },
};

export const mutations = {
  [types.SET_KANBAN_PROCESS_UI_FLAG]($state, data) {
    $state.uiFlags = {
      ...$state.uiFlags,
      ...data,
    };
  },

  [types.SET_KANBAN_PROCESSES]($state, data) {
    $state.records = {};
    data.forEach(item => {
      $state.records[item.id] = item;
    });
  },

  [types.SET_KANBAN_PROCESS_ITEM]($state, item) {
    $state.records[item.id] = item;
  },

  [types.ADD_KANBAN_PROCESS]($state, item) {
    $state.records[item.id] = item;
  },

  [types.EDIT_KANBAN_PROCESS]($state, item) {
    $state.records[item.id] = { ...$state.records[item.id], ...item };
  },

  [types.DELETE_KANBAN_PROCESS]($state, id) {
    delete $state.records[id];
  },

  [types.REORDER_KANBAN_PROCESSES]($state, reorderedProcesses) {
    reorderedProcesses.forEach((processData, index) => {
      if ($state.records[processData.id]) {
        $state.records[processData.id].position = index;
      }
    });
  },
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};