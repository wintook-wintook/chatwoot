<template>
  <div class="kanban-container">
    <div class="kanban-content">
      <KanbanTypeProcessesSimple />
      <KanbanProcessesSimple />
    </div>
  </div>
</template>

<script>
import { mapGetters } from 'vuex';
import kanbanMixin from 'dashboard/mixins/kanbanMixin';
import AddKanbanType from './AddKanbanType.vue';
import KanbanProcessesSimple from 'dashboard/components/settings/KanbanProcesses/Index.vue';
import KanbanTypeProcessesSimple from 'dashboard/components/settings/KanbanTypeProcesses/Index.vue';

export default {
  name: 'KanbanTypeSettings',
  components: {
    AddKanbanType,
    KanbanTypeProcessesSimple,
    KanbanProcessesSimple,
  },
  mixins: [kanbanMixin],

  data() {
    return {
      showAddKanbanTypeModal: false,
      selectedKanbanType: null,
    };
  },

  computed: {
    ...mapGetters({
      currentAccountId: 'getCurrentAccountId',
    }),

    // NUEVO: Ordenar tipos de proceso
    sortedKanbanTypes() {
      return [...this.kanbanTypeProcesses].sort((a, b) => {
        // Primero los por defecto, luego por nombre
        if (a.default && !b.default) return -1;
        if (!a.default && b.default) return 1;
        if (a.is_system && !b.is_system) return -1;
        if (!a.is_system && b.is_system) return 1;
        return a.process_name.localeCompare(b.process_name);
      });
    },
  },

  async mounted() {
    await this.loadKanbanTypeProcesses();
  },

  methods: {
    // MEJORADO: Método para abrir modal de creación
    openAddKanbanTypeModal() {
      console.log('🔄 Index: Abriendo modal para crear');
      this.selectedKanbanType = null;
      this.showAddKanbanTypeModal = true;
    },

    // MEJORADO: Método para abrir modal de edición
    openEditKanbanTypeModal(kanbanType) {
      console.log('🔄 Index: Abriendo modal para editar:', kanbanType.process_name);
      this.selectedKanbanType = { ...kanbanType };
      this.showAddKanbanTypeModal = true;
    },

    // SIMPLIFICADO: Método para cerrar modal
    forceCloseModal() {
      console.log('🔄 Index: Forzando cierre del modal');
      this.showAddKanbanTypeModal = false;
      this.selectedKanbanType = null;
    },

    // NUEVO: Manejar guardado exitoso
    handleKanbanTypeSaved() {
      console.log('🔄 Index: Tipo guardado, cerrando y refrescando');
      this.forceCloseModal();
      this.refreshList();
    },

    // SIMPLIFICADO: Callback cuando se guarda (legacy)
    onKanbanTypeSaved() {
      console.log('🔄 Index: onKanbanTypeSaved (legacy)');
      this.handleKanbanTypeSaved();
    },

    // SIMPLIFICADO: Método para eliminar
    async confirmDeleteKanbanType(kanbanType) {
      const confirmed = confirm(
        `¿Estás seguro de que quieres eliminar "${kanbanType.process_name}"?`
      );

      if (confirmed) {
        try {
          console.log('🗑️ Index: Eliminando:', kanbanType.process_name);

          await this.deleteKanbanTypeProcess(kanbanType.id);

          this.showSuccessMessage('Tipo de proceso eliminado exitosamente');

          // Refrescar lista inmediatamente
          this.refreshList();

        } catch (error) {
          console.error('❌ Index: Error eliminando:', error);
          this.showErrorMessage('Error al eliminar el tipo de proceso');
        }
      }
    },

    // NUEVO: Método simple para refrescar
    async refreshList() {
      try {
        console.log('🔄 Index: Refrescando lista...');

        // Usar dispatch directo para garantizar actualización
        await this.$store.dispatch('kanbanTypeProcesses/get');

        console.log('✅ Index: Lista refrescada');
      } catch (error) {
        console.error('❌ Index: Error refrescando lista:', error);
      }
    },

    // MANTENER: Método para formatear fechas
    formatDate(dateString) {
      if (!dateString) return '';
      try {
        return new Date(dateString).toLocaleDateString();
      } catch (error) {
        return dateString;
      }
    },
  },
};
</script>

<style scoped>
/* Contenedor principal con scroll */
.kanban-container {
  height: 100vh; /* Altura completa de la ventana */
  width: 100vw; /* Ancho completo de la ventana */
  overflow: hidden; /* Ocultar overflow del contenedor principal */
}

.kanban-content {
  height: 100%;
  width: 100%;
  overflow-y: auto; /* Scroll vertical */
  padding: 1rem; /* Espaciado interno opcional */
  box-sizing: border-box; /* Incluir padding en el ancho total */
}

/* Estilos adicionales si es necesario */
.spinner {
  @apply inline-block w-4 h-4 border-2 border-current border-t-transparent rounded-full animate-spin;
}

/* Personalización opcional del scrollbar */
.kanban-content::-webkit-scrollbar {
  width: 8px;
}

.kanban-content::-webkit-scrollbar-track {
  background: #f1f1f1;
  border-radius: 4px;
}

.kanban-content::-webkit-scrollbar-thumb {
  background: #c1c1c1;
  border-radius: 4px;
}

.kanban-content::-webkit-scrollbar-thumb:hover {
  background: #a8a8a8;
}
</style>