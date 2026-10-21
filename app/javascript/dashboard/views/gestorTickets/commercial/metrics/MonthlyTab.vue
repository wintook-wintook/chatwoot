<!--
  @tickets_cases — Plan-Metricas-Comercial M3: «Mes a mes» (a pedido, «Calcular»).
  Ventana propia (el período de la página no aplica): últimos 12 meses (por
  defecto), este año (enero a hoy) o el año pasado (ene–dic):
    1. Ganadas vs perdidas por mes — barras lado a lado (cantidad o monto). Verde
       oscuro vs gris claro: se distinguen por claridad, no solo por tono (seguro
       con daltonismo), y llevan leyenda con texto.
    2. Tasa de cierre por mes — línea en su PROPIA gráfica (nunca doble eje).
    3. Oportunidades nuevas por mes — si bajan, en meses bajan las ventas.
  Las tres comparten columnas (mismo mes, misma posición). Tooltip por mes y
  vista de tabla. Los montos son de UNA moneda (nunca se suman monedas).
-->
<script>
import CaseReportsAPI from 'dashboard/api/caseReports';
import { formatMoney, moneyList } from 'dashboard/helper/caseCommercial';
import {
  filtersKey,
  loadCalc,
  saveCalc,
} from 'dashboard/helper/caseMetricsCalc';
import CalcGate from './CalcGate.vue';

const SPANS = ['last_12', 'this_year', 'last_year'];

export default {
  name: 'MonthlyTab',
  components: { CalcGate },
  props: {
    baseFilters: { type: Object, required: true },
    currencies: { type: Array, default: () => [] },
  },
  data() {
    return {
      entry: null,
      loading: false,
      currency: '',
      span: 'last_12',
      measure: 'count',
      tableView: false,
    };
  },
  computed: {
    accountId() {
      return this.$route.params.accountId;
    },
    filters() {
      const { caseTypeId, assigneeId, teamId } = this.baseFilters;
      return {
        caseTypeId,
        assigneeId,
        teamId,
        currency: this.currency || undefined,
        span: this.span,
      };
    },
    spans() {
      return SPANS;
    },
    key() {
      return filtersKey(this.filters);
    },
    changed() {
      return !!this.entry && this.entry.key !== this.key;
    },
    months() {
      return (this.entry && this.entry.data && this.entry.data.months) || [];
    },
    // Moneda para los montos: la elegida o, si solo hay una, esa.
    amountCurrency() {
      if (this.currency) return this.currency;
      return this.currencies.length === 1 ? this.currencies[0] : null;
    },
    byAmount() {
      return this.measure === 'amount' && !!this.amountCurrency;
    },
    maxDecided() {
      return Math.max(
        1,
        ...this.months.flatMap(m => [this.wonOf(m), this.lostOf(m)])
      );
    },
    maxCreated() {
      return Math.max(1, ...this.months.map(m => m.created_count));
    },
    // Puntos de la tasa (x, y en %), con huecos donde no hubo decididas.
    ratePoints() {
      return this.months.map((m, i) => ({
        month: m.month,
        rate: m.win_rate,
        x: ((i + 0.5) / this.months.length) * 100,
        y: m.win_rate === null ? null : 100 - m.win_rate,
      }));
    },
    // Tramos de la línea (se corta donde no hay dato).
    rateSegments() {
      const segments = [];
      let current = [];
      this.ratePoints.forEach(p => {
        if (p.y === null) {
          if (current.length) segments.push(current);
          current = [];
        } else current.push(`${p.x},${p.y}`);
      });
      if (current.length) segments.push(current);
      return segments.map(s => s.join(' '));
    },
  },
  mounted() {
    const entry = loadCalc(this.accountId, 'monthly');
    if (!entry) return;
    this.entry = entry;
    // Vuelve con la moneda y la ventana con que se calculó.
    const saved = Object.fromEntries(JSON.parse(entry.key));
    if (saved.currency) this.currency = saved.currency;
    if (SPANS.includes(saved.span)) this.span = saved.span;
  },
  methods: {
    async calculate() {
      this.loading = true;
      try {
        const { data } = await CaseReportsAPI.getPipelineMonthly(this.filters);
        this.entry = saveCalc(this.accountId, 'monthly', this.key, data);
      } catch (_e) {
        this.$emitter.emit('newToastMessage', {
          message: this.$t('CASE_TICKETS.COMMERCIAL.METRICS.ERROR'),
          type: 'error',
        });
      } finally {
        this.loading = false;
      }
    },
    sumIn(values) {
      return (values || [])
        .filter(v => v.currency === this.amountCurrency)
        .reduce((a, v) => a + Number(v.amount || 0), 0);
    },
    wonOf(m) {
      return this.byAmount ? this.sumIn(m.won_value) : m.won_count;
    },
    lostOf(m) {
      return this.byAmount ? this.sumIn(m.lost_value) : m.lost_count;
    },
    height(value, max) {
      return `${value ? Math.max(2, (value / max) * 100) : 0}%`;
    },
    fmt(value) {
      return this.byAmount ? formatMoney(value, this.amountCurrency) : value;
    },
    money(values) {
      return moneyList(values);
    },
    monthShort(month, i) {
      const [y, m] = month.split('-').map(Number);
      const label = new Date(y, m - 1, 1).toLocaleDateString(undefined, {
        month: 'short',
      });
      return i === 0 || m === 1 ? `${label} ${String(y).slice(2)}` : label;
    },
    monthLong(month) {
      const [y, m] = month.split('-').map(Number);
      return new Date(y, m - 1, 1).toLocaleDateString(undefined, {
        month: 'long',
        year: 'numeric',
      });
    },
    pct(value) {
      return value === null || value === undefined ? '—' : `${value}%`;
    },
    monthTitle(m) {
      const t = k => this.$t(`CASE_TICKETS.COMMERCIAL.METRICS.MONTHLY.${k}`);
      return [
        this.monthLong(m.month),
        `${t('WON')}: ${this.fmt(this.wonOf(m))}`,
        `${t('LOST')}: ${this.fmt(this.lostOf(m))}`,
        `${t('RATE')}: ${this.pct(m.win_rate)}`,
        `${t('CREATED')}: ${m.created_count}`,
      ].join('\n');
    },
  },
};
</script>

