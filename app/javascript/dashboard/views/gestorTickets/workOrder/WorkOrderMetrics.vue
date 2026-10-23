<!--
  @tickets_cases — Plan-Clase-Orden-de-Trabajo F3
  Métricas de órdenes de trabajo (GET /api/v2/.../case_reports/work_orders).
  Lo abierto es foto de hoy; lo terminado se acota al período por la fecha en
  que se terminó. Cumplimiento = terminada a más tardar el día de su última
  visita. Barras de una sola serie (conteo) en el color de la clase, con
  etiqueta directa, tooltip y vista de tabla; por técnico y por tipo en tablas.
-->
<script>
import { mapGetters } from 'vuex';
import CaseReportsAPI from 'dashboard/api/caseReports';
import { formatMoney } from 'dashboard/helper/caseCommercial';
import { formatHours } from 'dashboard/helper/caseWorkOrder';
import CaseClassSwitcher from '../CaseClassSwitcher.vue';
import CaseTypeSelect from '../filters/CaseTypeSelect.vue';
import CalendarPeriodPicker from '../filters/CalendarPeriodPicker.vue';
import { loadCaseState, saveCaseState } from 'dashboard/helper/caseClasses';
// Plan-Metricas-Comercial — mismo período de calendario que Comercial.
import { toEpoch } from 'dashboard/helper/caseMetricsPeriod';
import caseMetricsPeriodMixin from 'dashboard/mixins/caseMetricsPeriodMixin';

const BASE = 'CASE_TICKETS.WORK_ORDER.METRICS';

