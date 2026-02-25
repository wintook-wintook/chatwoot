<!-- Proyecto: DEV0001 -->
<!-- app/javascript/dashboard/components/widgets/conversation/ -->
<template>
  <woot-modal :show.sync="show" :on-close="onClose" size="medium">
    <div class="flex flex-col h-auto overflow-auto max-w-none">
      <woot-modal-header :header-title="$t('CONVERSATION.SCHEDULE_MESSAGE.TITLE')"
        :header-content="$t('CONVERSATION.SCHEDULE_MESSAGE.DESC')" />

      <!-- Estructura de Tabs usando woot-tabs -->
      <div class="w-full flex flex-col">
        <!-- Tab Navigation usando componentes Chatwoot -->
        <woot-tabs class="font-medium [&_.tabs]:p-0 mb-4 px-6" :index="selectedTabIndex" @change="onClickTabChange">
          <woot-tabs-item v-for="tab in tabs" :key="tab.key" :name="tab.name" :show-badge="tab.showBadge"
            :badge-count="tab.badgeCount" />
        </woot-tabs>

        <!-- Tab Content con altura consistente -->
        <div class="px-6 pb-6 flex-1">
          <!-- Contenedor principal con altura mínima fija -->
          <div class="min-h-[480px] flex flex-col">

            <!-- Tab 0: General - Formulario de programación -->
            <div v-show="selectedTabIndex === 0" class="space-y-4 w-full flex-1 flex flex-col">
              <!-- Indicador de modo edición -->
              <div v-if="isEditMode" class="bg-blue-50 border border-blue-200 rounded-md p-4 mb-4">
                <div class="flex items-center">
                  <i class="ri-edit-line text-blue-600 mr-2"></i>
                  <span class="text-sm text-blue-800 font-medium">
                    {{ $t('CONVERSATION.SCHEDULE_MESSAGE.EDITING_MESSAGE') }}
                  </span>
                  <button @click="cancelEdit" class="ml-auto text-blue-600 hover:text-blue-800 text-sm underline">
                    {{ $t('CONVERSATION.SCHEDULE_MESSAGE.CANCEL_EDIT') }}
                  </button>
                </div>
              </div>

              <!-- Indicador de plantilla seleccionada
              <div v-if="selectedTemplate" class="bg-green-50 border border-green-200 rounded-md p-4 mb-4">
                <div class="flex items-center justify-between">
                  <div class="flex items-center">
                    <i class="ri-file-text-line text-green-600 mr-2"></i>
                    <div>
                      <span class="text-sm text-green-800 font-medium">
                        {{ $t('CONVERSATION.SCHEDULE_MESSAGE.TEMPLATE_SELECTED') }}: {{ selectedTemplate.name }}
                      </span>
                      <p class="text-xs text-green-600 mt-1">
                        {{ $t('CONVERSATION.SCHEDULE_MESSAGE.TEMPLATE_LANGUAGE') }}: {{ selectedTemplate.language }}
                      </p>
                    </div>
                  </div>
                  <button @click="clearTemplate" class="text-green-600 hover:text-green-800 text-sm underline">
                    {{ $t('CONVERSATION.SCHEDULE_MESSAGE.CLEAR_TEMPLATE') }}
                  </button>
                </div>
              </div> -->


              <!-- Indicador de plantilla seleccionada -->
              <div v-if="selectedTemplate && !isEditMode"
                class="bg-green-50 border border-green-200 rounded-md p-4 mb-4">
                <div class="flex items-center justify-between">
                  <div class="flex items-center">
                    <i class="ri-file-text-line text-green-600 mr-2"></i>
                    <div>
                      <span class="text-sm text-green-800 font-medium">
                        {{ $t('CONVERSATION.SCHEDULE_MESSAGE.TEMPLATE_SELECTED') }}: {{ selectedTemplate.name }}
                      </span>
                      <p class="text-xs text-green-600 mt-1">
                        {{ $t('CONVERSATION.SCHEDULE_MESSAGE.TEMPLATE_LANGUAGE') }}: {{ selectedTemplate.language }}
                      </p>
                    </div>
                  </div>
                  <button @click="clearTemplate" class="text-green-600 hover:text-green-800 text-sm underline">
                    {{ $t('CONVERSATION.SCHEDULE_MESSAGE.CLEAR_TEMPLATE') }}
                  </button>
                </div>
              </div>

              <!-- Formulario con flex-1 para ocupar espacio disponible -->
              <!-- <form @submit.prevent="saveMessage" class="space-y-3 flex-1 flex flex-col w-full"> -->
              <form @submit.prevent="saveMessage"  class="schedule-form">
                <!-- Selector de tipo de destinatario (deshabilitado si hay plantilla) -->
                <div class="w-full">
                  <label class="block text-sm font-medium text-slate-600 mb-3">
                    {{ $t('CONVERSATION.SCHEDULE_MESSAGE.RECIPIENT_TYPE') }}
                  </label>
                  <div class="grid grid-cols-1 md:grid-cols-2 gap-3">
                    <label
                      class="flex items-start p-3 border border-slate-200 rounded-lg hover:bg-slate-50 cursor-pointer transition-colors"
                      :class="{ 'opacity-100': !selectedTemplate || recipientType === 'contact', 'opacity-50': selectedTemplate && recipientType !== 'contact' }">
                      <input v-model="recipientType" type="radio" value="contact" :disabled="isContactOptionDisabled"
                        class="form-radio h-4 w-4 text-woot-600 transition duration-150 ease-in-out mt-0.5 mr-2 flex-shrink-0">
                      <div class="flex flex-col min-w-0">
                        <span class="text-sm font-medium text-slate-700">
                          {{ $t('CONVERSATION.SCHEDULE_MESSAGE.SEND_TO_CONTACT') }}
                        </span>
                        <span class="text-xs text-slate-500 mt-0.5 leading-tight">
                          {{ $t('CONVERSATION.SCHEDULE_MESSAGE.SEND_TO_CONTACT_DESC') }}
                        </span>
                      </div>
                    </label>
                    <label class="flex items-start p-3 border border-slate-200 rounded-lg transition-colors" :class="{
                      'hover:bg-slate-50 cursor-pointer': !selectedTemplate,
                      'opacity-50 cursor-not-allowed': selectedTemplate,
                      'bg-slate-100': selectedTemplate
                    }">
                      <input v-model="recipientType" type="radio" value="agent" :disabled="isAgentOptionDisabled"
                        class="form-radio h-4 w-4 text-woot-600 transition duration-150 ease-in-out mt-0.5 mr-2 flex-shrink-0"
                        :class="{ 'cursor-not-allowed': selectedTemplate }">
                      <div class="flex flex-col min-w-0">
                        <span class="text-sm font-medium text-slate-700"
                          :class="{ 'text-slate-400': selectedTemplate }">
                          {{ $t('CONVERSATION.SCHEDULE_MESSAGE.SEND_AS_REMINDER') }}
                        </span>
                        <span class="text-xs text-slate-500 mt-0.5 leading-tight"
                          :class="{ 'text-slate-400': selectedTemplate }">
                          {{ selectedTemplate
                            ? $t('CONVERSATION.SCHEDULE_MESSAGE.TEMPLATE_CONTACT_ONLY')
                            : $t('CONVERSATION.SCHEDULE_MESSAGE.SEND_AS_REMINDER_DESC')
                          }}
                        </span>
                      </div>
                    </label>
                  </div>
                </div>

                <!-- Fila con Timezone y Fecha/Hora -->
                <div class="grid grid-cols-1 md:grid-cols-2 gap-3">
                  <!-- Selector de zona horaria -->
                  <div class="w-full">
                    <label class="block text-sm font-medium text-slate-600 mb-2">
                      {{ $t('CONVERSATION.SCHEDULE_MESSAGE.TIMEZONE') }}
                    </label>
                    <multiselect v-model="selectedTimezone" track-by="value" label="label"
                      :placeholder="$t('CONVERSATION.SCHEDULE_MESSAGE.TIMEZONE_PLACEHOLDER')"
                      :select-label="$t('CONVERSATION.SCHEDULE_MESSAGE.TIMEZONE_SELECT')"
                      :deselect-label="$t('CONVERSATION.SCHEDULE_MESSAGE.TIMEZONE_DESELECT')"
                      :custom-label="timezoneNameWithCode" :max-height="160" :options="timezones" allow-empty
                      :option-height="104" />
                  </div>

                  <!-- Campo de fecha y hora programada -->
                  <div>
                    <label class="block text-sm font-medium text-slate-600 mb-2"
                      :class="{ error: v$.scheduledAt.$error }">
                      {{ $t('CONVERSATION.SCHEDULE_MESSAGE.SCHEDULED_AT') }}
                    </label>
                    <WootDateTimePicker :value="scheduledAt" :min-date="new Date()"
                      :confirm-text="$t('CONVERSATION.SCHEDULE_MESSAGE.CONFIRM')"
                      :placeholder="$t('CONVERSATION.SCHEDULE_MESSAGE.SCHEDULED_AT_PLACEHOLDER')" @change="onChange" />
                    <span v-if="v$.scheduledAt.$error" class="text-red-500 text-xs mt-1">
                      {{ $t('CONVERSATION.SCHEDULE_MESSAGE.SCHEDULED_AT_ERROR') }}
                    </span>
                  </div>
                </div>

                <!-- Campo de mensaje con flex-1 para ocupar espacio restante -->
                <div class="editor-wrap flex-1 flex flex-col">
                  <label class="block text-sm font-medium text-slate-600 mb-2">
                    {{ selectedTemplate
                      ? $t('CONVERSATION.SCHEDULE_MESSAGE.TEMPLATE_CONTENT')
                      : $t('CONVERSATION.SCHEDULE_MESSAGE.MESSAGE')
                    }}
                  </label>

                  <!-- Template content (read-only) -->
                  <div v-if="selectedTemplate" class="flex-1 flex flex-col">
                    <div class="template-content-display">
                      <textarea v-model="processedTemplateString" rows="6" readonly class="template-input w-full"
                        :placeholder="$t('CONVERSATION.SCHEDULE_MESSAGE.TEMPLATE_PROCESSING')" />

                      <!-- Template variables -->
                      <div v-if="templateVariables && templateVariables.length > 0"
                        class="template__variables-container mt-4">
                        <p class="variables-label text-sm font-medium text-slate-600 mb-3">
                          {{ $t('CONVERSATION.SCHEDULE_MESSAGE.TEMPLATE_VARIABLES') }}
                        </p>
                        <div v-for="(variable, key) in templateParams" :key="key" class="template__variable-item mb-3">
                          <span class="variable-label">
                            {{ key }}
                          </span>
                          <woot-input v-model="templateParams[key]" type="text" class="variable-input"
                            :styles="{ marginBottom: 0 }"
                            :placeholder="`${$t('CONVERSATION.SCHEDULE_MESSAGE.ENTER_VALUE_FOR')} ${key}`" />
                        </div>
                      </div>
                    </div>
                  </div>

                  <!-- Regular message editor -->
                  <div v-else class="flex-1 flex flex-col">
                    <WootMessageEditor v-model="message" class="message-editor flex-1"
                      :class="{ editor_warning: v$.message.$error }" :placeholder="getMessagePlaceholder()"
                      @blur="v$.message.$touch" />
                    <span v-if="v$.message.$error" class="editor-warning__message">
                      {{ $t('CONVERSATION.SCHEDULE_MESSAGE.MESSAGE_ERROR') }}
                    </span>
                  </div>
                </div>

                <!-- Botones de acción - siempre al final -->
                <div class="flex justify-end space-x-2 pt-4 border-t border-slate-200 mt-auto">
                  <woot-button variant="clear" @click.prevent="isEditMode ? cancelEdit() : onClose()">
                    {{ $t('CONVERSATION.SCHEDULE_MESSAGE.CANCEL') }}
                  </woot-button>
                  <woot-button :disabled="isSubmitDisabled" :is-loading="isCreating" type="submit">
                    {{ isEditMode ? $t('CONVERSATION.SCHEDULE_MESSAGE.UPDATE_MESSAGE') : getConfirmButtonText() }}
                  </woot-button>
                </div>
              </form>
            </div>

            <!-- Tab 1: Plantillas (solo visible si hay plantillas disponibles) -->
            <div v-show="selectedTabIndex === 1" class="space-y-4 flex-1 flex flex-col min-h-[480px]">
              <!-- Búsqueda de plantillas -->
              <div class="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-3 flex-shrink-0">
                <div class="w-full sm:w-80">
                  <div class="gap-1 templates__list-search">
                    <i class="ri-search-line search-icon"></i>
                    <input v-model="templateQuery" type="search"
                      :placeholder="$t('CONVERSATION.SCHEDULE_MESSAGE.SEARCH_TEMPLATES')"
                      class="templates__search-input" />
                  </div>
                </div>
              </div>

              <!-- Lista de plantillas -->
              <div class="template__list-container flex-1">
                <div v-if="filteredTemplates.length > 0" class="space-y-3">
                  <div v-for="(template) in filteredTemplates" :key="template.id" class="template__list-item"
                    @dblclick="selectTemplate(template)">
                    <div class="template-card">
                      <div class="flex items-center justify-between mb-2.5">
                        <p class="label-title font-medium text-slate-800">
                          {{ template.name }}
                        </p>
                        <div class="flex space-x-2">
                          <span class="template-badge template-badge--language">
                            {{ template.language }}
                          </span>
                          <span class="template-badge template-badge--category">
                            {{ template.category }}
                          </span>
                        </div>
                      </div>
                      <div class="template-content">
                        <p class="template-body">
                          {{ getTemplateBody(template) }}
                        </p>
                      </div>
                      <div class="template-hint">
                        <i class="ri-information-line text-woot-600 mr-1"></i>
                        <span class="text-xs text-slate-500">
                          {{ $t('CONVERSATION.SCHEDULE_MESSAGE.DOUBLE_CLICK_TO_SELECT') }}
                        </span>
                      </div>
                    </div>
                  </div>
                </div>

                <div v-else-if="availableTemplates.length === 0" class="flex items-center justify-center h-64">
                  <EmptyState :title="$t('CONVERSATION.SCHEDULE_MESSAGE.NO_TEMPLATES_AVAILABLE')"
                    :sub-title="$t('CONVERSATION.SCHEDULE_MESSAGE.NO_TEMPLATES_SUBTITLE')" />
                </div>

                <div v-else class="flex items-center justify-center h-64">
                  <EmptyState :title="$t('CONVERSATION.SCHEDULE_MESSAGE.NO_TEMPLATES_FOUND')"
                    :sub-title="`${$t('CONVERSATION.SCHEDULE_MESSAGE.SEARCH_TERM')}: ${templateQuery}`" />
                </div>
              </div>
            </div>

            <!-- Tab 2: Control de Mensajes con altura consistente -->
            <div v-show="selectedTabIndex === 2" class="space-y-4 flex-1 flex flex-col min-h-[480px]">
              <!-- Filtros -->
              <div class="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-3 flex-shrink-0">
                <div class="flex flex-col sm:flex-row space-x-0 sm:space-x-2 space-y-2 sm:space-y-0">
                  <select v-model="messageFilter" @change="loadScheduledMessages"
                    class="block w-full sm:w-40 px-3 py-2 border border-slate-300 rounded-md shadow-sm focus:outline-none focus:ring-woot-500 focus:border-woot-500 sm:text-sm">
                    <option value="all">{{ $t('CONVERSATION.SCHEDULE_MESSAGE.ALL_MESSAGES') }}</option>
                    <option value="pending">{{ $t('CONVERSATION.SCHEDULE_MESSAGE.PENDING_MESSAGES') }}</option>
                    <option value="sent">{{ $t('CONVERSATION.SCHEDULE_MESSAGE.SENT_MESSAGES') }}</option>
                  </select>
                  <select v-model="recipientFilter" @change="loadScheduledMessages"
                    class="block w-full sm:w-40 px-3 py-2 border border-slate-300 rounded-md shadow-sm focus:outline-none focus:ring-woot-500 focus:border-woot-500 sm:text-sm">
                    <option value="all">{{ $t('CONVERSATION.SCHEDULE_MESSAGE.ALL_RECIPIENTS') }}</option>
                    <option value="outgoing">{{ $t('CONVERSATION.SCHEDULE_MESSAGE.CONTACT_ONLY') }}</option>
                    <option value="private">{{ $t('CONVERSATION.SCHEDULE_MESSAGE.AGENT_ONLY') }}</option>
                  </select>
                </div>
                <button @click="loadScheduledMessages"
                  class="px-3 py-2 text-sm bg-slate-100 hover:bg-slate-200 rounded-md transition-colors w-full sm:w-auto flex-shrink-0">
                  <i class="ri-refresh-line mr-1"></i>
                  {{ $t('CONVERSATION.SCHEDULE_MESSAGE.REFRESH') }}
                </button>
              </div>

              <!-- Tabla de mensajes programados con altura fija -->
              <div class="scheduled-messages-table-wrap flex-1 flex flex-col">
                <!-- Tabla con altura fija para mantener consistencia -->
                <div class="flex-1 min-h-[380px]">
                  <VeTable fixed-header :max-height="tableMaxHeight" :columns="tableColumns"
                    :table-data="paginatedMessages" :border-around="false" :page-option="pageOption"
                    @on-page-number-change="onPageNumberChange" @on-page-size-change="onPageSizeChange" />

                  <!-- Estados vacíos/carga con posicionamiento absoluto o centrado -->
                  <div v-if="!isLoadingMessages && filteredMessages.length === 0"
                    class="flex items-center justify-center h-64">
                    <EmptyState :title="$t('CONVERSATION.SCHEDULE_MESSAGE.NO_MESSAGES')"
                      :sub-title="$t('CONVERSATION.SCHEDULE_MESSAGE.NO_MESSAGES_SUBTITLE')" />
                  </div>

                  <div v-if="isLoadingMessages" class="flex items-center justify-center h-64">
                    <div class="inline-block animate-spin rounded-full h-6 w-6 border-b-2 border-woot-600 mr-3"></div>
                    <span>{{ $t('CONVERSATION.SCHEDULE_MESSAGE.LOADING_MESSAGES') }}</span>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </woot-modal>
