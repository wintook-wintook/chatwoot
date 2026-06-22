<!--
  @tickets_cases
  Vista de métricas del Gestor de Tickets — Tailwind + dark mode.
-->
<script>
import { mapGetters } from 'vuex';
import BarChart from 'dashboard/components/widgets/chart/BarChart';
import DoughnutChart from 'dashboard/components/widgets/chart/DoughnutChart';

const PERIODS = [
  { key: '7d', label: '7 días', days: 7 },
  { key: '30d', label: '30 días', days: 30 },
  { key: '90d', label: '90 días', days: 90 },
  { key: 'all', label: 'Todo', days: null },
];

const CLOSED_STATUSES = ['closed', 'cancelled'];

// Paletas de color (hex para chart.js)
const TYPE_PALETTE = ['#3b82f6', '#8b5cf6', '#06b6d4', '#f59e0b', '#ec4899'];
const PRIORITY_COLORS = {
  low: '#94a3b8',
  medium: '#3b82f6',
  high: '#eab308',
  urgent: '#ef4444',
};
const SLA_COLORS = {
  on_time: '#22c55e',
  at_risk: '#eab308',
  overdue: '#ef4444',
};
// @tickets_cases 2J
const CATEGORY_PALETTE = [
  '#0ea5e9',
  '#6366f1',
  '#14b8a6',
  '#f97316',
  '#a855f7',
  '#84cc16',
  '#ef4444',
];
const SERVICE_PALETTE = [
  '#8b5cf6',
  '#06b6d4',
  '#f59e0b',
  '#22c55e',
  '#ec4899',
  '#3b82f6',
];

const BAR_OPTIONS = {
  responsive: true,
  maintainAspectRatio: false,
  legend: { display: false },
  scales: {
    xAxes: [{ gridLines: { drawOnChartArea: false } }],
    yAxes: [
      {
        // min:0 fuerza el origen en cero (beginAtZero no siempre se respeta en chart.js 2.9)
        ticks: { min: 0, beginAtZero: true, precision: 0 },
        gridLines: { drawOnChartArea: false },
      },
    ],
  },
};

// @tickets_cases 2J — opciones para la serie diaria (con leyenda creados/resueltos)
const DAILY_OPTIONS = {
  responsive: true,
  maintainAspectRatio: false,
  legend: { display: true, position: 'bottom' },
  scales: {
    xAxes: [{ gridLines: { drawOnChartArea: false } }],
    yAxes: [
      {
        ticks: { min: 0, beginAtZero: true, precision: 0 },
        gridLines: { drawOnChartArea: false },
      },
    ],
  },
};

// Donas: leyenda ABAJO para que el círculo quede centrado y del mismo tamaño en todas las tarjetas
// (con leyenda a la derecha el ancho variable de la leyenda descentraba y deformaba cada dona)
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

// Colores de valor para KPIs (acento sobre el número, no sobre la tarjeta → look limpio tipo Resumen)
const VALUE_NEUTRAL = 'text-woot-800 dark:text-woot-300';
const VALUE_ALERT = 'text-red-600 dark:text-red-400';
const VALUE_WARNING = 'text-yellow-600 dark:text-yellow-400';
const VALUE_SUCCESS = 'text-green-600 dark:text-green-400';

