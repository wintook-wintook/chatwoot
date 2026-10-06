<!--
  proyecto@metricas_casos
  Informes → Oportunidades. Reporte #1: embudo (cantidad de casos por columna del
  Kanban del Tipo de Caso elegido). Reporte #2: ganados/perdidos (closure_type +
  status cancelled) con tasa de conversión. Reporte #5: nuevas vs. cerradas por
  período (serie temporal, cada una por su propia columna de fecha). Todos
  comparten los mismos filtros de tipo de caso/vendedor/equipo/fechas.
-->
<script>
import { mapGetters } from 'vuex';
import FunnelBarChart from 'dashboard/components/widgets/chart/FunnelBarChart';
import DoughnutChart from 'dashboard/components/widgets/chart/DoughnutChart';
import BarChart from 'dashboard/components/widgets/chart/BarChart';
import WootDateRangePicker from 'dashboard/components/ui/DateRangePicker.vue';

const CHART_OPTIONS = {
  responsive: true,
  maintainAspectRatio: false,
  legend: { display: false },
  scales: {
    xAxes: [{ ticks: { min: 0, beginAtZero: true, precision: 0 } }],
  },
};

const OUTCOME_COLORS = {
  open: '#3b82f6',
  won: '#22c55e',
  lost: '#ef4444',
  other_closed: '#94a3b8',
};

const DOUGHNUT_OPTIONS = {
  responsive: true,
  maintainAspectRatio: false,
  cutoutPercentage: 62,
  legend: {
    display: true,
    position: 'bottom',
    labels: { boxWidth: 12, padding: 12, usePointStyle: true },
  },
};

const TIMESERIES_OPTIONS = {
  responsive: true,
  maintainAspectRatio: false,
  legend: { display: true, position: 'bottom' },
  scales: {
    yAxes: [{ ticks: { min: 0, beginAtZero: true, precision: 0 } }],
  },
};

const GROUP_BY_OPTIONS = ['day', 'week', 'month'];
const THRESHOLD_OPTIONS = [1, 3, 7, 14, 30];

