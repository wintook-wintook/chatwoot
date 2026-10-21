<!--
  @tickets_cases — «Resumen del negocio» (para el dueño). Todo el negocio en una
  pantalla que se lee en 30 segundos (GET case_reports/business_summary):
    · arriba, «Lo que necesita tu atención» (máx. 5, lo más grave primero; cada
      uno abre la Lista de su clase ya filtrada);
    · «Explícame la semana» con IA (explica, no decide; usa solo estas cifras);
    · un bloque por pregunta: ventas, soporte, órdenes, proyectos, conversaciones
      (cifras de «Informes → Conversaciones») y personas;
    · «Analizar conversaciones» con IA, a pedido (CalcGate: cuesta tokens; muestra
      de 150 del período) — temas, clientes molestos, ventas que se escapan, quejas.
  Una clase que la cuenta no usa no aparece. Período de calendario (como el resto
  de Números) con su comparación justa. Solo administradores y autorizados (el
  backend responde 403 a los demás). Vive en Casos y en Informes (`embedded`: el
  marco de Informes ya pone el título).
-->
<script>
import CaseReportsAPI from 'dashboard/api/caseReports';
import { formatMoney, moneyList } from 'dashboard/helper/caseCommercial';
import {
  ARROWS,
  compareMoney,
  compareNumbers,
} from 'dashboard/helper/caseMetricsDelta';
import { formatRange, toEpoch } from 'dashboard/helper/caseMetricsPeriod';
import caseMetricsPeriodMixin from 'dashboard/mixins/caseMetricsPeriodMixin';
import {
  CLASS_VIEW_ROUTES,
  loadCaseState,
  saveCaseState,
} from 'dashboard/helper/caseClasses';
import {
  DEFAULT_COMMERCIAL_RESULT,
  DEFAULT_WORK_ORDER_STAGE,
  emptyFineFilters,
  hasStages,
} from 'dashboard/helper/caseFilters';
import CalendarPeriodPicker from '../filters/CalendarPeriodPicker.vue';
import KpiTile from '../commercial/metrics/KpiTile.vue';
import CalcGate from '../commercial/metrics/CalcGate.vue';
import {
  filtersKey,
  loadCalc,
  saveCalc,
} from 'dashboard/helper/caseMetricsCalc';

const STATE_KEY = 'summary';
const T = 'CASE_TICKETS.BUSINESS_SUMMARY';
// Lo más grave en rojo; lo que es limpieza (pronóstico viejo) en ámbar.
const ATTENTION_TONE = {
  close_overdue:
    'bg-amber-50 border-amber-200 text-amber-900 dark:bg-amber-900/20 dark:border-amber-800 dark:text-amber-200',
};
const DEFAULT_TONE =
  'bg-red-50 border-red-200 text-red-900 dark:bg-red-900/20 dark:border-red-800 dark:text-red-200';

