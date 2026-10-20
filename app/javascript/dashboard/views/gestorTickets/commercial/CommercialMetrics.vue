<!--
  @tickets_cases — Plan-Clase-Comercial F5
  Métricas del embudo comercial (GET /api/v2/.../case_reports/pipeline).
  Lo abierto es foto de hoy; lo decidido se acota al período por fecha de cierre.
  Los montos van SIEMPRE por moneda (cada valor es una lista { currency, amount }).
  Las barras son de una sola serie (conteo), con etiqueta directa y tooltip; cada
  bloque tiene vista de tabla.
-->
<script>
import { mapGetters } from 'vuex';
import CaseReportsAPI from 'dashboard/api/caseReports';
import { formatMoney } from 'dashboard/helper/caseCommercial';
import CaseClassSwitcher from '../CaseClassSwitcher.vue'; // Plan-Casos E1
import CaseTypeSelect from '../filters/CaseTypeSelect.vue'; // Plan-Casos E1.1
import { loadCaseState, saveCaseState } from 'dashboard/helper/caseClasses';
// Plan-Casos E1.3 — mismo período que las Métricas de Soporte.
import { METRIC_PERIODS as PERIODS } from 'dashboard/helper/caseFilters';
import MetricsPeriodPicker from '../filters/MetricsPeriodPicker.vue';

