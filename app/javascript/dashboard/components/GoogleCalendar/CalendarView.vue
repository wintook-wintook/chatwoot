<template>
  <div class="flex flex-col flex-1 h-full overflow-hidden fc-wrapper">
    <FullCalendar ref="fullCalendar" :options="calendarOptions" />
  </div>
</template>

<script>
import FullCalendar from '@fullcalendar/vue';
import dayGridPlugin from '@fullcalendar/daygrid';
import timeGridPlugin from '@fullcalendar/timegrid';
import interactionPlugin from '@fullcalendar/interaction';
import listPlugin from '@fullcalendar/list';
import esLocale from '@fullcalendar/core/locales/es';

const COLORS = ['#6366f1', '#0ea5e9', '#10b981', '#f59e0b', '#ef4444', '#8b5cf6'];
const AGENT_COLORS = ['#f43f5e', '#fb923c', '#a3e635', '#22d3ee', '#818cf8', '#e879f9'];

// Color de respaldo cuando no conocemos el calendario del evento (hash del id).
function fallbackColor(eventId) {
  return COLORS[(eventId?.charCodeAt(0) || 0) % COLORS.length];
}

function agentColor(agentId) {
  return AGENT_COLORS[(agentId || 0) % AGENT_COLORS.length];
}

export default {
  name: 'CalendarView',
  components: { FullCalendar },
  props: {
    events: { type: Array, default: () => [] },
    availability: { type: Array, default: () => [] },
    calendars: { type: Array, default: () => [] },
  },
  emits: ['rangeChanged', 'eventDropped', 'eventClicked', 'dateSelected'],
  watch: {
    events() { this.syncEvents(); },
    availability() { this.syncEvents(); },
    calendars() { this.syncEvents(); },
  },
  methods: {
    // Cada evento se pinta con el color de SU calendario (igual que Google y que el
    // swatch de la barra lateral). El calendario principal puede venir con id real o
    // con el alias 'primary', así que mapeamos ambos.
    calendarColor(calendarId) {
      const map = {};
      this.calendars.forEach(c => {
        map[c.id] = c.background_color;
        if (c.primary) map.primary = c.background_color;
      });
      return map[calendarId];
    },
    syncEvents() {
      const api = this.$refs.fullCalendar?.getApi();
      if (!api) return;
      api.removeAllEvents();

      this.events.forEach(e => {
        const calId = e.calendarId || 'primary';
        const color = this.calendarColor(calId) || fallbackColor(e.id);
        api.addEvent({
          id: e.id,
          title: e.summary || this.$t('GOOGLE_CALENDAR.EVENTS.ALL_DAY'),
          start: e.start?.dateTime || e.start?.date,
          end: e.end?.dateTime || e.end?.date,
          allDay: !e.start?.dateTime,
          backgroundColor: color,
          borderColor: color,
          extendedProps: {
            calendarId: calId,
            description: e.description || '',
            location: e.location || '',
            attendees: e.attendees || [],
          },
        });
      });

      this.availability.forEach(agent => {
        const color = agentColor(agent.agent_id);
        (agent.busy || []).forEach((period, i) => {
          api.addEvent({
            id: `busy-${agent.agent_id}-${i}`,
            start: period.start,
            end: period.end,
            display: 'background',
            backgroundColor: color + '33',
            classNames: ['fc-agent-busy'],
          });
        });
      });
    },
  },
  computed: {
    calendarOptions() {
      return {
        plugins: [dayGridPlugin, timeGridPlugin, interactionPlugin, listPlugin],
        locale: esLocale,
        initialView: 'timeGridWeek',
        headerToolbar: {
          left: 'prev,next today',
          center: 'title',
          right: 'timeGridWeek,dayGridMonth,listWeek',
        },
        buttonText: {
          today: this.$t('GOOGLE_CALENDAR.AGENDA.TODAY'),
          week: this.$t('GOOGLE_CALENDAR.CALENDAR.WEEK'),
          month: this.$t('GOOGLE_CALENDAR.CALENDAR.MONTH'),
          list: this.$t('GOOGLE_CALENDAR.CALENDAR.AGENDA'),
        },
        height: '100%',
        editable: true,
        droppable: false,
        eventDurationEditable: true,
        selectable: true,
        selectMirror: true,
        // Arrastre en un hueco → rango prellenado.
        select: info => {
          this.$emit('dateSelected', {
            start: info.startStr,
            end: info.endStr,
            allDay: info.allDay,
          });
          this.$refs.fullCalendar?.getApi().unselect();
        },
        // Clic simple en una hora → cita de 1h (o tarea si es todo el día) prellenada.
        dateClick: info => {
          const end = info.allDay
            ? info.dateStr
            : new Date(info.date.getTime() + 60 * 60 * 1000).toISOString();
          this.$emit('dateSelected', {
            start: info.dateStr,
            end,
            allDay: info.allDay,
          });
        },
        datesSet: info => {
          this.$emit('rangeChanged', {
            start: info.startStr,
            end: info.endStr,
          });
        },
        eventClick: info => {
          this.$emit('eventClicked', info.event);
        },
        eventDrop: info => {
          this.$emit('eventDropped', {
            eventId: info.event.id,
            start_time: info.event.startStr,
            end_time: info.event.endStr,
            calendar_id: info.event.extendedProps?.calendarId || 'primary',
            revert: info.revert,
          });
        },
        eventResize: info => {
          this.$emit('eventDropped', {
            eventId: info.event.id,
            start_time: info.event.startStr,
            end_time: info.event.endStr,
            calendar_id: info.event.extendedProps?.calendarId || 'primary',
            revert: info.revert,
          });
        },
      };
    },
  },
};
</script>

