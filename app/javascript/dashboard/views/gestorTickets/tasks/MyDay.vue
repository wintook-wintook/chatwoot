<!--
  @tickets_cases — Plan-Bandeja-Prioridad: «Mi día».
  F1: las tareas pendientes del agente en el orden sugerido (puntaje del servidor,
  Cases::TaskPriorityScore), cada una con los motivos de su lugar, y a la derecha
  la agenda de hoy (las reuniones tienen hora fija: no entran al ranking).
  F2: el agente arma SU orden del día arriba («Mi orden de hoy»): fija tareas
  (↑) o las arrastra desde «Sugeridas», y las reordena arrastrando. La primera
  de su orden es la SIGUIENTE; sin orden propio, la siguiente es la de mayor
  puntaje. Si después de armarlo llega una urgente, se avisa arriba en vez de
  desacomodarle la lista. Los cambios salen por eventos (`plan`, `postpone`…) y
  los guarda la bandeja (Tasks.vue).
-->
<script>
import draggable from 'vuedraggable';
import { LocalStorage } from 'shared/helpers/localStorage';
import { formatMinutes, localDay } from 'dashboard/helper/caseTaskPriority';
import MyDayTaskRow from './MyDayTaskRow.vue';
import MyDayAiPlan from './MyDayAiPlan.vue';
import MyDayNotices from './MyDayNotices.vue';

const DISMISSED_KEY = 'case_tickets::my_day_dismissed';

export default {
  name: 'MyDay',
  components: { Draggable: draggable, MyDayTaskRow, MyDayAiPlan, MyDayNotices },
  props: {
    rows: { type: Array, default: () => [] },
    meta: { type: Object, default: () => ({}) },
    page: { type: Number, default: 1 },
    perPage: { type: Number, default: 25 },
    completingId: { type: [Number, String], default: null },
    // F4 — la cuenta tiene activa la IA «Plan de mi día».
    aiEnabled: { type: Boolean, default: false },
  },
  emits: [
    'openTicket',
    'openTask',
    'complete',
    'openMeeting',
    'plan',
    'postpone',
  ],
  data() {
    return {
      // Copias locales para arrastrar (vuedraggable muta los arreglos).
      plan: [],
      nextRow: null,
      suggested: [],
      dismissed: [],
    };
  },
  computed: {
    hasPlan() {
      return this.plan.length > 0;
    },
    base() {
      return (this.page - 1) * this.perPage;
    },
    suggestedOffset() {
      return this.base + this.plan.length + (this.nextRow ? 1 : 0);
    },
    agenda() {
      return this.meta.agenda || [];
    },
    load() {
      return this.meta.load || { count: 0, minutes: 0, unestimated: 0 };
    },
    total() {
      return this.meta.count || 0;
    },
    // La primera urgente que llegó después de armar el día y no se ha ignorado.
    pool() {
      return this.nextRow ? [this.nextRow, ...this.suggested] : this.suggested;
    },
    // Programadas para un día que ya pasó y sin hacer (vuelven a competir).
    missedRows() {
      if (this.dismissed.includes('missed')) return [];
      const ids = this.meta.missed || [];
      return this.pool.filter(r => ids.includes(r.id));
    },
    laterCount() {
      return this.meta.later_count || 0;
    },
    // Carga de MI orden de hoy; más de 8 h se avisa.
    planTime() {
      return formatMinutes(this.load.plan_minutes);
    },
    planOverloaded() {
      return (this.load.plan_minutes || 0) > 480;
    },
    urgentRow() {
      const ids = this.meta.new_urgent || [];
      const pool = this.pool;
      return (
        pool.find(r => ids.includes(r.id) && !this.dismissed.includes(r.id)) ||
        null
      );
    },
    dismissedKey() {
      return `${DISMISSED_KEY}::${localDay()}`;
    },
  },
  watch: {
    rows: { immediate: true, handler: 'rebuild' },
  },
  mounted() {
    try {
      const saved = LocalStorage.get(this.dismissedKey);
      this.dismissed = Array.isArray(saved) ? saved : [];
    } catch (e) {
      this.dismissed = [];
    }
  },
  methods: {
    rebuild() {
      this.plan = this.rows.filter(r => r.planned);
      const rest = this.rows.filter(r => !r.planned);
      // Sin orden propio, la siguiente es la de mayor puntaje.
      this.nextRow = !this.plan.length && this.page === 1 ? rest[0] : null;
      this.suggested = this.nextRow ? rest.slice(1) : rest;
    },
    emitPlan() {
      this.$emit(
        'plan',
        this.plan.map(r => r.id)
      );
    },
    without(list, row) {
      return list.filter(r => r.id !== row.id);
    },
    take(row) {
      this.suggested = this.without(this.suggested, row);
      if (this.nextRow && this.nextRow.id === row.id) this.nextRow = null;
    },
    pin(row) {
      this.take(row);
      this.plan = [...this.plan, row];
      this.emitPlan();
    },
    pinFirst(row) {
      this.take(row);
      this.plan = [row, ...this.without(this.plan, row)];
      this.emitPlan();
    },
    unpin(row) {
      this.plan = this.without(this.plan, row);
      this.suggested = [row, ...this.suggested];
      this.emitPlan();
    },
    // Arrastrar dentro del orden, o desde/hacia «Sugeridas»: el orden ya lo
    // dejó vuedraggable en `plan`; solo se guarda.
    onPlanChange() {
      this.emitPlan();
    },
    // «Pasarlas a hoy»: las programadas que quedaron sin hacer, al final de mi orden.
    passMissed() {
      const rows = this.missedRows;
      rows.forEach(r => this.take(r));
      this.plan = [...this.plan, ...rows];
      this.emitPlan();
    },
    dismissMissed() {
      this.dismiss({ id: 'missed' });
    },
    dismiss(row) {
      this.dismissed = [...this.dismissed, row.id];
      try {
        LocalStorage.set(this.dismissedKey, this.dismissed);
      } catch (e) {
        // sin almacenamiento: el aviso vuelve al recargar, nada más.
      }
    },
    minutes(value) {
      return formatMinutes(value);
    },
    timeLabel(iso) {
      return new Date(iso).toLocaleTimeString(undefined, {
        hour: '2-digit',
        minute: '2-digit',
      });
    },
  },
};
</script>

