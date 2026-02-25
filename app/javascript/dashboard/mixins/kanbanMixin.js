// app/javascript/dashboard/mixins/kanbanMixin.js
import { mapGetters, mapActions } from 'vuex';

export default {
  computed: {
    ...mapGetters({
      kanbanTypeProcesses: 'kanbanTypeProcesses/getKanbanTypeProcesses',
      kanbanProcesses: 'kanbanProcesses/getKanbanProcesses',
      kanbanTypeProcessesUIFlags: 'kanbanTypeProcesses/getUIFlags',
      kanbanProcessesUIFlags: 'kanbanProcesses/getUIFlags',
      conversationKanbanStats: 'conversations/getKanbanStats',
    }),

    defaultKanbanTypeProcess() {
      return this.kanbanTypeProcesses.find(process => process.default);
    },

    systemKanbanTypeProcesses() {
      return this.kanbanTypeProcesses.filter(process => process.is_system);
    },

    customKanbanTypeProcesses() {
      return this.kanbanTypeProcesses.filter(process => !process.is_system);
    },

    isKanbanLoading() {
      return this.kanbanTypeProcessesUIFlags.isFetching || this.kanbanProcessesUIFlags.isFetching;
    },
  },

  methods: {
    ...mapActions({
      fetchKanbanTypeProcesses: 'kanbanTypeProcesses/get',
      fetchKanbanProcesses: 'kanbanProcesses/get',
      createKanbanTypeProcess: 'kanbanTypeProcesses/create',
      updateKanbanTypeProcess: 'kanbanTypeProcesses/update',
      deleteKanbanTypeProcess: 'kanbanTypeProcesses/delete',
      createKanbanProcess: 'kanbanProcesses/create',
      updateKanbanProcess: 'kanbanProcesses/update',
      deleteKanbanProcess: 'kanbanProcesses/delete',
      reorderKanbanProcesses: 'kanbanProcesses/reorder',
      updateConversationKanban: 'conversations/updateKanbanProcess',
      fetchConversationsByKanban: 'conversations/fetchConversationsByKanban',
    }),

    async loadKanbanTypeProcesses() {
      try {
        await this.fetchKanbanTypeProcesses();
      } catch (error) {
        console.error('Error loading kanban type processes:', error);
        this.showErrorMessage('Failed to load kanban type processes');
      }
    },

    async loadKanbanProcesses(kanbanTypeProcessId) {
      try {
        await this.fetchKanbanProcesses({ kanbanTypeProcessId });
      } catch (error) {
        console.error('Error loading kanban processes:', error);
        this.showErrorMessage('Failed to load kanban processes');
      }
    },

    getKanbanProcessesByType(typeProcessId) {
      return this.kanbanProcesses.filter(
        process => process.kanban_type_process_id === typeProcessId
      ).sort((a, b) => a.position - b.position);
    },

    getDefaultKanbanProcess(typeProcessId) {
      return this.kanbanProcesses.find(
        process => process.kanban_type_process_id === typeProcessId && process.default
      );
    },

    async handleKanbanProcessChange(conversationId, kanbanTypeProcessId, kanbanProcessId) {
      try {
        await this.updateConversationKanban({
          conversationId,
          kanbanTypeProcessId,
          kanbanProcessId,
        });
        this.showSuccessMessage('Conversation kanban status updated successfully');
      } catch (error) {
        console.error('Error updating conversation kanban status:', error);
        this.showErrorMessage('Failed to update conversation kanban status');
      }
    },

    async handleKanbanReorder(kanbanTypeProcessId, reorderedProcesses) {
      try {
        await this.reorderKanbanProcesses({
          kanbanTypeProcessId,
          kanbanProcesses: reorderedProcesses.map((process, index) => ({
            id: process.id,
            position: index,
          })),
        });
        this.showSuccessMessage('Kanban processes reordered successfully');
      } catch (error) {
        console.error('Error reordering kanban processes:', error);
        this.showErrorMessage('Failed to reorder kanban processes');
      }
    },

    getKanbanProcessCount(processId) {
      return this.conversationKanbanStats[processId] || 0;
    },

    // Utility methods
    showSuccessMessage(message) {
      this.$toast.success(message);
    },

    showErrorMessage(message) {
      this.$toast.error(message);
    },
  },

  async created() {
    // Auto-load kanban type processes when component is created
    await this.loadKanbanTypeProcesses();
  },
};
