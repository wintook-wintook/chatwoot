<!-- /**
 KANBAN0725
 * KanbanBoard.vue
 *
 * 📌 Título: Componente principal del tablero Kanban completo
 *
 * 🎯 Objetivo:
 * Este componente sirve como la vista principal del sistema Kanban en la aplicación. Permite a los usuarios visualizar,
 * gestionar y manipular procesos y subprocesos (tipos de proceso) dentro de un tablero visual tipo Kanban.
 * Incluye funcionalidad completa de drag & drop, cards de conversaciones y scroll horizontal automático.
 *
 * 🧩 Funcionalidades principales:
 * - Visualizar columnas Kanban con conversaciones como cards
 * - Scroll horizontal automático basado en número de columnas
 * - Drag & drop completo entre columnas
 * - Filtros por etiqueta, estado y asignado
 * - Selector de tipo de proceso Kanban
 * - Gestión completa de conversaciones
 * - Navegación a conversaciones individuales
 * - Actualización en tiempo real
 *
 * 📦 Componentes usados:
 * - KanbanColumn: Renderiza cada columna del tablero con conversaciones
 * - KanbanConversationCard: Cards individuales de conversaciones
 * - ConversationKanbanSelector: Selector de asignación Kanban
 *
 * 🧠 Mixin:
 * - kanbanMixin: Contiene lógica compartida relacionada con procesos Kanban
 *
 * 🛠️ Autor: [Tu nombre o equipo]
 * 📅 Última modificación: [Fecha]
 * 🧩 Codigo de proyecto: [Codigo]
 */ -->