<style>
.fc-wrapper {
  --fc-border-color: theme('colors.slate.100');
  --fc-today-bg-color: theme('colors.woot.50 / 40%');
  --fc-event-border-color: transparent;
  --fc-button-bg-color: transparent;
  --fc-button-border-color: theme('colors.slate.200');
  --fc-button-text-color: theme('colors.slate.700');
  --fc-button-hover-bg-color: theme('colors.slate.50');
  --fc-button-hover-border-color: theme('colors.slate.300');
  --fc-button-active-bg-color: theme('colors.woot.500');
  --fc-button-active-border-color: theme('colors.woot.500');
  --fc-button-active-text-color: #fff;
}

.dark .fc-wrapper {
  --fc-border-color: theme('colors.slate.700');
  --fc-today-bg-color: theme('colors.woot.900 / 20%');
  --fc-page-bg-color: theme('colors.slate.900');
  --fc-neutral-bg-color: theme('colors.slate.800');
  --fc-button-border-color: theme('colors.slate.600');
  --fc-button-text-color: theme('colors.slate.200');
  --fc-button-hover-bg-color: theme('colors.slate.700');
  --fc-button-hover-border-color: theme('colors.slate.500');
  --fc-list-event-hover-bg-color: theme('colors.slate.700');
}

.fc-wrapper .fc {
  height: 100%;
  font-size: 0.8125rem;
}

.fc-wrapper .fc-toolbar-title {
  font-size: 1rem;
  font-weight: 600;
}

.fc-wrapper .fc-button {
  border-radius: 0.375rem;
  padding: 0.25rem 0.625rem;
  font-size: 0.8125rem;
  font-weight: 500;
}

.fc-wrapper .fc-event {
  border-radius: 0.25rem;
  padding: 1px 4px;
  font-size: 0.75rem;
  cursor: grab;
}

.fc-wrapper .fc-event:active {
  cursor: grabbing;
}

.fc-wrapper .fc-list-table {
  font-size: 0.8125rem;
}

.fc-wrapper .fc-list-day-cushion {
  background-color: theme('colors.slate.50');
  font-weight: 600;
}

.fc-wrapper .fc-list-event:hover td {
  background-color: theme('colors.woot.50 / 40%');
  cursor: pointer;
}

.dark .fc-wrapper .fc-list-day-cushion {
  background-color: theme('colors.slate.800');
}

.dark .fc-wrapper .fc-list-event:hover td {
  background-color: theme('colors.slate.700');
}

.dark .fc-wrapper .fc-list-empty {
  background-color: theme('colors.slate.900');
}
</style>
