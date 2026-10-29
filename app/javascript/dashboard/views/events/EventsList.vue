<!--
  Plan-Eventos E1 — Campañas › Eventos: los eventos con cuántos invitados, confirmados y
  asistentes tiene cada uno; búsqueda, filtro por estado y alta.
-->
<script>
import { mapGetters } from 'vuex';
import EventsAPI from 'dashboard/api/events';
import Spinner from 'shared/components/Spinner.vue';
import EventForm from './EventForm.vue';
import { STATUSES, eventAccess, formatDateTime } from './eventHelpers';

export default {
  name: 'EventsList',
  components: { Spinner, EventForm },
  data() {
    return {
      events: [],
      count: 0,
      page: 1,
      perPage: 50,
      loading: true,
      filters: { q: '', status: '' },
      showForm: false,
      timer: null,
    };
  },
  computed: {
    ...mapGetters({ currentUser: 'getCurrentUser' }),
    access() {
      return eventAccess(this.currentUser, this.$route.params.accountId);
    },
    statuses() {
      return STATUSES;
    },
    pages() {
      return Math.max(1, Math.ceil(this.count / this.perPage));
    },
  },
  watch: {
    'filters.status': 'reload',
  },
  mounted() {
    this.fetch();
  },
  methods: {
    formatDateTime,
    reload() {
      this.page = 1;
      this.fetch();
    },
    onSearch() {
      clearTimeout(this.timer);
      this.timer = setTimeout(this.reload, 300);
    },
    async fetch() {
      this.loading = true;
      try {
        const { data } = await EventsAPI.list({
          ...this.filters,
          page: this.page,
        });
        this.events = data.events || [];
        this.count = data.meta.count;
        this.perPage = data.meta.per_page;
      } catch {
        this.events = [];
      } finally {
        this.loading = false;
      }
    },
    goTo(page) {
      this.page = page;
      this.fetch();
    },
    open(event) {
      this.$router.push({
        name: 'event_detail',
        params: { accountId: this.$route.params.accountId, eventId: event.id },
      });
    },
    onSaved(event) {
      this.showForm = false;
      this.open(event);
    },
  },
};
</script>

<template>
  <div
    class="flex flex-col flex-1 w-full h-full overflow-hidden bg-white dark:bg-slate-900"
  >
    <header
      class="flex flex-wrap items-start justify-between gap-3 px-6 pt-5 pb-3"
    >
      <div>
        <h1 class="m-0 text-xl font-bold text-slate-800 dark:text-slate-100">
          {{ $t('EVENTS.TITLE') }}
        </h1>
        <p class="m-0 text-sm text-slate-600 dark:text-slate-300">
          {{ $t('EVENTS.DESCRIPTION') }}
        </p>
      </div>
      <woot-button
        v-if="access.canEdit"
        size="small"
        icon="add"
        @click="showForm = true"
      >
        {{ $t('EVENTS.NEW') }}
      </woot-button>
    </header>

    <div class="flex flex-wrap items-center gap-2 px-6 py-3">
      <input
        v-model="filters.q"
        type="search"
        class="!mb-0 max-w-xs"
        :placeholder="$t('EVENTS.SEARCH')"
        @input="onSearch"
      />
      <select v-model="filters.status" class="!mb-0 w-44">
        <option value="">{{ $t('EVENTS.ALL_STATUSES') }}</option>
        <option v-for="status in statuses" :key="status" :value="status">
          {{ $t(`EVENTS.STATUSES.${status}`) }}
        </option>
      </select>
      <span class="ml-auto text-xs text-slate-500">
        {{ $t('EVENTS.TOTAL', { count }) }}
      </span>
    </div>

    <div class="flex-1 px-6 pb-4 overflow-auto">
      <Spinner v-if="loading" />
      <p
        v-else-if="!events.length"
        class="py-12 text-sm text-center text-slate-500 dark:text-slate-400"
      >
        {{ $t('EVENTS.EMPTY') }}
      </p>
      <table v-else class="w-full text-sm">
        <thead>
          <tr
            class="text-left border-b text-slate-500 dark:text-slate-400 border-slate-50 dark:border-slate-800"
          >
            <th class="px-3 py-2 font-medium">
              {{ $t('EVENTS.COLUMNS.NAME') }}
            </th>
            <th class="px-3 py-2 font-medium">
              {{ $t('EVENTS.COLUMNS.DATE') }}
            </th>
            <th class="px-3 py-2 font-medium text-right">
              {{ $t('EVENTS.ATTENDEE_STATUSES.invited') }}
            </th>
            <th class="px-3 py-2 font-medium text-right">
              {{ $t('EVENTS.ATTENDEE_STATUSES.confirmed') }}
            </th>
            <th class="px-3 py-2 font-medium text-right">
              {{ $t('EVENTS.ATTENDEE_STATUSES.attended') }}
            </th>
            <th class="px-3 py-2 font-medium">
              {{ $t('EVENTS.COLUMNS.STATUS') }}
            </th>
          </tr>
        </thead>
        <tbody class="divide-y divide-slate-50 dark:divide-slate-800">
          <tr
            v-for="event in events"
            :key="event.id"
            class="cursor-pointer hover:bg-slate-25 dark:hover:bg-slate-800/50"
            @click="open(event)"
          >
            <td class="px-3 py-2">
              <span class="font-medium text-woot-600 dark:text-woot-300">
                {{ event.name }}
              </span>
              <span class="block text-xs text-slate-500">
                {{ $t(`EVENTS.KINDS.${event.kind}`) }}
                <template v-if="event.location">
                  · {{ event.location }}
                </template>
              </span>
            </td>
            <td class="px-3 py-2 whitespace-nowrap">
              {{ formatDateTime(event.starts_at) }}
            </td>
            <td class="px-3 py-2 text-right tabular-nums">
              {{ event.counts.invited }}
            </td>
            <td class="px-3 py-2 text-right tabular-nums">
              {{ event.counts.confirmed }}
            </td>
            <td class="px-3 py-2 text-right tabular-nums">
              {{ event.counts.attended }}
            </td>
            <td class="px-3 py-2 text-slate-600 dark:text-slate-300">
              {{ $t(`EVENTS.STATUSES.${event.status}`) }}
            </td>
          </tr>
        </tbody>
      </table>
      <div
        v-if="pages > 1"
        class="flex items-center justify-end gap-2 pt-3 text-sm"
      >
        <woot-button
          size="tiny"
          variant="clear"
          :disabled="page <= 1"
          icon="chevron-left"
          @click="goTo(page - 1)"
        />
        <span>{{ page }} / {{ pages }}</span>
        <woot-button
          size="tiny"
          variant="clear"
          :disabled="page >= pages"
          icon="chevron-right"
          @click="goTo(page + 1)"
        />
      </div>
    </div>

    <EventForm :show="showForm" @close="showForm = false" @saved="onSaved" />
  </div>
</template>