export default {
  components: {
    FunnelBarChart,
    DoughnutChart,
    BarChart,
    WootDateRangePicker,
  },
  data() {
    return {
      caseTypeId: '',
      assigneeId: '',
      teamId: '',
      dateRange: [], // [Date, Date] | []
      groupBy: 'day',
      thresholdDays: 3,
    };
  },
  computed: {
    ...mapGetters({
      caseTypes: 'caseTickets/getTypes',
      agents: 'agents/getAgents',
      teams: 'teams/getTeams',
      funnel: 'caseReports/getFunnel',
      outcome: 'caseReports/getOutcome',
      timeseries: 'caseReports/getTimeseries',
      assignees: 'caseReports/getAssignees',
      velocity: 'caseReports/getVelocity',
      stalled: 'caseReports/getStalled',
      uiFlags: 'caseReports/getUIFlags',
    }),
    isLoading() {
      return this.uiFlags.isFetchingFunnel;
    },
    isLoadingOutcome() {
      return this.uiFlags.isFetchingOutcome;
    },
    hasFunnelData() {
      return this.funnel.some(stage => stage.count > 0);
    },
    funnelChartData() {
      return {
        labels: this.funnel.map(stage => this.stageLabel(stage)),
        datasets: [
          {
            data: this.funnel.map(stage => stage.count),
            backgroundColor: this.funnel.map(stage => stage.color || '#3b82f6'),
            barPercentage: 0.6,
          },
        ],
      };
    },
    chartOptions() {
      return CHART_OPTIONS;
    },
    outcomeKeys() {
      return ['open', 'won', 'lost', 'other_closed'];
    },
    hasOutcomeData() {
      return this.outcomeKeys.some(key => this.outcome[key] > 0);
    },
    outcomeChartData() {
      return {
        labels: this.outcomeKeys.map(key =>
          this.$t(`OPPORTUNITY_REPORTS.OUTCOME.${key.toUpperCase()}`)
        ),
        datasets: [
          {
            data: this.outcomeKeys.map(key => this.outcome[key] || 0),
            backgroundColor: this.outcomeKeys.map(key => OUTCOME_COLORS[key]),
            borderWidth: 0,
          },
        ],
      };
    },
    doughnutOptions() {
      return DOUGHNUT_OPTIONS;
    },
    decidedCount() {
      return (this.outcome.won || 0) + (this.outcome.lost || 0);
    },
    conversionRateText() {
      if (this.decidedCount === 0) return '—';
      return `${Math.round(
        ((this.outcome.won || 0) / this.decidedCount) * 100
      )}%`;
    },
    from() {
      return this.dateRange[0]
        ? Math.floor(this.dateRange[0].getTime() / 1000)
        : undefined;
    },
    to() {
      return this.dateRange[1]
        ? Math.floor(this.dateRange[1].getTime() / 1000)
        : undefined;
    },
    groupByOptions() {
      return GROUP_BY_OPTIONS;
    },
    isLoadingTimeseries() {
      return this.uiFlags.isFetchingTimeseries;
    },
    hasTimeseriesData() {
      return (
        this.timeseries.created.some(point => point.value > 0) ||
        this.timeseries.closed.some(point => point.value > 0)
      );
    },
    // `created` y `closed` pueden traer timestamps distintos (sin since/until,
    // group_by_period solo devuelve fechas con datos reales — cada serie puede
    // tener las suyas) — se arma la unión ordenada y se alinea cada serie contra
    // eso, en vez de asumir que ambos arrays vienen en el mismo orden/tamaño.
    timeseriesChartData() {
      const byTimestamp = points =>
        Object.fromEntries(points.map(p => [p.timestamp, p.value]));
      const createdByTs = byTimestamp(this.timeseries.created);
      const closedByTs = byTimestamp(this.timeseries.closed);
      const timestamps = [
        ...new Set([
          ...this.timeseries.created.map(p => p.timestamp),
          ...this.timeseries.closed.map(p => p.timestamp),
        ]),
      ].sort((a, b) => a - b);

      return {
        labels: timestamps.map(ts => this.formatTimestamp(ts)),
        datasets: [
          {
            label: this.$t('OPPORTUNITY_REPORTS.TIMESERIES.CREATED'),
            data: timestamps.map(ts => createdByTs[ts] || 0),
            backgroundColor: '#3b82f6',
            barPercentage: 0.7,
          },
          {
            label: this.$t('OPPORTUNITY_REPORTS.TIMESERIES.CLOSED'),
            data: timestamps.map(ts => closedByTs[ts] || 0),
            backgroundColor: '#22c55e',
            barPercentage: 0.7,
          },
        ],
      };
    },
    timeseriesOptions() {
      return TIMESERIES_OPTIONS;
    },
    isLoadingAssignees() {
      return this.uiFlags.isFetchingAssignees;
    },
    hasAssigneesData() {
      return this.assignees.length > 0;
    },
    isLoadingVelocity() {
      return this.uiFlags.isFetchingVelocity;
    },
    hasVelocityData() {
      return this.velocity.length > 0;
    },
    velocityChartData() {
      return {
        labels: this.velocity.map(row => this.statusLabel(row.status)),
        datasets: [
          {
            data: this.velocity.map(row => row.avg_days),
            backgroundColor: '#6366f1',
            barPercentage: 0.6,
          },
        ],
      };
    },
    isLoadingStalled() {
      return this.uiFlags.isFetchingStalled;
    },
    hasStalledData() {
      return this.stalled.length > 0;
    },
    thresholdOptions() {
      return THRESHOLD_OPTIONS;
    },
  },
  mounted() {
    this.$store.dispatch('caseTickets/fetchTypes');
    this.$store.dispatch('agents/get');
    this.$store.dispatch('teams/get');
    this.fetchReports();
  },
  methods: {
    stageLabel(stage) {
      if (stage.label) return stage.label;
      if (stage.id === null) {
        return this.$t('OPPORTUNITY_REPORTS.FUNNEL.UNASSIGNED_COLUMN');
      }
      return this.statusLabel(stage.id);
    },
    statusLabel(status) {
      return this.$t(`CASE_TICKETS.STATUSES.${status}`) || status;
    },
    onFilterChange() {
      this.fetchReports();
    },
    onDateChange(value) {
      this.dateRange = value || [];
      this.fetchReports();
    },
    onGroupByChange() {
      this.fetchTimeseries();
    },
    onThresholdChange() {
      this.fetchStalled();
    },
    activeFilters() {
      return {
        caseTypeId: this.caseTypeId || undefined,
        assigneeId: this.assigneeId || undefined,
        teamId: this.teamId || undefined,
        from: this.from,
        to: this.to,
      };
    },
    fetchTimeseries() {
      this.$store.dispatch('caseReports/getTimeseries', {
        ...this.activeFilters(),
        groupBy: this.groupBy,
      });
    },
    fetchStalled() {
      this.$store.dispatch('caseReports/getStalled', {
        ...this.activeFilters(),
        thresholdDays: this.thresholdDays,
      });
    },
    fetchReports() {
      this.$store.dispatch('caseReports/getFunnel', this.activeFilters());
      this.$store.dispatch('caseReports/getOutcome', this.activeFilters());
      this.$store.dispatch('caseReports/getAssignees', this.activeFilters());
      this.$store.dispatch('caseReports/getVelocity', this.activeFilters());
      this.fetchTimeseries();
      this.fetchStalled();
    },
    formatTimestamp(timestamp) {
      return new Date(timestamp * 1000).toLocaleDateString(undefined, {
        day: '2-digit',
        month: '2-digit',
        year: this.groupBy === 'day' ? undefined : 'numeric',
      });
    },
    assigneeName(row) {
      return (
        row.assignee_name || this.$t('OPPORTUNITY_REPORTS.ASSIGNEES.UNASSIGNED')
      );
    },
    conversionRateCell(row) {
      return row.conversion_rate === null ? '—' : `${row.conversion_rate}%`;
    },
    avgCloseDaysCell(row) {
      return row.avg_close_days === null ? '—' : row.avg_close_days;
    },
  },
};
</script>

