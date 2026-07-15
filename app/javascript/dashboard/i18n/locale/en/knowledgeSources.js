// ================================================================================
// @knowledge_sources
// English translations for the Knowledge Base module.
// ================================================================================

export default {
  KNOWLEDGE_SOURCES: {
    TITLE: 'Knowledge Base',
    DESCRIPTION: 'Manage the information sources that power semantic search. Connect Discourse forums or use Canned Responses so the assistant finds relevant content in every conversation.',

    TABS: {
      INDEXED_CONTENT: 'Indexed content',
      SOURCES: 'Sources (%{count})',
      SEARCH_CONSOLE: 'Search Console (Sources)',
      ERP_CONNECTION: 'ERP Connection',
      COLLECTION_AGENT: 'Collection Agent',
      QUERY_CONSOLE: 'Query Console (ERP)',
    },

    ACTIONS: {
      ADD: 'Add Source',
    },

    EMPTY_STATE: 'No knowledge sources configured',

    API: {
      FETCH_ERROR: 'Error loading knowledge sources',
      CREATE_SUCCESS: 'Source created successfully',
      UPDATE_SUCCESS: 'Source updated successfully',
      DELETE_SUCCESS: 'Source deleted successfully',
      ERROR: 'An error occurred. Please try again',
    },
  },
};
