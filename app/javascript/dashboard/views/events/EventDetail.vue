<!--
  Plan-Eventos E1 — página del evento: cuántos hay por estado (pestañas), la lista de
  contactos con su estado, el check-in del día («Asistió» en un clic), agregar contactos
  (buscador, un segmento guardado o CSV), quitar, editar, cerrar (los que confirmaron y no
  llegaron quedan como «no asistió») y reabrir.
-->
<script>
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import EventsAPI from 'dashboard/api/events';
import CustomViewsAPI from 'dashboard/api/customViews';
import Spinner from 'shared/components/Spinner.vue';
import ContactPicker from 'dashboard/views/gestorTickets/ContactPicker.vue';
import EventForm from './EventForm.vue';
import {
  ATTENDEE_STATUSES,
  attendeeChipClass,
  eventAccess,
  formatDateTime,
} from './eventHelpers';

export default {
  name: 'EventDetail',
  components: { Spinner, ContactPicker, EventForm },
  data() {
    return {
      event: null,
      attendees: [],
      counts: {},
      loading: true,
      filters: { status: '', q: '' },
      addStatus: 'invited',
      picked: null,
      segments: [], // Plan-Eventos E2
      segmentId: '',
      showForm: false,
      timer: null,
    };
  },
  computed: {
    ...mapGetters({ currentUser: 'getCurrentUser' }),
    access() {
      return eventAccess(this.currentUser, this.$route.params.accountId);
    },
    eventId() {
      return Number(this.$route.params.eventId);
    },
    statuses() {
      return ATTENDEE_STATUSES;
    },
    isClosed() {
      return this.event && this.event.status === 'closed';
    },
    total() {
      return Object.values(this.counts).reduce((sum, n) => sum + n, 0);
    },
    tabs() {
      return [
        { key: '', count: this.total },
        ...ATTENDEE_STATUSES.map(key => ({
          key,
          count: this.counts[key] || 0,
        })),
      ];
    },
  },
  watch: {
    eventId: 'fetch',
    'filters.status': 'fetchAttendees',
    picked(contact) {
      if (contact) this.addContact(contact);
    },
  },
  mounted() {
    this.fetch();
    this.loadSegments();
  },
  beforeDestroy() {
    clearTimeout(this.timer);
  },
  methods: {
    formatDateTime,
    attendeeChipClass,
    async fetch() {
      this.loading = true;
      try {
        const { data } = await EventsAPI.find(this.eventId);
        this.event = data.event;
        this.counts = data.event.counts || {};
        await this.fetchAttendees();
      } catch {
        this.event = null;
      } finally {
        this.loading = false;
      }
    },
    async fetchAttendees() {
      const { data } = await EventsAPI.attendees(this.eventId, this.filters);
      this.attendees = data.attendees || [];
      this.counts = data.counts || this.counts;
    },
    onSearch() {
      clearTimeout(this.timer);
      this.timer = setTimeout(this.fetchAttendees, 300);
    },
    async run(request, message = 'EVENTS.SAVED') {
      try {
        const { data } = await request();
        if (data && data.counts) this.counts = data.counts;
        useAlert(this.$t(message));
        await this.fetchAttendees();
        return data;
      } catch (error) {
        useAlert(error?.response?.data?.error || this.$t('EVENTS.ERROR'));
        return null;
      }
    },
    async loadSegments() {
      try {
        const { data } =
          await CustomViewsAPI.getCustomViewsByFilterType('contact');
        this.segments = data || [];
      } catch {
        this.segments = [];
      }
    },
    async addSegment() {
      if (!this.segmentId) return;
      try {
        const { data } = await EventsAPI.addSegment(
          this.eventId,
          this.segmentId,
          this.addStatus
        );
        this.counts = data.counts || this.counts;
        useAlert(this.$t('EVENTS.SEGMENT_ADDED', { added: data.added }));
        this.segmentId = '';
        await this.fetchAttendees();
      } catch (error) {
        useAlert(error?.response?.data?.error || this.$t('EVENTS.ERROR'));
      }
    },
    async addContact(contact) {
      await this.run(() =>
        EventsAPI.addAttendees(this.eventId, [contact.id], this.addStatus)
      );
      this.picked = null;
    },
    setStatus(attendee, status) {
      this.run(() =>
        EventsAPI.updateAttendee(this.eventId, attendee.id, status)
      );
    },
    remove(attendee) {
      // eslint-disable-next-line no-alert
      if (!window.confirm(this.$t('EVENTS.REMOVE_CONFIRM'))) return;
      this.run(() => EventsAPI.removeAttendee(this.eventId, attendee.id));
    },
    async toggleClosed() {
      if (!this.isClosed) {
        // eslint-disable-next-line no-alert
        if (!window.confirm(this.$t('EVENTS.CLOSE_CONFIRM'))) return;
      }
      const data = await this.run(() =>
        this.isClosed
          ? EventsAPI.reopen(this.eventId)
          : EventsAPI.close(this.eventId)
      );
      if (data && data.event) {
        this.event = data.event;
        this.counts = data.event.counts;
      }
    },
    async downloadTemplate() {
      const { data } = await EventsAPI.template();
      const url = URL.createObjectURL(data);
      const link = document.createElement('a');
      link.href = url;
      link.download = 'asistentes.csv';
      link.click();
      URL.revokeObjectURL(url);
    },
    async importCsv(e) {
      const [file] = e.target.files || [];
      e.target.value = '';
      if (!file) return;
      try {
        const { data } = await EventsAPI.importCsv(this.eventId, file);
        this.counts = data.counts || this.counts;
        useAlert(
          this.$t('EVENTS.IMPORT_DONE', {
            added: data.added,
            updated: data.updated,
          })
        );
        if (data.errors && data.errors.length) {
          const [first] = data.errors;
          useAlert(
            this.$t('EVENTS.IMPORT_ERRORS', {
              count: data.errors.length,
              line: first.line,
              error: first.error,
            })
          );
        }
        this.fetchAttendees();
      } catch (error) {
        useAlert(error?.response?.data?.error || this.$t('EVENTS.ERROR'));
      }
    },
    async destroy() {
      // eslint-disable-next-line no-alert
      if (!window.confirm(this.$t('EVENTS.DELETE_CONFIRM'))) return;
      try {
        await EventsAPI.remove(this.eventId);
        this.$router.push({
          name: 'events_list',
          params: { accountId: this.$route.params.accountId },
        });
      } catch {
        useAlert(this.$t('EVENTS.ERROR'));
      }
    },
    openContact(contact) {
      this.$router.push({
        name: 'contact_profile_dashboard',
        params: {
          accountId: this.$route.params.accountId,
          contactId: contact.id,
        },
      });
    },
    openCampaign(campaign) {
      this.$router.push({
        name: 'contact_trackings_campaign_detail',
        params: {
          accountId: this.$route.params.accountId,
          campaignId: campaign.id,
        },
      });
    },
    onSaved(event) {
      this.showForm = false;
      this.event = { ...this.event, ...event };
    },
  },
};
</script>

