<!--
  @tickets_cases
  Sección "Ticket asociado" en el panel derecho de la conversación.
  Tailwind + dark mode.
-->
<template>
  <div class="p-4 border-b border-slate-50 dark:border-slate-800/50">
    <!-- Loading -->
    <div v-if="isFetching" class="flex justify-center py-2">
      <span class="text-sm text-slate-400 dark:text-slate-500">Cargando ticket...</span>
    </div>

    <!-- Sin ticket activo -->
    <template v-else-if="!activeTicket">
      <woot-button
        size="small"
        variant="smooth"
        color-scheme="secondary"
        icon="clipboard"
        class="w-full"
        @click="showCreateModal = true"
      >
        {{ $t('CASE_TICKETS.CREATE_BUTTON') }}
      </woot-button>
    </template>

    <!-- Ticket activo -->
    <template v-else>
      <div
        class="flex flex-col gap-2 p-2 border rounded-lg"
        :class="cardClass"
      >
        <!-- Badges -->
        <div class="flex flex-wrap gap-1">
          <span v-if="activeTicket.case_type" class="px-1.5 py-0.5 text-[11px] font-medium uppercase tracking-wide rounded text-white" :style="{ backgroundColor: activeTicket.case_type.color }">{{ activeTicket.case_type.name }}</span>
          <span class="px-1.5 py-0.5 text-[11px] font-medium uppercase tracking-wide rounded bg-slate-100 text-slate-800 dark:bg-slate-700 dark:text-slate-300">{{ statusLabel(activeTicket.status) }}</span>
          <span class="px-1.5 py-0.5 text-[11px] font-medium uppercase tracking-wide rounded" :class="priorityBadge(activeTicket.priority)">{{ priorityLabel(activeTicket.priority) }}</span>
          <span class="px-1.5 py-0.5 text-[11px] font-medium uppercase tracking-wide rounded" :class="slaBadge(activeTicket.sla_status)">SLA: {{ slaText }}</span>
        </div>

        <!-- Folio -->
        <span v-if="activeTicket.folio" class="font-mono text-xs text-slate-400 dark:text-slate-500">{{ activeTicket.folio }}</span>

        <!-- Título -->
        <p class="m-0 overflow-hidden text-sm whitespace-nowrap text-ellipsis text-slate-700 dark:text-slate-200">{{ activeTicket.title }}</p>

        <!-- Acciones -->
        <div class="flex items-center gap-1">
          <woot-button size="tiny" variant="clear" color-scheme="secondary" @click="showTimeline = true">
            {{ $t('CASE_TICKETS.VIEW_TIMELINE') }}
          </woot-button>

          <div class="relative">
            <woot-button
              size="tiny"
              variant="clear"
              color-scheme="secondary"
              icon="chevron-down"
              :is-loading="isTransitioning"
              @click="showTransitionMenu = !showTransitionMenu"
            >
              {{ $t('CASE_TICKETS.CHANGE_STATUS') }}
            </woot-button>
            <ul
              v-if="showTransitionMenu"
              class="absolute left-0 z-50 py-1 mt-1 list-none bg-white border rounded-md shadow-md dark:bg-slate-800 border-slate-100 dark:border-slate-700 min-w-[160px]"
            >
              <li
                v-for="s in validTransitions"
                :key="s"
                class="px-4 py-2 text-sm cursor-pointer text-slate-600 dark:text-slate-300 hover:bg-slate-50 dark:hover:bg-slate-700"
                @click="transitionTo(s)"
              >
                {{ statusLabel(s) }}
              </li>
            </ul>
          </div>
        </div>
      </div>
    </template>

    <!-- Modal crear ticket -->
    <CaseTicketModal
      v-if="showCreateModal"
      :show="showCreateModal"
      :contact-id="contactId"
      :conversation-id="conversationId"
      @close="showCreateModal = false"
      @created="onTicketCreated"
    />

    <!-- Modal timeline -->
    <CaseTimeline
      v-if="showTimeline && activeTicket"
      :show="showTimeline"
      :ticket-id="activeTicket.id"
      @close="showTimeline = false"
    />
  </div>
