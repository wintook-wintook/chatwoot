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
  objective_met: { label: 'Objetivo cumplido', color: '#059669' },
  cancelled: { label: 'Cancelado', color: '#ef4444' },
  failed: { label: 'Fallido', color: '#b91c1c' },
};

export default {
  components: { DoughnutChart, BarChart, HorizontalBarChart, TrackingsTable },
  data() {
    return {
      filters: {
        date_from: '',
        date_to: '',
        inbox_id: '',
        template_id: '',
        status: '',
      },
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
    // La pestaña activa la determina la ruta (menú secundario)
    activeTab() {
      return this.$route.name === 'contact_trackings_metrics'
        ? 'summary'
        : 'list';
    },
    // El HorizontalBarChart compartido no fija maintainAspectRatio, por eso no
    // llenaba el alto del contenedor y desalineaba las tarjetas. Lo forzamos y
    // mostramos las etiquetas del eje Y (nombres de canal).
    inboxChartOptions() {
      return {
        maintainAspectRatio: false,
        scales: {
          xAxes: [{ display: false, ticks: { beginAtZero: true } }],
          yAxes: [{ display: true, gridLines: { drawOnChartArea: false } }],
        },
      };
    },
    summary() {
      return this.metrics?.summary || {};
    },
    successPct() {
      return Math.round((this.summary.success_rate || 0) * 100);
    },

    // ── Los 3 ejes del estatus, separados ──────────────────────────────
    byStatus() {
      return this.metrics?.by_status || {};
    },
    // 🎯 Intención — qué pasó con el cliente (IA + reglas)
    intentionKpis() {
      const s = this.summary;
      const f = this.metrics?.funnel || {};
      return [
        { label: 'Interesados', value: f.interested || 0, color: 'text-violet-600' },
        { label: 'Citas', value: s.appointments || 0, color: 'text-slate-800 dark:text-slate-100' },
        { label: 'Objetivo cumplido', value: s.objectives_met || 0, color: 'text-emerald-600' },
        { label: 'Rechazos', value: s.rejected || 0, color: 'text-red-500' },
      ];
    },
    // ⚙️ Control — en qué punto del ciclo está el seguimiento (interno)
    controlKpis() {
      const b = this.byStatus;
      const active = (b.pending || 0) + (b.scheduled || 0) + (b.active || 0);
      return [
        { label: 'Activos', value: active, color: 'text-slate-800 dark:text-slate-100' },
        { label: 'Pausados', value: b.paused || 0, color: 'text-amber-500' },
        { label: 'Vencidos', value: this.summary.overdue || 0, color: 'text-red-500' },
        { label: 'Cancelados', value: b.cancelled || 0, color: 'text-red-500' },
        { label: 'Fallidos', value: b.failed || 0, color: 'text-red-700' },
      ];
    },
    // 📬 Entrega — si el mensaje llegó a WhatsApp (canal)
    delivery() {
      return this.metrics?.delivery || {};
    },
    deliveryKpis() {
      const d = this.delivery;
      return [
        { label: 'Entregados', value: d.delivered || 0, color: 'text-green-600' },
        { label: 'Enviados', value: d.sent || 0, color: 'text-slate-800 dark:text-slate-100' },
        { label: 'No entregados', value: d.failed || 0, color: 'text-red-500' },
      ];
    },
    hasDeliveryData() {
      const d = this.delivery;
      return (d.delivered || 0) + (d.sent || 0) + (d.failed || 0) > 0;
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
            backgroundColor: entries.map(
              ([k]) => STATUS_META[k]?.color || '#94a3b8'
            ),
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
        {
          label: 'Respondieron',
          value: f.replied || 0,
          pct: pct(f.replied),
          color: '#6366f1',
        },
        {
          label: 'Interesados',
          value: f.interested || 0,
          pct: pct(f.interested),
          color: '#8b5cf6',
        },
        {
          label: 'Citas',
          value: f.appointment || 0,
          pct: pct(f.appointment),
          color: '#16a34a',
        },
      ];
    },

    // Reglas — KPIs de palabras clave de acción (junto al embudo)
    rulesMetrics() {
      return this.metrics?.rules || {};
    },
    hasRulesData() {
      const r = this.rulesMetrics;
      return (r.trackings_with_rules || 0) > 0 || (r.fired_total || 0) > 0;
    },
    ruleActionStages() {
      const r = this.rulesMetrics;
      const by = r.by_action || {};
      const total = r.fired_total || 0;
      const pct = v => (total ? Math.round((v / total) * 100) : 0);
      return [
        {
          label: '🎯 Objetivo cumplido',
          value: by.objective_met || 0,
          pct: pct(by.objective_met || 0),
          color: '#059669',
        },
        {
          label: '⏸️ Pausados',
          value: by.pause || 0,
          pct: pct(by.pause || 0),
          color: '#f59e0b',
        },
        {
          label: '⌨️ Cancelados',
          value: by.cancel || 0,
          pct: pct(by.cancel || 0),
          color: '#ef4444',
        },
      ];
    },

    // Fase 3 — serie temporal
    hasTimeseries() {
      return (this.metrics?.timeseries || []).some(
        p => p.created > 0 || p.objectives_met > 0
      );
    },
    timeseriesChartData() {
      const ts = this.metrics?.timeseries || [];
      return {
        labels: ts.map(p => p.date.slice(5)),
        datasets: [
          {
            label: 'Creados',
            data: ts.map(p => p.created),
            backgroundColor: '#3b82f6',
            barPercentage: 0.7,
          },
          {
            label: 'Objetivos cumplidos',
            data: ts.map(p => p.objectives_met),
            backgroundColor: '#059669',
            barPercentage: 0.7,
          },
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
      this.filters = {
        date_from: '',
        date_to: '',
        inbox_id: '',
        template_id: '',
        status: '',
      };
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
    <div class="flex items-start justify-between">
      <div>
        <h1 class="text-xl font-medium text-slate-800 dark:text-slate-100">
          {{
            activeTab === 'summary'
              ? 'Resumen de Seguimientos'
              : 'Todos los Seguimientos'
          }}
        </h1>
        <p class="text-sm text-slate-600 dark:text-slate-400 mt-1">
          {{
            activeTab === 'summary'
              ? 'Métricas y KPIs de tus seguimientos con Agentes IA.'
              : 'Todos los seguimientos con Agentes IA en curso y su estado.'
          }}
        </p>
      </div>
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

    <TrackingsTable v-if="activeTab === 'list'" />

    <div v-show="activeTab === 'summary'" class="flex flex-col gap-4">
      <!-- Filtros -->
      <div
        class="flex flex-col gap-3 p-3 rounded-lg bg-white dark:bg-slate-800 border border-slate-100 dark:border-slate-700"
      >
        <div class="flex flex-wrap items-end gap-3">
          <label
            class="text-sm font-medium text-slate-600 dark:text-slate-300 flex flex-col gap-1"
          >
            Desde
            <input
              v-model="filters.date_from"
              type="date"
              class="text-sm rounded border border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-900 h-9 px-2"
            />
          </label>
          <label
            class="text-sm font-medium text-slate-600 dark:text-slate-300 flex flex-col gap-1"
          >
            Hasta
            <input
              v-model="filters.date_to"
              type="date"
              class="text-sm rounded border border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-900 h-9 px-2"
            />
          </label>
          <label
            class="text-sm font-medium text-slate-600 dark:text-slate-300 flex flex-col gap-1"
          >
            Canal
            <select
              v-model="filters.inbox_id"
              class="text-sm rounded border border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-900 h-9 px-2"
            >
              <option value="">Todos</option>
              <option v-for="ib in inboxes" :key="ib.id" :value="ib.id">
                {{ ib.name }}
              </option>
            </select>
          </label>
          <label
            class="text-sm font-medium text-slate-600 dark:text-slate-300 flex flex-col gap-1"
          >
            Agente IA
            <select
              v-model="filters.template_id"
              class="text-sm rounded border border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-900 h-9 px-2"
            >
              <option value="">Todos</option>
              <option v-for="tpl in templates" :key="tpl.id" :value="tpl.id">
                {{ tpl.name }}
              </option>
            </select>
          </label>
          <label
            class="text-sm font-medium text-slate-600 dark:text-slate-300 flex flex-col gap-1"
          >
            Estado
            <select
              v-model="filters.status"
              class="text-sm rounded border border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-900 h-9 px-2"
            >
              <option value="">Todos</option>
              <option v-for="s in statusOptions" :key="s" :value="s">
                {{ statusMeta[s].label }}
              </option>
            </select>
          </label>
        </div>
        <div class="flex items-center gap-2">
          <woot-button variant="smooth" size="small" @click="fetchMetrics"
            >Aplicar</woot-button
          >
          <woot-button variant="clear" size="small" @click="resetFilters"
            >Limpiar</woot-button
          >
        </div>
      </div>

      <!-- KPIs separados en los 3 ejes — 3 columnas compactas -->
      <div class="grid grid-cols-1 md:grid-cols-3 gap-3">
        <!-- 🎯 Intención -->
        <div
          class="p-3 rounded-lg bg-white dark:bg-slate-800 border border-slate-100 dark:border-slate-700"
        >
          <div class="flex items-center justify-between mb-2">
            <span class="text-sm font-medium text-slate-700 dark:text-slate-200">
              🎯 Intención
            </span>
            <span class="text-xs text-slate-500 dark:text-slate-400">
              éxito
              <span class="font-semibold text-green-600">{{ successPct }}%</span>
            </span>
          </div>
          <div class="divide-y divide-slate-100 dark:divide-slate-700/60">
            <div
              v-for="kpi in intentionKpis"
              :key="kpi.label"
              class="flex items-center justify-between py-1.5"
            >
              <span class="text-sm text-slate-500 dark:text-slate-400">
                {{ kpi.label }}
              </span>
              <span class="text-base font-semibold" :class="kpi.color">
                {{ kpi.value }}
              </span>
            </div>
          </div>
        </div>

        <!-- ⚙️ Control -->
        <div
          class="p-3 rounded-lg bg-white dark:bg-slate-800 border border-slate-100 dark:border-slate-700"
        >
          <span class="text-sm font-medium text-slate-700 dark:text-slate-200">
            ⚙️ Control
          </span>
          <div class="divide-y divide-slate-100 dark:divide-slate-700/60 mt-2">
            <div
              v-for="kpi in controlKpis"
              :key="kpi.label"
              class="flex items-center justify-between py-1.5"
            >
              <span class="text-sm text-slate-500 dark:text-slate-400">
                {{ kpi.label }}
              </span>
              <span class="text-base font-semibold" :class="kpi.color">
                {{ kpi.value }}
              </span>
            </div>
          </div>
        </div>

        <!-- 📬 Entrega -->
        <div
          class="p-3 rounded-lg bg-white dark:bg-slate-800 border border-slate-100 dark:border-slate-700"
        >
          <span class="text-sm font-medium text-slate-700 dark:text-slate-200">
            📬 Entrega de Mensajes
          </span>
          <div
            v-if="hasDeliveryData"
            class="divide-y divide-slate-100 dark:divide-slate-700/60 mt-2"
          >
            <div
              v-for="kpi in deliveryKpis"
              :key="kpi.label"
              class="flex items-center justify-between py-1.5"
            >
              <span class="text-sm text-slate-500 dark:text-slate-400">
                {{ kpi.label }}
              </span>
              <span class="text-base font-semibold" :class="kpi.color">
                {{ kpi.value }}
              </span>
            </div>
          </div>
          <p v-else class="text-xs text-slate-400 py-4 text-center">
            Aún no se han enviado mensajes.
          </p>
        </div>
      </div>

      <!-- Donut por estado -->
      <div
        class="p-4 rounded-lg bg-white dark:bg-slate-800 border border-slate-100 dark:border-slate-700"
      >
        <p class="text-sm font-medium mb-3 text-slate-700 dark:text-slate-200">
          Seguimientos por estado
        </p>
        <div v-if="hasStatusData" class="chart-box h-64">
          <DoughnutChart :collection="statusChartData" />
        </div>
        <p v-else class="text-sm text-slate-400 py-8 text-center">
          Sin datos todavía.
        </p>
      </div>

      <!-- Canal + Agente IA -->
      <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
        <div
          class="p-4 rounded-lg bg-white dark:bg-slate-800 border border-slate-100 dark:border-slate-700"
        >
          <p
            class="text-sm font-medium mb-3 text-slate-700 dark:text-slate-200"
          >
            Por canal
          </p>
          <div v-if="hasInboxData" class="chart-box h-56">
            <HorizontalBarChart
              :collection="inboxChartData"
              :chart-options="inboxChartOptions"
            />
          </div>
          <p v-else class="text-sm text-slate-400 py-8 text-center">
            Sin datos.
          </p>
        </div>
        <div
          class="p-4 rounded-lg bg-white dark:bg-slate-800 border border-slate-100 dark:border-slate-700"
        >
          <p
            class="text-sm font-medium mb-3 text-slate-700 dark:text-slate-200"
          >
            Por Agente IA (total vs éxito)
          </p>
          <div v-if="hasTemplateData" class="chart-box h-56">
            <BarChart :collection="templateChartData" />
          </div>
          <p v-else class="text-sm text-slate-400 py-8 text-center">
            Sin datos.
          </p>
        </div>
      </div>

      <!-- Embudo de intención -->
      <div
        class="p-4 rounded-lg bg-white dark:bg-slate-800 border border-slate-100 dark:border-slate-700"
      >
        <p class="text-sm font-medium mb-3 text-slate-700 dark:text-slate-200">
          Embudo de intención
        </p>
        <div class="flex flex-col gap-2">
          <div
            v-for="stage in funnelStages"
            :key="stage.label"
            class="flex items-center gap-3"
          >
            <span
              class="w-28 text-xs text-slate-500 dark:text-slate-400 shrink-0"
              >{{ stage.label }}</span
            >
            <div
              class="flex-1 h-5 rounded bg-slate-100 dark:bg-slate-700 overflow-hidden"
            >
              <div
                class="h-full rounded transition-all"
                :style="{
                  width: stage.pct + '%',
                  backgroundColor: stage.color,
                }"
              />
            </div>
            <span
              class="w-16 text-right text-xs text-slate-600 dark:text-slate-300 shrink-0"
            >
              {{ stage.value }} ({{ stage.pct }}%)
            </span>
          </div>
        </div>
      </div>

      <!-- Reglas de seguimiento (palabras clave de acción) -->
      <div
        class="p-4 rounded-lg bg-white dark:bg-slate-800 border border-slate-100 dark:border-slate-700"
      >
        <div class="flex items-center justify-between mb-3">
          <p class="text-sm font-medium text-slate-700 dark:text-slate-200">
            Reglas de seguimiento
          </p>
          <span
            v-if="hasRulesData"
            class="text-xs text-slate-500 dark:text-slate-400"
          >
            Tasa de disparo:
            <span class="font-semibold text-slate-700 dark:text-slate-200">
              {{ Math.round((rulesMetrics.fire_rate || 0) * 100) }}%
            </span>
          </span>
        </div>

        <!-- Adopción: siempre visible -->
        <div class="grid grid-cols-2 gap-3 mb-4">
          <div class="rounded-md bg-slate-50 dark:bg-slate-700/40 p-3">
            <p class="text-xs text-slate-500 dark:text-slate-400">
              Agentes IA con reglas
            </p>
            <p class="text-lg font-semibold text-slate-700 dark:text-slate-200">
              {{ rulesMetrics.templates_with_rules || 0 }}
              <span class="text-sm font-normal text-slate-400"
                >/ {{ rulesMetrics.templates_total || 0 }}</span
              >
            </p>
          </div>
          <div class="rounded-md bg-slate-50 dark:bg-slate-700/40 p-3">
            <p class="text-xs text-slate-500 dark:text-slate-400">
              Seguimientos con reglas
            </p>
            <p class="text-lg font-semibold text-slate-700 dark:text-slate-200">
              {{ rulesMetrics.trackings_with_rules || 0 }}
              <span class="text-sm font-normal text-slate-400"
                >/ {{ rulesMetrics.trackings_total || 0 }}</span
              >
            </p>
          </div>
        </div>

        <!-- Efectividad: solo sobre el subconjunto con reglas -->
        <template v-if="hasRulesData">
          <p class="text-xs text-slate-500 dark:text-slate-400 mb-2">
            Cerrados por una regla ({{ rulesMetrics.fired_total || 0 }} en total)
          </p>
          <div class="flex flex-col gap-2">
            <div
              v-for="stage in ruleActionStages"
              :key="stage.label"
              class="flex items-center gap-3"
            >
              <span
                class="w-36 text-xs text-slate-500 dark:text-slate-400 shrink-0"
                >{{ stage.label }}</span
              >
              <div
                class="flex-1 h-5 rounded bg-slate-100 dark:bg-slate-700 overflow-hidden"
              >
                <div
                  class="h-full rounded transition-all"
                  :style="{
                    width: stage.pct + '%',
                    backgroundColor: stage.color,
                  }"
                />
              </div>
              <span
                class="w-16 text-right text-xs text-slate-600 dark:text-slate-300 shrink-0"
              >
                {{ stage.value }} ({{ stage.pct }}%)
              </span>
            </div>
          </div>

          <!-- Top palabras clave -->
          <div
            v-if="(rulesMetrics.top_keywords || []).length"
            class="mt-4 pt-3 border-t border-slate-100 dark:border-slate-700"
          >
            <p class="text-xs text-slate-500 dark:text-slate-400 mb-2">
              Palabras clave más frecuentes
            </p>
            <div class="flex flex-wrap gap-1.5">
              <span
                v-for="kw in rulesMetrics.top_keywords"
                :key="kw.keyword"
                class="inline-flex items-center gap-1.5 text-xs rounded-full border border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-900 px-2 py-1"
              >
                <span class="text-slate-700 dark:text-slate-200">{{
                  kw.keyword
                }}</span>
                <span
                  class="text-slate-400 dark:text-slate-500 font-semibold"
                  >{{ kw.count }}</span
                >
              </span>
            </div>
          </div>
        </template>

        <!-- Empty-state: sin reglas configuradas -->
        <p
          v-else
          class="text-sm text-slate-400 py-6 text-center"
        >
          Aún no configuras reglas en tus Agentes IA. Agrégalas en la pestaña
          «Reglas» del Agente para automatizar cancelaciones, pausas y objetivos
          cumplidos.
        </p>
      </div>

      <!-- Serie temporal -->
      <div
        class="p-4 rounded-lg bg-white dark:bg-slate-800 border border-slate-100 dark:border-slate-700"
      >
        <p class="text-sm font-medium mb-3 text-slate-700 dark:text-slate-200">
          Creados vs Objetivos cumplidos (por día)
        </p>
        <div v-if="hasTimeseries" class="chart-box h-56">
          <BarChart :collection="timeseriesChartData" />
        </div>
        <p v-else class="text-sm text-slate-400 py-8 text-center">
          Sin datos en el rango.
        </p>
      </div>

      <!-- Próximas citas -->
      <div
        class="p-4 rounded-lg bg-white dark:bg-slate-800 border border-slate-100 dark:border-slate-700"
      >
        <p class="text-sm font-medium mb-3 text-slate-700 dark:text-slate-200">
          📅 Próximas citas ({{ appointmentsList.length }})
        </p>
        <table v-if="appointmentsList.length" class="w-full text-sm">
          <thead>
            <tr
              class="text-left text-slate-500 dark:text-slate-400 border-b border-slate-100 dark:border-slate-700"
            >
              <th class="py-2">Contacto</th>
              <th class="py-2">Cuándo</th>
              <th class="py-2">Objetivo</th>
            </tr>
          </thead>
          <tbody>
            <tr
              v-for="a in appointmentsList"
              :key="a.id"
              class="border-b border-slate-50 dark:border-slate-700/50"
            >
              <td class="py-2 text-slate-700 dark:text-slate-200">
                {{ a.contact_name || '—' }}
              </td>
              <td class="py-2 text-slate-500 dark:text-slate-400">
                {{ formatDate(a.appointment_at) }}
              </td>
              <td
                class="py-2 text-slate-600 dark:text-slate-300 truncate max-w-xs"
              >
                {{ a.objective }}
              </td>
            </tr>
          </tbody>
        </table>
        <p v-else class="text-sm text-slate-400 py-4 text-center">
          No hay citas próximas.
        </p>
      </div>

      <!-- Vencidos -->
      <div
        class="p-4 rounded-lg bg-white dark:bg-slate-800 border border-slate-100 dark:border-slate-700"
      >
        <p class="text-sm font-medium mb-3 text-slate-700 dark:text-slate-200">
          ⚠️ Vencidos ({{ overdueList.length }})
        </p>
        <table v-if="overdueList.length" class="w-full text-sm">
          <thead>
            <tr
              class="text-left text-slate-500 dark:text-slate-400 border-b border-slate-100 dark:border-slate-700"
            >
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
              <td class="py-2 text-slate-700 dark:text-slate-200">
                {{ t.contact_name || '—' }}
              </td>
              <td
                class="py-2 text-slate-600 dark:text-slate-300 truncate max-w-xs"
              >
                {{ t.objective }}
              </td>
              <td class="py-2 text-slate-500 dark:text-slate-400">
                {{ formatDate(t.scheduled_for) }}
              </td>
              <td class="py-2 text-slate-500 dark:text-slate-400">
                {{ t.attempt_count }}/{{ t.max_attempts }}
              </td>
            </tr>
          </tbody>
        </table>
        <p v-else class="text-sm text-slate-400 py-4 text-center">
          No hay seguimientos vencidos. 🎉
        </p>
      </div>
    </div>
  </div>
</template>

<style lang="scss" scoped>
// vue-chartjs envuelve el canvas en un div propio sin altura → chart.js cae a su
// default de 400px (gráficos gigantes que se solapan). Fijamos la altura en el
// wrapper (.chart-box + h-XX de Tailwind) y forzamos ese div interno a 100%.
.chart-box {
  ::v-deep > div {
    position: relative;
    height: 100% !important;
  }
}
</style>
