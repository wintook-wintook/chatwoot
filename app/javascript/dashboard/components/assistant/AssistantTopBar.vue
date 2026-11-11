<!--
  Asistente (Dali) — barra «Pregúntale a Dali…» arriba de todas las pantallas del
  dashboard, para tenerlo siempre a la vista. Escribir + Enter abre el panel con la
  pregunta ya enviada; Enter sin texto (o doble clic en la caja) abre el panel. El texto de la caja
  cambia según lo que se está viendo (caso, contacto, organización, conversación).
  Las pantallas de campo (Mi ruta) no usan Dashboard.vue y no la muestran.

  A la derecha, los accesos rápidos (Tarea, Reportar actividad, Buscar, Nuevo
  contacto, Ayuda), que antes estaban en el menú del logo. Sus ventanas viven aquí.
  En pantallas angostas solo se ve el ícono.
-->
<script>
import { mapGetters } from 'vuex';
import CreateContact from 'dashboard/routes/dashboard/conversation/contact/CreateContact.vue';
import QuickTaskModal from 'dashboard/views/gestorTickets/tasks/QuickTaskModal.vue';
import QuickSearchModal from 'dashboard/views/gestorTickets/tasks/QuickSearchModal.vue';
import ActivityReportModal from 'dashboard/views/gestorTickets/tasks/ActivityReportModal.vue';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import wootConstants from 'dashboard/constants/globals';
import {
  assistantState,
  toggleAssistant,
  DEFAULT_ASSISTANT_NAME,
} from 'dashboard/helper/assistantState';

const T = 'ASSISTANT.TOP_BAR';

export default {
  name: 'AssistantTopBar',
  components: {
    CreateContact,
    QuickTaskModal,
    QuickSearchModal,
    ActivityReportModal,
  },
  data() {
    return {
      state: assistantState,
      text: '',
      modal: null, // task | activity | search | contact
      reportTask: null, // «Reportar avance» desde el menú de una tarea
      helpDocsURL: window.chatwootConfig?.helpDocsURL || wootConstants.DOCS_URL,
    };
  },
  computed: {
    ...mapGetters({
      accountId: 'getCurrentAccountId',
      isFeatureEnabledonAccount: 'accounts/isFeatureEnabledonAccount',
    }),
    // Igual que CRMZeus en Contactos: el alta se sincroniza con el CRM.
    isIntegrationEnabled() {
      const integrations =
        this.$store.getters['integrations/getAppIntegrations'];
      return !!integrations.find(({ id }) => id === 'crmzeus')?.enabled;
    },
    // Sin casos en la cuenta no hay tareas.
    actions() {
      const withCases = this.isFeatureEnabledonAccount(
        this.accountId,
        FEATURE_FLAGS.CASE_MANAGEMENT
      );
      return [
        // La lupa primero, junto a la caja de Dali; el texto corto es «Buscar».
        {
          key: 'search',
          icon: 'search',
          label: 'QUICK_ACTIONS.SEARCH_CLIENT',
          text: 'QUICK_ACTIONS.SEARCH_SHORT',
        },
        withCases && {
          key: 'task',
          icon: 'checkmark-circle',
          label: 'QUICK_ACTIONS.NEW_TASK',
          text: true,
        },
        {
          key: 'activity',
          icon: 'clipboard',
          label: 'QUICK_ACTIONS.REPORT_ACTIVITY',
          text: true,
        },
        {
          key: 'contact',
          icon: 'person-add',
          label: 'QUICK_ACTIONS.NEW_CONTACT',
          text: true,
        },
      ].filter(Boolean);
    },
    name() {
      return this.state.name || DEFAULT_ASSISTANT_NAME;
    },
    // Mismo criterio que AssistantPanel#context.
    placeholder() {
      const { name: route, params } = this.$route;
      let key = 'PLACEHOLDER';
      if (route === 'gestorTickets_detail' && params.id) key = 'ON_CASE';
      else if (params.conversation_id) key = 'ON_CONVERSATION';
      else if (params.contactId) key = 'ON_CONTACT';
      else if (params.organizationId) key = 'ON_ORGANIZATION';
      return this.$t(`${T}.${key}`, { name: this.name });
    },
  },
  mounted() {
    window.addEventListener('keydown', this.onShortcut);
    // «Primeros pasos» abre aquí la ventana de alta (p. ej. «Nuevo contacto»).
    this.$emitter.on('topbar:open', this.openAction);
    // «Reportar avance» (menú de una tarea): la misma ventana, con la tarea ya puesta.
    this.$emitter.on('topbar:reportProgress', this.openProgress);
  },
  beforeDestroy() {
    window.removeEventListener('keydown', this.onShortcut);
    this.$emitter.off('topbar:open', this.openAction);
    this.$emitter.off('topbar:reportProgress', this.openProgress);
  },
  methods: {
    // Ctrl + K (⌘ K) abre la lupa desde cualquier pantalla.
    onShortcut(event) {
      if (!(event.ctrlKey || event.metaKey) || event.shiftKey || event.altKey)
        return;
      if (event.key.toLowerCase() !== 'k') return;
      event.preventDefault();
      this.openAction('search');
    },
    async openAction(key) {
      if (key === 'contact') await this.$store.dispatch('integrations/get');
      this.modal = key;
    },
    openProgress(task) {
      this.reportTask = task;
      this.modal = 'activity';
    },
    closeModal() {
      this.modal = null;
      this.reportTask = null;
    },
    submit() {
      const text = this.text.trim();
      toggleAssistant(true);
      if (!text) return;
      this.text = '';
      this.$refs.input?.blur();
      // El panel ya escucha (está montado siempre); se abre y luego recibe la pregunta.
      this.$nextTick(() => this.$emitter.emit('assistant:ask', text));
    },
  },
};
</script>

