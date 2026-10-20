<!--
  @tickets_cases — Plan-Clase-Proyecto P3
  Línea de tiempo del proyecto: una pista del inicio al final (la fecha objetivo o
  lo último que haya), con la marca de «Hoy» y la de la fecha objetivo, y encima
  los hitos (rombo) y los casos con fecha (círculo). El estado va por forma +
  color + texto, nunca solo por color: hecho (verde), vencido (rojo), pendiente
  (gris). Debajo, la misma información en lista ordenada por fecha (la vista
  accesible). Clic en un caso → abre su ficha.
-->
<script>
import CaseTicketsAPI from 'dashboard/api/caseTickets';
import { formatDay } from 'dashboard/helper/caseCommercial';

const DAY = 86400000;
const toTime = iso =>
  new Date(`${String(iso).slice(0, 10)}T00:00:00`).getTime();

export default {
  name: 'ProjectTimeline',
  props: {
    ticket: { type: Object, required: true },
  },
  emits: ['open'],
  data() {
    return { data: null, isLoading: false };
  },
  computed: {
    items() {
      return this.data?.items || [];
    },
    // Extremos de la pista: del inicio a lo más lejano entre objetivo, hoy y
    // el último elemento (así nada queda fuera).
    range() {
      if (!this.data) return null;
      const start = toTime(this.data.start_on);
      const ends = [toTime(this.data.today)];
      if (this.data.due_on) ends.push(toTime(this.data.due_on));
      this.items.forEach(i => ends.push(toTime(i.date)));
      const end = Math.max(...ends, start + DAY);
      return { start, end };
    },
    todayPct() {
      return this.pct(this.data.today);
    },
    duePct() {
      return this.data?.due_on ? this.pct(this.data.due_on) : null;
    },
  },
  watch: {
    // Los cambios del proyecto (casos, hitos, fechas) llegan con el ticket.
    ticket() {
      this.load();
    },
  },
  mounted() {
    this.load();
  },
  methods: {
    async load() {
      this.isLoading = true;
      try {
        const res = await CaseTicketsAPI.getProjectTimeline(this.ticket.id);
        this.data = res.data;
      } catch (_e) {
        this.data = null;
      } finally {
        this.isLoading = false;
      }
    },
    pct(iso) {
      const { start, end } = this.range;
      return Math.min(
        100,
        Math.max(0, ((toTime(iso) - start) / (end - start)) * 100)
      );
    },
    day(iso) {
      return formatDay(iso);
    },
    state(item) {
      if (item.done) return 'done';
      return item.overdue ? 'overdue' : 'pending';
    },
    stateLabel(item) {
      return this.$t(`CASE_TICKETS.PROJECT.TIMELINE.STATE.${this.state(item)}`);
    },
    markerClass(item) {
      return {
        done: 'bg-emerald-500 dark:bg-emerald-400',
        overdue: 'bg-red-500 dark:bg-red-400',
        pending: 'bg-slate-400 dark:bg-slate-500',
      }[this.state(item)];
    },
    textClass(item) {
      return {
        done: 'text-emerald-700 dark:text-emerald-300',
        overdue: 'text-red-700 dark:text-red-300',
        pending: 'text-slate-500 dark:text-slate-400',
      }[this.state(item)];
    },
    tooltip(item) {
      const what =
        item.kind === 'milestone'
          ? this.$t('CASE_TICKETS.PROJECT.TIMELINE.MILESTONE')
          : item.folio || `#${item.id}`;
      return `${what} · ${item.title}\n${this.day(
        item.date
      )} · ${this.stateLabel(item)}`;
    },
    openItem(item) {
      if (item.kind === 'case') this.$emit('open', item.id);
    },
  },
};
</script>

