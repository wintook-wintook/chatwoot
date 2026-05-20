<!-- 
 /**
 KANBAN0725
 * ConversationAction.vue
 *
 * 📌 Título: Asignaciones y configuración rápida de conversaciones (Sidebar)
 *
 * 🎯 Objetivo:
 * Este componente permite asignar agentes, equipos, prioridades y tipos de proceso Kanban 
 * directamente desde la vista lateral de una conversación en el panel de atención. 
 * Sirve como panel de acción para modificar los metadatos principales de una conversación en tiempo real.
 *
 * 🧩 Funcionalidades principales:
 * - Asignar o desasignar agentes a una conversación.
 * - Asignar o desasignar equipos responsables.
 * - Establecer la prioridad de la conversación (urgente, alta, media, baja, sin prioridad).
 * - Asignar o cambiar el tipo de oportunidad Kanban y su proceso por defecto.
 * - Utiliza listas desplegables personalizadas con búsqueda para mejorar la UX.
 * - Carga dinámica de datos desde el store (Vuex) y sincronización con el estado actual del chat.
 * - Interacción con eventos de analytics y alertas de usuario.
 *
 * 🧠 Reactividad y lógica:
 * - Computed properties reactivas para valores actuales de asignación (`assignedAgent`, `assignedTeam`, `assignedPriority`, `assignedKanbanType`).
 * - Uso de `mapGetters` para acceder a datos globales del store.
 * - Control de carga de procesos Kanban con `loadKanbanProcesses`.
 * - Lógica condicional para evitar conflictos de asignación y revertir cambios en caso de error.
 *
 * 🧪 Composables y herramientas:
 * - `useAgentsList`: Composable para cargar la lista de agentes disponibles.
 * - `useAlert`: Muestra mensajes de éxito o error al usuario.
 * - `mapGetters`: Conexión al store de Vuex.
 * - `MultiselectDropdown`: Componente reutilizable para listas desplegables con búsqueda.
 *
 * 🧩 Componentes usados:
 * - `ContactDetailsItem`: Encabezados compactos para cada sección del sidebar.
 * - `ConversationLabels`: Gestión visual de etiquetas por conversación.
 * - `MultiselectDropdown`: Selector dinámico reutilizable.
 *
 * 🛠️ Autor: [Tu nombre o equipo]
 * 📅 Última modificación: [Fecha]
 */
 -->
<!-- eslint-disable vue/v-slot-style -->
<!-- eslint-disable vue/v-slot-style -->
<script>
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import { useAgentsList } from 'dashboard/composables/useAgentsList';
import messageAPI from 'dashboard/api/inbox/message';
import ContactDetailsItem from './ContactDetailsItem.vue';
import MultiselectDropdown from 'shared/components/ui/MultiselectDropdown.vue';
import ConversationLabels from './labels/LabelBox.vue';
import { CONVERSATION_PRIORITY } from '../../../../shared/constants/messages';
import { CONVERSATION_EVENTS } from '../../../helper/AnalyticsHelper/events';

console.log('🚨 ARCHIVO CARGADO: ConversationAction.vue');

