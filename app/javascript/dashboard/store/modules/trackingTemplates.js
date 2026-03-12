// ================================================================================
// proyecto@tracking_templates
// ================================================================================
// Store Vuex: trackingTemplates
// Descripción: Estado, getters, actions y mutations para plantillas de seguimiento
// ================================================================================

import * as MutationHelpers from 'shared/helpers/vuex/mutationHelpers';
import {
  SET_TRACKING_TEMPLATES,
  ADD_TRACKING_TEMPLATE,
  EDIT_TRACKING_TEMPLATE,
  DELETE_TRACKING_TEMPLATE,
  SET_TRACKING_TEMPLATE_UI_FLAG,
} from '../mutation-types';
import trackingTemplatesAPI from '../../api/trackingTemplates';

const state = {
  records: [],
  uiFlags: {
    fetchingList: false,
    creatingItem: false,
    updatingItem: false,
    deletingItem: false,
  },
};

export const getters = {
  getTemplates(_state) {
    return _state.records.sort((a, b) => b.id - a.id);
  },
  getTemplateById: _state => id => {
    return _state.records.find(t => t.id === Number(id));
  },
  getTemplatesByTag: _state => tag => {
    return _state.records.filter(
      t => Array.isArray(t.tags) && t.tags.includes(tag)
    );
  },
  getAllTags(_state) {
    const tagsSet = new Set();
    _state.records.forEach(t => {
      if (Array.isArray(t.tags)) {
        t.tags.forEach(tag => tagsSet.add(tag));
      }
    });
    return Array.from(tagsSet).sort();
  },
  getAllInboxIds(_state) {
    const ids = new Set();
    _state.records.forEach(t => {
      if (t.inbox_id) ids.add(t.inbox_id);
    });
    return Array.from(ids);
  },
  getUIFlags(_state) {
    return _state.uiFlags;
  },
};

export const actions = {
  async get({ commit }) {
    commit(SET_TRACKING_TEMPLATE_UI_FLAG, { fetchingList: true });
    try {
      const response = await trackingTemplatesAPI.get();
      commit(SET_TRACKING_TEMPLATES, response.data);
    } catch (error) {
      // handle silently
    } finally {
      commit(SET_TRACKING_TEMPLATE_UI_FLAG, { fetchingList: false });
    }
  },

  async create({ commit }, params) {
    commit(SET_TRACKING_TEMPLATE_UI_FLAG, { creatingItem: true });
    try {
      const response = await trackingTemplatesAPI.create(params);
      commit(ADD_TRACKING_TEMPLATE, response.data);
      return response.data;
    } catch (error) {
      throw error;
    } finally {
      commit(SET_TRACKING_TEMPLATE_UI_FLAG, { creatingItem: false });
    }
  },

  async update({ commit }, { id, ...updateObj }) {
    commit(SET_TRACKING_TEMPLATE_UI_FLAG, { updatingItem: true });
    try {
      const response = await trackingTemplatesAPI.update(id, updateObj);
      commit(EDIT_TRACKING_TEMPLATE, response.data);
      return response.data;
    } catch (error) {
      throw error;
    } finally {
      commit(SET_TRACKING_TEMPLATE_UI_FLAG, { updatingItem: false });
    }
  },

  async delete({ commit }, id) {
    commit(SET_TRACKING_TEMPLATE_UI_FLAG, { deletingItem: true });
    try {
      await trackingTemplatesAPI.delete(id);
      commit(DELETE_TRACKING_TEMPLATE, id);
    } catch (error) {
      throw error;
    } finally {
      commit(SET_TRACKING_TEMPLATE_UI_FLAG, { deletingItem: false });
    }
  },
};

export const mutations = {
  [SET_TRACKING_TEMPLATE_UI_FLAG](_state, data) {
    _state.uiFlags = {
      ..._state.uiFlags,
      ...data,
    };
  },
  [SET_TRACKING_TEMPLATES]: MutationHelpers.set,
  [ADD_TRACKING_TEMPLATE]: MutationHelpers.create,
  [EDIT_TRACKING_TEMPLATE]: MutationHelpers.update,
  [DELETE_TRACKING_TEMPLATE]: MutationHelpers.destroy,
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};
