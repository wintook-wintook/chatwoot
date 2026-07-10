<!--
  @tickets_cases
  Sección "Ticket asociado" en el panel derecho de la conversación.
  Botón compacto: verde si el contacto tiene tickets en proceso (muestra el conteo),
  gris si no tiene. Abre el modal con la lista + alta. Tailwind + dark mode.
-->
<script>
import { mapGetters } from 'vuex';
import CaseTicketModal from './CaseTicketModal.vue';

export default {
  name: 'CaseTicketPanel',
  components: { CaseTicketModal },
  props: {
    contactId: { type: [Number, String], required: true },
    // Opcional: la ficha de contacto (sin conversación) lo monta sin este prop.
    conversationId: { type: [Number, String], default: null },
    // Modo inline: sin el wrapper con padding/borde, para colocarlo en una fila
    // junto a otro botón (p. ej. al lado del de seguimientos).
    bare: { type: Boolean, default: false },
  },
  data() {
    return {
      showModal: false,
    };
  },
  computed: {
    ...mapGetters({
      getUIFlags: 'caseTickets/getUIFlags',
      getContactTickets: 'caseTickets/getContactTickets',
    }),
    isFetching() {
      return this.getUIFlags.isFetching;
    },
    tickets() {
      return this.getContactTickets(this.contactId);
    },
    hasTickets() {
      return this.tickets.length > 0;
    },
  },
  watch: {
    contactId(newId) {
      if (newId) this.fetchTickets();
    },
  },
  mounted() {
    this.fetchTickets();
  },
  methods: {
    fetchTickets() {
      if (!this.contactId) return;
      this.$store.dispatch('caseTickets/fetchContactTickets', {
        contactId: this.contactId,
      });
    },
    onModalClose() {
      this.showModal = false;
      // El modal pudo crear/transicionar tickets → refrescar el conteo del botón.
      this.fetchTickets();
    },
  },
};
</script>

<template>
  <div :class="bare ? 'w-full' : 'p-4 border-b border-slate-50 dark:border-slate-800/50'">
    <woot-button
      size="small"
      variant="smooth"
      :color-scheme="hasTickets ? 'success' : 'secondary'"
      icon="clipboard"
      class="w-full"
      :is-loading="isFetching"
      @click="showModal = true"
    >
      <template v-if="hasTickets">
        {{ $t('CASE_TICKETS.PANEL_BUTTON', { count: tickets.length }) }}
      </template>
      <template v-else>
        {{ $t('CASE_TICKETS.CREATE_BUTTON') }}
      </template>
    </woot-button>

    <!-- Modal: lista de tickets en proceso + alta -->
    <CaseTicketModal
      v-if="showModal"
      :show="showModal"
      :contact-id="contactId"
      :conversation-id="conversationId"
      @close="onModalClose"
      @created="fetchTickets"
    />
  </div>
</template>