</template>

<script>
import { useVuelidate } from '@vuelidate/core';
import { required } from '@vuelidate/validators';
import { useAlert } from 'dashboard/composables';
import WootMessageEditor from 'dashboard/components/widgets/WootWriter/Editor.vue';
import WootDateTimePicker from 'dashboard/components/ui/DateTimePicker.vue';
import Multiselect from 'vue-multiselect';
import { VeTable } from 'vue-easytable';
import EmptyState from 'dashboard/components/widgets/EmptyState.vue';
import { mapActions, mapGetters } from 'vuex';
import messageAPI from 'dashboard/api/inbox/message';
import scheduledMessagesAPI from 'dashboard/api/scheduledMessages';
import timeZoneData from './timezones.json';

// TODO: Remove this when we support all formats
const formatsToRemove = ['DOCUMENT', 'IMAGE', 'VIDEO'];

export default {
  components: {
    WootDateTimePicker,
    WootMessageEditor,
    Multiselect,
    VeTable,
    EmptyState,
  },
  props: {
    show: {
      type: Boolean,
      default: false,
    },
    conversationId: {
      type: [Number, String],
      required: true,
    },
    currentUser: {
      type: Object,
      default: () => ({}),
    },
    currentChat: {
      type: Object,
      default: () => ({}),
    },
    inboxId: {
      type: Number,
      required: true,
    },
  },
  setup() {
    return { v$: useVuelidate() };
  },
  data() {
    return {
      // Tab management usando el patrón de Chatwoot
      selectedTabIndex: 0,

      // Form data
      message: '',
      scheduledAt: null,
      recipientType: 'contact',
      selectedTimezone: {
        value: 'UTC',
        label: 'UTC',
      },
      timezones: [],

      // Template data
      selectedTemplate: null,
      templateParams: {},
      templateQuery: '',

      // Edit mode
      isEditMode: false,
      editingMessageId: null,

      // Messages management
      scheduledMessages: [],
      isLoadingMessages: false,
      messageFilter: 'all', // all, pending, sent
      recipientFilter: 'all', // all, contact, agent

      // Pagination
      currentPage: 1,
      pageSize: 5,
    };
  },
  // validations() {
  //   return {
  //     message: {
  //       required: (value) => {
  //         // Si hay una plantilla seleccionada, no requerir mensaje manual
  //         return this.selectedTemplate ? true : required(value);
  //       },
  //     },
  //     scheduledAt: {
  //       required,
  //     },
  //     recipientType: {
  //       required,
  //     },
  //   };
  // },
  validations() {
    return {
      message: {
        required: (value) => {
          // Si hay una plantilla seleccionada, no requerir mensaje manual
          if (this.selectedTemplate) return true;

          // Verificar que hay contenido real (no solo HTML vacío)
          if (!value) return false;

          // Extraer texto sin HTML
          const tempDiv = document.createElement('div');
          tempDiv.innerHTML = value;
          const textContent = (tempDiv.textContent || tempDiv.innerText || '').trim();

          return textContent.length > 0;
        },
      },
      scheduledAt: {
        required,
      },
      recipientType: {
        required,
      },
    };
  },

  computed: {
    ...mapGetters({
      uiFlags: 'scheduledMessages/getUIFlags',
    }),

    // En el computed o methods de ScheduleMessageModal.vue
    get messageContent() {
      if (!this.message) return '';

      // Si el mensaje contiene HTML, extraer solo el texto
      const tempDiv = document.createElement('div');
      tempDiv.innerHTML = this.message;
      return tempDiv.textContent || tempDiv.innerText || '';
    },

    // Altura máxima calculada para la tabla
    tableMaxHeight() {
      return '380px';
    },

    // Lógicas para deshabilitar opciones de destinatario
    isContactOptionDisabled() {
      return false; // La opción de contacto nunca se deshabilita
    },

    isAgentOptionDisabled() {
      return !!this.selectedTemplate; // Deshabilitar si hay plantilla seleccionada
    },

    // Plantillas disponibles (similar a TemplatesPicker.vue)
    availableTemplates() {
      if (!this.inboxId) return [];

      return this.$store.getters['inboxes/getWhatsAppTemplates'](this.inboxId)
        .filter(template => template.status.toLowerCase() === 'approved')
        .filter(template => {
          return template.components.every(component => {
            return !formatsToRemove.includes(component.format);
          });
        });
    },

    // Plantillas filtradas por búsqueda
    filteredTemplates() {
      return this.availableTemplates.filter(template =>
        template.name.toLowerCase().includes(this.templateQuery.toLowerCase())
      );
    },

    // Variables de la plantilla seleccionada
    templateVariables() {
      if (!this.selectedTemplate) return null;
      const templateString = this.getTemplateBody(this.selectedTemplate);
      if (!templateString) return null;
      return templateString.match(/\{\{([^}]+)\}\}/g);
    },

    // String procesado de la plantilla
    processedTemplateString() {
      if (!this.selectedTemplate) return '';

      let templateString = this.getTemplateBody(this.selectedTemplate);
      if (!templateString) return '';

      return templateString.replace(/\{\{([^}]+)\}\}/g, (match, variable) => {
        const variableKey = this.processVariable(variable);
        return this.templateParams[variableKey] || match;
      });
    },

    // Definir tabs usando el patrón de Chatwoot
    tabs() {
      const baseTabs = [
        {
          key: 0,
          name: this.$t('CONVERSATION.SCHEDULE_MESSAGE.GENERAL'),
          showBadge: false,
          badgeCount: 0,
        },
      ];

      // Solo mostrar tab de plantillas si hay plantillas disponibles
      if (this.availableTemplates.length > 0) {
        baseTabs.push({
          key: 1,
          name: this.$t('CONVERSATION.SCHEDULE_MESSAGE.TEMPLATES'),
          showBadge: false,
          badgeCount: 0,
        });
      }

      baseTabs.push({
        key: this.availableTemplates.length > 0 ? 2 : 1,
        name: this.$t('CONVERSATION.SCHEDULE_MESSAGE.CONTROL_MESSAGES'),
        // showBadge: this.pendingMessagesCount > 0,
        showBadge: false,
        badgeCount: this.pendingMessagesCount,
      });

      return baseTabs;
    },

    isSubmitDisabled() {
      const baseValidation = !this.scheduledAt || !this.recipientType || this.isCreating;

      if (this.selectedTemplate) {
        // Para plantillas, verificar que todas las variables estén llenas
        if (this.templateVariables && this.templateVariables.length > 0) {
          const allVariablesFilled = Object.keys(this.templateParams).every(key =>
            this.templateParams[key] && this.templateParams[key].trim() !== ''
          );
          return baseValidation || !allVariablesFilled;
        }
        return baseValidation;
      }

      // Para mensajes normales
      return baseValidation || !this.message;
    },

    isCreating() {
      return this.uiFlags.isCreating;
    },

    filteredMessages() {
      let messages = [...this.scheduledMessages];

      // Filter by status
      if (this.messageFilter === 'pending') {
        messages = messages.filter(msg => !msg.sent);
      } else if (this.messageFilter === 'sent') {
        messages = messages.filter(msg => msg.sent);
      }

      // Filter by recipient type
      // if (this.recipientFilter !== 'all') {
      //   messages = messages.filter(msg => msg.message_type === this.recipientFilter);
      // }

      // Filtrar por tipo de destinatario
      if (this.recipientFilter !== 'all') {
        messages = messages.filter(msg => {
          if (this.recipientFilter === 'outgoing') {
            return msg.message_type === 'outgoing' || msg.message_type === 'template';
          }
          return msg.message_type === this.recipientFilter;
        });
      }

      // Sort by scheduled_at (most recent first)
      return messages.sort((a, b) => new Date(b.scheduled_at) - new Date(a.scheduled_at));
    },

    pendingMessagesCount() {
      return this.scheduledMessages.filter(msg => !msg.sent).length;
    },

    // Configuración de paginación para VeTable 
    pageOption() {
      return {
        show: this.filteredMessages.length > this.pageSize,
        pageSizeOption: [5, 10, 20],
        pageCount: Math.ceil(this.filteredMessages.length / this.pageSize),
        pageIndex: this.currentPage,
        pageSize: this.pageSize,
      };
    },

    // Mensajes paginados para mostrar en la tabla
    paginatedMessages() {
      if (this.isLoadingMessages || this.filteredMessages.length === 0) {
        return [];
      }

      const start = (this.currentPage - 1) * this.pageSize;
      const end = start + this.pageSize;
      return this.filteredMessages.slice(start, end);
    },

    // Definición de columnas para VeTable
    tableColumns() {
      return [
        {
          field: 'recipient_type',
          key: 'recipient_type',
          title: this.$t('CONVERSATION.SCHEDULE_MESSAGE.TYPE'),
          align: 'left',
          width: 120,
          renderBodyCell: ({ row }) => (
            <span
              class={[
                'inline-flex px-2 py-1 text-xs font-semibold rounded-full items-center',
                row.recipient_type === 'contact'
                  ? 'recipient-badge recipient-badge--contact'
                  : 'recipient-badge recipient-badge--agent'
              ]}
            >
              <i class={[
                'mr-1',
                row.recipient_type === 'contact' ? 'ri-user-line' : 'ri-notification-line'
              ]}></i>
              {row.recipient_type === 'contact'
                ? this.$t('CONVERSATION.SCHEDULE_MESSAGE.CONTACT')
                : this.$t('CONVERSATION.SCHEDULE_MESSAGE.REMINDER')
              }
            </span>
          ),
        },
        {
          field: 'content',
          key: 'content',
          title: this.$t('CONVERSATION.SCHEDULE_MESSAGE.MESSAGE_CONTENT'),
          align: 'left',
          width: 250,
          renderBodyCell: ({ row }) => (
            <div class="flex flex-col">
              <div
                class="text-sm text-slate-900 truncate cursor-help"
                title={row.content}
                style="max-width: 230px;"
              >
                {row.content}
              </div>
              {row.template_name && (
                <span class="template-indicator">
                  <i class="ri-file-text-line mr-1"></i>
                  {row.template_name}
                </span>
              )}
            </div>
          ),
        },
        {
          field: 'scheduled_at',
          key: 'scheduled_at',
          title: this.$t('CONVERSATION.SCHEDULE_MESSAGE.SCHEDULED_FOR'),
          align: 'left',
          width: 160,
          renderBodyCell: ({ row }) => (
            <span class="text-sm text-slate-500">
              {this.formatDate(row.scheduled_at)}
            </span>
          ),
        },
        {
          field: 'sent',
          key: 'sent',
          title: this.$t('CONVERSATION.SCHEDULE_MESSAGE.STATUS'),
          align: 'left',
          width: 100,
          renderBodyCell: ({ row }) => (
            <span
              class={[
                'inline-flex px-2 py-1 text-xs font-semibold rounded-full',
                row.sent
                  ? 'status-badge status-badge--sent'
                  : 'status-badge status-badge--pending'
              ]}
            >
              {row.sent
                ? this.$t('CONVERSATION.SCHEDULE_MESSAGE.SENT')
                : this.$t('CONVERSATION.SCHEDULE_MESSAGE.PENDING')
              }
            </span>
          ),
        },


        // Solución definitiva para la columna actions - NO más "undefined"
        {
          field: 'actions',
          key: 'actions',
          title: this.$t('CONVERSATION.SCHEDULE_MESSAGE.ACTIONS'),
          align: 'right',
          width: 120,
          renderBodyCell: ({ row, column, rowIndex }) => {
            // Determinar estado del mensaje
            const isSent = row.sent || row.is_sent || row.status === 'sent' ||
              row.status === 'enviado' || row.delivered_at;
            const isPending = !isSent;

            // IMPORTANTE: Usar Vue's h function o retornar JSX válido
            // Opción 1: Retornar JSX válido (recomendado)
            if (isPending) {
              return (
                <div style="display: flex; justify-content: flex-end; gap: 8px; align-items: center;">
                  <button
                    style="padding: 4px 8px; background-color: #3b82f6; color: white; border: none; border-radius: 4px; cursor: pointer; font-size: 10px;"
                    title={this.$t('CONVERSATION.SCHEDULE_MESSAGE.EDIT')}
                    onClick={(e) => {
                      e.stopPropagation();
                      e.preventDefault();
                      this.editMessage(row);
                    }}
                    onMouseover={(e) => e.target.style.backgroundColor = '#2563eb'}
                    onMouseout={(e) => e.target.style.backgroundColor = '#3b82f6'}
                  >
                    <i class="ri-edit-line">{this.$t('CONVERSATION.SCHEDULE_MESSAGE.EDIT')}</i>
                  </button>
                  <button
                    style="padding: 4px 8px; background-color: #ef4444; color: white; border: none; border-radius: 4px; cursor: pointer; font-size: 10px;"
                    title={this.$t('CONVERSATION.SCHEDULE_MESSAGE.DELETE')}
                    onClick={(e) => {
                      e.stopPropagation();
                      e.preventDefault();
                      this.deleteMessage(row);
                    }}
                    onMouseover={(e) => e.target.style.backgroundColor = '#dc2626'}
                    onMouseout={(e) => e.target.style.backgroundColor = '#ef4444'}
                  >
                    <i class="ri-delete-bin-line">{this.$t('CONVERSATION.SCHEDULE_MESSAGE.DELETE')}</i>
                  </button>
                </div>
              );
            } else {
              return (
                <div style="display: flex; justify-content: flex-end; align-items: center;">
                  <span
                    style="color: #16a34a; font-size: 16px; padding: 4px 8px;"
                    title={this.$t('CONVERSATION.SCHEDULE_MESSAGE.SENT')}
                  >
                    <i class="ri-check-line"></i>
                  </span>
                </div>
              );
            }
          },
        }

        // ALTERNATIVA - Si la anterior no funciona, usa esta versión más simple:
        /*
        {
          field: 'actions',
          key: 'actions',
          title: this.$t('CONVERSATION.SCHEDULE_MESSAGE.ACTIONS'),
          align: 'right',
          width: 120,
          renderBodyCell: ({ row }) => {
            const isSent = row.sent || row.is_sent || row.status === 'sent' || 
                           row.status === 'enviado' || row.delivered_at;
            const isPending = !isSent;
            
            if (isPending) {
              return `
                <div style="display: flex; justify-content: flex-end; gap: 6px;">
                  <button onclick="editMsg_${row.id}()" 
                          style="padding: 4px 8px; background: #3b82f6; color: white; border: none; border-radius: 4px; cursor: pointer;"
                          title="Editar">
                    <i class="ri-edit-line"></i>
                  </button>
                  <button onclick="deleteMsg_${row.id}()" 
                          style="padding: 4px 8px; background: #ef4444; color: white; border: none; border-radius: 4px; cursor: pointer;"
                          title="Eliminar">
                    <i class="ri-delete-bin-line"></i>
                  </button>
                </div>
              `;
            } else {
              return `
                <div style="display: flex; justify-content: flex-end;">
                  <span style="color: #16a34a; font-size: 16px;" title="Enviado">
                    <i class="ri-check-line"></i>
                  </span>
                </div>
              `;
            }
          },
        }
        */
      ];
    },
  },
  watch: {
    show(newVal) {
      if (newVal) {
        this.detectUserTimezone();
        this.loadScheduledMessages();
      } else {
        this.resetForm();
      }
    },

    // Cuando se selecciona una plantilla, forzar destinatario a contacto
    selectedTemplate(newTemplate) {
      if (newTemplate) {
        this.recipientType = 'contact';
        this.generateTemplateVariables();
      } else {
        this.templateParams = {};
      }
    }
  },
  mounted() {
    this.timezones = Object.keys(timeZoneData).map(key => ({
      label: key,
      value: timeZoneData[key],
    }));

    this.detectUserTimezone();

    window.editMessageHandler = (id) => {
      const message = this.scheduledMessages.find(m => m.id === id);
      this.editMessage(message);
    };

    window.deleteMessageHandler = (id) => {
      const message = this.scheduledMessages.find(m => m.id === id);
      this.deleteMessage(message);
    };

  },
  methods: {
    ...mapActions('scheduledMessages', ['create', 'update', 'delete']),

    // Tab management
    onClickTabChange(index) {
      // Ajustar índice si no hay plantillas disponibles
      if (this.availableTemplates.length === 0 && index >= 1) {
        this.selectedTabIndex = index + 1;
      } else {
        this.selectedTabIndex = index;
      }
      // // console...log(index)
    },

    // Template methods (basados en TemplatesPicker.vue y TemplateParser.vue)
    getTemplateBody(template) {
      if (!template || !template.components) return '';
      const bodyComponent = template.components.find(component => component.type === 'BODY');
      return bodyComponent?.text || '';
    },

    selectTemplate(template) {
      this.selectedTemplate = template;
      this.selectedTabIndex = 0; // Volver al tab General
      useAlert(this.$t('CONVERSATION.SCHEDULE_MESSAGE.TEMPLATE_SELECTED_SUCCESS', { name: template.name }));
    },

    clearTemplate() {
      this.selectedTemplate = null;
      this.templateParams = {};
    },

    processVariable(str) {
      return str.replace(/\{\{|\}\}/g, '').trim();
    },

    generateTemplateVariables() {
      if (!this.selectedTemplate) return;

      const templateString = this.getTemplateBody(this.selectedTemplate);
      if (!templateString) {
        this.templateParams = {};
        return;
      }

      const matchedVariables = templateString.match(/\{\{([^}]+)\}\}/g);

      if (!matchedVariables) {
        this.templateParams = {};
        return;
      }

      const finalVars = matchedVariables.map(i => this.processVariable(i));
      this.templateParams = finalVars.reduce((acc, variable) => {
        acc[variable] = '';
        return acc;
      }, {});
    },

    // Pagination handlers
    onPageNumberChange(pageNumber) {
      this.currentPage = pageNumber;
    },

    onPageSizeChange(pageSize) {
      this.pageSize = pageSize;
      this.currentPage = 1;
    },

    // Load scheduled messages
    async loadScheduledMessages() {
      this.isLoadingMessages = true;
      this.currentPage = 1;

      try {
        const response = await scheduledMessagesAPI.get(this.conversationId);
        this.scheduledMessages = response.data || [];
      } catch (error) {
        // // console...error('Error loading scheduled messages:', error);
        useAlert(this.$t('CONVERSATION.SCHEDULE_MESSAGE.ERROR_LOADING'));
      } finally {
        this.isLoadingMessages = false;
      }
    },

    // Edit message
    // editMessage(message) {
    //   this.isEditMode = true;
    //   this.editingMessageId = message.id;

    //   // Load message data into form
    //   this.message = message.content;
    //   this.scheduledAt = new Date(message.scheduled_at);
    //   this.recipientType = message.recipient_type || 'contact';

    //   // If it's a template message, load template data
    //   if (message.template_name) {
    //     const template = this.availableTemplates.find(t => t.name === message.template_name);
    //     if (template) {
    //       this.selectedTemplate = template;
    //       this.templateParams = message.template_params || {};
    //     }
    //   }

    //   this.selectedTabIndex = 0;
    // },

    // Método editMessage actualizado
    // editMessage(message) {
    //   this.isEditMode = true;
    //   this.editingMessageId = message.id;

    //   // Load message data into form
    //   this.scheduledAt = new Date(message.scheduled_at);
    //   this.recipientType = message.recipient_type || 'contact';

    //   // If it's a template message, load template data
    //   if (message.is_template && message.template_name) {
    //     const template = this.availableTemplates.find(t => t.name === message.template_name);
    //     if (template) {
    //       this.selectedTemplate = template;
    //       this.templateParams = message.template_params || {};
    //     } else {
    //       // Fallback para plantillas que ya no existen
    //       this.message = message.content;
    //     }
    //   } else {
    //     this.message = message.content;
    //   }

    //   this.selectedTabIndex = 0;
    // },
    // 21082025

    // MÉTODO 2: editMessage - REEMPLAZAR COMPLETAMENTE
    // editMessage(message) {
    //   this.isEditMode = true;
    //   this.editingMessageId = message.id;

    //   this.scheduledAt = new Date(message.scheduled_at);
    //   this.recipientType = message.recipient_type || 'contact';

    //   // Manejo corregido para plantillas
    //   if (message.is_template && message.template_name) {
    //     const template = this.availableTemplates.find(t => t.name === message.template_name);
    //     if (template) {
    //       this.selectedTemplate = template;
    //       // Cargar los parámetros procesados, no los metadatos completos
    //       this.templateParams = message.template_params?.processed_params ||
    //         message.template_params || {};
    //     } else {
    //       // Fallback si la plantilla ya no existe
    //       this.message = message.content;
    //       this.selectedTemplate = null;
    //       console.warn('Plantilla no encontrada:', message.template_name);
    //     }
    //   } else {
    //     this.message = message.content;
    //     this.selectedTemplate = null;
    //   }

    //   this.selectedTabIndex = 0;
    // },


    // // Método editMessage mejorado
    // async editMessage(message) {
    //   try {
    //     // Verificar que el mensaje aún esté pendiente
    //     if (message.sent || message.is_sent || message.status === 'sent') {
    //       useAlert(this.$t('CONVERSATION.SCHEDULE_MESSAGE.CANNOT_EDIT_SENT'));
    //       return;
    //     }

    //     this.isEditMode = true;
    //     this.editingMessageId = message.id;

    //     // Cargar datos del mensaje al formulario
    //     this.scheduledAt = new Date(message.scheduled_at);
    //     this.recipientType = message.recipient_type || 'contact';

    //     // Si es un mensaje de plantilla, cargar datos de plantilla
    //     if (message.is_template && message.template_name) {
    //       const template = this.availableTemplates.find(t => t.name === message.template_name);
    //       if (template) {
    //         this.selectedTemplate = template;
    //         this.templateParams = message.template_params || {};
    //       } else {
    //         // Fallback para plantillas que ya no existen
    //         this.selectedTemplate = null;
    //         this.message = message.content;
    //       }
    //     } else {
    //       this.selectedTemplate = null;
    //       this.message = message.content;
    //     }

    //     // Cambiar a la pestaña de edición
    //     this.selectedTabIndex = 0;

    //     useAlert(this.$t('CONVERSATION.SCHEDULE_MESSAGE.EDIT_MODE_ACTIVATED'));
    //   } catch (error) {
    //     console.error('Error al editar mensaje:', error);
    //     useAlert(this.$t('CONVERSATION.SCHEDULE_MESSAGE.ERROR_EDITING'));
    //   }
    // },

    // // Método deleteMessage mejorado
    // async deleteMessage(message) {
    //   try {
    //     // Verificar que el mensaje aún esté pendiente
    //     if (message.sent || message.is_sent || message.status === 'sent') {
    //       useAlert(this.$t('CONVERSATION.SCHEDULE_MESSAGE.CANNOT_DELETE_SENT'));
    //       return;
    //     }

    //     // Confirmar eliminación
    //     const confirmMessage = this.$t('CONVERSATION.SCHEDULE_MESSAGE.CONFIRM_DELETE');
    //     if (!confirm(confirmMessage)) {
    //       return;
    //     }

    //     // Mostrar indicador de carga
    //     this.isLoadingMessages = true;

    //     // Eliminar mensaje usando la API
    //     await scheduledMessagesAPI.delete(message.id);

    //     // Recargar lista de mensajes
    //     await this.loadScheduledMessages();

    //     // Mostrar mensaje de éxito
    //     useAlert(this.$t('CONVERSATION.SCHEDULE_MESSAGE.DELETE_SUCCESS'));

    //     // Si estábamos editando este mensaje, cancelar edición
    //     if (this.isEditMode && this.editingMessageId === message.id) {
    //       this.cancelEdit();
    //     }

    //   } catch (error) {
    //     console.error('Error al eliminar mensaje:', error);
    //     useAlert(this.$t('CONVERSATION.SCHEDULE_MESSAGE.ERROR_DELETING'));
    //   } finally {
    //     this.isLoadingMessages = false;
    //   }
    // },


    // Método editMessage funcional
    editMessage(message) {
      console.log('Editando mensaje:', message);

      // Verificar que el mensaje esté pendiente
      const isSent = message.sent || message.is_sent || message.status === 'sent' ||
        message.status === 'enviado' || message.delivered_at;

      if (isSent) {
        this.$alert(this.$t('CONVERSATION.SCHEDULE_MESSAGE.CANNOT_EDIT_SENT') || 'No se puede editar un mensaje enviado');
        return;
      }

      try {
        // Activar modo edición
        this.isEditMode = true;
        this.editingMessageId = message.id;

        // Cargar datos del mensaje
        this.scheduledAt = new Date(message.scheduled_at);
        this.recipientType = message.recipient_type || 'contact';

        // Manejar contenido del mensaje
        if (message.template_name) {
          // Es un mensaje de plantilla
          const template = this.availableTemplates?.find(t => t.name === message.template_name);
          if (template) {
            this.selectedTemplate = template;
            this.templateParams = message.template_params || {};
          } else {
            this.selectedTemplate = null;
            this.message = message.content;
          }
        } else {
          // Es un mensaje regular
          this.selectedTemplate = null;
          this.message = message.content || '';
        }

        // Cambiar a la pestaña de edición
        this.selectedTabIndex = 0;

        // Mostrar confirmación
        if (this.$alert) {
          this.$alert(this.$t('CONVERSATION.SCHEDULE_MESSAGE.EDIT_MODE_ACTIVATED') || 'Modo de edición activado');
        }

      } catch (error) {
        console.error('Error al editar mensaje:', error);
        if (this.$alert) {
          this.$alert(this.$t('CONVERSATION.SCHEDULE_MESSAGE.ERROR_EDITING') || 'Error al activar modo de edición');
        }
      }
    },

    // Método deleteMessage funcional
    async deleteMessage(message) {
      console.log('Eliminando mensaje:', message);

      // Verificar que el mensaje esté pendiente
      const isSent = message.sent || message.is_sent || message.status === 'sent' ||
        message.status === 'enviado' || message.delivered_at;

      if (isSent) {
        if (this.$alert) {
          this.$alert(this.$t('CONVERSATION.SCHEDULE_MESSAGE.CANNOT_DELETE_SENT') || 'No se puede eliminar un mensaje enviado');
        }
        return;
      }

      // Confirmar eliminación
      const confirmMessage = this.$t('CONVERSATION.SCHEDULE_MESSAGE.CONFIRM_DELETE') ||
        '¿Estás seguro de que deseas eliminar este mensaje programado?';

      if (!confirm(confirmMessage)) {
        return;
      }

      try {
        // Mostrar indicador de carga
        this.isLoadingMessages = true;

        // Llamar a la API para eliminar
        // Asegúrate de importar scheduledMessagesAPI o usar el método correcto
        if (this.$store && this.$store.dispatch) {
          await this.$store.dispatch('scheduledMessages/delete', message.id);
        } else if (window.scheduledMessagesAPI) {
          await window.scheduledMessagesAPI.delete(message.id);
        } else {
          // Fallback: remover del array local temporalmente
          console.log('API no disponible, removiendo localmente');
          const index = this.scheduledMessages.findIndex(m => m.id === message.id);
          if (index > -1) {
            this.scheduledMessages.splice(index, 1);
          }
        }

        // Recargar mensajes si es posible
        if (this.loadScheduledMessages) {
          await this.loadScheduledMessages();
        }

        // Mostrar éxito
        if (this.$alert) {
          this.$alert(this.$t('CONVERSATION.SCHEDULE_MESSAGE.DELETE_SUCCESS') || 'Mensaje eliminado correctamente');
        }

        // Si estábamos editando este mensaje, cancelar edición
        if (this.isEditMode && this.editingMessageId === message.id) {
          this.cancelEdit();
        }

      } catch (error) {
        console.error('Error al eliminar mensaje:', error);
        if (this.$alert) {
          this.$alert(this.$t('CONVERSATION.SCHEDULE_MESSAGE.ERROR_DELETING') || 'Error al eliminar el mensaje');
        }
      } finally {
        this.isLoadingMessages = false;
      }
    },

    // Método para cancelar edición
    cancelEdit() {
      this.isEditMode = false;
      this.editingMessageId = null;
      this.selectedTemplate = null;
      this.message = '';
      this.templateParams = {};

      if (this.resetForm) {
        this.resetForm();
      }
    },



    // Cancel edit
    // cancelEdit() {
    //   this.isEditMode = false;
    //   this.editingMessageId = null;
    //   this.resetForm();
    // },

    // Delete message
    // async deleteMessage(message) {
    //   if (!confirm(this.$t('CONVERSATION.SCHEDULE_MESSAGE.CONFIRM_DELETE'))) {
    //     return;
    //   }

    //   try {
    //     await scheduledMessagesAPI.delete(message.id);
    //     useAlert(this.$t('CONVERSATION.SCHEDULE_MESSAGE.DELETE_SUCCESS'));
    //     await this.loadScheduledMessages();
    //   } catch (error) {
    //     // // console...error('Error deleting message:', error);
    //     useAlert(this.$t('CONVERSATION.SCHEDULE_MESSAGE.ERROR_DELETING'));
    //   }
    // },

    // Format date for display
    formatDate(dateString) {
      const date = new Date(dateString);
      return date.toLocaleString('es-ES', {
        day: '2-digit',
        month: '2-digit',
        year: 'numeric',
        hour: '2-digit',
        minute: '2-digit'
      });
    },

    // Message placeholders and button text
    getMessagePlaceholder() {
      if (this.recipientType === 'agent') {
        return this.$t('CONVERSATION.SCHEDULE_MESSAGE.REMINDER_PLACEHOLDER');
      }
      return this.$t('CONVERSATION.SCHEDULE_MESSAGE.MESSAGE_PLACEHOLDER');
    },

    getConfirmButtonText() {
      if (this.selectedTemplate) {
        return this.$t('CONVERSATION.SCHEDULE_MESSAGE.SCHEDULE_TEMPLATE');
      }
      if (this.recipientType === 'agent') {
        return this.$t('CONVERSATION.SCHEDULE_MESSAGE.SCHEDULE_REMINDER');
      }
      return this.$t('CONVERSATION.SCHEDULE_MESSAGE.SCHEDULE_MESSAGE');
    },

    // Timezone methods
    detectUserTimezone() {
      const browserTimezone = Intl.DateTimeFormat().resolvedOptions().timeZone;
      const matchedTimezone = this.timezones.find(tz => tz.value === browserTimezone);

      if (matchedTimezone) {
        this.selectedTimezone = matchedTimezone;
      } else {
        this.setClosestTimezone(browserTimezone);
      }
    },

    setClosestTimezone(browserTimezone) {
      const date = new Date();
      const browserOffset = -date.getTimezoneOffset() / 60;

      const getTimezoneOffset = (timezone) => {
        try {
          const dateInTz = new Date().toLocaleString('en-US', { timeZone: timezone });
          const dateInLocal = new Date(dateInTz);
          return -dateInLocal.getTimezoneOffset() / 60;
        } catch (e) {
          return 0;
        }
      };

      let closestTimezone = this.timezones[0];
      let minDifference = Math.abs(getTimezoneOffset(closestTimezone.value) - browserOffset);

      this.timezones.forEach(tz => {
        const difference = Math.abs(getTimezoneOffset(tz.value) - browserOffset);
        if (difference < minDifference) {
          minDifference = difference;
          closestTimezone = tz;
        }
      });

      this.selectedTimezone = closestTimezone;
    },

    onClose() {
      this.resetForm();
      this.$emit('close');
    },

    onChange(value) {
      this.scheduledAt = value;
    },

    timezoneNameWithCode({ label, value }) {
      if (!value) return label;
      if (!label && !value) return '';
      return `${label}`;
    },

    async saveMessage() {
      this.v$.$touch();
      if (this.v$.$invalid) {
        return;
      }

      try {
        const timezone = this.selectedTimezone?.value || 'UTC';

        let messageData = {
          conversation_id: this.conversationId,
          scheduled_at: this.scheduledAt,
          timezone: timezone,
          recipient_type: this.recipientType,
        };

        // Agregar datos específicos según el tipo de mensaje
        if (this.selectedTemplate) {
          // Para plantillas: estructura corregida
          messageData = {
            ...messageData,
            content: this.processedTemplateString,
            template_name: this.selectedTemplate.name,
            template_category: this.selectedTemplate.category,
            template_language: this.selectedTemplate.language,
            template_namespace: this.selectedTemplate.namespace,
            template_params: {
              name: this.selectedTemplate.name,
              category: this.selectedTemplate.category,
              language: this.selectedTemplate.language,
              namespace: this.selectedTemplate.namespace,
              processed_params: this.templateParams, // Los parámetros procesados del usuario
            },
            is_template: true,
            message_type: 'template', // Importante: especificar el tipo
          };

          console.log('Enviando plantilla con datos:', {
            template_name: messageData.template_name,
            template_params: messageData.template_params,
            processed_string: this.processedTemplateString
          });

        } else {
          // Para mensajes regulares (sin cambios)
          messageData.content = this.message;
          messageData.is_template = false;

          // Si es recordatorio para agente
          if (this.recipientType === 'agent') {
            messageData.message_type = 'private';
          }
        }

        console.log('Enviando messageData completo:', messageData);

        let result;
        if (this.isEditMode) {

          result = await scheduledMessagesAPI.update(this.editingMessageId, messageData);
          await this.sendConfirmationNotification(result.data, timezone);
          useAlert(this.$t('CONVERSATION.SCHEDULE_MESSAGE.UPDATE_SUCCESS'));
        } else {
          result = await scheduledMessagesAPI.create(messageData);

          await this.sendConfirmationNotification(result.data, timezone);

          const successMessage = this.selectedTemplate
            ? this.$t('CONVERSATION.SCHEDULE_MESSAGE.TEMPLATE_SUCCESS')
            : this.recipientType === 'agent'
              ? this.$t('CONVERSATION.SCHEDULE_MESSAGE.REMINDER_SUCCESS')
              : this.$t('CONVERSATION.SCHEDULE_MESSAGE.SUCCESS');
          useAlert(successMessage);
        }

        await this.loadScheduledMessages();
        this.resetForm();

        // Navigate to appropriate tab
        // const controlTabIndex = this.availableTemplates.length > 0 ? 2 : 1;
        this.selectedTabIndex = 2;

      } catch (error) {
        console.error('Error saving message:', error);
        console.error('Error details:', error.response?.data);

        const errorMessage = error.response?.data?.error ||
          error.response?.data?.message ||
          error.message ||
          this.$t('CONVERSATION.SCHEDULE_MESSAGE.ERROR');
        useAlert(errorMessage);
      }
    },
    // 21082025





    // Send confirmation notification
    async sendConfirmationNotification(scheduledMessageData, timezone) {
      const messageContent = this.formatConfirmationMessage(scheduledMessageData, timezone);

      try {
        await messageAPI.create({
          conversationId: this.conversationId,
          message: messageContent,
          private: true,
          contentAttributes: {
            message_action: this.selectedTemplate
              ? "template_scheduled"
              : this.recipientType === 'agent'
                ? "reminder_scheduled"
                : "scheduled_message_created",
            scheduled_message_id: scheduledMessageData.id,
            recipient_type: this.recipientType,
            template_name: this.selectedTemplate?.name,
          },
          echo_id: null,
          files: null,
        });
      } catch (err) {
        // // console...log('Error sending confirmation:', err);
      }
    },

    formatConfirmationMessage(scheduledMessageData, timezone) {
      const scheduledDate = new Date(this.scheduledAt);
      const currentDate = new Date();
      const formattedScheduledDate = this.formatDate(scheduledDate);
      const formattedCurrentDate = this.formatDate(currentDate);

      if (this.selectedTemplate) {
        return `📋 **PLANTILLA PROGRAMADA**

⏰ **Se enviará al contacto el:** ${formattedScheduledDate}
📋 **Detalles:**
• Plantilla: ${this.selectedTemplate.name}
• Idioma: ${this.selectedTemplate.language}
• Categoría: ${this.selectedTemplate.category}
• Programado por: ${this.currentUser.name || this.currentUser.email}
• Fecha de programación: ${formattedCurrentDate}
• Zona horaria: ${timezone}

💡 **Nota:** Esta plantilla se enviará automáticamente al contacto a la hora programada.`;
      } else if (this.recipientType === 'agent') {
        return `🔔 **RECORDATORIO PROGRAMADO**

⏰ **Se enviará como recordatorio el:** ${formattedScheduledDate}
📋 **Detalles:**
• Programado por: ${this.currentUser.name || this.currentUser.email}
• Fecha de programación: ${formattedCurrentDate}
• Zona horaria: ${timezone}
• Tipo: Recordatorio interno (privado)

💡 **Nota:** Este recordatorio se enviará como mensaje privado solo visible para agentes.`;
      } else {
        return `📅 **MENSAJE PROGRAMADO**

⏰ **Se enviará al contacto el:** ${formattedScheduledDate}
📋 **Detalles:**
• Programado por: ${this.currentUser.name || this.currentUser.email}
• Fecha de programación: ${formattedCurrentDate}
• Zona horaria: ${timezone}
• Destinatario: Contacto de la conversación

💡 **Nota:** Este mensaje se enviará automáticamente al contacto a la hora programada.`;
      }
    },

    resetForm() {
      this.message = '';
      this.scheduledAt = null;
      this.recipientType = 'contact';
      this.selectedTemplate = null;
      this.templateParams = {};
      this.templateQuery = '';
      this.isEditMode = false;
      this.editingMessageId = null;
      this.selectedTabIndex = 0;
      this.currentPage = 1;
      this.v$.$reset();
    },
  },
};
</script>

