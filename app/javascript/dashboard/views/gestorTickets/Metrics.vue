<!--
  @tickets_cases
  Vista de métricas del Gestor de Tickets — Tailwind + dark mode.
-->
<template>
  <div class="flex flex-col flex-1 w-full h-full overflow-hidden bg-slate-25 dark:bg-slate-900">
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
          :class="selectedPeriod === p.key
            ? 'bg-woot-500 border-woot-500 text-white'
            : 'bg-white dark:bg-slate-800 border-slate-100 dark:border-slate-700 text-slate-600 dark:text-slate-300 hover:border-woot-500'"
          @click="selectPeriod(p.key)"
        >
          {{ p.label }}
        </button>
      </div>
    </div>

    <!-- Loading -->
    <div v-if="isLoading" class="flex items-center justify-center flex-1 text-slate-400 dark:text-slate-500">
      <span>{{ $t('CASE_TICKETS.METRICS.LOADING') }}</span>
    </div>

    <div v-else-if="metrics" class="flex flex-col flex-1 gap-6 p-6 overflow-y-auto">
      <!-- Cards resumen -->
      <div class="grid gap-4" style="grid-template-columns: repeat(auto-fill, minmax(150px, 1fr));">
        <div
          v-for="card in summaryCards"
          :key="card.label"
          class="flex flex-col items-center justify-center gap-1 p-4 text-center border rounded-lg"
          :class="card.cardClass"
        >
          <span class="text-3xl font-bold leading-none text-slate-800 dark:text-slate-100">{{ card.value }}</span>
          <span class="text-xs text-center text-slate-500 dark:text-slate-400">{{ card.label }}</span>
        </div>
      </div>

      <!-- Distribuciones -->
      <div class="grid gap-4" style="grid-template-columns: repeat(auto-fit, minmax(320px, 1fr));">
        <!-- Por estado — barra vertical -->
        <div class="p-4 bg-white border rounded-lg dark:bg-slate-800 border-slate-75 dark:border-slate-700">
          <h3 class="mb-4 text-base font-semibold text-slate-800 dark:text-slate-100">{{ $t('CASE_TICKETS.METRICS.BY_STATUS') }}</h3>
          <div v-if="hasStatusData" class="h-56">
            <BarChart :key="'status' + chartKey" :collection="statusChartData" :chart-options="barOptions" />
          </div>
          <p v-else class="py-10 text-sm text-center text-slate-400 dark:text-slate-500">Sin datos</p>
        </div>

        <!-- Por tipo — dona -->
        <div class="p-4 bg-white border rounded-lg dark:bg-slate-800 border-slate-75 dark:border-slate-700">
          <h3 class="mb-4 text-base font-semibold text-slate-800 dark:text-slate-100">{{ $t('CASE_TICKETS.METRICS.BY_TYPE') }}</h3>
          <div v-if="hasTypeData" class="h-56">
            <DoughnutChart :key="'type' + chartKey" :collection="typeChartData" />
          </div>
          <p v-else class="py-10 text-sm text-center text-slate-400 dark:text-slate-500">Sin datos</p>
        </div>

        <!-- Por prioridad — dona -->
        <div class="p-4 bg-white border rounded-lg dark:bg-slate-800 border-slate-75 dark:border-slate-700">
          <h3 class="mb-4 text-base font-semibold text-slate-800 dark:text-slate-100">{{ $t('CASE_TICKETS.METRICS.BY_PRIORITY') }}</h3>
          <div v-if="hasPriorityData" class="h-56">
            <DoughnutChart :key="'prio' + chartKey" :collection="priorityChartData" />
          </div>
          <p v-else class="py-10 text-sm text-center text-slate-400 dark:text-slate-500">Sin datos</p>
        </div>

        <!-- Por SLA — dona -->
        <div class="p-4 bg-white border rounded-lg dark:bg-slate-800 border-slate-75 dark:border-slate-700">
          <h3 class="mb-4 text-base font-semibold text-slate-800 dark:text-slate-100">{{ $t('CASE_TICKETS.METRICS.BY_SLA') }}</h3>
          <div v-if="hasSlaData" class="h-56">
            <DoughnutChart :key="'sla' + chartKey" :collection="slaChartData" />
          </div>
          <p v-else class="py-10 text-sm text-center text-slate-400 dark:text-slate-500">Sin datos</p>
        </div>
      </div>

      <!-- Período info -->
      <p class="m-0 text-xs text-center text-slate-400 dark:text-slate-500">
        {{ $t('CASE_TICKETS.METRICS.PERIOD_FROM') }} {{ formatDate(metrics.period.from) }}
        {{ $t('CASE_TICKETS.METRICS.PERIOD_TO') }} {{ formatDate(metrics.period.to) }}
      </p>
    </div>

    <!-- Sin datos -->
    <div v-else class="flex items-center justify-center flex-1 text-slate-400 dark:text-slate-500">
      <p>{{ $t('CASE_TICKETS.METRICS.EMPTY') }}</p>
    </div>
  </div>
