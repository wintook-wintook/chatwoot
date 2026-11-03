<!--
  Plan-Trabajo-Campo R2 — «Mi ruta»: las visitas del día del técnico, en orden
  de hora, con su estado y acceso directo a cómo llegar, llamar o WhatsApp.
-->
<script>
import FieldVisitsAPI from 'dashboard/api/fieldVisits';
import { mapsUrl, whatsappUrl } from './location';

const isoDay = date => {
  const d = new Date(date.getTime() - date.getTimezoneOffset() * 60000);
  return d.toISOString().slice(0, 10);
};

const STATE_COLORS = {
  pending: 'bg-slate-100 text-slate-700',
  on_the_way: 'bg-yellow-100 text-yellow-800',
  working: 'bg-woot-50 text-woot-700',
  done: 'bg-green-100 text-green-800',
};

export default {
  name: 'FieldRoute',
  data() {
    return { day: new Date(), visits: [], loading: true };
  },
  computed: {
    dayLabel() {
      if (isoDay(this.day) === isoDay(new Date()))
        return this.$t('FIELD.TODAY');
      return this.day.toLocaleDateString(undefined, {
        weekday: 'long',
        day: 'numeric',
        month: 'short',
      });
    },
  },
  mounted() {
    this.fetch();
  },
  methods: {
    async fetch() {
      this.loading = true;
      try {
        const { data } = await FieldVisitsAPI.route(isoDay(this.day));
        this.visits = data.visits || [];
      } catch {
        this.visits = [];
      } finally {
        this.loading = false;
      }
    },
    shift(days) {
      const next = new Date(this.day);
      next.setDate(next.getDate() + days);
      this.day = next;
      this.fetch();
    },
    hour(value) {
      return new Date(value).toLocaleTimeString(undefined, {
        hour: '2-digit',
        minute: '2-digit',
      });
    },
    stateColor(state) {
      return STATE_COLORS[state] || STATE_COLORS.pending;
    },
    open(visit) {
      if (visit.kind === 'visit') {
        this.$router.push({
          name: 'field_agenda_visit',
          params: {
            accountId: this.$route.params.accountId,
            meetingId: visit.meeting.id,
          },
        });
        return;
      }
      this.$router.push({
        name: 'field_visit',
        params: { accountId: this.$route.params.accountId, ticketId: visit.id },
      });
    },
    maps: mapsUrl,
    whatsapp: whatsappUrl,
  },
};
</script>

<template>
  <div class="flex flex-col gap-3">
    <div class="flex items-center justify-between">
      <woot-button
        size="small"
        variant="clear"
        icon="chevron-left"
        :title="$t('FIELD.PREV_DAY')"
        @click="shift(-1)"
      />
      <span class="text-base font-semibold capitalize text-slate-800">{{
        dayLabel
      }}</span>
      <woot-button
        size="small"
        variant="clear"
        icon="chevron-right"
        :title="$t('FIELD.NEXT_DAY')"
        @click="shift(1)"
      />
    </div>
    <p v-if="loading" class="py-8 text-center text-slate-500">
      {{ $t('FIELD.LOADING') }}
    </p>
    <p v-else-if="!visits.length" class="py-8 text-center text-slate-500">
      {{ $t('FIELD.EMPTY') }}
    </p>
    <article
      v-for="visit in visits"
      :key="visit.meeting.id"
      class="p-4 bg-white shadow-sm rounded-xl"
      @click="open(visit)"
    >
      <div class="flex items-start justify-between gap-2">
        <div class="min-w-0">
          <p class="m-0 text-sm font-semibold text-woot-600">
            {{ hour(visit.meeting.starts_at) }}
          </p>
          <p class="m-0 text-base font-semibold truncate text-slate-800">
            {{ visit.contact ? visit.contact.name : visit.organization }}
          </p>
          <p class="m-0 text-sm truncate text-slate-600">
            <template v-if="visit.folio">{{ visit.folio }} · </template>
            {{ visit.title }}
          </p>
          <p v-if="visit.work_address" class="m-0 mt-1 text-sm text-slate-500">
            {{ visit.work_address }}
          </p>
        </div>
        <span
          class="px-2 py-0.5 text-xs font-medium rounded whitespace-nowrap"
          :class="stateColor(visit.state)"
        >
          {{ $t(`FIELD.STATES.${visit.state}`) }}
        </span>
      </div>
      <div class="flex gap-2 mt-3" @click.stop>
        <a
          v-if="visit.work_address"
          :href="maps(visit.work_address)"
          target="_blank"
          rel="noopener noreferrer"
          class="flex-1 py-2 text-sm font-medium text-center rounded-lg bg-slate-100 text-slate-700"
        >
          {{ $t('FIELD.DIRECTIONS') }}
        </a>
        <a
          v-if="visit.contact && visit.contact.phone_number"
          :href="`tel:${visit.contact.phone_number}`"
          class="flex-1 py-2 text-sm font-medium text-center rounded-lg bg-slate-100 text-slate-700"
        >
          {{ $t('FIELD.CALL') }}
        </a>
        <a
          v-if="visit.contact && visit.contact.phone_number"
          :href="whatsapp(visit.contact.phone_number)"
          target="_blank"
          rel="noopener noreferrer"
          class="flex-1 py-2 text-sm font-medium text-center text-green-800 bg-green-100 rounded-lg"
        >
          {{ $t('FIELD.WHATSAPP') }}
        </a>
      </div>
    </article>
  </div>
</template>