<style lang="scss" scoped>
.schedule-form {
  @apply space-y-3 flex-1 flex flex-col w-full;
  padding: 8px 8px 16px 8px !important; // !important para sobrescribir estilos inline
}

// Template search styles (similar to TemplatesPicker.vue)
.templates__list-search {
  @apply items-center flex mb-2.5 py-0 px-2.5 rounded-md border border-solid border-slate-100;
  background-color: #f8fafc;

  .search-icon {
    @apply text-slate-400 text-sm mr-2;
  }

  .templates__search-input {
    @apply bg-transparent border-0 text-xs h-9 m-0 w-full;
  }
}

// Template list styles
.template__list-container {
  @apply bg-slate-25 dark:bg-slate-900 rounded-md max-h-[380px] overflow-y-auto p-2.5;

  .template__list-item {
    @apply rounded-lg cursor-pointer block p-3 text-left w-full hover:bg-woot-50 dark:hover:bg-slate-800 transition-colors border border-transparent hover:border-woot-200;

    .template-card {
      .label-title {
        @apply text-sm font-medium text-slate-800;
      }

      // Template badges
      .template-badge {
        @apply inline-block px-2 py-1 text-xs leading-none rounded-sm cursor-default;

        &--language {
          background-color: #dbeafe;
          color: #1e40af;
        }

        &--category {
          background-color: #dcfce7;
          color: #16a34a;
        }
      }

      .template-content {
        @apply my-3;

        .template-body {
          @apply text-sm text-slate-600 leading-relaxed;
          font-family: monospace;
        }
      }

      .template-hint {
        @apply flex items-center text-xs text-slate-500 mt-2;
      }
    }
  }
}

