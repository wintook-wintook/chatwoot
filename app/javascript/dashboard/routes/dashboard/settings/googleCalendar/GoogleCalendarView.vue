<template>
  <div class="flex flex-1 h-full overflow-hidden">
    <!-- Plan-Agenda — sin Google también se agenda; conectarlo es opcional. -->
    <div class="flex flex-col flex-1 overflow-hidden">
      <!-- Top bar -->
      <div class="flex items-center justify-between px-4 py-2 border-b border-slate-100 dark:border-slate-700">
        <span class="text-xs text-slate-500 dark:text-slate-400">
          <template v-if="isConnected">
            {{ $t('GOOGLE_CALENDAR.CONNECTED_AS') }}
            <strong>{{ googleEmail }}</strong>
            · {{ $t('GOOGLE_CALENDAR.AGENDA_LINK.LEGEND_NO_TASK') }}
          </template>
          <template v-else>
            {{ $t('GOOGLE_CALENDAR.AGENDA_LINK.NOT_CONNECTED') }}
          </template>
        </span>
        <div class="flex gap-2">
          <woot-button size="small" @click="openCreate">
            <fluent-icon icon="add" size="14" class="mr-1" />
            {{ $t('GOOGLE_CALENDAR.EVENTS.NEW_EVENT') }}
          </woot-button>
          <woot-button
            v-if="!isConnected"
            size="small"
            variant="smooth"
            icon="brand-google"
            :is-loading="uiFlags.isConnecting"
            @click="connectAccount"
          >
            {{ $t('GOOGLE_CALENDAR.CONNECT.BUTTON') }}
          </woot-button>
          <woot-button v-if="isConnected" size="small" variant="smooth" @click="showShareModal = true">
            <fluent-icon icon="send" size="14" class="mr-1" />
            {{ $t('GOOGLE_CALENDAR.SHARE_AGENDA.TITLE') }}
          </woot-button>
          <woot-button
            v-if="isConnected"
            size="small"
            variant="smooth"
            :is-loading="uiFlags.isConnecting"
            @click="connectAccount"
          >
            <fluent-icon icon="arrow-clockwise" size="14" class="mr-1" />
            {{ $t('GOOGLE_CALENDAR.RECONNECT.BUTTON') }}
          </woot-button>
          <woot-button v-if="isConnected" size="small" variant="smooth" color-scheme="alert" @click="disconnect">
            {{ $t('GOOGLE_CALENDAR.DISCONNECT.BUTTON') }}
          </woot-button>
        </div>
      </div>

      <div class="flex flex-1 overflow-hidden">
        <CalendarView
          :events="events"
          :agenda-items="agendaItems"
          :availability="availability"
          :calendars="calendars"
          class="flex-1"
          @rangeChanged="fetchData"
          @eventDropped="onEventDropped"
          @eventClicked="onEventClicked"
          @dateSelected="onDateSelected"
        />
        <AgendaWidget
          :events="events"
          :calendars="calendars"
          :availability="availability"
          :agents="agents"
          @toggleCalendar="toggleCalendar"
        />
      </div>
    </div>

    <CreateEventModal
      :show="showCreateModal"
      :edit-event="editingEvent"
      :initial-start="createStart"
      :initial-end="createEnd"
      :initial-all-day="createAllDay"
      @close="onModalClose"
      @created="fetchData"
    />

    <ShareAgendaModal
      :show="showShareModal"
      @close="showShareModal = false"
    />
  </div>
</template>

<script>
import { mapGetters } from 'vuex';
import CalendarView from '../../../../components/GoogleCalendar/CalendarView.vue';
import AgendaWidget from '../../../../components/GoogleCalendar/AgendaWidget.vue';
import CreateEventModal from '../../../../components/GoogleCalendar/CreateEventModal.vue';
import ShareAgendaModal from '../../../../components/GoogleCalendar/ShareAgendaModal.vue';
import AgendaItemsAPI from '../../../../api/agendaItems';

export default {
  name: 'GoogleCalendarView',
  components: { CalendarView, AgendaWidget, CreateEventModal, ShareAgendaModal },
  data() {
    return { showCreateModal: false, editingEvent: null, createStart: '', createEnd: '', createAllDay: false, showShareModal: false, pollInterval: null, currentRange: {} };
  },
  computed: {
    ...mapGetters({
      events: 'googleCalendar/getCalendarEvents',
      agendaItems: 'googleCalendar/getAgendaItems',
      calendars: 'googleCalendar/getCalendars',
      availability: 'googleCalendar/getCalendarAvailability',
      isConnected: 'googleCalendar/isCalendarConnected',
      googleEmail: 'googleCalendar/getCalendarEmail',
      uiFlags: 'googleCalendar/getCalendarUIFlags',
      agents: 'agents/getAgents',
    }),
  },
  mounted() {
    if (this.$route.query.oauth === 'success' && window.opener) {
      window.close();
      return;
    }
    this.$store.dispatch('agents/get');
    this.fetchData();
    this.$store.dispatch('googleCalendar/fetchCalendars');
    this.pollInterval = setInterval(() => this.fetchData(this.currentRange), 30000);
  },
  beforeDestroy() {
    clearInterval(this.pollInterval);
  },
  methods: {
    fetchData(range = {}) {
      if (range.start) this.currentRange = range;
      this.$store.dispatch('googleCalendar/fetchEvents', this.currentRange);
      this.$store.dispatch('googleCalendar/fetchAgendaItems', this.currentRange);
      this.$store.dispatch('googleCalendar/fetchAvailability', this.currentRange);
    },
    connectAccount() {
      this.$store.dispatch('googleCalendar/connectAccount');
    },
    toggleCalendar(calendarId) {
      this.$store.dispatch('googleCalendar/toggleCalendar', calendarId);
    },
    openCreate() {
      this.editingEvent = null;
      this.createStart = '';
      this.createEnd = '';
      this.createAllDay = false;
      this.showCreateModal = true;
    },
    onEventClicked(fcEvent) {
      this.editingEvent = fcEvent;
      this.showCreateModal = true;
    },
    onDateSelected({ start, end, allDay }) {
      this.editingEvent = null;
      this.createStart = start;
      this.createEnd = end;
      this.createAllDay = allDay;
      this.showCreateModal = true;
    },
    onModalClose() {
      this.showCreateModal = false;
      this.editingEvent = null;
    },
    async onEventDropped({ eventId, start_time, end_time, calendar_id, agendaItem, revert }) {
      try {
        // Con tarea agendada se mueve ella: lleva el cambio a Google.
        if (agendaItem) {
          await AgendaItemsAPI.updateItem(agendaItem.id, { starts_at: start_time, ends_at: end_time });
          this.fetchData();
          return;
        }
        await this.$store.dispatch('googleCalendar/updateEvent', { eventId, start_time, end_time, calendar_id });
      } catch {
        revert();
      }
    },
    async disconnect() {
      if (!confirm(this.$t('GOOGLE_CALENDAR.DISCONNECT.CONFIRM'))) return;
      await this.$store.dispatch('googleCalendar/disconnectAccount');
    },
  },
};
</script>