export default {
  name: 'BusinessSummary',
  components: { CalendarPeriodPicker, KpiTile, CalcGate },
  mixins: [caseMetricsPeriodMixin],
  props: {
    // Dentro de Informes: su marco ya pone el título.
    embedded: { type: Boolean, default: false },
  },
  data() {
    return {
      report: null,
      shownRange: null,
      isLoading: false,
      forbidden: false,
      story: null,
      storyLoading: false,
      analysisEntry: null,
      analysisLoading: false,
    };
  },
  computed: {
    accountId() {
      return this.$route.params.accountId;
    },
    sales() {
      return this.report && this.report.sales;
    },
    support() {
      return this.report && this.report.support;
    },
    workOrders() {
      return this.report && this.report.work_orders;
    },
    projects() {
      return this.report && this.report.projects;
    },
    people() {
      return (this.report && this.report.people) || {};
    },
    attention() {
      return (this.report && this.report.attention) || [];
    },
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
    previousSales() {
      return (this.sales && this.sales.previous) || null;
    },
    wonDelta() {
      if (!this.previousSales) return null;
      const money = compareMoney(
        this.sales.won_value,
        this.previousSales.won_value
      );
      if (money)
        return this.delta(money, formatMoney(money.diff, money.currency));
      const count = compareNumbers(
        this.sales.won_count,
        this.previousSales.won_count
      );
      return this.delta(count, count && String(count.diff));
    },
    rateDelta() {
      if (!this.previousSales) return null;
      const d = compareNumbers(
        this.sales.win_rate,
        this.previousSales.win_rate
      );
      return this.delta(d, d && this.t('POINTS', { n: d.diff }));
    },
    conversations() {
      return this.report && this.report.conversations;
    },
    conversationsPrev() {
      return (this.conversations && this.conversations.previous) || null;
    },
    newConversationsDelta() {
      if (!this.conversationsPrev) return null;
      const d = compareNumbers(
        this.conversations.new_count,
        this.conversationsPrev.new_count
      );
      return this.delta(d, d && String(d.diff), { neutral: true });
    },
    chatResponseDelta() {
      if (!this.conversationsPrev) return null;
      const d = compareNumbers(
        this.conversations.avg_first_response_seconds,
        this.conversationsPrev.avg_first_response_seconds,
        { lowerIsBetter: true }
      );
      return this.delta(d, d && this.minutes(d.diff / 60));
    },
    chatResolutionDelta() {
      if (!this.conversationsPrev) return null;
      const d = compareNumbers(
        this.conversations.avg_resolution_seconds,
        this.conversationsPrev.avg_resolution_seconds,
        { lowerIsBetter: true }
      );
      return this.delta(d, d && this.minutes(d.diff / 60));
    },
    // Análisis con IA: vale para el período con que se hizo (misma llave, mismo día).
    analysisKey() {
      const r = this.filters();
      return filtersKey({ from: r.from, to: r.to });
    },
    analysis() {
      return this.analysisEntry ? this.analysisEntry.data : null;
    },
    analysisChanged() {
      return (
        !!this.analysisEntry && this.analysisEntry.key !== this.analysisKey
      );
    },
    responseDelta() {
      const s = this.support;
      if (!s) return null;
      const d = compareNumbers(
        s.avg_first_response_minutes,
        s.previous_avg_first_response_minutes,
        { lowerIsBetter: true }
      );
      return this.delta(d, d && this.minutes(d.diff));
    },
  },
  mounted() {
    this.restorePeriod(loadCaseState(this.accountId, STATE_KEY));
    this.analysisEntry = loadCalc(this.accountId, 'conversation_analysis');
    this.fetch();
  },
  methods: {
    t(key, params) {
      return this.$t(`${T}.${key}`, params);
    },
    filters() {
      const r = this.periodRangeOf();
      if (!r) return {};
      return {
        from: toEpoch(r.from),
        to: toEpoch(r.to),
        prevFrom: toEpoch(r.prevFrom),
        prevTo: toEpoch(r.prevTo),
      };
    },
    async fetch() {
      saveCaseState(this.accountId, STATE_KEY, this.periodState());
      this.isLoading = true;
      this.story = null;
      try {
        const range = this.periodRangeOf();
        const { data } = await CaseReportsAPI.getBusinessSummary(
          this.filters()
        );
        this.report = data;
        this.shownRange = range;
      } catch (e) {
        if (e.response && e.response.status === 403) this.forbidden = true;
        else
          this.$emitter.emit('newToastMessage', {
            message: this.t('ERROR'),
            type: 'error',
          });
      } finally {
        this.isLoading = false;
      }
    },
    async explain() {
      this.storyLoading = true;
      try {
        const { data } = await CaseReportsAPI.explainBusinessSummary({
          ...this.filters(),
          periodLabel: this.rangeLabel,
          compareLabel: this.compareLabel,
        });
        this.story = data.story;
      } catch (e) {
        this.$emitter.emit('newToastMessage', {
          message:
            (e.response && e.response.data && e.response.data.error) ||
            this.t('AI.ERROR'),
          type: 'error',
        });
      } finally {
        this.storyLoading = false;
      }
    },
    async analyze() {
      this.analysisLoading = true;
      try {
        const { data } = await CaseReportsAPI.analyzeConversations(
          this.filters()
        );
        this.analysisEntry = saveCalc(
          this.accountId,
          'conversation_analysis',
          this.analysisKey,
          data.analysis
        );
      } catch (e) {
        this.$emitter.emit('newToastMessage', {
          message:
            (e.response && e.response.data && e.response.data.error) ||
            this.t('ANALYSIS.ERROR'),
          type: 'error',
        });
      } finally {
        this.analysisLoading = false;
      }
    },
    openConversation(displayId) {
      this.$router.push({
        name: 'inbox_conversation',
        params: { accountId: this.accountId, conversation_id: displayId },
      });
    },
    channelLabel(channel) {
      const key = `${T}.CHANNELS.${channel}`;
      return this.$te(key) ? this.$t(key) : channel;
    },
    seconds(value) {
      return value === null || value === undefined
        ? '—'
        : this.minutes(value / 60);
    },
    money(values, field) {
      return moneyList(values, field);
    },
    countOf(values) {
      return (values || []).reduce((a, v) => a + (v.count || 0), 0);
    },
    pct(value) {
      return value === null || value === undefined ? '—' : `${value}%`;
    },
    minutes(value) {
      if (value === null || value === undefined) return '—';
      const m = Math.round(value);
      if (m < 60) return this.t('MINUTES', { n: m });
      return this.t('HOURS', { h: Math.floor(m / 60), m: m % 60 });
    },
    csat(c) {
      return c && c.avg !== null && c.avg !== undefined ? `${c.avg} / 5` : '—';
    },
    // { dir, good } + texto → { text, good } para KpiTile («▲ $500 vs 1–21 sept»).
    // `neutral`: subir o bajar no es bueno ni malo (p. ej. conversaciones nuevas).
    delta(d, amount, { neutral = false } = {}) {
      if (!d) return null;
      const range = this.compareLabel;
      if (d.dir === 'same')
        return { text: this.t('SAME', { range }), good: null };
      return {
        text: `${ARROWS[d.dir]} ${amount} ${this.t('VS', { range })}`,
        good: neutral ? null : d.good,
      };
    },
    attentionTone(item) {
      return ATTENTION_TONE[item.key] || DEFAULT_TONE;
    },
    attentionText(item) {
      return this.t(`ATTENTION.${item.key}`, {
        count: item.count,
        amount: item.values ? this.money(item.values) : '',
      });
    },
    // Abre la Lista de la clase ya filtrada: todos, abiertos, el aviso de
    // vencidos y, en promesas, «Solo comprometidas». Se deja en el estado que la
    // Lista restaura al abrir (como si el dueño lo hubiera elegido ahí).
    openAttention(item) {
      // Conversaciones sin atender: la vista de Chatwoot que ya las filtra.
      if (item.case_class === 'conversations') {
        this.$router.push({
          name: 'conversation_unattended',
          params: { accountId: this.accountId },
        });
        return;
      }
      const caseClass = item.case_class;
      const st = loadCaseState(this.accountId, caseClass);
      const list = { ...(st.list || {}), status: 'pending', currentPage: 1 };
      list.viewId = '';
      if (caseClass === 'commercial') list.outcome = DEFAULT_COMMERCIAL_RESULT;
      list.stage = hasStages(caseClass) ? DEFAULT_WORK_ORDER_STAGE : '';
      saveCaseState(this.accountId, caseClass, {
        scope: 'all',
        sla: true,
        committed: item.key === 'promises_overdue',
        search: '',
        type: '',
        fine: emptyFineFilters(),
        list,
      });
      this.$router.push({
        name: CLASS_VIEW_ROUTES.list,
        params: { accountId: this.accountId, caseClass },
      });
    },
    openMetrics(caseClass) {
      this.$router.push({
        name: CLASS_VIEW_ROUTES.metrics,
        params: { accountId: this.accountId, caseClass },
      });
    },
  },
};
</script>

