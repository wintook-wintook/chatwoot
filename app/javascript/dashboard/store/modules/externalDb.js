// @query_databases — Vuex: conexiones a ERPs, consultas predefinidas y consola.
import connectionsAPI from '../../api/externalDbConnections';
import queriesAPI from '../../api/externalDbQueries';
import consoleAPI from '../../api/externalDbConsole';
import botsAPI from '../../api/erpCollectionBots';

const state = {
  connections: [],
  catalog: [], // consola del agente: conexiones + consultas activas (sin credenciales)
  queriesByConnection: {}, // { [connectionId]: [queries] }
  bots: [],
  uiFlags: {
    fetchingConnections: false,
    savingConnection: false,
    testingConnection: false,
    fetchingQueries: false,
    savingQuery: false,
    runningQuery: false,
    fetchingBots: false,
    savingBot: false,
  },
};

export const getters = {
  getConnections: _state => _state.connections,
  getCatalog: _state => _state.catalog,
  getConnection: _state => id =>
    _state.connections.find(c => c.id === Number(id)),
  getQueries: _state => connectionId =>
    _state.queriesByConnection[connectionId] || [],
  getBots: _state => _state.bots,
  getUIFlags: _state => _state.uiFlags,
};

export const actions = {
  async fetchConnections({ commit }) {
    commit('SET_UI_FLAG', { fetchingConnections: true });
    try {
      const { data } = await connectionsAPI.get();
      commit('SET_CONNECTIONS', data);
    } finally {
      commit('SET_UI_FLAG', { fetchingConnections: false });
    }
  },

  async createConnection({ commit }, payload) {
    commit('SET_UI_FLAG', { savingConnection: true });
    try {
      const { data } = await connectionsAPI.create({
        external_db_connection: payload,
      });
      commit('UPSERT_CONNECTION', data);
      return data;
    } finally {
      commit('SET_UI_FLAG', { savingConnection: false });
    }
  },

  async updateConnection({ commit }, { id, ...payload }) {
    commit('SET_UI_FLAG', { savingConnection: true });
    try {
      const { data } = await connectionsAPI.update(id, {
        external_db_connection: payload,
      });
      commit('UPSERT_CONNECTION', data);
      return data;
    } finally {
      commit('SET_UI_FLAG', { savingConnection: false });
    }
  },

  async deleteConnection({ commit }, id) {
    await connectionsAPI.delete(id);
    commit('REMOVE_CONNECTION', id);
  },

  async testConnection({ commit }, id) {
    commit('SET_UI_FLAG', { testingConnection: true });
    try {
      const { data } = await connectionsAPI.testConnection(id);
      return data;
    } finally {
      commit('SET_UI_FLAG', { testingConnection: false });
    }
  },

  async fetchQueries({ commit }, connectionId) {
    commit('SET_UI_FLAG', { fetchingQueries: true });
    try {
      const { data } = await queriesAPI.getByConnection(connectionId);
      commit('SET_QUERIES', { connectionId, queries: data });
    } finally {
      commit('SET_UI_FLAG', { fetchingQueries: false });
    }
  },

  async createQuery({ commit }, { connectionId, query }) {
    commit('SET_UI_FLAG', { savingQuery: true });
    try {
      const { data } = await queriesAPI.createQuery(connectionId, query);
      commit('UPSERT_QUERY', { connectionId, query: data });
      return data;
    } finally {
      commit('SET_UI_FLAG', { savingQuery: false });
    }
  },

  async updateQuery({ commit }, { connectionId, id, query }) {
    commit('SET_UI_FLAG', { savingQuery: true });
    try {
      const { data } = await queriesAPI.updateQuery(connectionId, id, query);
      commit('UPSERT_QUERY', { connectionId, query: data });
      return data;
    } finally {
      commit('SET_UI_FLAG', { savingQuery: false });
    }
  },

  async deleteQuery({ commit }, { connectionId, id }) {
    await queriesAPI.deleteQuery(connectionId, id);
    commit('REMOVE_QUERY', { connectionId, id });
  },

  async fetchCatalog({ commit }) {
    commit('SET_UI_FLAG', { fetchingConnections: true });
    try {
      const { data } = await consoleAPI.getCatalog();
      commit('SET_CATALOG', data);
      return data;
    } finally {
      commit('SET_UI_FLAG', { fetchingConnections: false });
    }
  },

  async runQuery({ commit }, { queryId, params }) {
    commit('SET_UI_FLAG', { runningQuery: true });
    try {
      const { data } = await consoleAPI.run({ queryId, params });
      return data;
    } finally {
      commit('SET_UI_FLAG', { runningQuery: false });
    }
  },

  async askQuestion({ commit }, { connectionId, question }) {
    commit('SET_UI_FLAG', { runningQuery: true });
    try {
      const { data } = await consoleAPI.ask({ connectionId, question });
      return data;
    } finally {
      commit('SET_UI_FLAG', { runningQuery: false });
    }
  },

  async fetchBots({ commit }) {
    commit('SET_UI_FLAG', { fetchingBots: true });
    try {
      const { data } = await botsAPI.get();
      commit('SET_BOTS', data);
    } finally {
      commit('SET_UI_FLAG', { fetchingBots: false });
    }
  },

  async createBot({ commit }, payload) {
    commit('SET_UI_FLAG', { savingBot: true });
    try {
      const { data } = await botsAPI.create({ erp_collection_bot: payload });
      commit('UPSERT_BOT', data);
      return data;
    } finally {
      commit('SET_UI_FLAG', { savingBot: false });
    }
  },

  async updateBot({ commit }, { id, ...payload }) {
    commit('SET_UI_FLAG', { savingBot: true });
    try {
      const { data } = await botsAPI.update(id, {
        erp_collection_bot: payload,
      });
      commit('UPSERT_BOT', data);
      return data;
    } finally {
      commit('SET_UI_FLAG', { savingBot: false });
    }
  },

  async deleteBot({ commit }, id) {
    await botsAPI.delete(id);
    commit('REMOVE_BOT', id);
  },

  async previewBot(_ctx, id) {
    const { data } = await botsAPI.preview(id);
    return data;
  },
};

