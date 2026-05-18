<template>
  <div class="w-72 border-l border-slate-100 dark:border-slate-700 flex flex-col h-full overflow-hidden">
    <div class="p-4 border-b border-slate-100 dark:border-slate-700">
      <h3 class="text-sm font-semibold text-slate-700 dark:text-slate-200">
        {{ $t('GOOGLE_CALENDAR.AGENDA.TITLE') }}
      </h3>
    </div>

    <div class="flex-1 overflow-y-auto p-3 space-y-2">
      <template v-if="upcomingEvents.length">
        <div
          v-for="event in upcomingEvents"
          :key="event.id"
          class="rounded-lg bg-slate-50 dark:bg-slate-800 p-3 border-l-4"
          :style="{ borderColor: eventColor(event) }"
        >
          <p class="text-xs font-semibold text-slate-800 dark:text-slate-100 truncate">
            {{ event.summary || $t('GOOGLE_CALENDAR.EVENTS.ALL_DAY') }}
          </p>
          <p class="text-xs text-slate-500 dark:text-slate-400 mt-0.5">
            {{ formatEventTime(event) }}
          </p>
        </div>
      </template>
      <p v-else class="text-xs text-slate-400 text-center py-4">
        {{ $t('GOOGLE_CALENDAR.AGENDA.EMPTY') }}
      </p>
    </div>

    <div class="p-4 border-t border-slate-100 dark:border-slate-700">
      <h3 class="text-sm font-semibold text-slate-700 dark:text-slate-200 mb-3">
        {{ $t('GOOGLE_CALENDAR.AVAILABILITY.TITLE') }}
      </h3>
      <div class="space-y-2">
        <div
          v-for="agent in availability"
          :key="agent.agent_id"
          class="flex items-center gap-2"
        >
          <span
            class="w-2 h-2 rounded-full flex-shrink-0"
            :class="agent.busy.length ? 'bg-ruby-400' : 'bg-green-400'"
          />
          <span class="text-xs text-slate-600 dark:text-slate-300 truncate">
            {{ agent.google_email }}
          </span>
        </div>
      </div>
    </div>
  </div>
</template>

<script>
import { format, isToday, isTomorrow, parseISO } from 'date-fns';

export default {
  name: 'AgendaWidget',
  props: {
    events: { type: Array, default: () => [] },
    availability: { type: Array, default: () => [] },
  },
  computed: {
    upcomingEvents() {
      const now = new Date();
      return this.events
        .filter(e => {
          const start = e.start?.dateTime || e.start?.date;
          return start && new Date(start) >= now;
        })
        .slice(0, 8);
    },
  },
  methods: {
    formatEventTime(event) {
      const start = event.start?.dateTime || event.start?.date;
      if (!start) return '';
      const date = parseISO(start);
      if (isToday(date)) return `${this.$t('GOOGLE_CALENDAR.AGENDA.TODAY')} ${format(date, 'HH:mm')}`;
      if (isTomorrow(date)) return `${this.$t('GOOGLE_CALENDAR.AGENDA.TOMORROW')} ${format(date, 'HH:mm')}`;
      return format(date, 'dd MMM HH:mm');
    },
    eventColor(event) {
      const colors = ['#6366f1', '#0ea5e9', '#10b981', '#f59e0b', '#ef4444'];
      const index = (event.id?.charCodeAt(0) || 0) % colors.length;
      return colors[index];
    },
  },
};
</script>