<template>
  <div class="flex flex-col flex-1 gap-6 px-4 pt-4 overflow-auto">
    <div
      class="flex flex-col flex-wrap w-full gap-3 md:flex-row md:items-center"
    >
      <select
        v-model="caseTypeId"
        class="!mb-0 w-48 text-sm"
        @change="onFilterChange"
      >
        <option value="">
          {{ $t('OPPORTUNITY_REPORTS.FILTERS.ALL_CASE_TYPES') }}
        </option>
        <option v-for="type in caseTypes" :key="type.id" :value="type.id">
          {{ type.name }}
        </option>
      </select>
      <select
        v-model="assigneeId"
        class="!mb-0 w-48 text-sm"
        @change="onFilterChange"
      >
        <option value="">
          {{ $t('OPPORTUNITY_REPORTS.FILTERS.ALL_ASSIGNEES') }}
        </option>
        <option v-for="agent in agents" :key="agent.id" :value="agent.id">
          {{ agent.name }}
        </option>
      </select>
      <select
        v-model="teamId"
        class="!mb-0 w-40 text-sm"
        @change="onFilterChange"
      >
        <option value="">
          {{ $t('OPPORTUNITY_REPORTS.FILTERS.ALL_TEAMS') }}
        </option>
        <option v-for="team in teams" :key="team.id" :value="team.id">
          {{ team.name }}
        </option>
      </select>
      <WootDateRangePicker
        class="no-margin auto-width w-56"
        :value="dateRange"
        :placeholder="$t('OPPORTUNITY_REPORTS.FILTERS.DATE_RANGE')"
        @change="onDateChange"
      />
    </div>

    <div class="grid gap-4 reports-grid">
      <div
        class="p-4 bg-white border rounded-md shadow-sm dark:bg-slate-800 border-slate-75 dark:border-slate-700"
      >
        <h3 class="mb-4 text-xl font-medium text-slate-800 dark:text-slate-100">
          {{ $t('OPPORTUNITY_REPORTS.FUNNEL.TITLE') }}
        </h3>
        <p
          v-if="!caseTypeId"
          class="mb-4 text-sm text-slate-500 dark:text-slate-400"
        >
          {{ $t('OPPORTUNITY_REPORTS.FUNNEL.STATUS_FALLBACK_NOTICE') }}
        </p>
        <div
          v-if="isLoading"
          class="py-10 text-sm text-center text-slate-400 dark:text-slate-500"
        >
          {{ $t('OPPORTUNITY_REPORTS.FUNNEL.LOADING') }}
        </div>
        <div v-else-if="hasFunnelData" class="chart-box">
          <FunnelBarChart
            :collection="funnelChartData"
            :chart-options="chartOptions"
          />
        </div>
        <p
          v-else
          class="py-10 text-sm text-center text-slate-400 dark:text-slate-500"
        >
          {{ $t('OPPORTUNITY_REPORTS.FUNNEL.EMPTY') }}
        </p>
      </div>

      <div
        class="p-4 bg-white border rounded-md shadow-sm dark:bg-slate-800 border-slate-75 dark:border-slate-700"
      >
        <div class="flex items-center justify-between mb-4">
          <h3
            class="m-0 text-xl font-medium text-slate-800 dark:text-slate-100"
          >
            {{ $t('OPPORTUNITY_REPORTS.OUTCOME.TITLE') }}
          </h3>
          <div class="text-right">
            <p class="m-0 text-2xl font-medium text-woot-500">
              {{ conversionRateText }}
            </p>
            <p class="m-0 text-xs text-slate-500 dark:text-slate-400">
              {{ $t('OPPORTUNITY_REPORTS.OUTCOME.CONVERSION_RATE') }}
            </p>
          </div>
        </div>
        <div
          v-if="isLoadingOutcome"
          class="py-10 text-sm text-center text-slate-400 dark:text-slate-500"
        >
          {{ $t('OPPORTUNITY_REPORTS.OUTCOME.LOADING') }}
        </div>
        <div v-else-if="hasOutcomeData" class="chart-box">
          <DoughnutChart
            :collection="outcomeChartData"
            :chart-options="doughnutOptions"
          />
        </div>
        <p
          v-else
          class="py-10 text-sm text-center text-slate-400 dark:text-slate-500"
        >
          {{ $t('OPPORTUNITY_REPORTS.OUTCOME.EMPTY') }}
        </p>
      </div>
    </div>

    <div
      class="p-4 bg-white border rounded-md shadow-sm dark:bg-slate-800 border-slate-75 dark:border-slate-700"
    >
      <div class="flex items-center justify-between mb-4">
        <h3 class="m-0 text-xl font-medium text-slate-800 dark:text-slate-100">
          {{ $t('OPPORTUNITY_REPORTS.TIMESERIES.TITLE') }}
        </h3>
        <select
          v-model="groupBy"
          class="!mb-0 w-32 text-sm"
          @change="onGroupByChange"
        >
          <option
            v-for="option in groupByOptions"
            :key="option"
            :value="option"
          >
            {{
              $t(
                `OPPORTUNITY_REPORTS.TIMESERIES.GROUP_BY.${option.toUpperCase()}`
              )
            }}
          </option>
        </select>
      </div>
      <div
        v-if="isLoadingTimeseries"
        class="py-10 text-sm text-center text-slate-400 dark:text-slate-500"
      >
        {{ $t('OPPORTUNITY_REPORTS.TIMESERIES.LOADING') }}
      </div>
      <div v-else-if="hasTimeseriesData" class="chart-box">
        <BarChart
          :collection="timeseriesChartData"
          :chart-options="timeseriesOptions"
        />
      </div>
      <p
        v-else
        class="py-10 text-sm text-center text-slate-400 dark:text-slate-500"
      >
        {{ $t('OPPORTUNITY_REPORTS.TIMESERIES.EMPTY') }}
      </p>
    </div>

    <div
      class="p-4 bg-white border rounded-md shadow-sm dark:bg-slate-800 border-slate-75 dark:border-slate-700"
    >
      <h3 class="mb-4 text-xl font-medium text-slate-800 dark:text-slate-100">
        {{ $t('OPPORTUNITY_REPORTS.ASSIGNEES.TITLE') }}
      </h3>
      <div
        v-if="isLoadingAssignees"
        class="py-10 text-sm text-center text-slate-400 dark:text-slate-500"
      >
        {{ $t('OPPORTUNITY_REPORTS.ASSIGNEES.LOADING') }}
      </div>
      <div v-else-if="hasAssigneesData" class="overflow-x-auto">
        <table class="w-full text-sm">
          <thead>
            <tr class="border-b border-slate-75 dark:border-slate-700">
              <th
                class="px-3 py-2 text-left text-slate-500 dark:text-slate-400"
              >
                {{ $t('OPPORTUNITY_REPORTS.ASSIGNEES.HEADER.ASSIGNEE') }}
              </th>
              <th
                class="px-3 py-2 text-right text-slate-500 dark:text-slate-400"
              >
                {{ $t('OPPORTUNITY_REPORTS.ASSIGNEES.HEADER.OPEN') }}
              </th>
              <th
                class="px-3 py-2 text-right text-slate-500 dark:text-slate-400"
              >
                {{ $t('OPPORTUNITY_REPORTS.ASSIGNEES.HEADER.WON') }}
              </th>
              <th
                class="px-3 py-2 text-right text-slate-500 dark:text-slate-400"
              >
                {{ $t('OPPORTUNITY_REPORTS.ASSIGNEES.HEADER.LOST') }}
              </th>
              <th
                class="px-3 py-2 text-right text-slate-500 dark:text-slate-400"
              >
                {{ $t('OPPORTUNITY_REPORTS.ASSIGNEES.HEADER.CONVERSION_RATE') }}
              </th>
              <th
                class="px-3 py-2 text-right text-slate-500 dark:text-slate-400"
              >
                {{ $t('OPPORTUNITY_REPORTS.ASSIGNEES.HEADER.AVG_CLOSE_DAYS') }}
              </th>
            </tr>
          </thead>
          <tbody>
            <tr
              v-for="row in assignees"
              :key="row.assignee_id || 'unassigned'"
              class="border-b border-slate-25 dark:border-slate-800/50"
            >
              <td class="px-3 py-2 text-slate-800 dark:text-slate-100">
                {{ assigneeName(row) }}
              </td>
              <td
                class="px-3 py-2 text-right text-slate-800 dark:text-slate-100"
              >
                {{ row.open }}
              </td>
              <td
                class="px-3 py-2 text-right text-green-600 dark:text-green-400"
              >
                {{ row.won }}
              </td>
              <td class="px-3 py-2 text-right text-red-600 dark:text-red-400">
                {{ row.lost }}
              </td>
              <td
                class="px-3 py-2 text-right text-slate-800 dark:text-slate-100"
              >
                {{ conversionRateCell(row) }}
              </td>
              <td
                class="px-3 py-2 text-right text-slate-800 dark:text-slate-100"
              >
                {{ avgCloseDaysCell(row) }}
              </td>
            </tr>
          </tbody>
        </table>
      </div>
      <p
        v-else
        class="py-10 text-sm text-center text-slate-400 dark:text-slate-500"
      >
        {{ $t('OPPORTUNITY_REPORTS.ASSIGNEES.EMPTY') }}
      </p>
    </div>

    <div
      class="p-4 bg-white border rounded-md shadow-sm dark:bg-slate-800 border-slate-75 dark:border-slate-700"
    >
      <h3 class="mb-4 text-xl font-medium text-slate-800 dark:text-slate-100">
        {{ $t('OPPORTUNITY_REPORTS.VELOCITY.TITLE') }}
      </h3>
      <div
        v-if="isLoadingVelocity"
        class="py-10 text-sm text-center text-slate-400 dark:text-slate-500"
      >
        {{ $t('OPPORTUNITY_REPORTS.VELOCITY.LOADING') }}
      </div>
      <div v-else-if="hasVelocityData" class="chart-box">
        <FunnelBarChart
          :collection="velocityChartData"
          :chart-options="chartOptions"
        />
      </div>
      <p
        v-else
        class="py-10 text-sm text-center text-slate-400 dark:text-slate-500"
      >
        {{ $t('OPPORTUNITY_REPORTS.VELOCITY.EMPTY') }}
      </p>
    </div>

    <div
      class="p-4 bg-white border rounded-md shadow-sm dark:bg-slate-800 border-slate-75 dark:border-slate-700"
    >
      <div class="flex items-center justify-between mb-4">
        <h3 class="m-0 text-xl font-medium text-slate-800 dark:text-slate-100">
          {{ $t('OPPORTUNITY_REPORTS.STALLED.TITLE') }}
        </h3>
        <select
          v-model.number="thresholdDays"
          class="!mb-0 w-40 text-sm"
          @change="onThresholdChange"
        >
          <option
            v-for="option in thresholdOptions"
            :key="option"
            :value="option"
          >
            {{
              $t('OPPORTUNITY_REPORTS.STALLED.THRESHOLD_OPTION', {
                days: option,
              })
            }}
          </option>
        </select>
      </div>
      <div
        v-if="isLoadingStalled"
        class="py-10 text-sm text-center text-slate-400 dark:text-slate-500"
      >
        {{ $t('OPPORTUNITY_REPORTS.STALLED.LOADING') }}
      </div>
      <div v-else-if="hasStalledData" class="overflow-x-auto">
        <table class="w-full text-sm">
          <thead>
            <tr class="border-b border-slate-75 dark:border-slate-700">
              <th
                class="px-3 py-2 text-left text-slate-500 dark:text-slate-400"
              >
                {{ $t('OPPORTUNITY_REPORTS.STALLED.HEADER.FOLIO') }}
              </th>
              <th
                class="px-3 py-2 text-left text-slate-500 dark:text-slate-400"
              >
                {{ $t('OPPORTUNITY_REPORTS.STALLED.HEADER.TITLE') }}
              </th>
              <th
                class="px-3 py-2 text-left text-slate-500 dark:text-slate-400"
              >
                {{ $t('OPPORTUNITY_REPORTS.STALLED.HEADER.STATUS') }}
              </th>
              <th
                class="px-3 py-2 text-left text-slate-500 dark:text-slate-400"
              >
                {{ $t('OPPORTUNITY_REPORTS.STALLED.HEADER.ASSIGNEE') }}
              </th>
              <th
                class="px-3 py-2 text-right text-slate-500 dark:text-slate-400"
              >
                {{ $t('OPPORTUNITY_REPORTS.STALLED.HEADER.STALLED_DAYS') }}
              </th>
            </tr>
          </thead>
          <tbody>
            <tr
              v-for="row in stalled"
              :key="row.id"
              class="border-b border-slate-25 dark:border-slate-800/50"
            >
              <td class="px-3 py-2 text-slate-800 dark:text-slate-100">
                {{ row.folio }}
              </td>
              <td class="px-3 py-2 text-slate-800 dark:text-slate-100">
                {{ row.title }}
              </td>
              <td class="px-3 py-2 text-slate-800 dark:text-slate-100">
                {{ statusLabel(row.status) }}
              </td>
              <td class="px-3 py-2 text-slate-800 dark:text-slate-100">
                {{ assigneeName(row) }}
              </td>
              <td
                class="px-3 py-2 text-right text-amber-600 dark:text-amber-400"
              >
                {{ row.stalled_days }}
              </td>
            </tr>
          </tbody>
        </table>
      </div>
      <p
        v-else
        class="py-10 text-sm text-center text-slate-400 dark:text-slate-500"
      >
        {{ $t('OPPORTUNITY_REPORTS.STALLED.EMPTY') }}
      </p>
    </div>
  </div>
</template>

<style lang="scss" scoped>
.reports-grid {
  grid-template-columns: repeat(auto-fit, minmax(360px, 1fr));
}

.chart-box {
  height: 20rem;

  ::v-deep > div {
    position: relative;
    height: 100% !important;
  }
}
</style>
