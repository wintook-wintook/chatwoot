<!--
  Plan-Eventos E1 — pestaña «Eventos» del contacto: a cuáles lo invitaron, cuáles confirmó,
  a cuáles asistió y a cuáles faltó.
-->
<script>
import EventsAPI from 'dashboard/api/events';
import Spinner from 'shared/components/Spinner.vue';
import {
  attendeeChipClass,
  formatDateTime,
} from 'dashboard/views/events/eventHelpers';

export default {
  name: 'ContactEventsTab',
  components: { Spinner },
  props: {
    contactId: { type: Number, required: true },
  },
  data() {
    return { attendances: [], loading: true };
  },
  watch: {
    contactId: { immediate: true, handler: 'fetch' },
  },
  methods: {
    attendeeChipClass,
    formatDateTime,
    async fetch() {
      this.loading = true;
      try {
        const { data } = await EventsAPI.forContact(this.contactId);
        this.attendances = data.attendances || [];
      } catch {
        this.attendances = [];
      } finally {
        this.loading = false;
      }
    },
    open(event) {
      this.$router.push({
        name: 'event_detail',
        params: { accountId: this.$route.params.accountId, eventId: event.id },
      });
    },
  },
};
</script>

<template>
  <div
    class="p-4 bg-white border rounded-lg dark:bg-slate-800 border-slate-75 dark:border-slate-700"
  >
    <Spinner v-if="loading" />
    <p
      v-else-if="!attendances.length"
      class="py-6 m-0 text-sm text-center text-slate-500 dark:text-slate-400"
    >
      {{ $t('EVENTS.CONTACT_EMPTY') }}
    </p>
    <ul v-else class="flex flex-col gap-2 p-0 m-0 list-none">
      <li
        v-for="row in attendances"
        :key="row.id"
        class="flex flex-wrap items-center gap-3 px-3 py-2 border rounded-md border-slate-100 dark:border-slate-700"
      >
        <button
          type="button"
          class="p-0 font-medium text-left text-woot-600 dark:text-woot-300 hover:underline"
          @click="open(row.event)"
        >
          {{ row.event.name }}
        </button>
        <span class="text-xs text-slate-500">
          {{ $t(`EVENTS.KINDS.${row.event.kind}`) }} ·
          {{ formatDateTime(row.event.starts_at) }}
        </span>
        <span
          class="ml-auto px-2 py-0.5 text-xs font-medium rounded-full"
          :class="attendeeChipClass(row.status)"
        >
          {{ $t(`EVENTS.ATTENDEE_STATUSES.${row.status}`) }}
        </span>
      </li>
    </ul>
  </div>
</template>
