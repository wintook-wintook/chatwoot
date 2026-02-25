
// app/javascript/dashboard/mixins/kanbanFilterMixin.js
import { mapGetters, mapActions } from 'vuex';

export default {
  data() {
    return {
      kanbanFilter: {
        kanban_type_process_id: null,
        kanban_process_id: null,
      },
      isKanbanFilterActive: false,
    };
  },

  computed: {
    ...mapGetters({
      conversations: 'conversations/getAllConversations',
      conversationKanbanFilter: 'conversations/getConversationKanbanFilter',
    }),

    filteredConversations() {
      if (!this.isKanbanFilterActive) {
        return this.conversations;
      }

      return this.conversations.filter(conversation => {
        if (this.kanbanFilter.kanban_type_process_id && 
            conversation.kanban_type_process_id !== this.kanbanFilter.kanban_type_process_id) {
          return false;
        }

        if (this.kanbanFilter.kanban_process_id && 
            conversation.kanban_process_id !== this.kanbanFilter.kanban_process_id) {
          return false;
        }

        return true;
      });
    },

    hasActiveKanbanFilter() {
      return this.kanbanFilter.kanban_type_process_id || this.kanbanFilter.kanban_process_id;
    },
  },

  methods: {
    ...mapActions({
      setConversationKanbanFilter: 'conversations/setConversationKanbanFilter',
      clearConversationKanbanFilter: 'conversations/clearConversationKanbanFilter',
      fetchConversationsByKanban: 'conversations/fetchConversationsByKanban',
    }),

    applyKanbanFilter(filter) {
      this.kanbanFilter = { ...filter };
      this.isKanbanFilterActive = true;
      this.setConversationKanbanFilter(filter);
      
      // Fetch conversations with the new filter
      this.fetchConversationsByKanban(filter);
    },

    clearKanbanFilter() {
      this.kanbanFilter = {
        kanban_type_process_id: null,
        kanban_process_id: null,
      };
      this.isKanbanFilterActive = false;
      this.clearConversationKanbanFilter();
    },

    updateKanbanTypeFilter(kanbanTypeProcessId) {
      this.applyKanbanFilter({
        ...this.kanbanFilter,
        kanban_type_process_id: kanbanTypeProcessId,
        kanban_process_id: null, // Reset process filter when type changes
      });
    },

    updateKanbanProcessFilter(kanbanProcessId) {
      this.applyKanbanFilter({
        ...this.kanbanFilter,
        kanban_process_id: kanbanProcessId,
      });
    },
  },

  watch: {
    // Watch for changes in route query parameters
    '$route.query': {
      handler(newQuery) {
        if (newQuery.kanban_type_process_id || newQuery.kanban_process_id) {
          this.applyKanbanFilter({
            kanban_type_process_id: newQuery.kanban_type_process_id || null,
            kanban_process_id: newQuery.kanban_process_id || null,
          });
        } else if (this.hasActiveKanbanFilter) {
          this.clearKanbanFilter();
        }
      },
      immediate: true,
    },
  },
};