<template>
  <div
    class="flex items-center flex-shrink-0 h-10 px-3 bg-white border-b border-slate-100 dark:bg-slate-900 dark:border-slate-800"
  >
    <form
      class="flex items-center flex-1 max-w-lg gap-2 px-3 rounded-lg h-7 bg-slate-50 dark:bg-slate-800 focus-within:ring-1 focus-within:ring-woot-300"
      @submit.prevent="submit"
    >
      <fluent-icon icon="wand" size="14" class="flex-shrink-0 text-woot-500" />
      <input
        ref="input"
        v-model="text"
        type="text"
        class="flex-1 min-w-0 !h-7 !mb-0 !p-0 text-sm !bg-transparent !border-0 !shadow-none focus:!ring-0 placeholder:text-slate-400"
        :placeholder="placeholder"
        :aria-label="placeholder"
        @dblclick="submit"
      />
      <kbd
        class="flex-shrink-0 hidden px-1.5 text-[10px] font-sans border rounded sm:inline text-slate-400 border-slate-200 dark:border-slate-700"
      >
        {{ $t('ASSISTANT.SHORTCUT') }}
      </kbd>
    </form>
    <div class="flex items-center flex-shrink-0 gap-1 ml-3">
      <button
        v-for="action in actions"
        :key="action.key"
        v-tooltip.bottom="$t(action.label)"
        type="button"
        class="flex items-center h-7 gap-1.5 px-2 text-xs rounded-lg text-slate-600 hover:bg-slate-100 hover:text-slate-900 dark:text-slate-300 dark:hover:bg-slate-800 dark:hover:text-white"
        :aria-label="$t(action.label)"
        @click="openAction(action.key)"
      >
        <fluent-icon :icon="action.icon" size="16" class="flex-shrink-0" />
        <span v-if="action.text" class="hidden whitespace-nowrap xl:inline">
          {{ $t(action.text === true ? action.label : action.text) }}
        </span>
      </button>
      <a
        v-tooltip.bottom="$t('SIDEBAR.DOCS')"
        :href="helpDocsURL"
        target="_blank"
        rel="noopener noreferrer"
        class="flex items-center justify-center rounded-lg w-7 h-7 text-slate-600 hover:bg-slate-100 hover:text-slate-900 dark:text-slate-300 dark:hover:bg-slate-800 dark:hover:text-white"
        :aria-label="$t('SIDEBAR.DOCS')"
      >
        <fluent-icon icon="chat-help" size="16" />
      </a>
    </div>
    <QuickTaskModal :show="modal === 'task'" @close="closeModal" />
    <ActivityReportModal
      :show="modal === 'activity'"
      :task="reportTask"
      @close="closeModal"
    />
    <QuickSearchModal :show="modal === 'search'" @close="closeModal" />
    <CreateContact
      :show="modal === 'contact'"
      :is-integration-enabled="isIntegrationEnabled"
      @cancel="closeModal"
    />
  </div>
</template>