<template>
  <div
    class="flex flex-col flex-1 w-full h-full overflow-hidden bg-slate-25 dark:bg-slate-900"
  >
    <div
      class="flex flex-wrap items-center flex-shrink-0 gap-3 px-6 py-4 bg-white border-b dark:bg-slate-900 border-slate-50 dark:border-slate-800/50"
    >
      <div class="flex flex-col">
        <h1
          v-if="!embedded"
          class="m-0 text-xl font-bold text-slate-800 dark:text-slate-100"
        >
          {{ t('TITLE') }}
        </h1>
        <p
          v-if="rangeLabel"
          class="m-0 text-xs text-slate-500 dark:text-slate-400"
        >
          <strong class="font-semibold text-slate-700 dark:text-slate-200">
            {{ rangeLabel }}
          </strong>
          {{ t('COMPARED_WITH', { range: compareLabel }) }}
        </p>
      </div>
      <div class="ml-auto">
        <CalendarPeriodPicker
          :value="period"
          :from="customFrom"
          :to="customTo"
          @input="setPeriod"
          @custom="setCustom"
        />
      </div>
    </div>

    <div class="flex flex-col flex-1 gap-4 px-6 py-4 overflow-y-auto">
      <p
        v-if="forbidden"
        class="m-0 py-12 text-center text-slate-500 dark:text-slate-400"
      >
        {{ t('FORBIDDEN') }}
      </p>
      <p
        v-else-if="isLoading && !report"
        class="m-0 py-12 text-center text-slate-400 dark:text-slate-500"
      >
        {{ t('LOADING') }}
      </p>

      <template v-else-if="report">
        <div class="flex flex-col gap-4" :class="isLoading ? 'opacity-60' : ''">
          <!-- Lo que necesita tu atención -->
          <section
            class="p-4 bg-white border rounded-lg dark:bg-slate-800 border-slate-75 dark:border-slate-700"
          >
            <h2
              class="m-0 mb-3 text-sm font-semibold text-slate-800 dark:text-slate-100"
            >
              {{ t('ATTENTION_TITLE') }}
            </h2>
            <p
              v-if="!attention.length"
              class="m-0 text-sm text-green-700 dark:text-green-400"
            >
              {{ t('ATTENTION_NONE') }}
            </p>
            <ul v-else class="flex flex-col gap-2 p-0 m-0 list-none">
              <li
                v-for="item in attention"
                :key="item.key"
                class="flex flex-wrap items-center gap-2 px-3 py-2 text-sm border rounded-lg"
                :class="attentionTone(item)"
              >
                <fluent-icon icon="warning" size="14" />
                <span class="font-medium">{{ attentionText(item) }}</span>
                <button
                  type="button"
                  class="ml-auto text-xs font-semibold underline hover:no-underline"
                  @click="openAttention(item)"
                >
                  {{ t('SEE') }}
                </button>
              </li>
            </ul>
          </section>

          <!-- Explícame la semana (IA) -->
          <section
            class="p-4 bg-white border rounded-lg dark:bg-slate-800 border-slate-75 dark:border-slate-700"
          >
            <div class="flex flex-wrap items-center gap-2">
              <h2
                class="m-0 text-sm font-semibold text-slate-800 dark:text-slate-100"
              >
                {{ t('AI.TITLE') }}
              </h2>
              <woot-button
                class="ml-auto"
                size="small"
                variant="smooth"
                icon="wand"
                :is-loading="storyLoading"
                @click="explain"
              >
                {{ story ? t('AI.AGAIN') : t('AI.EXPLAIN') }}
              </woot-button>
            </div>
            <p
              v-if="!story"
              class="m-0 mt-2 text-xs text-slate-500 dark:text-slate-400"
            >
              {{ t('AI.HINT') }}
            </p>
            <div v-else class="flex flex-col gap-3 mt-3">
              <p
                class="m-0 text-base font-semibold text-slate-800 dark:text-slate-100"
              >
                {{ story.headline }}
              </p>
              <div class="grid gap-3 md:grid-cols-3">
                <div
                  v-for="part in ['good', 'watch', 'today']"
                  :key="part"
                  class="flex flex-col gap-1"
                >
                  <p
                    class="m-0 text-xs font-semibold uppercase text-slate-500 dark:text-slate-400"
                  >
                    {{ t(`AI.${part}`) }}
                  </p>
                  <ul
                    class="pl-4 m-0 text-sm text-slate-700 dark:text-slate-200"
                  >
                    <li v-for="(line, i) in story[part]" :key="i">
                      {{ line }}
                    </li>
                    <li
                      v-if="!story[part].length"
                      class="list-none -ml-4 text-slate-400"
                    >
                      —
                    </li>
                  </ul>
                </div>
              </div>
              <p class="m-0 text-[11px] text-slate-400 dark:text-slate-500">
                {{ t('AI.DISCLAIMER') }}
              </p>
            </div>
          </section>

          <!-- Ventas -->
          <section v-if="sales" class="flex flex-col gap-2">
            <div class="flex items-center gap-2">
              <h2
                class="m-0 text-sm font-semibold text-slate-800 dark:text-slate-100"
              >
                {{ t('SALES.TITLE') }}
              </h2>
              <button
                type="button"
                class="ml-auto text-xs text-woot-600 dark:text-woot-300 hover:underline"
                @click="openMetrics('commercial')"
              >
                {{ t('MORE') }}
              </button>
            </div>
            <div
              class="grid gap-3 grid-cols-[repeat(auto-fit,minmax(190px,1fr))]"
            >
              <KpiTile
                :label="t('SALES.WON')"
                :value="money(sales.won_value)"
                :sub="t('SALES.WON_SUB', { count: sales.won_count || 0 })"
                :delta="wonDelta"
              />
              <KpiTile
                :label="t('SALES.WIN_RATE')"
                :value="pct(sales.win_rate)"
                :delta="rateDelta"
              />
              <KpiTile
                :label="t('SALES.COMMITTED_WEEK')"
                :value="money(sales.committed_week)"
                :sub="
                  t('SALES.COMMITTED_SUB', {
                    count: countOf(sales.committed_week),
                  })
                "
              />
              <KpiTile
                :label="t('SALES.COMMITTED_MONTH')"
                :value="money(sales.committed_month)"
                :sub="
                  t('SALES.OVERDUE_SUB', {
                    count: countOf(sales.committed_overdue),
                  })
                "
              />
              <KpiTile
                :label="t('SALES.OPEN')"
                :value="money(sales.open_value)"
                :sub="
                  t('SALES.OPEN_SUB', {
                    count: sales.open_count || 0,
                    weighted: money(sales.open_value, 'weighted'),
                  })
                "
              />
            </div>
          </section>

          <!-- Soporte -->
          <section v-if="support" class="flex flex-col gap-2">
            <div class="flex items-center gap-2">
              <h2
                class="m-0 text-sm font-semibold text-slate-800 dark:text-slate-100"
              >
                {{ t('SUPPORT.TITLE') }}
              </h2>
              <button
                type="button"
                class="ml-auto text-xs text-woot-600 dark:text-woot-300 hover:underline"
                @click="openMetrics('support')"
              >
                {{ t('MORE') }}
              </button>
            </div>
            <div
              class="grid gap-3 grid-cols-[repeat(auto-fit,minmax(190px,1fr))]"
            >
              <KpiTile
                :label="t('SUPPORT.OPEN')"
                :value="support.open_count"
                :sub="
                  t('SUPPORT.CREATED_SUB', { count: support.created_count })
                "
              />
              <KpiTile
                :label="t('SUPPORT.SLA_OVERDUE')"
                :value="support.sla_overdue"
                :sub="t('SUPPORT.AT_RISK_SUB', { count: support.sla_at_risk })"
              />
              <KpiTile
                :label="t('SUPPORT.FIRST_RESPONSE')"
                :value="minutes(support.avg_first_response_minutes)"
                :delta="responseDelta"
              />
              <KpiTile
                :label="t('SUPPORT.CSAT')"
                :value="csat(support.csat)"
                :sub="t('SUPPORT.CSAT_SUB', { count: support.csat.count })"
              />
            </div>
          </section>

          <!-- Órdenes de trabajo -->
          <section v-if="workOrders" class="flex flex-col gap-2">
            <div class="flex items-center gap-2">
              <h2
                class="m-0 text-sm font-semibold text-slate-800 dark:text-slate-100"
              >
                {{ t('WORK_ORDERS.TITLE') }}
              </h2>
              <button
                type="button"
                class="ml-auto text-xs text-woot-600 dark:text-woot-300 hover:underline"
                @click="openMetrics('work_order')"
              >
                {{ t('MORE') }}
              </button>
            </div>
            <div
              class="grid gap-3 grid-cols-[repeat(auto-fit,minmax(190px,1fr))]"
            >
              <KpiTile
                :label="t('WORK_ORDERS.OPEN')"
                :value="workOrders.open_count"
                :sub="
                  t('WORK_ORDERS.TO_SCHEDULE_SUB', {
                    count: workOrders.to_schedule_count,
                  })
                "
              />
              <KpiTile
                :label="t('WORK_ORDERS.VISITS_OVERDUE')"
                :value="workOrders.overdue_visits_count"
              />
              <KpiTile
                :label="t('WORK_ORDERS.ON_TIME')"
                :value="pct(workOrders.on_time_rate)"
                :sub="
                  t('WORK_ORDERS.FINISHED_SUB', {
                    count: workOrders.finished_count,
                  })
                "
              />
              <KpiTile
                :label="t('WORK_ORDERS.SIGNOFF')"
                :value="workOrders.awaiting_signoff_count"
              />
            </div>
          </section>

          <!-- Proyectos -->
          <section v-if="projects" class="flex flex-col gap-2">
            <div class="flex items-center gap-2">
              <h2
                class="m-0 text-sm font-semibold text-slate-800 dark:text-slate-100"
              >
                {{ t('PROJECTS.TITLE') }}
              </h2>
              <button
                type="button"
                class="ml-auto text-xs text-woot-600 dark:text-woot-300 hover:underline"
                @click="openMetrics('project')"
              >
                {{ t('MORE') }}
              </button>
            </div>
            <div
              class="grid gap-3 grid-cols-[repeat(auto-fit,minmax(190px,1fr))]"
            >
              <KpiTile
                :label="t('PROJECTS.OPEN')"
                :value="projects.open_count"
              />
              <KpiTile
                :label="t('PROJECTS.LATE')"
                :value="projects.late_count"
                :sub="
                  t('PROJECTS.MILESTONES_SUB', {
                    count: projects.overdue_milestones_count,
                  })
                "
              />
              <KpiTile
                :label="t('PROJECTS.AT_RISK')"
                :value="projects.at_risk_count"
              />
              <KpiTile
                :label="t('PROJECTS.OVER_BUDGET')"
                :value="projects.over_budget_count"
              />
            </div>
          </section>

          <!-- Conversaciones (cifras de Informes → Conversaciones) -->
          <section v-if="conversations" class="flex flex-col gap-2">
            <h2
              class="m-0 text-sm font-semibold text-slate-800 dark:text-slate-100"
            >
              {{ t('CONVERSATIONS.TITLE') }}
            </h2>
            <div
              class="grid gap-3 grid-cols-[repeat(auto-fit,minmax(190px,1fr))]"
            >
              <KpiTile
                :label="t('CONVERSATIONS.NEW')"
                :value="conversations.new_count"
                :sub="
                  t('CONVERSATIONS.RESOLVED_SUB', {
                    count: conversations.resolved_count,
                  })
                "
                :delta="newConversationsDelta"
              />
              <KpiTile
                :label="t('CONVERSATIONS.UNATTENDED')"
                :value="conversations.now.unattended"
                :sub="
                  t('CONVERSATIONS.OPEN_SUB', {
                    open: conversations.now.open,
                    unassigned: conversations.now.unassigned || 0,
                  })
                "
              />
              <KpiTile
                :label="t('CONVERSATIONS.FIRST_RESPONSE')"
                :value="seconds(conversations.avg_first_response_seconds)"
                :delta="chatResponseDelta"
              />
              <KpiTile
                :label="t('CONVERSATIONS.RESOLUTION')"
                :value="seconds(conversations.avg_resolution_seconds)"
                :delta="chatResolutionDelta"
              />
              <KpiTile
                :label="t('CONVERSATIONS.CSAT')"
                :value="csat(conversations.csat)"
                :sub="
                  t('SUPPORT.CSAT_SUB', { count: conversations.csat.count })
                "
              />
            </div>
            <div class="grid gap-3 md:grid-cols-2">
              <div
                class="p-4 bg-white border rounded-lg dark:bg-slate-800 border-slate-75 dark:border-slate-700"
              >
                <h3
                  class="m-0 mb-2 text-xs font-semibold uppercase text-slate-500 dark:text-slate-400"
                >
                  {{ t('CONVERSATIONS.BY_CHANNEL') }}
                </h3>
                <p
                  v-if="!conversations.by_channel.length"
                  class="m-0 text-sm text-slate-400 dark:text-slate-500"
                >
                  {{ t('CONVERSATIONS.NONE') }}
                </p>
                <ul
                  v-else
                  class="p-0 m-0 text-sm list-none text-slate-700 dark:text-slate-200"
                >
                  <li
                    v-for="c in conversations.by_channel"
                    :key="c.channel"
                    class="flex justify-between py-0.5"
                  >
                    <span>{{ channelLabel(c.channel) }}</span>
                    <strong class="tabular-nums">{{ c.count }}</strong>
                  </li>
                </ul>
              </div>
              <div
                class="p-4 bg-white border rounded-lg dark:bg-slate-800 border-slate-75 dark:border-slate-700"
              >
                <h3
                  class="m-0 mb-2 text-xs font-semibold uppercase text-slate-500 dark:text-slate-400"
                >
                  {{ t('CONVERSATIONS.TOP_LABELS') }}
                </h3>
                <p
                  v-if="!conversations.top_labels.length"
                  class="m-0 text-sm text-slate-400 dark:text-slate-500"
                >
                  {{ t('CONVERSATIONS.NO_LABELS') }}
                </p>
                <ul
                  v-else
                  class="p-0 m-0 text-sm list-none text-slate-700 dark:text-slate-200"
                >
                  <li
                    v-for="l in conversations.top_labels"
                    :key="l.label"
                    class="flex justify-between py-0.5"
                  >
                    <span>{{ l.label }}</span>
                    <strong class="tabular-nums">{{ l.count }}</strong>
                  </li>
                </ul>
              </div>
            </div>

            <!-- Análisis con IA, a pedido -->
            <CalcGate
              :title="t('ANALYSIS.TITLE')"
              :description="t('ANALYSIS.DESCRIPTION')"
              :calculated-at="analysisEntry ? analysisEntry.at : null"
              :loading="analysisLoading"
              :filters-changed="analysisChanged"
              @calculate="analyze"
            >
              <p
                v-if="analysis && !analysis.sample_size"
                class="m-0 text-sm text-slate-500 dark:text-slate-400"
              >
                {{ t('ANALYSIS.EMPTY') }}
              </p>
              <div v-else-if="analysis" class="flex flex-col gap-3">
                <p class="m-0 text-xs text-slate-500 dark:text-slate-400">
                  {{ t('ANALYSIS.SAMPLE', { count: analysis.sample_size }) }}
                </p>
                <div class="grid gap-3 md:grid-cols-2">
                  <div
                    v-for="part in ['topics', 'complaints']"
                    :key="part"
                    class="flex flex-col gap-1"
                  >
                    <p
                      class="m-0 text-xs font-semibold uppercase text-slate-500 dark:text-slate-400"
                    >
                      {{ t(`ANALYSIS.${part}`) }}
                    </p>
                    <p
                      v-if="!analysis[part].length"
                      class="m-0 text-sm text-slate-400"
                    >
                      —
                    </p>
                    <ul
                      v-else
                      class="p-0 m-0 text-sm list-none text-slate-700 dark:text-slate-200"
                    >
                      <li
                        v-for="g in analysis[part]"
                        :key="g.label"
                        class="py-0.5"
                      >
                        <strong>{{ g.label }}</strong>
                        <span
                          v-if="g.count"
                          class="text-slate-500 dark:text-slate-400"
                        >
                          · {{ t('ANALYSIS.COUNT', { count: g.count }) }}
                        </span>
                        <button
                          v-for="id in g.examples"
                          :key="id"
                          type="button"
                          class="ml-1 text-xs text-woot-600 dark:text-woot-300 hover:underline"
                          @click="openConversation(id)"
                        >
                          {{ `#${id}` }}
                        </button>
                      </li>
                    </ul>
                  </div>
                  <div
                    v-for="part in ['lost_sales', 'upset']"
                    :key="part"
                    class="flex flex-col gap-1"
                  >
                    <p
                      class="m-0 text-xs font-semibold uppercase text-slate-500 dark:text-slate-400"
                    >
                      {{ t(`ANALYSIS.${part}`) }}
                    </p>
                    <p
                      v-if="!analysis[part].length"
                      class="m-0 text-sm text-slate-400"
                    >
                      —
                    </p>
                    <ul
                      v-else
                      class="p-0 m-0 text-sm list-none text-slate-700 dark:text-slate-200"
                    >
                      <li
                        v-for="item in analysis[part]"
                        :key="item.conversation"
                        class="py-0.5"
                      >
                        <button
                          type="button"
                          class="font-mono text-xs font-semibold text-woot-600 dark:text-woot-300 hover:underline"
                          @click="openConversation(item.conversation)"
                        >
                          {{ `#${item.conversation}` }}
                        </button>
                        {{ item.why }}
                      </li>
                    </ul>
                  </div>
                </div>
                <p class="m-0 text-[11px] text-slate-400 dark:text-slate-500">
                  {{ t('ANALYSIS.DISCLAIMER') }}
                </p>
              </div>
            </CalcGate>
          </section>

          <!-- Personas -->
          <section class="grid gap-3 md:grid-cols-2">
            <div
              v-if="sales"
              class="p-4 bg-white border rounded-lg dark:bg-slate-800 border-slate-75 dark:border-slate-700"
            >
              <h2
                class="m-0 mb-2 text-sm font-semibold text-slate-800 dark:text-slate-100"
              >
                {{ t('PEOPLE.TOP_SELLERS') }}
              </h2>
              <p
                v-if="!sales.top_sellers.length"
                class="m-0 text-sm text-slate-400 dark:text-slate-500"
              >
                {{ t('PEOPLE.NO_SALES') }}
              </p>
              <ol
                v-else
                class="pl-5 m-0 text-sm text-slate-700 dark:text-slate-200"
              >
                <li
                  v-for="s in sales.top_sellers"
                  :key="s.assignee_id"
                  class="py-0.5"
                >
                  <strong>{{ s.assignee_name }}</strong>
                  · {{ money(s.won_value) }}
                  <span class="text-slate-500 dark:text-slate-400">
                    ({{ t('PEOPLE.WON', { count: s.won_count }) }})
                  </span>
                </li>
              </ol>
            </div>
            <div
              class="p-4 bg-white border rounded-lg dark:bg-slate-800 border-slate-75 dark:border-slate-700"
            >
              <h2
                class="m-0 mb-2 text-sm font-semibold text-slate-800 dark:text-slate-100"
              >
                {{ t('PEOPLE.MOST_OVERDUE') }}
              </h2>
              <p
                v-if="!(people.most_overdue || []).length"
                class="m-0 text-sm text-green-700 dark:text-green-400"
              >
                {{ t('PEOPLE.NONE_OVERDUE') }}
              </p>
              <ol
                v-else
                class="pl-5 m-0 text-sm text-slate-700 dark:text-slate-200"
              >
                <li
                  v-for="p in people.most_overdue"
                  :key="p.assignee_id"
                  class="py-0.5"
                >
                  <strong>{{ p.assignee_name }}</strong>
                  · {{ t('PEOPLE.OVERDUE', { count: p.count }) }}
                </li>
              </ol>
            </div>
          </section>
        </div>
      </template>
    </div>
  </div>
</template>
