<!--
  @tickets_cases — Plan-Clase-Proyecto P3
  Métricas de proyectos (GET /api/v2/.../case_reports/projects). Lo abierto es
  foto de hoy: salud contra el plan (en tiempo / en riesgo / atrasado / sin
  fechas), fases, hitos vencidos y horas reales contra presupuesto. Lo terminado
  se acota al período: entregas a tiempo = a más tardar la fecha objetivo.
  Barras de una sola serie en el color de la clase, con etiqueta directa, tooltip
  y vista de tabla; por responsable y por tipo en tablas.
-->
<script>
import { mapGetters } from 'vuex';
import CaseReportsAPI from 'dashboard/api/caseReports';
import { formatHours } from 'dashboard/helper/caseWorkOrder';
import CaseClassSwitcher from '../CaseClassSwitcher.vue';
import CaseTypeSelect from '../filters/CaseTypeSelect.vue';
import MetricsPeriodPicker from '../filters/MetricsPeriodPicker.vue';
import { loadCaseState, saveCaseState } from 'dashboard/helper/caseClasses';
import { METRIC_PERIODS as PERIODS } from 'dashboard/helper/caseFilters';

const BASE = 'CASE_TICKETS.PROJECT.METRICS';

export default {
  name: 'ProjectMetrics',
  components: { CaseClassSwitcher, CaseTypeSelect, MetricsPeriodPicker },
  props: {
    caseClass: { type: String, default: 'project' },
  },
  data() {
    return {
      period: '90d',
      caseTypeId: '',
      assigneeId: '',
      teamId: '',
      report: null,
      isLoading: false,
      tableView: { health: false, stages: false },
    };
  },
  computed: {
    ...mapGetters({ agents: 'agents/getAgents', teams: 'teams/getTeams' }),
    summary() {
      return this.report?.summary || {};
    },
    health() {
      return this.report?.health || [];
    },
    stages() {
      return this.report?.stages || [];
    },
    breakdowns() {
      return [
        {
          key: 'assignee',
          title: this.t('BY_ASSIGNEE'),
          rows: this.report?.by_assignee || [],
          empty: this.t('UNASSIGNED'),
        },
        {
          key: 'type',
          title: this.t('BY_TYPE'),
          rows: this.report?.by_type || [],
          empty: this.t('NO_TYPE'),
        },
      ];
    },
    // Las dos gráficas de barras (una serie cada una): salud y fases.
    chartBlocks() {
      return [
        {
          key: 'health',
          title: this.t('HEALTH.TITLE'),
          rows: this.health.map(h => ({
            key: h.key,
            label: this.healthLabel(h.key),
            count: h.count,
          })),
          max: this.maxHealth,
        },
        {
          key: 'stages',
          title: this.t('STAGES'),
          rows: this.stages.map(st => ({
            key: st.label || 'none',
            label: this.stageLabel(st),
            count: st.count,
          })),
          max: this.maxStage,
        },
      ];
    },
    maxHealth() {
      return Math.max(1, ...this.health.map(h => h.count));
    },
    maxStage() {
      return Math.max(1, ...this.stages.map(s => s.count));
    },
    isEmpty() {
      return (
        this.report && !this.summary.open_count && !this.summary.finished_count
      );
    },
  },
  mounted() {
    this.$store.dispatch('caseTickets/fetchTypes');
    this.$store.dispatch('agents/get');
    this.$store.dispatch('teams/get');
    const st = loadCaseState(this.$route.params.accountId, this.caseClass);
    const saved = st.metrics || {};
    this.caseTypeId = st.type ?? '';
    if (PERIODS.some(p => p.key === saved.period)) this.period = saved.period;
    this.assigneeId = saved.assigneeId || '';
    this.teamId = saved.teamId || '';
    this.fetch();
  },
  methods: {
    t(key, params) {
      return this.$t(`${BASE}.${key}`, params);
    },
    filters() {
      const period = PERIODS.find(p => p.key === this.period);
      const f = {
        caseTypeId: this.caseTypeId || undefined,
        assigneeId: this.assigneeId || undefined,
        teamId: this.teamId || undefined,
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
        const { data } = await CaseReportsAPI.getProjects(this.filters());
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
    setPeriod(key) {
      this.period = key;
      this.fetch();
    },
    pct(value) {
      return value === null || value === undefined ? '—' : `${value}%`;
    },
    hours(value) {
      return formatHours(value);
    },
    barWidth(count, max) {
      return `${Math.max(2, (count / max) * 100)}%`;
    },
    healthLabel(key) {
      return this.t(`HEALTH.${key}`);
    },
    stageLabel(stage) {
      return stage.label || this.t('NO_STAGE');
    },
  },
};
</script>

<template>
  <div
    class="flex flex-col flex-1 w-full h-full overflow-hidden bg-slate-25 dark:bg-slate-900"
  >
    <div
      class="flex flex-col flex-shrink-0 gap-3 px-6 py-4 bg-white border-b dark:bg-slate-900 border-slate-50 dark:border-slate-800/50"
    >
      <div class="flex flex-wrap items-center justify-between gap-3">
        <div class="flex flex-wrap items-center gap-3">
          <CaseClassSwitcher
            :case-class="caseClass"
            :title="$t('CASE_TICKETS.CLASSES.PROJECT.METRICS')"
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
            :aria-label="t('ASSIGNEE')"
            @change="fetch"
          >
            <option value="">{{ t('ALL_ASSIGNEES') }}</option>
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
          <MetricsPeriodPicker :value="period" @input="setPeriod" />
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
                late: summary.late_count || 0,
                risk: summary.at_risk_count || 0,
              })
            }}
          </p>
        </div>
        <div
          class="p-4 bg-white border rounded-lg dark:bg-slate-800 border-slate-75 dark:border-slate-700"
        >
          <p class="m-0 text-xs uppercase text-slate-500 dark:text-slate-400">
            {{ t('KPI.MILESTONES') }}
          </p>
          <p
            class="flex items-center gap-2 m-0 mt-1 text-2xl font-bold tabular-nums text-slate-800 dark:text-slate-100"
          >
            <fluent-icon
              v-if="summary.overdue_milestones_count"
              icon="warning"
              size="18"
              class="text-red-600 dark:text-red-400"
            />
            {{ summary.overdue_milestones_count || 0 }}
          </p>
          <p class="m-0 mt-1 text-xs text-slate-500 dark:text-slate-400">
            {{ t('KPI.MILESTONES_SUB') }}
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
            {{ pct(summary.hours_used) }}
          </p>
          <p class="m-0 mt-1 text-xs text-slate-500 dark:text-slate-400">
            {{
              t('KPI.HOURS_SUB', {
                actual: hours(summary.actual_hours),
                budget: hours(summary.budget_hours),
                over: summary.over_budget_count || 0,
              })
            }}
          </p>
        </div>
        <div
          class="p-4 bg-white border rounded-lg dark:bg-slate-800 border-slate-75 dark:border-slate-700"
        >
          <p class="m-0 text-xs uppercase text-slate-500 dark:text-slate-400">
            {{ t('KPI.DELIVERY') }}
          </p>
          <p
            class="m-0 mt-1 text-2xl font-bold tabular-nums text-slate-800 dark:text-slate-100"
          >
            {{ pct(summary.on_time_rate) }}
          </p>
          <p class="m-0 mt-1 text-xs text-slate-500 dark:text-slate-400">
            {{
              t('KPI.DELIVERY_SUB', {
                onTime: summary.delivered_on_time_count || 0,
                late: summary.delivered_late_count || 0,
                finished: summary.finished_count || 0,
              })
            }}
          </p>
        </div>
      </div>

      <div class="grid gap-4 lg:grid-cols-2">
        <section
          v-for="block in chartBlocks"
          :key="block.key"
          class="p-4 bg-white border rounded-lg dark:bg-slate-800 border-slate-75 dark:border-slate-700"
        >
          <div class="flex items-center justify-between mb-3">
            <h2
              class="m-0 text-sm font-semibold text-slate-800 dark:text-slate-100"
            >
              {{ block.title }}
            </h2>
            <button
              type="button"
              class="text-xs text-woot-600 dark:text-woot-300 hover:underline"
              @click="tableView[block.key] = !tableView[block.key]"
            >
              {{ tableView[block.key] ? t('CHART_VIEW') : t('TABLE_VIEW') }}
            </button>
          </div>
          <p
            v-if="!block.rows.length"
            class="m-0 text-sm text-slate-400 dark:text-slate-500"
          >
            —
          </p>
          <div v-else-if="!tableView[block.key]" class="flex flex-col gap-2">
            <div
              v-for="row in block.rows"
              :key="row.key"
              class="grid items-center gap-3 grid-cols-[8rem_1fr] group"
              :title="`${row.label}: ${row.count}`"
            >
              <span class="text-sm truncate text-slate-600 dark:text-slate-300">
                {{ row.label }}
              </span>
              <div class="flex items-center min-w-0 gap-2">
                <div
                  class="flex-shrink-0 h-5 rounded-r bg-indigo-500 group-hover:bg-indigo-600 dark:bg-indigo-400 dark:group-hover:bg-indigo-300"
                  :style="{ width: barWidth(row.count, block.max) }"
                />
                <strong
                  class="text-xs tabular-nums text-slate-700 dark:text-slate-200"
                  >{{ row.count }}</strong
                >
              </div>
            </div>
            <p
              v-if="block.key === 'health'"
              class="m-0 mt-1 text-xs text-slate-500 dark:text-slate-400"
            >
              {{ t('HEALTH.HINT') }}
            </p>
          </div>
          <table v-else class="w-full text-sm">
            <tbody class="text-slate-700 dark:text-slate-200">
              <tr v-for="row in block.rows" :key="row.key">
                <td class="py-1">{{ row.label }}</td>
                <td class="py-1 text-right tabular-nums">{{ row.count }}</td>
              </tr>
            </tbody>
          </table>
        </section>
      </div>

      <!-- Por responsable y por tipo -->
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
              <th class="py-1 text-right">{{ t('COLS.LATE') }}</th>
              <th class="py-1 text-right">{{ t('COLS.RISK') }}</th>
              <th class="py-1 text-right">{{ t('COLS.HOURS') }}</th>
              <th class="py-1 text-right">{{ t('COLS.FINISHED') }}</th>
              <th class="py-1 text-right">{{ t('COLS.ON_TIME') }}</th>
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
                {{ row.late_count }}
              </td>
              <td class="py-1.5 text-right tabular-nums">
                {{ row.at_risk_count }}
              </td>
              <td class="py-1.5 text-right tabular-nums">
                {{ hours(row.actual_hours) }} / {{ hours(row.budget_hours) }}
              </td>
              <td class="py-1.5 text-right tabular-nums">
                {{ row.finished_count }}
              </td>
              <td class="py-1.5 text-right font-semibold tabular-nums">
                {{ pct(row.on_time_rate) }}
              </td>
            </tr>
          </tbody>
        </table>
      </section>
    </div>
  </div>
</template>
