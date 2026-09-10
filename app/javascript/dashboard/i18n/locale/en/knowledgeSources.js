// ================================================================================
// @knowledge_sources
// English translations for the Knowledge Base module.
// ================================================================================

export default {
  KNOWLEDGE_SOURCES: {
    TITLE: 'Knowledge Base',
    DESCRIPTION:
      'Manage the information sources that power semantic search. Connect Discourse forums or use Canned Responses so the assistant finds relevant content in every conversation.',

    TABS: {
      INDEXED_CONTENT: 'Indexed content',
      SOURCES: 'Sources (%{count})',
      SEARCH_CONSOLE: 'Search Console (Sources)',
      CONFIG: 'Settings',
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

    // @knowledge_sources — WordPress source
    WORDPRESS: {
      SITE_URL: 'Site URL',
      SITE_URL_PLACEHOLDER: 'https://misitio.com',
      TEST_CONNECTION: 'Test connection',
      CONNECT_HINT:
        'Connecting only reads the titles. What goes into the index is chosen in the next step.',
      PROBE_OK:
        'It responds. %{posts} posts · %{pages} pages · %{products} products · %{categories} categories.',
      ERROR_FORBIDDEN:
        'The site blocked access to its API (403). Usually a security plugin: allow read access to /wp-json/ and try again.',
      ERROR_UNREACHABLE:
        'Could not reach the site. Check the address is right and the site is online.',
      ERROR_NOT_WORDPRESS:
        'The address responds but does not return the WordPress API. It may be a maintenance page or a firewall.',
      ERROR_INVALID_URL: 'That address is not valid.',
      ERROR_GENERIC: 'Could not read the site. Please try again.',

      PICKER_TITLE: 'Choose what the agent knows',
      PICKER_HINT:
        'Pick the categories that go in whole; below you can make exceptions one by one. Anything published later in a chosen category goes in on its own.',
      TYPES: 'What kind of content?',
      TYPE_POSTS: 'Posts',
      TYPE_PAGES: 'Pages',
      TYPE_PRODUCTS: 'Products',
      NO_TYPES: 'This site has no readable content.',
      CATEGORIES: 'Categories',
      CATEGORIES_HINT:
        'With none chosen, everything goes in. Choosing one brings in all of its content, including anything published later.',
      SEARCH: 'Search by title…',
      ONLY_SELECTED: 'only the chosen ones',
      NO_RESULTS: 'No content matches.',
      CATALOG_ERROR: 'Could not read the site listing.',
      ESTIMATE:
        '%{selected} of %{total} chosen · ≈ %{chunks} chunks · about %{seconds}s',
      INDEX_SELECTED: 'Index what is chosen',
      CANCEL: 'Cancel',
      PICK_CONTENT: 'Choose content',
    },
  },
};