<script>
import { mapGetters } from 'vuex';
import KanbanColumn from '../components/kanban/kanbanColumn.vue';
import KanbanConversationCard from '../components/kanban/KanbanConversationCard.vue';
import ProcessModal from '../components/kanban/ProcessModal.vue';
import TypeProcessModal from '../components/kanban/TypeProcessModal.vue';
import { useAlert } from 'dashboard/composables';
import kanbanMixin from 'dashboard/mixins/kanbanMixin';
//import { frontendURL } from '../helper/URLHelper';
export default {
  name: 'KanbanBoard',
  components: {
    KanbanColumn,
    KanbanConversationCard,
    ProcessModal,
    TypeProcessModal,
  },

  mixins: [kanbanMixin],

  props: {
    label: {
      type: String,
      default: null,
    },
    statusFilter: {
      type: String,
      default: null,
    },
    // NUEVA prop para recibir el typeId desde la ruta
    typeId: {
      type: Number,
      default: null,
    },
    labelTypeName: {
      type: String,
      default: null,
    },
  },

  data() {
    return {
      selectedProcessId: null,
      draggedItem: null,
      draggedConversation: null,
      showProcessModal: false,
      showTypeProcessModal: false,
      selectedProcess: null,
      selectedTypeProcess: null,
      expandedProcessId: null,
      activeView: 'board', // 'board' o 'management'
      filteredTypeProcesses: [],

      // 🆕 NUEVAS PROPIEDADES PARA FILTROS
      filters: {
        assigneeFilter: 'all', // 'all', 'me', 'unassigned', o ID específico
        statusFilter: 'all',   // 'all', 'open', 'pending', 'resolved', etc.
        labelFilter: null,     // null o label específico
      },

      // 🆕 PROPIEDADES PARA DRAG & DROP
      dragOverColumn: null,
      isDragActive: false,
    };
  },

  computed: {
    ...mapGetters({
      conversations: 'kanbanConversations/getKanbanConversations',
      meta: 'kanbanConversations/getMeta',
      currentFilters: 'kanbanConversations/getCurrentFilters',
      uiFlags: 'kanbanConversations/getUIFlags',
      agents: 'agents/getAgents',
      currentUser: 'getCurrentUser',
    }),

    // Mapear los kanban types desde el store
    kanbanTypes() {
      console.log('🔄 Computando kanbanTypes desde store...');

      const storeData = this.$store.state.kanbanTypeProcesses;
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
        kanban_processes: record.kanban_processes || [],
      }));

      console.log('✅ Kanban types mapeados:', types);
      return types;
    },

    // NUEVA: Obtener el objeto completo del kanban type seleccionado
    selectedKanbanType() {
      if (!this.selectedProcessId || !this.kanbanTypes.length) {
        return null;
      }

      return this.kanbanTypes.find(
        type => type.id == this.selectedProcessId
      );
    },

    sortedTypeProcesses() {
      return [...this.filteredTypeProcesses].sort(
        (a, b) => a.position - b.position
      );
    },

    pageTitle() {
      console.log('🔍 COMPUTING pageTitle...');

      if (this.activeView === 'management') {
        return this.$t('KANBAN.PROCESSES.TITLE');
      }
      if (this.label) {
        const title = `${this.$t('KANBAN.BOARD.TITLE')} - Label: ${this.label}`;
        console.log('✅ Título con label:', title);
        return title;
      }
      if (this.statusFilter) {
        return `${this.$t('KANBAN.BOARD.TITLE')} - Status: ${this.statusFilter}`;
      }

      return this.$t('KANBAN.BOARD.TITLE');
    },

    // 🆕 COMPUTED PARA OPCIONES DE FILTROS
    assigneeOptions() {
      const options = [
        { id: 'all', name: 'Todos los agentes' },
        { id: 'me', name: 'Mis conversaciones' },
        { id: 'unassigned', name: 'Sin asignar' },
      ];

      // Agregar agentes específicos
      if (this.agents && this.agents.length > 0) {
        options.push({ id: 'separator', name: '──────────', disabled: true });
        this.agents.forEach(agent => {
          options.push({
            id: agent.id,
            name: agent.name,
            avatar: agent.avatar_url
          });
        });
      }

      return options;
    },

    statusOptions() {
      return [
        { id: 'all', name: 'Todos los estados' },
        { id: 'open', name: 'Abierto' },
        { id: 'pending', name: 'Pendiente' },
        { id: 'resolved', name: 'Resuelto' },
        { id: 'snoozed', name: 'Pospuesto' },
      ];
    },

    // 🆕 COMPUTED PARA ESTADÍSTICAS
    boardStats() {
      if (!this.sortedTypeProcesses.length) return {};

      const stats = {};
      this.sortedTypeProcesses.forEach(column => {
        stats[column.id] = {
          total: 0,
          unread: 0,
          highPriority: 0,
        };
      });

      return stats;
    },

    // 🆕 COMPUTED PARA ESTADO DE CARGA
    isLoading() {
      return this.uiFlags.isFetching || this.uiFlags.isUpdating;
    },

    // 🆕 COMPUTED PARA VERIFICAR SI HAY DATOS
    hasData() {
      return this.selectedProcessId && this.sortedTypeProcesses.length > 0;
    },
  },

  watch: {
    // Observar cambios en los datos del store
    kanbanTypes: {
      handler(newTypes) {
        console.log('🔄 kanbanTypes cambió:', newTypes);

        // NUEVA LÓGICA: Si hay un typeId específico de la ruta, usarlo
        if (this.typeId && newTypes.length > 0) {
          console.log('🎯 Usando typeId de la ruta:', this.typeId);
          this.selectedProcessId = this.typeId;
          this.onKanbanTypeChange();
          return;
        }

        // Si no hay typeId específico, usar la lógica por defecto
        if (newTypes.length > 0 && !this.selectedProcessId) {
          const defaultType = newTypes.find(type => type.default);
          const typeToSelect = defaultType || newTypes[0]; // Usar el por defecto o el primero

          console.log('🎯 Seleccionando tipo por defecto:', typeToSelect.name);
          this.selectedProcessId = typeToSelect.id;

          // Llamar al método para cargar los procesos filtrados
          this.onKanbanTypeChange();
        }
      },
      immediate: true,
    },

    // NUEVO: Watch para cambios en typeId desde la ruta
    typeId: {
      handler(newTypeId) {
        console.log('🔄 typeId desde ruta cambió a:', newTypeId);
        if (newTypeId && this.kanbanTypes.length > 0) {
          this.selectedProcessId = newTypeId;
          this.onKanbanTypeChange();
        }
      },
      immediate: true,
    },

    // Observar cambios en selectedProcessId
    selectedProcessId(newId) {
      console.log('🔄 selectedProcessId cambió a:', newId);
      if (newId) {
        this.onKanbanTypeChange();
        this.updateRouteIfNeeded(newId);
      }
    },

    // 🆕 WATCH PARA FILTROS
    'filters.assigneeFilter'() {
      this.refreshBoardData();
    },

    'filters.statusFilter'() {
      this.refreshBoardData();
    },

    'filters.labelFilter'() {
      this.refreshBoardData();
    },

    // 🆕 WATCH PARA RECALCULAR SCROLL WIDTH CUANDO CAMBIEN LAS COLUMNAS
    sortedTypeProcesses: {
      handler() {
        this.$nextTick(() => {
          // Forzar recálculo del scroll width
          this.$forceUpdate();
        });
      },
      immediate: true
    }
  },

  async mounted() {
    try {
      console.log('🔄 Componente montado, cargando datos...');
      console.log('1. Vue i18n disponible:', !!this.$i18n);
      console.log('2. Función $t disponible:', typeof this.$t);

      // Debug temporal
      console.log('🔍 KanbanBoard mounted con props:', {
        typeId: this.typeId,
        label: this.label,
        statusFilter: this.statusFilter,
        labelTypeName: this.labelTypeName
      });

      // Cargar agentes
      this.$store.dispatch('agents/get');

      // IMPORTANTE: Cargar kanban types desde el store
      await this.$store.dispatch('kanbanTypeProcesses/get');

      // 🆕 CONFIGURAR FILTROS INICIALES
      this.setupInitialFilters();

      console.log('✅ Estado del store después de cargar:');
      console.log('📊 Store state:', this.$store.state.kanbanTypeProcesses);
      console.log('🎯 Kanban types computed:', this.kanbanTypes);
    } catch (error) {
      console.error('❌ Error en mounted:', error);
    }
  },

  methods: {
    // ============ MÉTODOS DE INICIALIZACIÓN ============

    // 🆕 CONFIGURAR FILTROS INICIALES
    setupInitialFilters() {
      // Configurar filtros basados en props de la ruta
      if (this.label) {
        this.filters.labelFilter = this.label;
      }
      if (this.statusFilter) {
        this.filters.statusFilter = this.statusFilter;
      }
    },

    navigateToKanbanSettings() {
      console.log('=== DEBUG INFO ===');
  console.log('this.currentAccountId:', this.currentAccountId);
  console.log('this.accountId:', this.accountId);
  console.log('$route.params:', this.$route.params);
  console.log('$route.params.accountId:', this.$route.params.accountId);
  console.log('$store.state:', this.$store.state);
  console.log('==================');
      // this.$router.push({
      //   name: 'kanban_types_list',
      //   params: {
      //     accountId: this.currentAccountId
      //   }
      // });
        const url = `/app/accounts/${this.$route.params.accountId}/settings/kanban`;
        console.log('Navegando a:', url);
         this.$router.push(url);
      //params: { accountId: this.currentAccountId },
    },


    // 🆕 CALCULAR ANCHO DE SCROLL DINÁMICO
    calculateScrollWidth() {
      const columnWidth = 320; // 320px por columna
      const gap = 24; // 24px gap entre columnas
      const padding = 48; // 48px padding total
      const totalColumns = this.sortedTypeProcesses.length;

      if (totalColumns === 0) return '100%';

      const totalWidth = (totalColumns * columnWidth) + ((totalColumns - 1) * gap) + padding + 100; // +100px buffer
      console.log('🔧 Calculated scroll width:', `${totalWidth}px`, 'for', totalColumns, 'columns');
      return `${totalWidth}px`;
    },

    // ============ MÉTODOS DE NAVEGACIÓN Y RUTA ============

    // NUEVO: Método para actualizar la ruta cuando cambia el selector
    updateRouteIfNeeded(typeId) {
      const currentTypeId = parseInt(this.$route.params.typeId);

      // Solo actualizar si el typeId es diferente al actual en la ruta
      if (currentTypeId !== typeId) {
        console.log('🔄 Actualizando ruta a typeId:', typeId);

        this.$router.replace({
          name: 'kanban_type_view',
          params: {
            accountId: this.$route.params.accountId,
            typeId: typeId
          },
          query: this.$route.query // Mantener query params como label, status, etc.
        }).catch(err => {
          // Ignorar errores de navegación duplicada
          if (err.name !== 'NavigationDuplicated') {
            console.error('Error actualizando ruta:', err);
          }
        });
      }
    },

    // ============ MÉTODOS DE DATOS Y FILTROS ============

    onKanbanTypeChange() {
      console.log('🔄 Cambio en kanban type:');
      console.log('Valor seleccionado:', this.selectedProcessId);
      console.log('kanbanTypes disponibles:', this.kanbanTypes);

      // Buscar el proceso seleccionado
      const selectedProcess = this.kanbanTypes.find(
        process => process.id == this.selectedProcessId
      );
      console.log('Proceso seleccionado:', selectedProcess);

      // Validar que se encontró el proceso
      if (selectedProcess) {
        selectedProcess.typeProcess = this.selectedProcessId;
        this.filteredTypeProcesses = selectedProcess.kanban_processes || [];
        console.log('✅ Procesos tipo cargados:', this.filteredTypeProcesses);

        // Cargar datos del tablero
        this.$nextTick(() => {
          this.loadBoardData();
        });
      } else {
        console.error('❌ No se encontró el proceso con ID:', this.selectedProcessId);
        this.filteredTypeProcesses = [];
      }
    },

    // AÑADIR este método:
    forceHorizontalScroll() {
      this.$nextTick(() => {
        const container = this.$refs.boardContainer;
        if (container) {
          // Forzar recalculo del layout
          container.style.display = 'none';
          container.offsetHeight; // trigger reflow
          container.style.display = '';

          // Log para debug
          console.log('📊 Container info:', {
            scrollWidth: container.scrollWidth,
            clientWidth: container.clientWidth,
            hasScroll: container.scrollWidth > container.clientWidth
          });
        }
      });
    },

    // 🆕 CARGAR DATOS DEL TABLERO
    async loadBoardData() {
      if (!this.selectedProcessId || !this.filteredTypeProcesses.length) {
        console.log('⚠️ No hay proceso seleccionado o columnas disponibles');
        return;
      }

      console.log('🔄 Cargando datos del tablero para proceso:', this.selectedProcessId);

      try {
        // Notificar a las columnas que deben recargar sus datos
        this.$nextTick(() => {
          const columns = this.$refs.kanbanColumns;
          if (columns && columns.length > 0) {
            columns.forEach(column => {
              if (column.refreshConversations) {
                column.refreshConversations();
              }
            });
          }
          // AÑADIR ESTA LÍNEA:
          this.forceHorizontalScroll();
        });
      } catch (error) {
        console.error('❌ Error cargando datos del tablero:', error);
        useAlert('Error al cargar los datos del tablero');
      }
    },

    // 🆕 REFRESCAR DATOS CON FILTROS
    async refreshBoardData() {
      console.log('🔄 Refrescando datos del tablero con filtros:', this.filters);
      await this.loadBoardData();
    },

    // 🆕 CAMBIAR FILTRO DE ASIGNADO
    onAssigneeFilterChange(assigneeId) {
      console.log('🔄 Cambio en filtro de asignado:', assigneeId);
      this.filters.assigneeFilter = assigneeId;
    },

    // 🆕 CAMBIAR FILTRO DE ESTADO
    onStatusFilterChange(status) {
      console.log('🔄 Cambio en filtro de estado:', status);
      this.filters.statusFilter = status;
    },

    // ============ MÉTODOS DE DRAG & DROP ============

    // 🆕 INICIO DE DRAG GLOBAL
    onGlobalDragStart(conversation, sourceColumnId) {
      console.log('🎯 GLOBAL_DRAG_START:', conversation.id, 'from column:', sourceColumnId);
      this.draggedConversation = conversation;
      this.isDragActive = true;
    },

    // 🆕 FIN DE DRAG GLOBAL
    onGlobalDragEnd() {
      console.log('🎯 GLOBAL_DRAG_END');
      this.draggedConversation = null;
      this.isDragActive = false;
      this.dragOverColumn = null;
    },

    // 🆕 DRAG SOBRE COLUMNA
    onColumnDragOver(columnId) {
      if (this.isDragActive) {
        this.dragOverColumn = columnId;
      }
    },

    // 🆕 DRAG SALE DE COLUMNA
    onColumnDragLeave(columnId) {
      if (this.dragOverColumn === columnId) {
        this.dragOverColumn = null;
      }
    },

    // 🆕 DROP EN COLUMNA
    async onColumnDrop(event, targetColumnId) {
      console.log('🎯 COLUMN_DROP en columna:', targetColumnId);

      try {
        const dragDataStr = event.dataTransfer.getData('application/json');
        if (!dragDataStr) {
          console.log('❌ No hay datos de drag');
          return;
        }

        const dragData = JSON.parse(dragDataStr);
        console.log('📦 Datos de drop:', dragData);

        // Verificar que no se está soltando en la misma columna
        if (dragData.sourceColumnId === targetColumnId) {
          console.log('ℹ️ Drop en la misma columna, no se requiere acción');
          return;
        }

        // Actualizar conversación en la base de datos
        await this.updateConversationColumn(
          dragData.conversationId,
          targetColumnId,
          dragData.sourceColumnId
        );

        // Refrescar datos del tablero
        await this.refreshBoardData();

        useAlert('Conversación movida exitosamente');

      } catch (error) {
        console.error('❌ Error en drop:', error);
        useAlert('Error al mover la conversación');
      } finally {
        this.onGlobalDragEnd();
      }
    },

    // 🆕 ACTUALIZAR COLUMNA DE CONVERSACIÓN
    async updateConversationColumn(conversationId, targetColumnId, sourceColumnId) {
      console.log(`🔄 Moviendo conversación ${conversationId} de columna ${sourceColumnId} a ${targetColumnId}`);

      try {
        // Usar la action del store para actualizar
        await this.$store.dispatch('conversations/updateKanbanProcess', {
          conversationId: conversationId,
          kanbanTypeProcessId: this.selectedProcessId,
          kanbanProcessId: targetColumnId,
        });

        console.log('✅ Conversación actualizada en BD');

      } catch (error) {
        console.error('❌ Error actualizando conversación:', error);
        throw error;
      }
    },

    // ============ MÉTODOS DE NAVEGACIÓN DE VISTAS ============

    setActiveViewFromRoute() {
      // Determinar la vista activa basada en la ruta actual
      const routeName = this.$route.name;
      if (routeName === 'kanban_processes') {
        this.activeView = 'management';
      } else {
        this.activeView = 'board';
      }
    },

    switchToManagement() {
      this.activeView = 'management';
      this.$router.push({
        name: 'kanban_processes',
        params: { accountId: this.currentAccountId },
      });
    },

    switchToBoard() {
      this.activeView = 'board';
      this.$router.push({
        name: 'kanban_board',
        params: { accountId: this.currentAccountId },
      });
    },

    // ============ MÉTODOS DE GESTIÓN DE PROCESOS ============

    // Métodos del Tablero Kanban (mantener existentes)
    async loadData() {
      try {
        await this.loadProcesses();
        if (this.kanbanProcesses.length > 0) {
          this.selectedProcessId = this.kanbanProcesses[0].id;
          await this.loadProcess();
        }
      } catch (error) {
        useAlert(this.$t('KANBAN.ERROR.LOADING_DATA'));
      }
    },

    async loadProcesses() {
      await this.$store.dispatch('kanbanProcesses/get');
    },

    async loadProcess() {
      if (this.selectedProcessId) {
        try {
          console.log('🔄 LOAD_PROCESS: Iniciando carga para processId:', this.selectedProcessId);

          const processResult = await this.$store.dispatch(
            'kanbanProcesses/getProcess',
            this.selectedProcessId
          );
          console.log('✅ LOAD_PROCESS: getProcess resultado:', processResult);

          const typeProcessesResult = await this.$store.dispatch(
            'kanbanProcesses/getTypeProcesses',
            this.selectedProcessId
          );
          console.log('✅ LOAD_PROCESS: getTypeProcesses resultado:', typeProcessesResult);

          console.log('🎉 LOAD_PROCESS: Ambas llamadas completadas exitosamente');
        } catch (error) {
          console.error('❌ LOAD_PROCESS: Error durante la carga:', error);
          useAlert(this.$t('KANBAN.ERROR.LOADING_PROCESS'));
        }
      }
    },

    async onProcessChange() {
      await this.loadProcess();
    },

    // Process Management Methods (mantener existentes)
    openCreateProcessModal() {
      this.selectedProcess = null;
      this.showProcessModal = true;
    },

    openEditProcessModal(process) {
      this.selectedProcess = { ...process };
      this.showProcessModal = true;
    },

    closeProcessModal() {
      this.showProcessModal = false;
      this.selectedProcess = null;
    },

    async handleProcessSave(processData) {
      try {
        if (this.selectedProcess) {
          await this.$store.dispatch('kanbanProcesses/update', {
            id: this.selectedProcess.id,
            ...processData,
          });
          useAlert(this.$t('KANBAN.PROCESSES.SUCCESS.UPDATED'));
        } else {
          await this.$store.dispatch('kanbanProcesses/create', processData);
          useAlert(this.$t('KANBAN.PROCESSES.SUCCESS.CREATED'));
        }
        this.closeProcessModal();
      } catch (error) {
        useAlert(this.$t('KANBAN.PROCESSES.ERROR.SAVING'));
      }
    },

    async deleteProcess(process) {
      if (confirm(this.$t('KANBAN.PROCESSES.CONFIRM_DELETE'))) {
        try {
          await this.$store.dispatch('kanbanProcesses/delete', process.id);
          useAlert(this.$t('KANBAN.PROCESSES.SUCCESS.DELETED'));
          if (this.expandedProcessId === process.id) {
            this.expandedProcessId = null;
          }
        } catch (error) {
          useAlert(this.$t('KANBAN.PROCESSES.ERROR.DELETING'));
        }
      }
    },

    // Type Process Management Methods (mantener existentes)
    async toggleProcessExpansion(process) {
      if (this.expandedProcessId === process.id) {
        this.expandedProcessId = null;
      } else {
        this.expandedProcessId = process.id;
        try {
          await this.$store.dispatch('kanbanProcesses/getTypeProcesses', process.id);
        } catch (error) {
          useAlert(this.$t('KANBAN.TYPE_PROCESSES.ERROR.LOADING'));
        }
      }
    },

    openCreateTypeProcessModal(processId) {
      this.selectedTypeProcess = { processId };
      this.showTypeProcessModal = true;
    },

    openEditTypeProcessModal(typeProcess) {
      this.selectedTypeProcess = {
        ...typeProcess,
        processId: this.expandedProcessId,
      };
      this.showTypeProcessModal = true;
    },

    closeTypeProcessModal() {
      this.showTypeProcessModal = false;
      this.selectedTypeProcess = null;
    },

    async handleTypeProcessSave(typeProcessData) {
      try {
        if (this.selectedTypeProcess.id) {
          await this.$store.dispatch('kanbanTypeProcesses/update', {
            kanbanProcessId: this.selectedTypeProcess.processId,
            id: this.selectedTypeProcess.id,
            ...typeProcessData,
          });
          useAlert(this.$t('KANBAN.TYPE_PROCESSES.SUCCESS.UPDATED'));
        } else {
          await this.$store.dispatch('kanbanProcesses/createTypeProcess', {
            processId: this.selectedTypeProcess.processId,
            typeProcessData,
          });
          useAlert(this.$t('KANBAN.TYPE_PROCESSES.SUCCESS.CREATED'));
        }
        this.closeTypeProcessModal();
      } catch (error) {
        useAlert(this.$t('KANBAN.TYPE_PROCESSES.ERROR.SAVING'));
      }
    },

    async deleteTypeProcess(typeProcess) {
      if (typeProcess.is_system) {
        useAlert(this.$t('KANBAN.TYPE_PROCESSES.ERROR.CANNOT_DELETE_SYSTEM'));
        return;
      }

      if (confirm(this.$t('KANBAN.TYPE_PROCESSES.CONFIRM_DELETE'))) {
        try {
          await this.$store.dispatch('kanbanTypeProcesses/delete', {
            kanbanProcessId: this.expandedProcessId,
            id: typeProcess.id,
          });
          useAlert(this.$t('KANBAN.TYPE_PROCESSES.SUCCESS.DELETED'));
        } catch (error) {
          useAlert(this.$t('KANBAN.TYPE_PROCESSES.ERROR.DELETING'));
        }
      }
    },

    async handleReorder(newOrder) {
      try {
        await this.$store.dispatch('kanbanProcesses/bulkReorderTypeProcesses', {
          processId: this.expandedProcessId,
          reorderData: { type_processes: newOrder },
        });
        useAlert(this.$t('KANBAN.TYPE_PROCESSES.SUCCESS.REORDERED'));
      } catch (error) {
        useAlert(this.$t('KANBAN.TYPE_PROCESSES.ERROR.REORDERING'));
      }
    },
  },
};
</script>

