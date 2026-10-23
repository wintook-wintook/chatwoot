<script>
// feat/licencias (F4) — PESTAÑA «RESUMEN»
// ============================================================================
// Cómo va el negocio de licencias de un vistazo:
//   fila de indicadores (tarjetas nativas ReportMetricCard): de pago, en demo, por vencer
//   en 7/14/30/60 días, vencidas, sin licencia y conversión demo → pago. Cada tarjeta abre
//   la pestaña Cuentas con ese filtro (salvo conversión).
//   vencimientos por semana (60 días) y cuentas activas por plan: barras de una sola serie.
//
// Color de las barras: el woot-600 del tema activo (validado con la guía de visualización:
// pasa luminosidad y contraste ≥ 3:1 en claro y oscuro con el tema por omisión). Los valores
// exactos están en el tooltip y en la tabla de Cuentas.
// Plan: docs/licencias_plan_v1.md §9 (F4)
// ============================================================================
import LicensesAPI from 'dashboard/api/licenses';
import BarChart from 'dashboard/components/widgets/chart/BarChart';
import ReportMetricCard from 'dashboard/routes/dashboard/settings/reports/components/ReportMetricCard.vue';

const WINDOWS = [7, 14, 30, 60];
const FALLBACK_COLOR = '0 144 255';

const barColor = () => {
  const rgb =
    getComputedStyle(document.documentElement)
      .getPropertyValue('--color-woot-600')
      .trim() || FALLBACK_COLOR;
  return `rgb(${rgb.split(/\s+/).join(', ')})`;
};

export default {
  components: { BarChart, ReportMetricCard },
  emits: ['filter'],
  data() {
    return {
      windows: WINDOWS,
      dias: 7,
      summary: null,
      loading: true,
      loadError: false,
    };
  },
  computed: {
    kpis() {
      return (this.summary && this.summary.kpis) || null;
    },
    cards() {
      if (!this.kpis) return [];
      const k = this.kpis;
      return [
        { key: 'PAID', value: k.paid, estado: 'vigente' },
        { key: 'DEMO', value: k.demo, estado: 'demo' },
        { key: 'EXPIRING', value: k.expiring[this.dias], estado: 'por_vencer' },
        { key: 'EXPIRED', value: k.expired, estado: 'vencida' },
        { key: 'WITHOUT', value: k.without_license, estado: 'sin_licencia' },
        {
          key: 'CONVERSION',
          value: `${k.conversion.rate}%`,
          estado: null,
          args: k.conversion,
        },
      ];
    },
    chartOptions() {
      return {
        scales: {
          xAxes: [{ gridLines: { drawOnChartArea: false } }],
          yAxes: [
            {
              ticks: { beginAtZero: true, precision: 0 },
              gridLines: { drawOnChartArea: false },
            },
          ],
        },
      };
    },
    expirationsChart() {
      const semanas = (this.summary && this.summary.expirations) || [];
      return {
        labels: semanas.map(s => this.weekLabel(s.week_start)),
        datasets: [
          {
            label: this.t('SUMMARY.EXPIRATIONS_SERIES'),
            data: semanas.map(s => s.count),
            backgroundColor: barColor(),
            barPercentage: 0.6,
          },
        ],
      };
    },
    plansChart() {
      const planes = (this.summary && this.summary.by_plan) || [];
      return {
        labels: planes.map(p => p.name),
        datasets: [
          {
            label: this.t('SUMMARY.BY_PLAN_SERIES'),
            data: planes.map(p => p.count),
            backgroundColor: barColor(),
            barPercentage: 0.6,
          },
        ],
      };
    },
    hasPlans() {
      return Boolean(this.summary && this.summary.by_plan.length);
    },
  },
  mounted() {
    this.fetch();
  },
  methods: {
    t(key, args) {
      return this.$t(`LICENSES.${key}`, args);
    },
    async fetch() {
      this.loading = true;
      this.loadError = false;
      try {
        const { data } = await LicensesAPI.getSummary();
        this.summary = data;
      } catch (error) {
        this.loadError = true;
      } finally {
        this.loading = false;
      }
    },
    cardLabel(card) {
      return card.key === 'EXPIRING'
        ? this.t('SUMMARY.CARDS.EXPIRING', { days: this.dias })
        : this.t(`SUMMARY.CARDS.${card.key}`);
    },
    cardInfo(card) {
      return this.t(`SUMMARY.INFO.${card.key}`, card.args || {});
    },
    open(card) {
      if (!card.estado) return;
      this.$emit('filter', { estado: card.estado, dias: this.dias });
    },
    weekLabel(iso) {
      return new Date(`${iso}T12:00:00`).toLocaleDateString(this.$i18n.locale, {
        day: 'numeric',
        month: 'short',
      });
    },
  },
};
</script>

