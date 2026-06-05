<!--
  @tickets_cases
  Timeline de eventos de un CaseTicket — Tailwind + dark mode.
-->
<template>
  <woot-modal :show="show" :on-close="() => $emit('close')" size="medium">
    <div class="flex flex-col overflow-hidden" style="max-height: 600px;">
      <woot-modal-header :header-title="$t('CASE_TICKETS.TIMELINE.TITLE')" />

      <div class="flex-1 px-8 pb-8 overflow-y-auto">
        <!-- Loading -->
        <div v-if="isFetchingEvents" class="flex justify-center py-8">
          <span class="text-sm text-slate-400 dark:text-slate-500">Cargando...</span>
        </div>

        <!-- Empty -->
        <div v-else-if="!events.length" class="flex justify-center py-8">
          <span class="text-sm text-slate-400 dark:text-slate-500">{{ $t('CASE_TICKETS.TIMELINE.EMPTY') }}</span>
        </div>

        <!-- Events list -->
        <ul v-else class="flex flex-col gap-2 p-0 m-0 list-none">
          <li v-for="event in events" :key="event.id" class="flex items-start gap-4">
            <div class="flex-shrink-0 w-2.5 h-2.5 mt-1 rounded-full" :class="dotColor(event.event_type)" />
            <div class="flex-1 min-w-0">
              <p class="m-0 text-sm font-medium text-slate-700 dark:text-slate-200">
                {{ $t(`CASE_TICKETS.EVENT_TYPES.${event.event_type}`) || event.event_type }}
              </p>
              <p v-if="payloadSummary(event)" class="mt-0.5 m-0 overflow-hidden text-sm whitespace-nowrap text-ellipsis text-slate-500 dark:text-slate-400">
                {{ payloadSummary(event) }}
              </p>
              <p class="mt-0.5 m-0 text-xs text-slate-400 dark:text-slate-500">
                {{ actorName(event) }} · {{ formatDate(event.created_at) }}
              </p>
            </div>
          </li>
        </ul>
      </div>

      <div class="flex justify-end px-8 pb-6">
        <woot-button variant="clear" color-scheme="secondary" @click="$emit('close')">
          {{ $t('CASE_TICKETS.TIMELINE.CLOSE') }}
        </woot-button>
      </div>
    </div>
  </woot-modal>
</template>

<script>
import { mapGetters } from 'vuex';

export default {
  name: 'CaseTimeline',
  props: {
    show: { type: Boolean, default: false },
    ticketId: { type: [Number, String], required: true },
  },
  emits: ['close'],
  computed: {
    ...mapGetters({
      getUIFlags: 'caseTickets/getUIFlags',
      getTicketEvents: 'caseTickets/getTicketEvents',
    }),
    isFetchingEvents() {
      return this.getUIFlags.isFetchingEvents;
    },
    events() {
      return this.getTicketEvents(this.ticketId);
    },
  },
  watch: {
    show(val) {
      if (val) this.load();
    },
  },
  mounted() {
    if (this.show) this.load();
  },
  methods: {
    load() {
      this.$store.dispatch('caseTickets/fetchEvents', { ticketId: this.ticketId });
    },
    dotColor(type) {
      const map = {
        ticket_created: 'bg-blue-500',
        resolved:       'bg-green-500',
        closed:         'bg-slate-500',
        escalated:      'bg-red-500',
        sla_overdue:    'bg-red-500',
        sla_at_risk:    'bg-yellow-500',
        reopened:       'bg-yellow-600',
      };
      return map[type] || 'bg-slate-300 dark:bg-slate-600';
    },
    actorName(event) {
      if (event.actor?.name) return event.actor.name;
      if (event.origin === 'bot') return this.$t('CASE_TICKETS.TIMELINE.ACTOR_BOT');
      return this.$t('CASE_TICKETS.TIMELINE.ACTOR_SYSTEM');
    },
    formatDate(dateStr) {
      if (!dateStr) return '';
      const d = new Date(dateStr);
      return d.toLocaleString(undefined, {
        day: '2-digit', month: '2-digit', year: 'numeric',
        hour: '2-digit', minute: '2-digit',
      });
    },
    payloadSummary(event) {
      const p = event.payload || {};
      if (p.from && p.to) {
        const from = this.$t(`CASE_TICKETS.STATUSES.${p.from}`) || p.from;
        const to   = this.$t(`CASE_TICKETS.STATUSES.${p.to}`)   || p.to;
        return `${from} → ${to}`;
      }
      if (p.content) return p.content.slice(0, 80);
      if (p.team)    return `Equipo: ${p.team}`;
      return null;
    },
  },
};
</script>
