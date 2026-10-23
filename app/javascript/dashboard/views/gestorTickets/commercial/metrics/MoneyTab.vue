<!--
  @tickets_cases — Plan-Metricas-Comercial M2: «Dinero en juego».
  Lo abierto HOY: indicadores (con lo COMPROMETIDO por el cliente esta semana y
  este mes, y «Cierra este mes» partido en confirmado + probable), el embudo
  (CommercialFunnel), «Calcular estancadas» (a pedido, con memoria: ver CalcGate
  / caseMetricsCalc) que marca ⚠ en cada franja, la lista «Requieren atención»
  (promesas vencidas primero, luego cierres vencidos, del reporte; + estancadas,
  si se calcularon) y el pronóstico por mes con su parte comprometida.
-->
<script>
import CaseReportsAPI from 'dashboard/api/caseReports';
import { formatDay, moneyList } from 'dashboard/helper/caseCommercial';
import {
  filtersKey,
  loadCalc,
  saveCalc,
} from 'dashboard/helper/caseMetricsCalc';
import CommercialFunnel from '../CommercialFunnel.vue';
import CalcGate from './CalcGate.vue';
import KpiTile from './KpiTile.vue';

const THRESHOLDS = [7, 15, 30];

export default {
  name: 'MoneyTab',
  components: { CommercialFunnel, CalcGate, KpiTile },
  props: {
    report: { type: Object, required: true },
    baseFilters: { type: Object, required: true },
    caseClass: { type: String, default: 'commercial' },
  },
  data() {
    return { threshold: 15, staleEntry: null, staleLoading: false };
  },
  computed: {
    accountId() {
      return this.$route.params.accountId;
    },
    thresholds() {
      return THRESHOLDS;
    },
    summary() {
      return this.report.summary || {};
    },
    forecast() {
      return this.report.forecast || [];
    },
    // Las estancadas no dependen del período: solo tipo, vendedor, equipo y umbral.
    staleFilters() {
      const { caseTypeId, assigneeId, teamId } = this.baseFilters;
      return { caseTypeId, assigneeId, teamId, thresholdDays: this.threshold };
    },
    staleKey() {
      return filtersKey(this.staleFilters);
    },
    stale() {
      return this.staleEntry ? this.staleEntry.data : null;
    },
    staleChanged() {
      return !!this.staleEntry && this.staleEntry.key !== this.staleKey;
    },
    closingCount() {
      return this.countOf(this.summary.closing_this_month);
    },
    // Comprometidas por el cliente (fecha prometida) y lo probable del mes.
    commitments() {
      return this.summary.commitments || {};
    },
    // Promesa vencida y cierre vencido (reporte) + estancadas (si se
    // calcularon), sin repetir. Primero las promesas: lo más cerca del dinero.
    attention() {
      const byId = {};
      (this.report.attention || []).forEach(row => {
        const promise = row.reason === 'promise_overdue';
        byId[row.id] = { ...row, promise, overdueClose: !promise };
      });
      ((this.stale && this.stale.items) || []).forEach(row => {
        byId[row.id] = { ...(byId[row.id] || row), days: row.days_in_stage };
      });
      const weight = r =>
        (r.promise ? 2 : 0) + (r.overdueClose && r.days ? 1 : 0);
      return Object.values(byId).sort(
        (a, b) => weight(b) - weight(a) || (b.amount || 0) - (a.amount || 0)
      );
    },
  },
  mounted() {
    const entry = loadCalc(this.accountId, 'stale');
    if (entry) {
      this.staleEntry = entry;
      const saved = JSON.parse(entry.key).find(([k]) => k === 'thresholdDays');
      if (saved) this.threshold = Number(saved[1]);
    }
  },
  methods: {
    async calculateStale() {
      this.staleLoading = true;
      try {
        const { data } = await CaseReportsAPI.getPipelineStale(
          this.staleFilters
        );
        this.staleEntry = saveCalc(
          this.accountId,
          'stale',
          this.staleKey,
          data
        );
      } catch (_e) {
        this.$emitter.emit('newToastMessage', {
          message: this.$t('CASE_TICKETS.COMMERCIAL.METRICS.ERROR'),
          type: 'error',
        });
      } finally {
        this.staleLoading = false;
      }
    },
    money(values, field) {
      return moneyList(values, field);
    },
    countOf(values) {
      return (values || []).reduce((a, v) => a + (v.count || 0), 0);
    },
    committedOf(row) {
      return row.committed
        ? this.money([{ currency: row.currency, amount: row.committed }])
        : '—';
    },
    day(value) {
      return formatDay(value);
    },
    open(row) {
      this.$router.push({
        name: 'gestorTickets_detail',
        params: { id: String(row.id) },
        // El caso muestra «Volver a métricas» y regresa a esta misma pestaña.
        query: { back: this.$route.fullPath },
      });
    },
    monthLabel(month) {
      const [y, m] = month.split('-').map(Number);
      return new Date(y, m - 1, 1).toLocaleDateString(undefined, {
        month: 'long',
        year: 'numeric',
      });
    },
    isPastMonth(month) {
      const d = new Date();
      const now = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(
        2,
        '0'
      )}`;
      return month < now;
    },
  },
};
</script>

<template>
  <div class="flex flex-col gap-4">
    <div class="grid gap-3 grid-cols-[repeat(auto-fit,minmax(200px,1fr))]">
      <KpiTile
        :label="$t('CASE_TICKETS.COMMERCIAL.METRICS.KPI.OPEN_VALUE')"
        :value="money(summary.open_value)"
        :sub="
          $t('CASE_TICKETS.COMMERCIAL.METRICS.KPI.OPEN_SUB', {
            count: summary.open_count || 0,
            postponed: summary.postponed_count || 0,
          })
        "
      />
      <KpiTile
        :label="$t('CASE_TICKETS.COMMERCIAL.METRICS.KPI.WEIGHTED')"
        :value="money(summary.open_value, 'weighted')"
        :sub="$t('CASE_TICKETS.COMMERCIAL.METRICS.KPI.WEIGHTED_SUB')"
      />
      <KpiTile
        :label="$t('CASE_TICKETS.COMMERCIAL.METRICS.MONEY.COMMITTED_WEEK')"
        :value="money(commitments.this_week)"
        :sub="
          $t('CASE_TICKETS.COMMERCIAL.METRICS.MONEY.COMMITTED_WEEK_SUB', {
            count: countOf(commitments.this_week),
          })
        "
      />
      <KpiTile
        :label="$t('CASE_TICKETS.COMMERCIAL.METRICS.MONEY.COMMITTED_MONTH')"
        :value="money(commitments.this_month)"
        :sub="
          $t('CASE_TICKETS.COMMERCIAL.METRICS.MONEY.COMMITTED_MONTH_SUB', {
            count: countOf(commitments.this_month),
            overdue: countOf(commitments.overdue),
          })
        "
      />
      <KpiTile
        :label="$t('CASE_TICKETS.COMMERCIAL.METRICS.MONEY.CLOSING')"
        :value="money(summary.closing_this_month)"
        :sub="
          $t('CASE_TICKETS.COMMERCIAL.METRICS.MONEY.CLOSING_SPLIT', {
            count: closingCount,
            confirmed: money(commitments.this_month),
            probable: money(commitments.probable_this_month, 'weighted'),
          })
        "
      />
    </div>

    <!-- El embudo (con sus propios filtros de moneda y cierre). -->
    <section
      class="bg-white border rounded-lg dark:bg-slate-800 border-slate-75 dark:border-slate-700"
    >
      <CommercialFunnel
        :base-filters="baseFilters"
        :case-class="caseClass"
        :stale="stale"
      />
    </section>

    <!-- Estancadas: a pedido -->
    <CalcGate
      :title="$t('CASE_TICKETS.COMMERCIAL.METRICS.MONEY.STALE_TITLE')"
      :description="
        $t('CASE_TICKETS.COMMERCIAL.METRICS.MONEY.STALE_DESCRIPTION', {
          days: threshold,
        })
      "
      :calculated-at="staleEntry ? staleEntry.at : null"
      :loading="staleLoading"
      :filters-changed="staleChanged"
      @calculate="calculateStale"
    >
      <template #controls>
        <select
          v-model.number="threshold"
          class="!mb-0 !h-7 !py-0 text-xs w-36"
          :aria-label="$t('CASE_TICKETS.COMMERCIAL.METRICS.MONEY.THRESHOLD')"
        >
          <option v-for="d in thresholds" :key="d" :value="d">
            {{
              $t('CASE_TICKETS.COMMERCIAL.METRICS.MONEY.THRESHOLD_OPTION', {
                days: d,
              })
            }}
          </option>
        </select>
      </template>
      <p v-if="stale" class="m-0 text-sm text-slate-700 dark:text-slate-200">
        {{
          stale.items.length
            ? $t('CASE_TICKETS.COMMERCIAL.METRICS.MONEY.STALE_RESULT', {
                count: stale.items.length,
                days: stale.threshold_days,
              })
            : $t('CASE_TICKETS.COMMERCIAL.METRICS.MONEY.STALE_NONE', {
                days: stale.threshold_days,
              })
        }}
      </p>
    </CalcGate>

    <!-- Requieren atención -->
    <section
      class="p-4 overflow-x-auto bg-white border rounded-lg dark:bg-slate-800 border-slate-75 dark:border-slate-700"
    >
      <h2
        class="m-0 mb-1 text-sm font-semibold text-slate-800 dark:text-slate-100"
      >
        {{ $t('CASE_TICKETS.COMMERCIAL.METRICS.MONEY.ATTENTION') }}
      </h2>
      <p class="m-0 mb-3 text-xs text-slate-500 dark:text-slate-400">
        {{ $t('CASE_TICKETS.COMMERCIAL.METRICS.MONEY.ATTENTION_HELP') }}
      </p>
      <p
        v-if="!attention.length"
        class="m-0 text-sm text-slate-400 dark:text-slate-500"
      >
        {{ $t('CASE_TICKETS.COMMERCIAL.METRICS.MONEY.ATTENTION_NONE') }}
      </p>
      <table v-else class="w-full text-sm">
        <thead>
          <tr class="text-xs text-left uppercase text-slate-500">
            <th class="py-1">
              {{ $t('CASE_TICKETS.COMMERCIAL.METRICS.MONEY.OPPORTUNITY') }}
            </th>
            <th class="py-1">
              {{ $t('CASE_TICKETS.COMMERCIAL.METRICS.ASSIGNEES.NAME') }}
            </th>
            <th class="py-1">
              {{ $t('CASE_TICKETS.COMMERCIAL.FIELDS.STAGE') }}
            </th>
            <th class="py-1 text-right">
              {{ $t('CASE_TICKETS.COMMERCIAL.FIELDS.AMOUNT') }}
            </th>
            <th class="py-1">
              {{ $t('CASE_TICKETS.COMMERCIAL.METRICS.MONEY.WHY') }}
            </th>
          </tr>
        </thead>
        <tbody class="text-slate-700 dark:text-slate-200">
          <tr
            v-for="row in attention"
            :key="row.id"
            class="border-t border-slate-50 dark:border-slate-700"
          >
            <td class="py-1.5 pr-3">
              <button
                type="button"
                class="text-left hover:underline"
                @click="open(row)"
              >
                <span class="font-mono text-xs font-semibold">
                  {{ row.folio }}
                </span>
                <span class="block max-w-xs truncate">{{ row.title }}</span>
              </button>
            </td>
            <td class="py-1.5 pr-3">{{ row.assignee_name || '—' }}</td>
            <td class="py-1.5 pr-3">{{ row.stage || '—' }}</td>
            <td class="py-1.5 pr-3 text-right tabular-nums">
              {{ money([row]) }}
            </td>
            <td class="py-1.5">
              <span class="flex flex-wrap gap-1">
                <span
                  v-if="row.promise"
                  class="px-1.5 py-0.5 text-[11px] font-semibold rounded-full bg-red-100 text-red-800 dark:bg-red-900/40 dark:text-red-300"
                >
                  {{
                    $t(
                      'CASE_TICKETS.COMMERCIAL.METRICS.MONEY.PROMISE_OVERDUE',
                      {
                        date: day(row.expected_close_at),
                      }
                    )
                  }}
                </span>
                <span
                  v-if="row.overdueClose"
                  class="px-1.5 py-0.5 text-[11px] rounded-full bg-red-100 text-red-800 dark:bg-red-900/40 dark:text-red-300"
                >
                  {{
                    $t('CASE_TICKETS.COMMERCIAL.METRICS.MONEY.CLOSE_OVERDUE', {
                      date: day(row.expected_close_at),
                    })
                  }}
                </span>
                <span
                  v-if="row.days"
                  class="px-1.5 py-0.5 text-[11px] rounded-full bg-amber-100 text-amber-800 dark:bg-amber-900/40 dark:text-amber-300"
                >
                  {{
                    $t('CASE_TICKETS.COMMERCIAL.METRICS.MONEY.STALE_DAYS', {
                      days: row.days,
                    })
                  }}
                </span>
              </span>
            </td>
          </tr>
        </tbody>
      </table>
    </section>

    <!-- Pronóstico por mes de cierre -->
    <section
      class="p-4 bg-white border rounded-lg dark:bg-slate-800 border-slate-75 dark:border-slate-700"
    >
      <h2
        class="m-0 mb-3 text-sm font-semibold text-slate-800 dark:text-slate-100"
      >
        {{ $t('CASE_TICKETS.COMMERCIAL.METRICS.FORECAST.TITLE') }}
      </h2>
      <p
        v-if="!forecast.length"
        class="m-0 text-sm text-slate-400 dark:text-slate-500"
      >
        {{ $t('CASE_TICKETS.COMMERCIAL.METRICS.FORECAST.EMPTY') }}
      </p>
      <table v-else class="w-full text-sm">
        <thead>
          <tr class="text-xs text-left uppercase text-slate-500">
            <th class="py-1">
              {{ $t('CASE_TICKETS.COMMERCIAL.METRICS.FORECAST.MONTH') }}
            </th>
            <th class="py-1 text-right">
              {{ $t('CASE_TICKETS.COMMERCIAL.METRICS.FORECAST.COUNT') }}
            </th>
            <th class="py-1 text-right">
              {{ $t('CASE_TICKETS.COMMERCIAL.METRICS.FORECAST.AMOUNT') }}
            </th>
            <th class="py-1 text-right">
              {{ $t('CASE_TICKETS.COMMERCIAL.METRICS.FORECAST.COMMITTED') }}
            </th>
            <th class="py-1 text-right">
              {{ $t('CASE_TICKETS.COMMERCIAL.METRICS.FORECAST.WEIGHTED') }}
            </th>
          </tr>
        </thead>
        <tbody class="text-slate-700 dark:text-slate-200">
          <tr
            v-for="row in forecast"
            :key="`${row.month}-${row.currency}`"
            class="border-t border-slate-50 dark:border-slate-700"
          >
            <td class="py-1.5">
              {{ monthLabel(row.month) }}
              <span
                v-if="isPastMonth(row.month)"
                class="ml-1 px-1.5 py-0.5 text-[10px] rounded bg-amber-100 text-amber-800 dark:bg-amber-900/40 dark:text-amber-300"
              >
                {{ $t('CASE_TICKETS.COMMERCIAL.METRICS.FORECAST.PAST') }}
              </span>
            </td>
            <td class="py-1.5 text-right">{{ row.count }}</td>
            <td class="py-1.5 text-right">{{ money([row]) }}</td>
            <td class="py-1.5 text-right text-teal-800 dark:text-teal-200">
              {{ committedOf(row) }}
            </td>
            <td class="py-1.5 text-right font-semibold">
              {{ money([row], 'weighted') }}
            </td>
          </tr>
        </tbody>
      </table>
    </section>
  </div>
</template>