export const mutations = {
  SET_UI_FLAG(_state, flags) {
    _state.uiFlags = { ..._state.uiFlags, ...flags };
  },
  SET_CONNECTIONS(_state, connections) {
    _state.connections = connections;
  },
  SET_CATALOG(_state, catalog) {
    _state.catalog = catalog;
  },
  UPSERT_CONNECTION(_state, conn) {
    const idx = _state.connections.findIndex(c => c.id === conn.id);
    if (idx === -1) _state.connections.push(conn);
    else _state.connections.splice(idx, 1, conn);
  },
  REMOVE_CONNECTION(_state, id) {
    _state.connections = _state.connections.filter(c => c.id !== Number(id));
  },
  SET_QUERIES(_state, { connectionId, queries }) {
    _state.queriesByConnection = {
      ..._state.queriesByConnection,
      [connectionId]: queries,
    };
  },
  UPSERT_QUERY(_state, { connectionId, query }) {
    const list = (_state.queriesByConnection[connectionId] || []).slice();
    const idx = list.findIndex(q => q.id === query.id);
    if (idx === -1) list.push(query);
    else list.splice(idx, 1, query);
    _state.queriesByConnection = {
      ..._state.queriesByConnection,
      [connectionId]: list,
    };
  },
  REMOVE_QUERY(_state, { connectionId, id }) {
    _state.queriesByConnection = {
      ..._state.queriesByConnection,
      [connectionId]: (_state.queriesByConnection[connectionId] || []).filter(
        q => q.id !== Number(id)
      ),
    };
  },
  SET_BOTS(_state, bots) {
    _state.bots = bots;
  },
  UPSERT_BOT(_state, bot) {
    const idx = _state.bots.findIndex(b => b.id === bot.id);
    if (idx === -1) _state.bots.push(bot);
    else _state.bots.splice(idx, 1, bot);
  },
  REMOVE_BOT(_state, id) {
    _state.bots = _state.bots.filter(b => b.id !== Number(id));
  },
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};