// Template variables styles (similar to TemplateParser.vue)
.template__variables-container {
  .variables-label {
    @apply text-sm font-semibold mb-3;
  }

  .template__variable-item {
    @apply items-center flex mb-3;

    .variable-input {
      @apply flex-1 text-sm ml-2.5;
    }

    .variable-label {
      @apply text-slate-700 inline-block rounded-md text-xs py-2.5 px-6 min-w-[80px] text-center;
      background-color: #f1f5f9;
    }
  }
}

// Template content display
.template-content-display {
  @apply flex-1 flex flex-col;

  .template-input {
    @apply text-slate-700 border border-slate-200 rounded-md p-3 resize-none;
    background-color: #f8fafc;
    font-family: monospace;
  }
}

// Editor styles
::v-deep .ProseMirror-woot-style {
  min-height: 5rem;
  height: auto;
}

.message-editor {
  @apply px-3;

  ::v-deep {
    .ProseMirror-menubar {
      @apply rounded-tl-[4px];
    }

    .ProseMirror-woot-style {
      min-height: 5rem;
      height: auto;
      flex: 1;
    }
  }

  &.flex-1 {
    ::v-deep .ProseMirror-woot-style {
      min-height: 8rem;
    }
  }
}

.editor-warning__message {
  @apply text-red-500 text-xs mt-1;
}