<template>
  <CalcGate
    :title="$t(`CASE_TICKETS.COMMERCIAL.METRICS.MONTHLY.TITLE.${span}`)"
    :description="$t('CASE_TICKETS.COMMERCIAL.METRICS.MONTHLY.DESCRIPTION')"
    :calculated-at="entry ? entry.at : null"
    :loading="loading"
    :filters-changed="changed"
    @calculate="calculate"
  >
    <template #controls>
      <select
        v-model="span"
        class="!mb-0 !h-7 !py-0 text-xs w-40"
        :aria-label="$t('CASE_TICKETS.COMMERCIAL.METRICS.MONTHLY.SPAN')"
      >
        <option v-for="sp in spans" :key="sp" :value="sp">
          {{ $t(`CASE_TICKETS.COMMERCIAL.METRICS.MONTHLY.SPANS.${sp}`) }}
        </option>
      </select>
      <select
        v-model="currency"
        class="!mb-0 !h-7 !py-0 text-xs w-40"
        :aria-label="$t('CASE_TICKETS.COMMERCIAL.FUNNEL.CURRENCY')"
      >
        <option value="">
          {{ $t('CASE_TICKETS.COMMERCIAL.FUNNEL.ALL_CURRENCIES') }}
        </option>
        <option v-for="c in currencies" :key="c" :value="c">{{ c }}</option>
      </select>
    </template>

    <div class="flex flex-wrap items-center gap-3 mb-3 text-xs">
      <div
        class="inline-flex overflow-hidden border rounded-md border-slate-200 dark:border-slate-600"
        role="group"
      >
        <button
          v-for="m in ['count', 'amount']"
          :key="m"
          type="button"
          class="px-2.5 py-1"
          :class="
            measure === m
              ? 'bg-slate-800 text-white dark:bg-slate-100 dark:text-slate-900'
              : 'text-slate-600 dark:text-slate-300'
          "
          :aria-pressed="measure === m"
          @click="measure = m"
        >
          {{ $t(`CASE_TICKETS.COMMERCIAL.METRICS.MONTHLY.MEASURE.${m}`) }}
        </button>
      </div>
      <span
        v-if="measure === 'amount' && !amountCurrency"
        class="text-amber-700 dark:text-amber-300"
      >
        {{ $t('CASE_TICKETS.COMMERCIAL.METRICS.MONTHLY.PICK_CURRENCY') }}
      </span>
      <!-- Leyenda (2 series: siempre con texto, no solo color) -->
      <span
        class="flex items-center gap-1.5 text-slate-600 dark:text-slate-300"
      >
        <span
          class="inline-block w-3 h-3 rounded-sm bg-green-700 dark:bg-green-500"
        />
        {{ $t('CASE_TICKETS.COMMERCIAL.METRICS.MONTHLY.WON') }}
      </span>
      <span
        class="flex items-center gap-1.5 text-slate-600 dark:text-slate-300"
      >
        <span
          class="inline-block w-3 h-3 rounded-sm bg-slate-300 dark:bg-slate-500"
        />
        {{ $t('CASE_TICKETS.COMMERCIAL.METRICS.MONTHLY.LOST') }}
      </span>
      <button
        type="button"
        class="ml-auto text-woot-600 dark:text-woot-300 hover:underline"
        @click="tableView = !tableView"
      >
        {{
          tableView
            ? $t('CASE_TICKETS.COMMERCIAL.METRICS.CHART_VIEW')
            : $t('CASE_TICKETS.COMMERCIAL.METRICS.TABLE_VIEW')
        }}
      </button>
    </div>

    <div v-if="!tableView" class="flex flex-col gap-5">
      <!-- 1. Ganadas vs perdidas -->
      <div>
        <p
          class="m-0 mb-1 text-xs font-semibold text-slate-600 dark:text-slate-300"
        >
          {{ $t('CASE_TICKETS.COMMERCIAL.METRICS.MONTHLY.CHART_DECIDED') }}
        </p>
        <div
          class="flex items-end h-40 border-b border-slate-200 dark:border-slate-600"
        >
          <div
            v-for="m in months"
            :key="m.month"
            class="flex items-end justify-center flex-1 h-full gap-0.5 hover:bg-slate-50 dark:hover:bg-slate-700/40"
            :title="monthTitle(m)"
          >
            <div
              class="w-[30%] max-w-[14px] rounded-t bg-green-700 dark:bg-green-500"
              :style="{ height: height(wonOf(m), maxDecided) }"
            />
            <div
              class="w-[30%] max-w-[14px] rounded-t bg-slate-300 dark:bg-slate-500"
              :style="{ height: height(lostOf(m), maxDecided) }"
            />
          </div>
        </div>
        <div class="flex">
          <span
            v-for="(m, i) in months"
            :key="m.month"
            class="flex-1 pt-1 text-[10px] text-center text-slate-500 dark:text-slate-400"
          >
            {{ monthShort(m.month, i) }}
          </span>
        </div>
      </div>

      <!-- 2. Tasa de cierre (su propia escala 0–100 %) -->
      <div>
        <p
          class="m-0 mb-1 text-xs font-semibold text-slate-600 dark:text-slate-300"
        >
          {{ $t('CASE_TICKETS.COMMERCIAL.METRICS.MONTHLY.CHART_RATE') }}
        </p>
        <div
          class="relative h-24 border-b border-slate-200 dark:border-slate-600"
        >
          <div
            class="absolute inset-x-0 border-t border-dashed top-1/2 border-slate-100 dark:border-slate-700"
          />
          <span
            class="absolute top-0 left-0 text-[10px] text-slate-400 dark:text-slate-500"
          >
            {{ pct(100) }}
          </span>
          <span
            class="absolute left-0 -translate-y-1/2 top-1/2 text-[10px] text-slate-400 dark:text-slate-500"
          >
            {{ pct(50) }}
          </span>
          <svg
            class="absolute inset-0 w-full h-full overflow-visible text-woot-600 dark:text-woot-400"
            viewBox="0 0 100 100"
            preserveAspectRatio="none"
            aria-hidden="true"
          >
            <polyline
              v-for="(seg, i) in rateSegments"
              :key="i"
              :points="seg"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
              vector-effect="non-scaling-stroke"
            />
          </svg>
          <span
            v-for="p in ratePoints"
            v-show="p.y !== null"
            :key="p.month"
            class="absolute w-2 h-2 -translate-x-1/2 translate-y-1/2 rounded-full ring-2 ring-white dark:ring-slate-800 bg-woot-600 dark:bg-woot-400"
            :style="{ left: `${p.x}%`, bottom: `${100 - (p.y || 0)}%` }"
            :title="`${monthLong(p.month)}: ${pct(p.rate)}`"
          />
        </div>
      </div>

      <!-- 3. Nuevas por mes -->
      <div>
        <p
          class="m-0 mb-1 text-xs font-semibold text-slate-600 dark:text-slate-300"
        >
          {{ $t('CASE_TICKETS.COMMERCIAL.METRICS.MONTHLY.CHART_CREATED') }}
        </p>
        <div
          class="flex items-end h-20 border-b border-slate-200 dark:border-slate-600"
        >
          <div
            v-for="m in months"
            :key="m.month"
            class="flex items-end justify-center flex-1 h-full"
            :title="`${monthLong(m.month)}: ${m.created_count}`"
          >
            <div
              class="w-[45%] max-w-[22px] rounded-t bg-woot-500 dark:bg-woot-400"
              :style="{ height: height(m.created_count, maxCreated) }"
            />
          </div>
        </div>
      </div>
    </div>

    <table v-else class="w-full text-sm">
      <thead>
        <tr class="text-xs text-left uppercase text-slate-500">
          <th class="py-1">
            {{ $t('CASE_TICKETS.COMMERCIAL.METRICS.FORECAST.MONTH') }}
          </th>
          <th class="py-1 text-right">
            {{ $t('CASE_TICKETS.COMMERCIAL.METRICS.MONTHLY.CREATED') }}
          </th>
          <th class="py-1 text-right">
            {{ $t('CASE_TICKETS.COMMERCIAL.METRICS.MONTHLY.WON') }}
          </th>
          <th class="py-1 text-right">
            {{ $t('CASE_TICKETS.COMMERCIAL.METRICS.MONTHLY.LOST') }}
          </th>
          <th class="py-1 text-right">
            {{ $t('CASE_TICKETS.COMMERCIAL.METRICS.MONTHLY.RATE') }}
          </th>
          <th class="py-1 text-right">
            {{ $t('CASE_TICKETS.COMMERCIAL.METRICS.MONTHLY.WON_VALUE') }}
          </th>
        </tr>
      </thead>
      <tbody class="text-slate-700 dark:text-slate-200">
        <tr
          v-for="m in months"
          :key="m.month"
          class="border-t border-slate-50 dark:border-slate-700"
        >
          <td class="py-1.5">{{ monthLong(m.month) }}</td>
          <td class="py-1.5 text-right">{{ m.created_count }}</td>
          <td class="py-1.5 text-right">{{ m.won_count }}</td>
          <td class="py-1.5 text-right">{{ m.lost_count }}</td>
          <td class="py-1.5 text-right">{{ pct(m.win_rate) }}</td>
          <td class="py-1.5 text-right">{{ money(m.won_value) }}</td>
        </tr>
      </tbody>
    </table>
  </CalcGate>
</template>
