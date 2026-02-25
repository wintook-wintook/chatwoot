<template>
    <div
      class="flex flex-col w-80 bg-slate-100 dark:bg-slate-800 rounded-lg kanban-column"
      :class="{ 'bg-blue-100 border-2 border-blue-400 border-dashed': isDragOver }"
      @dragover="onDragOver"
      @drop="onDrop"
      @dragenter="onDragEnter"
      @dragleave="onDragLeave"
    >
      <!-- Column Header -->
      <div
        class="flex items-center justify-between p-4 border-b border-slate-200 dark:border-slate-700"
      >
        <div>
          <h3 class="font-medium text-slate-900 dark:text-slate-100">
            {{ typeProcess.type_process_name }}
          </h3>
          <p class="text-sm text-slate-500 dark:text-slate-400">
            <span v-if="loading">Cargando...</span>
            <span v-else-if="error" class="text-red-500">Error</span>
            <span v-else>{{ columnConversations.length }} {{ $t('KANBAN.BOARD.CONVERSATION') }}</span>
          </p>
        </div>
        <div class="flex items-center space-x-1">
          <!-- Botón de refresh -->
          <button
            @click="refreshConversations"
            class="p-1 text-slate-400 hover:text-slate-600 dark:hover:text-slate-300 transition-colors"
            :disabled="loading"
            title="Actualizar conversaciones"
          >
            <i
              class="icon icon--font fluent-icon-arrow-clockwise"
              :class="{ 'animate-spin': loading }"
            ></i>
          </button>
  
          <span
            v-if="typeProcess.default"
            class="px-2 py-1 text-xs bg-green-100 text-green-800 rounded dark:bg-green-900 dark:text-green-300"
          >
            Default
          </span>
          <span
            v-if="typeProcess.is_system"
            class="px-2 py-1 text-xs bg-blue-100 text-blue-800 rounded dark:bg-blue-900 dark:text-blue-300"
          >
            System
          </span>
        </div>
      </div>
  
      <!-- Column Content -->
      <div class="flex-1 p-4 space-y-3 overflow-y-auto">
        <!-- Loading State -->
        <div v-if="loading" class="text-center py-8">
          <div class="spinner mx-auto mb-2"></div>
          <p class="text-slate-500 dark:text-slate-400">
             <!-- Cargando conversaciones... -->
          {{ $t('KANBAN.BOARD.LOADING_CONVERSATIONS') }}
          </p>
        </div>
  
        <!-- Error State -->
        <div v-else-if="error" class="text-center py-8">
          <div class="text-4xl mb-2">⚠️</div>
          <p class="text-red-500 mb-2 text-sm">{{ error }}</p>
          <button
            @click="refreshConversations"
            class="px-3 py-1 text-sm bg-red-100 text-red-700 rounded hover:bg-red-200 transition-colors"
          >
            <!-- Reintentar -->
          {{ $t('KANBAN.BOARD.RETRY') }}
          </button>
        </div>
  
        <!-- Empty State -->
        <div v-else-if="columnConversations.length === 0" class="text-center py-8">
          <div class="text-4xl mb-2">📋</div>
          <p class="text-slate-500 dark:text-slate-400 mb-1">
            <!-- No hay conversaciones en esta etapa -->
           {{ $t('KANBAN.BOARD.NO_CONVERSATIONS') }}
          </p>
          <p class="text-xs text-slate-400">
            <!-- Arrastra conversaciones aquí -->
          {{ $t('KANBAN.BOARD.DRAG_CONVERSATIONS') }}
          </p>
        </div>
  
        <!-- Conversations List -->
        <div v-else class="space-y-3">
          <KanbanConversationCard
            v-for="conversation in columnConversations"
            :key="`${typeProcess.id}-${conversation.id}`"
            :conversation="conversation"
            :column-id="typeProcess.id"
            :active-label="labelFilter"
            :team-id="teamId"
            :folders-id="foldersId"
            :conversation-type="conversationType"
            @drag-start="onCardDragStart"
            @drag-end="onCardDragEnd"
          />
        </div>
  
        <!-- Refresh Button -->
        <button
          class="w-full p-3 text-sm text-slate-600 border-2 border-dashed rounded-lg border-slate-300 dark:border-slate-600 dark:text-slate-400 hover:border-blue-500 hover:text-blue-500 transition-colors"
          @click="refreshConversations"
          :disabled="loading"
        >
          <i class="icon icon--font fluent-icon-arrow-clockwise mr-2"></i>
           <!-- Actualizar conversaciones -->
         {{ $t('KANBAN.BOARD.UPDATING_CONVERSATIONS') }}
        </button>
      </div>
    </div>
  </template>
  
  <script>
  import KanbanConversationCard from './KanbanConversationCard.vue';
  
  export default {
    name: 'KanbanColumn',
    
    components: {
      KanbanConversationCard,
    },
  
    props: {
      typeProcess: {
        type: Object,
        required: true,
      },
      processId: {
        type: [String, Number],
        required: true,
      },
      labelFilter: {
        type: String,
        default: null,
      },
      statusFilter: {
        type: String,
        default: 'open',
      },
      assigneeFilter: {
        type: String,
        default: 'me',
      },
      teamId: {
        type: [String, Number],
        default: 0,
      },
      foldersId: {
        type: [String, Number],
        default: 0,
      },
      conversationType: {
        type: String,
        default: '',
      },
    },
  
    data() {
      return {
        loading: false,
        error: null,
        columnConversations: [],
        lastLoadTime: null,
        draggingConversation: null,
        isDragOver: false,
      };
    },
  
    async mounted() {
      console.log(`🚀 MOUNTED: Column "${this.typeProcess.type_process_name}" (ID: ${this.typeProcess.id})`);
      
      // Delay diferente para cada columna para evitar conflictos
      const columnDelays = {
        9: 0,     // Nuevo - carga inmediatamente
        10: 300,  // En Progreso - 300ms después
        11: 600,  // Esperando Cliente - 600ms después  
        12: 900,  // Resuelto - 900ms después
      };
      
      const delay = columnDelays[this.typeProcess.id] || 0;
      console.log(`⏱️ Column "${this.typeProcess.type_process_name}" will load in ${delay}ms`);
      
      setTimeout(async () => {
        await this.loadConversations();
      }, delay);
    },
  
    methods: {
      // === CARGA DE CONVERSACIONES ===
      async loadConversations() {
        this.loading = true;
        this.error = null;
        this.lastLoadTime = new Date().toLocaleTimeString();
        
        try {
          console.log(`🔄 LOADING: "${this.typeProcess.type_process_name}" (ID: ${this.typeProcess.id})`);
          
          // Construir filtros
          const filters = {
            kanban_type_process_id: this.processId,
            kanban_process_id: this.typeProcess.id,
          };
          
          // Agregar assignee si no es 'all'
          if (this.assigneeFilter && this.assigneeFilter !== 'all') {
            if (this.assigneeFilter === 'me') {
              const currentUser = await this.$store.getters.getCurrentUser;
              if (currentUser && currentUser.id) {
                filters.assignee_id = currentUser.id;
              }
            } else {
              filters.assignee_id = this.assigneeFilter;
            }
          }
          
          console.log(`📡 FILTERS:`, filters);
          
          // Obtener datos directamente del dispatch
          const dispatchResult = await this.$store.dispatch('kanbanConversations/filterByBothKanban', filters);
          
          // Extraer conversaciones usando función auxiliar
          const conversations = this.extractConversationsFromResponse(dispatchResult);
          
          // Asignar directamente
          this.columnConversations = [...conversations];
          
          console.log(`✅ SUCCESS: ${this.columnConversations.length} conversations for "${this.typeProcess.type_process_name}"`);
          
        } catch (error) {
          console.error(`❌ ERROR loading "${this.typeProcess.type_process_name}":`, error);
          this.error = error.message || 'Error al cargar conversaciones';
        } finally {
          this.loading = false;
        }
      },
  
      // Función auxiliar en el componente
      extractConversationsFromResponse(response) {
        if (response && response.data && response.data.data && Array.isArray(response.data.data)) {
          return response.data.data;
        }
        if (response && response.data && Array.isArray(response.data)) {
          return response.data;
        }
        if (response && Array.isArray(response)) {
          return response;
        }
        return [];
      },
  
      async refreshConversations() {
        console.log(`🔄 REFRESH: "${this.typeProcess.type_process_name}"`);
        await this.loadConversations();
      },
  
      // === DRAG & DROP HANDLERS ===
      onCardDragStart(conversation, columnId) {
        console.log(`🎯 CARD_DRAG_START: Conversation ${conversation.id} from column ${columnId}`);
        this.draggingConversation = conversation.id;
        
        // Emitir al componente padre (KanbanBoard)
        this.$emit('drag-start', conversation, this.typeProcess);
      },
  
      onCardDragEnd() {
        console.log(`🎯 CARD_DRAG_END: Clearing dragging state`);
        this.draggingConversation = null;
      },
  
      onDragEnter(event) {
        event.preventDefault();
        this.isDragOver = true;
      },
  
      onDragLeave(event) {
        // Solo quitar el highlight si realmente salimos de la columna
        if (!this.$el.contains(event.relatedTarget)) {
          this.isDragOver = false;
        }
      },
  
      onDragOver(event) {
        event.preventDefault();
        event.dataTransfer.dropEffect = 'move';
        this.isDragOver = true;
      },
  
      async onDrop(event) {
        event.preventDefault();
        this.isDragOver = false;
  
        try {
          const dragDataStr = event.dataTransfer.getData('application/json');
          if (!dragDataStr) {
            console.log('❌ No drag data found');
            return;
          }
  
          const dragData = JSON.parse(dragDataStr);
          console.log(`🎯 DROP: Conversation ${dragData.conversationId} from column ${dragData.sourceColumnId} to column ${this.typeProcess.id}`);
  
          // No hacer nada si se suelta en la misma columna
          if (dragData.sourceColumnId === this.typeProcess.id) {
            console.log('ℹ️ Dropped in same column, no action needed');
            return;
          }
  
          // Mover la conversación
          await this.moveConversationDirect(dragData.conversation, dragData.sourceColumnId);
  
        } catch (error) {
          console.error('❌ Error handling drop:', error);
          this.error = 'Error al mover la conversación';
        }
      },
  
      // ✅ NEW METHOD: Update conversation Kanban info like ConversationAction.vue does
      async updateConversationKanbanInfo(conversation, targetProcessId) {
        try {
          console.log('🔄 UPDATE_KANBAN_INFO: Starting update for conversation', conversation.id);
          console.log('📊 Target process ID:', targetProcessId);
  
          const conversationId = conversation.id;
          const oldKanbanTypeProcessId = conversation.kanban_type_process_id;
          const oldKanbanProcessId = conversation.kanban_process_id;
  
          // ✅ STEP 1: Update store immediately (optimistic update)
          console.log('🔄 UPDATE_KANBAN_INFO: STEP 1 - Updating local store...');
  
          if (this.$store._actions['conversations/setCurrentChatKanbanType']) {
            await this.$store.dispatch('conversations/setCurrentChatKanbanType', {
              kanbanTypeProcessId: this.processId, // Keep the same type
              kanbanProcessId: targetProcessId,    // Update to new process
              conversationId,
            });
            console.log('✅ UPDATE_KANBAN_INFO: Local store updated');
          }
  
          // ✅ STEP 2: Call the API that works (same as ConversationAction.vue)
          console.log('🔄 UPDATE_KANBAN_INFO: STEP 2 - Calling API...');
  
          if (this.$store._actions['conversations/updateKanbanProcess']) {
            const result = await this.$store.dispatch('conversations/updateKanbanProcess', {
              conversationId,
              kanban_type_process_id: this.processId, // Keep the same type
              kanban_process_id: targetProcessId,     // Update to new process
            });
            console.log('✅ UPDATE_KANBAN_INFO: API called successfully, result:', result);
          } else {
            console.error('❌ UPDATE_KANBAN_INFO: updateKanbanProcess action not found');
  
            // ✅ FALLBACK: Call API directly if not in store
            console.log('🔄 UPDATE_KANBAN_INFO: FALLBACK - Calling API directly...');
  
            const ConversationAPI = (await import('dashboard/api/conversations')).default;
            const response = await ConversationAPI.updateKanbanProcess(conversationId, {
              kanban_type_process_id: this.processId,
              kanban_process_id: targetProcessId,
            });
  
            console.log('✅ UPDATE_KANBAN_INFO: Direct API successful:', response.data);
          }
  
          // ✅ STEP 3: Update conversation object locally
          conversation.kanban_type_process_id = this.processId;
          conversation.kanban_process_id = targetProcessId;
  
          console.log('✅ UPDATE_KANBAN_INFO: Update completed successfully');
          return true;
  
        } catch (error) {
          console.error('❌ UPDATE_KANBAN_INFO: Error updating conversation:', error);
          
          // ✅ REVERT local changes on error
          if (this.$store._actions['conversations/setCurrentChatKanbanType']) {
            this.$store.dispatch('conversations/setCurrentChatKanbanType', {
              kanbanTypeProcessId: oldKanbanTypeProcessId,
              kanbanProcessId: oldKanbanProcessId,
              conversationId,
            });
          }
          
          throw error;
        }
      },
  
      // ✅ UPDATED METHOD: Use the new Kanban update method
      async moveConversationDirect(conversation, sourceColumnId) {
        console.log(`🔄 MOVE_DIRECT: Moving conversation ${conversation.id} from ${sourceColumnId} to ${this.typeProcess.id}`);
        
        try {
          // 1. Verify conversation doesn't already exist in this column
          const exists = this.columnConversations.find(conv => conv.id === conversation.id);
          if (exists) {
            console.log(`⚠️ Conversation ${conversation.id} already exists in column ${this.typeProcess.id}`);
            return;
          }
  
          // 2. Update in database using the same method as ConversationAction.vue
          console.log(`💾 DATABASE: Updating conversation ${conversation.id} in database`);
          
          try {
            // ✅ USE NEW METHOD: Same as ConversationAction.vue
            await this.updateConversationKanbanInfo(conversation, this.typeProcess.id);
            
            console.log(`✅ DATABASE: Successfully updated conversation ${conversation.id}`);
            
            // Show success message
            if (this.$toast?.success) {
              this.$toast.success('Conversación movida exitosamente');
            } else {
              console.log('✅ SUCCESS: Conversation moved successfully');
            }
            
          } catch (dbError) {
            console.error(`❌ DATABASE: Failed to update conversation ${conversation.id}:`, dbError);
            
            if (this.$toast?.error) {
              this.$toast.error('Error al mover la conversación');
            } else {
              console.error('❌ ERROR: Failed to move conversation');
            }
            
            this.error = 'Error al actualizar la conversación en la base de datos';
            return;
          }
  
          // 3. If DB updates successfully, update UI
          this.columnConversations.push({ ...conversation });
          console.log(`✅ UI: Added conversation ${conversation.id} to column ${this.typeProcess.id}`);
  
          // 4. Find and remove from all other columns
          this.$nextTick(() => {
            this.removeFromOtherColumns(conversation.id, sourceColumnId);
          });
  
        } catch (error) {
          console.error(`❌ Error in moveConversationDirect:`, error);
          this.error = 'Error al mover la conversación';
          
          if (this.$toast?.error) {
            this.$toast.error('Error inesperado al mover la conversación');
          } else {
            console.error('❌ UNEXPECTED ERROR: Failed to move conversation');
          }
          
          throw error;
        }
      },
  
      // ✅ ENHANCED METHOD: Remove old HTTP fallback, use Kanban-specific update
      async updateConversationKanban(params) {
        console.log(`💾 UPDATE_DB: Updating conversation ${params.conversationId} with:`, params);
        
        // ✅ DIRECT USE: Use the new Kanban update method
        try {
          const conversation = { 
            id: params.conversationId,
            kanban_type_process_id: params.kanbanTypeProcessId,
            kanban_process_id: params.kanbanProcessId,
          };
          
          await this.updateConversationKanbanInfo(conversation, params.kanbanProcessId);
          return { success: true };
          
        } catch (error) {
          console.error(`❌ UPDATE_DB: Failed to update conversation ${params.conversationId}:`, error);
          throw error;
        }
      },
  
      // ✅ OPTIONAL: Method to update conversation status like ConversationAction.vue
      async updateConversationStatus(conversation, newStatus) {
        try {
          console.log('🔄 UPDATE_STATUS: Updating conversation status');
          
          const conversationId = conversation.id;
          
          // Update via store action if available
          if (this.$store._actions['conversations/updateConversation']) {
            await this.$store.dispatch('conversations/updateConversation', {
              conversationId,
              status: newStatus,
            });
          } else {
            // Fallback to direct API call
            const ConversationAPI = (await import('dashboard/api/conversations')).default;
            await ConversationAPI.update(conversationId, { status: newStatus });
          }
          
          // Update local conversation object
          conversation.status = newStatus;
          
          console.log('✅ UPDATE_STATUS: Status updated successfully');
          
        } catch (error) {
          console.error('❌ UPDATE_STATUS: Error updating status:', error);
          throw error;
        }
      },
  
      removeFromOtherColumns(conversationId, sourceColumnId) {
        console.log(`🔍 SEARCH: Looking for conversation ${conversationId} in other columns to remove`);
        
        // Buscar todas las instancias de KanbanColumn en el DOM
        const allColumns = this.$parent.$children.filter(child => 
          child.$options.name === 'KanbanColumn' && 
          child.typeProcess.id !== this.typeProcess.id
        );
  
        console.log(`🔍 Found ${allColumns.length} other columns to check`);
  
        allColumns.forEach(column => {
          const index = column.columnConversations.findIndex(conv => conv.id === conversationId);
          if (index !== -1) {
            console.log(`🗑️ REMOVING conversation ${conversationId} from column ${column.typeProcess.id} (${column.typeProcess.type_process_name})`);
            column.columnConversations.splice(index, 1);
          }
        });
      },
  
      // === MÉTODOS PÚBLICOS ===
      removeConversation(conversationId) {
        console.log(`➖ REMOVE: Removing conversation ${conversationId} from "${this.typeProcess.type_process_name}"`);
        
        const index = this.columnConversations.findIndex(conv => conv.id === conversationId);
        if (index !== -1) {
          this.columnConversations.splice(index, 1);
          console.log(`✅ Conversation ${conversationId} removed from "${this.typeProcess.type_process_name}"`);
          return true;
        } else {
          console.log(`⚠️ Conversation ${conversationId} not found in "${this.typeProcess.type_process_name}"`);
          return false;
        }
      },
  
      // === UTILITIES ===
      formatDate(timestamp) {
        if (!timestamp) return 'Sin fecha';
        const date = new Date(timestamp * 1000);
        return date.toLocaleDateString() + ' ' + date.toLocaleTimeString();
      },
    },
  };
  </script>
  
  <style scoped>
  /* === COLUMNA BASE === */
  .kanban-column {
    min-width: 320px;
    max-width: 320px;
    flex-shrink: 0;
    transition: all 0.2s ease;
  }
  
  .kanban-column:hover {
    transform: translateY(-1px);
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
  }
  
  /* === SPINNER === */
  .spinner {
    border: 2px solid #f3f3f3;
    border-top: 2px solid #3498db;
    border-radius: 50%;
    width: 20px;
    height: 20px;
    animation: spin 1s linear infinite;
  }
  
  @keyframes spin {
    0% { transform: rotate(0deg); }
    100% { transform: rotate(360deg); }
  }
  
  .animate-spin {
    animation: spin 1s linear infinite;
  }
  
  /* === DRAG & DROP STATES === */
  .kanban-column.drag-over {
    background: linear-gradient(135deg, #dbeafe 0%, #bfdbfe 100%);
    border: 2px dashed #3b82f6;
    transform: scale(1.02);
  }
  
  /* === TRANSITION EFFECTS === */
  .kanban-column {
    animation: fadeInSlide 0.3s ease-out;
  }
  
  @keyframes fadeInSlide {
    from {
      opacity: 0;
      transform: translateY(10px);
    }
    to {
      opacity: 1;
      transform: translateY(0);
    }
  }
  
  /* === SCROLL === */
  .overflow-y-auto {
    scrollbar-width: thin;
    scrollbar-color: rgba(148, 163, 184, 0.5) rgba(241, 245, 249, 0.3);
  }
  
  .overflow-y-auto::-webkit-scrollbar {
    width: 6px;
  }
  
  .overflow-y-auto::-webkit-scrollbar-track {
    background: rgba(241, 245, 249, 0.3);
    border-radius: 3px;
  }
  
  .overflow-y-auto::-webkit-scrollbar-thumb {
    background: rgba(148, 163, 184, 0.5);
    border-radius: 3px;
    transition: background-color 0.2s ease;
  }
  
  .overflow-y-auto::-webkit-scrollbar-thumb:hover {
    background: rgba(100, 116, 139, 0.7);
  }
  
  /* === RESPONSIVE === */
  @media (max-width: 768px) {
    .kanban-column {
      min-width: 280px;
      max-width: 280px;
    }
  }
  
  /* === DARK MODE === */
  @media (prefers-color-scheme: dark) {
    .overflow-y-auto {
      scrollbar-color: rgba(100, 116, 139, 0.5) rgba(30, 41, 59, 0.3);
    }
    
    .overflow-y-auto::-webkit-scrollbar-track {
      background: rgba(30, 41, 59, 0.3);
    }
    
    .overflow-y-auto::-webkit-scrollbar-thumb {
      background: rgba(100, 116, 139, 0.5);
    }
    
    .overflow-y-auto::-webkit-scrollbar-thumb:hover {
      background: rgba(148, 163, 184, 0.7);
    }
  }
  
  /* === ACCESIBILIDAD === */
  .kanban-column:focus-within {
    outline: 2px solid rgba(59, 130, 246, 0.5);
    outline-offset: 2px;
  }
  
  /* === PERFORMANCE === */
  .kanban-column {
    will-change: transform, box-shadow;
  }
  </style>