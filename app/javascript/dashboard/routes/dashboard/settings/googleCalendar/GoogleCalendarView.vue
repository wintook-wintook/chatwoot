<template>
  <div class="flex flex-1 h-full overflow-hidden">
    <!-- Not connected -->
    <CalendarConnectModal
      v-if="!isConnected"
      :ui-flags="uiFlags"
      @connect="connectAccount"
    />

    <!-- Connected -->
    <div v-else class="flex flex-col flex-1 overflow-hidden">
      <!-- Top bar -->
      <div class="flex items-center justify-between px-4 py-2 border-b border-slate-100 dark:border-slate-700">
        <span class="text-xs text-slate-500 dark:text-slate-400">
          {{ $t('GOOGLE_CALENDAR.CONNECTED_AS') }}
          <strong>{{ googleEmail }}</strong>
        </span>
        <div class="flex gap-2">
          <div class="relative" v-on-clickaway="closeCreateDropdown">
            <woot-button size="small" @click="toggleCreateDropdown">
              <fluent-icon icon="add" size="14" class="mr-1" />
              {{ $t('GOOGLE_CALENDAR.EVENTS.NEW_EVENT') }}
              <fluent-icon icon="chevron-down" size="12" class="ml-1" />
            </woot-button>
            <div
              v-if="showCreateDropdown"
              class="absolute right-0 top-full mt-1 w-36 bg-white dark:bg-slate-800 border border-slate-100 dark:border-slate-700 rounded-xl shadow-lg z-20 py-1 overflow-hidden"
            >
              <button
                class="w-full flex items-center gap-2 px-3 py-2 text-sm text-slate-700 dark:text-slate-200 hover:bg-slate-50 dark:hover:bg-slate-700"
                @click="openCreate('event')"
              >
                <fluent-icon icon="calendar" size="15" />
                {{ $t('GOOGLE_CALENDAR.CREATE_EVENT.TYPE.EVENT') }}
              </button>
              <button
                class="w-full flex items-center gap-2 px-3 py-2 text-sm text-slate-700 dark:text-slate-200 hover:bg-slate-50 dark:hover:bg-slate-700"
                @click="openCreate('task')"
              >
                <fluent-icon icon="checkmark-circle" size="15" />
                {{ $t('GOOGLE_CALENDAR.CREATE_EVENT.TYPE.TASK') }}
              </button>
            </div>
          </div>
          <woot-button size="small" variant="smooth" @click="showShareModal = true">
            <fluent-icon icon="send" size="14" class="mr-1" />
            {{ $t('GOOGLE_CALENDAR.SHARE_AGENDA.TITLE') }}
          </woot-button>
          <woot-button size="small" variant="smooth" color-scheme="alert" @click="disconnect">
            {{ $t('GOOGLE_CALENDAR.DISCONNECT.BUTTON') }}
          </woot-button>
        </div>
      </div>

      <div class="flex flex-1 overflow-hidden">
        <CalendarView
          :events="events"
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
      :initial-type="createType"
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
import CalendarConnectModal from '../../../../components/GoogleCalendar/CalendarConnectModal.vue';
import CalendarView from '../../../../components/GoogleCalendar/CalendarView.vue';
import AgendaWidget from '../../../../components/GoogleCalendar/AgendaWidget.vue';
import CreateEventModal from '../../../../components/GoogleCalendar/CreateEventModal.vue';
import ShareAgendaModal from '../../../../components/GoogleCalendar/ShareAgendaModal.vue';

export default {
  name: 'GoogleCalendarView',
  components: { CalendarConnectModal, CalendarView, AgendaWidget, CreateEventModal, ShareAgendaModal },
  data() {
    return { showCreateModal: false, showCreateDropdown: false, createType: 'event', editingEvent: null, createStart: '', createEnd: '', createAllDay: false, showShareModal: false, pollInterval: null, currentRange: {} };
  },
  computed: {
    ...mapGetters({
      events: 'googleCalendar/getCalendarEvents',
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
    this.$store.dispatch('agents/fetch');
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
      this.$store.dispatch('googleCalendar/fetchAvailability', this.currentRange);
    },
    connectAccount() {
      this.$store.dispatch('googleCalendar/connectAccount');
    },
    toggleCalendar(calendarId) {
      this.$store.dispatch('googleCalendar/toggleCalendar', calendarId);
    },
    toggleCreateDropdown() {
      this.showCreateDropdown = !this.showCreateDropdown;
    },
    closeCreateDropdown() {
      this.showCreateDropdown = false;
    },
    openCreate(type) {
      this.createType = type;
      this.showCreateDropdown = false;
      this.editingEvent = null;
      this.createStart = '';
      this.createEnd = '';
      this.createAllDay = false;
      this.showCreateModal = true;
    },
    onEventClicked(fcEvent) {
      this.editingEvent = fcEvent;
      this.createType = 'event';
      this.showCreateModal = true;
    },
    onDateSelected({ start, end, allDay }) {
      this.editingEvent = null;
      this.createType = allDay ? 'task' : 'event';
      this.createStart = start;
      this.createEnd = end;
      this.createAllDay = allDay;
      this.showCreateModal = true;
    },
    onModalClose() {
      this.showCreateModal = false;
      this.editingEvent = null;
    },
    async onEventDropped({ eventId, start_time, end_time, calendar_id, revert }) {
      try {
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