</template>

<script>
import { mapGetters } from 'vuex';
import BarChart from 'dashboard/components/widgets/chart/BarChart';
import DoughnutChart from 'dashboard/components/widgets/chart/DoughnutChart';

const PERIODS = [
  { key: '7d',  label: '7 días',   days: 7   },
  { key: '30d', label: '30 días',  days: 30  },
  { key: '90d', label: '90 días',  days: 90  },
  { key: 'all', label: 'Todo',     days: null },
];

const CLOSED_STATUSES = ['closed', 'cancelled'];

// Paletas de color (hex para chart.js)
const TYPE_PALETTE     = ['#3b82f6', '#8b5cf6', '#06b6d4', '#f59e0b', '#ec4899'];
const PRIORITY_COLORS  = { low: '#94a3b8', medium: '#3b82f6', high: '#eab308', urgent: '#ef4444' };
const SLA_COLORS       = { on_time: '#22c55e', at_risk: '#eab308', overdue: '#ef4444' };

const BAR_OPTIONS = {
  responsive: true,
  maintainAspectRatio: false,
  legend: { display: false },
  scales: {
    xAxes: [{ gridLines: { drawOnChartArea: false } }],
    yAxes: [{ ticks: { beginAtZero: true, precision: 0 }, gridLines: { drawOnChartArea: false } }],
  },
};

const CARD_NEUTRAL = 'bg-white dark:bg-slate-800 border-slate-75 dark:border-slate-700';
const CARD_ALERT   = 'bg-red-50 dark:bg-red-900/20 border-red-200 dark:border-red-800';
const CARD_WARNING = 'bg-yellow-50 dark:bg-yellow-900/20 border-yellow-200 dark:border-yellow-800';
const CARD_SUCCESS = 'bg-green-50 dark:bg-green-900/20 border-green-200 dark:border-green-800';

