<!--
  Presupuesto de ventas › Avance: meta contra lo logrado (ventas ganadas sin IVA,
  contadas por trato) en un rango de meses. Tarjetas del total, barras por mes
  (lo logrado; la meta es la raya de referencia) y la tabla por vendedor, que se
  abre para ver sus clientes con meta y «otros clientes».
-->
<script>
import SalesBudgetsAPI from 'dashboard/api/salesBudgets';
import Spinner from 'shared/components/Spinner.vue';
import { quickRange, monthLabel, money, compactMoney } from './budgetHelpers';

const T = 'SALES_BUDGET.PROGRESS';

export default {
  name: 'BudgetProgress',
  components: { Spinner },
  props: {
    currency: { type: String, default: 'MXN' },
  },
  emits: ['loaded'],
  data() {
    return {
      ...quickRange('month'),
      report: null,
      loading: true,
      open: [],
      hover: null,
    };
  },
  computed: {
    totals() {
      return this.report ? this.report.totals : {};
    },
    months() {
      return this.report ? this.report.months : [];
    },
    sellers() {
      return this.report ? this.report.sellers : [];
    },
    chartMax() {
      const values = this.months.flatMap(m => [m.budget, m.actual]);
      return Math.max(1, ...values);
    },
  },
  watch: {
    currency: 'fetch',
    from: 'fetch',
    to: 'fetch',
  },
  mounted() {
    this.fetch();
  },
  methods: {
    t(key, params) {
      return this.$t(`${T}.${key}`, params);
    },
    monthLabel,
    money(value) {
      return money(value, this.currency);
    },
    compact(value) {
      return compactMoney(value, this.currency);
    },
    async fetch() {
      if (!this.from || !this.to) return;
      this.loading = true;
      try {
        const { data } = await SalesBudgetsAPI.report({
          from: this.from,
          to: this.to,
          currency: this.currency,
        });
        this.report = data;
        this.$emit('loaded', data);
      } catch {
        this.report = null;
      } finally {
        this.loading = false;
      }
    },
    setRange(kind) {
      Object.assign(this, quickRange(kind));
    },
    isRange(kind) {
      const range = quickRange(kind);
      return range.from === this.from && range.to === this.to;
    },
    toggle(key) {
      this.open = this.open.includes(key)
        ? this.open.filter(k => k !== key)
        : [...this.open, key];
    },
    sellerKey(seller) {
      return seller.user_id || 'none';
    },
    barHeight(value) {
      return `${Math.round((value / this.chartMax) * 100)}%`;
    },
    // Ancho de la barra de avance (tope 100 %; el número dice si se pasó).
    progressWidth(row) {
      if (!row.budget) return row.actual ? '100%' : '0%';
      return `${Math.min(100, (row.actual / row.budget) * 100)}%`;
    },
    percent(row) {
      return row.percent === null || row.percent === undefined
        ? '—'
        : `${row.percent}%`;
    },
  },
};
</script>