export default {
  name: 'CommercialMetrics',
  components: { CaseClassSwitcher, CaseTypeSelect, MetricsPeriodPicker },
  props: {
    caseClass: { type: String, default: 'commercial' },
  },
  data() {
    return {
      period: '90d',
      caseTypeId: '',
      assigneeId: '',
      teamId: '', // Plan-Casos E1.3
      report: null,
      isLoading: false,
      // Vista de tabla por bloque de barras (accesibilidad / exportar a ojo).
      tableView: { stages: false, reasons: false },
    };
  },
  computed: {
    ...mapGetters({
      agents: 'agents/getAgents',
      teams: 'teams/getTeams',
    }),
    summary() {
      return this.report?.summary || {};
    },
    decidedCount() {
      return (this.summary.won_count || 0) + (this.summary.lost_count || 0);
    },
    stages() {
      return this.report?.stages || [];
    },
    reasons() {
      return this.report?.loss_reasons || [];
    },
    byAssignee() {
      return this.report?.by_assignee || [];
    },
    byType() {
      return this.report?.by_type || [];
    },
    forecast() {
      return this.report?.forecast || [];
    },
    maxStageCount() {
      return Math.max(1, ...this.stages.map(s => s.count));
    },
    maxReasonCount() {
      return Math.max(1, ...this.reasons.map(r => r.count));
    },
    currentMonth() {
      const d = new Date();
      return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`;
    },
    isEmpty() {
      return (
        this.report &&
        !this.summary.open_count &&
        !this.decidedCount &&
        !this.summary.cancelled_count
      );
    },
  },
  mounted() {
    this.$store.dispatch('caseTickets/fetchTypes');
    this.$store.dispatch('agents/get');
    // Plan-Casos E1.2 — vuelve con el tipo, período y vendedor que dejaste.
    const st = loadCaseState(this.$route.params.accountId, this.caseClass);
    const saved = st.metrics || {};
    this.caseTypeId = st.type ?? '';
    if (PERIODS.some(p => p.key === saved.period)) this.period = saved.period;
    this.assigneeId = saved.assigneeId || '';
    this.teamId = saved.teamId || '';
    this.$store.dispatch('teams/get');
    this.fetch();
  },
  methods: {
    filters() {
      const period = PERIODS.find(p => p.key === this.period);
      const f = {
        caseTypeId: this.caseTypeId || undefined,
        assigneeId: this.assigneeId || undefined,
        teamId: this.teamId || undefined, // E1.3 — la API ya filtra por equipo
      };
      if (period?.days) {
        const now = Math.floor(Date.now() / 1000);
        f.from = now - period.days * 86400;
        f.to = now;
      }
      return f;
    },
    async fetch() {
      saveCaseState(this.$route.params.accountId, this.caseClass, {
        type: this.caseTypeId,
        metrics: {
          period: this.period,
          assigneeId: this.assigneeId,
          teamId: this.teamId,
        },
      });
      this.isLoading = true;
      try {
        const { data } = await CaseReportsAPI.getPipeline(this.filters());
        this.report = data;
      } catch (_e) {
        this.$emitter.emit('newToastMessage', {
          message: this.$t('CASE_TICKETS.COMMERCIAL.METRICS.ERROR'),
          type: 'error',
        });
      } finally {
        this.isLoading = false;
      }
    },
    onTypeChange(id) {
      this.caseTypeId = id;
      this.fetch();
    },
    setPeriod(key) {
      this.period = key;
      this.fetch();
    },
    // [{ currency, amount }] → "$1,000 MXN · $500 USD"; vacío → "—".
    moneyList(values, field = 'amount') {
      const list = (values || []).filter(v => v[field] !== undefined);
      if (!list.length) return '—';
      return list.map(v => formatMoney(v[field], v.currency)).join(' · ');
    },
    pct(value) {
      return value === null || value === undefined ? '—' : `${value}%`;
    },
    barWidth(count, max) {
      return `${Math.max(2, (count / max) * 100)}%`;
    },
    stageLabel(stage) {
      return (
        stage.label ||
        this.$t('CASE_TICKETS.COMMERCIAL.METRICS.STAGES.NO_STAGE')
      );
    },
    stageTooltip(stage) {
      return [
        this.stageLabel(stage),
        this.$t('CASE_TICKETS.COMMERCIAL.METRICS.STAGES.COUNT', {
          count: stage.count,
        }),
        `${this.$t('CASE_TICKETS.COMMERCIAL.FIELDS.AMOUNT')}: ${this.moneyList(
          stage.values
        )}`,
        `${this.$t(
          'CASE_TICKETS.COMMERCIAL.FIELDS.WEIGHTED'
        )}: ${this.moneyList(stage.values, 'weighted')}`,
      ].join('\n');
    },
    reasonLabel(reason) {
      return (
        reason.label ||
        this.$t('CASE_TICKETS.COMMERCIAL.METRICS.REASONS.NO_REASON')
      );
    },
    outcomeLabel(outcome) {
      return this.$t(`CASE_TICKETS.COMMERCIAL.OUTCOMES.${outcome}`);
    },
    monthLabel(month) {
      const [y, m] = month.split('-').map(Number);
      return new Date(y, m - 1, 1).toLocaleDateString(undefined, {
        month: 'long',
        year: 'numeric',
      });
    },
    isPastMonth(month) {
      return month < this.currentMonth;
    },
  },
};
</script>

<template>
  <div
    class="flex flex-col flex-1 w-full h-full overflow-hidden bg-slate-25 dark:bg-slate-900"
  >
    <!-- Encabezado + filtros (una sola fila) -->
    <div
      class="flex flex-col flex-shrink-0 gap-3 px-6 py-4 bg-white border-b dark:bg-slate-900 border-slate-50 dark:border-slate-800/50"
    >
      <div class="flex flex-wrap items-center justify-between gap-3">
        <div class="flex flex-wrap items-center gap-3">
          <!-- Plan-Casos E1 — el selector Comercial | Soporte es el título -->
          <CaseClassSwitcher
            :case-class="caseClass"
            :title="$t('CASE_TICKETS.CLASSES.COMMERCIAL.METRICS')"
          />
          <!-- E1.1 — el tipo, junto a la clase -->
          <CaseTypeSelect
            :case-class="caseClass"
            :value="caseTypeId"
            @input="onTypeChange"
          />
        </div>
        <div class="flex flex-wrap items-center gap-2">
          <select
            v-model="assigneeId"
            class="!mb-0 text-sm w-44"
            @change="fetch"
          >
            <option value="">
              {{ $t('CASE_TICKETS.COMMERCIAL.METRICS.ALL_AGENTS') }}
            </option>
            <option v-for="a in agents" :key="a.id" :value="a.id">
              {{ a.name }}
            </option>
          </select>
          <select v-model="teamId" class="!mb-0 text-sm w-40" @change="fetch">
            <option value="">{{ $t('CASE_TICKETS.FILTERS.ALL_TEAMS') }}</option>
            <option v-for="t in teams" :key="t.id" :value="t.id">
              {{ t.name }}
            </option>
          </select>
          <MetricsPeriodPicker :value="period" @input="setPeriod" />
        </div>
      </div>
      <p class="m-0 text-xs text-slate-500 dark:text-slate-400">
        {{ $t('CASE_TICKETS.COMMERCIAL.METRICS.HELP') }}
      </p>
    </div>

    <div
      v-if="isLoading && !report"
      class="flex items-center justify-center flex-1 text-slate-400 dark:text-slate-500"
    >
      {{ $t('CASE_TICKETS.COMMERCIAL.METRICS.LOADING') }}
    </div>
    <div
      v-else-if="isEmpty"
      class="flex items-center justify-center flex-1 text-slate-400 dark:text-slate-500"
    >
      {{ $t('CASE_TICKETS.COMMERCIAL.METRICS.EMPTY') }}
    </div>

    <div
      v-else-if="report"
      class="flex flex-col flex-1 gap-4 px-6 py-4 overflow-y-auto"
      :class="isLoading ? 'opacity-60' : ''"
    >
      <!-- KPIs -->
      <div class="grid gap-3 grid-cols-[repeat(auto-fit,minmax(200px,1fr))]">
        <div
          class="p-4 bg-white border rounded-lg dark:bg-slate-800 border-slate-75 dark:border-slate-700"
        >
          <p class="m-0 text-xs uppercase text-slate-500 dark:text-slate-400">
            {{ $t('CASE_TICKETS.COMMERCIAL.METRICS.KPI.OPEN_VALUE') }}
          </p>
          <p
            class="m-0 mt-1 text-lg font-bold text-slate-800 dark:text-slate-100"
          >
            {{ moneyList(summary.open_value) }}
          </p>
          <p class="m-0 mt-1 text-xs text-slate-500 dark:text-slate-400">
            {{
              $t('CASE_TICKETS.COMMERCIAL.METRICS.KPI.OPEN_SUB', {
                count: summary.open_count || 0,
                postponed: summary.postponed_count || 0,
              })
            }}
          </p>
        </div>
        <div
          class="p-4 bg-white border rounded-lg dark:bg-slate-800 border-slate-75 dark:border-slate-700"
        >
          <p class="m-0 text-xs uppercase text-slate-500 dark:text-slate-400">
            {{ $t('CASE_TICKETS.COMMERCIAL.METRICS.KPI.WEIGHTED') }}
          </p>
          <p
            class="m-0 mt-1 text-lg font-bold text-slate-800 dark:text-slate-100"
          >
            {{ moneyList(summary.open_value, 'weighted') }}
          </p>
          <p class="m-0 mt-1 text-xs text-slate-500 dark:text-slate-400">
            {{ $t('CASE_TICKETS.COMMERCIAL.METRICS.KPI.WEIGHTED_SUB') }}
          </p>
        </div>
        <div
          class="p-4 bg-white border rounded-lg dark:bg-slate-800 border-slate-75 dark:border-slate-700"
        >
          <p class="m-0 text-xs uppercase text-slate-500 dark:text-slate-400">
            {{ $t('CASE_TICKETS.COMMERCIAL.METRICS.KPI.WON') }}
          </p>
          <p
            class="m-0 mt-1 text-lg font-bold text-slate-800 dark:text-slate-100"
          >
            {{ moneyList(summary.won_value) }}
          </p>
          <p class="m-0 mt-1 text-xs text-slate-500 dark:text-slate-400">
            {{
              $t('CASE_TICKETS.COMMERCIAL.METRICS.KPI.WON_SUB', {
                count: summary.won_count || 0,
              })
            }}
          </p>
        </div>
        <div
          class="p-4 bg-white border rounded-lg dark:bg-slate-800 border-slate-75 dark:border-slate-700"
        >
          <p class="m-0 text-xs uppercase text-slate-500 dark:text-slate-400">
            {{ $t('CASE_TICKETS.COMMERCIAL.METRICS.KPI.WIN_RATE') }}
          </p>
          <p
            class="m-0 mt-1 text-2xl font-bold text-slate-800 dark:text-slate-100"
          >
            {{ pct(summary.win_rate) }}
          </p>
          <p class="m-0 mt-1 text-xs text-slate-500 dark:text-slate-400">
            {{
              $t('CASE_TICKETS.COMMERCIAL.METRICS.KPI.WIN_RATE_SUB', {
                won: summary.won_count || 0,
                decided: decidedCount,
              })
            }}
          </p>
        </div>
        <div
          class="p-4 bg-white border rounded-lg dark:bg-slate-800 border-slate-75 dark:border-slate-700"
        >
          <p class="m-0 text-xs uppercase text-slate-500 dark:text-slate-400">
            {{ $t('CASE_TICKETS.COMMERCIAL.METRICS.KPI.CYCLE') }}
          </p>
          <p
            class="m-0 mt-1 text-2xl font-bold text-slate-800 dark:text-slate-100"
          >
            {{
              summary.avg_cycle_days === null ||
              summary.avg_cycle_days === undefined
                ? '—'
                : $t('CASE_TICKETS.COMMERCIAL.METRICS.KPI.DAYS', {
                    days: summary.avg_cycle_days,
                  })
            }}
          </p>
          <p class="m-0 mt-1 text-xs text-slate-500 dark:text-slate-400">
            {{ $t('CASE_TICKETS.COMMERCIAL.METRICS.KPI.CYCLE_SUB') }}
          </p>
        </div>
        <div
          class="p-4 bg-white border rounded-lg dark:bg-slate-800 border-slate-75 dark:border-slate-700"
        >
          <p class="m-0 text-xs uppercase text-slate-500 dark:text-slate-400">
            {{ $t('CASE_TICKETS.COMMERCIAL.METRICS.KPI.LOST') }}
          </p>
          <p
            class="m-0 mt-1 text-2xl font-bold text-slate-800 dark:text-slate-100"
          >
            {{ summary.lost_count || 0 }} / {{ summary.cancelled_count || 0 }}
          </p>
          <p class="m-0 mt-1 text-xs text-slate-500 dark:text-slate-400">
            {{
              $t('CASE_TICKETS.COMMERCIAL.METRICS.KPI.LOST_SUB', {
                recovered: summary.recovered_count || 0,
              })
            }}
          </p>
        </div>
      </div>

      <div class="grid gap-4 lg:grid-cols-2">
        <!-- Embudo por etapa: una serie (conteo), etiqueta directa + tooltip -->
        <section
          class="p-4 bg-white border rounded-lg dark:bg-slate-800 border-slate-75 dark:border-slate-700"
        >
          <div class="flex items-center justify-between mb-3">
            <h2
              class="m-0 text-sm font-semibold text-slate-800 dark:text-slate-100"
            >
              {{ $t('CASE_TICKETS.COMMERCIAL.METRICS.STAGES.TITLE') }}
            </h2>
            <button
              type="button"
              class="text-xs text-woot-600 dark:text-woot-300 hover:underline"
              @click="tableView.stages = !tableView.stages"
            >
              {{
                tableView.stages
                  ? $t('CASE_TICKETS.COMMERCIAL.METRICS.CHART_VIEW')
                  : $t('CASE_TICKETS.COMMERCIAL.METRICS.TABLE_VIEW')
              }}
            </button>
          </div>
          <p
            v-if="!stages.length"
            class="m-0 text-sm text-slate-400 dark:text-slate-500"
          >
            —
          </p>
          <div v-else-if="!tableView.stages" class="flex flex-col gap-2">
            <div
              v-for="stage in stages"
              :key="stage.label || 'none'"
              class="grid items-center gap-3 grid-cols-[8rem_1fr] group"
              :title="stageTooltip(stage)"
            >
              <span class="text-sm truncate text-slate-600 dark:text-slate-300">
                {{ stageLabel(stage) }}
              </span>
              <div class="flex items-center min-w-0 gap-2">
                <div
                  class="h-5 rounded-r bg-woot-500 group-hover:bg-woot-600 flex-shrink-0"
                  :style="{ width: barWidth(stage.count, maxStageCount) }"
                />
                <span
                  class="text-xs whitespace-nowrap text-slate-700 dark:text-slate-200"
                >
                  <strong>{{ stage.count }}</strong> ·
                  {{ moneyList(stage.values) }}
                </span>
              </div>
            </div>
          </div>
          <table v-else class="w-full text-sm">
            <thead>
              <tr class="text-xs text-left uppercase text-slate-500">
                <th class="py-1">
                  {{ $t('CASE_TICKETS.COMMERCIAL.FIELDS.STAGE') }}
                </th>
                <th class="py-1 text-right">#</th>
                <th class="py-1 text-right">
                  {{ $t('CASE_TICKETS.COMMERCIAL.FIELDS.AMOUNT') }}
                </th>
                <th class="py-1 text-right">
                  {{ $t('CASE_TICKETS.COMMERCIAL.FIELDS.WEIGHTED') }}
                </th>
              </tr>
            </thead>
            <tbody class="text-slate-700 dark:text-slate-200">
              <tr v-for="stage in stages" :key="stage.label || 'none'">
                <td class="py-1">{{ stageLabel(stage) }}</td>
                <td class="py-1 text-right">{{ stage.count }}</td>
                <td class="py-1 text-right">{{ moneyList(stage.values) }}</td>
                <td class="py-1 text-right">
                  {{ moneyList(stage.values, 'weighted') }}
                </td>
              </tr>
            </tbody>
          </table>
        </section>

        <!-- Motivos de pérdida / cancelación -->
        <section
          class="p-4 bg-white border rounded-lg dark:bg-slate-800 border-slate-75 dark:border-slate-700"
        >
          <div class="flex items-center justify-between mb-3">
            <h2
              class="m-0 text-sm font-semibold text-slate-800 dark:text-slate-100"
            >
              {{ $t('CASE_TICKETS.COMMERCIAL.METRICS.REASONS.TITLE') }}
            </h2>
            <button
              type="button"
              class="text-xs text-woot-600 dark:text-woot-300 hover:underline"
              @click="tableView.reasons = !tableView.reasons"
            >
              {{
                tableView.reasons
                  ? $t('CASE_TICKETS.COMMERCIAL.METRICS.CHART_VIEW')
                  : $t('CASE_TICKETS.COMMERCIAL.METRICS.TABLE_VIEW')
              }}
            </button>
          </div>
          <p
            v-if="!reasons.length"
            class="m-0 text-sm text-slate-400 dark:text-slate-500"
          >
            —
          </p>
          <div v-else-if="!tableView.reasons" class="flex flex-col gap-2">
            <div
              v-for="r in reasons"
              :key="`${r.outcome}-${r.label}`"
              class="grid items-center gap-3 grid-cols-[10rem_1fr] group"
              :title="`${outcomeLabel(r.outcome)} · ${reasonLabel(r)}: ${
                r.count
              }`"
            >
              <span class="text-sm truncate text-slate-600 dark:text-slate-300">
                {{ reasonLabel(r) }}
                <span class="text-xs text-slate-400 dark:text-slate-500">
                  · {{ outcomeLabel(r.outcome) }}
                </span>
              </span>
              <div class="flex items-center min-w-0 gap-2">
                <div
                  class="h-5 rounded-r bg-slate-400 dark:bg-slate-500 group-hover:bg-slate-500 flex-shrink-0"
                  :style="{ width: barWidth(r.count, maxReasonCount) }"
                />
                <strong class="text-xs text-slate-700 dark:text-slate-200">{{
                  r.count
                }}</strong>
              </div>
            </div>
          </div>
          <table v-else class="w-full text-sm">
            <thead>
              <tr class="text-xs text-left uppercase text-slate-500">
                <th class="py-1">
                  {{ $t('CASE_TICKETS.COMMERCIAL.FIELDS.REASON') }}
                </th>
                <th class="py-1">
                  {{ $t('CASE_TICKETS.COMMERCIAL.FIELDS.OUTCOME') }}
                </th>
                <th class="py-1 text-right">#</th>
              </tr>
            </thead>
            <tbody class="text-slate-700 dark:text-slate-200">
              <tr v-for="r in reasons" :key="`${r.outcome}-${r.label}`">
                <td class="py-1">{{ reasonLabel(r) }}</td>
                <td class="py-1">{{ outcomeLabel(r.outcome) }}</td>
                <td class="py-1 text-right">{{ r.count }}</td>
              </tr>
            </tbody>
          </table>
        </section>
      </div>

      <!-- Por vendedor -->
      <section
        class="p-4 overflow-x-auto bg-white border rounded-lg dark:bg-slate-800 border-slate-75 dark:border-slate-700"
      >
        <h2
          class="m-0 mb-3 text-sm font-semibold text-slate-800 dark:text-slate-100"
        >
          {{ $t('CASE_TICKETS.COMMERCIAL.METRICS.ASSIGNEES.TITLE') }}
        </h2>
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
                {{ $t('CASE_TICKETS.COMMERCIAL.METRICS.ASSIGNEES.WEIGHTED') }}
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
              v-for="row in byAssignee"
              :key="row.assignee_id || 'none'"
              class="border-t border-slate-50 dark:border-slate-700"
            >
              <td class="py-1.5">
                {{
                  row.assignee_name ||
                  $t('CASE_TICKETS.COMMERCIAL.METRICS.ASSIGNEES.UNASSIGNED')
                }}
              </td>
              <td class="py-1.5 text-right">{{ row.open_count }}</td>
              <td class="py-1.5 text-right">{{ moneyList(row.open_value) }}</td>
              <td class="py-1.5 text-right">
                {{ moneyList(row.open_value, 'weighted') }}
              </td>
              <td class="py-1.5 text-right">{{ row.won_count }}</td>
              <td class="py-1.5 text-right">{{ moneyList(row.won_value) }}</td>
              <td class="py-1.5 text-right">{{ row.lost_count }}</td>
              <td class="py-1.5 text-right font-semibold">
                {{ pct(row.win_rate) }}
              </td>
            </tr>
          </tbody>
        </table>
      </section>

      <div class="grid gap-4 lg:grid-cols-2">
        <!-- Pronóstico por mes -->
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
                <td class="py-1.5 text-right">{{ moneyList([row]) }}</td>
                <td class="py-1.5 text-right font-semibold">
                  {{ moneyList([row], 'weighted') }}
                </td>
              </tr>
            </tbody>
          </table>
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
    </div>
  </div>
</template>
