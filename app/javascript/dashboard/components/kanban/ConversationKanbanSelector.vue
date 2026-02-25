<template>
  <div class="kanban-conversation-filter">
    <div class="filter-controls">
      <h2 class="page-sub-title">
        {{ $t('KANBAN_FILTER.TITLE') }}
      </h2>
      
      <div class="filter-form">
        <div class="multiselect-wrap">
          <label class="input-label">
            {{ $t('KANBAN_FILTER.KANBAN_TYPE_PROCESS') }}
          </label>
          <select
            v-model="filters.kanban_type_process_id"
            class="form-control"
            @change="onKanbanTypeChange"
          >
            <option value="">{{ $t('KANBAN_FILTER.ALL') }}</option>
            <option
              v-for="kanbanType in kanbanTypes"
              :key="kanbanType.id"
              :value="kanbanType.id"
            >
              {{ kanbanType.name }}
              <span v-if="kanbanType.default"> ({{ $t('KANBAN_FILTER.DEFAULT') }})</span>
            </option>
          </select>
        </div>

        <div class="multiselect-wrap">
          <label class="input-label">
            {{ $t('KANBAN_FILTER.KANBAN_PROCESS') }}
          </label>
          <select
            v-model="filters.kanban_process_id"
            class="form-control"
            @change="onFilterChange"
            :disabled="!filters.kanban_type_process_id"
          >
            <option value="">{{ $t('KANBAN_FILTER.ALL') }}</option>
            <option
              v-for="kanbanProcess in availableKanbanProcesses"
              :key="kanbanProcess.id"
              :value="kanbanProcess.id"
            >
              {{ kanbanProcess.name }}
              <span v-if="kanbanProcess.default"> ({{ $t('KANBAN_FILTER.DEFAULT') }})</span>
            </option>
          </select>
        </div>

        <div class="multiselect-wrap">
          <label class="input-label">
            {{ $t('KANBAN_FILTER.STATUS') }}
          </label>
          <select
            v-model="filters.status"
            class="form-control"
            @change="onFilterChange"
          >
            <option value="">{{ $t('KANBAN_FILTER.ALL') }}</option>
            <option value="open">{{ $t('CHAT_LIST.CHAT_STATUS_FILTER_ITEMS.open') }}</option>
            <option value="resolved">{{ $t('CHAT_LIST.CHAT_STATUS_FILTER_ITEMS.resolved') }}</option>
            <option value="pending">{{ $t('CHAT_LIST.CHAT_STATUS_FILTER_ITEMS.pending') }}</option>
            <option value="snoozed">{{ $t('CHAT_LIST.CHAT_STATUS_FILTER_ITEMS.snoozed') }}</option>
          </select>
        </div>

        <div class="multiselect-wrap">
          <label class="input-label">
            {{ $t('KANBAN_FILTER.ASSIGNEE') }}
          </label>
          <select
            v-model="filters.assignee_id"
            class="form-control"
            @change="onFilterChange"
          >
            <option value="">{{ $t('KANBAN_FILTER.ALL') }}</option>
            <option
              v-for="agent in agents"
              :key="agent.id"
              :value="agent.id"
            >
              {{ agent.name }}
            </option>
          </select>
        </div>

        <div class="button-wrap">
          <woot-button
            color-scheme="primary"
            variant="smooth"
            size="small"
            :is-loading="isFilteringConversations"
            @click="applyFilters"
          >
            {{ $t('KANBAN_FILTER.APPLY_FILTER') }}
          </woot-button>
          
          <woot-button
            color-scheme="secondary"
            variant="smooth"
            size="small"
            @click="clearAllFilters"
          >
            {{ $t('KANBAN_FILTER.CLEAR_FILTERS') }}
          </woot-button>
        </div>
      </div>
    </div>

    <div class="conversations-list">
      <div v-if="isFilteringConversations" class="conversations--loader">
        <spinner />
      </div>
      
      <div v-else-if="conversations.length === 0" class="empty-state">
        <div class="empty-state--content">
          <fluent-icon
            icon="chat-multiple"
            size="64"
            class="empty-state--icon"
          />
          <h3 class="empty-state--title">
            {{ $t('KANBAN_FILTER.EMPTY_STATE.TITLE') }}
          </h3>
          <p class="empty-state--subtitle">
            {{ $t('KANBAN_FILTER.EMPTY_STATE.SUBTITLE') }}
          </p>
        </div>
      </div>

      <div v-else class="conversation-list-wrap">
        <div class="conversation-metadata">
          <span class="conversation-count">
            {{ $t('KANBAN_FILTER.RESULT_COUNT', { count: meta.count }) }}
          </span>
        </div>
        
        <conversation-card
          v-for="chat in conversations"
          :key="chat.id"
          :active-label="label"
          :team-id="teamId"
          :folders="folders"
          :chat="chat"
          :conversation-type="conversationType"
          :show-assignee="showAssigneeInConversationCard"
          :use-inbox-avatar-for-bot="useInboxAvatarForBot"
        />
      </div>
    </div>
  </div>
