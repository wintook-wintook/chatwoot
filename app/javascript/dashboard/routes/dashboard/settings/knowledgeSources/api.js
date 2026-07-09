// ================================================================================
// @knowledge_sources
// API service para el módulo Base de Conocimiento.
// Usa el axios global (con auth token) igual que el resto del proyecto.
// Comunica con /api/v1/accounts/:accountId/knowledge_base/*
// ================================================================================

/* global axios */

const base = accountId => `/api/v1/accounts/${accountId}/knowledge_base`;

export default {
  getItems(accountId, params = {}) {
    return axios.get(`${base(accountId)}/items`, { params });
  },

  getItemCategories(accountId, knowledge_source_id) {
    return axios.get(`${base(accountId)}/item_categories`, { params: { knowledge_source_id } });
  },

  getSources(accountId) {
    return axios.get(`${base(accountId)}/sources`);
  },

  createSource(accountId, payload) {
    return axios.post(`${base(accountId)}/sources`, {
      knowledge_source: payload,
    });
  },

  updateSource(accountId, id, payload) {
    return axios.patch(`${base(accountId)}/sources/${id}`, {
      knowledge_source: payload,
    });
  },

  deleteSource(accountId, id) {
    return axios.delete(`${base(accountId)}/sources/${id}`);
  },

  syncSource(accountId, id) {
    return axios.post(`${base(accountId)}/sources/${id}/sync`);
  },

  search(accountId, query, { limit = 5, threshold = 0.7 } = {}) {
    return axios.post(`${base(accountId)}/search`, { query, limit, threshold });
  },

  getSearchSettings(accountId) {
    return axios.get(`${base(accountId)}/search_settings`);
  },

  updateSearchSettings(accountId, payload) {
    return axios.patch(`${base(accountId)}/search_settings`, payload);
  },
};
