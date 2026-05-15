import * as types from '../mutation-types';
import KnowledgeBaseAPI from '../../api/knowledgeBase';

const state = {
  articles: [],
  internalLinks: [],
  loading: false,
  searchResult: null,
  error: null,
};

const getters = {
  getArticles: $state => $state.articles,
  getInternalLinks: $state => $state.internalLinks,
  isLoading: $state => $state.loading,
  getSearchResult: $state => $state.searchResult,
  getError: $state => $state.error,
};

const actions = {
  // ==========================================
  // WEBSITE SKETCH
  // ==========================================
  
  async fetchWebsiteSketch({ commit }, url) {
    commit(types.default.SET_KNOWLEDGE_BASE_UI_FLAG, { loading: true });
    commit(types.default.SET_KNOWLEDGE_BASE_ERROR, null);
    
    try {
      const response = await KnowledgeBaseAPI.fetchWebsiteSketch(url);
      return response.data;
    } catch (error) {
      const errorMessage = error.response?.data?.error || 'Error fetching website sketch';
      commit(types.default.SET_KNOWLEDGE_BASE_ERROR, errorMessage);
      throw error;
    } finally {
      commit(types.default.SET_KNOWLEDGE_BASE_UI_FLAG, { loading: false });
    }
  },
  // 👇 AGREGAR ESTA NUEVA ACTION AQUÍ
  async checkWebsiteSketchStatus({ commit }, { accountId, cacheKey }) {
    try {
      const response = await KnowledgeBaseAPI.checkWebsiteSketchStatus(accountId, cacheKey);
      return response.data;
    } catch (error) {
      const errorMessage = error.response?.data?.error || 'Error checking status';
      throw new Error(errorMessage);
    }
  },
// 👆 FIN DE LA NUEVA ACTION


  async importFromSketch({ commit }, sketchData) {
    commit(types.default.SET_KNOWLEDGE_BASE_UI_FLAG, { loading: true });
    commit(types.default.SET_KNOWLEDGE_BASE_ERROR, null);
    
    try {
      const response = await KnowledgeBaseAPI.importFromSketch(sketchData);
      return response.data;
    } catch (error) {
      const errorMessage = error.response?.data?.error || 'Error importing from sketch';
      commit(types.default.SET_KNOWLEDGE_BASE_ERROR, errorMessage);
      throw error;
    } finally {
      commit(types.default.SET_KNOWLEDGE_BASE_UI_FLAG, { loading: false });
    }
  },

  // ==========================================
  // INTERNAL LINKS
  // ==========================================

  async fetchArticlesWithInternalLinks({ commit }) {
    commit(types.default.SET_KNOWLEDGE_BASE_UI_FLAG, { loading: true });
    commit(types.default.SET_KNOWLEDGE_BASE_ERROR, null);
    
    try {
      const response = await KnowledgeBaseAPI.getArticlesWithInternalLinks();
      
      // El API Client ahora retorna { data: { articles: [...] } }
      const articles = response.data && response.data.articles ? response.data.articles : [];
      
      commit(types.default.SET_KNOWLEDGE_BASE_INTERNAL_LINKS, articles);
      
      return { articles };
    } catch (error) {
      const errorMessage = error.response?.data?.error || 'Error fetching articles';
      commit(types.default.SET_KNOWLEDGE_BASE_ERROR, errorMessage);
      throw error;
    } finally {
      commit(types.default.SET_KNOWLEDGE_BASE_UI_FLAG, { loading: false });
    }
  },

  async fetchInternalLinks({ commit }, articleId) {
    commit(types.default.SET_KNOWLEDGE_BASE_UI_FLAG, { loading: true });
    commit(types.default.SET_KNOWLEDGE_BASE_ERROR, null);
    
    try {
      const response = await KnowledgeBaseAPI.getInternalLinks(articleId);
      commit(types.default.SET_KNOWLEDGE_BASE_INTERNAL_LINKS, response.data.internal_links || []);
      return response.data;
    } catch (error) {
      const errorMessage = error.response?.data?.error || 'Error fetching internal links';
      commit(types.default.SET_KNOWLEDGE_BASE_ERROR, errorMessage);
      throw error;
    } finally {
      commit(types.default.SET_KNOWLEDGE_BASE_UI_FLAG, { loading: false });
    }
  },

  async trainInternalLinks({ commit }, { articleId, useOpenai }) {
    commit(types.default.SET_KNOWLEDGE_BASE_UI_FLAG, { loading: true });
    commit(types.default.SET_KNOWLEDGE_BASE_ERROR, null);
    
    try {
      const response = await KnowledgeBaseAPI.trainInternalLinks(articleId, useOpenai);
      return response.data;
    } catch (error) {
      const errorMessage = error.response?.data?.error || 'Error training internal links';
      commit(types.default.SET_KNOWLEDGE_BASE_ERROR, errorMessage);
      throw error;
    } finally {
      commit(types.default.SET_KNOWLEDGE_BASE_UI_FLAG, { loading: false });
    }
  },

  async trainSpecificInternalLink({ commit }, { articleId, internalLinkUrl, useOpenai }) {
    commit(types.default.SET_KNOWLEDGE_BASE_UI_FLAG, { loading: true });
    commit(types.default.SET_KNOWLEDGE_BASE_ERROR, null);
    
    try {
      const response = await KnowledgeBaseAPI.trainSpecificInternalLink(
        articleId,
        internalLinkUrl,
        useOpenai
      );
      return response.data;
    } catch (error) {
      const errorMessage = error.response?.data?.error || 'Error training specific link';
      commit(types.default.SET_KNOWLEDGE_BASE_ERROR, errorMessage);
      throw error;
    } finally {
      commit(types.default.SET_KNOWLEDGE_BASE_UI_FLAG, { loading: false });
    }
  },

  async deleteInternalLinkEmbeddings({ commit }, { articleId, internalLinkUrl }) {
    commit(types.default.SET_KNOWLEDGE_BASE_UI_FLAG, { loading: true });
    commit(types.default.SET_KNOWLEDGE_BASE_ERROR, null);
    
    try {
      const response = await KnowledgeBaseAPI.deleteInternalLinkEmbeddings(
        articleId,
        internalLinkUrl
      );
      return response.data;
    } catch (error) {
      const errorMessage = error.response?.data?.error || 'Error deleting embeddings';
      commit(types.default.SET_KNOWLEDGE_BASE_ERROR, errorMessage);
      throw error;
    } finally {
      commit(types.default.SET_KNOWLEDGE_BASE_UI_FLAG, { loading: false });
    }
  },

  async deleteInternalLinkChunk({ commit }, chunkId) {
    commit(types.default.SET_KNOWLEDGE_BASE_UI_FLAG, { loading: true });
    commit(types.default.SET_KNOWLEDGE_BASE_ERROR, null);
    
    try {
      const response = await KnowledgeBaseAPI.deleteInternalLinkChunk(chunkId);
      return response.data;
    } catch (error) {
      const errorMessage = error.response?.data?.error || 'Error deleting chunk';
      commit(types.default.SET_KNOWLEDGE_BASE_ERROR, errorMessage);
      throw error;
    } finally {
      commit(types.default.SET_KNOWLEDGE_BASE_UI_FLAG, { loading: false });
    }
  },

  // ==========================================
  // SEMANTIC SEARCH
  // ==========================================

  async semanticSearch({ commit }, { query, useOpenai, minSimilarity }) {
    commit(types.default.SET_KNOWLEDGE_BASE_UI_FLAG, { loading: true });
    commit(types.default.SET_KNOWLEDGE_BASE_ERROR, null);
    
    try {
      const response = await KnowledgeBaseAPI.semanticSearch(query, useOpenai, minSimilarity);
      commit(types.default.SET_KNOWLEDGE_BASE_SEARCH_RESULT, response.data);
      return response.data;
    } catch (error) {
      const errorMessage = error.response?.data?.error || 'Error performing search';
      commit(types.default.SET_KNOWLEDGE_BASE_ERROR, errorMessage);
      commit(types.default.SET_KNOWLEDGE_BASE_SEARCH_RESULT, null);
      throw error;
    } finally {
      commit(types.default.SET_KNOWLEDGE_BASE_UI_FLAG, { loading: false });
    }
  },

  clearSearchResult({ commit }) {
    commit(types.default.SET_KNOWLEDGE_BASE_SEARCH_RESULT, null);
  },

  clearError({ commit }) {
    commit(types.default.SET_KNOWLEDGE_BASE_ERROR, null);
  },
};

const mutations = {
  [types.default.SET_KNOWLEDGE_BASE_ARTICLES]($state, articles) {
    $state.articles = articles;
  },

  [types.default.SET_KNOWLEDGE_BASE_INTERNAL_LINKS]($state, internalLinks) {
    $state.internalLinks = internalLinks;
  },

  [types.default.SET_KNOWLEDGE_BASE_UI_FLAG]($state, { loading }) {
    $state.loading = loading;
  },

  [types.default.SET_KNOWLEDGE_BASE_SEARCH_RESULT]($state, result) {
    $state.searchResult = result;
  },

  [types.default.SET_KNOWLEDGE_BASE_ERROR]($state, error) {
    $state.error = error;
  },
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};