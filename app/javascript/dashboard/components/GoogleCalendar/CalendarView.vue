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
import esLocale from '@fullcalendar/core/locales/es';

const COLORS = ['#6366f1', '#0ea5e9', '#10b981', '#f59e0b', '#ef4444', '#8b5cf6'];

function eventColor(eventId) {
  return COLORS[(eventId?.charCodeAt(0) || 0) % COLORS.length];
}

export default {
  name: 'CalendarView',
  components: { FullCalendar },
  props: {
    events: { type: Array, default: () => [] },
  },
  emits: ['rangeChanged', 'eventDropped'],
  watch: {
    events(newEvents) {
      const api = this.$refs.fullCalendar?.getApi();
      if (!api) return;
      api.removeAllEvents();
      newEvents.forEach(e => {
        api.addEvent({
          id: e.id,
          title: e.summary || this.$t('GOOGLE_CALENDAR.EVENTS.ALL_DAY'),
          start: e.start?.dateTime || e.start?.date,
          end: e.end?.dateTime || e.end?.date,
          allDay: !e.start?.dateTime,
          backgroundColor: eventColor(e.id),
          borderColor: eventColor(e.id),
        });
      });
    },
  },
  computed: {
    calendarOptions() {
      return {
        plugins: [dayGridPlugin, timeGridPlugin, interactionPlugin],
        locale: esLocale,
        initialView: 'timeGridWeek',
        headerToolbar: {
          left: 'prev,next today',
          center: 'title',
          right: 'timeGridWeek,dayGridMonth',
        },
        buttonText: {
          today: this.$t('GOOGLE_CALENDAR.AGENDA.TODAY'),
          week: this.$t('GOOGLE_CALENDAR.CALENDAR.WEEK'),
          month: this.$t('GOOGLE_CALENDAR.CALENDAR.MONTH'),
        },
        height: '100%',
        editable: true,
        droppable: false,
        eventDurationEditable: true,
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
            revert: info.revert,
          });
        },
        eventResize: info => {
          this.$emit('eventDropped', {
            eventId: info.event.id,
            start_time: info.event.startStr,
            end_time: info.event.endStr,
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
</style>
