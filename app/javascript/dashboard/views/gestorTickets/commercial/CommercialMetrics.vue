<!--
  @tickets_cases — Plan-Clase-Comercial F5 · Plan-Metricas-Comercial
  Métricas del embudo comercial (GET /api/v2/.../case_reports/pipeline), en cuatro
  pestañas por la pregunta que responde cada una:
    ¿Cómo vamos? (OverviewTab) · Dinero en juego (MoneyTab, con el embudo) ·
    Mes a mes (MonthlyTab, a pedido) · ¿Por qué perdemos? (LossesTab).
  Tipo, vendedor y equipo son de toda la página. El tiempo depende de la pestaña:
  el período de calendario (Este mes, Mes pasado…) solo aplica a «¿Cómo vamos?» y
  «¿Por qué perdemos?» (lo decidido, por fecha de cierre); «Dinero en juego» es
  foto de hoy (su filtro de tiempo es el cierre estimado) y «Mes a mes» trae su
  propia ventana. Montos SIEMPRE por moneda.
  Este componente solo arma la página y pide el reporte que comparten
  «¿Cómo vamos?», «Dinero en juego» y «¿Por qué perdemos?».
-->
<script>
import { mapGetters } from 'vuex';
import CaseReportsAPI from 'dashboard/api/caseReports';
import CaseClassSwitcher from '../CaseClassSwitcher.vue'; // Plan-Casos E1
import CaseTypeSelect from '../filters/CaseTypeSelect.vue'; // Plan-Casos E1.1
import { loadCaseState, saveCaseState } from 'dashboard/helper/caseClasses';
// Plan-Metricas-Comercial — período de calendario con comparación justa.
import { formatRange, toEpoch } from 'dashboard/helper/caseMetricsPeriod';
import caseMetricsPeriodMixin from 'dashboard/mixins/caseMetricsPeriodMixin';
import CalendarPeriodPicker from '../filters/CalendarPeriodPicker.vue';
import OverviewTab from './metrics/OverviewTab.vue';
import MoneyTab from './metrics/MoneyTab.vue';
import MonthlyTab from './metrics/MonthlyTab.vue';
import LossesTab from './metrics/LossesTab.vue';

const TABS = ['overview', 'money', 'monthly', 'losses'];
// Pestañas guardadas con los nombres anteriores (Generales / Embudo).
const LEGACY_TABS = { general: 'overview', funnel: 'money' };
// Pestañas a las que les aplica el período de arriba (lo decidido).
const PERIOD_TABS = ['overview', 'losses'];

export default {
  name: 'CommercialMetrics',
  components: {
    CaseClassSwitcher,
    CaseTypeSelect,
    CalendarPeriodPicker,
    OverviewTab,
    MoneyTab,
    MonthlyTab,
    LossesTab,
  },
  mixins: [caseMetricsPeriodMixin],
  props: {
    caseClass: { type: String, default: 'commercial' },
  },
  data() {
    return {
      caseTypeId: '',
      assigneeId: '',
      teamId: '', // Plan-Casos E1.3
      tab: 'overview',
      report: null,
      shownRange: null,
      isLoading: false,
    };
  },
  computed: {
    ...mapGetters({
      agents: 'agents/getAgents',
      teams: 'teams/getTeams',
    }),
    tabs() {
      return TABS;
    },
    tabIndex() {
      return Math.max(0, TABS.indexOf(this.tab));
    },
    // Filtros de la página para las pestañas que piden su propio reporte (se
    // recalcula solo si cambian: el rango usa la hora de ese momento).
    baseFilters() {
      return this.filters({
        period: this.period,
        customFrom: this.customFrom,
        customTo: this.customTo,
        caseTypeId: this.caseTypeId,
        assigneeId: this.assigneeId,
        teamId: this.teamId,
      });
    },
    showPeriod() {
      return PERIOD_TABS.includes(this.tab);
    },
    // «1–21 oct» y, en «¿Cómo vamos?», contra qué se compara («1–21 sept»).
    // Se fija al pedir el reporte, para que el texto siempre sea el de esos números.
    rangeLabel() {
      return this.shownRange
        ? formatRange(this.shownRange.from, this.shownRange.to)
        : '';
    },
    compareLabel() {
      return this.shownRange
        ? formatRange(this.shownRange.prevFrom, this.shownRange.prevTo)
        : '';
    },
    summary() {
      return (this.report && this.report.summary) || {};
    },
    isEmpty() {
      const s = this.summary;
      return (
        this.report &&
        !s.open_count &&
        !s.won_count &&
        !s.lost_count &&
        !s.cancelled_count
      );
    },
  },
  mounted() {
    this.$store.dispatch('caseTickets/fetchTypes');
    this.$store.dispatch('agents/get');
    this.$store.dispatch('teams/get');
    // Plan-Casos E1.2 — vuelve con el tipo, período, vendedor y pestaña que dejaste.
    const st = loadCaseState(this.$route.params.accountId, this.caseClass);
    const saved = st.metrics || {};
    this.caseTypeId = st.type ?? '';
    this.restorePeriod(saved);
    this.assigneeId = saved.assigneeId || '';
    this.teamId = saved.teamId || '';
    const tab = LEGACY_TABS[saved.tab] || saved.tab;
    if (TABS.includes(tab)) this.tab = tab;
    this.fetch();
  },
  methods: {
    filters(state = this) {
      const f = {
        caseTypeId: state.caseTypeId || undefined,
        assigneeId: state.assigneeId || undefined,
        teamId: state.teamId || undefined, // E1.3 — la API ya filtra por equipo
      };
      const r = this.periodRangeOf(state);
      if (r) {
        f.from = toEpoch(r.from);
        f.to = toEpoch(r.to);
        f.prevFrom = toEpoch(r.prevFrom);
        f.prevTo = toEpoch(r.prevTo);
      }
      return f;
    },
    persist() {
      saveCaseState(this.$route.params.accountId, this.caseClass, {
        type: this.caseTypeId,
        metrics: {
          ...this.periodState(),
          assigneeId: this.assigneeId,
          teamId: this.teamId,
          tab: this.tab,
        },
      });
    },
    async fetch() {
      this.persist();
      this.isLoading = true;
      try {
        const range = this.periodRangeOf();
        const { data } = await CaseReportsAPI.getPipeline(this.filters());
        this.report = data;
        this.shownRange = range;
      } catch (_e) {
        this.$emitter.emit('newToastMessage', {
          message: this.$t('CASE_TICKETS.COMMERCIAL.METRICS.ERROR'),
          type: 'error',
        });
      } finally {
        this.isLoading = false;
      }
    },
    setTab(index) {
      this.tab = TABS[index] || 'overview';
      this.persist();
    },
    onTypeChange(id) {
      this.caseTypeId = id;
      this.fetch();
    },
  },
};
</script>