export default {
  name: 'GestorTicketsMetrics',
  components: { BarChart, DoughnutChart },
  data() {
    return {
      selectedPeriod: '30d',
      barOptions: BAR_OPTIONS,
      dailyOptions: DAILY_OPTIONS,
      doughnutOptions: DOUGHNUT_OPTIONS,
    };
  },
  computed: {
    ...mapGetters({
      metrics: 'caseTickets/getMetrics',
      uiFlags: 'caseTickets/getUIFlags',
      itilEnabled: 'caseTickets/getItilEnabled', // modo simple/ITIL
    }),
    isLoading() {
      return this.uiFlags.isFetchingList;
    },
    periods() {
      return PERIODS;
    },

    // key que cambia con el período para forzar re-render de los charts
    chartKey() {
      return this.selectedPeriod;
    },

    activeStatuses() {
      if (!this.metrics?.by_status) return {};
      return Object.fromEntries(
        Object.entries(this.metrics.by_status).filter(
          ([k]) => !CLOSED_STATUSES.includes(k)
        )
      );
    },

    // ── Datasets chart.js ──────────────────────────────────────
    hasStatusData() {
      return Object.values(this.activeStatuses).some(v => v > 0);
    },
    hasTypeData() {
      return Object.values(this.metrics?.by_type || {}).some(v => v > 0);
    },
    hasPriorityData() {
      return Object.values(this.metrics?.by_priority || {}).some(v => v > 0);
    },
    hasSlaData() {
      return Object.values(this.metrics?.by_sla_status || {}).some(v => v > 0);
    },

    statusChartData() {
      const entries = Object.entries(this.activeStatuses);
      return {
        labels: entries.map(([k]) => this.statusLabel(k)),
        datasets: [
          {
            data: entries.map(([, v]) => v),
            backgroundColor: '#3b82f6',
            hoverBackgroundColor: '#2563eb',
            barPercentage: 0.6,
          },
        ],
      };
    },
    typeChartData() {
      const entries = Object.entries(this.metrics?.by_type || {}).filter(
        ([, v]) => v > 0
      );
      return {
        labels: entries.map(([k]) => k), // by_type ya viene con el nombre del tipo como clave
        datasets: [
          {
            data: entries.map(([, v]) => v),
            backgroundColor: entries.map(
              (_, i) => TYPE_PALETTE[i % TYPE_PALETTE.length]
            ),
            borderWidth: 0,
          },
        ],
      };
    },
    priorityChartData() {
      const entries = Object.entries(this.metrics?.by_priority || {}).filter(
        ([, v]) => v > 0
      );
      return {
        labels: entries.map(([k]) => this.priorityLabel(k)),
        datasets: [
          {
            data: entries.map(([, v]) => v),
            backgroundColor: entries.map(
              ([k]) => PRIORITY_COLORS[k] || '#94a3b8'
            ),
            borderWidth: 0,
          },
        ],
      };
    },
    slaChartData() {
      const entries = Object.entries(this.metrics?.by_sla_status || {}).filter(
        ([, v]) => v > 0
      );
      return {
        labels: entries.map(([k]) => this.slaLabel(k)),
        datasets: [
          {
            data: entries.map(([, v]) => v),
            backgroundColor: entries.map(([k]) => SLA_COLORS[k] || '#94a3b8'),
            borderWidth: 0,
          },
        ],
      };
    },

    avgResolutionText() {
      return this.minutesToText(this.metrics?.summary?.avg_resolution_minutes);
    },
    avgFirstResponseText() {
      return this.minutesToText(
        this.metrics?.summary?.avg_first_response_minutes
      );
    },
    csatText() {
      const s = this.metrics?.summary || {};
      if (s.csat_avg == null) return '—';
      return `${s.csat_avg} ⭐`;
    },

    // ── 2J — nuevas distribuciones ─────────────────────────────
    hasCategoryData() {
      return Object.keys(this.metrics?.by_category || {}).length > 0;
    },
    hasServiceData() {
      return Object.keys(this.metrics?.by_service || {}).length > 0;
    },
    hasAssigneeData() {
      return Object.keys(this.metrics?.by_assignee || {}).length > 0;
    },
    hasDailyData() {
      return (this.metrics?.daily || []).some(
        d => d.created > 0 || d.resolved > 0
      );
    },
    categoryChartData() {
      const entries = Object.entries(this.metrics?.by_category || {});
      return {
        labels: entries.map(([k]) => k),
        datasets: [
          {
            data: entries.map(([, v]) => v),
            backgroundColor: entries.map(
              (_, i) => CATEGORY_PALETTE[i % CATEGORY_PALETTE.length]
            ),
            borderWidth: 0,
          },
        ],
      };
    },
    serviceChartData() {
      const entries = Object.entries(this.metrics?.by_service || {});
      return {
        labels: entries.map(([k]) => k),
        datasets: [
          {
            data: entries.map(([, v]) => v),
            backgroundColor: entries.map(
              (_, i) => SERVICE_PALETTE[i % SERVICE_PALETTE.length]
            ),
            borderWidth: 0,
          },
        ],
      };
    },
    assigneeChartData() {
      const entries = Object.entries(this.metrics?.by_assignee || {});
      return {
        labels: entries.map(([k]) => k),
        datasets: [
          {
            data: entries.map(([, v]) => v),
            backgroundColor: '#6366f1',
            hoverBackgroundColor: '#4f46e5',
            barPercentage: 0.6,
          },
        ],
      };
    },
    dailyChartData() {
      const days = this.metrics?.daily || [];
      return {
        labels: days.map(d => this.shortDate(d.date)),
        datasets: [
          {
            label: this.$t('CASE_TICKETS.METRICS.DAILY_CREATED'),
            data: days.map(d => d.created),
            backgroundColor: '#3b82f6',
            barPercentage: 0.7,
          },
          {
            label: this.$t('CASE_TICKETS.METRICS.DAILY_RESOLVED'),
            data: days.map(d => d.resolved),
            backgroundColor: '#22c55e',
            barPercentage: 0.7,
          },
        ],
      };
    },

    complianceValueClass() {
      const r = this.metrics?.summary?.sla_compliance_rate;
      if (r == null) return VALUE_NEUTRAL;
      if (r >= 90) return VALUE_SUCCESS;
      if (r >= 70) return VALUE_WARNING;
      return VALUE_ALERT;
    },

    // KPIs agrupados en tarjetas temáticas (estilo Resumen): Volumen / SLA / Tiempos / ITIL
    metricGroups() {
      const s = this.metrics?.summary || {};
      return [
        {
          header: this.$t('CASE_TICKETS.METRICS.GROUP_VOLUME'),
          metrics: [
            {
              value: s.total ?? 0,
              label: this.$t('CASE_TICKETS.METRICS.TOTAL_PERIOD'),
              valueClass: VALUE_NEUTRAL,
            },
            {
              value: s.total_open ?? 0,
              label: this.$t('CASE_TICKETS.METRICS.TOTAL_OPEN'),
              valueClass: VALUE_NEUTRAL,
            },
            {
              value: s.resolved_this_period ?? 0,
              label: this.$t('CASE_TICKETS.METRICS.RESOLVED_PERIOD'),
              valueClass: VALUE_SUCCESS,
            },
            {
              value: s.reopened ?? 0,
              label: this.$t('CASE_TICKETS.METRICS.REOPENED'),
              valueClass: s.reopened > 0 ? VALUE_WARNING : VALUE_NEUTRAL,
            },
          ],
        },
        {
          header: this.$t('CASE_TICKETS.METRICS.GROUP_SLA'),
          metrics: [
            {
              value: s.sla_overdue ?? 0,
              label: this.$t('CASE_TICKETS.METRICS.SLA_OVERDUE'),
              valueClass: s.sla_overdue > 0 ? VALUE_ALERT : VALUE_NEUTRAL,
            },
            {
              value: s.sla_at_risk ?? 0,
              label: this.$t('CASE_TICKETS.METRICS.SLA_AT_RISK'),
              valueClass: s.sla_at_risk > 0 ? VALUE_WARNING : VALUE_NEUTRAL,
            },
            {
              value:
                s.sla_compliance_rate != null
                  ? s.sla_compliance_rate + '%'
                  : '—',
              label: this.$t('CASE_TICKETS.METRICS.SLA_COMPLIANCE'),
              valueClass: this.complianceValueClass,
            },
          ],
        },
        {
          header: this.$t('CASE_TICKETS.METRICS.GROUP_TIMES'),
          metrics: [
            {
              value: this.avgResolutionText,
              label: this.$t('CASE_TICKETS.METRICS.AVG_RESOLUTION'),
              valueClass: VALUE_NEUTRAL,
            },
            {
              value: this.avgFirstResponseText,
              label: this.$t('CASE_TICKETS.METRICS.AVG_FIRST_RESPONSE'),
              valueClass: VALUE_NEUTRAL,
            },
          ],
        },
        {
          // Modo simple (osTicket): se ocultan los KPIs ITIL (problemas/cambios),
          // queda solo CSAT y el grupo se titula "Calidad".
          header: this.itilEnabled
            ? this.$t('CASE_TICKETS.METRICS.GROUP_ITIL')
            : this.$t('CASE_TICKETS.METRICS.GROUP_QUALITY'),
          metrics: [
            ...(this.itilEnabled
              ? [
                  {
                    value: s.open_problems ?? 0,
                    label: this.$t('CASE_TICKETS.METRICS.OPEN_PROBLEMS'),
                    valueClass: VALUE_NEUTRAL,
                  },
                  {
                    value: s.pending_changes ?? 0,
                    label: this.$t('CASE_TICKETS.METRICS.PENDING_CHANGES'),
                    valueClass:
                      s.pending_changes > 0 ? VALUE_WARNING : VALUE_NEUTRAL,
                  },
                ]
              : []),
            {
              value: this.csatText,
              label: this.$t('CASE_TICKETS.METRICS.CSAT'),
              valueClass: VALUE_NEUTRAL,
            },
          ],
        },
      ];
    },
  },
  mounted() {
    this.fetch();
    this.$store.dispatch('caseTickets/fetchSettings'); // modo simple/ITIL
  },
  methods: {
    fetch() {
      const period = PERIODS.find(p => p.key === this.selectedPeriod);
      const params = {};
      if (period?.days) {
        const from = new Date();
        from.setDate(from.getDate() - period.days);
        params.date_from = from.toISOString().split('T')[0];
        params.date_to = new Date().toISOString().split('T')[0];
      }
      this.$store.dispatch('caseTickets/fetchMetrics', params);
    },
    selectPeriod(key) {
      this.selectedPeriod = key;
      this.fetch();
    },
    minutesToText(m) {
      if (m == null) return '—';
      const h = Math.floor(m / 60);
      const min = Math.round(m % 60);
      return h > 0 ? `${h}h ${min}m` : `${min}m`;
    },
    shortDate(d) {
      if (!d) return '';
      return new Date(d).toLocaleDateString(undefined, {
        day: '2-digit',
        month: '2-digit',
      });
    },
    statusLabel(key) {
      return this.$t(`CASE_TICKETS.STATUSES.${key}`) || key;
    },
    priorityLabel(key) {
      return this.$t(`CASE_TICKETS.PRIORITIES.${key}`) || key;
    },
    slaLabel(key) {
      return this.$t(`CASE_TICKETS.STATUSES.${key}`) || key;
    },
    formatDate(d) {
      if (!d) return '';
      return new Date(d).toLocaleDateString(undefined, {
        day: '2-digit',
        month: '2-digit',
        year: 'numeric',
      });
    },
  },
};
</script>

