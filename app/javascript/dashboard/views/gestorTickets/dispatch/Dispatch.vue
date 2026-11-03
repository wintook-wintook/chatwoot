<!--
  Plan-Trabajo-Campo R3 — Servicio › Despacho: el día de técnicos y vendedores. Una
  columna por persona (zona, habilidades, choques de horario y su ruta en Google
  Maps), y a la izquierda las órdenes por programar y las visitas sin técnico.
  Arrastrar una tarjeta a un técnico se la asigna; si no tiene visita, pide la
  hora y la agenda (se sincroniza con el calendario como cualquier visita).
  R5: cada visita dice si el cliente la confirmó o pidió otra fecha en su portal.
-->
<script>
import { useAlert } from 'dashboard/composables';
import FieldDispatchAPI from 'dashboard/api/fieldDispatch';
import Spinner from 'shared/components/Spinner.vue';
import { backQuery } from '../backLink';

const isoDay = date => {
  const d = new Date(date.getTime() - date.getTimezoneOffset() * 60000);
  return d.toISOString().slice(0, 10);
};

// «YYYY-MM-DD» de la URL → fecha local; si no viene o no sirve, hoy.
const dayFromQuery = value => {
  const [y, m, d] = String(value || '')
    .split('-')
    .map(Number);
  return y && m && d ? new Date(y, m - 1, d) : new Date();
};

export default {
  name: 'DispatchBoard',
  components: { Spinner },
  data() {
    return {
      // El día va en la URL (?day=) para que «Volver» desde una orden regrese al mismo.
      day: dayFromQuery(this.$route.query.day),
      board: null,
      loading: true,
      zone: '',
      area: 'all',
      dragged: null,
      pending: null,
      time: '09:00',
      duration: 60,
    };
  },
  computed: {
    zones() {
      if (!this.board) return [];
      return [
        ...new Set(this.board.technicians.map(t => t.zone).filter(Boolean)),
      ];
    },
    technicians() {
      if (!this.board) return [];
      const techs = this.board.technicians.filter(
        t => !this.zone || t.zone === this.zone
      );
      const sales = this.zone ? [] : this.board.salespeople || [];
      if (this.area === 'service') return techs;
      if (this.area === 'sales') return sales;
      // Quien es técnico y vendedor va en una sola columna.
      const merged = techs.map(tech => {
        const same = sales.find(s => s.id === tech.id);
        return same
          ? {
              ...tech,
              visits: [...tech.visits, ...same.visits],
              conflicts: [...tech.conflicts, ...same.conflicts],
            }
          : tech;
      });
      return [...merged, ...sales.filter(s => !techs.some(t => t.id === s.id))];
    },
  },
  mounted() {
    this.fetch();
  },
  methods: {
    async fetch() {
      this.loading = true;
      try {
        const { data } = await FieldDispatchAPI.board(isoDay(this.day));
        this.board = data;
      } catch (error) {
        useAlert(error?.response?.data?.error || this.$t('DISPATCH.ERROR'));
      } finally {
        this.loading = false;
      }
    },
    shift(days) {
      const next = new Date(this.day);
      next.setDate(next.getDate() + days);
      this.day = next;
      this.$router.replace({
        query: { ...this.$route.query, day: isoDay(next) },
      });
      this.fetch();
    },
    dayLabel() {
      return this.day.toLocaleDateString(undefined, {
        weekday: 'long',
        day: 'numeric',
        month: 'long',
      });
    },
    cardTitle(card) {
      return card.meeting
        ? `${this.hour(card.meeting.starts_at)} · ${card.folio || ''}`
        : card.folio;
    },
    hour(value) {
      return new Date(value).toLocaleTimeString(undefined, {
        hour: '2-digit',
        minute: '2-digit',
      });
    },
    routeUrl(tech) {
      const stops = tech.visits.map(v => v.work_address).filter(Boolean);
      if (!stops.length) return '';
      const destination = encodeURIComponent(stops[stops.length - 1]);
      const waypoints = stops.slice(0, -1).map(encodeURIComponent).join('|');
      return `https://www.google.com/maps/dir/?api=1&destination=${destination}${
        waypoints ? `&waypoints=${waypoints}` : ''
      }`;
    },
    onDragStart(card) {
      this.dragged = card;
    },
    onDrop(tech) {
      const card = this.dragged;
      this.dragged = null;
      if (!card) return;
      if (card.kind === 'visit') {
        // El supervisor cambia a quién le toca y la hora.
        this.time = this.timeOf(card.meeting.starts_at);
        this.pending = { card, tech };
      } else if (card.meeting) {
        this.assign(
          { order_id: card.id, user_id: tech.id, meeting_id: card.meeting.id },
          tech
        );
      } else {
        this.pending = { card, tech };
      }
    },
    timeOf(value) {
      const date = new Date(value);
      const pad = n => String(n).padStart(2, '0');
      return `${pad(date.getHours())}:${pad(date.getMinutes())}`;
    },
    async moveVisit(card, tech, start) {
      try {
        const { data } = await FieldDispatchAPI.moveVisit({
          meeting_id: card.meeting.id,
          user_id: tech.id,
          starts_at: start.toISOString(),
          day: isoDay(this.day),
        });
        this.board = data;
        useAlert(this.$t('DISPATCH.ASSIGNED', { name: tech.name }));
      } catch (error) {
        useAlert(error?.response?.data?.error || this.$t('DISPATCH.ERROR'));
      }
    },
    async confirmSchedule() {
      const { card, tech } = this.pending;
      const [h, m] = this.time.split(':').map(Number);
      const start = new Date(this.day);
      start.setHours(h, m, 0, 0);
      this.pending = null;
      if (card.kind === 'visit') {
        await this.moveVisit(card, tech, start);
        return;
      }
      await this.assign(
        {
          order_id: card.id,
          user_id: tech.id,
          starts_at: start.toISOString(),
          duration_minutes: this.duration,
        },
        tech
      );
    },
    async assign(payload, tech) {
      try {
        const { data } = await FieldDispatchAPI.assign({
          ...payload,
          day: isoDay(this.day),
        });
        this.board = data;
        useAlert(this.$t('DISPATCH.ASSIGNED', { name: tech.name }));
      } catch (error) {
        useAlert(error?.response?.data?.error || this.$t('DISPATCH.ERROR'));
      }
    },
    open(card) {
      if (!card.id) return; // visita sin caso
      this.$router.push({
        name: 'gestorTickets_detail',
        params: { accountId: this.$route.params.accountId, id: card.id },
        query: backQuery(this.$route, { day: isoDay(this.day) }),
      });
    },
  },
};
</script>

