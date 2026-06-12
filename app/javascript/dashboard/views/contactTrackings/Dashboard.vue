<script>
// ================================================================================
// proyecto@contact_tracking — Dashboard de Seguimientos (Fase 1)
// KPIs + donut por estado + tabla de vencidos. Patrón espejo de gestorTickets/Metrics.
// ================================================================================
import { mapGetters } from 'vuex';
import DoughnutChart from 'dashboard/components/widgets/chart/DoughnutChart';
import BarChart from 'dashboard/components/widgets/chart/BarChart';
import HorizontalBarChart from 'dashboard/components/widgets/chart/HorizontalBarChart';

const STATUS_META = {
  pending: { label: 'Pendiente', color: '#94a3b8' },
  scheduled: { label: 'Programado', color: '#3b82f6' },
  active: { label: 'Activo', color: '#22c55e' },
  paused: { label: 'Pausado', color: '#f59e0b' },
  completed: { label: 'Completado', color: '#16a34a' },
  cancelled: { label: 'Cancelado', color: '#ef4444' },
  failed: { label: 'Fallido', color: '#b91c1c' },
};

export default {
  components: { DoughnutChart, BarChart, HorizontalBarChart },
  computed: {
    ...mapGetters({
      metrics: 'contactTrackings/getMetrics',
      metricsFlags: 'contactTrackings/getMetricsFlags',
    }),
    summary() {
      return this.metrics?.summary || {};
    },
    successPct() {
      return Math.round((this.summary.success_rate || 0) * 100);
    },
    overdueList() {
      return this.metrics?.lists?.overdue || [];
    },
    hasStatusData() {
      return Object.values(this.metrics?.by_status || {}).some(v => v > 0);
    },
    statusChartData() {
      const entries = Object.entries(this.metrics?.by_status || {}).filter(
        ([, v]) => v > 0
      );
      return {
        labels: entries.map(([k]) => STATUS_META[k]?.label || k),
        datasets: [
          {
            data: entries.map(([, v]) => v),
            backgroundColor: entries.map(([k]) => STATUS_META[k]?.color || '#94a3b8'),
            borderWidth: 0,
          },
        ],
      };
    },

    // Fase 2 — por canal (inbox)
    byInbox() {
      return this.metrics?.by_inbox || [];
    },
    hasInboxData() {
      return this.byInbox.some(x => x.count > 0);
    },
    inboxChartData() {
      return {
        labels: this.byInbox.map(x => x.name),
        datasets: [
          {
            data: this.byInbox.map(x => x.count),
            backgroundColor: '#3b82f6',
            barPercentage: 0.6,
          },
        ],
      };
    },

    // Fase 2 — por Agente IA (template), total vs éxito
    byTemplate() {
      return this.metrics?.by_template || [];
    },
    hasTemplateData() {
      return this.byTemplate.some(x => x.total > 0);
    },
    templateChartData() {
      return {
        labels: this.byTemplate.map(x => x.name),
        datasets: [
          {
            label: 'Total',
            data: this.byTemplate.map(x => x.total),
            backgroundColor: '#94a3b8',
            barPercentage: 0.6,
          },
          {
            label: 'Éxito',
            data: this.byTemplate.map(x => x.success),
            backgroundColor: '#16a34a',
            barPercentage: 0.6,
          },
        ],
      };
    },

    // Fase 2 — embudo de intención
    funnelStages() {
      const f = this.metrics?.funnel || {};
      const created = f.created || 0;
      const pct = v => (created ? Math.round((v / created) * 100) : 0);
      return [
        { label: 'Creados', value: f.created || 0, pct: 100, color: '#3b82f6' },
        { label: 'Respondieron', value: f.replied || 0, pct: pct(f.replied), color: '#6366f1' },
        { label: 'Interesados', value: f.interested || 0, pct: pct(f.interested), color: '#8b5cf6' },
        { label: 'Citas', value: f.appointment || 0, pct: pct(f.appointment), color: '#16a34a' },
      ];
    },
  },
  mounted() {
    this.fetchMetrics();
  },
  methods: {
    fetchMetrics() {
      this.$store.dispatch('contactTrackings/fetchMetrics');
    },
    formatDate(value) {
      if (!value) return '—';
      return new Date(value).toLocaleString();
    },
  },
};
</script>