export default {
  name: 'WorkOrderMetrics',
  components: { CaseClassSwitcher, CaseTypeSelect, CalendarPeriodPicker },
  mixins: [caseMetricsPeriodMixin],
  props: {
    caseClass: { type: String, default: 'work_order' },
  },
  data() {
    return {
      caseTypeId: '',
      assigneeId: '',
      teamId: '',
      report: null,
      isLoading: false,
      tableView: { stages: false, timing: false },
    };
  },
  computed: {
    ...mapGetters({
      agents: 'agents/getAgents',
      teams: 'teams/getTeams',
      caseSettings: 'caseTickets/getCaseSettings',
    }),
    summary() {
      return this.report?.summary || {};
    },
    stages() {
      return this.report?.stages || [];
    },
    timing() {
      return this.report?.timing || [];
    },
    breakdowns() {
      return [
        {
          key: 'assignee',
          title: this.$t(`${BASE}.BY_TECHNICIAN`),
          rows: this.report?.by_assignee || [],
          empty: this.$t(`${BASE}.UNASSIGNED`),
        },
        {
          key: 'type',
          title: this.$t(`${BASE}.BY_TYPE`),
          rows: this.report?.by_type || [],
          empty: this.$t(`${BASE}.NO_TYPE`),
        },
      ];
    },
    maxStageCount() {
      return Math.max(1, ...this.stages.map(s => s.count));
    },
    maxTimingCount() {
      return Math.max(1, ...this.timing.map(t => t.count));
    },
    isEmpty() {
      return (
        this.report &&
        !this.summary.open_count &&
        !this.summary.finished_count &&
        !this.summary.cancelled_count
      );
    },
  },
  mounted() {
    this.$store.dispatch('caseTickets/fetchTypes');
    this.$store.dispatch('caseTickets/fetchSettings');
    this.$store.dispatch('agents/get');
    this.$store.dispatch('teams/get');
    // Vuelve con el tipo, período, técnico y equipo que dejaste.
    const st = loadCaseState(this.$route.params.accountId, this.caseClass);
    const saved = st.metrics || {};
    this.caseTypeId = st.type ?? '';
    this.restorePeriod(saved);
    this.assigneeId = saved.assigneeId || '';
    this.teamId = saved.teamId || '';
    this.fetch();
  },
  methods: {
    t(key, params) {
      return this.$t(`${BASE}.${key}`, params);
    },
    filters() {
      const f = {
        caseTypeId: this.caseTypeId || undefined,
        assigneeId: this.assigneeId || undefined,
        teamId: this.teamId || undefined,
      };
      const r = this.periodRangeOf();
      if (r) {
        f.from = toEpoch(r.from);
        f.to = toEpoch(r.to);
      }
      return f;
    },
    async fetch() {
      saveCaseState(this.$route.params.accountId, this.caseClass, {
        type: this.caseTypeId,
        metrics: {
          ...this.periodState(),
          assigneeId: this.assigneeId,
          teamId: this.teamId,
        },
      });
      this.isLoading = true;
      try {
        const { data } = await CaseReportsAPI.getWorkOrders(this.filters());
        this.report = data;
      } catch (_e) {
        this.$emitter.emit('newToastMessage', {
          message: this.t('ERROR'),
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
    pct(value) {
      return value === null || value === undefined ? '—' : `${value}%`;
    },
    // +12% / -8% / 0%: horas reales contra estimadas.
    variance(value) {
      if (value === null || value === undefined) return '—';
      return `${value > 0 ? '+' : ''}${value}%`;
    },
    hours(value) {
      return formatHours(value);
    },
    money(value) {
      return formatMoney(value || 0, this.caseSettings?.default_currency);
    },
    barWidth(count, max) {
      return `${Math.max(2, (count / max) * 100)}%`;
    },
    stageLabel(stage) {
      return stage.label || this.t('NO_STAGE');
    },
    timingLabel(key) {
      return this.t(`TIMING.${key}`);
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
          <CaseClassSwitcher
            :case-class="caseClass"
            :title="$t('CASE_TICKETS.CLASSES.WORK_ORDER.METRICS')"
          />
          <CaseTypeSelect
            :case-class="caseClass"
            :value="caseTypeId"
            @input="onTypeChange"
          />
        </div>
        <div
          class="flex flex-wrap items-center gap-2 [&_select]:!h-8 [&_select]:!py-0"
        >
          <select
            v-model="assigneeId"
            class="!mb-0 text-sm w-44"
            :aria-label="t('TECHNICIAN')"
            @change="fetch"
          >
            <option value="">{{ t('ALL_TECHNICIANS') }}</option>
            <option v-for="a in agents" :key="a.id" :value="a.id">
              {{ a.name }}
            </option>
          </select>
          <select v-model="teamId" class="!mb-0 text-sm w-40" @change="fetch">
            <option value="">{{ $t('CASE_TICKETS.FILTERS.ALL_TEAMS') }}</option>
            <option v-for="tm in teams" :key="tm.id" :value="tm.id">
              {{ tm.name }}
            </option>
          </select>
          <CalendarPeriodPicker
            :value="period"
            :from="customFrom"
            :to="customTo"
            @input="setPeriod"
            @custom="setCustom"
          />
        </div>
      </div>
      <p class="m-0 text-xs text-slate-500 dark:text-slate-400">
        {{ t('HELP') }}
      </p>
    </div>

    <div
      v-if="isLoading && !report"
      class="flex items-center justify-center flex-1 text-slate-400 dark:text-slate-500"
    >
      {{ t('LOADING') }}
    </div>
    <div
      v-else-if="isEmpty"
      class="flex items-center justify-center flex-1 text-slate-400 dark:text-slate-500"
    >
      {{ t('EMPTY') }}
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
            {{ t('KPI.OPEN') }}
          </p>
          <p
            class="m-0 mt-1 text-2xl font-bold tabular-nums text-slate-800 dark:text-slate-100"
          >
            {{ summary.open_count || 0 }}
          </p>
          <p class="m-0 mt-1 text-xs text-slate-500 dark:text-slate-400">
            {{
              t('KPI.OPEN_SUB', {
                toSchedule: summary.to_schedule_count || 0,
                signoff: summary.awaiting_signoff_count || 0,
              })
            }}
          </p>
        </div>
        <div
          class="p-4 bg-white border rounded-lg dark:bg-slate-800 border-slate-75 dark:border-slate-700"
        >
          <p class="m-0 text-xs uppercase text-slate-500 dark:text-slate-400">
            {{ t('KPI.OVERDUE') }}
          </p>
          <p
            class="flex items-center gap-2 m-0 mt-1 text-2xl font-bold tabular-nums text-slate-800 dark:text-slate-100"
          >
            <fluent-icon
              v-if="summary.overdue_visits_count"
              icon="warning"
              size="18"
              class="text-red-600 dark:text-red-400"
            />
            {{ summary.overdue_visits_count || 0 }}
          </p>
          <p class="m-0 mt-1 text-xs text-slate-500 dark:text-slate-400">
            {{ t('KPI.OVERDUE_SUB') }}
          </p>
        </div>
        <div
          class="p-4 bg-white border rounded-lg dark:bg-slate-800 border-slate-75 dark:border-slate-700"
        >
          <p class="m-0 text-xs uppercase text-slate-500 dark:text-slate-400">
            {{ t('KPI.ON_TIME') }}
          </p>
          <p
            class="m-0 mt-1 text-2xl font-bold tabular-nums text-slate-800 dark:text-slate-100"
          >
            {{ pct(summary.on_time_rate) }}
          </p>
          <p class="m-0 mt-1 text-xs text-slate-500 dark:text-slate-400">
            {{
              t('KPI.ON_TIME_SUB', {
                onTime: summary.on_time_count || 0,
                late: summary.late_count || 0,
                noVisit: summary.no_visit_count || 0,
              })
            }}
          </p>
        </div>
        <div
          class="p-4 bg-white border rounded-lg dark:bg-slate-800 border-slate-75 dark:border-slate-700"
        >
          <p class="m-0 text-xs uppercase text-slate-500 dark:text-slate-400">
            {{ t('KPI.HOURS') }}
          </p>
          <p
            class="m-0 mt-1 text-2xl font-bold tabular-nums text-slate-800 dark:text-slate-100"
          >
            {{ variance(summary.hours_variance) }}
          </p>
          <p class="m-0 mt-1 text-xs text-slate-500 dark:text-slate-400">
            {{
              t('KPI.HOURS_SUB', {
                actual: hours(summary.actual_hours),
                estimated: hours(summary.estimated_hours),
                count: summary.hours_orders_count || 0,
              })
            }}
          </p>
        </div>
        <div
          class="p-4 bg-white border rounded-lg dark:bg-slate-800 border-slate-75 dark:border-slate-700"
        >
          <p class="m-0 text-xs uppercase text-slate-500 dark:text-slate-400">
            {{ t('KPI.REWORK') }}
          </p>
          <p
            class="m-0 mt-1 text-2xl font-bold tabular-nums text-slate-800 dark:text-slate-100"
          >
            {{ pct(summary.rework_rate) }}
          </p>
          <p class="m-0 mt-1 text-xs text-slate-500 dark:text-slate-400">
            {{
              t('KPI.REWORK_SUB', {
                count: summary.rework_count || 0,
                finished: summary.finished_count || 0,
              })
            }}
          </p>
        </div>
        <div
          class="p-4 bg-white border rounded-lg dark:bg-slate-800 border-slate-75 dark:border-slate-700"
        >
          <p class="m-0 text-xs uppercase text-slate-500 dark:text-slate-400">
            {{ t('KPI.BILLABLE') }}
          </p>
          <p
            class="m-0 mt-1 text-lg font-bold tabular-nums text-slate-800 dark:text-slate-100"
          >
            {{ money(summary.billable_materials) }}
          </p>
          <p class="m-0 mt-1 text-xs text-slate-500 dark:text-slate-400">
            {{
              t('KPI.BILLABLE_SUB', {
                count: summary.billable_count || 0,
                cancelled: summary.cancelled_count || 0,
              })
            }}
          </p>
        </div>
      </div>

      <div class="grid gap-4 lg:grid-cols-2">
        <!-- Abiertas por etapa: una serie (conteo), etiqueta directa + tooltip -->
        <section
          class="p-4 bg-white border rounded-lg dark:bg-slate-800 border-slate-75 dark:border-slate-700"
        >
          <div class="flex items-center justify-between mb-3">
            <h2
              class="m-0 text-sm font-semibold text-slate-800 dark:text-slate-100"
            >
              {{ t('STAGES') }}
            </h2>
            <button
              type="button"
              class="text-xs text-woot-600 dark:text-woot-300 hover:underline"
              @click="tableView.stages = !tableView.stages"
            >
              {{ tableView.stages ? t('CHART_VIEW') : t('TABLE_VIEW') }}
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
              :title="`${stageLabel(stage)}: ${stage.count}`"
            >
              <span class="text-sm truncate text-slate-600 dark:text-slate-300">
                {{ stageLabel(stage) }}
              </span>
              <div class="flex items-center min-w-0 gap-2">
                <div
                  class="flex-shrink-0 h-5 rounded-r bg-teal-500 group-hover:bg-teal-600 dark:bg-teal-400 dark:group-hover:bg-teal-300"
                  :style="{ width: barWidth(stage.count, maxStageCount) }"
                />
                <strong
                  class="text-xs tabular-nums text-slate-700 dark:text-slate-200"
                  >{{ stage.count }}</strong
                >
              </div>
            </div>
          </div>
          <table v-else class="w-full text-sm">
            <thead>
              <tr class="text-xs text-left uppercase text-slate-500">
                <th class="py-1">{{ t('STAGE') }}</th>
                <th class="py-1 text-right">#</th>
              </tr>
            </thead>
            <tbody class="text-slate-700 dark:text-slate-200">
              <tr v-for="stage in stages" :key="stage.label || 'none'">
                <td class="py-1">{{ stageLabel(stage) }}</td>
                <td class="py-1 text-right tabular-nums">{{ stage.count }}</td>
              </tr>
            </tbody>
          </table>
        </section>

        <!-- Puntualidad de lo terminado: una serie (conteo) -->
        <section
          class="p-4 bg-white border rounded-lg dark:bg-slate-800 border-slate-75 dark:border-slate-700"
        >
          <div class="flex items-center justify-between mb-3">
            <h2
              class="m-0 text-sm font-semibold text-slate-800 dark:text-slate-100"
            >
              {{ t('TIMING.TITLE') }}
            </h2>
            <button
              type="button"
              class="text-xs text-woot-600 dark:text-woot-300 hover:underline"
              @click="tableView.timing = !tableView.timing"
            >
              {{ tableView.timing ? t('CHART_VIEW') : t('TABLE_VIEW') }}
            </button>
          </div>
          <p
            v-if="!summary.finished_count"
            class="m-0 text-sm text-slate-400 dark:text-slate-500"
          >
            {{ t('TIMING.EMPTY') }}
          </p>
          <div v-else-if="!tableView.timing" class="flex flex-col gap-2">
            <div
              v-for="row in timing"
              :key="row.key"
              class="grid items-center gap-3 grid-cols-[8rem_1fr] group"
              :title="`${timingLabel(row.key)}: ${row.count}`"
            >
              <span class="text-sm truncate text-slate-600 dark:text-slate-300">
                {{ timingLabel(row.key) }}
              </span>
              <div class="flex items-center min-w-0 gap-2">
                <div
                  class="flex-shrink-0 h-5 rounded-r bg-teal-500 group-hover:bg-teal-600 dark:bg-teal-400 dark:group-hover:bg-teal-300"
                  :style="{ width: barWidth(row.count, maxTimingCount) }"
                />
                <strong
                  class="text-xs tabular-nums text-slate-700 dark:text-slate-200"
                  >{{ row.count }}</strong
                >
              </div>
            </div>
            <p class="m-0 mt-1 text-xs text-slate-500 dark:text-slate-400">
              {{ t('TIMING.HINT') }}
            </p>
          </div>
          <table v-else class="w-full text-sm">
            <thead>
              <tr class="text-xs text-left uppercase text-slate-500">
                <th class="py-1">{{ t('TIMING.TITLE') }}</th>
                <th class="py-1 text-right">#</th>
              </tr>
            </thead>
            <tbody class="text-slate-700 dark:text-slate-200">
              <tr v-for="row in timing" :key="row.key">
                <td class="py-1">{{ timingLabel(row.key) }}</td>
                <td class="py-1 text-right tabular-nums">{{ row.count }}</td>
              </tr>
            </tbody>
          </table>
        </section>
      </div>

      <!-- Por técnico y por tipo -->
      <section
        v-for="block in breakdowns"
        :key="block.key"
        class="p-4 overflow-x-auto bg-white border rounded-lg dark:bg-slate-800 border-slate-75 dark:border-slate-700"
      >
        <h2
          class="m-0 mb-3 text-sm font-semibold text-slate-800 dark:text-slate-100"
        >
          {{ block.title }}
        </h2>
        <p
          v-if="!block.rows.length"
          class="m-0 text-sm text-slate-400 dark:text-slate-500"
        >
          —
        </p>
        <table v-else class="w-full text-sm">
          <thead>
            <tr class="text-xs text-left uppercase text-slate-500">
              <th class="py-1">{{ block.title }}</th>
              <th class="py-1 text-right">{{ t('COLS.OPEN') }}</th>
              <th class="py-1 text-right">{{ t('COLS.FINISHED') }}</th>
              <th class="py-1 text-right">{{ t('COLS.ON_TIME') }}</th>
              <th class="py-1 text-right">{{ t('COLS.HOURS') }}</th>
              <th class="py-1 text-right">{{ t('COLS.VARIANCE') }}</th>
              <th class="py-1 text-right">{{ t('COLS.REWORK') }}</th>
            </tr>
          </thead>
          <tbody class="text-slate-700 dark:text-slate-200">
            <tr
              v-for="row in block.rows"
              :key="row.id || 'none'"
              class="border-t border-slate-50 dark:border-slate-700"
            >
              <td class="py-1.5">{{ row.name || block.empty }}</td>
              <td class="py-1.5 text-right tabular-nums">
                {{ row.open_count }}
              </td>
              <td class="py-1.5 text-right tabular-nums">
                {{ row.finished_count }}
              </td>
              <td class="py-1.5 text-right font-semibold tabular-nums">
                {{ pct(row.on_time_rate) }}
              </td>
              <td class="py-1.5 text-right tabular-nums">
                {{ hours(row.actual_hours) }} /
                {{ hours(row.estimated_hours) }}
              </td>
              <td class="py-1.5 text-right tabular-nums">
                {{ variance(row.hours_variance) }}
              </td>
              <td class="py-1.5 text-right tabular-nums">
                {{ row.rework_count }}
              </td>
            </tr>
          </tbody>
        </table>
      </section>
    </div>
  </div>
</template>