<template>
  <div
    class="flex flex-col gap-3 p-4 bg-white border rounded-lg dark:bg-slate-800 border-slate-75 dark:border-slate-700"
  >
    <div class="flex flex-wrap items-center gap-x-4 gap-y-1">
      <h3 class="m-0 text-sm font-semibold text-slate-800 dark:text-slate-100">
        {{ $t('CASE_TICKETS.PROJECT.TIMELINE.TITLE') }}
      </h3>
      <!-- Leyenda: forma + texto (el color no es lo único que distingue) -->
      <span
        class="flex flex-wrap items-center gap-3 text-xs text-slate-500 dark:text-slate-400"
      >
        <span class="inline-flex items-center gap-1">
          <span class="inline-block w-2.5 h-2.5 rotate-45 bg-slate-400" />
          {{ $t('CASE_TICKETS.PROJECT.TIMELINE.MILESTONE') }}
        </span>
        <span class="inline-flex items-center gap-1">
          <span class="inline-block w-2.5 h-2.5 rounded-full bg-slate-400" />
          {{ $t('CASE_TICKETS.PROJECT.TIMELINE.CASE') }}
        </span>
        <span class="inline-flex items-center gap-1">
          <span class="inline-block w-0.5 h-3 bg-woot-500" />
          {{ $t('CASE_TICKETS.PROJECT.TIMELINE.TODAY') }}
        </span>
        <span class="inline-flex items-center gap-1">
          <span
            class="inline-block w-0 h-3 border-l-2 border-dashed border-indigo-500"
          />
          {{ $t('CASE_TICKETS.PROJECT.FIELDS.DUE') }}
        </span>
      </span>
    </div>

    <p
      v-if="isLoading && !data"
      class="m-0 text-sm text-slate-400 dark:text-slate-500"
    >
      {{ $t('CASE_TICKETS.PROJECT.TIMELINE.LOADING') }}
    </p>

    <template v-else-if="data">
      <!-- Pista -->
      <div class="relative h-14 mx-2">
        <div
          class="absolute left-0 right-0 h-1 -translate-y-1/2 rounded-full top-1/2 bg-slate-100 dark:bg-slate-700"
        />
        <!-- Hoy -->
        <div
          class="absolute top-0 bottom-0 w-0.5 bg-woot-500"
          :style="{ left: `${todayPct}%` }"
          :title="`${$t('CASE_TICKETS.PROJECT.TIMELINE.TODAY')} · ${day(
            data.today
          )}`"
        />
        <!-- Fecha objetivo -->
        <div
          v-if="duePct !== null"
          class="absolute top-0 bottom-0 w-0 border-l-2 border-dashed border-indigo-500"
          :style="{ left: `${duePct}%` }"
          :title="`${$t('CASE_TICKETS.PROJECT.FIELDS.DUE')} · ${day(
            data.due_on
          )}`"
        />
        <!-- Marcadores: el área de clic es más grande que la marca -->
        <button
          v-for="item in items"
          :key="`${item.kind}-${item.id}`"
          type="button"
          class="absolute flex items-center justify-center w-5 h-5 -translate-x-1/2 -translate-y-1/2 top-1/2"
          :class="item.kind === 'case' ? 'cursor-pointer' : 'cursor-default'"
          :style="{ left: `${pct(item.date)}%` }"
          :title="tooltip(item)"
          :aria-label="tooltip(item)"
          @click="openItem(item)"
        >
          <span
            class="block w-3 h-3 ring-2 ring-white dark:ring-slate-800"
            :class="[
              markerClass(item),
              item.kind === 'milestone' ? 'rotate-45' : 'rounded-full',
            ]"
          />
        </button>
        <!-- Extremos -->
        <span
          class="absolute bottom-0 left-0 text-[11px] tabular-nums text-slate-500 dark:text-slate-400 -translate-x-1/4"
          >{{ day(data.start_on) }}</span
        >
      </div>

      <!-- Lista (vista accesible) -->
      <p
        v-if="!items.length"
        class="m-0 text-sm text-slate-400 dark:text-slate-500"
      >
        {{ $t('CASE_TICKETS.PROJECT.TIMELINE.EMPTY') }}
      </p>
      <ul v-else class="flex flex-col gap-1 p-0 m-0 list-none">
        <li
          v-for="item in items"
          :key="`row-${item.kind}-${item.id}`"
          class="flex items-center gap-3 text-sm"
        >
          <span
            class="w-20 text-xs tabular-nums text-slate-500 dark:text-slate-400"
            >{{ day(item.date) }}</span
          >
          <span
            class="inline-block w-2.5 h-2.5 flex-shrink-0"
            :class="[
              markerClass(item),
              item.kind === 'milestone' ? 'rotate-45' : 'rounded-full',
            ]"
          />
          <button
            v-if="item.kind === 'case'"
            type="button"
            class="font-mono text-xs font-semibold text-woot-600 dark:text-woot-300 hover:underline"
            @click="openItem(item)"
          >
            {{ item.folio || `#${item.id}` }}
          </button>
          <span class="truncate text-slate-700 dark:text-slate-200">{{
            item.title
          }}</span>
          <span class="ml-auto text-xs" :class="textClass(item)">{{
            stateLabel(item)
          }}</span>
        </li>
      </ul>
    </template>
  </div>
</template>
