<!--
  @tickets_cases — Plan-Metricas-Comercial M1: «¿Cómo vamos?».
  El período en 10 segundos: indicadores con ▲▼ contra el rango de comparación
  (report.previous; «este mes» contra el mismo tramo del mes anterior, que se lee
  en cada flecha: «vs 1–21 sept»),
  ranking de vendedores (barras, con vista de tabla) y resumen por tipo.
-->
<script>
import { moneyList } from 'dashboard/helper/caseCommercial';
import {
  ARROWS,
  averageTicket,
  compareMoney,
  compareNumbers,
} from 'dashboard/helper/caseMetricsDelta';
import { formatMoney } from 'dashboard/helper/caseCommercial';
import KpiTile from './KpiTile.vue';

export default {
  name: 'OverviewTab',
  components: { KpiTile },
  props: {
    report: { type: Object, required: true },
    compareLabel: { type: String, default: '' },
  },
  data() {
    return { assigneesTable: false };
  },
  computed: {
    summary() {
      return this.report.summary || {};
    },
    previous() {
      return this.report.previous || null;
    },
    decidedCount() {
      return (this.summary.won_count || 0) + (this.summary.lost_count || 0);
    },
    wonDelta() {
      if (!this.previous) return null;
      const money = compareMoney(
        this.summary.won_value,
        this.previous.won_value
      );
      if (money)
        return this.deltaText(money, formatMoney(money.diff, money.currency));
      const count = compareNumbers(
        this.summary.won_count,
        this.previous.won_count
      );
      return this.deltaText(count, count && String(count.diff));
    },
    rateDelta() {
      if (!this.previous) return null;
      const d = compareNumbers(this.summary.win_rate, this.previous.win_rate);
      return this.deltaText(
        d,
        d &&
          this.$t('CASE_TICKETS.COMMERCIAL.METRICS.OVERVIEW.POINTS', {
            n: d.diff,
          })
      );
    },
    avgTicket() {
      return averageTicket(this.summary.won_value);
    },
    ticketDelta() {
      if (!this.previous) return null;
      const d = compareMoney(
        this.avgTicket,
        averageTicket(this.previous.won_value)
      );
      return this.deltaText(d, d && formatMoney(d.diff, d.currency));
    },
    cycleDelta() {
      if (!this.previous) return null;
      const d = compareNumbers(
        this.summary.avg_cycle_days,
        this.previous.avg_cycle_days,
        { lowerIsBetter: true }
      );
      return this.deltaText(
        d,
        d &&
          this.$t('CASE_TICKETS.COMMERCIAL.METRICS.KPI.DAYS', {
            days: Math.round(d.diff * 10) / 10,
          })
      );
    },
    // Plan-Metricas-Comercial — % de comprometidas ganadas a tiempo, sin mover la fecha.
    promisesDelta() {
      if (!this.previous) return null;
      const d = compareNumbers(
        this.summary.promises_rate,
        this.previous.promises_rate
      );
      return this.deltaText(
        d,
        d &&
          this.$t('CASE_TICKETS.COMMERCIAL.METRICS.OVERVIEW.POINTS', {
            n: d.diff,
          })
      );
    },
    recoveredDelta() {
      if (!this.previous) return null;
      const d = compareNumbers(
        this.summary.recovered_count,
        this.previous.recovered_count
      );
      return this.deltaText(d, d && String(d.diff));
    },
    // Ranking: por monto ganado si todo es de una moneda; si no, por cantidad.
    assignees() {
      const rows = this.report.by_assignee || [];
      const currencies = new Set(
        rows.flatMap(r => (r.won_value || []).map(v => v.currency))
      );
      const metric = r =>
        currencies.size === 1
          ? (r.won_value || []).reduce((a, v) => a + Number(v.amount), 0)
          : r.won_count;
      const list = rows.map(r => ({ ...r, metric: metric(r) }));
      return list.sort(
        (a, b) => b.metric - a.metric || b.open_count - a.open_count
      );
    },
    maxMetric() {
      return Math.max(1, ...this.assignees.map(r => r.metric));
    },
    byType() {
      return this.report.by_type || [];
    },
  },
  methods: {
    money(values, field) {
      return moneyList(values, field);
    },
    pct(value) {
      return value === null || value === undefined ? '—' : `${value}%`;
    },
    // { dir, good } + texto de la diferencia → { text, good } para KpiTile.
    deltaText(d, amount) {
      if (!d) return null;
      const range = this.compareLabel;
      if (d.dir === 'same') {
        return {
          text: this.$t('CASE_TICKETS.COMMERCIAL.METRICS.OVERVIEW.SAME', {
            range,
          }),
          good: null,
        };
      }
      return {
        text: `${ARROWS[d.dir]} ${amount} ${this.$t(
          'CASE_TICKETS.COMMERCIAL.METRICS.OVERVIEW.VS_RANGE',
          { range }
        )}`,
        good: d.good,
      };
    },
    days(value) {
      return value === null || value === undefined
        ? '—'
        : this.$t('CASE_TICKETS.COMMERCIAL.METRICS.KPI.DAYS', { days: value });
    },
    barWidth(value) {
      return `${Math.max(2, (value / this.maxMetric) * 100)}%`;
    },
    assigneeName(row) {
      return (
        row.assignee_name ||
        this.$t('CASE_TICKETS.COMMERCIAL.METRICS.ASSIGNEES.UNASSIGNED')
      );
    },
  },
};
</script>

