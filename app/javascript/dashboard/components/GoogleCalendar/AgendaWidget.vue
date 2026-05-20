<template>
  <div class="w-72 border-l border-slate-100 dark:border-slate-700 flex flex-col h-full overflow-hidden">
    <!-- Próximos eventos -->
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
          :style="{ borderColor: calendarColor(event.calendarId) }"
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

    <!-- Mis calendarios -->
    <div
      v-if="calendars.length"
      class="p-4 border-t border-slate-100 dark:border-slate-700"
    >
      <button
        class="w-full flex items-center justify-between mb-3 group"
        @click="calendarsExpanded = !calendarsExpanded"
      >
        <h3 class="text-sm font-semibold text-slate-700 dark:text-slate-200">
          {{ $t('GOOGLE_CALENDAR.CALENDARS.TITLE') }}
        </h3>
        <fluent-icon
          :icon="calendarsExpanded ? 'chevron-up' : 'chevron-down'"
          size="14"
          class="text-slate-400"
        />
      </button>

      <div v-if="calendarsExpanded" class="space-y-1.5">
        <label
          v-for="cal in calendars"
          :key="cal.id"
          class="flex items-center gap-2 cursor-pointer group/cal py-0.5"
        >
          <span
            class="w-3 h-3 rounded-sm flex-shrink-0 border-2 transition-all"
            :style="cal.enabled
              ? { backgroundColor: cal.background_color, borderColor: cal.background_color }
              : { borderColor: cal.background_color, backgroundColor: 'transparent' }"
          />
          <input
            type="checkbox"
            class="sr-only"
            :checked="cal.enabled"
            @change="$emit('toggleCalendar', cal.id)"
          />
          <span
            class="text-xs text-slate-600 dark:text-slate-300 truncate"
            :class="{ 'line-through opacity-50': !cal.enabled }"
          >
            {{ cal.summary }}
          </span>
        </label>

        <!-- Suscribirse a calendario externo -->
        <div v-if="showSubscribeInput" class="flex gap-1 mt-2">
          <input
            v-model="subscribeInput"
            type="text"
            class="flex-1 text-xs px-2 py-1 border border-slate-200 dark:border-slate-600 rounded-md bg-white dark:bg-slate-800 text-slate-700 dark:text-slate-200 outline-none focus:border-woot-400"
            :placeholder="$t('GOOGLE_CALENDAR.CALENDARS.SUBSCRIBE_PLACEHOLDER')"
            @keydown.enter="subscribe"
            @keydown.esc="closeSubscribeInput"
          />
          <button
            class="px-2 py-1 text-xs bg-woot-500 text-white rounded-md hover:bg-woot-600 disabled:opacity-50"
            :disabled="subscribing || !subscribeInput.trim()"
            @click="subscribe"
          >
            {{ subscribing ? '...' : $t('GOOGLE_CALENDAR.CALENDARS.SUBSCRIBE_ADD') }}
          </button>
        </div>

        <button
          v-else
          class="flex items-center gap-1 text-xs text-slate-400 hover:text-woot-500 mt-1 transition-colors"
          @click="showSubscribeInput = true"
        >
          <fluent-icon icon="add" size="12" />
          {{ $t('GOOGLE_CALENDAR.CALENDARS.SUBSCRIBE_BUTTON') }}
        </button>
      </div>
    </div>

    <!-- Disponibilidad del equipo -->
    <div
      v-if="agents.length"
      class="p-4 border-t border-slate-100 dark:border-slate-700 overflow-y-auto"
    >
      <h3 class="text-sm font-semibold text-slate-700 dark:text-slate-200 mb-3">
        {{ $t('GOOGLE_CALENDAR.AVAILABILITY.TITLE') }}
      </h3>
      <div class="space-y-2">
        <div
          v-for="agent in agentsWithStatus"
          :key="agent.id"
          class="flex items-center gap-2"
        >
          <span
            class="w-2 h-2 rounded-full flex-shrink-0"
            :class="{
              'bg-green-400': agent.calendarStatus === 'free',
              'bg-ruby-400': agent.calendarStatus === 'busy',
              'bg-slate-300 dark:bg-slate-600': agent.calendarStatus === 'not_connected',
            }"
          />
          <img
            v-if="agent.thumbnail"
            :src="agent.thumbnail"
            class="w-5 h-5 rounded-full flex-shrink-0 object-cover"
            :alt="agent.name"
          />
          <span class="text-xs text-slate-600 dark:text-slate-300 truncate flex-1">
            {{ agent.name }}
          </span>
          <span
            v-if="agent.calendarStatus === 'not_connected'"
            class="text-xs text-slate-400 dark:text-slate-500 flex-shrink-0"
          >
            {{ $t('GOOGLE_CALENDAR.AVAILABILITY.NOT_CONNECTED') }}
          </span>
          <span
            v-else-if="agent.calendarStatus === 'busy'"
            class="text-xs text-ruby-500 flex-shrink-0"
          >
            {{ $t('GOOGLE_CALENDAR.AVAILABILITY.BUSY') }}
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
    calendars: { type: Array, default: () => [] },
    availability: { type: Array, default: () => [] },
    agents: { type: Array, default: () => [] },
  },
  emits: ['toggleCalendar'],
  data() {
    return {
      calendarsExpanded: true,
      showSubscribeInput: false,
      subscribeInput: '',
      subscribing: false,
    };
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
    calendarColorMap() {
      return Object.fromEntries(this.calendars.map(c => [c.id, c.background_color]));
    },
    availabilityMap() {
      return Object.fromEntries(this.availability.map(a => [a.agent_id, a.busy || []]));
    },
    agentsWithStatus() {
      return this.agents.map(agent => {
        const busy = this.availabilityMap[agent.id];
        let calendarStatus;
        if (busy === undefined) calendarStatus = 'not_connected';
        else if (busy.length > 0) calendarStatus = 'busy';
        else calendarStatus = 'free';
        return { ...agent, calendarStatus };
      });
    },
  },
  methods: {
    async subscribe() {
      const id = this.subscribeInput.trim();
      if (!id) return;
      this.subscribing = true;
      try {
        await this.$store.dispatch('googleCalendar/subscribeCalendar', id);
        this.closeSubscribeInput();
      } catch {
        // error silently — backend sends 422 with message if calendar not found/accessible
      } finally {
        this.subscribing = false;
      }
    },
    closeSubscribeInput() {
      this.showSubscribeInput = false;
      this.subscribeInput = '';
    },
    calendarColor(calendarId) {
      return this.calendarColorMap[calendarId] || '#6366f1';
    },
    formatEventTime(event) {
      const start = event.start?.dateTime || event.start?.date;
      if (!start) return '';
      const date = parseISO(start);
      if (isToday(date)) return `${this.$t('GOOGLE_CALENDAR.AGENDA.TODAY')} ${format(date, 'HH:mm')}`;
      if (isTomorrow(date)) return `${this.$t('GOOGLE_CALENDAR.AGENDA.TOMORROW')} ${format(date, 'HH:mm')}`;
      return format(date, 'dd MMM HH:mm');
    },
  },
};
</script>