<template>
  <div
    class="flex flex-col flex-1 w-full h-full overflow-hidden bg-slate-25 dark:bg-slate-900"
  >
    <!-- Encabezado + filtros de toda la página + pestañas -->
    <div
      class="flex flex-col flex-shrink-0 gap-3 px-6 pt-4 bg-white border-b dark:bg-slate-900 border-slate-50 dark:border-slate-800/50"
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
          <CalendarPeriodPicker
            v-if="showPeriod"
            :value="period"
            :from="customFrom"
            :to="customTo"
            @input="setPeriod"
            @custom="setCustom"
          />
          <span
            v-else-if="tab === 'money'"
            class="px-2.5 py-1 text-xs font-medium rounded-full bg-slate-100 text-slate-700 dark:bg-slate-800 dark:text-slate-200"
            :title="$t('CASE_TICKETS.COMMERCIAL.METRICS.SNAPSHOT_HINT')"
          >
            {{ $t('CASE_TICKETS.COMMERCIAL.METRICS.SNAPSHOT') }}
          </span>
        </div>
      </div>
      <woot-tabs :index="tabIndex" @change="setTab">
        <woot-tabs-item
          v-for="(key, i) in tabs"
          :key="key"
          :index="i"
          :name="$t(`CASE_TICKETS.COMMERCIAL.METRICS.TABS.${key}`)"
          :show-badge="false"
        />
      </woot-tabs>
    </div>

    <div class="flex flex-col flex-1 gap-4 px-6 py-4 overflow-y-auto">
      <p class="m-0 text-xs text-slate-500 dark:text-slate-400">
        {{ $t(`CASE_TICKETS.COMMERCIAL.METRICS.TAB_HELP.${tab}`) }}
        <template v-if="showPeriod && rangeLabel">
          ·
          <strong class="font-semibold text-slate-700 dark:text-slate-200">
            {{ rangeLabel }}
          </strong>
          <template v-if="tab === 'overview'">
            {{
              $t('CASE_TICKETS.COMMERCIAL.METRICS.COMPARED_WITH', {
                range: compareLabel,
              })
            }}
          </template>
        </template>
      </p>

      <!-- Mes a mes: su propio reporte, a pedido (no espera al general). -->
      <MonthlyTab
        v-if="tab === 'monthly'"
        :base-filters="baseFilters"
        :currencies="(report && report.currencies) || []"
      />
      <p
        v-else-if="isLoading && !report"
        class="m-0 py-12 text-center text-slate-400 dark:text-slate-500"
      >
        {{ $t('CASE_TICKETS.COMMERCIAL.METRICS.LOADING') }}
      </p>
      <p
        v-else-if="isEmpty"
        class="m-0 py-12 text-center text-slate-400 dark:text-slate-500"
      >
        {{ $t('CASE_TICKETS.COMMERCIAL.METRICS.EMPTY') }}
      </p>
      <template v-else-if="report">
        <div :class="isLoading ? 'opacity-60' : ''">
          <OverviewTab
            v-if="tab === 'overview'"
            :report="report"
            :compare-label="compareLabel"
          />
          <MoneyTab
            v-else-if="tab === 'money'"
            :report="report"
            :base-filters="baseFilters"
            :case-class="caseClass"
          />
          <LossesTab v-else :report="report" />
        </div>
      </template>
    </div>
  </div>
</template>
