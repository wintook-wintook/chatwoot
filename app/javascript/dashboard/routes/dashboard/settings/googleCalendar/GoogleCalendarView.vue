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
          <!-- fix/calendario_google F3c — qué ve cada compañero de mi agenda -->
          <woot-button
            v-if="isConnected"
            size="small"
            variant="smooth"
            @click="showShareCalendar = true"
          >
            <fluent-icon icon="people" size="14" class="mr-1" />
            {{ $t('GOOGLE_CALENDAR.SHARE_CALENDAR.BUTTON') }}
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
          :coworker-events="coworkerEventRows"
          class="flex-1"
          @rangeChanged="fetchData"
          @eventDropped="onEventDropped"
          @eventClicked="onEventClicked"
          @dateSelected="onDateSelected"
          @coworkerEventClicked="onCoworkerEventClicked"
        />
        <AgendaWidget
          :events="events"
          :calendars="calendars"
          :agents="agents"
          :coworkers="coworkers"
          :selected-coworker-ids="selectedCoworkerIds"
          :coworkers-error="coworkersError"
          :coworker-events="coworkerEvents"
          :google-email="googleEmail || ''"
          @toggleCalendar="toggleCalendar"
          @toggleCoworker="toggleCoworker"
          @openShareCalendar="showShareCalendar = true"
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
      @cancelItem="openCancelItem"
    />

    <!-- fix/calendario_eliminar F2 — cancelar la tarea agendada con motivo (la de Tickets) -->
    <CancelItemModal
      :show="!!cancelTarget"
      :item="cancelTarget"
      kind="meeting"
      :busy="cancelBusy"
      :error="cancelError"
      @close="cancelTarget = null"
      @reschedule="rescheduleInstead"
      @submit="submitCancel"
    />

    <ShareAgendaModal
      :show="showShareModal"
      @close="showShareModal = false"
    />

    <!-- fix/calendario_google F3c — con quién comparto mi calendario -->
    <ShareCalendarModal
      :show="showShareCalendar"
      @close="showShareCalendar = false"
    />

    <!-- fix/calendario_google — evento de un compañero: solo lectura -->
    <woot-modal
      :show="!!coworkerEvent"
      :on-close="closeCoworkerEvent"
      size="small"
    >
      <woot-modal-header
        :header-title="coworkerEventTitle"
        :header-content="$t('GOOGLE_CALENDAR.COWORKERS.EVENT_MODAL.READ_ONLY')"
      />
      <div class="px-8 pb-8 pt-2 space-y-3">
        <p class="text-sm font-medium text-slate-800 dark:text-slate-100">
          {{ coworkerEventSummary }}
        </p>
        <p
          v-if="coworkerEventIsPrivate"
          class="text-xs text-slate-500 dark:text-slate-400"
        >
          {{ $t('GOOGLE_CALENDAR.COWORKERS.EVENT_MODAL.PRIVATE') }}
        </p>
        <div class="text-sm text-slate-600 dark:text-slate-300">
          <span class="font-medium">{{ eventLabels.when }}:</span>
          {{ coworkerEventWhen }}
        </div>
        <div
          v-if="coworkerEventLocation"
          class="text-sm text-slate-600 dark:text-slate-300"
        >
          <span class="font-medium">{{ eventLabels.where }}:</span>
          {{ coworkerEventLocation }}
        </div>
        <div class="flex justify-end">
          <woot-button variant="clear" @click="closeCoworkerEvent">
            {{ $t('GOOGLE_CALENDAR.COWORKERS.EVENT_MODAL.CLOSE') }}
          </woot-button>
        </div>
      </div>
    </woot-modal>
  </div>
</template>

<script>
import { mapGetters } from 'vuex';
import CalendarView from '../../../../components/GoogleCalendar/CalendarView.vue';
import AgendaWidget from '../../../../components/GoogleCalendar/AgendaWidget.vue';
import CreateEventModal from '../../../../components/GoogleCalendar/CreateEventModal.vue';
import ShareAgendaModal from '../../../../components/GoogleCalendar/ShareAgendaModal.vue';
import ShareCalendarModal from '../../../../components/GoogleCalendar/ShareCalendarModal.vue';
import AgendaItemsAPI from '../../../../api/agendaItems';
import CancelItemModal from '../../../../components/cancel/CancelItemModal.vue';
import { useAlert } from 'dashboard/composables';
import { format } from 'date-fns';
import { es } from 'date-fns/locale';