<template>
  <div
    class="flex flex-col flex-1 w-full h-full overflow-hidden bg-white dark:bg-slate-900"
  >
    <Spinner v-if="loading" class="mt-8" />
    <p
      v-else-if="!event"
      class="py-12 text-sm text-center text-slate-500 dark:text-slate-400"
    >
      {{ $t('EVENTS.NOT_FOUND') }}
    </p>
    <template v-else>
      <header
        class="flex flex-wrap items-start justify-between gap-3 px-6 pt-5 pb-3 border-b border-slate-50 dark:border-slate-800"
      >
        <div>
          <router-link
            :to="{
              name: 'events_list',
              params: { accountId: $route.params.accountId },
            }"
            class="inline-flex items-center gap-1 text-xs text-slate-500 hover:underline"
          >
            <fluent-icon icon="chevron-left" size="12" />
            {{ $t('EVENTS.TITLE') }}
          </router-link>
          <h1 class="m-0 text-xl font-bold text-slate-800 dark:text-slate-100">
            {{ event.name }}
          </h1>
          <p class="m-0 text-sm text-slate-600 dark:text-slate-300">
            {{ $t(`EVENTS.KINDS.${event.kind}`) }} ·
            {{ formatDateTime(event.starts_at) }}
            <template v-if="event.location"> · {{ event.location }}</template>
            · {{ $t(`EVENTS.STATUSES.${event.status}`) }}
          </p>
        </div>
        <div v-if="access.canEdit" class="flex flex-wrap items-center gap-2">
          <woot-button
            size="small"
            variant="smooth"
            color-scheme="secondary"
            icon="arrow-download"
            @click="downloadTemplate"
          >
            {{ $t('EVENTS.TEMPLATE') }}
          </woot-button>
          <label
            v-tooltip="$t('EVENTS.IMPORT_HELP')"
            class="mb-0 cursor-pointer button smooth secondary small"
          >
            {{ $t('EVENTS.IMPORT') }}
            <input
              type="file"
              accept=".csv,text/csv"
              class="hidden"
              @change="importCsv"
            />
          </label>
          <woot-button
            size="small"
            variant="smooth"
            color-scheme="secondary"
            icon="edit"
            @click="showForm = true"
          >
            {{ $t('EVENTS.EDIT') }}
          </woot-button>
          <woot-button
            size="small"
            :color-scheme="isClosed ? 'secondary' : 'primary'"
            @click="toggleClosed"
          >
            {{ isClosed ? $t('EVENTS.REOPEN') : $t('EVENTS.CLOSE') }}
          </woot-button>
          <woot-button
            size="small"
            variant="clear"
            color-scheme="alert"
            icon="delete"
            :title="$t('EVENTS.DELETE')"
            @click="destroy"
          />
        </div>
      </header>

      <!-- Pestañas por estado, con cuántos hay -->
      <nav
        class="flex flex-wrap gap-1 px-6 py-2 border-b border-slate-50 dark:border-slate-800"
      >
        <button
          v-for="tab in tabs"
          :key="tab.key || 'all'"
          type="button"
          class="flex items-center gap-1.5 px-3 py-1.5 text-sm rounded-md"
          :class="
            filters.status === tab.key
              ? 'bg-woot-50 text-woot-700 font-semibold dark:bg-woot-800 dark:text-woot-100'
              : 'text-slate-600 hover:bg-slate-50 dark:text-slate-300 dark:hover:bg-slate-800'
          "
          @click="filters.status = tab.key"
        >
          {{
            tab.key
              ? $t(`EVENTS.ATTENDEE_STATUSES.${tab.key}`)
              : $t('EVENTS.ALL')
          }}
          <span class="text-xs opacity-70">{{ tab.count }}</span>
        </button>
      </nav>

      <div class="flex flex-wrap items-end gap-3 px-6 py-3">
        <input
          v-model="filters.q"
          type="search"
          class="!mb-0 max-w-xs"
          :placeholder="$t('EVENTS.SEARCH_ATTENDEES')"
          @input="onSearch"
        />
        <div
          v-if="access.canEdit && !isClosed"
          class="flex items-end gap-2 ml-auto"
        >
          <label class="mb-0 text-xs text-slate-500">
            {{ $t('EVENTS.ADD_AS') }}
            <select v-model="addStatus" class="!mb-0 w-36">
              <option v-for="s in statuses" :key="s" :value="s">
                {{ $t(`EVENTS.ATTENDEE_STATUSES.${s}`) }}
              </option>
            </select>
          </label>
          <div class="w-72">
            <span class="text-xs text-slate-500">
              {{ $t('EVENTS.ADD_CONTACT') }}
            </span>
            <ContactPicker v-model="picked" />
          </div>
          <!-- Plan-Eventos E2 — todos los de un segmento guardado -->
          <label v-if="segments.length" class="mb-0 text-xs text-slate-500">
            {{ $t('EVENTS.ADD_SEGMENT') }}
            <span class="flex gap-1">
              <select v-model="segmentId" class="!mb-0 w-48">
                <option value="">{{ $t('EVENTS.CHOOSE_SEGMENT') }}</option>
                <option v-for="s in segments" :key="s.id" :value="s.id">
                  {{ s.name }}
                </option>
              </select>
              <woot-button
                size="small"
                variant="smooth"
                :disabled="!segmentId"
                @click="addSegment"
              >
                {{ $t('EVENTS.ADD') }}
              </woot-button>
            </span>
          </label>
        </div>
      </div>

      <div class="flex-1 px-6 pb-4 overflow-auto">
        <p
          v-if="!attendees.length"
          class="py-12 text-sm text-center text-slate-500 dark:text-slate-400"
        >
          {{ $t('EVENTS.NO_ATTENDEES') }}
        </p>
        <table v-else class="w-full text-sm">
          <tbody class="divide-y divide-slate-50 dark:divide-slate-800">
            <tr
              v-for="attendee in attendees"
              :key="attendee.id"
              class="hover:bg-slate-25 dark:hover:bg-slate-800/50"
            >
              <td class="px-3 py-2">
                <button
                  type="button"
                  class="p-0 font-medium text-left text-woot-600 dark:text-woot-300 hover:underline"
                  @click="openContact(attendee.contact)"
                >
                  {{ attendee.contact.name }}
                </button>
                <span class="block text-xs text-slate-500">
                  {{ attendee.contact.email || attendee.contact.phone_number }}
                </span>
              </td>
              <td class="px-3 py-2">
                <span
                  class="px-2 py-0.5 text-xs font-medium rounded-full whitespace-nowrap"
                  :class="attendeeChipClass(attendee.status)"
                >
                  {{ $t(`EVENTS.ATTENDEE_STATUSES.${attendee.status}`) }}
                </span>
              </td>
              <td class="px-3 py-2 text-xs text-slate-500 whitespace-nowrap">
                {{
                  formatDateTime(
                    attendee.attended_at ||
                      attendee.confirmed_at ||
                      attendee.invited_at
                  )
                }}
              </td>
              <td class="px-3 py-2">
                <div
                  v-if="access.canEdit"
                  class="flex items-center justify-end gap-2"
                >
                  <!-- Check-in del día en un clic -->
                  <woot-button
                    v-if="attendee.status !== 'attended'"
                    size="tiny"
                    variant="smooth"
                    color-scheme="success"
                    icon="checkmark"
                    @click="setStatus(attendee, 'attended')"
                  >
                    {{ $t('EVENTS.CHECK_IN') }}
                  </woot-button>
                  <select
                    :value="attendee.status"
                    class="!mb-0 h-7 py-0 text-xs w-32"
                    @change="setStatus(attendee, $event.target.value)"
                  >
                    <option v-for="s in statuses" :key="s" :value="s">
                      {{ $t(`EVENTS.ATTENDEE_STATUSES.${s}`) }}
                    </option>
                  </select>
                  <woot-button
                    size="tiny"
                    variant="clear"
                    color-scheme="secondary"
                    icon="dismiss"
                    :title="$t('EVENTS.REMOVE')"
                    @click="remove(attendee)"
                  />
                </div>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <!-- Plan-Eventos E3 — las campañas que tienen este evento en su apartado «Evento» -->
      <section
        v-if="event.campaigns && event.campaigns.length"
        class="px-6 py-3 border-t border-slate-50 dark:border-slate-800"
      >
        <h3
          class="mb-2 text-xs font-semibold tracking-wide uppercase text-slate-500 dark:text-slate-400"
        >
          {{ $t('EVENTS.CAMPAIGNS') }}
        </h3>
        <div class="flex flex-wrap gap-2">
          <button
            v-for="c in event.campaigns"
            :key="c.id"
            type="button"
            class="px-3 py-1.5 text-sm text-left border rounded-md border-slate-100 dark:border-slate-700 hover:bg-slate-25 dark:hover:bg-slate-800"
            @click="openCampaign(c)"
          >
            <span class="font-medium text-woot-600 dark:text-woot-300">
              {{ c.name }}
            </span>
            <span class="block text-xs text-slate-500">
              {{ $t(`EVENTS.ATTENDEE_STATUSES.${c.event_status}`) }}
            </span>
          </button>
        </div>
      </section>

      <EventForm
        :show="showForm"
        :event="event"
        @close="showForm = false"
        @saved="onSaved"
      />
    </template>
  </div>
</template>