<template>
  <div
    class="flex flex-col flex-1 w-full h-full overflow-hidden bg-slate-25 dark:bg-slate-900"
  >
    <header
      class="flex flex-wrap items-center justify-between gap-3 px-6 pt-5 pb-3"
    >
      <div>
        <h1 class="m-0 text-xl font-bold text-slate-800 dark:text-slate-100">
          {{ $t('DISPATCH.TITLE') }}
        </h1>
        <p class="m-0 text-sm text-slate-600 dark:text-slate-300">
          {{ $t('DISPATCH.HELP') }}
        </p>
      </div>
      <div class="flex items-center gap-2">
        <select v-model="area" class="!mb-0 w-36">
          <option value="all">{{ $t('DISPATCH.AREA_ALL') }}</option>
          <option value="service">{{ $t('DISPATCH.AREA_SERVICE') }}</option>
          <option value="sales">{{ $t('DISPATCH.AREA_SALES') }}</option>
        </select>
        <select v-if="zones.length" v-model="zone" class="!mb-0 w-44">
          <option value="">{{ $t('DISPATCH.ALL_ZONES') }}</option>
          <option v-for="z in zones" :key="z" :value="z">{{ z }}</option>
        </select>
        <woot-button
          size="small"
          variant="clear"
          icon="chevron-left"
          @click="shift(-1)"
        />
        <span
          class="text-sm font-semibold capitalize text-slate-700 dark:text-slate-200"
          >{{ dayLabel() }}</span
        >
        <woot-button
          size="small"
          variant="clear"
          icon="chevron-right"
          @click="shift(1)"
        />
      </div>
    </header>

    <Spinner v-if="loading && !board" />
    <div
      v-else-if="board"
      class="flex flex-1 min-h-0 gap-3 px-6 pb-4 overflow-x-auto"
    >
      <!-- Por programar y sin técnico -->
      <aside class="flex flex-col flex-shrink-0 gap-3 overflow-y-auto w-72">
        <section
          v-for="group in ['unscheduled', 'unassigned']"
          :key="group"
          class="p-3 bg-white border rounded-lg dark:bg-slate-800 border-slate-75 dark:border-slate-700"
        >
          <h2
            class="m-0 mb-2 text-sm font-semibold text-slate-700 dark:text-slate-200"
          >
            {{ $t(`DISPATCH.${group.toUpperCase()}`) }} ({{
              board[group].length
            }})
          </h2>
          <div
            v-for="card in board[group]"
            :key="`${group}-${card.id}-${card.meeting ? card.meeting.id : 0}`"
            draggable="true"
            class="p-2 mb-2 text-sm border rounded-md cursor-grab bg-slate-25 dark:bg-slate-900 border-slate-75 dark:border-slate-700"
            @dragstart="onDragStart(card)"
            @dblclick="open(card)"
          >
            <p class="m-0 font-medium text-slate-800 dark:text-slate-100">
              {{ cardTitle(card) }}
            </p>
            <p class="m-0 truncate text-slate-600 dark:text-slate-300">
              {{ card.contact }} · {{ card.title }}
            </p>
            <p
              v-if="card.work_address"
              class="m-0 text-xs truncate text-slate-500"
            >
              {{ card.work_address }}
            </p>
          </div>
        </section>
      </aside>

      <!-- Técnicos -->
      <p v-if="!technicians.length" class="py-12 m-0 text-sm text-slate-500">
        {{ $t('DISPATCH.NO_TECHS') }}
      </p>
      <section
        v-for="tech in technicians"
        :key="tech.id"
        class="flex flex-col flex-shrink-0 p-3 bg-white border rounded-lg w-72 dark:bg-slate-800 border-slate-75 dark:border-slate-700"
        @dragover.prevent
        @drop.prevent="onDrop(tech)"
      >
        <header class="mb-2">
          <p
            class="m-0 text-sm font-semibold text-slate-800 dark:text-slate-100"
          >
            {{ tech.name }}
          </p>
          <p class="m-0 text-xs text-slate-500">
            <span v-if="tech.zone"
              >{{ $t('DISPATCH.ZONE') }}: {{ tech.zone }}</span
            >
            <span v-if="tech.skills.length">
              · {{ tech.skills.join(', ') }}</span
            >
          </p>
          <div class="flex items-center justify-between mt-1">
            <span
              v-if="tech.conflicts.length"
              class="text-xs font-medium text-red-600"
            >
              {{ $t('DISPATCH.CONFLICTS', { n: tech.conflicts.length }) }}
            </span>
            <a
              v-if="routeUrl(tech)"
              :href="routeUrl(tech)"
              target="_blank"
              rel="noopener noreferrer"
              class="ml-auto text-xs text-woot-600"
            >
              {{ $t('DISPATCH.ROUTE') }}
            </a>
          </div>
        </header>
        <p v-if="!tech.visits.length" class="m-0 text-xs text-slate-400">
          {{ $t('DISPATCH.EMPTY_COLUMN') }}
        </p>
        <div
          v-for="card in tech.visits"
          :key="card.meeting.id"
          draggable="true"
          class="p-2 mb-2 text-sm border rounded-md cursor-grab"
          :class="
            tech.conflicts.includes(card.meeting.id)
              ? 'border-red-300 bg-red-50 dark:bg-red-900/20'
              : 'border-slate-75 bg-slate-25 dark:bg-slate-900 dark:border-slate-700'
          "
          @dragstart="onDragStart(card)"
          @dblclick="open(card)"
        >
          <p class="m-0 font-medium text-slate-800 dark:text-slate-100">
            <span class="text-woot-600">{{
              hour(card.meeting.starts_at)
            }}</span>
            <template v-if="card.folio">· {{ card.folio }}</template>
            <span
              v-if="tech.conflicts.includes(card.meeting.id)"
              class="text-xs text-red-600"
            >
              · {{ $t('DISPATCH.CONFLICT') }}</span
            >
          </p>
          <p class="m-0 truncate text-slate-600 dark:text-slate-300">
            {{ card.contact }} · {{ card.title }}
          </p>
          <p
            v-if="card.work_address"
            class="m-0 text-xs truncate text-slate-500"
          >
            {{ card.work_address }}
          </p>
          <!-- Plan-Trabajo-Campo R5 — lo que contestó el cliente desde su portal -->
          <p
            v-if="card.customer_response"
            class="m-0 mt-1 text-xs font-medium"
            :class="
              card.customer_response.status === 'confirmed'
                ? 'text-green-700 dark:text-green-400'
                : 'text-yellow-700 dark:text-yellow-400'
            "
          >
            {{
              card.customer_response.status === 'confirmed'
                ? $t('DISPATCH.CUSTOMER_CONFIRMED')
                : $t('DISPATCH.CUSTOMER_RESCHEDULE', {
                    preferred: card.customer_response.preferred || '—',
                  })
            }}
          </p>
        </div>
      </section>
    </div>

    <!-- Hora de la visita -->
    <woot-modal
      v-if="pending"
      show
      :on-close="() => (pending = null)"
      size="small"
    >
      <woot-modal-header
        :header-title="
          $t('DISPATCH.SCHEDULE_TITLE', {
            folio: pending.card.folio || pending.card.title,
            name: pending.tech.name,
          })
        "
      />
      <form
        class="flex flex-col self-stretch w-full gap-2"
        @submit.prevent="confirmSchedule"
      >
        <div class="grid grid-cols-2 gap-3">
          <label>
            {{ $t('DISPATCH.TIME') }}
            <input v-model="time" type="time" required />
          </label>
          <label v-if="pending.card.kind !== 'visit'">
            {{ $t('DISPATCH.DURATION') }}
            <input v-model.number="duration" type="number" min="15" step="15" />
          </label>
        </div>
        <div class="flex justify-end gap-2">
          <button type="button" class="button clear" @click="pending = null">
            {{ $t('DISPATCH.CANCEL') }}
          </button>
          <woot-submit-button :button-text="$t('DISPATCH.SCHEDULE')" />
        </div>
      </form>
    </woot-modal>
  </div>
</template>