</template>

<script>
import { mapGetters } from 'vuex';
import ConversationCard from 'dashboard/components/widgets/conversation/ConversationCard';
import Spinner from 'shared/components/Spinner';
import kanbanMixin from 'dashboard/mixins/kanbanMixin';

export default {
  name: 'KanbanConversationFilter',
  components: {
    ConversationCard,
    Spinner,
  },
  mixins: [kanbanMixin],
  
  data() {
    return {
      filters: {
        kanban_type_process_id: '',
        kanban_process_id: '',
        status: '',
        assignee_id: '',
      },
    };
  },

  computed: {
    ...mapGetters({
      conversations: 'kanbanConversations/getKanbanConversations',
      meta: 'kanbanConversations/getMeta',
      currentFilters: 'kanbanConversations/getCurrentFilters',
      uiFlags: 'kanbanConversations/getUIFlags',
      agents: 'agents/getAgents',
    }),

    // Mapear los kanban types desde el store
    kanbanTypes() {
      console.log('🔄 Computando kanbanTypes desde store...');
      
      const storeData = this.$store.state.kanbanTypeProcesses;
      console.log(storeData);      
      if (!storeData || !storeData.records) {
        console.log('❌ No hay datos en el store');
        return [];
      }

      const types = Object.values(storeData.records).map(record => ({
        id: record.id,
        name: record.process_name,
        default: record.default,
        is_system: record.is_system,
        account_id: record.account_id,
        created_at: record.created_at,
        updated_at: record.updated_at,
        kanban_processes: record.kanban_processes || []
      }));

      console.log('✅ Kanban types mapeados:', types);
      return types;
    },

    // Mapear todos los kanban processes desde el store
    allKanbanProcesses() {
      console.log('🔄 Computando allKanbanProcesses desde store...');
      
      const processes = [];
      
      this.kanbanTypes.forEach(type => {
        if (type.kanban_processes && type.kanban_processes.length > 0) {
          type.kanban_processes.forEach(process => {
            processes.push({
              id: process.id,
              name: process.type_process_name,
              default: process.default,
              is_system: process.is_system,
              position: process.position,
              kanban_type_process_id: type.id,
              type_name: type.name
            });
          });
        }
      });

      console.log('✅ Todos los procesos mapeados:', processes);
      return processes;
    },

    // Procesos disponibles según el tipo seleccionado
    availableKanbanProcesses() {
      if (!this.filters.kanban_type_process_id) {
        return this.allKanbanProcesses;
      }

      const filtered = this.allKanbanProcesses.filter(
        process => process.kanban_type_process_id === parseInt(this.filters.kanban_type_process_id)
      );

      console.log('🔄 Procesos filtrados para tipo', this.filters.kanban_type_process_id, ':', filtered);
      return filtered;
    },

    isFilteringConversations() {
      return this.uiFlags.isFetchingFilteredConversations;
    },

    // Props para ConversationCard
    label() {
      return this.$route.params.label || '';
    },
    
    teamId() {
      return this.$route.params.teamId || null;
    },
    
    folders() {
      return [];
    },
    
    conversationType() {
      return 'kanban';
    },
    
    showAssigneeInConversationCard() {
      return true;
    },
    
    useInboxAvatarForBot() {
      return false;
    },
  },

  watch: {
    // Observar cambios en los datos del store
    kanbanTypes: {
      handler(newTypes) {
        console.log('🔄 kanbanTypes cambió:', newTypes);
        
        // Si hay un tipo por defecto y no hay filtro seleccionado, seleccionarlo
        if (newTypes.length > 0 && !this.filters.kanban_type_process_id) {
          const defaultType = newTypes.find(type => type.default);
          if (defaultType) {
            console.log('🎯 Seleccionando tipo por defecto:', defaultType.name);
            this.filters.kanban_type_process_id = defaultType.id;
          }
        }
      },
      immediate: true
    },

    // Limpiar proceso seleccionado cuando cambia el tipo
    'filters.kanban_type_process_id'() {
      console.log('🔄 Tipo de proceso cambió a:', this.filters.kanban_type_process_id);
      this.filters.kanban_process_id = '';
    }
  },

  async mounted() {
    try {
      console.log('🔄 Componente montado, cargando datos...');
      
      // Cargar agentes
      this.$store.dispatch('agents/get');
      
      // Cargar kanban types
      //await this.loadKanbanTypeProcesses();
      
      console.log('✅ Estado del store después de cargar:');
      console.log('📊 Store state:', this.$store.state.kanbanTypeProcesses);
      console.log('🎯 Kanban types computed:', this.kanbanTypes);
      console.log('🔧 Todos los procesos:', this.allKanbanProcesses);
      
      // Aplicar filtros iniciales
      this.applyFilters();
      
    } catch (error) {
      console.error('❌ Error en mounted:', error);
    }
  },

  methods: {
    onKanbanTypeChange() {
      console.log('🔄 Cambio en kanban type:', this.filters.kanban_type_process_id);
      alert("change kanban")
      // Limpiar proceso cuando cambia el tipo
      this.filters.kanban_process_id = '';
      
      // Aplicar filtros
      this.onFilterChange();
    },

    onFilterChange() {
      console.log('🔄 Filtros cambiaron:', this.filters);
      // Auto-aplicar filtros cuando cambia algún valor
      this.applyFilters();
    },

    applyFilters() {
      console.log('🔄 Aplicando filtros:', this.filters);
      
      const activeFilters = {};
      
      Object.keys(this.filters).forEach(key => {
        if (this.filters[key] !== '' && this.filters[key] !== null) {
          activeFilters[key] = this.filters[key];
        }
      });

      console.log('✅ Filtros activos:', activeFilters);
      this.$store.dispatch('kanbanConversations/filterByBothKanban', activeFilters);
    },

    clearAllFilters() {
      console.log('🧹 Limpiando todos los filtros');
      
      this.filters = {
        kanban_type_process_id: '',
        kanban_process_id: '',
        status: '',
        assignee_id: '',
      };
      
      this.$store.dispatch('kanbanConversations/clearFilters');
    },

    // Método de utilidad para debugging
    debugStoreState() {
      console.group('🔍 DEBUG STORE STATE');
      console.log('Raw store state:', this.$store.state.kanbanTypeProcesses);
      console.log('Computed kanbanTypes:', this.kanbanTypes);
      console.log('All processes:', this.allKanbanProcesses);
      console.log('Available processes:', this.availableKanbanProcesses);
      console.log('Current filters:', this.filters);
      console.groupEnd();
    },
  },
};
</script>