<template>
  <div class="flex flex-col h-full w-full bg-slate-50 dark:bg-slate-900">
    <!-- Header con Navegación y Filtros -->
    <div
      class="flex items-center justify-between p-4 bg-white border-b dark:bg-slate-900 border-slate-200 dark:border-slate-700 shadow-sm">
      <div class="flex items-center space-x-4">
        <woot-sidemenu-icon />

        <!-- Título y breadcrumbs - MOVIDO A LA IZQUIERDA -->
        <div class="flex flex-row w-50 ">
          <h1 class="text-xl font-semibold text-slate-900 dark:text-slate-100 pr-3">
            {{ pageTitle }}
          </h1>

          <!-- Breadcrumbs/Filtros aplicados -->
          <div v-if="label || statusFilter || selectedKanbanType" class="flex items-center space-x-2 mt-1">
            <span v-if="label" class="kanban-badge-primary">
              Label: {{ label }}
            </span>
            <span v-if="statusFilter" class="kanban-badge-success">
              Status: {{ statusFilter }}
            </span>
            <span v-if="selectedKanbanType && !label && !statusFilter" class="kanban-badge-purple">
              {{ selectedKanbanType.name }}
            </span>
          </div>
          <woot-button variant="clear" size="small" icon="arrow-clockwise" :is-loading="isLoading"
            @click="refreshBoardData"
            class="text-slate-600 hover:text-slate-800 dark:text-slate-400 dark:hover:text-slate-200 pr-3">
            Actualizar
          </woot-button>
        </div>
      </div>

      <!-- Centro - 🆕 FILTROS AVANZADOS (solo en vista board) -->
      <div v-if="activeView === 'board' && hasData" class="flex items-center space-x-3">
        <!-- Los filtros están comentados en el original -->
      </div>

      <!-- Derecha - Botones de Navegación -->
       <!-- <div class="flex items-center space-x-2">
        <woot-button :variant="activeView === 'board' ? 'solid' : 'clear'"
          :color-scheme="activeView === 'board' ? 'primary' : 'secondary'" icon="kanban-board" size="small"
          @click="switchToBoard">
          {{ $t('KANBAN.BOARD.TITLE') }}
        </woot-button> 
        <woot-button :variant="activeView === 'management' ? 'solid' : 'clear'"
          :color-scheme="activeView === 'management' ? 'primary' : 'secondary'" icon="settings" size="small"
          @click="navigateToKanbanSettings">
          {{ $t('KANBAN.BOARD.MANAGE_PROCESSES') }}
        </woot-button>  
      </div>  -->
    </div>

    <!-- Vista del Tablero Kanban -->
    <div v-if="activeView === 'board'" class="flex-1 flex flex-col overflow-hidden">

      <!-- 🆕 TABLERO KANBAN CON SCROLL WIDTH AUTOMÁTICO -->
      <section class="flex-1 h-full overflow-hidden bg-slate-50 dark:bg-slate-900 kanban-board-wrap">

        <!-- Loading State -->
        <div v-if="isLoading" class="flex items-center justify-center h-full">
          <div class="text-center">
            <div class="kanban-spinner mb-4"></div>
            <span class="text-slate-600 dark:text-slate-400">Cargando tablero...</span>
          </div>
        </div>

        <!-- Empty State - No processes -->
        <div v-else-if="!selectedProcessId || kanbanTypes.length === 0" class="flex items-center justify-center h-full">
          <div class="text-center max-w-md">
            <div class="text-6xl mb-4">📋</div>
            <h3 class="text-lg font-medium text-slate-900 dark:text-slate-100 mb-2">
              {{ $t('KANBAN.BOARD.NO_PROCESSES') }}
            </h3>
            <p class="text-slate-500 dark:text-slate-400 mb-4">
              Para comenzar, necesitas crear al menos un tipo de proceso Kanban.
            </p>
            <woot-button color-scheme="primary" icon="add" @click="switchToManagement">
              {{ $t('KANBAN.BOARD.CREATE_FIRST_PROCESS') }}
            </woot-button>
          </div>
        </div>

        <!-- Empty State - No columns -->
        <div v-else-if="sortedTypeProcesses.length === 0" class="flex items-center justify-center h-full">
          <div class="text-center max-w-md">
            <div class="text-6xl mb-4">📊</div>
            <h3 class="text-lg font-medium text-slate-900 dark:text-slate-100 mb-2">
              {{ $t('KANBAN.BOARD.NO_TYPE_PROCESSES') }}
            </h3>
            <p class="text-slate-500 dark:text-slate-400 mb-4">
              {{ $t('KANBAN.BOARD.ADD_TYPE_PROCESSES_HINT') }}
            </p>
            <woot-button color-scheme="secondary" icon="settings" @click="navigateToKanbanSettings">
              {{ $t('SIDEBAR.NEW_KANBAN_TYPE') }}
            </woot-button>
          </div>
        </div>

        <!-- 🎯 TABLERO KANBAN FIJO CON SCROLL FUNCIONAL -->
        <!-- <div 
          v-else
          style="position: absolute; top: 0; left: 0; right: 0; bottom: 0; background: white; border-radius: 8px; z-index: 1000; box-shadow: 0 4px 20px rgba(0,0,0,0.1); display: flex; flex-direction: column;"
        > -->
        <div v-else
          style="position: absolute; top: 0; left: 0; right: 0; bottom: 0; width: 100%; height: 100%; background: white; border-radius: 8px; z-index: 1000; box-shadow: 0 4px 20px rgba(0,0,0,0.1); display: flex; flex-direction: column; overflow: hidden;">
          <!-- Header del tablero -->
          <!-- <div
            style="padding: 16px 20px; border-bottom: 1px solid #e2e8f0; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); border-radius: 8px 8px 0 0; display: flex; justify-content: space-between; align-items: center;">
            <div style="display: flex; align-items: center; gap: 12px;">
              <span style="font-size: 24px;">📋</span>
              <div>
                <h3 style="margin: 0; font-size: 18px; font-weight: 600; color: white;">
                  Tablero Kanban
                </h3>
                <p style="margin: 0; font-size: 14px; color: rgba(255,255,255,0.8);">
                  {{ sortedTypeProcesses.length }} columnas • Scroll horizontal
                </p>
              </div>
            </div>
            <div style="display: flex; align-items: center; gap: 8px;">
              <woot-button variant="clear" size="small" icon="arrow-clockwise" :is-loading="isLoading"
                @click="refreshBoardData" style="color: white; border-color: rgba(255,255,255,0.3);">
                Actualizar
              </woot-button>
            </div>
          </div> -->

          <!-- 🎯 CONTENIDO DEL KANBAN - LA LÓGICA QUE FUNCIONA -->
          <div style="flex: 1; overflow-x: auto; overflow-y: hidden; padding: 20px; background: #f8fafc;">
            <div style="display: flex; height: 100%; gap: 20px; width: max-content; min-width: 100%;">
              <div v-for="(typeProcess, index) in sortedTypeProcesses" :key="typeProcess.id"
                style="width: 320px; height: 100%; flex-shrink: 0;">
                <KanbanColumn ref="kanbanColumns" :type-process="typeProcess" :process-id="selectedProcessId"
                  :label-filter="filters.labelFilter || label"
                  :status-filter="filters.statusFilter !== 'all' ? filters.statusFilter : (statusFilter || null)"
                  :assignee-filter="filters.assigneeFilter" style="width: 100%; height: 100%;"
                  @drag-start="onGlobalDragStart" @drag-end="onGlobalDragEnd"
                  @card-click="(conversation) => $emit('conversation-select', conversation)" />
              </div>
            </div>
          </div>
        </div>

      </section>

    </div>

    <!-- Vista de Gestión de Procesos -->
    <div v-if="activeView === 'management'" class="flex-1 overflow-auto bg-white dark:bg-slate-900">
      <div class="p-6">
        <!-- Botón Crear Proceso -->
        <div class="mb-6">
          <woot-button color-scheme="primary" icon="add" @click="openCreateProcessModal">
            {{ $t('KANBAN.PROCESSES.ADD_NEW') }}
          </woot-button>
        </div>

        <!-- Loading State -->
        <div v-if="uiFlags.isFetching" class="flex items-center justify-center h-64">
          <div class="text-center">
            <div class="kanban-spinner mb-4"></div>
            <span class="text-slate-600 dark:text-slate-400">Cargando procesos...</span>
          </div>
        </div>

        <!-- Empty State -->
        <div v-else-if="kanbanProcesses.length === 0" class="flex items-center justify-center h-64">
          <div class="text-center">
            <div class="text-6xl mb-4">📋</div>
            <h3 class="text-lg font-medium text-slate-900 dark:text-slate-100 mb-2">
              {{ $t('KANBAN.PROCESSES.NO_RECORDS') }}
            </h3>
            <p class="text-slate-500 dark:text-slate-400 mb-4">
              Crea tu primer proceso Kanban para comenzar a organizar conversaciones.
            </p>
            <woot-button color-scheme="primary" icon="add" @click="openCreateProcessModal">
              {{ $t('KANBAN.PROCESSES.CREATE_FIRST') }}
            </woot-button>
          </div>
        </div>

        <!-- Lista de Procesos -->
        <div v-else class="space-y-4">
          <div v-for="process in kanbanProcesses" :key="process.id"
            class="border rounded-lg border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-800 shadow-sm hover:shadow-md transition-shadow">
            <!-- Process Header -->
            <div class="flex items-center justify-between p-4">
              <div class="flex items-center space-x-3">
                <woot-button variant="clear" size="small"
                  :icon="expandedProcessId === process.id ? 'chevron-down' : 'chevron-right'"
                  @click="toggleProcessExpansion(process)" />
                <div>
                  <h3 class="text-lg font-medium text-slate-900 dark:text-slate-100">
                    {{ process.kanban_process_id }}
                  </h3>
                  <div class="flex items-center mt-1 space-x-4 text-sm text-slate-500 dark:text-slate-400">
                    <span v-if="process.default"
                      class="px-2 py-1 text-xs bg-green-100 text-green-800 rounded-full dark:bg-green-900 dark:text-green-300">
                      {{ $t('KANBAN.PROCESSES.DEFAULT') }}
                    </span>
                    <span v-if="process.is_system"
                      class="px-2 py-1 text-xs bg-blue-100 text-blue-800 rounded-full dark:bg-blue-900 dark:text-blue-300">
                      {{ $t('KANBAN.PROCESSES.SYSTEM') }}
                    </span>
                  </div>
                </div>
              </div>

              <div class="flex items-center space-x-2">
                <woot-button variant="clear" color-scheme="secondary" size="small" icon="edit"
                  @click="openEditProcessModal(process)">
                  {{ $t('KANBAN.PROCESSES.EDIT') }}
                </woot-button>
                <woot-button v-if="!process.is_system" variant="clear" color-scheme="alert" size="small" icon="delete"
                  @click="deleteProcess(process)">
                  {{ $t('KANBAN.PROCESSES.DELETE') }}
                </woot-button>
              </div>
            </div>

            <!-- Type Processes (Expanded) -->
            <div v-if="expandedProcessId === process.id" class="border-t border-slate-200 dark:border-slate-700">
              <div class="p-4 bg-slate-50 dark:bg-slate-900">
                <div class="flex items-center justify-between mb-4">
                  <h4 class="text-sm font-medium text-slate-700 dark:text-slate-300">
                    {{ $t('KANBAN.TYPE_PROCESSES.TITLE') }}
                  </h4>
                  <woot-button size="small" color-scheme="primary" icon="add"
                    @click="openCreateTypeProcessModal(process.id)">
                    {{ $t('KANBAN.TYPE_PROCESSES.ADD_NEW') }}
                  </woot-button>
                </div>

                <div v-if="uiFlags.isFetchingTypeProcesses" class="flex items-center justify-center py-8">
                  <div class="kanban-spinner"></div>
                </div>

                <div v-else-if="currentTypeProcesses.length === 0" class="text-center py-8">
                  <div class="text-4xl mb-2">📊</div>
                  <p class="text-slate-500 dark:text-slate-400 mb-4">
                    {{ $t('KANBAN.TYPE_PROCESSES.NO_RECORDS') }}
                  </p>
                  <woot-button size="small" color-scheme="primary" icon="add"
                    @click="openCreateTypeProcessModal(process.id)">
                    Crear primera columna
                  </woot-button>
                </div>

                <div v-else class="space-y-2">
                  <div v-for="typeProcess in currentTypeProcesses" :key="typeProcess.id"
                    class="flex items-center justify-between p-3 bg-white border rounded-md dark:bg-slate-800 border-slate-200 dark:border-slate-700 hover:bg-slate-50 dark:hover:bg-slate-700 transition-colors">
                    <div class="flex items-center space-x-3">
                      <span class="text-sm text-slate-500 dark:text-slate-400 font-mono">
                        #{{ typeProcess.position }}
                      </span>
                      <div class="flex items-center space-x-2">
                        <div class="w-3 h-3 rounded-full" :style="{ backgroundColor: typeProcess.color || '#6b7280' }">
                        </div>
                        <div>
                          <span class="font-medium text-slate-900 dark:text-slate-100">
                            {{ typeProcess.type_process_name }}
                          </span>
                          <div class="flex items-center mt-1 space-x-2">
                            <span v-if="typeProcess.default"
                              class="px-2 py-0.5 text-xs bg-green-100 text-green-800 rounded dark:bg-green-900 dark:text-green-300">
                              {{ $t('KANBAN.TYPE_PROCESSES.DEFAULT') }}
                            </span>
                            <span v-if="typeProcess.is_system"
                              class="px-2 py-0.5 text-xs bg-blue-100 text-blue-800 rounded dark:bg-blue-900 dark:text-blue-300">
                              {{ $t('KANBAN.TYPE_PROCESSES.SYSTEM') }}
                            </span>
                          </div>
                        </div>
                      </div>
                    </div>

                    <div class="flex items-center space-x-1">
                      <woot-button variant="clear" color-scheme="secondary" size="tiny" icon="edit"
                        @click="openEditTypeProcessModal(typeProcess)" />
                      <woot-button v-if="!typeProcess.is_system" variant="clear" color-scheme="alert" size="tiny"
                        icon="delete" @click="deleteTypeProcess(typeProcess)" />
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Modals -->
    <ProcessModal v-if="showProcessModal" :show="showProcessModal" :process="selectedProcess" @close="closeProcessModal"
      @save="handleProcessSave" />

    <TypeProcessModal v-if="showTypeProcessModal" :show="showTypeProcessModal" :type-process="selectedTypeProcess"
      @close="closeTypeProcessModal" @save="handleTypeProcessSave" />
  </div>
