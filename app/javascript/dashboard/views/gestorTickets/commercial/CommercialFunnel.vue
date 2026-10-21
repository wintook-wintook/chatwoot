<!--
  @tickets_cases — Métricas → Comercial, pestaña «Embudo».
  El embudo clásico: una franja por etapa EN CURSO (en el orden de las columnas
  del tipo) con su cantidad y su total, y al final las GANADAS del período. La
  forma se angosta siempre igual (decisión: forma clásica, los números escritos),
  así no deja de parecer embudo cuando una etapa tiene más que la anterior.
  Pospuestas (etapa «en espera») y «Sin etapa» van aparte, abajo: no son pasos.
  Color: un solo tono (azul) que se oscurece hacia abajo = avance; Ganadas en el
  verde de estado «bueno», con ✔ y texto (nunca solo color). Tabla equivalente.
  Filtros propios (no tocan «Generales»): moneda y cierre estimado (este, solo
  sobre lo abierto); casillas para ponderado y perdidas/canceladas.
  Pide su propio reporte (CaseReportsAPI.getPipeline) con los filtros de la página.
-->
<script>
import CaseReportsAPI from 'dashboard/api/caseReports';
import { formatMoney } from 'dashboard/helper/caseCommercial';
import {
  loadCaseState,
  saveCaseState,
  typesOfClass,
} from 'dashboard/helper/caseClasses';

// Una columna es del embudo si cubre algún estado abierto; es «en espera»
// (Pospuesta) si todos sus estados son de espera.
const CLOSED = ['closed', 'cancelled'];
const WAITING = [
  'waiting_on_customer',
  'waiting_on_third_party',
  'waiting_on_internal',
];

const CLOSE_OPTIONS = [
  '',
  'overdue',
  'this_week',
  'this_month',
  'next_month',
  'this_quarter',
  'none',
];

// Escalón del color de marca (woot) por profundidad: claro → oscuro = avance;
// en oscuro, sus propios pasos. OJO: el tema del proyecto NO trae `blue` ni
// `emerald` (theme/colors.js reemplaza la paleta): esas clases no pintan nada.
// Tinta con contraste ≥ 4.5:1 en cada paso.
const STEPS = [
  { bg: 'bg-woot-100 dark:bg-woot-800', ink: 'text-slate-800 dark:text-white' },
  { bg: 'bg-woot-200 dark:bg-woot-700', ink: 'text-slate-900 dark:text-white' },
  { bg: 'bg-woot-300 dark:bg-woot-600', ink: 'text-slate-900' },
  { bg: 'bg-woot-400 dark:bg-woot-500', ink: 'text-slate-900' },
  { bg: 'bg-woot-500 dark:bg-woot-400', ink: 'text-slate-900' },
  { bg: 'bg-woot-700 dark:bg-woot-300', ink: 'text-white dark:text-slate-900' },
];
// Ganadas: el verde de estado «bueno» (con ✔ y texto, nunca solo color).
const WON_STEP = {
  bg: 'bg-green-700 dark:bg-green-500',
  ink: 'text-white dark:text-slate-900',
};

// Ancho de la boca y del pico del embudo (% del contenedor).
const TOP = 100;
const BOTTOM = 38;

