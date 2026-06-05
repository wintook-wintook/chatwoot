<!--
  @tickets_cases
  Vista de detalle de un CaseTicket — timeline + acciones. Tailwind + dark mode.
-->
<template>
  <div class="flex flex-col flex-1 w-full h-full overflow-hidden bg-slate-25 dark:bg-slate-900">
    <!-- Header -->
    <div class="flex flex-col flex-shrink-0 gap-2 px-6 py-4 bg-white border-b dark:bg-slate-900 border-slate-50 dark:border-slate-800/50">
      <woot-button
        size="small"
        variant="clear"
        color-scheme="secondary"
        icon="arrow-left"
        class="self-start"
        @click="$router.push({ name: 'gestorTickets_index' })"
      >
        Volver
      </woot-button>

      <div v-if="ticket" class="flex items-start justify-between gap-4">
        <div class="flex flex-col gap-1 min-w-0">
          <div class="flex flex-wrap gap-1">
            <span v-if="ticket.case_type" class="px-1.5 py-0.5 text-[11px] font-medium uppercase tracking-wide rounded text-white" :style="{ backgroundColor: ticket.case_type.color }">{{ ticket.case_type.name }}</span>
            <span class="px-1.5 py-0.5 text-[11px] font-medium uppercase tracking-wide rounded bg-slate-100 text-slate-800 dark:bg-slate-700 dark:text-slate-300">{{ statusLabel(ticket.status) }}</span>
            <span class="px-1.5 py-0.5 text-[11px] font-medium uppercase tracking-wide rounded" :class="priorityBadge(ticket.priority)">{{ priorityLabel(ticket.priority) }}</span>
            <span class="px-1.5 py-0.5 text-[11px] font-medium uppercase tracking-wide rounded" :class="slaBadge(ticket.sla_status)">SLA: {{ slaText }}</span>
          </div>
          <span v-if="ticket.folio" class="font-mono text-xs text-slate-400 dark:text-slate-500">{{ ticket.folio }}</span>
          <h2 class="m-0 text-xl font-bold text-slate-800 dark:text-slate-100">{{ ticket.title }}</h2>
          <p v-if="ticket.description" class="m-0 text-sm text-slate-600 dark:text-slate-300">{{ ticket.description }}</p>
        </div>

        <!-- Acciones -->
        <div class="relative flex-shrink-0">
          <woot-button
            size="small"
            color-scheme="primary"
            :is-loading="isTransitioning"
            @click="showTransitionMenu = !showTransitionMenu"
          >
            Cambiar estado ▾
          </woot-button>
          <ul
            v-if="showTransitionMenu"
            class="absolute right-0 z-50 py-1 mt-1 list-none bg-white border rounded-md shadow-md dark:bg-slate-800 border-slate-100 dark:border-slate-700 min-w-[180px]"
          >
            <li
              v-for="s in validTransitions"
              :key="s"
              class="px-4 py-2 text-sm cursor-pointer text-slate-600 dark:text-slate-300 hover:bg-slate-50 dark:hover:bg-slate-700"
              @click="transitionTo(s)"
            >
              {{ statusLabel(s) }}
            </li>
            <li v-if="!validTransitions.length" class="px-4 py-2 text-sm text-slate-400 dark:text-slate-500">
              Sin transiciones disponibles
            </li>
          </ul>
        </div>
      </div>
    </div>

    <!-- Loading -->
    <div v-if="!ticket && isFetchingList" class="flex items-center justify-center flex-1 text-slate-400 dark:text-slate-500">
      <span>Cargando ticket...</span>
    </div>

    <div v-else-if="ticket" class="flex flex-col flex-1 gap-6 p-6 overflow-y-auto">
      <!-- Información -->
      <div class="p-4 bg-white border rounded-lg dark:bg-slate-800 border-slate-75 dark:border-slate-700">
        <h3 class="mb-4 text-base font-semibold text-slate-800 dark:text-slate-100">Información</h3>
        <div class="grid grid-cols-2 gap-4">
          <div class="flex flex-col gap-0.5">
            <span class="text-xs tracking-wide uppercase text-slate-400 dark:text-slate-500">Tipo</span>
            <span class="text-sm font-medium text-slate-700 dark:text-slate-200">{{ ticket.case_type ? ticket.case_type.name : '—' }}</span>
          </div>
          <div class="flex flex-col gap-0.5">
            <span class="text-xs tracking-wide uppercase text-slate-400 dark:text-slate-500">Prioridad</span>
            <span class="text-sm font-medium text-slate-700 dark:text-slate-200">{{ priorityLabel(ticket.priority) }}</span>
          </div>
          <div class="flex flex-col gap-0.5">
            <span class="text-xs tracking-wide uppercase text-slate-400 dark:text-slate-500">Estado</span>
            <span class="text-sm font-medium text-slate-700 dark:text-slate-200">{{ statusLabel(ticket.status) }}</span>
          </div>
          <div class="flex flex-col gap-0.5">
            <span class="text-xs tracking-wide uppercase text-slate-400 dark:text-slate-500">SLA</span>
            <span class="text-sm font-medium" :class="slaInfoColor(ticket.sla_status)">{{ slaText }}</span>
          </div>
          <div class="flex flex-col gap-0.5">
            <span class="text-xs tracking-wide uppercase text-slate-400 dark:text-slate-500">Creado</span>
            <span class="text-sm font-medium text-slate-700 dark:text-slate-200">{{ formatDate(ticket.created_at) }}</span>
          </div>
          <div v-if="ticket.resolved_at" class="flex flex-col gap-0.5">
            <span class="text-xs tracking-wide uppercase text-slate-400 dark:text-slate-500">Resuelto</span>
            <span class="text-sm font-medium text-slate-700 dark:text-slate-200">{{ formatDate(ticket.resolved_at) }}</span>
          </div>
        </div>
      </div>

      <!-- Timeline -->
      <div class="p-4 bg-white border rounded-lg dark:bg-slate-800 border-slate-75 dark:border-slate-700">
        <h3 class="mb-4 text-base font-semibold text-slate-800 dark:text-slate-100">Historial</h3>

        <div v-if="isFetchingEvents" class="text-sm text-slate-400 dark:text-slate-500">Cargando eventos...</div>
        <div v-else-if="!events.length" class="text-sm text-slate-400 dark:text-slate-500">{{ $t('CASE_TICKETS.TIMELINE.EMPTY') }}</div>

        <ul v-else class="flex flex-col gap-4 p-0 m-0 list-none">
          <li v-for="event in events" :key="event.id" class="flex items-start gap-4">
            <div class="flex-shrink-0 w-2.5 h-2.5 mt-1 rounded-full" :class="eventDotColor(event.event_type)" />
            <div class="flex-1 min-w-0">
              <p class="m-0 text-sm font-medium text-slate-700 dark:text-slate-200">
                {{ $t(`CASE_TICKETS.EVENT_TYPES.${event.event_type}`) || event.event_type }}
              </p>
              <p v-if="payloadSummary(event)" class="mt-0.5 m-0 text-sm text-slate-500 dark:text-slate-400">{{ payloadSummary(event) }}</p>
              <p class="mt-0.5 m-0 text-xs text-slate-400 dark:text-slate-500">{{ actorName(event) }} · {{ formatDate(event.created_at) }}</p>
            </div>
          </li>
        </ul>
      </div>
    </div>
  </div>
