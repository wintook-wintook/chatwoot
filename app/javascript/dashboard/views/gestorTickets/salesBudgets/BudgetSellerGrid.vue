<!--
  Presupuesto de ventas › Por vendedor: la meta global de cada vendedor, mes por mes
  (sin IVA). Se edita en la celda; «Guardar» manda solo lo cambiado (vacío o 0 la
  borra). «Copiar año anterior» trae las metas con ±% sin pisar lo capturado.
-->
<script>
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import SalesBudgetsAPI from 'dashboard/api/salesBudgets';
import { yearMonths, monthLabel, money } from './budgetHelpers';

const T = 'SALES_BUDGET.CAPTURE';

export default {
  name: 'BudgetSellerGrid',
  props: {
    year: { type: Number, required: true },
    currency: { type: String, default: 'MXN' },
  },
  data() {
    return { cells: {}, dirty: {}, saving: false, percent: 0 };
  },
  computed: {
    ...mapGetters({ agents: 'agents/getAgents' }),
    months() {
      return yearMonths(this.year);
    },
    hasChanges() {
      return Object.keys(this.dirty).length > 0;
    },
  },
  watch: {
    year: 'fetch',
    currency: 'fetch',
  },
  mounted() {
    this.$store.dispatch('agents/get');
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
    key(userId, period) {
      return `${userId}|${period}`;
    },
    async fetch() {
      this.dirty = {};
      try {
        const { data } = await SalesBudgetsAPI.list({
          year: this.year,
          currency: this.currency,
          kind: 'seller',
        });
        const cells = {};
        data.lines.forEach(line => {
          cells[this.key(line.user_id, line.period)] = line.amount;
        });
        this.cells = cells;
      } catch {
        this.cells = {};
      }
    },
    value(userId, period) {
      const v = this.cells[this.key(userId, period)];
      return v === undefined || v === null ? '' : v;
    },
    onInput(userId, period, event) {
      const k = this.key(userId, period);
      this.$set(this.cells, k, event.target.value);
      this.$set(this.dirty, k, { userId, period });
    },
    rowTotal(userId) {
      return this.months.reduce(
        (sum, p) => sum + Number(this.value(userId, p) || 0),
        0
      );
    },
    monthTotal(period) {
      return this.agents.reduce(
        (sum, a) => sum + Number(this.value(a.id, period) || 0),
        0
      );
    },
    yearTotal() {
      return this.months.reduce((sum, p) => sum + this.monthTotal(p), 0);
    },
    async save() {
      if (this.saving || !this.hasChanges) return;
      this.saving = true;
      try {
        const lines = Object.values(this.dirty).map(({ userId, period }) => ({
          user_id: userId,
          period,
          amount: this.value(userId, period),
        }));
        await SalesBudgetsAPI.save({
          year: this.year,
          currency: this.currency,
          lines,
        });
        useAlert(this.t('SAVED'));
        this.fetch();
      } catch (error) {
        useAlert(error?.response?.data?.error || this.t('ERROR'));
      } finally {
        this.saving = false;
      }
    },
    async copyPrevious() {
      try {
        const { data } = await SalesBudgetsAPI.copy({
          fromYear: this.year - 1,
          toYear: this.year,
          currency: this.currency,
          percent: Number(this.percent) || 0,
        });
        useAlert(this.t('COPIED', { count: data.copied }));
        this.fetch();
      } catch {
        useAlert(this.t('ERROR'));
      }
    },
  },
};
</script>

<template>
  <div class="flex flex-col gap-3">
    <div class="flex flex-wrap items-center gap-2">
      <woot-button
        size="small"
        :is-loading="saving"
        :disabled="!hasChanges"
        @click="save"
      >
        {{ t('SAVE') }}
      </woot-button>
      <span class="ml-auto text-xs text-slate-500">{{ t('COPY_HINT') }}</span>
      <input
        v-model="percent"
        type="number"
        step="1"
        class="!mb-0 !w-20 text-sm"
        :aria-label="t('PERCENT')"
      />
      <span class="text-xs text-slate-500">%</span>
      <woot-button
        size="small"
        variant="smooth"
        color-scheme="secondary"
        @click="copyPrevious"
      >
        {{ t('COPY', { year: year - 1 }) }}
      </woot-button>
    </div>
    <div
      class="overflow-x-auto bg-white border rounded-xl border-slate-100 dark:bg-slate-800 dark:border-slate-700"
    >
      <table class="min-w-full text-sm">
        <thead>
          <tr class="text-xs text-slate-500 dark:text-slate-400">
            <th
              class="sticky left-0 px-3 py-2 font-medium text-left bg-white dark:bg-slate-800"
            >
              {{ t('SELLER') }}
            </th>
            <th
              v-for="p in months"
              :key="p"
              class="px-1 py-2 font-medium text-right capitalize"
            >
              {{ monthLabel(p) }}
            </th>
            <th class="px-3 py-2 font-medium text-right">{{ t('YEAR') }}</th>
          </tr>
        </thead>
        <tbody>
          <tr
            v-for="agent in agents"
            :key="agent.id"
            class="border-t border-slate-50 dark:border-slate-700/60"
          >
            <td
              class="sticky left-0 px-3 py-1 whitespace-nowrap bg-white dark:bg-slate-800 text-slate-800 dark:text-slate-100"
            >
              {{ agent.name }}
            </td>
            <td v-for="p in months" :key="p" class="px-1 py-1">
              <input
                type="number"
                min="0"
                step="1000"
                class="!mb-0 !w-24 !h-8 text-right text-sm tabular-nums"
                :class="{ '!border-woot-400': dirty[key(agent.id, p)] }"
                :value="value(agent.id, p)"
                :aria-label="`${agent.name} ${monthLabel(p)}`"
                @input="onInput(agent.id, p, $event)"
              />
            </td>
            <td
              class="px-3 py-1 text-right whitespace-nowrap tabular-nums text-slate-700 dark:text-slate-200"
            >
              {{ money(rowTotal(agent.id)) }}
            </td>
          </tr>
        </tbody>
        <tfoot>
          <tr
            class="font-semibold border-t border-slate-100 dark:border-slate-700 text-slate-800 dark:text-slate-100"
          >
            <td class="sticky left-0 px-3 py-2 bg-white dark:bg-slate-800">
              {{ t('TOTAL') }}
            </td>
            <td
              v-for="p in months"
              :key="p"
              class="px-1 py-2 text-xs text-right whitespace-nowrap tabular-nums"
            >
              {{ money(monthTotal(p)) }}
            </td>
            <td class="px-3 py-2 text-right whitespace-nowrap tabular-nums">
              {{ money(yearTotal()) }}
            </td>
          </tr>
        </tfoot>
      </table>
    </div>
  </div>
</template>