<template>
  <div
    class="flex flex-col flex-1 min-h-0 gap-4 px-6 py-4 overflow-auto lg:flex-row"
  >
    <section class="flex flex-col flex-1 min-w-0 gap-3">
      <!-- «Tienes avisos importantes»: avisos sin leer de la campanita, por peso. -->
      <MyDayNotices />
      <!-- Carga del día: lo vencido + lo que vence hoy. -->
      <div
        class="flex flex-wrap items-center gap-x-3 gap-y-1 text-sm text-slate-600 dark:text-slate-300"
      >
        <span
          v-if="load.count"
          class="font-semibold text-slate-800 dark:text-slate-100"
        >
          {{ $t('CASE_TICKETS.TASKS.MY_DAY.LOAD', { count: load.count }) }}
        </span>
        <span v-else>{{ $t('CASE_TICKETS.TASKS.MY_DAY.LOAD_NONE') }}</span>
        <span v-if="load.minutes">
          {{
            $t('CASE_TICKETS.TASKS.MY_DAY.LOAD_TIME', {
              time: minutes(load.minutes),
            })
          }}
        </span>
        <span
          v-if="load.unestimated"
          class="text-slate-400 dark:text-slate-500"
        >
          {{
            $t('CASE_TICKETS.TASKS.MY_DAY.LOAD_UNESTIMATED', {
              count: load.unestimated,
            })
          }}
        </span>
        <span class="ml-auto text-xs text-slate-400 dark:text-slate-500">
          {{ $t('CASE_TICKETS.TASKS.MY_DAY.TOTAL', { count: total }) }}
          <template v-if="laterCount">
            ·
            {{ $t('CASE_TICKETS.TASKS.MY_DAY.LATER', { count: laterCount }) }}
          </template>
        </span>
      </div>

      <!-- F4 — «Plan de mi día» con IA (a pedido; no cambia el orden). -->
      <MyDayAiPlan
        v-if="aiEnabled && rows.length"
        :rows="rows"
        @openTask="r => $emit('openTask', r)"
        @postpone="r => $emit('postpone', r)"
      />

      <!-- Lo programado para días pasados que quedó sin hacer: tú decides. -->
      <div
        v-if="missedRows.length"
        class="flex flex-wrap items-center gap-2 px-3 py-2 text-sm border rounded-lg bg-amber-50 border-amber-200 text-amber-800 dark:bg-amber-900/30 dark:border-amber-800 dark:text-amber-300"
      >
        <fluent-icon icon="calendar-clock" size="16" />
        <span class="flex-1 min-w-0">
          {{
            $t('CASE_TICKETS.TASKS.MY_DAY.MISSED', {
              count: missedRows.length,
            })
          }}
        </span>
        <woot-button
          size="tiny"
          color-scheme="warning"
          icon="arrow-up"
          @click="passMissed"
        >
          {{ $t('CASE_TICKETS.TASKS.MY_DAY.PASS_TO_TODAY') }}
        </woot-button>
        <woot-button
          size="tiny"
          variant="clear"
          color-scheme="secondary"
          @click="dismissMissed"
        >
          {{ $t('CASE_TICKETS.TASKS.MY_DAY.IGNORE') }}
        </woot-button>
      </div>

      <!-- Nueva urgente: llegó después de armar el día; no se mete sola. -->
      <div
        v-if="urgentRow"
        class="flex flex-wrap items-center gap-2 px-3 py-2 text-sm border rounded-lg bg-red-50 border-red-200 text-red-800 dark:bg-red-900/30 dark:border-red-800 dark:text-red-300"
        role="alert"
      >
        <fluent-icon icon="alert" size="16" />
        <span class="flex-1 min-w-0">
          {{ $t('CASE_TICKETS.TASKS.MY_DAY.NEW_URGENT') }}
          <strong>{{ urgentRow.title }}</strong>
        </span>
        <woot-button
          size="tiny"
          color-scheme="alert"
          icon="arrow-up"
          @click="pinFirst(urgentRow)"
        >
          {{ $t('CASE_TICKETS.TASKS.MY_DAY.PIN_FIRST') }}
        </woot-button>
        <woot-button
          size="tiny"
          variant="clear"
          color-scheme="secondary"
          @click="dismiss(urgentRow)"
        >
          {{ $t('CASE_TICKETS.TASKS.MY_DAY.IGNORE') }}
        </woot-button>
      </div>

      <div
        v-if="!rows.length"
        class="flex flex-col items-center justify-center gap-3 py-16 text-slate-400 dark:text-slate-500"
      >
        <fluent-icon icon="checkmark-circle" size="36" />
        <p class="m-0">{{ $t('CASE_TICKETS.TASKS.MY_DAY.EMPTY') }}</p>
      </div>

      <template v-else>
        <!-- Sin orden propio: la siguiente es la de mayor puntaje. -->
        <MyDayTaskRow
          v-if="nextRow"
          :row="nextRow"
          :rank="base + 1"
          highlight
          :completing-id="completingId"
          @openTask="r => $emit('openTask', r)"
          @openTicket="r => $emit('openTicket', r)"
          @complete="r => $emit('complete', r)"
          @postpone="r => $emit('postpone', r)"
          @pin="pin"
        />

        <!-- Mi orden de hoy -->
        <div>
          <h2
            class="flex items-baseline gap-2 m-0 mb-2 text-xs font-semibold tracking-wide uppercase text-slate-500 dark:text-slate-400"
          >
            {{ $t('CASE_TICKETS.TASKS.MY_DAY.MY_ORDER') }}
            <span
              v-if="hasPlan"
              class="font-normal normal-case tracking-normal text-slate-400 dark:text-slate-500"
            >
              {{ $t('CASE_TICKETS.TASKS.MY_DAY.MY_ORDER_HINT') }}
            </span>
            <span
              v-if="hasPlan && planTime"
              class="ml-auto font-normal normal-case tracking-normal"
              :class="
                planOverloaded
                  ? 'font-semibold text-amber-700 dark:text-amber-300'
                  : 'text-slate-500 dark:text-slate-400'
              "
            >
              {{
                $t(
                  planOverloaded
                    ? 'CASE_TICKETS.TASKS.MY_DAY.PLAN_OVERLOAD'
                    : 'CASE_TICKETS.TASKS.MY_DAY.PLAN_TIME',
                  { time: planTime }
                )
              }}
            </span>
          </h2>
          <div class="relative">
            <p
              v-if="!hasPlan"
              class="absolute inset-0 flex items-center justify-center px-4 m-0 text-sm text-center pointer-events-none text-slate-400 dark:text-slate-500"
            >
              {{ $t('CASE_TICKETS.TASKS.MY_DAY.MY_ORDER_EMPTY') }}
            </p>
            <Draggable
              v-model="plan"
              group="my-day"
              handle=".my-day-handle"
              class="flex flex-col gap-2"
              :class="
                hasPlan
                  ? ''
                  : 'min-h-[64px] p-2 border-2 border-dashed rounded-lg border-slate-200 dark:border-slate-700'
              "
              @change="onPlanChange"
            >
              <MyDayTaskRow
                v-for="(row, i) in plan"
                :key="row.id"
                :row="row"
                :rank="base + i + 1"
                :highlight="i === 0 && page === 1"
                planned
                draggable
                :completing-id="completingId"
                @openTask="r => $emit('openTask', r)"
                @openTicket="r => $emit('openTicket', r)"
                @complete="r => $emit('complete', r)"
                @postpone="r => $emit('postpone', r)"
                @unpin="unpin"
              />
            </Draggable>
          </div>
        </div>

        <!-- Sugeridas por prioridad (el resto, por puntaje) -->
        <div v-if="suggested.length">
          <h2
            class="m-0 mb-2 text-xs font-semibold tracking-wide uppercase text-slate-500 dark:text-slate-400"
          >
            {{ $t('CASE_TICKETS.TASKS.MY_DAY.SUGGESTED') }}
          </h2>
          <Draggable
            v-model="suggested"
            :group="{ name: 'my-day', pull: true, put: true }"
            :sort="false"
            handle=".my-day-handle"
            class="flex flex-col gap-2"
          >
            <MyDayTaskRow
              v-for="(row, i) in suggested"
              :key="row.id"
              :row="row"
              :rank="suggestedOffset + i + 1"
              draggable
              :completing-id="completingId"
              @openTask="r => $emit('openTask', r)"
              @openTicket="r => $emit('openTicket', r)"
              @complete="r => $emit('complete', r)"
              @postpone="r => $emit('postpone', r)"
              @pin="pin"
            />
          </Draggable>
        </div>
      </template>
    </section>

    <!-- Agenda de hoy: reuniones a hora fija. -->
    <aside class="flex-shrink-0 lg:w-80">
      <h2
        class="m-0 mb-2 text-xs font-semibold tracking-wide uppercase text-slate-500 dark:text-slate-400"
      >
        {{ $t('CASE_TICKETS.TASKS.MY_DAY.AGENDA') }}
      </h2>
      <p
        v-if="!agenda.length"
        class="m-0 text-sm text-slate-400 dark:text-slate-500"
      >
        {{ $t('CASE_TICKETS.TASKS.MY_DAY.AGENDA_EMPTY') }}
      </p>
      <ul v-else class="flex flex-col gap-2 p-0 m-0 list-none">
        <li v-for="m in agenda" :key="m.id">
          <button
            type="button"
            class="flex items-start w-full gap-3 px-3 py-2 text-left bg-white border rounded-lg border-slate-100 dark:bg-slate-800 dark:border-slate-700 hover:border-woot-300 dark:hover:border-woot-600"
            @click="$emit('openMeeting', m)"
          >
            <span
              class="font-mono text-sm font-semibold tabular-nums text-woot-600 dark:text-woot-300"
            >
              {{ timeLabel(m.starts_at) }}
            </span>
            <span class="flex-1 min-w-0">
              <span
                class="block text-sm truncate text-slate-800 dark:text-slate-100"
              >
                {{ m.title }}
              </span>
              <span
                v-if="m.case_ticket"
                class="block font-mono text-xs text-slate-500 dark:text-slate-400"
              >
                {{ m.case_ticket.folio }}
              </span>
              <span
                v-else-if="m.contact"
                class="block text-xs truncate text-slate-500 dark:text-slate-400"
              >
                {{ m.contact.name }}
              </span>
            </span>
          </button>
        </li>
      </ul>
    </aside>
  </div>
</template>