// Radio buttons
.form-radio {
  @apply bg-white border-2 border-slate-300;

  &:checked {
    @apply bg-woot-600 border-woot-600;
  }

  &:focus {
    @apply outline-none ring-2 ring-woot-500 ring-opacity-50;
  }

  &:disabled {
    @apply bg-slate-100 border-slate-300 cursor-not-allowed;
  }
}

// Labels for radio buttons
label:has(.form-radio) {
  min-height: 76px;

  .text-xs {
    line-height: 1.3;
    font-size: 11px;
  }

  &:hover:not(:has(.form-radio:disabled)) {
    @apply border-slate-300 bg-slate-50;
    transition: all 0.15s ease;
  }
}

// Multiselect
::v-deep .multiselect {
  .multiselect__tags {
    min-height: 38px;
    padding: 6px 8px;
    font-size: 14px;
  }

  .multiselect__single {
    font-size: 14px;
    padding-left: 0;
  }

  .multiselect__select {
    height: 38px;
  }
}

// VeTable styles
.scheduled-messages-table-wrap::v-deep {
  .ve-table {
    @apply pb-4;
  }

  .ve-table-header-th {
    padding: var(--space-small) var(--space-two) !important;
    font-size: var(--font-size-mini) !important;
  }

  .ve-table-body-td {
    padding: var(--space-small) var(--space-two) !important;
  }

  .ve-pagination {
    @apply mt-4;
  }
}