<template>
  <div class="flex flex-col gap-4">
    <div class="grid gap-3 grid-cols-[repeat(auto-fit,minmax(190px,1fr))]">
      <KpiTile
        :label="$t('CASE_TICKETS.COMMERCIAL.METRICS.KPI.WON')"
        :value="money(summary.won_value)"
        :sub="
          $t('CASE_TICKETS.COMMERCIAL.METRICS.KPI.WON_SUB', {
            count: summary.won_count || 0,
          })
        "
        :delta="wonDelta"
      />
      <KpiTile
        :label="$t('CASE_TICKETS.COMMERCIAL.METRICS.KPI.WIN_RATE')"
        :value="pct(summary.win_rate)"
        :sub="
          $t('CASE_TICKETS.COMMERCIAL.METRICS.KPI.WIN_RATE_SUB', {
            won: summary.won_count || 0,
            decided: decidedCount,
          })
        "
        :delta="rateDelta"
      />
      <KpiTile
        :label="$t('CASE_TICKETS.COMMERCIAL.METRICS.OVERVIEW.AVG_TICKET')"
        :value="money(avgTicket)"
        :sub="$t('CASE_TICKETS.COMMERCIAL.METRICS.OVERVIEW.AVG_TICKET_SUB')"
        :delta="ticketDelta"
      />
      <KpiTile
        :label="$t('CASE_TICKETS.COMMERCIAL.METRICS.KPI.CYCLE')"
        :value="days(summary.avg_cycle_days)"
        :sub="$t('CASE_TICKETS.COMMERCIAL.METRICS.KPI.CYCLE_SUB')"
        :delta="cycleDelta"
      />
      <KpiTile
        :label="$t('CASE_TICKETS.COMMERCIAL.METRICS.OVERVIEW.RECOVERED')"
        :value="summary.recovered_count || 0"
        :sub="$t('CASE_TICKETS.COMMERCIAL.METRICS.OVERVIEW.RECOVERED_SUB')"
        :delta="recoveredDelta"
      />
      <KpiTile
        :label="$t('CASE_TICKETS.COMMERCIAL.METRICS.OVERVIEW.PROMISES')"
        :value="pct(summary.promises_rate)"
        :sub="
          $t('CASE_TICKETS.COMMERCIAL.METRICS.OVERVIEW.PROMISES_SUB', {
            kept: summary.promises_kept || 0,
            decided: summary.promises_decided || 0,
          })
        "
        :delta="promisesDelta"
      />
    </div>

    <!-- Ranking de vendedores -->
    <section
      class="p-4 bg-white border rounded-lg dark:bg-slate-800 border-slate-75 dark:border-slate-700"
    >
      <div class="flex items-center justify-between mb-3">
        <h2
          class="m-0 text-sm font-semibold text-slate-800 dark:text-slate-100"
        >
          {{ $t('CASE_TICKETS.COMMERCIAL.METRICS.OVERVIEW.RANKING') }}
        </h2>
        <button
          type="button"
          class="text-xs text-woot-600 dark:text-woot-300 hover:underline"
          @click="assigneesTable = !assigneesTable"
        >
          {{
            assigneesTable
              ? $t('CASE_TICKETS.COMMERCIAL.METRICS.CHART_VIEW')
              : $t('CASE_TICKETS.COMMERCIAL.METRICS.TABLE_VIEW')
          }}
        </button>
      </div>
      <p
        v-if="!assignees.length"
        class="m-0 text-sm text-slate-400 dark:text-slate-500"
      >
        —
      </p>
      <div v-else-if="!assigneesTable" class="flex flex-col gap-2">
        <div
          v-for="row in assignees"
          :key="row.assignee_id || 'none'"
          class="grid items-center gap-3 grid-cols-[9rem_1fr] group"
        >
          <span class="text-sm truncate text-slate-700 dark:text-slate-200">
            {{ assigneeName(row) }}
          </span>
          <div class="flex items-center min-w-0 gap-2">
            <div
              class="h-5 rounded-r bg-woot-500 group-hover:bg-woot-600 flex-shrink-0"
              :style="{ width: barWidth(row.metric) }"
            />
            <span
              class="text-xs whitespace-nowrap text-slate-700 dark:text-slate-200"
            >
              <strong>{{ money(row.won_value) }}</strong>
              ·
              {{
                $t('CASE_TICKETS.COMMERCIAL.METRICS.OVERVIEW.RANK_LINE', {
                  won: row.won_count,
                  rate: pct(row.win_rate),
                  open: row.open_count,
                })
              }}
            </span>
          </div>
        </div>
      </div>
      <div v-else class="overflow-x-auto">
        <table class="w-full text-sm">
          <thead>
            <tr class="text-xs text-left uppercase text-slate-500">
              <th class="py-1">
                {{ $t('CASE_TICKETS.COMMERCIAL.METRICS.ASSIGNEES.NAME') }}
              </th>
              <th class="py-1 text-right">
                {{ $t('CASE_TICKETS.COMMERCIAL.METRICS.ASSIGNEES.OPEN') }}
              </th>
              <th class="py-1 text-right">
                {{ $t('CASE_TICKETS.COMMERCIAL.METRICS.ASSIGNEES.OPEN_VALUE') }}
              </th>
              <th class="py-1 text-right">
                {{ $t('CASE_TICKETS.COMMERCIAL.METRICS.ASSIGNEES.WON') }}
              </th>
              <th class="py-1 text-right">
                {{ $t('CASE_TICKETS.COMMERCIAL.METRICS.ASSIGNEES.WON_VALUE') }}
              </th>
              <th class="py-1 text-right">
                {{ $t('CASE_TICKETS.COMMERCIAL.METRICS.ASSIGNEES.LOST') }}
              </th>
              <th class="py-1 text-right">
                {{ $t('CASE_TICKETS.COMMERCIAL.METRICS.ASSIGNEES.WIN_RATE') }}
              </th>
            </tr>
          </thead>
          <tbody class="text-slate-700 dark:text-slate-200">
            <tr
              v-for="row in assignees"
              :key="row.assignee_id || 'none'"
              class="border-t border-slate-50 dark:border-slate-700"
            >
              <td class="py-1.5">{{ assigneeName(row) }}</td>
              <td class="py-1.5 text-right">{{ row.open_count }}</td>
              <td class="py-1.5 text-right">{{ money(row.open_value) }}</td>
              <td class="py-1.5 text-right">{{ row.won_count }}</td>
              <td class="py-1.5 text-right">{{ money(row.won_value) }}</td>
              <td class="py-1.5 text-right">{{ row.lost_count }}</td>
              <td class="py-1.5 text-right font-semibold">
                {{ pct(row.win_rate) }}
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </section>

    <!-- Por tipo -->
    <section
      class="p-4 bg-white border rounded-lg dark:bg-slate-800 border-slate-75 dark:border-slate-700"
    >
      <h2
        class="m-0 mb-3 text-sm font-semibold text-slate-800 dark:text-slate-100"
      >
        {{ $t('CASE_TICKETS.COMMERCIAL.METRICS.TYPES.TITLE') }}
      </h2>
      <table class="w-full text-sm">
        <thead>
          <tr class="text-xs text-left uppercase text-slate-500">
            <th class="py-1">
              {{ $t('CASE_TICKETS.COMMERCIAL.METRICS.TYPES.NAME') }}
            </th>
            <th class="py-1 text-right">
              {{ $t('CASE_TICKETS.COMMERCIAL.METRICS.ASSIGNEES.OPEN') }}
            </th>
            <th class="py-1 text-right">
              {{ $t('CASE_TICKETS.COMMERCIAL.METRICS.ASSIGNEES.WON') }}
            </th>
            <th class="py-1 text-right">
              {{ $t('CASE_TICKETS.COMMERCIAL.METRICS.ASSIGNEES.LOST') }}
            </th>
            <th class="py-1 text-right">
              {{ $t('CASE_TICKETS.COMMERCIAL.METRICS.ASSIGNEES.WIN_RATE') }}
            </th>
          </tr>
        </thead>
        <tbody class="text-slate-700 dark:text-slate-200">
          <tr
            v-for="row in byType"
            :key="row.case_type_id || 'none'"
            class="border-t border-slate-50 dark:border-slate-700"
          >
            <td class="py-1.5">{{ row.case_type_name || '—' }}</td>
            <td class="py-1.5 text-right">{{ row.open_count }}</td>
            <td class="py-1.5 text-right">{{ row.won_count }}</td>
            <td class="py-1.5 text-right">{{ row.lost_count }}</td>
            <td class="py-1.5 text-right font-semibold">
              {{ pct(row.win_rate) }}
            </td>
          </tr>
        </tbody>
      </table>
    </section>
  </div>
</template>