<style lang="scss" scoped>
.kanban-conversation-filter {
  display: flex;
  flex-direction: column;
  height: 100%;
}

.filter-controls {
  padding: var(--space-normal);
  border-bottom: 1px solid var(--color-border);
  background: var(--white);
}

.filter-form {
  display: flex;
  flex-wrap: wrap;
  gap: var(--space-small);
  margin-top: var(--space-small);
}

.multiselect-wrap {
  min-width: 200px;
  flex: 1;
}

.button-wrap {
  display: flex;
  gap: var(--space-smaller);
  align-items: end;
  
  .button {
    min-width: 120px;
  }
}

.conversations-list {
  flex: 1;
  overflow-y: auto;
}

.conversations--loader {
  align-items: center;
  display: flex;
  font-size: var(--font-size-default);
  justify-content: center;
  padding: var(--space-jumbo);
}

.empty-state {
  align-items: center;
  display: flex;
  flex-direction: column;
  height: 100%;
  justify-content: center;
  padding: var(--space-jumbo);
  
  &--content {
    text-align: center;
  }
  
  &--icon {
    color: var(--s-200);
    margin-bottom: var(--space-normal);
  }
  
  &--title {
    color: var(--s-600);
    font-size: var(--font-size-large);
    font-weight: var(--font-weight-medium);
    margin-bottom: var(--space-smaller);
  }
  
  &--subtitle {
    color: var(--s-500);
    font-size: var(--font-size-small);
    line-height: 1.4;
  }
}

.conversation-list-wrap {
  padding: var(--space-small);
}

.conversation-metadata {
  padding: var(--space-small) var(--space-normal);
  border-bottom: 1px solid var(--color-border-light);
  
  .conversation-count {
    color: var(--s-500);
    font-size: var(--font-size-mini);
    font-weight: var(--font-weight-medium);
  }
}
</style>