export default {
  name: 'GestorTicketsMetrics',
  components: { BarChart, DoughnutChart },
  data() {
    return { selectedPeriod: '30d', barOptions: BAR_OPTIONS };
  },
  computed: {
    ...mapGetters({
      metrics: 'caseTickets/getMetrics',
      uiFlags:  'caseTickets/getUIFlags',
    }),
    isLoading()  { return this.uiFlags.isFetchingList; },
    periods()    { return PERIODS; },

    // key que cambia con el período para forzar re-render de los charts
    chartKey() { return this.selectedPeriod; },

    activeStatuses() {
      if (!this.metrics?.by_status) return {};
      return Object.fromEntries(
        Object.entries(this.metrics.by_status).filter(([k]) => !CLOSED_STATUSES.includes(k))
      );
    },

    // ── Datasets chart.js ──────────────────────────────────────
    hasStatusData()   { return Object.values(this.activeStatuses).some(v => v > 0); },
    hasTypeData()     { return Object.values(this.metrics?.by_type || {}).some(v => v > 0); },
    hasPriorityData() { return Object.values(this.metrics?.by_priority || {}).some(v => v > 0); },
    hasSlaData()      { return Object.values(this.metrics?.by_sla_status || {}).some(v => v > 0); },

    statusChartData() {
      const entries = Object.entries(this.activeStatuses);
      return {
        labels: entries.map(([k]) => this.statusLabel(k)),
        datasets: [{
          data: entries.map(([, v]) => v),
          backgroundColor: '#3b82f6',
          hoverBackgroundColor: '#2563eb',
          barPercentage: 0.6,
        }],
      };
    },
    typeChartData() {
      const entries = Object.entries(this.metrics?.by_type || {}).filter(([, v]) => v > 0);
      return {
        labels: entries.map(([k]) => k), // by_type ya viene con el nombre del tipo como clave
        datasets: [{
          data: entries.map(([, v]) => v),
          backgroundColor: entries.map((_, i) => TYPE_PALETTE[i % TYPE_PALETTE.length]),
          borderWidth: 0,
        }],
      };
    },
    priorityChartData() {
      const entries = Object.entries(this.metrics?.by_priority || {}).filter(([, v]) => v > 0);
      return {
        labels: entries.map(([k]) => this.priorityLabel(k)),
        datasets: [{
          data: entries.map(([, v]) => v),
          backgroundColor: entries.map(([k]) => PRIORITY_COLORS[k] || '#94a3b8'),
          borderWidth: 0,
        }],
      };
    },
    slaChartData() {
      const entries = Object.entries(this.metrics?.by_sla_status || {}).filter(([, v]) => v > 0);
      return {
        labels: entries.map(([k]) => this.slaLabel(k)),
        datasets: [{
          data: entries.map(([, v]) => v),
          backgroundColor: entries.map(([k]) => SLA_COLORS[k] || '#94a3b8'),
          borderWidth: 0,
        }],
      };
    },

    avgResolutionText() {
      const m = this.metrics?.summary?.avg_resolution_minutes;
      if (m == null) return '—';
      const h = Math.floor(m / 60);
      const min = Math.round(m % 60);
      return h > 0 ? `${h}h ${min}m` : `${min}m`;
    },

    complianceCardClass() {
      const r = this.metrics?.summary?.sla_compliance_rate;
      if (r == null) return CARD_NEUTRAL;
      if (r >= 90)  return CARD_SUCCESS;
      if (r >= 70)  return CARD_WARNING;
      return CARD_ALERT;
    },

    summaryCards() {
      const s = this.metrics?.summary || {};
      return [
        { value: s.total ?? 0,        label: this.$t('CASE_TICKETS.METRICS.TOTAL_PERIOD'),  cardClass: CARD_NEUTRAL },
        { value: s.total_open ?? 0,   label: this.$t('CASE_TICKETS.METRICS.TOTAL_OPEN'),    cardClass: CARD_NEUTRAL },
        { value: s.sla_overdue ?? 0,  label: this.$t('CASE_TICKETS.METRICS.SLA_OVERDUE'),   cardClass: s.sla_overdue > 0 ? CARD_ALERT : CARD_NEUTRAL },
        { value: s.sla_at_risk ?? 0,  label: this.$t('CASE_TICKETS.METRICS.SLA_AT_RISK'),   cardClass: s.sla_at_risk > 0 ? CARD_WARNING : CARD_NEUTRAL },
        { value: s.sla_compliance_rate != null ? s.sla_compliance_rate + '%' : '—', label: this.$t('CASE_TICKETS.METRICS.SLA_COMPLIANCE'), cardClass: this.complianceCardClass },
        { value: this.avgResolutionText, label: this.$t('CASE_TICKETS.METRICS.AVG_RESOLUTION'), cardClass: CARD_NEUTRAL },
        { value: s.resolved_this_period ?? 0, label: this.$t('CASE_TICKETS.METRICS.RESOLVED_PERIOD'), cardClass: CARD_SUCCESS },
      ];
    },
  },
  mounted() {
    this.fetch();
  },
  methods: {
    fetch() {
      const period = PERIODS.find(p => p.key === this.selectedPeriod);
      const params = {};
      if (period?.days) {
        const from = new Date();
        from.setDate(from.getDate() - period.days);
        params.date_from = from.toISOString().split('T')[0];
        params.date_to   = new Date().toISOString().split('T')[0];
      }
      this.$store.dispatch('caseTickets/fetchMetrics', params);
    },
    selectPeriod(key) {
      this.selectedPeriod = key;
      this.fetch();
    },
    statusLabel(key)   { return this.$t(`CASE_TICKETS.STATUSES.${key}`) || key; },
    priorityLabel(key) { return this.$t(`CASE_TICKETS.PRIORITIES.${key}`) || key; },
    slaLabel(key)      { return this.$t(`CASE_TICKETS.STATUSES.${key}`) || key; },
    formatDate(d) {
      if (!d) return '';
      return new Date(d).toLocaleDateString(undefined, {
        day: '2-digit', month: '2-digit', year: 'numeric',
      });
    },
  },
};
</script>
