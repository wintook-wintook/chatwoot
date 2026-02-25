<!-- KANBAN0725
  app/javascript/dashboard/components/KanbanTypeProcessManager.vue -->
<template>
    <div class="kanban-type-process-manager">
      <div class="header-section">
        <h2 class="page-title">
          Kanban Type Processes
        </h2>
        <woot-button
          color-scheme="primary"
          icon="plus"
          @click="openCreateModal"
        >
          Add new type process
        </woot-button>
      </div>
  
      <div class="content-section">
        <woot-loading-state
          v-if="isKanbanLoading"
          message="Fetching kanban type processes"
        />
  
        <div v-else class="kanban-type-processes-container">
          <!-- System Processes -->
          <div v-if="systemKanbanTypeProcesses.length" class="process-group">
            <h3 class="group-title">
              System Processes
            </h3>
            <div class="process-grid">
              <kanban-type-process-card
                v-for="process in systemKanbanTypeProcesses"
                :key="process.id"
                :process="process"
                :is-system="true"
                @edit="openEditModal"
                @delete="handleDelete"
              />
            </div>
          </div>
  
          <!-- Custom Processes -->
          <div class="process-group">
            <h3 class="group-title">
              Custom Processes
            </h3>
            <div v-if="customKanbanTypeProcesses.length" class="process-grid">
              <kanban-type-process-card
                v-for="process in customKanbanTypeProcesses"
                :key="process.id"
                :process="process"
                :is-system="false"
                @edit="openEditModal"
                @delete="handleDelete"
              />
            </div>
            <div v-else class="empty-state">
              <p>There are no custom type processes configured for this account yet</p>
            </div>
          </div>
        </div>
      </div>
  
      <!-- Create/Edit Modal -->
      <woot-modal
        v-model="showModal"
        :on-close="closeModal"
      >
        <kanban-type-process-form
          :process="selectedProcess"
          :is-editing="isEditing"
          @save="handleSave"
          @cancel="closeModal"
        />
      </woot-modal>
  
      <!-- Delete Confirmation Modal -->
      <woot-confirm-delete-modal
        v-if="showDeleteModal"
        :show.sync="showDeleteModal"
        title="Confirm Deletion"
        :message="deleteConfirmMessage"
        confirm-text="Yes, Delete"
        reject-text="No, Keep it"
        @on-confirm="confirmDelete"
        @on-reject="cancelDelete"
      />
    </div>
  </template>
  
  <script>
  import kanbanMixin from '../mixins/kanbanMixin';
  import KanbanTypeProcessCard from './KanbanTypeProcessCard.vue';
  import KanbanTypeProcessForm from './KanbanTypeProcessForm.vue';
  
  export default {
    name: 'KanbanTypeProcessManager',
    components: {
      KanbanTypeProcessCard,
      KanbanTypeProcessForm,
    },
    mixins: [kanbanMixin],
    data() {
      return {
        showModal: false,
        showDeleteModal: false,
        selectedProcess: null,
        isEditing: false,
        processToDelete: null,
        isInitialized: false, // Flag para evitar múltiples cargas
      };
    },
    computed: {
      deleteConfirmMessage() {
        return `Are you sure you want to delete the kanban type process '${this.processToDelete?.name || ''}'? This action cannot be undone.`;
      },
    },
    methods: {
      openCreateModal() {
        this.selectedProcess = null;
        this.isEditing = false;
        this.showModal = true;
      },
  
      openEditModal(process) {
        this.selectedProcess = { ...process };
        this.isEditing = true;
        this.showModal = true;
      },
  
      closeModal() {
        this.showModal = false;
        this.selectedProcess = null;
        this.isEditing = false;
      },
  
      async handleSave(processData) {
        try {
          if (this.isEditing) {
            await this.updateKanbanTypeProcess({
              id: this.selectedProcess.id,
              ...processData,
            });
            this.showSuccessMessage('Kanban type process updated successfully');
          } else {
            await this.createKanbanTypeProcess(processData);
            this.showSuccessMessage('Kanban type process created successfully');
          }
          this.closeModal();
        } catch (error) {
          console.error('Error saving kanban type process:', error);
          this.showErrorMessage('Failed to save kanban type process');
        }
      },
  
      handleDelete(process) {
        this.processToDelete = process;
        this.showDeleteModal = true;
      },
  
      async confirmDelete() {
        try {
          await this.deleteKanbanTypeProcess(this.processToDelete.id);
          this.showSuccessMessage('Kanban type process deleted successfully');
          this.cancelDelete();
        } catch (error) {
          console.error('Error deleting kanban type process:', error);
          this.showErrorMessage('Could not delete kanban type process. Please try again later');
        }
      },
  
      cancelDelete() {
        this.showDeleteModal = false;
        this.processToDelete = null;
      },
  
      // Método para inicializar datos una sola vez
      async initializeData() {
        if (this.isInitialized) return;
        
        this.isInitialized = true;
        await this.loadKanbanTypeProcesses();
      },
    },
  
    // Cargar datos al montar el componente
    async mounted() {
      await this.initializeData();
    },
  };
  </script>
  
  <style lang="scss" scoped>
  .kanban-type-process-manager {
    padding: var(--space-normal);
  }
  
  .header-section {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: var(--space-large);
  }
  
  .page-title {
    margin: 0;
    font-size: var(--font-size-large);
    font-weight: var(--font-weight-bold);
  }
  
  .content-section {
    background: var(--white);
    border-radius: var(--border-radius-normal);
    padding: var(--space-normal);
    box-shadow: var(--shadow-small);
  }
  
  .process-group {
    margin-bottom: var(--space-large);
  
    &:last-child {
      margin-bottom: 0;
    }
  }
  
  .group-title {
    margin: 0 0 var(--space-normal) 0;
    font-size: var(--font-size-medium);
    font-weight: var(--font-weight-medium);
    color: var(--s-700);
  }
  
  .process-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(320px, 1fr));
    gap: var(--space-normal);
  }
  
  .empty-state {
    text-align: center;
    padding: var(--space-large);
    color: var(--s-500);
  }
  </style>