</template>

<style scoped>
/* 🆕 ESTILOS ESPECÍFICOS PARA EL KANBAN BOARD */
.kanban-board-wrap {
  position: relative;
  background-color: #f8fafc;
  height: 100%;
}

.dark .kanban-board-wrap {
  background-color: #0f172a;
}

/* Efectos de drag sobre columnas */
.kanban-ring-active {
  box-shadow: 0 0 0 2px rgba(16, 169, 58, 0.5) !important;
  transition: box-shadow 0.2s ease;
  transform: scale(1.02);
}

/* Estados de foco para accesibilidad */
.kanban-focus:focus {
  outline: none;
  box-shadow: 0 0 0 2px rgba(16, 169, 58, 0.5), 0 0 0 4px rgba(16, 169, 58, 0.2);
}

/* Badges de estado */
.kanban-badge-primary {
  background-color: #dbeafe;
  color: #1e40af;
  padding: 4px 8px;
  border-radius: 9999px;
  font-size: 12px;
  font-weight: 500;
}

.dark .kanban-badge-primary {
  background-color: #1e3a8a;
  color: #93c5fd;
}

.kanban-badge-success {
  background-color: #dcfce7;
  color: #166534;
  padding: 4px 8px;
  border-radius: 9999px;
  font-size: 12px;
  font-weight: 500;
}

