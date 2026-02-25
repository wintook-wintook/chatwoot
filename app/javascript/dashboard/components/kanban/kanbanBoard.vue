<script>
import { mapGetters } from 'vuex';
import KanbanColumn from './kanbanColumn.vue';
import ConversationApi from '../../api/inbox/conversation';

import wootConstants from 'dashboard/constants/globals';
// En kanbanBoard.vue, agregar estos imports:
import ProcessModal from './ProcessModal.vue';
import TypeProcessModal from './TypeProcessModal.vue';

export default {
  name: 'KanbanBoard',
  components: {
    KanbanColumn,
    ProcessModal,
    TypeProcessModal,
  },

  // 1. NUEVA PROP AGREGADA
  props: {
    label: {
      type: String,
      default: '',
    },
    // NUEVA PROP para filtro por estado
    statusFilter: {
      type: String,
      default: '',
    },
  },
  

  //MNDN- Identificacion del mapeo de los estados de Kanban 
  data() {
    return {
      columns: [
        // { id: 'open', name: 'To Do', status: 'pending' },
        // { id: 'pending', name: 'In Progress', status: 'open' },
        // { id: 'resolved', name: 'Done', status: 'resolved' },
         { id: 'open', name: 'CONTACTO INICIAL', status: 'open' },
         { id: 'pending', name: 'NECESIDADES', status: 'pending' },
         { id: 'resolved', name: 'CIERRE', status: 'resolved' },
        { id: 'helpme', name: 'POSTVENTA', status: 'snoozed' },
      ],
      conversations: [],
      loading: true,
      error: null,
      activeAssigneeTab: wootConstants.ASSIGNEE_TYPE.ME, // Usar la constante del proyecto
    };
  },
  computed: {
    ...mapGetters({
      currentUser: 'getCurrentUser',
      accountId: 'getCurrentAccountId',
      mineChatsList: 'getMineChats', // Getter que ya filtra "mías"
      allChatList: 'getAllStatusChats', // Para obtener todas las conversaciones
    }),
    
    // Crear filtros como en el proyecto original
    conversationFilters() {
      return {
        assigneeType: this.activeAssigneeTab, // Usar "me"
        status: 'all', // Obtener todos los estados
        page: 1,
      };
    },

    // 2. NUEVA FUNCIÓN COMPUTED AGREGADA - Filtrar conversaciones por etiqueta

/*       filteredConversations() {
  if (!this.label) {
    return this.conversations;
  }
  
  return this.conversations.filter(conversation => {
    if (!conversation.labels || !Array.isArray(conversation.labels)) {
      return false;
    }
    
    // CAMBIO CLAVE: labels es array de strings directos, no objetos
    return conversation.labels.some(labelString => {
      // Comparar string directamente (sin .title)
      return labelString === this.label || 
             labelString.toLowerCase() === this.label.toLowerCase();
    });
  });
}, */
     // REEMPLAZAR tu función filteredConversations() completa por esta:

filteredConversations() {
  // Empezar con todas las conversaciones
  let filtered = this.conversations;
  
  // FILTRO POR ETIQUETA (tu código existente)
  if (this.label) {
    console.log('🏷️ Filtrando por etiqueta:', this.label);
    filtered = filtered.filter(conversation => {
      if (!conversation.labels || !Array.isArray(conversation.labels)) {
        return false;
      }
      // CAMBIO CLAVE: labels es array de strings directos, no objetos
      return conversation.labels.some(labelString => {
        // Comparar string directamente (sin .title)
        return labelString === this.label ||
               labelString.toLowerCase() === this.label.toLowerCase();
      });
    });
  }
  
  // NUEVO: FILTRO POR ESTADO
  if (this.statusFilter) {
    console.log('📊 Filtrando por estado:', this.statusFilter);
    filtered = filtered.filter(conversation => {
      return conversation.status === this.statusFilter;
    });
  }
  
  console.log('✅ Conversaciones filtradas:', filtered.length);
  return filtered;
},

    // NUEVA FUNCIÓN COMPUTED - Título dinámico
   /*  boardTitle() {
      const baseTitle = `My Conversations (${this.totalConversations})`;
      if (this.label) {
        return `${baseTitle} - #${this.label}`;
      }
      return baseTitle;
    }, */

     // MODIFICAR boardTitle para mostrar ambos filtros:
    boardTitle() {
      let title = `My Conversations (${this.totalConversations})`;
      
      if (this.statusFilter) {
        const statusNames = {
          'open': 'Analisis',
          'pending': 'Propuesta', 
          'resolved': 'Seguimiento',
          'snoozed': 'Cierre'
        };
        title += ` - ${statusNames[this.statusFilter] || this.statusFilter.toUpperCase()}`;
      }
      
      if (this.label) {
        title += ` - #${this.label}`;
      }
      
      return title;
    },

    // NUEVO: Computed para saber si hay filtros activos
    hasActiveFilters() {
      return !!(this.label || this.statusFilter);
    },
    
    // MNDN- Mapeo de los estados de Kanban de una conversacion y es actualizar los  los computed properties
    // MODIFICADO: Cambiar this.conversations por this.filteredConversations
    openConversations() {
      return this.filteredConversations.filter(conv => conv.status === 'open');
    },
     pendingConversations() {
      return this.filteredConversations.filter(conv => conv.status === 'pending');
    },
    resolvedConversations() {
      return this.filteredConversations.filter(conv => conv.status === 'resolved');
    },
    helpmeConversations() {
      return this.filteredConversations.filter(conv => conv.status === 'snoozed');
    },
    columnConversations() {
      return {
        open: this.openConversations,
        pending: this.pendingConversations,
        resolved: this.resolvedConversations,
        helpme: this.helpmeConversations,
      };
    },
    
    // MODIFICADO: Cambiar this.conversations por this.filteredConversations
    totalConversations() {
      return this.filteredConversations.length;
    },
  },

  // 3. NUEVO WATCH AGREGADO
 /*  watch: {
    label(newLabel, oldLabel) {
        console.log('🎯 WATCH LABEL:');
      console.log('  Nuevo label:', newLabel);
      console.log('  Label anterior:', oldLabel);
      console.log('  $route.params:', this.$route.params);
      console.log('  $route.params.label:', this.$route.params.label);
      console.log('  URL actual:', this.$route.fullPath);
      if (newLabel !== oldLabel) {
        this.fetchMyConversations();
      }
    }
  }, */
  // MODIFICAR watch para incluir statusFilter:
  watch: {
    label(newLabel, oldLabel) {
      if (newLabel !== oldLabel) {
        this.fetchMyConversations();
      }
    },
    // NUEVO: Watch para statusFilter
    statusFilter(newStatus, oldStatus) {
      if (newStatus !== oldStatus) {
        this.fetchMyConversations();
      }
    }
  },

  mounted() {
    // this.fetchMyConversations();
    alert("hola")
  },
  methods: {
    async fetchMyConversations() {
      this.loading = true;
      this.error = null;

      //MNDN temporal
      // Copia y pega esto en la consola del Kanban:
      console.log('🔍 Debug completo:');
      console.log('Conversaciones cargadas:', this.conversations);
      this.conversations.forEach((conv, index) => {
      console.log(`Conversación ${index + 1}: ID=${conv.id}, Status="${conv.status}"`);
        });
        //agregar console temporal 
        this.conversations.forEach((conv, index) => {
  console.log(`Conversación ${index + 1}:`, {
    id: conv.id,
    status: conv.status,
    // AGREGAR ESTAS LÍNEAS PARA VER TODO:
    labels: conv.labels,
    hasLabels: !!conv.labels,
    labelCount: conv.labels ? conv.labels.length : 0,
    // Ver todas las propiedades del objeto:
    allProperties: Object.keys(conv)
  });
});

        // Verificar definición de columnas:
      console.log('Columnas definidas:', this.columns);
       console.log('Mapeo de conversaciones:', this.columnConversations);
      
      try {
        console.log('🔍 Loading MY conversations using store method...');
        console.log('👤 Current user:', this.currentUser);
        console.log('🎯 Assignee type:', this.activeAssigneeTab);
        
        // USAR EL MISMO SISTEMA QUE EL PROYECTO ORIGINAL:
        // 1. Actualizar filtros en el store
        await this.$store.dispatch('updateChatListFilters', this.conversationFilters);
        
        // 2. Obtener conversaciones usando el action del store
        await this.$store.dispatch('fetchAllConversations');
        
        // 3. Obtener MIS conversaciones usando el getter que ya filtra
        this.conversations = [...this.mineChatsList(this.conversationFilters)];
        
        console.log('✅ Loaded MY conversations from store:', this.conversations.length);
        console.log('📋 Conversations:', this.conversations);
        
      } catch (error) {
        console.error('❌ Error using store method:', error);
        
        // FALLBACK: Usar método directo como respaldo
        try {
          console.log('🔄 Trying direct API as fallback...');
          
          const response = await ConversationApi.get({
            assignee_type: 'me'
          });
          
          console.log('📡 Direct API Response:', response);
          
          if (response.data && response.data.data && response.data.data.payload) {
            const allConversations = response.data.data.payload;
            
            // Filtrar manualmente las que son mías
            this.conversations = allConversations.filter(conv => {
              const isAssignedToMe = conv.assignee && conv.assignee.id === this.currentUser.id;
              console.log(`Conversation ${conv.id}: assigned to ${conv.assignee?.name || 'nobody'}, is mine: ${isAssignedToMe}`);
              return isAssignedToMe;
            });
            
            console.log('✅ Fallback successful, my conversations:', this.conversations.length);
          } else {
            this.conversations = [];
            console.log('⚠️ No conversations found in fallback');
          }
          
        } catch (fallbackError) {
          console.error('❌ Fallback also failed:', fallbackError);
          this.error = fallbackError;
          this.conversations = [];
        }
      }
      
      this.loading = false;
    },
    
    async handleCardDropped({ conversationId, sourceColumnId, targetColumnId }) {
      if (sourceColumnId === targetColumnId) return;
      
      const targetColumn = this.columns.find(c => c.id === targetColumnId);
      if (!targetColumn) return;
      
      try {
        console.log(`🔄 Moving conversation ${conversationId} to ${targetColumn.status}`);
        
        // Actualizar en la UI inmediatamente
        const conv = this.conversations.find(c => c.id === conversationId);
        if (conv) {
          conv.status = targetColumn.status;
        }
        
        // Usar el action del store para actualizar (como en el proyecto original)
        await this.$store.dispatch('toggleStatus', {
          conversationId,
          status: targetColumn.status,
        });
        
        console.log('✅ Conversation status updated via store');
        
        // Refrescar las conversaciones
        setTimeout(() => {
          this.fetchMyConversations();
        }, 500);
        
      } catch (error) {
        console.error('❌ Error updating conversation:', error);
        // Recargar para sincronizar
        this.fetchMyConversations();
      }
    },
    
    refresh() {
      this.fetchMyConversations();
    },
    
    goToConversations() {
      this.$router.push({
        name: 'home',
        params: { accountId: this.accountId }
      });
    },
  },
};
</script>