export default {
  name: 'GoogleCalendarView',
  components: {
    CalendarView,
    AgendaWidget,
    CreateEventModal,
    ShareAgendaModal,
    ShareCalendarModal,
    CancelItemModal,
  },
  data() {
    return {
      showCreateModal: false,
      editingEvent: null,
      createStart: '',
      createEnd: '',
      createAllDay: false,
      showShareModal: false,
      pollInterval: null,
      currentRange: {},
      coworkerEvent: null,
      showShareCalendar: false,
      // fix/calendario_eliminar F2
      cancelTarget: null,
      cancelEvent: null,
      cancelBusy: false,
      cancelError: '',
    };
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
      coworkers: 'googleCalendar/getCoworkers',
      coworkerEvents: 'googleCalendar/getCoworkerEvents',
      selectedCoworkerIds: 'googleCalendar/getSelectedCoworkerIds',
      coworkersError: 'googleCalendar/getCoworkersError',
    }),
    // Solo los palomeados y que siguen compartiendo, con su nombre para el calendario.
    coworkerEventRows() {
      const names = Object.fromEntries(
        this.agents.map(a => [a.id, a.available_name || a.name])
      );
      return this.coworkerEvents
        .filter(
          r =>
            this.selectedCoworkerIds.includes(r.agent_id) && names[r.agent_id]
        )
        .map(r => ({ ...r, name: names[r.agent_id] }));
    },
    // Ventanita de solo lectura (computed: en <template> no se puede usar ?. con webpack 4).
    coworkerEventTitle() {
      const name = this.coworkerEvent ? this.coworkerEvent.name : '';
      return this.$t('GOOGLE_CALENDAR.COWORKERS.EVENT_MODAL.TITLE', { name });
    },
    coworkerEventSummary() {
      if (!this.coworkerEvent) return '';
      return (
        this.coworkerEvent.summary || this.$t('GOOGLE_CALENDAR.COWORKERS.BUSY')
      );
    },
    eventLabels() {
      return {
        when: this.$t('GOOGLE_CALENDAR.COWORKERS.EVENT_MODAL.WHEN'),
        where: this.$t('GOOGLE_CALENDAR.COWORKERS.EVENT_MODAL.WHERE'),
      };
    },
    coworkerEventIsPrivate() {
      return !!(this.coworkerEvent && this.coworkerEvent.private);
    },
    coworkerEventLocation() {
      return this.coworkerEvent ? this.coworkerEvent.location || '' : '';
    },
    coworkerEventWhen() {
      const ev = this.coworkerEvent;
      if (!ev || !ev.start) return '';
      const day = format(ev.start, "EEEE d 'de' MMMM", { locale: es });
      if (ev.allDay)
        return `${day} · ${this.$t('GOOGLE_CALENDAR.EVENTS.ALL_DAY')}`;
      const end = ev.end ? ` – ${format(ev.end, 'HH:mm')}` : '';
      return `${day} · ${format(ev.start, 'HH:mm')}${end}`;
    },
  },
  mounted() {
    if (this.$route.query.oauth === 'success' && window.opener) {
      window.close();
      return;
    }
    this.$store.dispatch('agents/get');
    this.fetchData();
    this.$store.dispatch('googleCalendar/fetchCalendars');
    this.$store.dispatch('googleCalendar/fetchCoworkers');
    // El estado de los compañeros (compartido / ocupado ahora) va con el sondeo, no con la semana.
    this.pollInterval = setInterval(() => {
      this.fetchData(this.currentRange);
      this.$store.dispatch('googleCalendar/fetchCoworkers');
    }, 30000);
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
      this.$store.dispatch(
        'googleCalendar/fetchCoworkerEvents',
        this.currentRange
      );
    },
    toggleCoworker(agentId) {
      this.$store.dispatch('googleCalendar/toggleCoworker', { agentId });
    },
    onCoworkerEventClicked(payload) {
      this.coworkerEvent = payload;
    },
    closeCoworkerEvent() {
      this.coworkerEvent = null;
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
    // fix/calendario_eliminar F2 — la ventana del evento se cierra y abre «Cancelar con motivo»
    // (no una ventana encima de otra). «Reprogramar» la vuelve a abrir para cambiar la hora.
    openCancelItem(item) {
      this.cancelEvent = this.editingEvent;
      this.onModalClose();
      this.cancelError = '';
      this.cancelTarget = {
        ...item,
        has_client: !!(item.contact || item.organization || item.case_ticket),
      };
    },
    rescheduleInstead() {
      this.cancelTarget = null;
      this.editingEvent = this.cancelEvent;
      this.showCreateModal = !!this.cancelEvent;
    },
    async submitCancel(reason) {
      this.cancelBusy = true;
      this.cancelError = '';
      try {
        const { data } = await AgendaItemsAPI.updateItem(this.cancelTarget.id, {
          ...reason,
          status: 'cancelled',
        });
        let notice = 'GOOGLE_CALENDAR.EDIT_EVENT.CANCEL_ITEM_DONE';
        if (data.client_notice) {
          notice = data.client_notice.sent
            ? 'CANCEL_ITEM.NOTICE_SENT'
            : 'CANCEL_ITEM.NOTICE_FAILED';
        }
        useAlert(this.$t(notice));
        this.cancelTarget = null;
        this.cancelEvent = null;
        this.fetchData();
      } catch (e) {
        this.cancelError = e.response?.data?.error || '';
      } finally {
        this.cancelBusy = false;
      }
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
