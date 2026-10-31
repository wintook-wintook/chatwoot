<!--
  Plan-Agenda — accesos rápidos: el logo de la barra de íconos abre un menú flotante,
  en todas las pantallas. La tarea va primero.
-->
<script>
import CreateContact from 'dashboard/routes/dashboard/conversation/contact/CreateContact.vue';
import QuickTaskModal from 'dashboard/views/gestorTickets/tasks/QuickTaskModal.vue';

export default {
  name: 'QuickActions',
  components: { CreateContact, QuickTaskModal },
  props: {
    logoSource: { type: String, default: '' },
    name: { type: String, default: '' },
    // Sin casos en la cuenta no hay tareas: queda solo el contacto.
    showTask: { type: Boolean, default: true },
  },
  data() {
    return { open: false, showTaskModal: false, showContactModal: false };
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
    openTask() {
      this.close();
      this.showTaskModal = true;
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
      class="absolute top-0 z-50 w-48 py-1 bg-white border shadow-lg left-10 rtl:left-auto rtl:right-10 rounded-xl border-slate-100 dark:bg-slate-800 dark:border-slate-700"
    >
      <button
        v-if="showTask"
        type="button"
        class="flex items-center w-full gap-2 px-3 py-2 text-sm text-slate-700 dark:text-slate-200 hover:bg-slate-50 dark:hover:bg-slate-700"
        @click="openTask"
      >
        <fluent-icon icon="checkmark-circle" size="16" />
        {{ $t('QUICK_ACTIONS.NEW_TASK') }}
      </button>
      <button
        type="button"
        class="flex items-center w-full gap-2 px-3 py-2 text-sm text-slate-700 dark:text-slate-200 hover:bg-slate-50 dark:hover:bg-slate-700"
        @click="openContact"
      >
        <fluent-icon icon="person-add" size="16" />
        {{ $t('QUICK_ACTIONS.NEW_CONTACT') }}
      </button>
    </div>
    <QuickTaskModal :show="showTaskModal" @close="showTaskModal = false" />
    <CreateContact
      :show="showContactModal"
      :is-integration-enabled="isIntegrationEnabled"
      @cancel="showContactModal = false"
    />
  </div>
</template>