.dark .kanban-badge-success {
  background-color: #14532d;
  color: #86efac;
}

.kanban-badge-purple {
  background-color: #f3e8ff;
  color: #7c3aed;
  padding: 4px 8px;
  border-radius: 9999px;
  font-size: 12px;
  font-weight: 500;
}

.dark .kanban-badge-purple {
  background-color: #581c87;
  color: #c4b5fd;
}

/* Loading spinner */
.kanban-spinner {
  width: 32px;
  height: 32px;
  border: 2px solid #f3f3f3;
  border-top: 2px solid #10a93a;
  border-radius: 50%;
  animation: kanban-spin 1s linear infinite;
  margin: 0 auto;
}

@keyframes kanban-spin {
  0% {
    transform: rotate(0deg);
  }

  100% {
    transform: rotate(360deg);
  }
}

/* Focus states para accesibilidad */
button:focus {
  outline: none;
  box-shadow: 0 0 0 2px #10a93a, 0 0 0 4px rgba(16, 169, 58, 0.2);
}

/* Estados hover mejorados */
.hover\:shadow-md:hover {
  box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1), 0 2px 4px -1px rgba(0, 0, 0, 0.06);
}

/* Efectos de depth para el tablero */
.shadow-sm {
  box-shadow: 0 1px 2px 0 rgba(0, 0, 0, 0.05);
}

.shadow-lg {
  box-shadow: 0 10px 15px -3px rgba(0, 0, 0, 0.1), 0 4px 6px -2px rgba(0, 0, 0, 0.05);
}
</style>