<template>
  <div class="flex flex-col flex-1 w-full h-full overflow-auto p-4 gap-4">
    <div class="flex items-center justify-between">
      <h1 class="text-xl font-medium text-slate-800 dark:text-slate-100">
        Dashboard de Seguimientos
      </h1>
      <woot-button
        variant="smooth"
        size="small"
        icon="arrow-clockwise"
        :is-loading="metricsFlags.isFetching"
        @click="fetchMetrics"
      >
        Actualizar
      </woot-button>
    </div>

    <!-- KPIs -->
    <div class="grid grid-cols-2 md:grid-cols-5 gap-3">
      <div class="p-3 rounded-lg bg-white dark:bg-slate-800 border border-slate-100 dark:border-slate-700">
        <p class="text-2xl font-semibold text-slate-800 dark:text-slate-100">{{ summary.active || 0 }}</p>
        <p class="text-xs text-slate-500 dark:text-slate-400">Activos</p>
      </div>
      <div class="p-3 rounded-lg bg-white dark:bg-slate-800 border border-slate-100 dark:border-slate-700">
        <p class="text-2xl font-semibold text-red-500">{{ summary.overdue || 0 }}</p>
        <p class="text-xs text-slate-500 dark:text-slate-400">Vencidos</p>
      </div>
      <div class="p-3 rounded-lg bg-white dark:bg-slate-800 border border-slate-100 dark:border-slate-700">
        <p class="text-2xl font-semibold text-green-600">{{ successPct }}%</p>
        <p class="text-xs text-slate-500 dark:text-slate-400">Tasa de éxito</p>
      </div>
      <div class="p-3 rounded-lg bg-white dark:bg-slate-800 border border-slate-100 dark:border-slate-700">
        <p class="text-2xl font-semibold text-slate-800 dark:text-slate-100">{{ summary.appointments || 0 }}</p>
        <p class="text-xs text-slate-500 dark:text-slate-400">Citas</p>
      </div>
      <div class="p-3 rounded-lg bg-white dark:bg-slate-800 border border-slate-100 dark:border-slate-700">
        <p class="text-2xl font-semibold text-slate-800 dark:text-slate-100">{{ summary.due_24h || 0 }}</p>
        <p class="text-xs text-slate-500 dark:text-slate-400">Próximas 24 h</p>
      </div>
    </div>

    <!-- Donut por estado -->
    <div class="p-4 rounded-lg bg-white dark:bg-slate-800 border border-slate-100 dark:border-slate-700">
      <p class="text-sm font-medium mb-3 text-slate-700 dark:text-slate-200">Seguimientos por estado</p>
      <div v-if="hasStatusData" class="h-64">
        <DoughnutChart :collection="statusChartData" />
      </div>
      <p v-else class="text-sm text-slate-400 py-8 text-center">Sin datos todavía.</p>
    </div>

    <!-- Canal + Agente IA -->
    <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
      <div class="p-4 rounded-lg bg-white dark:bg-slate-800 border border-slate-100 dark:border-slate-700">
        <p class="text-sm font-medium mb-3 text-slate-700 dark:text-slate-200">Por canal</p>
        <div v-if="hasInboxData" class="h-56">
          <HorizontalBarChart :collection="inboxChartData" />
        </div>
        <p v-else class="text-sm text-slate-400 py-8 text-center">Sin datos.</p>
      </div>
      <div class="p-4 rounded-lg bg-white dark:bg-slate-800 border border-slate-100 dark:border-slate-700">
        <p class="text-sm font-medium mb-3 text-slate-700 dark:text-slate-200">Por Agente IA (total vs éxito)</p>
        <div v-if="hasTemplateData" class="h-56">
          <BarChart :collection="templateChartData" />
        </div>
        <p v-else class="text-sm text-slate-400 py-8 text-center">Sin datos.</p>
      </div>
    </div>

    <!-- Embudo de intención -->
    <div class="p-4 rounded-lg bg-white dark:bg-slate-800 border border-slate-100 dark:border-slate-700">
      <p class="text-sm font-medium mb-3 text-slate-700 dark:text-slate-200">Embudo de intención</p>
      <div class="flex flex-col gap-2">
        <div v-for="stage in funnelStages" :key="stage.label" class="flex items-center gap-3">
          <span class="w-28 text-xs text-slate-500 dark:text-slate-400 shrink-0">{{ stage.label }}</span>
          <div class="flex-1 h-5 rounded bg-slate-100 dark:bg-slate-700 overflow-hidden">
            <div
              class="h-full rounded transition-all"
              :style="{ width: stage.pct + '%', backgroundColor: stage.color }"
            />
          </div>
          <span class="w-16 text-right text-xs text-slate-600 dark:text-slate-300 shrink-0">
            {{ stage.value }} ({{ stage.pct }}%)
          </span>
        </div>
      </div>
    </div>

    <!-- Vencidos -->
    <div class="p-4 rounded-lg bg-white dark:bg-slate-800 border border-slate-100 dark:border-slate-700">
      <p class="text-sm font-medium mb-3 text-slate-700 dark:text-slate-200">
        ⚠️ Vencidos ({{ overdueList.length }})
      </p>
      <table v-if="overdueList.length" class="w-full text-sm">
        <thead>
          <tr class="text-left text-slate-500 dark:text-slate-400 border-b border-slate-100 dark:border-slate-700">
            <th class="py-2">Contacto</th>
            <th class="py-2">Objetivo</th>
            <th class="py-2">Programado</th>
            <th class="py-2">Intentos</th>
          </tr>
        </thead>
        <tbody>
          <tr
            v-for="t in overdueList"
            :key="t.id"
            class="border-b border-slate-50 dark:border-slate-700/50"
          >
            <td class="py-2 text-slate-700 dark:text-slate-200">{{ t.contact_name || '—' }}</td>
            <td class="py-2 text-slate-600 dark:text-slate-300 truncate max-w-xs">{{ t.objective }}</td>
            <td class="py-2 text-slate-500 dark:text-slate-400">{{ formatDate(t.scheduled_for) }}</td>
            <td class="py-2 text-slate-500 dark:text-slate-400">{{ t.attempt_count }}/{{ t.max_attempts }}</td>
          </tr>
        </tbody>
      </table>
      <p v-else class="text-sm text-slate-400 py-4 text-center">No hay seguimientos vencidos. 🎉</p>
    </div>
  </div>
</template>