export default {
  components: {
    ContactDetailsItem,
    MultiselectDropdown,
    ConversationLabels,
  },
  props: {
    conversationId: {
      type: [Number, String],
      required: true,
    },
  },
  setup() {
    const { agentsList } = useAgentsList();
    return {
      agentsList,
    };
  },
  data() {
    return {
      priorityOptions: [
        {
          id: null,
          name: this.$t('CONVERSATION.PRIORITY.OPTIONS.NONE'),
          thumbnail: `/assets/images/dashboard/priority/none.svg`,
        },
        {
          id: CONVERSATION_PRIORITY.URGENT,
          name: this.$t('CONVERSATION.PRIORITY.OPTIONS.URGENT'),
          thumbnail: `/assets/images/dashboard/priority/${CONVERSATION_PRIORITY.URGENT}.svg`,
        },
        {
          id: CONVERSATION_PRIORITY.HIGH,
          name: this.$t('CONVERSATION.PRIORITY.OPTIONS.HIGH'),
          thumbnail: `/assets/images/dashboard/priority/${CONVERSATION_PRIORITY.HIGH}.svg`,
        },
        {
          id: CONVERSATION_PRIORITY.MEDIUM,
          name: this.$t('CONVERSATION.PRIORITY.OPTIONS.MEDIUM'),
          thumbnail: `/assets/images/dashboard/priority/${CONVERSATION_PRIORITY.MEDIUM}.svg`,
        },
        {
          id: CONVERSATION_PRIORITY.LOW,
          name: this.$t('CONVERSATION.PRIORITY.OPTIONS.LOW'),
          thumbnail: `/assets/images/dashboard/priority/${CONVERSATION_PRIORITY.LOW}.svg`,
        },
      ],
      loadingKanbanTypes: false,
      kanbanInfo: null,
    };
  },
  computed: {
    ...mapGetters({
      currentChat: 'getSelectedChat',
      currentUser: 'getCurrentUser',
      teams: 'teams/getTeams',
      // ✅ USAR kanbanTypeProcesses para los tipos de proceso Kanban
      kanbanTypeProcesses: 'kanbanTypeProcesses/getKanbanTypeProcesses',
      kanbanTypeProcessesUIFlags: 'kanbanTypeProcesses/getUIFlags',
      currentAccountId: 'getCurrentAccountId',
    }),

    // ✅ OPCIONES PARA EL DROPDOWN de tipos de proceso Kanban
    kanbanTypeOptions() {
      console.log(
        '🔧 Calculando kanbanTypeOptions desde kanbanTypeProcesses:',
        this.kanbanTypeProcesses
      );

      if (
        !Array.isArray(this.kanbanTypeProcesses) ||
        this.kanbanTypeProcesses.length === 0
      ) {
        console.warn('⚠️ kanbanTypeProcesses está vacío');
        return [
          {
            id: null,
            name: 'Sin asignar',
          },
        ];
      }

      const noneOption = {
        id: null,
        name: 'Sin asignar',
      };

      // ✅ MAPEAR desde kanbanTypeProcesses con la estructura correcta
      const dynamicOptions = this.kanbanTypeProcesses.map(
        kanbanTypeProcess => ({
          id: kanbanTypeProcess.id,
          name: kanbanTypeProcess.process_name,
          kanban_processes: kanbanTypeProcess.kanban_processes || [],
        })
      );

      const options = [noneOption, ...dynamicOptions];
      console.log('✅ kanbanTypeOptions finales:', options);

      return options;
    },

    hasAnAssignedTeam() {
      return !!this.currentChat?.meta?.team;
    },
    teamsList() {
      if (this.hasAnAssignedTeam) {
        return [
          { id: 0, name: this.$t('TEAMS_SETTINGS.LIST.NONE') },
          ...this.teams,
        ];
      }
      return this.teams;
    },
    assignedAgent: {
      get() {
        return this.currentChat.meta.assignee;
      },
      set(agent) {
        const agentId = agent ? agent.id : 0;
        this.$store.dispatch('setCurrentChatAssignee', agent);
        this.$store
          .dispatch('assignAgent', {
            conversationId: this.currentChat.id,
            agentId,
          })
          .then(() => {
            useAlert(this.$t('CONVERSATION.CHANGE_AGENT'));
          });
      },
    },
    assignedTeam: {
      get() {
        return this.currentChat.meta.team;
      },
      set(team) {
        const conversationId = this.currentChat.id;
        const teamId = team ? team.id : 0;
        this.$store.dispatch('setCurrentChatTeam', { team, conversationId });
        this.$store
          .dispatch('assignTeam', { conversationId, teamId })
          .then(() => {
            useAlert(this.$t('CONVERSATION.CHANGE_TEAM'));
          });
      },
    },
    assignedPriority: {
      get() {
        const selectedOption = this.priorityOptions.find(
          opt => opt.id === this.currentChat.priority
        );

        return selectedOption || this.priorityOptions[0];
      },
      set(priorityItem) {
        const conversationId = this.currentChat.id;
        const oldValue = this.currentChat?.priority;
        const priority = priorityItem ? priorityItem.id : null;

        this.$store.dispatch('setCurrentChatPriority', {
          priority,
          conversationId,
        });
        this.$store
          .dispatch('assignPriority', { conversationId, priority })
          .then(() => {
            this.$track(CONVERSATION_EVENTS.CHANGE_PRIORITY, {
              oldValue,
              newValue: priority,
              from: 'Conversation Sidebar',
            });
            useAlert(
              this.$t('CONVERSATION.PRIORITY.CHANGE_PRIORITY.SUCCESSFUL', {
                priority: priorityItem.name,
                conversationId,
              })
            );
          });
      },
    },

    // ✅ COMPUTED PROPERTY para Kanban Type
    assignedKanbanType: {
      get() {
        console.log('🔍 assignedKanbanType getter');
        console.log('📊 this.currentChat:', this.currentChat);
        console.log('📊 this.kanbanTypeOptions:', this.kanbanTypeOptions);

        // if (!this.currentChat) {
        //   console.warn('⚠️ currentChat no existe');
        //   return this.kanbanTypeOptions[0]; // Sin asignar
        // }
        if (!this.kanbanInfo || !this.kanbanInfo.kanban_type_process_id) {
          console.warn('⚠️ kanbanInfo no existe o no tiene kanban_type_process_id');
          return this.kanbanTypeOptions[0]; // Sin asignar
        }

        // ✅ BUSCAR el tipo asignado basado en kanban_type_process_id
        const selectedOption = this.kanbanTypeOptions.find(
          opt => opt.id === this.kanbanInfo.kanban_type_process_id
        );
        console.log('selectedOption', selectedOption);

        const defaultProcess = selectedOption.kanban_processes?.find(
          process => process.default === true
        );

        // if defaultProcess === undefined 
        // return false
        // return selectedOption || this.kanbanTypeOptions[0];
        return defaultProcess === undefined ? false : (selectedOption || this.kanbanTypeOptions[0]);
      },
      // set(kanbanTypeItem) {
      //   console.log('🔄 assignedKanbanType setter iniciado');
      //   console.log('📊 kanbanTypeItem:', kanbanTypeItem);
      //   console.log('📊 this.conversationId:', this.conversationId);
      //   console.log('📊 this.currentChat:', this.currentChat);

      //   const conversationId = this.currentChat.display_id;
      //   const oldKanbanTypeProcessId = this.kanbanInfo?.kanban_type_process_id;
      //   const oldKanbanProcessId = this.kanbanInfo?.kanban_process_id;

      //   if (!kanbanTypeItem || kanbanTypeItem.id === null) {
      //     // Sin asignar - enviar null para ambos campos
      //     this.assignKanbanType(
      //       conversationId,
      //       null,
      //       null,
      //       oldKanbanTypeProcessId,
      //       oldKanbanProcessId
      //     );
      //   } else {
      //     // ✅ ENCONTRAR el proceso por defecto en los kanban_processes del tipo seleccionado
      //     const defaultProcess = kanbanTypeItem.kanban_processes?.find(
      //       process => process.default === true
      //     );

      //     if (defaultProcess) {
      //       this.assignKanbanType(
      //         conversationId,
      //         kanbanTypeItem.id,
      //         defaultProcess.id,
      //         oldKanbanTypeProcessId,
      //         oldKanbanProcessId,
      //         kanbanTypeItem.name
      //       );
      //     } else {
      //       // Si no hay proceso por defecto, usar solo el tipo
      //       this.assignKanbanType(
      //         conversationId,
      //         kanbanTypeItem.id,
      //         null,
      //         oldKanbanTypeProcessId,
      //         oldKanbanProcessId,
      //         kanbanTypeItem.name
      //       );
      //     }
      //   }
      // },
      set(kanbanTypeItem) {
        console.log('🔄 assignedKanbanType setter iniciado');

        // ✅ CAMBIO PRINCIPAL: Usar display_id que aparece en la URL
        const conversationId = this.currentChat.id; // ← CAMBIO AQUÍ

        const oldKanbanTypeProcessId = this.kanbanInfo?.kanban_type_process_id;
        const oldKanbanProcessId = this.kanbanInfo?.kanban_process_id;

        if (!kanbanTypeItem || kanbanTypeItem.id === null) {
          // Sin asignar
          this.assignKanbanType(
            conversationId, // ← display_id
            null,
            null,
            oldKanbanTypeProcessId,
            oldKanbanProcessId
          );
        } else {
          // Con tipo asignado
          const defaultProcess = kanbanTypeItem.kanban_processes?.find(
            process => process.default === true
          );

          if (defaultProcess) {
            this.assignKanbanType(
              conversationId, // ← display_id
              kanbanTypeItem.id,
              defaultProcess.id,
              oldKanbanTypeProcessId,
              oldKanbanProcessId,
              kanbanTypeItem.name
            );
          } else {
            useAlert(`Error: @@@@@@@@`);
            // console.log(`$`)
            this.assignKanbanType(
              conversationId, // ← display_id
              kanbanTypeItem.id,
              null,
              oldKanbanTypeProcessId,
              oldKanbanProcessId,
              kanbanTypeItem.name
            );
          }
        }
      },
    },

    showSelfAssign() {
      if (!this.assignedAgent) {
        return true;
      }
      if (this.assignedAgent.id !== this.currentUser.id) {
        return true;
      }
      return false;
    },
  },
  // watch: {
  //   async conversationId() {
  //     console.log("this.currentChat:",this.currentChat)
  //     const kanbanInfo = await this.$store.dispatch(
  //         'kanbanTypeProcesses/getConversationKanbanInfo', 
  //         this.currentChat.id
  //       );
  //     console.log("kanbanInfo:", kanbanInfo)
  //   }
  // },
  watch: {
    async conversationId() {
      console.log("this.currentChat:", this.currentChat)
      const kanbanInfo = await this.$store.dispatch(
        'kanbanTypeProcesses/getConversationKanbanInfo',
        this.currentChat.id
      );
      console.log("kanbanInfo:", kanbanInfo)
      this.kanbanInfo = kanbanInfo; // ✅ ADD THIS LINE
    }
  },

  async mounted() {
    console.log("this.currentChat:", this.currentChat)
    const kanbanInfo = await this.$store.dispatch(
      'kanbanTypeProcesses/getConversationKanbanInfo',
      this.currentChat.id
    );
    console.log("kanbanInfo:", kanbanInfo)
    this.kanbanInfo = kanbanInfo;

    console.log('🔍 MOUNTED: Iniciando carga de tipos kanban...');
    // Si ya tienes la conversación cargada en el store:
    console.log('Kanban Type ID:', this.currentChat.kanban_type_process_id);
    console.log('Kanban Process ID:', this.currentChat.kanban_process_id);
    console.log('📊 Conversación actual:', {
      id: this.currentChat?.id,
      display_id: this.currentChat?.display_id,
      conversation_id: this.currentChat?.id,
    });
    await this.loadKanbanTypeProcesses();
    console.log(
      '📊 MOUNTED: kanbanTypeProcesses cargados:',
      this.kanbanTypeProcesses
    );
    console.log('currentChat:');
    console.log(this.currentChat?.kanban_type_process_id);
    console.log(currentChat);
    const currentChat = this.$store.getters.getSelectedChat;
    this.$store.dispatch('conversations/get', {
      conversationId: currentChat?.id,
    });
    await this.$store.dispatch('conversations/setCurrentChatKanbanType', {
      conversationId,
    });
  },

  methods: {
    // ✅ MÉTODO para cargar los tipos de proceso Kanban
    async loadKanbanTypeProcesses() {
      console.log('🔄 LOAD: === INICIO loadKanbanTypeProcesses ===');
      this.loadingKanbanTypes = true;

      try {
        // Cargar tipos de proceso Kanban
        await this.$store.dispatch('kanbanTypeProcesses/get');
        console.log(
          '✅ LOAD: kanbanTypeProcesses cargados:',
          this.kanbanTypeProcesses
        );
      } catch (error) {
        console.error('❌ LOAD: Error cargando kanbanTypeProcesses:', error);
      } finally {
        this.loadingKanbanTypes = false;
      }
    },

    // ✅ MÉTODO PRINCIPAL: Asignar tipo Kanban (usa la API que funciona)
    async assignKanbanType(
      conversationId,
      kanbanTypeProcessId,
      kanbanProcessId,
      oldKanbanTypeProcessId,
      oldKanbanProcessId,
      typeName = null
    ) {
      try {
        console.log('🔄 ASSIGN: Iniciando asignación de tipo Kanban');
        console.log('📊 ASSIGN: Parámetros:', {
          conversationId,
          kanbanTypeProcessId,
          kanbanProcessId,
          oldKanbanTypeProcessId,
          oldKanbanProcessId,
          typeName,
        });

        if (kanbanProcessId === null && kanbanTypeProcessId != null ) {
            const message_no_default = `🚨🚨🚨  Tipo de oportunidad "${typeName}" no tiene etapa asignado por default...`;
            useAlert(message_no_default);
            return false;
        }
        


        // ==== DEBUG TEMPORAL INI ====================
        // ✅ DEBUG: Verificar que el store tiene las acciones
        console.log('🔍 DEBUG: Verificando store...');
        console.log('📊 DEBUG: this.$store:', this.$store);
        console.log(
          '📊 DEBUG: this.$store._actions:',
          Object.keys(this.$store._actions)
        );

        // if (!kanbanProcessId && kanbanProcessId>0) {
        //   useAlert(`Tipo de oportunidad "${typeName}" no tiene un proceso asignado por default...`);
        //   return;
        // }

        // Buscar acciones de conversations
        const conversationActions = Object.keys(this.$store._actions).filter(
          action => action.includes('conversations/')
        );
        console.log(
          '📊 DEBUG: Acciones de conversations disponibles:',
          conversationActions
        );

        // ✅ PASO 1: Actualizar store local inmediatamente
        console.log('🔄 ASSIGN: PASO 1 - Actualizando store local...');

        // ==== DEBUG TEMPORAL FIN ====================

        // ✅ ACTUALIZAR store local inmediatamente (optimistic update)
        // this.$store.dispatch('conversations/setCurrentChatKanbanType', {
        //   kanbanTypeProcessId,
        //   kanbanProcessId,
        //   conversationId,
        // });
        console.log('🔄 ASSIGN: PASO 1 - Actualizando store local...');

        if (this.$store._actions['conversations/setCurrentChatKanbanType']) {
          await this.$store.dispatch('conversations/setCurrentChatKanbanType', {
            kanbanTypeProcessId,
            kanbanProcessId,
            conversationId,
          });
          console.log('✅ ASSIGN: Store local actualizado');
        } else {
          console.error(
            '❌ ASSIGN: Acción setCurrentChatKanbanType no encontrada'
          );
        }

        // ✅ LLAMAR A LA API QUE FUNCIONA
        // await this.$store.dispatch('conversations/updateKanbanProcess', {
        //   conversationId,
        //   kanban_type_process_id: kanbanTypeProcessId,
        //   kanban_process_id: kanbanProcessId,
        // });
        // ✅ PASO 2: Llamar a la API
        console.log('🔄 ASSIGN: PASO 2 - Llamando a la API...');

        if (this.$store._actions['conversations/updateKanbanProcess']) {
          const result = await this.$store.dispatch(
            'conversations/updateKanbanProcess',
            {
              conversationId,
              kanban_type_process_id: kanbanTypeProcessId,
              kanban_process_id: kanbanProcessId,
            }
          );
          console.log(
            '✅ ASSIGN: API llamada exitosamente, resultado:',
            result
          );
        } else {
          console.error('❌ ASSIGN: Acción updateKanbanProcess no encontrada');

          // ✅ FALLBACK: Llamar directamente a la API si no está en el store
          console.log('🔄 ASSIGN: FALLBACK - Llamando API directamente...');

          const ConversationAPI = (await import('dashboard/api/conversations'))
            .default;
          const response = await ConversationAPI.updateKanbanProcess(
            conversationId,
            {
              kanban_type_process_id: kanbanTypeProcessId,
              kanban_process_id: kanbanProcessId,
            }
          );

          console.log('✅ ASSIGN: API directa exitosa:', response.data);

          // Actualizar manualmente el currentChat
          if (this.currentChat && this.currentChat.id === conversationId) {
            this.currentChat.kanban_type_process_id = kanbanTypeProcessId;
            this.currentChat.kanban_process_id = kanbanProcessId;
            console.log('✅ ASSIGN: currentChat actualizado manualmente');
          }
        }
        // Actualizar kanbanInfo local inmediatamente
        this.kanbanInfo = {
          ...this.kanbanInfo,
          kanban_type_process_id: kanbanTypeProcessId,
          kanban_process_id: kanbanProcessId,
          hasKanbanTypeProcess: kanbanTypeProcessId !== null,
          hasKanbanProcess: kanbanProcessId !== null
        };

        console.log('✅ ASSIGN: kanbanInfo actualizado localmente:', this.kanbanInfo);


         const message = (typeName && kanbanTypeProcessId ) 
            ? `✅✅✅  Tipo de oportunidad "${typeName}" asignado correctamente`
            : '⚠️⚠️⚠️ Tipo de oportunidad desasignado';

            await messageAPI.create({
          conversationId: this.currentChat.id,
          message: message,
          private: true,
          echo_id: null,
          files: null,
        });
        
        useAlert(message);

        console.log('✅ ASSIGN: Asignación completada exitosamente');
      } catch (error) {
        console.error('❌ ASSIGN: Error assigning kanban type:', error);
        useAlert('Error al asignar tipo de oportunidad');

        // ✅ REVERTIR cambios locales en caso de error
        this.$store.dispatch('conversations/setCurrentChatKanbanType', {
          kanbanTypeProcessId: oldKanbanTypeProcessId,
          kanbanProcessId: oldKanbanProcessId,
          conversationId,
        });
      }
    },

    // 3. En los métodos de asignación:
    async clearKanbanAssignment(conversationId) {
      // conversationId ya será display_id
      try {
        console.log('🔄 CLEAR: Limpiando asignación kanban para display_id:', conversationId);

        await this.assignKanbanType(
          conversationId, // ← display_id
          null,
          null,
          this.kanbanInfo?.kanban_type_process_id,
          this.kanbanInfo?.kanban_process_id,
          null
        );

        // Actualizar kanbanInfo local
        this.kanbanInfo = {
          ...this.kanbanInfo,
          kanban_type_process_id: null,
          kanban_process_id: null,
          hasKanbanTypeProcess: false,
          hasKanbanProcess: false
        };

        console.log('✅ CLEAR: Limpieza completada exitosamente');
      } catch (error) {
        console.error('❌ CLEAR: Error:', error);
        useAlert('Error al desasignar tipo de oportunidad');
      }
    },

    // ✅ MÉTODO MEJORADO: Con detección automática de proceso por defecto
    async assignKanbanTypeWithAutoProcess(
      conversationId,
      kanbanTypeProcessId,
      typeName
    ) {
      try {
        console.log('🔄 AUTO: Asignando tipo con proceso automático');

        // Buscar el proceso por defecto del tipo seleccionado
        const selectedType = this.kanbanTypeOptions.find(
          type => type.id === kanbanTypeProcessId
        );
        const defaultProcess = selectedType?.kanban_processes?.find(
          process => process.default === true
        );

        if (defaultProcess) {
          console.log(
            '✅ AUTO: Proceso por defecto encontrado:',
            defaultProcess.type_process_name
          );

          await this.assignKanbanType(
            conversationId,
            kanbanTypeProcessId,
            defaultProcess.id,
            this.kanbanInfo.kanban_type_process_id,
            this.kanbanInfo.kanban_process_id,
            typeName
          );
        } else {
          console.log(
            '⚠️ AUTO: No hay proceso por defecto, asignando solo tipo'
          );

          await this.assignKanbanType(
            conversationId,
            kanbanTypeProcessId,
            null,
            this.kanbanInfo.kanban_type_process_id,
            this.kanbanInfo.kanban_process_id,
            typeName
          );
        }
      } catch (error) {
        console.error('❌ AUTO: Error:', error);
        useAlert('Error al asignar tipo de oportunidad automáticamente');
      }
    },

    // ===== MÉTODOS ORIGINALES MANTENIDOS =====
    onSelfAssign() {
      const {
        account_id,
        availability_status,
        available_name,
        email,
        id,
        name,
        role,
        avatar_url,
      } = this.currentUser;
      const selfAssign = {
        account_id,
        availability_status,
        available_name,
        email,
        id,
        name,
        role,
        thumbnail: avatar_url,
      };
      this.assignedAgent = selfAssign;
    },

    onClickAssignAgent(selectedItem) {
      if (this.assignedAgent && this.assignedAgent.id === selectedItem.id) {
        this.assignedAgent = null;
      } else {
        this.assignedAgent = selectedItem;
      }
    },

    onClickAssignTeam(selectedItemTeam) {
      if (this.assignedTeam && this.assignedTeam.id === selectedItemTeam.id) {
        this.assignedTeam = null;
      } else {
        this.assignedTeam = selectedItemTeam;
      }
    },

    onClickAssignPriority(selectedPriorityItem) {
      const isSamePriority =
        this.assignedPriority &&
        this.assignedPriority.id === selectedPriorityItem.id;

      this.assignedPriority = isSamePriority ? null : selectedPriorityItem;
    },
    // 2. En el método onClickAssignKanbanType:
    onClickAssignKanbanType(selectedKanbanTypeItem) {
      const isSameKanbanType =
        this.assignedKanbanType &&
        this.assignedKanbanType.id === selectedKanbanTypeItem.id;

      if (isSameKanbanType) {
        // Desasignar
        this.clearKanbanAssignment(this.currentChat.id); // ← CAMBIO AQUÍ
      } else {
        // Asignar nuevo tipo
        this.assignKanbanTypeWithAutoProcess(
          this.currentChat.id, // ← CAMBIO AQUÍ
          selectedKanbanTypeItem.id,
          selectedKanbanTypeItem.name
        );
      }
    },
  },
};
</script>