<template>
  <div
    class="flex flex-col flex-1 w-full h-full overflow-hidden bg-slate-25 dark:bg-slate-900"
  >
    <!-- Header -->
    <div
      class="flex flex-wrap items-center justify-between flex-shrink-0 gap-4 px-6 py-4 bg-white border-b dark:bg-slate-900 border-slate-50 dark:border-slate-800/50"
    >
      <div class="flex items-center gap-4">
        <woot-button
          size="small"
          variant="clear"
          color-scheme="secondary"
          icon="arrow-left"
          @click="$router.push({ name: 'gestorTickets_index' })"
        >
          Volver
        </woot-button>
        <h1 class="m-0 text-xl font-bold text-slate-800 dark:text-slate-100">
          {{ $t('CASE_TICKETS.METRICS.TITLE') }}
        </h1>
      </div>

      <!-- Selector de período -->
      <div class="flex gap-1">
        <button
          v-for="p in periods"
          :key="p.key"
          class="px-3 py-1 text-sm border rounded-full transition-colors"
          :class="
            selectedPeriod === p.key
              ? 'bg-woot-500 border-woot-500 text-white'
              : 'bg-white dark:bg-slate-800 border-slate-100 dark:border-slate-700 text-slate-600 dark:text-slate-300 hover:border-woot-500'
          "
          @click="selectPeriod(p.key)"
        >
          {{ p.label }}
        </button>
      </div>
    </div>

    <!-- Loading -->
    <div
      v-if="isLoading"
      class="flex items-center justify-center flex-1 text-slate-400 dark:text-slate-500"
    >
      <span>{{ $t('CASE_TICKETS.METRICS.LOADING') }}</span>
    </div>

    <div
      v-else-if="metrics"
      class="flex flex-col flex-1 gap-6 p-6 overflow-y-auto"
    >
      <!-- KPIs agrupados (estilo Resumen) -->
      <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
        <div
          v-for="group in metricGroups"
          :key="group.header"
          class="flex flex-col p-4 bg-white border rounded-md shadow-sm dark:bg-slate-800 border-slate-75 dark:border-slate-700"
        >
          <h3
            class="mb-6 text-xl font-medium text-slate-800 dark:text-slate-100"
          >
            {{ group.header }}
          </h3>
          <div class="flex flex-wrap items-end gap-x-8 gap-y-3">
            <div
              v-for="m in group.metrics"
              :key="m.label"
              class="flex flex-col"
            >
              <p
                class="text-sm leading-tight text-slate-600 dark:text-slate-300"
              >
                {{ m.label }}
              </p>
              <p class="mt-1 mb-0 text-3xl font-medium" :class="m.valueClass">
                {{ m.value }}
              </p>
            </div>
          </div>
        </div>
      </div>

      <!-- Serie diaria: creados vs resueltos (2J) -->
      <div
        class="p-4 bg-white border rounded-md shadow-sm dark:bg-slate-800 border-slate-75 dark:border-slate-700"
      >
        <h3 class="mb-4 text-xl font-medium text-slate-800 dark:text-slate-100">
          {{ $t('CASE_TICKETS.METRICS.DAILY') }}
        </h3>
        <div v-if="hasDailyData" class="chart-box">
          <BarChart
            :key="'daily' + chartKey"
            :collection="dailyChartData"
            :chart-options="dailyOptions"
          />
        </div>
        <p
          v-else
          class="py-10 text-sm text-center text-slate-400 dark:text-slate-500"
        >
          Sin datos
        </p>
      </div>

      <!-- Distribuciones -->
      <div
        class="grid gap-4"
        style="grid-template-columns: repeat(auto-fit, minmax(320px, 1fr))"
      >
        <!-- Por estado — barra vertical -->
        <div
          class="p-4 bg-white border rounded-md shadow-sm dark:bg-slate-800 border-slate-75 dark:border-slate-700"
        >
          <h3
            class="mb-4 text-xl font-medium text-slate-800 dark:text-slate-100"
          >
            {{ $t('CASE_TICKETS.METRICS.BY_STATUS') }}
          </h3>
          <div v-if="hasStatusData" class="chart-box">
            <BarChart
              :key="'status' + chartKey"
              :collection="statusChartData"
              :chart-options="barOptions"
            />
          </div>
          <p
            v-else
            class="py-10 text-sm text-center text-slate-400 dark:text-slate-500"
          >
            Sin datos
          </p>
        </div>

        <!-- Por tipo — dona -->
        <div
          class="p-4 bg-white border rounded-md shadow-sm dark:bg-slate-800 border-slate-75 dark:border-slate-700"
        >
          <h3
            class="mb-4 text-xl font-medium text-slate-800 dark:text-slate-100"
          >
            {{ $t('CASE_TICKETS.METRICS.BY_TYPE') }}
          </h3>
          <div v-if="hasTypeData" class="chart-box">
            <DoughnutChart
              :key="'type' + chartKey"
              :collection="typeChartData"
              :chart-options="doughnutOptions"
            />
          </div>
          <p
            v-else
            class="py-10 text-sm text-center text-slate-400 dark:text-slate-500"
          >
            Sin datos
          </p>
        </div>

        <!-- Por prioridad — dona -->
        <div
          class="p-4 bg-white border rounded-md shadow-sm dark:bg-slate-800 border-slate-75 dark:border-slate-700"
        >
          <h3
            class="mb-4 text-xl font-medium text-slate-800 dark:text-slate-100"
          >
            {{ $t('CASE_TICKETS.METRICS.BY_PRIORITY') }}
          </h3>
          <div v-if="hasPriorityData" class="chart-box">
            <DoughnutChart
              :key="'prio' + chartKey"
              :collection="priorityChartData"
              :chart-options="doughnutOptions"
            />
          </div>
          <p
            v-else
            class="py-10 text-sm text-center text-slate-400 dark:text-slate-500"
          >
            Sin datos
          </p>
        </div>

        <!-- Por SLA — dona -->
        <div
          class="p-4 bg-white border rounded-md shadow-sm dark:bg-slate-800 border-slate-75 dark:border-slate-700"
        >
          <h3
            class="mb-4 text-xl font-medium text-slate-800 dark:text-slate-100"
          >
            {{ $t('CASE_TICKETS.METRICS.BY_SLA') }}
          </h3>
          <div v-if="hasSlaData" class="chart-box">
            <DoughnutChart
              :key="'sla' + chartKey"
              :collection="slaChartData"
              :chart-options="doughnutOptions"
            />
          </div>
          <p
            v-else
            class="py-10 text-sm text-center text-slate-400 dark:text-slate-500"
          >
            Sin datos
          </p>
        </div>

        <!-- Por categoría — dona (2J) -->
        <div
          class="p-4 bg-white border rounded-md shadow-sm dark:bg-slate-800 border-slate-75 dark:border-slate-700"
        >
          <h3
            class="mb-4 text-xl font-medium text-slate-800 dark:text-slate-100"
          >
            {{ $t('CASE_TICKETS.METRICS.BY_CATEGORY') }}
          </h3>
          <div v-if="hasCategoryData" class="chart-box">
            <DoughnutChart
              :key="'cat' + chartKey"
              :collection="categoryChartData"
              :chart-options="doughnutOptions"
            />
          </div>
          <p
            v-else
            class="py-10 text-sm text-center text-slate-400 dark:text-slate-500"
          >
            Sin datos
          </p>
        </div>

        <!-- Por servicio — dona (2J) -->
        <div
          class="p-4 bg-white border rounded-md shadow-sm dark:bg-slate-800 border-slate-75 dark:border-slate-700"
        >
          <h3
            class="mb-4 text-xl font-medium text-slate-800 dark:text-slate-100"
          >
            {{ $t('CASE_TICKETS.METRICS.BY_SERVICE') }}
          </h3>
          <div v-if="hasServiceData" class="chart-box">
            <DoughnutChart
              :key="'svc' + chartKey"
              :collection="serviceChartData"
              :chart-options="doughnutOptions"
            />
          </div>
          <p
            v-else
            class="py-10 text-sm text-center text-slate-400 dark:text-slate-500"
          >
            Sin datos
          </p>
        </div>

        <!-- Por responsable — barra (2J) -->
        <div
          class="p-4 bg-white border rounded-md shadow-sm dark:bg-slate-800 border-slate-75 dark:border-slate-700"
        >
          <h3
            class="mb-4 text-xl font-medium text-slate-800 dark:text-slate-100"
          >
            {{ $t('CASE_TICKETS.METRICS.BY_ASSIGNEE') }}
          </h3>
          <div v-if="hasAssigneeData" class="chart-box">
            <BarChart
              :key="'asg' + chartKey"
              :collection="assigneeChartData"
              :chart-options="barOptions"
            />
          </div>
          <p
            v-else
            class="py-10 text-sm text-center text-slate-400 dark:text-slate-500"
          >
            Sin datos
          </p>
        </div>
      </div>

      <!-- Período info -->
      <p class="m-0 text-xs text-center text-slate-400 dark:text-slate-500">
        {{ $t('CASE_TICKETS.METRICS.PERIOD_FROM') }}
        {{ formatDate(metrics.period.from) }}
        {{ $t('CASE_TICKETS.METRICS.PERIOD_TO') }}
        {{ formatDate(metrics.period.to) }}
      </p>
    </div>

    <!-- Sin datos -->
    <div
      v-else
      class="flex items-center justify-center flex-1 text-slate-400 dark:text-slate-500"
    >
      <p>{{ $t('CASE_TICKETS.METRICS.EMPTY') }}</p>
    </div>
  </div>
</template>

<style lang="scss" scoped>
// vue-chartjs envuelve el canvas en un div propio sin altura → caía al default de 400px de
// chart.js (gráficos gigantes/dispares). Fijamos la altura y forzamos ese div interno a 100%.
.chart-box {
  height: 16rem;

  ::v-deep > div {
    position: relative;
    height: 100% !important;
  }
}
</style>