<template>
  <div class="flex flex-col flex-1 min-h-0 gap-6 overflow-auto">
    <p v-if="loadError" class="text-sm text-red-600 dark:text-red-400">
      {{ t('LOAD_ERROR') }}
    </p>
    <template v-else-if="kpis">
      <div class="flex flex-wrap items-center gap-2">
        <span class="text-sm text-slate-600 dark:text-slate-300">
          {{ t('SUMMARY.WINDOW') }}
        </span>
        <woot-button
          v-for="ventana in windows"
          :key="ventana"
          size="small"
          :variant="ventana === dias ? 'smooth' : 'clear'"
          :color-scheme="ventana === dias ? 'primary' : 'secondary'"
          @click="dias = ventana"
        >
          {{ t('SUMMARY.DAYS', { count: ventana }) }}
        </woot-button>
      </div>

      <div
        class="grid grid-cols-2 gap-px overflow-hidden border rounded-lg md:grid-cols-3 xl:grid-cols-6 border-slate-100 dark:border-slate-700 bg-slate-100 dark:bg-slate-700"
      >
        <button
          v-for="card in cards"
          :key="card.key"
          type="button"
          class="text-left bg-white dark:bg-slate-900"
          :class="
            card.estado
              ? 'hover:bg-slate-25 dark:hover:bg-slate-800'
              : 'cursor-default'
          "
          @click="open(card)"
        >
          <ReportMetricCard
            :label="cardLabel(card)"
            :value="String(card.value)"
            :info-text="cardInfo(card)"
          />
        </button>
      </div>

      <div class="grid grid-cols-1 gap-6 lg:grid-cols-2">
        <section
          class="p-4 border rounded-lg border-slate-100 dark:border-slate-700"
        >
          <h3
            class="mb-1 text-sm font-semibold text-slate-800 dark:text-slate-100"
          >
            {{ t('SUMMARY.EXPIRATIONS_TITLE') }}
          </h3>
          <p class="mb-3 text-xs text-slate-500 dark:text-slate-400">
            {{ t('SUMMARY.EXPIRATIONS_HINT') }}
          </p>
          <div class="h-56">
            <BarChart
              :key="`exp-${summary.expirations.length}`"
              :collection="expirationsChart"
              :chart-options="chartOptions"
            />
          </div>
        </section>
        <section
          class="p-4 border rounded-lg border-slate-100 dark:border-slate-700"
        >
          <h3
            class="mb-1 text-sm font-semibold text-slate-800 dark:text-slate-100"
          >
            {{ t('SUMMARY.BY_PLAN_TITLE') }}
          </h3>
          <p class="mb-3 text-xs text-slate-500 dark:text-slate-400">
            {{ t('SUMMARY.BY_PLAN_HINT') }}
          </p>
          <div v-if="hasPlans" class="h-56">
            <BarChart
              :key="`plan-${summary.by_plan.length}`"
              :collection="plansChart"
              :chart-options="chartOptions"
            />
          </div>
          <p v-else class="text-sm text-slate-500 dark:text-slate-400">
            {{ t('SUMMARY.BY_PLAN_EMPTY') }}
          </p>
        </section>
      </div>
    </template>
  </div>
</template>