<template>
  <div class="kanban-board-container p-6 h-full bg-slate-25 dark:bg-slate-900">
    <!-- Header -->
    <div class="flex justify-between items-center mb-6">
      <div class="flex items-center space-x-4">
        <!-- MODIFICADO: Cambiar título por boardTitle -->
        <h1 class="text-2xl font-semibold text-slate-800 dark:text-slate-200">
          {{ boardTitle }}
        </h1>
        <!---DESDE AQUI 2 DE JUNIO-->
        <!-- AGREGAR ESTAS LÍNEAS DESPUÉS DEL </h1>: -->
        
        <!-- Indicadores de filtros activos -->
        <div v-if="hasActiveFilters" class="flex items-center space-x-2 mt-2">
          
          <!-- Mostrar si hay filtro por estado -->
          <div v-if="statusFilter" class="text-sm">
            <span class="bg-green-100 dark:bg-green-900 px-2 py-1 rounded text-green-800 dark:text-green-200">
              Estado: {{ statusFilter.toUpperCase() }}
            </span>
          </div>

          <!-- Mostrar si hay filtro por etiqueta -->
          <div v-if="label" class="text-sm">
            <span class="bg-blue-100 dark:bg-blue-900 px-2 py-1 rounded text-blue-800 dark:text-blue-200">
              Etiqueta: #{{ label }}
            </span>
          </div>

          <!-- Botón para limpiar filtros -->
          <router-link 
            :to="{ name: 'kanban_dashboard' }"
            class="ml-2 text-red-600 hover:text-red-800 text-sm underline"
          >
            Limpiar filtros
          </router-link>
        </div>
        <!---HASTA AQUI 2 DE JUNIO-->

        <!-- NUEVO: Indicador de filtro por etiqueta -->
        <div v-if="label" class="text-sm text-slate-600 dark:text-slate-400">
          <span class="bg-blue-100 dark:bg-blue-900 px-2 py-1 rounded">
            Filtrado por: #{{ label }}
          </span>
          <router-link 
            :to="{ name: 'kanban_dashboard' }"
            class="ml-2 text-blue-600 hover:text-blue-800 dark:text-blue-400 dark:hover:text-blue-300"
          >
            Limpiar filtro
          </router-link>
        </div>

        <!-- <div class="text-sm text-slate-600 dark:text-slate-400">
          <span class="bg-blue-100 dark:bg-blue-900 px-2 py-1 rounded">
            Filter: {{ activeAssigneeTab.toUpperCase() }}
          </span>
        </div> -->
      </div>
      
      <div class="flex items-center space-x-3">
        <woot-button 
          variant="clear"
          color-scheme="primary"
          icon="arrow-counterclockwise"
          size="small"
          :loading="loading"
          @click="refresh"
        >
          Refresh
        </woot-button>
        <woot-button 
          variant="solid"
          color-scheme="primary"
          icon="chat"
          size="small"
          @click="goToConversations"
        >
          All Conversations
        </woot-button>
      </div>
    </div>
    
    <!-- Error -->
    <div v-if="error" class="bg-red-50 border border-red-200 rounded p-4 mb-4">
      <p class="text-red-700">Error loading conversations. Check console for details.</p>
    </div>

    <!-- NUEVO: Mensaje cuando no hay conversaciones con la etiqueta -->
    <!-- <div 
      v-if="label && filteredConversations.length === 0 && !loading" 
      class="flex flex-col items-center justify-center h-64 text-center"
    > -->
    <div 
      v-if="hasActiveFilters && filteredConversations.length === 0 && !loading" 
      class="flex flex-col items-center justify-center h-64 text-center"
    >
      <div class="text-slate-400 mb-4">
        <fluent-icon icon="tag" size="48" />
      </div>
      <h3 class="text-lg font-medium text-slate-600 dark:text-slate-300 mb-2">
        No hay conversaciones con la etiqueta "#{{ label }}"
      </h3>
      <p class="text-slate-500 dark:text-slate-400">
        Intenta con una etiqueta diferente o crea nuevas conversaciones.
      </p>
    </div>
    
    <!-- Loading -->
    <div v-if="loading" class="flex justify-center items-center h-64">
      <div class="text-center">
        <div class="loading-spinner mx-auto mb-3"></div>
        <p class="text-slate-500">Loading conversations...</p>
      </div>
    </div>
    
    <!-- Kanban Board 
    <div v-else-if="!label || filteredConversations.length > 0" class="kanban-board flex space-x-6 overflow-x-auto pb-4">  -->
      <!--
      LINEA NUEVA 2 DE JUNIO
      -->
       <div v-else-if="!hasActiveFilters || filteredConversations.length > 0" class="kanban-board flex space-x-6 overflow-x-auto pb-4">
      <KanbanColumn
        v-for="column in columns"
        :key="column.id"
        :column="column"
        :conversations="columnConversations[column.id] || []"
        @card-dropped="handleCardDropped"
      />
    </div>
  </div>
</template>

<style scoped>
.kanban-board-container {
  max-height: calc(100vh - 72px);
}

.kanban-board {
  min-height: 500px;
}

.loading-spinner {
  width: 32px;
  height: 32px;
  border: 3px solid #f3f4f6;
  border-top: 3px solid #3b82f6;
  border-radius: 50%;
  animation: spin 1s linear infinite;
}

@keyframes spin {
  0% { transform: rotate(0deg); }
  100% { transform: rotate(360deg); }
}
</style>