<template>
  <div class="bg-white dark:bg-slate-900">
    <!-- ===== SECCIONES ORIGINALES MANTENIDAS ===== -->
    <!-- ✅ NUEVA SECCIÓN: Selector para Tipo de Proceso Kanban -->
    <div class="multiselect-wrap--small">
      <ContactDetailsItem compact :title="$t('CONVERSATION.KANBAN.TITLE')" />
      <MultiselectDropdown :options="kanbanTypeOptions" :selected-item="assignedKanbanType"
        :multiselector-title="$t('CONVERSATION.KANBAN.SELECTOR')" :multiselector-placeholder="loadingKanbanTypes
          ? 'Cargando tipos de oportunidad...'
          : 'Seleccionar tipo de oportunidad'
          " :no-search-result="$t('CONVERSATION.KANBAN.NOT_FOUND')"
        :input-placeholder="$t('CONVERSATION.KANBAN.SEARCH')" :disabled="loadingKanbanTypes"
        @click="onClickAssignKanbanType" />
    </div>
    <!-- ✅ FIN DE NUEVA SECCIÓN -->
    <!-- ===== SECCIONES ORIGINALES MANTENIDAS ===== -->
    <div class="multiselect-wrap--small">
      <ContactDetailsItem compact :title="$t('CONVERSATION_SIDEBAR.ASSIGNEE_LABEL')">
        <template #button>
          <woot-button v-if="showSelfAssign" icon="arrow-right" variant="link" size="small" @click="onSelfAssign">
            {{ $t('CONVERSATION_SIDEBAR.SELF_ASSIGN') }}
          </woot-button>
        </template>
      </ContactDetailsItem>
      <MultiselectDropdown :options="agentsList" :selected-item="assignedAgent"
        :multiselector-title="$t('AGENT_MGMT.MULTI_SELECTOR.TITLE.AGENT')"
        :multiselector-placeholder="$t('AGENT_MGMT.MULTI_SELECTOR.PLACEHOLDER')" :no-search-result="$t('AGENT_MGMT.MULTI_SELECTOR.SEARCH.NO_RESULTS.AGENT')
          " :input-placeholder="$t('AGENT_MGMT.MULTI_SELECTOR.SEARCH.PLACEHOLDER.AGENT')
            " @click="onClickAssignAgent" />
    </div>
    <div class="multiselect-wrap--small">
      <ContactDetailsItem compact :title="$t('CONVERSATION_SIDEBAR.TEAM_LABEL')" />
      <MultiselectDropdown :options="teamsList" :selected-item="assignedTeam"
        :multiselector-title="$t('AGENT_MGMT.MULTI_SELECTOR.TITLE.TEAM')"
        :multiselector-placeholder="$t('AGENT_MGMT.MULTI_SELECTOR.PLACEHOLDER')" :no-search-result="$t('AGENT_MGMT.MULTI_SELECTOR.SEARCH.NO_RESULTS.TEAM')
          " :input-placeholder="$t('AGENT_MGMT.MULTI_SELECTOR.SEARCH.PLACEHOLDER.INPUT')
            " @click="onClickAssignTeam" />
    </div>
    <div class="multiselect-wrap--small">
      <ContactDetailsItem compact :title="$t('CONVERSATION.PRIORITY.TITLE')" />
      <MultiselectDropdown :options="priorityOptions" :selected-item="assignedPriority"
        :multiselector-title="$t('CONVERSATION.PRIORITY.TITLE')" :multiselector-placeholder="$t('CONVERSATION.PRIORITY.CHANGE_PRIORITY.SELECT_PLACEHOLDER')
          " :no-search-result="$t('CONVERSATION.PRIORITY.CHANGE_PRIORITY.NO_RESULTS')
            " :input-placeholder="$t('CONVERSATION.PRIORITY.CHANGE_PRIORITY.INPUT_PLACEHOLDER')
              " @click="onClickAssignPriority" />
    </div>

    <!-- ✅ NUEVA SECCIÓN: Selector para Tipo de oportunidad Kanban -->
    <!-- <div class="multiselect-wrap--small">
      <ContactDetailsItem compact title="TIPO DE oportunidad" />
      <MultiselectDropdown :options="kanbanTypeOptions" :selected-item="assignedKanbanType"
        multiselector-title="Tipo de oportunidad Kanban" :multiselector-placeholder="loadingKanbanTypes
          ? 'Cargando tipos de proceso...'
          : 'Seleccionar tipo de oportunidad'
          " no-search-result="No se encontraron tipos de proceso" input-placeholder="Buscar tipo de oportunidad..."
        :disabled="loadingKanbanTypes" @click="onClickAssignKanbanType" />
    </div> -->
    <!-- ✅ FIN DE NUEVA SECCIÓN -->

    <!-- ===== SECCIÓN ORIGINAL MANTENIDA ===== -->
    <ContactDetailsItem compact :title="$t('CONVERSATION_SIDEBAR.ACCORDION.CONVERSATION_LABELS')" />
    <ConversationLabels :conversation-id="conversationId" />

  </div>
</template>