</template>

<script>
import { mapGetters } from 'vuex';
import CaseTicketModal from './CaseTicketModal.vue';
import CaseTimeline from './CaseTimeline.vue';

export default {
  name: 'CaseTicketPanel',
  components: { CaseTicketModal, CaseTimeline },
  props: {
    contactId: { type: [Number, String], required: true },
    conversationId: { type: [Number, String], required: true },
  },
  data() {
    return {
      showCreateModal: false,
      showTimeline: false,
      showTransitionMenu: false,
    };
  },
  computed: {
    ...mapGetters({
      getUIFlags: 'caseTickets/getUIFlags',
      getActiveTicket: 'caseTickets/getActiveTicket',
    }),
    isFetching() { return this.getUIFlags.isFetching; },
    isTransitioning() { return this.getUIFlags.isTransitioning; },
    activeTicket() { return this.getActiveTicket(this.contactId); },
    validTransitions() {
      return this.activeTicket?.can_transition_to || [];
    },
    cardClass() {
      const sla = this.activeTicket?.sla_status;
      return {
        on_time: 'bg-white dark:bg-slate-800 border-slate-75 dark:border-slate-700',
        at_risk: 'bg-yellow-50 dark:bg-yellow-900/20 border-yellow-300 dark:border-yellow-800',
        overdue: 'bg-red-50 dark:bg-red-900/20 border-red-300 dark:border-red-800',
      }[sla] || 'bg-white dark:bg-slate-800 border-slate-75 dark:border-slate-700';
    },
    slaText() {
      const t = this.activeTicket;
      if (!t) return '';
      if (t.sla_status === 'overdue') return this.$t('CASE_TICKETS.SLA_OVERDUE');

      const targetMin = t.first_response_at
        ? t.resolution_time_target
        : t.first_response_time_target;
      if (!targetMin) return '';

      const elapsedMin = (Date.now() - new Date(t.created_at).getTime()) / 60000;
      const remaining = Math.max(0, targetMin - elapsedMin);
      const h = Math.floor(remaining / 60);
      const m = Math.floor(remaining % 60);
      return h > 0 ? `${h}h ${m}min` : `${m}min`;
    },
  },
  watch: {
    contactId(newId) {
      if (newId) this.fetchTicket();
    },
  },
  mounted() {
    this.fetchTicket();
  },
  methods: {
    fetchTicket() {
      if (!this.contactId) return;
      this.$store.dispatch('caseTickets/fetchActiveTicket', {
        contactId: this.contactId,
      });
    },
    priorityBadge(p) {
      return {
        low:    'bg-slate-100 text-slate-700 dark:bg-slate-700 dark:text-slate-300',
        medium: 'bg-blue-100 text-blue-800 dark:bg-blue-900 dark:text-blue-300',
        high:   'bg-yellow-100 text-yellow-800 dark:bg-yellow-900 dark:text-yellow-300',
        urgent: 'bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-300',
      }[p] || 'bg-slate-100 text-slate-700';
    },
    slaBadge(sla) {
      return {
        on_time: 'bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-300',
        at_risk: 'bg-yellow-100 text-yellow-800 dark:bg-yellow-900 dark:text-yellow-300',
        overdue: 'bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-300',
      }[sla] || 'bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-300';
    },
    statusLabel(key) {
      return this.$t(`CASE_TICKETS.STATUSES.${key}`) || key;
    },
    priorityLabel(key) {
      return this.$t(`CASE_TICKETS.PRIORITIES.${key}`) || key;
    },
    onTicketCreated() {
      this.fetchTicket();
    },
    async transitionTo(newStatus) {
      this.showTransitionMenu = false;
      try {
        await this.$store.dispatch('caseTickets/transitionTicket', {
          ticketId: this.activeTicket.id,
          contactId: this.contactId,
          status: newStatus,
        });
      } catch (_e) {
        // silent — la API responderá con error si la transición no es válida
      }
    },
  },
};
</script>
