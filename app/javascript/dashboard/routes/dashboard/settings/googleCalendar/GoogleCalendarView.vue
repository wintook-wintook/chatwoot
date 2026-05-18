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
          <woot-button size="small" icon="add" @click="showCreateModal = true">
            {{ $t('GOOGLE_CALENDAR.EVENTS.NEW_EVENT') }}
          </woot-button>
          <woot-button size="small" variant="smooth" color-scheme="alert" @click="disconnect">
            {{ $t('GOOGLE_CALENDAR.DISCONNECT.BUTTON') }}
          </woot-button>
        </div>
      </div>

      <div class="flex flex-1 overflow-hidden">
        <CalendarView :events="events" class="flex-1" @rangeChanged="fetchData" @eventDropped="onEventDropped" @eventClicked="onEventClicked" />
        <AgendaWidget :events="events" :availability="availability" />
      </div>
    </div>

    <CreateEventModal
      :show="showCreateModal"
      :edit-event="editingEvent"
      @close="onModalClose"
      @created="fetchData"
    />
  </div>
</template>

<script>
import { mapGetters } from 'vuex';
import CalendarConnectModal from '../../../../components/GoogleCalendar/CalendarConnectModal.vue';
import CalendarView from '../../../../components/GoogleCalendar/CalendarView.vue';
import AgendaWidget from '../../../../components/GoogleCalendar/AgendaWidget.vue';
import CreateEventModal from '../../../../components/GoogleCalendar/CreateEventModal.vue';

export default {
  name: 'GoogleCalendarView',
  components: { CalendarConnectModal, CalendarView, AgendaWidget, CreateEventModal },
  data() {
    return { showCreateModal: false, editingEvent: null, pollInterval: null, currentRange: {} };
  },
  computed: {
    ...mapGetters({
      events: 'googleCalendar/getCalendarEvents',
      availability: 'googleCalendar/getCalendarAvailability',
      isConnected: 'googleCalendar/isCalendarConnected',
      googleEmail: 'googleCalendar/getCalendarEmail',
      uiFlags: 'googleCalendar/getCalendarUIFlags',
    }),
  },
  mounted() {
    if (this.$route.query.oauth === 'success' && window.opener) {
      window.close();
      return;
    }
    this.fetchData();
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
    onEventClicked(fcEvent) {
      this.editingEvent = fcEvent;
      this.showCreateModal = true;
    },
    onModalClose() {
      this.showCreateModal = false;
      this.editingEvent = null;
    },
    async onEventDropped({ eventId, start_time, end_time, revert }) {
      try {
        await this.$store.dispatch('googleCalendar/updateEvent', { eventId, start_time, end_time });
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
