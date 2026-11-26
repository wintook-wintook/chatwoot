<script>
import FullCalendar from '@fullcalendar/vue';
import dayGridPlugin from '@fullcalendar/daygrid';
import timeGridPlugin from '@fullcalendar/timegrid';
import interactionPlugin from '@fullcalendar/interaction';
import listPlugin from '@fullcalendar/list';
import esLocale from '@fullcalendar/core/locales/es';
import { agentColor, agentTextColor, coworkerColorsFrom } from './agentColor';

const COLORS = [
  '#6366f1',
  '#0ea5e9',
  '#10b981',
  '#f59e0b',
  '#ef4444',
  '#8b5cf6',
];
const LOCAL_COLOR = '#475569';

// Color de respaldo cuando no conocemos el calendario del evento (hash del id).
function fallbackColor(eventId) {
  return COLORS[(eventId?.charCodeAt(0) || 0) % COLORS.length];
}

export default {
  name: 'CalendarView',
  components: { FullCalendar },
  props: {
    events: { type: Array, default: () => [] },
    agendaItems: { type: Array, default: () => [] },
    availability: { type: Array, default: () => [] },
    calendars: { type: Array, default: () => [] },
    // fix/calendario_google — compañeros palomeados: [{ agent_id, name, access, events }].
    coworkerEvents: { type: Array, default: () => [] },
  },
  emits: [
    'rangeChanged',
    'eventDropped',
    'eventClicked',
    'dateSelected',
    'coworkerEventClicked',
  ],
  computed: {
    // fix/calendario_eliminar F4 — colores que escogí para mis compañeros (ui_settings).
    coworkerColors() {
      return coworkerColorsFrom(this.$store.getters.getUISettings);
    },
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
          // Evento de un compañero: solo se mira, nunca abre el editor.
          const coworker = info.event.extendedProps?.coworker;
          if (coworker) {
            this.$emit('coworkerEventClicked', {
              ...coworker,
              start: info.event.start,
              end: info.event.end,
              allDay: info.event.allDay,
            });
            return;
          }
          this.$emit('eventClicked', info.event);
        },
        eventDrop: info => {
          this.$emit('eventDropped', {
            eventId: info.event.id,
            start_time: info.event.startStr,
            end_time: info.event.endStr,
            calendar_id: info.event.extendedProps?.calendarId || 'primary',
            agendaItem: info.event.extendedProps?.agendaItem,
            revert: info.revert,
          });
        },
        eventResize: info => {
          this.$emit('eventDropped', {
            eventId: info.event.id,
            start_time: info.event.startStr,
            end_time: info.event.endStr,
            calendar_id: info.event.extendedProps?.calendarId || 'primary',
            agendaItem: info.event.extendedProps?.agendaItem,
            revert: info.revert,
          });
        },
      };
    },
  },
  watch: {
    events() {
      this.syncEvents();
    },
    // fix/calendario_eliminar F4 — al escoger un color se repinta al momento.
    coworkerColors() {
      this.syncEvents();
    },
    agendaItems() {
      this.syncEvents();
    },
    availability() {
      this.syncEvents();
    },
    calendars() {
      this.syncEvents();
    },
    coworkerEvents() {
      this.syncEvents();
    },
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
    itemTitle(title, item) {
      const client = item && (item.contact || item.organization);
      // Agenda: la ve por ser participante (otro es el responsable).
      const own = item?.participating
        ? `${this.$t('AGENDA_PARTICIPANTS.PARTICIPATING')} · ${title}`
        : title;
      return client ? `${own} · ${client.name}` : own;
    },
    // Lo que no vino en la lista de Google: sin Google conectado, o sin evento allá.
    addLocalItems(api) {
      const shown = new Set(this.events.map(e => e.id));
      this.agendaItems
        .filter(item => !shown.has(item.google_event_id))
        .forEach(item => {
          api.addEvent({
            id: `agenda-${item.id}`,
            title: this.itemTitle(item.title, item),
            start: new Date(item.start),
            end: new Date(item.end),
            backgroundColor: LOCAL_COLOR,
            borderColor: LOCAL_COLOR,
            extendedProps: {
              calendarId: item.google_calendar_id || 'primary',
              description: item.description || '',
              location: item.location || '',
              attendees: [],
              agendaItem: item,
            },
          });
        });
    },
    syncEvents() {
      const api = this.$refs.fullCalendar?.getApi();
      if (!api) return;
      api.removeAllEvents();

      // Plan-Agenda — cada evento de Google con su tarea; sin ella, va punteado.
      const byGoogleId = {};
      this.agendaItems.forEach(item => {
        if (item.google_event_id) byGoogleId[item.google_event_id] = item;
      });

      this.events.forEach(e => {
        const calId = e.calendarId || 'primary';
        const color = this.calendarColor(calId) || fallbackColor(e.id);
        const agendaItem = byGoogleId[e.id] || null;
        api.addEvent({
          id: e.id,
          title: this.itemTitle(
            e.summary || this.$t('GOOGLE_CALENDAR.EVENTS.ALL_DAY'),
            agendaItem
          ),
          classNames: agendaItem || !e.start?.dateTime ? [] : ['fc-no-task'],
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
            agendaItem,
            // fix/calendario_eliminar F3 — para «Eliminar evento» / «Quitar de mi calendario».
            organizerSelf: !e.organizer || e.organizer.self === true,
            recurringEventId: e.recurringEventId || null,
          },
        });
      });

      this.addLocalItems(api);

      // Los palomeados ya van como eventos: no repetir su franja de fondo.
      const shownCoworkers = new Set(this.coworkerEvents.map(c => c.agent_id));
      this.availability.forEach(agent => {
        if (shownCoworkers.has(agent.agent_id)) return;
        const color = agentColor(agent.agent_id, this.coworkerColors);
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

      this.addCoworkerEvents(api);
    },
    // Eventos de compañeros tal como Google los entregó: sin título = «Ocupado»
    // (solo libre/ocupado, o evento privado). No se arrastran ni se editan.
    addCoworkerEvents(api) {
      this.coworkerEvents.forEach(row => {
        const color = agentColor(row.agent_id, this.coworkerColors);
        const textColor = agentTextColor(row.agent_id, this.coworkerColors);
        (row.events || []).forEach(e => {
          const summary =
            e.summary || this.$t('GOOGLE_CALENDAR.COWORKERS.BUSY');
          api.addEvent({
            id: `coworker-${row.agent_id}-${e.id}`,
            title: `${row.name} · ${summary}`,
            start: e.start,
            end: e.end,
            allDay: e.all_day,
            editable: false,
            startEditable: false,
            durationEditable: false,
            backgroundColor: color,
            borderColor: color,
            textColor,
            classNames: ['fc-coworker'],
            extendedProps: {
              coworker: {
                agentId: row.agent_id,
                name: row.name,
                summary: e.summary,
                location: e.location,
                private: e.private,
              },
            },
          });
        });
      });
    },
  },
};
</script>

<template>
  <div class="flex flex-col flex-1 h-full overflow-hidden fc-wrapper">
    <FullCalendar ref="fullCalendar" :options="calendarOptions" />
  </div>
</template>

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

/* fix/calendario_google — evento de un compañero: solo lectura. */
.fc-wrapper .fc-event.fc-coworker {
  cursor: pointer;
  opacity: 0.85;
  border-style: dashed;
}

/* Plan-Agenda — evento de Google que aún no tiene tarea. */
.fc-wrapper .fc-event.fc-no-task {
  border: 1px dashed theme('colors.slate.500');
  opacity: 0.75;
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