// Consistent input heights
input,
select {
  height: 38px !important;
  font-size: 14px !important;
}

// Loading animation
@keyframes spin {
  to {
    transform: rotate(360deg);
  }
}

.animate-spin {
  animation: spin 1s linear infinite;
}

// Consistent height
.min-h-\[480px\] {
  min-height: 480px;
}

// Flexbox editor
.editor-wrap.flex-1 {
  display: flex;
  flex-direction: column;
  min-height: 0;

  .message-editor {
    flex: 1;
    display: flex;
    flex-direction: column;
    min-height: 0;

    ::v-deep .editor-content-wrapper {
      flex: 1;
      display: flex;
      flex-direction: column;
    }

    ::v-deep .ProseMirror-woot-style {
      flex: 1;
      min-height: 8rem;
    }
  }
}

// Custom badge styles (replacing Tailwind colors not available)
.recipient-badge {
  &--contact {
    background-color: #dbeafe;
    color: #1e40af;
  }

  &--agent {
    background-color: #f3e8ff;
    color: #7c3aed;
  }
}

.status-badge {
  &--sent {
    background-color: #dcfce7;
    color: #16a34a;
  }

  &--pending {
    background-color: #fef3c7;
    color: #d97706;
  }
}

.template-indicator {
  @apply inline-flex items-center px-2 py-0.5 rounded text-xs font-medium mt-1 w-fit;
  background-color: #dcfce7;
  color: #16a34a;
}
</style>