</template>

<script>
import { mapGetters } from 'vuex';

export default {
  name: 'TicketDetail',
  props: {
    ticketId: { type: Number, required: true },
  },
  data() {
    return { showTransitionMenu: false };
  },
  computed: {
    ...mapGetters({
      getTicketById:   'caseTickets/getTicketById',
      getTicketEvents: 'caseTickets/getTicketEvents',
      uiFlags:         'caseTickets/getUIFlags',
    }),
    ticket()          { return this.getTicketById(this.ticketId); },
    events()          { return this.getTicketEvents(this.ticketId); },
    isFetchingList()  { return this.uiFlags.isFetchingList; },
    isFetchingEvents(){ return this.uiFlags.isFetchingEvents; },
    isTransitioning() { return this.uiFlags.isTransitioning; },
    validTransitions(){ return this.ticket?.can_transition_to || []; },
    slaText() {
      const t = this.ticket;
      if (!t) return '';
      if (t.sla_status === 'overdue') return this.$t('CASE_TICKETS.SLA_OVERDUE');
      const target = t.first_response_at ? t.resolution_time_target : t.first_response_time_target;
      if (!target) return '—';
      const elapsed   = (Date.now() - new Date(t.created_at).getTime()) / 60000;
      const remaining = Math.max(0, target - elapsed);
      const h = Math.floor(remaining / 60);
      const m = Math.floor(remaining % 60);
      return h > 0 ? `${h}h ${m}min` : `${m}min`;
    },
  },
  mounted() {
    if (!this.ticket) {
      this.$store.dispatch('caseTickets/fetchTickets', { per_page: 1 });
    }
    this.$store.dispatch('caseTickets/fetchEvents', { ticketId: this.ticketId });
  },
  methods: {
    async transitionTo(status) {
      this.showTransitionMenu = false;
      await this.$store.dispatch('caseTickets/transitionTicket', {
        ticketId:  this.ticketId,
        contactId: this.ticket?.contact_id,
        status,
      });
      this.$store.dispatch('caseTickets/fetchTickets');
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
    slaInfoColor(sla) {
      return {
        on_time: 'text-slate-700 dark:text-slate-200',
        at_risk: 'text-yellow-600 dark:text-yellow-400',
        overdue: 'text-red-600 dark:text-red-400',
      }[sla] || 'text-slate-700 dark:text-slate-200';
    },
    eventDotColor(type) {
      const map = {
        ticket_created: 'bg-blue-500',
        resolved:       'bg-green-500',
        closed:         'bg-slate-500',
        escalated:      'bg-red-500',
        sla_overdue:    'bg-red-500',
        sla_at_risk:    'bg-yellow-500',
        reopened:       'bg-yellow-500',
      };
      return map[type] || 'bg-slate-300 dark:bg-slate-600';
    },
    statusLabel(key)   { return this.$t(`CASE_TICKETS.STATUSES.${key}`) || key; },
    priorityLabel(key) { return this.$t(`CASE_TICKETS.PRIORITIES.${key}`) || key; },
    formatDate(d) {
      if (!d) return '';
      return new Date(d).toLocaleString(undefined, {
        day: '2-digit', month: '2-digit', year: 'numeric',
        hour: '2-digit', minute: '2-digit',
      });
    },
    actorName(event) {
      if (event.actor?.name) return event.actor.name;
      return event.origin === 'bot'
        ? this.$t('CASE_TICKETS.TIMELINE.ACTOR_BOT')
        : this.$t('CASE_TICKETS.TIMELINE.ACTOR_SYSTEM');
    },
    payloadSummary(event) {
      const p = event.payload || {};
      if (p.from && p.to) return `${this.statusLabel(p.from)} → ${this.statusLabel(p.to)}`;
      if (p.content) return p.content.slice(0, 80);
      if (p.team)    return `Equipo: ${p.team}`;
      return null;
    },
  },
};
</script>