export default {
  name: 'CommercialFunnel',
  props: {
    // Filtros de la página (tipo, agente, equipo, período) — CaseReportsAPI.
    baseFilters: { type: Object, required: true },
    caseClass: { type: String, default: 'commercial' },
    // Plan-Metricas-Comercial M2 — resultado de «Calcular estancadas» (o null):
    // { threshold_days, by_stage: { etiqueta: n } } → ⚠ en la franja.
    stale: { type: Object, default: null },
  },
  data() {
    return {
      report: null,
      isLoading: false,
      currency: '',
      close: '',
      showWeighted: false,
      showLost: false,
      tableView: false,
    };
  },
  computed: {
    types() {
      return this.$store.getters['caseTickets/getTypes'] || [];
    },
    // Etapas de las columnas del tipo elegido (o de todos los Comerciales), en
    // orden y sin repetir nombre: así el embudo muestra también las vacías.
    typeStages() {
      const typeId = this.baseFilters.caseTypeId;
      const types = typesOfClass(this.types, this.caseClass).filter(
        t => !typeId || String(t.id) === String(typeId)
      );
      const byLabel = {};
      types.forEach(t =>
        (t.columns || []).forEach(c => {
          const st = c.statuses || [];
          if (!st.some(x => !CLOSED.includes(x))) return;
          const prev = byLabel[c.label];
          if (prev && prev.position <= c.position) return;
          byLabel[c.label] = {
            label: c.label,
            position: c.position,
            waiting: st.every(x => WAITING.includes(x)),
          };
        })
      );
      return Object.values(byLabel).sort((a, b) => a.position - b.position);
    },
    // Columnas del tipo + lo que trae el reporte (por nombre); vacías en 0.
    mergedStages() {
      const fromReport = {};
      this.stages
        .filter(s => s.label)
        .forEach(s => {
          fromReport[s.label] = s;
        });
      const list = this.typeStages.map(t => ({
        ...t,
        count: fromReport[t.label] ? fromReport[t.label].count : 0,
        values: fromReport[t.label] ? fromReport[t.label].values : [],
      }));
      const known = list.map(t => t.label);
      this.stages
        .filter(s => s.label && !known.includes(s.label))
        .forEach(s => list.push({ ...s }));
      return list;
    },
    accountId() {
      return this.$route.params.accountId;
    },
    closeOptions() {
      return CLOSE_OPTIONS;
    },
    currencies() {
      return (this.report && this.report.currencies) || [];
    },
    summary() {
      return (this.report && this.report.summary) || {};
    },
    stages() {
      return (this.report && this.report.stages) || [];
    },
    // Pasos del embudo: etapas en curso con nombre que no son «en espera».
    steps() {
      return this.mergedStages.filter(s => !s.waiting);
    },
    waitingStages() {
      return this.mergedStages.filter(s => s.waiting && s.count > 0);
    },
    noStage() {
      return this.stages.find(s => !s.label) || null;
    },
    // Franjas: las etapas y, al final, las ganadas del período.
    bands() {
      const n = this.steps.length;
      const list = this.steps.map((s, i) => ({
        key: `stage-${s.label}`,
        label: s.label,
        count: s.count,
        values: s.values,
        tone: STEPS[Math.round((i * (STEPS.length - 1)) / Math.max(n - 1, 1))],
        won: false,
      }));
      list.push({
        key: 'won',
        label: this.$t('CASE_TICKETS.COMMERCIAL.FUNNEL.WON'),
        count: this.summary.won_count || 0,
        values: this.summary.won_value || [],
        tone: WON_STEP,
        won: true,
      });
      const total = list.length;
      const width = i => TOP - ((TOP - BOTTOM) * i) / total;
      return list.map((b, i) => {
        const top = width(i);
        const inset = ((top - width(i + 1)) / 2 / top) * 100;
        return {
          ...b,
          style: {
            width: `${top}%`,
            clipPath: `polygon(0 0, 100% 0, ${
              100 - inset
            }% 100%, ${inset}% 100%)`,
          },
        };
      });
    },
    openCount() {
      return this.summary.open_count || 0;
    },
    isEmpty() {
      return this.report && !this.openCount && !this.summary.won_count;
    },
  },
  watch: {
    baseFilters: { deep: true, handler: 'fetch' },
  },
  mounted() {
    const saved = loadCaseState(this.accountId, this.caseClass).funnel || {};
    this.currency = saved.currency || '';
    this.close = CLOSE_OPTIONS.includes(saved.close) ? saved.close : '';
    this.showWeighted = !!saved.showWeighted;
    this.showLost = !!saved.showLost;
    this.fetch();
  },
  methods: {
    persist() {
      saveCaseState(this.accountId, this.caseClass, {
        funnel: {
          currency: this.currency,
          close: this.close,
          showWeighted: this.showWeighted,
          showLost: this.showLost,
        },
      });
    },
    onOptionChange() {
      this.persist();
    },
    async fetch() {
      this.persist();
      this.isLoading = true;
      try {
        const { data } = await CaseReportsAPI.getPipeline({
          ...this.baseFilters,
          currency: this.currency || undefined,
          close: this.close || undefined,
        });
        this.report = data;
        // Una moneda guardada que ya no existe no deja el embudo vacío.
        if (this.currency && !data.currencies.includes(this.currency)) {
          this.currency = '';
          this.fetch();
        }
      } catch (_e) {
        this.$emitter.emit('newToastMessage', {
          message: this.$t('CASE_TICKETS.COMMERCIAL.METRICS.ERROR'),
          type: 'error',
        });
      } finally {
        this.isLoading = false;
      }
    },
    // [{ currency, amount }] → "$1,000 MXN · $500 USD"; vacío → "—".
    moneyList(values, field = 'amount') {
      const list = (values || []).filter(
        v => v[field] !== undefined && v[field] !== null
      );
      if (!list.length) return '—';
      return list.map(v => formatMoney(v[field], v.currency)).join(' · ');
    },
    staleCount(band) {
      if (!this.stale || band.won) return 0;
      return (this.stale.by_stage || {})[band.label] || 0;
    },
    closeLabel(key) {
      return this.$t(`CASE_TICKETS.COMMERCIAL.FUNNEL.CLOSE.${key || 'any'}`);
    },
    bandTitle(band) {
      const lines = [
        band.label,
        this.$t('CASE_TICKETS.COMMERCIAL.METRICS.STAGES.COUNT', {
          count: band.count,
        }),
        `${this.$t('CASE_TICKETS.COMMERCIAL.FIELDS.AMOUNT')}: ${this.moneyList(
          band.values
        )}`,
      ];
      if (!band.won) {
        lines.push(
          `${this.$t(
            'CASE_TICKETS.COMMERCIAL.FIELDS.WEIGHTED'
          )}: ${this.moneyList(band.values, 'weighted')}`
        );
      }
      return lines.join('\n');
    },
  },
};
</script>

