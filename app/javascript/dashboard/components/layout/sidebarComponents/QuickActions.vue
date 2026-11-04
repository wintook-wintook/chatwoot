<!--
  Plan-Agenda — accesos rápidos: el logo de la barra de íconos abre un menú flotante,
  en todas las pantallas. Primero «Pedirle a Dali» (el asistente), luego la tarea; al final Ayuda.
-->
<script>
import CreateContact from 'dashboard/routes/dashboard/conversation/contact/CreateContact.vue';
import QuickTaskModal from 'dashboard/views/gestorTickets/tasks/QuickTaskModal.vue';
import QuickSearchModal from 'dashboard/views/gestorTickets/tasks/QuickSearchModal.vue';
import ActivityReportModal from 'dashboard/views/gestorTickets/tasks/ActivityReportModal.vue';
import wootConstants from 'dashboard/constants/globals';
import {
  assistantState,
  toggleAssistant,
} from 'dashboard/helper/assistantState';

export default {
  name: 'QuickActions',
  components: {
    CreateContact,
    QuickTaskModal,
    QuickSearchModal,
    ActivityReportModal,
  },
  props: {
    logoSource: { type: String, default: '' },
    name: { type: String, default: '' },
    // Sin casos en la cuenta no hay tareas: queda solo el contacto.
    showTask: { type: Boolean, default: true },
  },
  data() {
    return {
      open: false,
      showTaskModal: false,
      showActivityModal: false,
      showSearchModal: false,
      showContactModal: false,
      assistant: assistantState,
      // El foro de Kontrolya (antes un ícono propio en la barra).
      helpDocsURL: window.chatwootConfig?.helpDocsURL || wootConstants.DOCS_URL,
    };
  },
  computed: {
    // Igual que en Contactos: con CRMZeus activo el alta se sincroniza con el CRM.
    isIntegrationEnabled() {
      const integrations =
        this.$store.getters['integrations/getAppIntegrations'];
      return !!integrations.find(({ id }) => id === 'crmzeus')?.enabled;
    },
  },
  methods: {
    close() {
      this.open = false;
    },
    openAssistant() {
      this.close();
      toggleAssistant(true);
    },
    openTask() {
      this.close();
      this.showTaskModal = true;
    },
    openActivity() {
      this.close();
      this.showActivityModal = true;
    },
    openSearch() {
      this.close();
      this.showSearchModal = true;
    },
    async openContact() {
      this.close();
      await this.$store.dispatch('integrations/get');
      this.showContactModal = true;
    },
  },
};
</script>

<template>
  <div v-on-clickaway="close" class="relative w-8 h-8 m-4 mb-2">
    <button
      type="button"
      class="block w-8 h-8 p-0 bg-transparent"
      :title="$t('QUICK_ACTIONS.TITLE')"
      :aria-label="$t('QUICK_ACTIONS.TITLE')"
      :aria-expanded="open"
      @click="open = !open"
    >
      <img
        :src="logoSource"
        :alt="name"
        class="object-contain w-8 h-8 rounded-md"
      />
    </button>
    <div
      v-if="open"
      class="absolute top-0 z-50 w-72 py-1 bg-white border shadow-lg left-10 rtl:left-auto rtl:right-10 rounded-xl border-slate-100 dark:bg-slate-800 dark:border-slate-700"
    >
      <button
        type="button"
        class="flex items-center w-full gap-2 px-3 py-2 text-sm font-medium text-woot-700 dark:text-woot-200 hover:bg-slate-50 dark:hover:bg-slate-700"
        @click="openAssistant"
      >
        <fluent-icon icon="wand" size="16" />
        {{ $t('ASSISTANT.MENU', { name: assistant.name }) }}
      </button>
      <button
        v-if="showTask"
        type="button"
        class="flex items-center w-full gap-2 px-3 py-2 text-sm text-slate-700 dark:text-slate-200 hover:bg-slate-50 dark:hover:bg-slate-700"
        @click="openTask"
      >
        <fluent-icon icon="checkmark-circle" size="16" />
        {{ $t('QUICK_ACTIONS.NEW_TASK') }}
      </button>
      <!-- Algo que ya se hizo, sin tarea: con caso, con cliente o interno. -->
      <button
        type="button"
        class="flex items-center w-full gap-2 px-3 py-2 text-sm text-slate-700 dark:text-slate-200 hover:bg-slate-50 dark:hover:bg-slate-700"
        @click="openActivity"
      >
        <fluent-icon icon="clipboard" size="16" />
        {{ $t('QUICK_ACTIONS.REPORT_ACTIVITY') }}
      </button>
      <button
        type="button"
        class="flex items-center w-full gap-2 px-3 py-2 text-sm text-slate-700 dark:text-slate-200 hover:bg-slate-50 dark:hover:bg-slate-700"
        @click="openSearch"
      >
        <fluent-icon icon="search" size="16" />
        {{ $t('QUICK_ACTIONS.SEARCH_CLIENT') }}
      </button>
      <button
        type="button"
        class="flex items-center w-full gap-2 px-3 py-2 text-sm text-slate-700 dark:text-slate-200 hover:bg-slate-50 dark:hover:bg-slate-700"
        @click="openContact"
      >
        <fluent-icon icon="person-add" size="16" />
        {{ $t('QUICK_ACTIONS.NEW_CONTACT') }}
      </button>
      <a
        :href="helpDocsURL"
        target="_blank"
        rel="noopener noreferrer"
        class="flex items-center w-full gap-2 px-3 py-2 text-sm text-slate-700 border-t border-slate-100 dark:border-slate-700 dark:text-slate-200 hover:bg-slate-50 dark:hover:bg-slate-700"
        @click="close"
      >
        <fluent-icon icon="chat-help" size="16" />
        {{ $t('SIDEBAR.DOCS') }}
      </a>
    </div>
    <QuickTaskModal :show="showTaskModal" @close="showTaskModal = false" />
    <ActivityReportModal
      :show="showActivityModal"
      @close="showActivityModal = false"
    />
    <QuickSearchModal
      :show="showSearchModal"
      @close="showSearchModal = false"
    />
    <CreateContact
      :show="showContactModal"
      :is-integration-enabled="isIntegrationEnabled"
      @cancel="showContactModal = false"
    />
  </div>
</template>
