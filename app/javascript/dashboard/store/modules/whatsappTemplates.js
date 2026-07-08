// @waba_templates — Vuex: gestión de plantillas de WhatsApp por canal (inbox).
import templatesAPI from '../../api/whatsapp/templates';

const state = {
  records: [],
  uiFlags: {
    fetching: false,
    saving: false,
    syncing: false,
  },
};

export const getters = {
  getTemplates: _state => _state.records,
  getUIFlags: _state => _state.uiFlags,
};

export const actions = {
  async fetch({ commit }, inboxId) {
    commit('SET_UI_FLAG', { fetching: true });
    try {
      const { data } = await templatesAPI.get(inboxId);
      commit('SET_RECORDS', data);
    } finally {
      commit('SET_UI_FLAG', { fetching: false });
    }
  },

  async create({ commit }, { inboxId, template }) {
    commit('SET_UI_FLAG', { saving: true });
    try {
      const { data } = await templatesAPI.create(inboxId, template);
      commit('UPSERT_RECORD', data);
      return data;
    } finally {
      commit('SET_UI_FLAG', { saving: false });
    }
  },

  async update({ commit }, { id, template }) {
    commit('SET_UI_FLAG', { saving: true });
    try {
      const { data } = await templatesAPI.update(id, template);
      commit('UPSERT_RECORD', data);
      return data;
    } finally {
      commit('SET_UI_FLAG', { saving: false });
    }
  },

  async delete({ commit }, id) {
    await templatesAPI.delete(id);
    commit('REMOVE_RECORD', id);
  },

  async sync({ commit }, inboxId) {
    commit('SET_UI_FLAG', { syncing: true });
    try {
      const { data } = await templatesAPI.sync(inboxId);
      return data;
    } finally {
      commit('SET_UI_FLAG', { syncing: false });
    }
  },
};

export const mutations = {
  SET_UI_FLAG(_state, flags) {
    _state.uiFlags = { ..._state.uiFlags, ...flags };
  },
  SET_RECORDS(_state, records) {
    _state.records = records;
  },
  UPSERT_RECORD(_state, record) {
    const index = _state.records.findIndex(r => r.id === record.id);
    if (index === -1) _state.records.unshift(record);
    else _state.records.splice(index, 1, record);
  },
  REMOVE_RECORD(_state, id) {
    _state.records = _state.records.filter(r => r.id !== id);
  },
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};
