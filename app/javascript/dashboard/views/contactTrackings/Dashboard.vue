<script>
// ================================================================================
// proyecto@contact_tracking — Dashboard de Seguimientos (Fase 1)
// KPIs + donut por estado + tabla de vencidos. Patrón espejo de gestorTickets/Metrics.
// ================================================================================
import { mapGetters } from 'vuex';
import DoughnutChart from 'dashboard/components/widgets/chart/DoughnutChart';
import BarChart from 'dashboard/components/widgets/chart/BarChart';
import HorizontalBarChart from 'dashboard/components/widgets/chart/HorizontalBarChart';
import TrackingsTable from './TrackingsTable.vue';

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
  components: { DoughnutChart, BarChart, HorizontalBarChart, TrackingsTable },
  data() {
    return {
      activeTab: 'list',
      filters: { date_from: '', date_to: '', inbox_id: '', template_id: '', status: '' },
      statusOptions: Object.keys(STATUS_META),
      statusMeta: STATUS_META,
    };
  },
  computed: {
    ...mapGetters({
      metrics: 'contactTrackings/getMetrics',
      metricsFlags: 'contactTrackings/getMetricsFlags',
      inboxes: 'inboxes/getInboxes',
      templates: 'trackingTemplates/getTemplates',
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

    // Fase 3 — serie temporal
    hasTimeseries() {
      return (this.metrics?.timeseries || []).some(p => p.created > 0 || p.completed > 0);
    },
    timeseriesChartData() {
      const ts = this.metrics?.timeseries || [];
      return {
        labels: ts.map(p => p.date.slice(5)),
        datasets: [
          { label: 'Creados', data: ts.map(p => p.created), backgroundColor: '#3b82f6', barPercentage: 0.7 },
          { label: 'Completados', data: ts.map(p => p.completed), backgroundColor: '#16a34a', barPercentage: 0.7 },
        ],
      };
    },

    // Fase 3 — próximas citas
    appointmentsList() {
      return this.metrics?.lists?.appointments || [];
    },
  },
  mounted() {
    this.fetchMetrics();
    this.$store.dispatch('trackingTemplates/get');
  },
  methods: {
    fetchMetrics() {
      const params = {};
      Object.entries(this.filters).forEach(([k, v]) => {
        if (v) params[k] = v;
      });
      this.$store.dispatch('contactTrackings/fetchMetrics', params);
    },
    resetFilters() {
      this.filters = { date_from: '', date_to: '', inbox_id: '', template_id: '', status: '' };
      this.fetchMetrics();
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
        v-if="activeTab === 'summary'"
        variant="smooth"
        size="small"
        icon="arrow-clockwise"
        :is-loading="metricsFlags.isFetching"
        @click="fetchMetrics"
      >
        Actualizar
      </woot-button>
    </div>

    <!-- Pestañas -->
    <div class="flex gap-1 border-b border-slate-100 dark:border-slate-700">
      <button
        class="px-3 py-2 text-sm -mb-px border-b-2"
        :class="activeTab === 'list' ? 'border-woot-500 text-woot-600 font-medium' : 'border-transparent text-slate-500'"
        @click="activeTab = 'list'"
      >
        Listado
      </button>
      <button
        class="px-3 py-2 text-sm -mb-px border-b-2"
        :class="activeTab === 'summary' ? 'border-woot-500 text-woot-600 font-medium' : 'border-transparent text-slate-500'"
        @click="activeTab = 'summary'"
      >
        Resumen
      </button>
    </div>

    <TrackingsTable v-if="activeTab === 'list'" />

    <div v-show="activeTab === 'summary'" class="flex flex-col gap-4">
    <!-- Filtros -->
    <div class="flex flex-wrap items-end gap-2 p-3 rounded-lg bg-white dark:bg-slate-800 border border-slate-100 dark:border-slate-700">
      <label class="text-xs text-slate-500 dark:text-slate-400 flex flex-col gap-1">
        Desde
        <input v-model="filters.date_from" type="date" class="text-sm rounded border border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-900 px-2 py-1" />
      </label>
      <label class="text-xs text-slate-500 dark:text-slate-400 flex flex-col gap-1">
        Hasta
        <input v-model="filters.date_to" type="date" class="text-sm rounded border border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-900 px-2 py-1" />
      </label>
      <label class="text-xs text-slate-500 dark:text-slate-400 flex flex-col gap-1">
        Canal
        <select v-model="filters.inbox_id" class="text-sm rounded border border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-900 px-2 py-1">
          <option value="">Todos</option>
          <option v-for="ib in inboxes" :key="ib.id" :value="ib.id">{{ ib.name }}</option>
        </select>
      </label>
      <label class="text-xs text-slate-500 dark:text-slate-400 flex flex-col gap-1">
        Agente IA
        <select v-model="filters.template_id" class="text-sm rounded border border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-900 px-2 py-1">
          <option value="">Todos</option>
          <option v-for="tpl in templates" :key="tpl.id" :value="tpl.id">{{ tpl.name }}</option>
        </select>
      </label>
      <label class="text-xs text-slate-500 dark:text-slate-400 flex flex-col gap-1">
        Estado
        <select v-model="filters.status" class="text-sm rounded border border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-900 px-2 py-1">
          <option value="">Todos</option>
          <option v-for="s in statusOptions" :key="s" :value="s">{{ statusMeta[s].label }}</option>
        </select>
      </label>
      <woot-button variant="smooth" size="small" @click="fetchMetrics">Aplicar</woot-button>
      <woot-button variant="clear" size="small" @click="resetFilters">Limpiar</woot-button>
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

    <!-- Serie temporal -->
    <div class="p-4 rounded-lg bg-white dark:bg-slate-800 border border-slate-100 dark:border-slate-700">
      <p class="text-sm font-medium mb-3 text-slate-700 dark:text-slate-200">Creados vs Completados (por día)</p>
      <div v-if="hasTimeseries" class="h-56">
        <BarChart :collection="timeseriesChartData" />
      </div>
      <p v-else class="text-sm text-slate-400 py-8 text-center">Sin datos en el rango.</p>
    </div>

    <!-- Próximas citas -->
    <div class="p-4 rounded-lg bg-white dark:bg-slate-800 border border-slate-100 dark:border-slate-700">
      <p class="text-sm font-medium mb-3 text-slate-700 dark:text-slate-200">
        📅 Próximas citas ({{ appointmentsList.length }})
      </p>
      <table v-if="appointmentsList.length" class="w-full text-sm">
        <thead>
          <tr class="text-left text-slate-500 dark:text-slate-400 border-b border-slate-100 dark:border-slate-700">
            <th class="py-2">Contacto</th>
            <th class="py-2">Cuándo</th>
            <th class="py-2">Objetivo</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="a in appointmentsList" :key="a.id" class="border-b border-slate-50 dark:border-slate-700/50">
            <td class="py-2 text-slate-700 dark:text-slate-200">{{ a.contact_name || '—' }}</td>
            <td class="py-2 text-slate-500 dark:text-slate-400">{{ formatDate(a.appointment_at) }}</td>
            <td class="py-2 text-slate-600 dark:text-slate-300 truncate max-w-xs">{{ a.objective }}</td>
          </tr>
        </tbody>
      </table>
      <p v-else class="text-sm text-slate-400 py-4 text-center">No hay citas próximas.</p>
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
  </div>
</template>