<template>
  <div class="flex flex-col gap-4 p-4">
    <!-- Filtros propios del embudo: una fila. -->
    <div class="flex flex-wrap items-center gap-3">
      <select
        v-model="currency"
        class="!mb-0 text-sm w-44"
        :aria-label="$t('CASE_TICKETS.COMMERCIAL.FUNNEL.CURRENCY')"
        @change="fetch"
      >
        <option value="">
          {{ $t('CASE_TICKETS.COMMERCIAL.FUNNEL.ALL_CURRENCIES') }}
        </option>
        <option v-for="c in currencies" :key="c" :value="c">{{ c }}</option>
      </select>
      <select
        v-model="close"
        class="!mb-0 text-sm w-52"
        :aria-label="$t('CASE_TICKETS.COMMERCIAL.FUNNEL.CLOSE_LABEL')"
        :title="$t('CASE_TICKETS.COMMERCIAL.FUNNEL.CLOSE_HINT')"
        @change="fetch"
      >
        <option v-for="c in closeOptions" :key="c || 'any'" :value="c">
          {{ closeLabel(c) }}
        </option>
      </select>
      <label
        class="flex items-center gap-1.5 text-sm text-slate-700 dark:text-slate-200"
      >
        <input
          v-model="showWeighted"
          type="checkbox"
          class="!mb-0"
          @change="onOptionChange"
        />
        {{ $t('CASE_TICKETS.COMMERCIAL.FUNNEL.SHOW_WEIGHTED') }}
      </label>
      <label
        class="flex items-center gap-1.5 text-sm text-slate-700 dark:text-slate-200"
      >
        <input
          v-model="showLost"
          type="checkbox"
          class="!mb-0"
          @change="onOptionChange"
        />
        {{ $t('CASE_TICKETS.COMMERCIAL.FUNNEL.SHOW_LOST') }}
      </label>
      <button
        type="button"
        class="ml-auto text-xs font-medium text-woot-600 dark:text-woot-300 hover:underline"
        @click="tableView = !tableView"
      >
        {{
          tableView
            ? $t('CASE_TICKETS.COMMERCIAL.METRICS.CHART_VIEW')
            : $t('CASE_TICKETS.COMMERCIAL.METRICS.TABLE_VIEW')
        }}
      </button>
    </div>

    <p
      v-if="isLoading && !report"
      class="m-0 text-sm text-slate-400 dark:text-slate-500"
    >
      {{ $t('CASE_TICKETS.COMMERCIAL.METRICS.LOADING') }}
    </p>
    <p
      v-else-if="isEmpty"
      class="m-0 py-12 text-sm text-center text-slate-400 dark:text-slate-500"
    >
      {{ $t('CASE_TICKETS.COMMERCIAL.FUNNEL.EMPTY') }}
    </p>

    <section
      v-else-if="report"
      class="w-full max-w-3xl mx-auto"
      :class="isLoading ? 'opacity-60' : ''"
    >
      <h2 class="m-0 text-sm font-semibold text-slate-800 dark:text-slate-100">
        {{ $t('CASE_TICKETS.COMMERCIAL.FUNNEL.TITLE') }}
      </h2>
      <p class="m-0 mt-0.5 mb-4 text-xs text-slate-500 dark:text-slate-400">
        {{
          $t('CASE_TICKETS.COMMERCIAL.FUNNEL.SUBTITLE', { count: openCount })
        }}
      </p>

      <!-- El dibujo -->
      <div v-if="!tableView" class="flex flex-col items-center gap-0.5">
        <div
          v-for="band in bands"
          :key="band.key"
          class="flex flex-col items-center justify-center min-h-[4rem] py-2 px-[12%] text-center"
          :class="[band.tone.bg, band.tone.ink]"
          :style="band.style"
          :title="bandTitle(band)"
        >
          <span
            class="flex items-center gap-1 text-[11px] font-semibold tracking-wide uppercase"
          >
            <fluent-icon v-if="band.won" icon="checkmark-circle" size="12" />
            {{ band.label }}
            <span v-if="band.won" class="font-normal normal-case">
              {{ $t('CASE_TICKETS.COMMERCIAL.FUNNEL.IN_PERIOD') }}
            </span>
          </span>
          <span class="max-w-full text-sm font-bold truncate tabular-nums">
            {{ band.count }} · {{ moneyList(band.values) }}
          </span>
          <span
            v-if="staleCount(band)"
            class="px-1.5 mt-0.5 text-[10px] font-semibold rounded-full bg-amber-100 text-amber-800 dark:bg-amber-900 dark:text-amber-200"
          >
            {{
              $t('CASE_TICKETS.COMMERCIAL.FUNNEL.STALE_CHIP', {
                count: staleCount(band),
                days: stale.threshold_days,
              })
            }}
          </span>
          <span
            v-if="showWeighted && !band.won"
            class="max-w-full text-[11px] truncate tabular-nums opacity-90"
          >
            {{ $t('CASE_TICKETS.COMMERCIAL.FUNNEL.WEIGHTED') }}
            {{ moneyList(band.values, 'weighted') }}
          </span>
        </div>
      </div>

      <!-- La misma información en tabla -->
      <table v-else class="w-full text-sm">
        <thead>
          <tr class="text-left text-xs text-slate-500 dark:text-slate-400">
            <th class="py-1.5 font-medium">
              {{ $t('CASE_TICKETS.COMMERCIAL.FUNNEL.STAGE') }}
            </th>
            <th class="py-1.5 font-medium text-right">
              {{ $t('CASE_TICKETS.COMMERCIAL.FUNNEL.COUNT') }}
            </th>
            <th class="py-1.5 font-medium text-right">
              {{ $t('CASE_TICKETS.COMMERCIAL.FIELDS.AMOUNT') }}
            </th>
            <th v-if="showWeighted" class="py-1.5 font-medium text-right">
              {{ $t('CASE_TICKETS.COMMERCIAL.FIELDS.WEIGHTED') }}
            </th>
          </tr>
        </thead>
        <tbody class="text-slate-700 dark:text-slate-200">
          <tr
            v-for="band in bands"
            :key="band.key"
            class="border-t border-slate-100 dark:border-slate-700"
          >
            <td class="py-1.5" :class="band.won ? 'font-semibold' : ''">
              {{ band.label }}
            </td>
            <td class="py-1.5 text-right tabular-nums">{{ band.count }}</td>
            <td class="py-1.5 text-right tabular-nums">
              {{ moneyList(band.values) }}
            </td>
            <td v-if="showWeighted" class="py-1.5 text-right tabular-nums">
              {{ band.won ? '—' : moneyList(band.values, 'weighted') }}
            </td>
          </tr>
        </tbody>
      </table>

      <!-- Fuera del embudo: perdidas/canceladas (opcional), pospuestas, sin etapa -->
      <div
        class="flex flex-col gap-1.5 mt-4 text-xs text-slate-600 dark:text-slate-300"
      >
        <p v-if="showLost" class="flex flex-wrap gap-x-4 gap-y-1 m-0">
          <span>
            <fluent-icon icon="dismiss-circle" size="12" class="inline" />
            {{
              $t('CASE_TICKETS.COMMERCIAL.FUNNEL.LOST', {
                count: summary.lost_count || 0,
              })
            }}
            · {{ moneyList(summary.lost_value) }}
          </span>
          <span>
            {{
              $t('CASE_TICKETS.COMMERCIAL.FUNNEL.CANCELLED', {
                count: summary.cancelled_count || 0,
              })
            }}
            · {{ moneyList(summary.cancelled_value) }}
          </span>
        </p>
        <p v-for="s in waitingStages" :key="`waiting-${s.label}`" class="m-0">
          <fluent-icon icon="snooze" size="12" class="inline" />
          {{
            $t('CASE_TICKETS.COMMERCIAL.FUNNEL.WAITING', {
              label: s.label,
              count: s.count,
            })
          }}
          · {{ moneyList(s.values) }}
        </p>
        <p v-if="noStage" class="m-0">
          {{
            $t('CASE_TICKETS.COMMERCIAL.FUNNEL.NO_STAGE', {
              count: noStage.count,
            })
          }}
          · {{ moneyList(noStage.values) }}
        </p>
      </div>
    </section>
  </div>
</template>