<template>
  <div class="flex flex-col gap-5">
    <!-- Filtros en una fila: rango rápido o meses a mano. -->
    <div class="flex flex-wrap items-center gap-2">
      <woot-button
        v-for="kind in ['month', 'quarter', 'year']"
        :key="kind"
        size="small"
        :variant="isRange(kind) ? 'smooth' : 'clear'"
        color-scheme="secondary"
        @click="setRange(kind)"
      >
        {{ t(`RANGES.${kind.toUpperCase()}`) }}
      </woot-button>
      <input
        v-model="from"
        type="month"
        class="!mb-0 text-sm w-40"
        :aria-label="t('FROM')"
      />
      <span class="text-sm text-slate-500">—</span>
      <input
        v-model="to"
        type="month"
        class="!mb-0 text-sm w-40"
        :aria-label="t('TO')"
      />
    </div>

    <Spinner v-if="loading && !report" />
    <template v-else-if="report">
      <!-- Tarjetas del total -->
      <div class="grid grid-cols-2 gap-3 lg:grid-cols-4">
        <div
          v-for="tile in [
            { key: 'BUDGET', value: compact(totals.budget) },
            { key: 'ACTUAL', value: compact(totals.actual) },
            { key: 'PERCENT', value: percent(totals) },
            { key: 'DIFF', value: compact(totals.diff) },
          ]"
          :key="tile.key"
          class="p-4 bg-white border rounded-xl border-slate-100 dark:bg-slate-800 dark:border-slate-700"
        >
          <p class="m-0 text-xs text-slate-500 dark:text-slate-400">
            {{ t(`TILES.${tile.key}`) }}
          </p>
          <p
            class="m-0 mt-1 text-2xl font-semibold tabular-nums text-slate-800 dark:text-slate-100"
          >
            {{ tile.value }}
          </p>
        </div>
      </div>

      <!-- Por mes: barra = logrado; raya = meta. Solo si el rango tiene varios meses. -->
      <section
        v-if="months.length > 1"
        class="p-4 bg-white border rounded-xl border-slate-100 dark:bg-slate-800 dark:border-slate-700"
      >
        <div class="flex flex-wrap items-center justify-between gap-2 mb-3">
          <h3
            class="m-0 text-sm font-semibold text-slate-800 dark:text-slate-100"
          >
            {{ t('BY_MONTH') }}
          </h3>
          <div
            class="flex items-center gap-4 text-xs text-slate-600 dark:text-slate-300"
          >
            <span class="flex items-center gap-1.5">
              <span class="w-3 h-3 rounded-sm bg-woot-600" />
              {{ t('TILES.ACTUAL') }}
            </span>
            <span class="flex items-center gap-1.5">
              <span class="w-4 h-0.5 bg-slate-700 dark:bg-slate-200" />
              {{ t('TILES.BUDGET') }}
            </span>
          </div>
        </div>
        <div class="relative flex items-end h-48 gap-0.5">
          <div
            v-for="(m, i) in months"
            :key="m.period"
            class="relative flex flex-col items-center justify-end flex-1 h-full cursor-default group"
            @mouseenter="hover = i"
            @mouseleave="hover = null"
          >
            <div class="relative flex items-end justify-center w-full h-full">
              <div
                class="w-3/5 max-w-[40px] rounded-t bg-woot-600 group-hover:bg-woot-700"
                :style="{ height: barHeight(m.actual) }"
              />
              <div
                v-if="m.budget"
                class="absolute w-4/5 max-w-[52px] h-0.5 bg-slate-700 dark:bg-slate-200"
                :style="{ bottom: barHeight(m.budget) }"
              />
            </div>
            <div
              v-if="hover === i"
              class="absolute z-10 px-2 py-1 text-xs bg-white border rounded-md shadow-md pointer-events-none whitespace-nowrap -top-2 -translate-y-full border-slate-200 dark:bg-slate-900 dark:border-slate-700 text-slate-700 dark:text-slate-200"
            >
              <strong>{{ monthLabel(m.period) }}</strong>
              · {{ t('TILES.ACTUAL') }} {{ money(m.actual) }} ·
              {{ t('TILES.BUDGET') }} {{ money(m.budget) }}
            </div>
          </div>
        </div>
        <div
          class="flex gap-0.5 mt-1 border-t border-slate-100 dark:border-slate-700"
        >
          <span
            v-for="m in months"
            :key="m.period"
            class="flex-1 pt-1 text-[11px] text-center text-slate-500 dark:text-slate-400"
          >
            {{ monthLabel(m.period) }}
          </span>
        </div>
      </section>

      <!-- Por vendedor (y sus clientes) -->
      <section
        class="overflow-hidden bg-white border rounded-xl border-slate-100 dark:bg-slate-800 dark:border-slate-700"
      >
        <p
          v-if="!sellers.length"
          class="p-4 m-0 text-sm text-slate-500 dark:text-slate-400"
        >
          {{ t('EMPTY') }}
        </p>
        <table v-else class="w-full text-sm">
          <thead>
            <tr
              class="text-xs text-left text-slate-500 dark:text-slate-400 border-b border-slate-100 dark:border-slate-700"
            >
              <th class="px-4 py-2 font-medium">{{ t('COLUMNS.SELLER') }}</th>
              <th class="px-4 py-2 font-medium text-right">
                {{ t('TILES.BUDGET') }}
              </th>
              <th class="px-4 py-2 font-medium text-right">
                {{ t('TILES.ACTUAL') }}
              </th>
              <th class="w-48 px-4 py-2 font-medium">
                {{ t('TILES.PERCENT') }}
              </th>
              <th class="px-4 py-2 font-medium text-right">
                {{ t('TILES.DIFF') }}
              </th>
            </tr>
          </thead>
          <tbody>
            <template v-for="seller in sellers">
              <tr
                :key="sellerKey(seller)"
                class="border-b cursor-pointer border-slate-50 dark:border-slate-700/60 hover:bg-slate-25 dark:hover:bg-slate-700/40"
                @click="toggle(sellerKey(seller))"
              >
                <td class="px-4 py-2 text-slate-800 dark:text-slate-100">
                  <fluent-icon
                    :icon="
                      open.includes(sellerKey(seller))
                        ? 'chevron-down'
                        : 'chevron-right'
                    "
                    size="12"
                    class="inline mr-1 text-slate-400"
                  />
                  {{ seller.name || t('NO_SELLER') }}
                </td>
                <td class="px-4 py-2 text-right tabular-nums">
                  {{ money(seller.budget) }}
                </td>
                <td class="px-4 py-2 text-right tabular-nums">
                  {{ money(seller.actual) }}
                </td>
                <td class="px-4 py-2">
                  <div class="flex items-center gap-2">
                    <div
                      class="flex-1 h-2 overflow-hidden rounded-full bg-slate-100 dark:bg-slate-700"
                    >
                      <div
                        class="h-full rounded-full bg-woot-600"
                        :style="{ width: progressWidth(seller) }"
                      />
                    </div>
                    <span
                      class="w-12 text-xs text-right tabular-nums text-slate-700 dark:text-slate-200"
                    >
                      {{ percent(seller) }}
                    </span>
                  </div>
                </td>
                <td
                  class="px-4 py-2 text-right tabular-nums text-slate-700 dark:text-slate-200"
                >
                  {{ money(seller.diff) }}
                </td>
              </tr>
              <template v-if="open.includes(sellerKey(seller))">
                <tr
                  v-for="client in seller.clients"
                  :key="`${sellerKey(seller)}-${
                    client.organization_id || 'c'
                  }-${client.contact_id || ''}`"
                  class="text-xs border-b border-slate-50 dark:border-slate-700/60 text-slate-600 dark:text-slate-300"
                >
                  <td class="py-1.5 pl-10 pr-4">{{ client.name }}</td>
                  <td class="px-4 py-1.5 text-right tabular-nums">
                    {{ money(client.budget) }}
                  </td>
                  <td class="px-4 py-1.5 text-right tabular-nums">
                    {{ money(client.actual) }}
                  </td>
                  <td class="px-4 py-1.5 tabular-nums">
                    {{ percent(client) }}
                  </td>
                  <td class="px-4 py-1.5 text-right tabular-nums">
                    {{ money(client.diff) }}
                  </td>
                </tr>
                <tr
                  :key="`${sellerKey(seller)}-other`"
                  class="text-xs border-b border-slate-50 dark:border-slate-700/60 text-slate-500 dark:text-slate-400"
                >
                  <td class="py-1.5 pl-10 pr-4 italic">
                    {{ t('OTHER_CLIENTS') }}
                  </td>
                  <td class="px-4 py-1.5 text-right">—</td>
                  <td class="px-4 py-1.5 text-right tabular-nums">
                    {{ money(seller.other_actual) }}
                  </td>
                  <td colspan="2" />
                </tr>
              </template>
            </template>
          </tbody>
          <tfoot>
            <tr class="font-semibold text-slate-800 dark:text-slate-100">
              <td class="px-4 py-2">{{ t('TOTAL') }}</td>
              <td class="px-4 py-2 text-right tabular-nums">
                {{ money(totals.budget) }}
              </td>
              <td class="px-4 py-2 text-right tabular-nums">
                {{ money(totals.actual) }}
              </td>
              <td class="px-4 py-2 text-xs tabular-nums">
                {{ percent(totals) }}
              </td>
              <td class="px-4 py-2 text-right tabular-nums">
                {{ money(totals.diff) }}
              </td>
            </tr>
          </tfoot>
        </table>
      </section>
      <p class="m-0 text-xs text-slate-500 dark:text-slate-400">
        {{ t('HOW_COUNTED') }}
      </p>
    </template>
  </div>
</template>
