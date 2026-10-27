<script>
// ================================================================================
// @campanas_vendedor — Detalle de Campaña (Dashboard de Seguimientos)
// Cabecera + KPIs de la TrackingCampaign y la cola de prospectos (sus
// ContactTracking, reusando el endpoint de listado filtrado por campaign_id).
// ================================================================================
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import { frontendURL } from 'dashboard/helper/URLHelper';
import TrackingCampaignsAPI from 'dashboard/api/trackingCampaigns';
import ContactTrackingsAPI from 'dashboard/api/contactTrackings';
import TableFooter from 'dashboard/components/widgets/TableFooter.vue';
import CampaignEntries from './CampaignEntries.vue';
import CampaignHandoffSettings from './CampaignHandoffSettings.vue';
import CampaignScoringSettings from './CampaignScoringSettings.vue';

const PAGE_SIZE = 25;
// Cada cuánto se refrescan los indicadores mientras la pantalla está abierta
const KPI_REFRESH_MS = 60 * 1000;

// Colores del estado de la campaña (draft/running/paused/finished)
const CAMPAIGN_STATUS_COLOR = {
  saved: 'text-woot-700 bg-woot-50 dark:text-woot-300 dark:bg-woot-900/30',
  draft: 'text-slate-500 bg-slate-100 dark:bg-slate-700',
  running: 'text-green-700 bg-green-100 dark:bg-green-900/30',
  paused: 'text-amber-800 bg-amber-100 dark:bg-amber-900/30',
  finished: 'text-slate-600 bg-slate-100 dark:bg-slate-700',
};

// Estado de cada prospecto (ContactTracking) — etiquetas en el módulo
const TRACKING_STATUS_META = {
  pending: { label: 'Pendiente', color: 'text-slate-500' },
  scheduled: { label: 'Programado', color: 'text-blue-500' },
  active: { label: 'Activo', color: 'text-green-600' },
  paused: { label: 'Pausado', color: 'text-amber-800' },
  completed: { label: 'Completado', color: 'text-green-700' },
  cancelled: { label: 'Cancelado', color: 'text-red-500' },
  failed: { label: 'Fallido', color: 'text-red-700' },
};

// Eje de ENTREGA (WhatsApp), separado del de ejecución ([[Entrega-vs-ejecucion]]).
// proyecto@automatizacion_campanas: el backend manda delivery_status (último envío
// registrado del seguimiento; sin envíos registrados, el último mensaje saliente).
const DELIVERY_META = {
  delivered: { icon: '✅', key: 'DELIVERED', color: 'text-green-600' },
  sent: { icon: '⏳', key: 'SENT', color: 'text-slate-400' },
  unconfirmed: { icon: '❔', key: 'UNCONFIRMED', color: 'text-amber-700' },
  retrying: { icon: '🔁', key: 'RETRYING', color: 'text-blue-600' },
  failed: { icon: '⚠️', key: 'FAILED', color: 'text-red-600' },
};

function deliveryBucket(prospect) {
  return prospect.delivery_status || null;
}

// Filtros client-side: cada KPI clicable mapea a un predicado sobre el prospecto.
// 'clear' no está aquí (limpia el filtro); Avance/Progreso no es filtrable.
const PROSPECT_FILTERS = {
  intent_replied: p => !!p.last_intent,
  // Interesados/Agendaron: solo por las reglas de palabra clave (igual que el embudo)
  intent_interested: p => !!p.interested_at,
  intent_appointment: p => !!p.booked_at,
  intent_objective: p => p.status === 'objective_met',
  // Pausados/Cancelados (Regla): siguen así porque los dejó una regla de palabra clave
  intent_paused_rule: p => p.status === 'paused' && p.rule_action === 'pause',
  intent_cancelled_rule: p =>
    p.status === 'cancelled' && p.rule_action === 'cancel',
  // prospeccion V6: embudo de prospección (etapas y salidas de V5)
  p_contacted: p => p.attempt_count > 0,
  p_replied: p => !!p.prospect_stage,
  p_interested: p => ['interested', 'handed_off'].includes(p.prospect_stage),
  p_handed_off: p => p.prospect_stage === 'handed_off',
  p_not_now: p => p.prospect_exit === 'not_now',
  p_not_interested: p => p.prospect_exit === 'not_interested',
  p_wrong_person: p => p.prospect_exit === 'wrong_person',
  p_opted_out: p => p.prospect_exit === 'opted_out',
  p_hot: p => (p.prospect_score || 0) >= 60, // prospeccion P4: calientes
  p_bounced: p => p.prospect_exit === 'bounced', // prospeccion V7b
  p_no_reply: p =>
    p.status === 'completed' && !p.prospect_stage && !p.prospect_exit,
  ctrl_pending: p => p.status === 'pending' || p.status === 'scheduled',
  ctrl_completed_replied: p => p.status === 'completed' && !!p.last_intent,
  ctrl_completed_no_reply: p => p.status === 'completed' && !p.last_intent,
  ctrl_failed: p => p.status === 'failed',
  del_delivered: p => deliveryBucket(p) === 'delivered',
  del_sent: p => deliveryBucket(p) === 'sent',
  del_unconfirmed: p => deliveryBucket(p) === 'unconfirmed',
  del_retrying: p => deliveryBucket(p) === 'retrying',
  del_failed: p => deliveryBucket(p) === 'failed',
};

export default {
  components: {
    TableFooter,
    CampaignEntries,
    CampaignHandoffSettings,
    CampaignScoringSettings,
  },
  data() {
    return {
      campaign: null,
      prospects: [],
      handingOff: null, // prospeccion V6
      showHandoffModal: false, // prospeccion P2
      showScoringModal: false, // prospeccion P4
      sortByScore: false, // prospeccion P4: ordenar por puntos
      choosingSubject: null, // prospeccion P3
      isLoading: false,
      currentPage: 1,
      pageSize: PAGE_SIZE,
      activeFilter: null, // id del filtro por KPI (PROSPECT_FILTERS) o null
      activeFilterLabel: '', // etiqueta traducida del KPI activo (para el chip)
      activeTab: 0, // proyecto@automatizacion_campanas: 0 = Prospectos, 1 = Inscritos
      kpiTimer: null,
      showLaunchModal: false,
      isLaunching: false,
      isResuming: false,
    };
  },
  computed: {
    ...mapGetters({ accountId: 'getCurrentAccountId' }),
    campaignId() {
      return this.$route.params.campaignId;
    },
    stats() {
      return this.campaign?.stats || {};
    },
    delivery() {
      return this.campaign?.delivery || {};
    },
    // Eje de entrega: se muestra solo si hay algún mensaje ya enviado.
    hasDelivery() {
      const d = this.delivery;
      return (
        (d.delivered || 0) +
          (d.sent || 0) +
          (d.unconfirmed || 0) +
          (d.retrying || 0) +
          (d.failed || 0) >
        0
      );
    },
    // proyecto@automatizacion_campanas: [{ code, title, count }] de los fallidos
    failureReasons() {
      return this.delivery.failure_reasons || [];
    },
    // Pausada por un error de configuración de Meta (ver TrackingCampaigns::Pause)
    isPausedByError() {
      return (
        this.campaign?.status === 'paused' && !!this.campaign.paused_reason
      );
    },
    deliveryKpis() {
      return [
        {
          key: 'DELIVERED',
          value: this.delivery.delivered || 0,
          color: 'text-green-600 dark:text-green-500',
          filter: 'del_delivered',
        },
        {
          key: 'SENT',
          value: this.delivery.sent || 0,
          color: 'text-slate-800 dark:text-slate-100',
          filter: 'del_sent',
        },
        {
          key: 'UNCONFIRMED',
          value: this.delivery.unconfirmed || 0,
          color: 'text-amber-700 dark:text-amber-500',
          filter: 'del_unconfirmed',
        },
        {
          key: 'RETRYING',
          value: this.delivery.retrying || 0,
          color: 'text-blue-600 dark:text-blue-400',
          filter: 'del_retrying',
        },
        {
          key: 'FAILED',
          value: this.delivery.failed || 0,
          color: 'text-red-500 dark:text-red-400',
          filter: 'del_failed',
        },
      ];
    },
    funnel() {
      return this.campaign?.funnel || {};
    },
    // Embudo de intención: se muestra solo si al menos un contacto respondió.
    hasFunnel() {
      return (this.funnel.replied || 0) > 0;
    },
    // prospeccion V6: en Prospección la tarjeta muestra su embudo
    isProspecting() {
      return this.campaign?.purpose === 'prospecting';
    },
    // prospeccion P3: la prueba A/B de asuntos (nil si la campaña no tiene asunto B).
    subjectTest() {
      return this.isProspecting ? this.campaign.subject_test : null;
    },
    subjectRows() {
      const test = this.subjectTest;
      if (!test) return [];
      return ['a', 'b'].map(variant => ({
        variant,
        letter: variant.toUpperCase(),
        ...test.variants[variant],
        winner: test.winner === variant,
        leader: !test.winner && test.leader === variant,
      }));
    },
    subjectStatus() {
      const test = this.subjectTest;
      if (!test) return '';
      const t = (key, args) =>
        this.$t(`TRACKING_CAMPAIGN_DETAIL.SUBJECT_TEST.${key}`, args);
      if (test.winner)
        return t('STATUS_WINNER', { letter: test.winner.toUpperCase() });
      if (test.leader)
        return t('STATUS_LEADER', { letter: test.leader.toUpperCase() });
      return t('STATUS_WAITING', { min: test.min_sample });
    },
    // prospeccion P2: «Oportunidades › Columna · plazo 4 h · escalar 8 h» o «solo con el botón».
    handoffSummary() {
      const c = this.campaign || {};
      const t = key =>
        this.$t(`TRACKING_CAMPAIGN_DETAIL.HANDOFF_SETTINGS.${key}`);
      const parts = [
        c.handoff_board_name
          ? `${c.handoff_board_name} › ${c.handoff_column_name}`
          : t('SUMMARY_MANUAL'),
        c.handoff_due_hours
          ? this.$t('TRACKING_CAMPAIGN_DETAIL.HANDOFF_SETTINGS.SUMMARY_DUE', {
              hours: c.handoff_due_hours,
            })
          : t('NO_DUE'),
      ];
      if (c.handoff_escalate_hours) {
        parts.push(
          this.$t(
            'TRACKING_CAMPAIGN_DETAIL.HANDOFF_SETTINGS.SUMMARY_ESCALATE',
            {
              hours: c.handoff_escalate_hours,
            }
          )
        );
      }
      return parts.join(' · ');
    },
    funnelTitle() {
      return this.isProspecting
        ? this.$t('TRACKING_CAMPAIGN_DETAIL.FUNNEL.P_TITLE')
        : this.$t('TRACKING_CAMPAIGN_DETAIL.FUNNEL.TITLE');
    },
    prospectingKpis() {
      const f = this.campaign?.prospecting_funnel || {};
      const contacted = f.contacted || 0;
      const rate = n =>
        contacted ? `${Math.round(((n || 0) * 100) / contacted)} %` : '';
      const kpi = (key, value, color, extra = {}) => ({
        key,
        value: value || 0,
        color,
        filter: `p_${key.slice(2).toLowerCase()}`,
        ...extra,
      });
      return [
        kpi('P_CONTACTED', f.contacted, 'text-slate-800 dark:text-slate-100'),
        kpi('P_REPLIED', f.replied, 'text-slate-800 dark:text-slate-100', {
          rate: rate(f.replied),
        }),
        kpi(
          'P_INTERESTED',
          f.interested,
          'text-green-600 dark:text-green-500',
          { rate: rate(f.interested) }
        ),
        kpi('P_HANDED_OFF', f.handed_off, 'text-woot-600 dark:text-woot-500'),
        kpi('P_NOT_NOW', f.not_now, 'text-amber-800 dark:text-amber-500'),
        kpi('P_NOT_INTERESTED', f.not_interested, 'text-slate-500'),
        kpi('P_WRONG_PERSON', f.wrong_person, 'text-slate-500'),
        kpi('P_OPTED_OUT', f.opted_out, 'text-red-500 dark:text-red-400'),
        kpi('P_BOUNCED', f.bounced, 'text-red-500 dark:text-red-400'),
        kpi(
          'P_HOT',
          this.prospects.filter(PROSPECT_FILTERS.p_hot).length,
          'text-red-500 dark:text-red-400'
        ),
        kpi('P_NO_REPLY', f.no_reply, 'text-slate-500'),
      ];
    },
    funnelKpis() {
      if (this.isProspecting) return this.prospectingKpis;
      return [
        {
          key: 'REPLIED',
          value: this.funnel.replied || 0,
          color: 'text-slate-800 dark:text-slate-100',
          filter: 'intent_replied',
        },
        {
          key: 'INTERESTED',
          value: this.funnel.interested || 0,
          color: 'text-green-600 dark:text-green-500',
          filter: 'intent_interested',
        },
        {
          key: 'APPOINTMENT',
          value: this.funnel.appointment || 0,
          color: 'text-woot-600 dark:text-woot-500',
          filter: 'intent_appointment',
        },
        {
          key: 'OBJECTIVE_MET',
          value: this.funnel.objective_met || 0,
          color: 'text-emerald-600 dark:text-emerald-500',
          filter: 'intent_objective',
        },
        {
          key: 'PAUSED_RULE',
          value: this.funnel.paused_rule || 0,
          color: 'text-amber-800 dark:text-amber-800',
          filter: 'intent_paused_rule',
        },
        {
          key: 'CANCELLED_RULE',
          value: this.funnel.cancelled_rule || 0,
          color: 'text-red-500 dark:text-red-400',
          filter: 'intent_cancelled_rule',
        },
      ];
    },
    backRoute() {
      return { name: 'contact_trackings_campaigns' };
    },
    kpis() {
      return [
        {
          key: 'PENDING',
          value: this.stats.pending || 0,
          color: 'text-slate-800 dark:text-slate-100',
          filter: 'ctrl_pending',
        },
        {
          key: 'COMPLETED_REPLIED',
          value: this.stats.completed_replied || 0,
          color: 'text-green-700 dark:text-green-500',
          filter: 'ctrl_completed_replied',
        },
        {
          key: 'COMPLETED_NO_REPLY',
          value: this.stats.completed_no_reply || 0,
          color: 'text-slate-500 dark:text-slate-400',
          filter: 'ctrl_completed_no_reply',
        },
        {
          key: 'FAILED',
          value: this.stats.failed || 0,
          color: 'text-red-700 dark:text-red-500',
          filter: 'ctrl_failed',
        },
      ];
    },
    // Descripción del KPI filtrado (qué significa) — se muestra junto a "Prospectos".
    activeFilterDesc() {
      if (!this.activeFilter) return '';
      return this.$t(
        `TRACKING_CAMPAIGN_DETAIL.FILTER_DESC.${this.activeFilter}`
      );
    },
    // Prospectos tras aplicar el filtro por KPI (client-side sobre lo cargado).
    filteredProspects() {
      const predicate = PROSPECT_FILTERS[this.activeFilter];
      const list = predicate
        ? this.prospects.filter(predicate)
        : this.prospects;
      if (!this.sortByScore) return list;
      // prospeccion P4: de más a menos puntos; sin puntuación, al final.
      return [...list].sort(
        (a, b) => (b.prospect_score ?? -1) - (a.prospect_score ?? -1)
      );
    },
    scoreHeader() {
      const arrow = this.sortByScore ? '↓' : '↕';
      return `${this.$t('TRACKING_CAMPAIGN_DETAIL.COL.SCORE')} ${arrow}`;
    },
    // prospeccion P4: «Pesos sugeridos · reglas: giro, zona» para el renglón de puntuación.
    scoringSummary() {
      const scoring = this.campaign && this.campaign.scoring;
      if (!scoring) return '';
      const t = (key, args) =>
        this.$t(`TRACKING_CAMPAIGN_DETAIL.SCORING.${key}`, args);
      const withRules = ['industry', 'size', 'decider'].filter(key => {
        const rule = scoring.rules[key];
        return (
          rule.labels.length ||
          (rule.attribute_key && rule.attribute_values.length)
        );
      });
      if (!withRules.length) return t('SUMMARY_NO_RULES');
      return t('SUMMARY_RULES', {
        rules: withRules.map(key => t(`CRITERIA.${key}`)).join(', '),
      });
    },
    totalProspects() {
      return this.filteredProspects.length;
    },
    paginatedProspects() {
      const start = (this.currentPage - 1) * this.pageSize;
      return this.filteredProspects.slice(start, start + this.pageSize);
    },
  },
  mounted() {
    this.fetchAll();
    this.kpiTimer = setInterval(this.refreshKpis, KPI_REFRESH_MS);
    document.addEventListener('visibilitychange', this.onVisibilityChange);
  },
  beforeDestroy() {
    clearInterval(this.kpiTimer);
    document.removeEventListener('visibilitychange', this.onVisibilityChange);
  },
  methods: {
    // Refresca solo los números (stats/funnel/delivery) en su lugar: sin spinner ni
    // recargar prospectos, para que la pantalla no parpadee. Con la pestaña oculta no
    // pide nada; al volver a ella se pone al día. Si falla, deja los últimos valores.
    async refreshKpis() {
      if (document.hidden || this.isLoading || !this.campaign) return;
      try {
        const { data } = await TrackingCampaignsAPI.show(this.campaignId);
        if (String(data.id) !== String(this.campaignId)) return;
        this.campaign = {
          ...this.campaign,
          status: data.status,
          paused_reason: data.paused_reason,
          stats: data.stats,
          funnel: data.funnel,
          prospecting_funnel: data.prospecting_funnel, // prospeccion V6
          subject_test: data.subject_test, // prospeccion P3
          delivery: data.delivery,
        };
      } catch (error) {
        // silencioso: se reintenta en el próximo ciclo
      }
    },
    onVisibilityChange() {
      if (!document.hidden) this.refreshKpis();
    },
    async fetchAll() {
      this.isLoading = true;
      try {
        const [{ data: campaign }, prospects] = await Promise.all([
          TrackingCampaignsAPI.show(this.campaignId),
          this.fetchProspects(),
        ]);
        this.campaign = campaign;
        this.prospects = prospects;
        this.currentPage = 1;
      } catch (error) {
        this.campaign = null;
        this.prospects = [];
      } finally {
        this.isLoading = false;
      }
    },
    // proyecto@automatizacion_campanas — Fase 2: una campaña llega a 1,000 prospectos y el
    // listado entrega 100 por página: se piden todas las páginas (los filtros por indicador
    // corren en el navegador sobre la campaña completa).
    async fetchProspects() {
      const params = { campaign_id: this.campaignId, per_page: 100 };
      const { data: first } = await ContactTrackingsAPI.getList(
        this.accountId,
        params
      );
      const totalPages = first.meta?.total_pages || 1;
      const rest = await Promise.all(
        Array.from({ length: totalPages - 1 }, (_, index) =>
          ContactTrackingsAPI.getList(this.accountId, {
            ...params,
            page: index + 2,
          })
        )
      );
      return [first, ...rest.map(response => response.data)].flatMap(
        list => list.trackings || []
      );
    },
    onPageChange(page) {
      this.currentPage = page;
    },
    // Clic en un KPI: 'clear' o volver a clicar el activo limpia; si no, filtra.
    async handOff(prospect) {
      this.handingOff = prospect.id;
      try {
        const { data } = await TrackingCampaignsAPI.handOff(
          this.campaignId,
          prospect.id
        );
        Object.assign(prospect, data); // prospeccion P2: etapa y reloj
        useAlert(this.$t('TRACKING_CAMPAIGN_DETAIL.HAND_OFF_DONE'));
        this.refreshKpis();
      } catch (error) {
        useAlert(
          error.response?.data?.error ||
            this.$t('TRACKING_CAMPAIGN_DETAIL.HAND_OFF_ERROR')
        );
      } finally {
        this.handingOff = null;
      }
    },
    // prospeccion P2: la entrega guardada vuelve al detalle sin recargar.
    onHandoffSaved(settings) {
      this.campaign = { ...this.campaign, ...settings };
    },
    closeHandoffModal() {
      this.showHandoffModal = false;
    },
    // prospeccion P4: los pesos guardados se recalculan en segundo plano; se recargan los
    // prospectos unos segundos después para ver las nuevas puntuaciones.
    onScoringSaved(scoring) {
      this.campaign = { ...this.campaign, scoring };
      setTimeout(async () => {
        this.prospects = await this.fetchProspects();
      }, 4000);
    },
    // prospeccion P4: «Perfil: giro +20 · Interés: respondió +10, pidió precio +20»
    scoreBreakdown(p) {
      const parts = p.prospect_score_parts || {};
      const keys = Object.keys(parts);
      if (!keys.length)
        return this.$t('TRACKING_CAMPAIGN_DETAIL.SCORING.NO_POINTS');
      return keys
        .map(key => {
          const points = parts[key] > 0 ? `+${parts[key]}` : parts[key];
          return `${this.$t(
            `TRACKING_CAMPAIGN_DETAIL.SCORING.CRITERIA.${key}`
          )} ${points}`;
        })
        .join(' · ');
    },
    scoreLabel(p) {
      return p.prospect_score ?? '—';
    },
    closeScoringModal() {
      this.showScoringModal = false;
    },
    scoreClass(p) {
      if ((p.prospect_score || 0) >= 60)
        return 'text-red-500 dark:text-red-400';
      if ((p.prospect_score || 0) >= 30)
        return 'text-amber-700 dark:text-amber-500';
      return 'text-slate-500 dark:text-slate-400';
    },
    // prospeccion P3: quedarse con el asunto A o B.
    async chooseSubject(variant) {
      this.choosingSubject = variant;
      try {
        const { data } = await TrackingCampaignsAPI.chooseSubject(
          this.campaignId,
          variant
        );
        this.campaign = { ...this.campaign, subject_test: data };
        useAlert(this.$t('TRACKING_CAMPAIGN_DETAIL.SUBJECT_TEST.CHOSEN'));
      } catch {
        useAlert(this.$t('TRACKING_CAMPAIGN_DETAIL.SUBJECT_TEST.ERROR'));
      } finally {
        this.choosingSubject = null;
      }
    },
    // prospeccion P2: atendido, vencido o entregado (con su vencimiento).
    handoffLabel(p) {
      if (p.handoff_attended_at) {
        return this.$t('TRACKING_CAMPAIGN_DETAIL.HANDOFF_ATTENDED');
      }
      if (p.handoff_due_at && new Date(p.handoff_due_at) <= new Date()) {
        return this.$t('TRACKING_CAMPAIGN_DETAIL.HANDOFF_OVERDUE');
      }
      if (p.handoff_due_at) {
        return this.$t('TRACKING_CAMPAIGN_DETAIL.HANDOFF_DUE', {
          at: this.formatDate(p.handoff_due_at),
        });
      }
      return this.$t('TRACKING_CAMPAIGN_DETAIL.HANDED_OFF');
    },
    handoffClass(p) {
      if (p.handoff_attended_at) return 'text-green-600 dark:text-green-500';
      if (p.handoff_due_at && new Date(p.handoff_due_at) <= new Date()) {
        return 'text-red-500 dark:text-red-400';
      }
      return 'text-woot-600';
    },
    applyFilter(filterId, label) {
      if (!filterId) return; // KPI no filtrable (ej. Avance)
      if (filterId === 'clear' || filterId === this.activeFilter) {
        this.clearFilter();
        return;
      }
      this.activeFilter = filterId;
      this.activeFilterLabel = label || '';
      this.currentPage = 1;
    },
    clearFilter() {
      this.activeFilter = null;
      this.activeFilterLabel = '';
      this.currentPage = 1;
    },
    // Pone en curso la campaña Guardada y recarga todo (por lote, los contactos
    // se inscriben en background: aparecen en las siguientes actualizaciones).
    async confirmLaunch() {
      this.showLaunchModal = false;
      this.isLaunching = true;
      try {
        const { data } = await TrackingCampaignsAPI.launch(this.campaignId);
        useAlert(
          data.queued
            ? this.$t('TRACKING_CAMPAIGNS_VIEW.LAUNCH_QUEUED', {
                count: data.queued,
              })
            : this.$t('TRACKING_CAMPAIGNS_VIEW.LAUNCH_SUCCESS')
        );
        await this.fetchAll();
      } catch (error) {
        useAlert(
          error.response?.data?.error ||
            this.$t('TRACKING_CAMPAIGNS_VIEW.LAUNCH_ERROR')
        );
      } finally {
        this.isLaunching = false;
      }
    },
    // proyecto@automatizacion_campanas: reanuda la pausada por error de Meta; sus
    // seguimientos pausados se reprograman en background a partir de un minuto.
    async resumeCampaign() {
      this.isResuming = true;
      try {
        const { data } = await TrackingCampaignsAPI.resume(this.campaignId);
        useAlert(
          this.$t('TRACKING_CAMPAIGNS_VIEW.RESUME_SUCCESS', {
            count: data.trackings,
          })
        );
        await this.fetchAll();
      } catch (error) {
        useAlert(
          error.response?.data?.error ||
            this.$t('TRACKING_CAMPAIGNS_VIEW.RESUME_ERROR')
        );
      } finally {
        this.isResuming = false;
      }
    },
    campaignStatusLabel(status) {
      return this.$t(`TRACKING_CAMPAIGNS_VIEW.STATUS.${status}`);
    },
    campaignStatusClass(status) {
      return CAMPAIGN_STATUS_COLOR[status] || 'text-slate-500 bg-slate-100';
    },
    trackingStatusLabel(status) {
      return TRACKING_STATUS_META[status]?.label || status;
    },
    trackingStatusColor(status) {
      return TRACKING_STATUS_META[status]?.color || 'text-slate-500';
    },
    deliveryMeta(prospect) {
      const bucket = deliveryBucket(prospect);
      return bucket ? DELIVERY_META[bucket] : null;
    },
    deliveryLabel(prospect) {
      const meta = this.deliveryMeta(prospect);
      if (!meta) return '—';
      return this.$t(`TRACKING_CAMPAIGN_DETAIL.DELIVERY.${meta.key}`);
    },
    // Tooltip: motivo de Meta y, si está en reintento, cuándo sale.
    deliveryTitle(prospect) {
      const parts = [prospect.delivery_error || this.deliveryLabel(prospect)];
      if (prospect.delivery_retry_at) {
        parts.push(
          this.$t('TRACKING_CAMPAIGN_DETAIL.DELIVERY.RETRY_AT', {
            date: this.formatDate(prospect.delivery_retry_at),
          })
        );
      }
      return parts.join(' · ');
    },
    // last_intent guarda la ruta técnica del bot (tracking/interested/…). La
    // traducimos a algo legible; 'tracking' = respondió sin intención especial.
    intentLabel(intent) {
      if (!intent) return '—';
      const key = `TRACKING_CAMPAIGN_DETAIL.INTENT_VALUES.${intent}`;
      const label = this.$t(key);
      return label === key ? intent : label;
    },
    // outcome guarda el desenlace del seguimiento (rejected/interested/…) en crudo.
    outcomeLabel(outcome) {
      if (!outcome) return '—';
      const key = `TRACKING_CAMPAIGN_DETAIL.OUTCOME_VALUES.${outcome}`;
      const label = this.$t(key);
      return label === key ? outcome : label;
    },
    // Traduce el last_error técnico a una causa legible (tooltip de los Fallidos).
    failureReason(p) {
      if (p.status !== 'failed') return '';
      const err = p.last_error || '';
      const base = 'TRACKING_CAMPAIGN_DETAIL.FAILURE';
      if (/window closed/i.test(err)) return this.$t(`${base}.WINDOW_CLOSED`);
      if (/par[aá]metros|requiere par/i.test(err))
        return this.$t(`${base}.TEMPLATE_PARAMS`);
      if (/failed to send/i.test(err)) return this.$t(`${base}.SEND_FAILED`);
      return err || this.$t(`${base}.UNKNOWN`);
    },
    // proyecto@automatizacion_campanas: "01/10/2026 10:00 → sin fin"
    windowText(campaign) {
      const end = campaign.ends_at
        ? this.formatDate(campaign.ends_at)
        : this.$t('TRACKING_CAMPAIGNS_VIEW.NO_END');
      return `${this.formatDate(campaign.scheduled_for)} → ${end}`;
    },
    formatDate(value) {
      if (!value) return '—';
      return new Date(value).toLocaleString('es-MX', {
        day: '2-digit',
        month: '2-digit',
        year: 'numeric',
        hour: '2-digit',
        minute: '2-digit',
      });
    },
    conversationUrl(prospect) {
      if (!prospect.conversation_display_id) return null;
      return frontendURL(
        `accounts/${this.accountId}/conversations/${prospect.conversation_display_id}`
      );
    },
  },
};
</script>

<template>
  <div class="flex flex-col flex-1 w-full h-full overflow-hidden p-4">
    <!-- Volver a la tabla de campañas -->
    <div class="mb-3 shrink-0">
      <woot-button
        variant="smooth"
        color-scheme="secondary"
        size="small"
        icon="chevron-left"
        @click="$router.push(backRoute)"
      >
        {{ $t('TRACKING_CAMPAIGNS_VIEW.BACK_TO_LIST') }}
      </woot-button>
    </div>

    <!-- Cargando -->
    <div v-if="isLoading" class="py-16 text-center text-slate-400">
      {{ $t('TRACKING_CAMPAIGN_DETAIL.LOADING') }}
    </div>

    <template v-else-if="campaign">
      <!-- Cabecera -->
      <div class="flex items-center gap-3 mb-1 shrink-0">
        <h1 class="text-xl font-bold text-slate-800 dark:text-slate-100">
          {{ campaign.name }}
        </h1>
        <span
          class="px-2 py-0.5 rounded-full text-xs font-medium"
          :class="campaignStatusClass(campaign.status)"
        >
          {{ campaignStatusLabel(campaign.status) }}
        </span>
        <!-- Guardada: se puede modificar (en el formulario de Campañas) -->
        <woot-button
          v-if="campaign.status === 'saved'"
          variant="smooth"
          color-scheme="secondary"
          size="small"
          icon="edit"
          class="ml-auto"
          @click="$router.push({ ...backRoute, query: { edit: campaign.id } })"
        >
          {{ $t('TRACKING_CAMPAIGNS_VIEW.EDIT') }}
        </woot-button>
        <woot-button
          v-if="campaign.status === 'saved'"
          size="small"
          icon="send"
          :is-loading="isLaunching"
          @click="showLaunchModal = true"
        >
          {{ $t('TRACKING_CAMPAIGNS_VIEW.LAUNCH') }}
        </woot-button>
      </div>
      <p
        v-if="campaign.status === 'saved'"
        class="text-sm text-woot-700 dark:text-woot-300 mb-3 shrink-0"
      >
        {{ $t('TRACKING_CAMPAIGNS_VIEW.SAVED_BANNER') }}
      </p>
      <!-- proyecto@automatizacion_campanas: pausada por error de configuración de Meta -->
      <div
        v-if="isPausedByError"
        class="flex items-start gap-3 p-3 mb-3 rounded-lg shrink-0 bg-amber-50 dark:bg-amber-900/20 border border-amber-200 dark:border-amber-800"
      >
        <div class="flex-1 text-sm text-amber-900 dark:text-amber-200">
          <p class="font-medium">
            {{
              $t('TRACKING_CAMPAIGNS_VIEW.PAUSED_BANNER', {
                reason: campaign.paused_reason,
              })
            }}
          </p>
          <p class="mt-1">
            {{ $t('TRACKING_CAMPAIGNS_VIEW.PAUSED_BANNER_HINT') }}
          </p>
        </div>
        <woot-button
          size="small"
          icon="arrow-clockwise"
          :is-loading="isResuming"
          @click="resumeCampaign"
        >
          {{ $t('TRACKING_CAMPAIGNS_VIEW.RESUME') }}
        </woot-button>
      </div>
      <div
        class="flex flex-wrap gap-x-6 gap-y-1 text-sm text-slate-500 dark:text-slate-400 mb-5 shrink-0"
      >
        <span>
          {{ $t('TRACKING_CAMPAIGN_DETAIL.AGENT') }}:
          <strong>{{ campaign.template_name || '—' }}</strong>
        </span>
        <span>
          {{ $t('TRACKING_CAMPAIGN_DETAIL.CHANNEL') }}:
          <strong>{{ campaign.inbox_name || '—' }}</strong>
        </span>
        <!-- proyecto@automatizacion_campanas: tipo y ventana (inicio → fin) -->
        <span>
          {{ $t('TRACKING_CAMPAIGN_DETAIL.TYPE') }}:
          <strong>{{
            $t(`TRACKING_CAMPAIGNS_VIEW.MODE.${campaign.mode || 'batch'}`)
          }}</strong>
        </span>
        <span>
          {{ $t('TRACKING_CAMPAIGN_DETAIL.WINDOW') }}:
          <strong>{{ windowText(campaign) }}</strong>
        </span>
        <span v-if="campaign.objective">
          {{ $t('TRACKING_CAMPAIGN_DETAIL.OBJECTIVE') }}:
          <strong>{{ campaign.objective }}</strong>
        </span>
      </div>

      <!-- KPIs de la campaña — 3 ejes en columnas compactas (mismo layout que el Resumen) -->
      <div class="grid grid-cols-1 md:grid-cols-3 gap-3 mb-5 shrink-0">
        <!-- 🎯 Intención -->
        <div
          class="p-3 rounded-lg bg-white dark:bg-slate-800 border border-slate-75 dark:border-slate-700 shadow-sm"
        >
          <span class="text-sm font-medium text-slate-700 dark:text-slate-200">
            🎯 {{ funnelTitle }}
          </span>
          <div class="grid grid-cols-2 gap-x-4 mt-2">
            <div
              v-for="kpi in funnelKpis"
              :key="kpi.key"
              class="flex items-center justify-between py-1.5 border-b border-slate-100 dark:border-slate-700/60"
              :class="[
                kpi.filter
                  ? 'cursor-pointer hover:bg-slate-50 dark:hover:bg-slate-700/40'
                  : '',
                activeFilter === kpi.filter
                  ? 'bg-woot-50 dark:bg-woot-800/30 rounded'
                  : '',
              ]"
              @click="
                applyFilter(
                  kpi.filter,
                  $t(`TRACKING_CAMPAIGN_DETAIL.FUNNEL.${kpi.key}`)
                )
              "
            >
              <span class="text-sm text-slate-500 dark:text-slate-400">
                {{ $t(`TRACKING_CAMPAIGN_DETAIL.FUNNEL.${kpi.key}`) }}
              </span>
              <span class="text-base font-semibold" :class="kpi.color">
                {{ kpi.value }}
              </span>
            </div>
          </div>
        </div>

        <!-- ⚙️ Control -->
        <div
          class="p-3 rounded-lg bg-white dark:bg-slate-800 border border-slate-75 dark:border-slate-700 shadow-sm"
        >
          <span class="text-sm font-medium text-slate-700 dark:text-slate-200">
            ⚙️ {{ $t('TRACKING_CAMPAIGN_DETAIL.KPI.TITLE') }}
          </span>
          <div class="grid grid-cols-2 gap-x-4 mt-2">
            <div
              v-for="kpi in kpis"
              :key="kpi.key"
              class="flex items-center justify-between py-1.5 border-b border-slate-100 dark:border-slate-700/60"
              :class="[
                kpi.filter
                  ? 'cursor-pointer hover:bg-slate-50 dark:hover:bg-slate-700/40'
                  : '',
                activeFilter === kpi.filter
                  ? 'bg-woot-50 dark:bg-woot-800/30 rounded'
                  : '',
              ]"
              @click="
                applyFilter(
                  kpi.filter,
                  $t(`TRACKING_CAMPAIGN_DETAIL.KPI.${kpi.key}`)
                )
              "
            >
              <span class="text-sm text-slate-500 dark:text-slate-400">
                {{ $t(`TRACKING_CAMPAIGN_DETAIL.KPI.${kpi.key}`) }}
              </span>
              <span class="text-base font-semibold" :class="kpi.color">
                {{ kpi.value }}
              </span>
            </div>
          </div>
        </div>

        <!-- 📬 Entrega -->
        <div
          class="p-3 rounded-lg bg-white dark:bg-slate-800 border border-slate-75 dark:border-slate-700 shadow-sm"
        >
          <span class="text-sm font-medium text-slate-700 dark:text-slate-200">
            📬 {{ $t('TRACKING_CAMPAIGN_DETAIL.DELIVERY.TITLE') }}
          </span>
          <div v-if="hasDelivery" class="grid grid-cols-2 gap-x-4 mt-2">
            <div
              v-for="kpi in deliveryKpis"
              :key="kpi.key"
              class="flex items-center justify-between py-1.5 border-b border-slate-100 dark:border-slate-700/60"
              :class="[
                kpi.filter
                  ? 'cursor-pointer hover:bg-slate-50 dark:hover:bg-slate-700/40'
                  : '',
                activeFilter === kpi.filter
                  ? 'bg-woot-50 dark:bg-woot-800/30 rounded'
                  : '',
              ]"
              @click="
                applyFilter(
                  kpi.filter,
                  $t(`TRACKING_CAMPAIGN_DETAIL.DELIVERY.${kpi.key}`)
                )
              "
            >
              <span class="text-sm text-slate-500 dark:text-slate-400">
                {{ $t(`TRACKING_CAMPAIGN_DETAIL.DELIVERY.${kpi.key}`) }}
              </span>
              <span class="text-base font-semibold" :class="kpi.color">
                {{ kpi.value }}
              </span>
            </div>
          </div>
          <p v-else class="text-xs text-slate-400 py-4 text-center">
            {{ $t('TRACKING_CAMPAIGN_DETAIL.DELIVERY.EMPTY') }}
          </p>
          <!-- proyecto@automatizacion_campanas: por qué fallaron (código de Meta) -->
          <div v-if="failureReasons.length" class="mt-2">
            <span
              class="text-xs font-medium text-slate-500 dark:text-slate-400"
            >
              {{ $t('TRACKING_CAMPAIGN_DETAIL.DELIVERY.REASONS_TITLE') }}
            </span>
            <ul class="mt-1 space-y-0.5">
              <li
                v-for="reason in failureReasons"
                :key="`${reason.code}-${reason.title}`"
                class="flex justify-between gap-2 text-xs text-slate-600 dark:text-slate-300"
                :title="reason.title"
              >
                <span class="truncate">
                  {{ reason.code ? `${reason.code}: ` : '' }}{{ reason.title }}
                </span>
                <span class="font-semibold">{{ reason.count }}</span>
              </li>
            </ul>
          </div>
        </div>
      </div>

      <!-- prospeccion P2: entrega de interesados (resumen; se configura en el modal) -->
      <div
        v-if="isProspecting"
        class="flex items-center justify-between gap-3 p-3 mb-3 rounded-lg bg-white dark:bg-slate-800 border border-slate-75 dark:border-slate-700 shadow-sm"
      >
        <div class="min-w-0">
          <span class="text-sm font-medium text-slate-700 dark:text-slate-200">
            {{ $t('TRACKING_CAMPAIGN_DETAIL.HANDOFF_SETTINGS.TITLE') }}
          </span>
          <p class="mb-0 text-xs truncate text-slate-500 dark:text-slate-400">
            {{ handoffSummary }}
          </p>
        </div>
        <woot-button
          size="small"
          variant="smooth"
          icon="settings"
          @click="showHandoffModal = true"
        >
          {{ $t('TRACKING_CAMPAIGN_DETAIL.HANDOFF_SETTINGS.CONFIGURE') }}
        </woot-button>
      </div>
      <!-- prospeccion P4: puntuación (resumen; se configura en el modal) -->
      <div
        v-if="isProspecting"
        class="flex items-center justify-between gap-3 p-3 mb-3 rounded-lg bg-white dark:bg-slate-800 border border-slate-75 dark:border-slate-700 shadow-sm"
      >
        <div class="min-w-0">
          <span class="text-sm font-medium text-slate-700 dark:text-slate-200">
            {{ $t('TRACKING_CAMPAIGN_DETAIL.SCORING.TITLE') }}
          </span>
          <p class="mb-0 text-xs truncate text-slate-500 dark:text-slate-400">
            {{ scoringSummary }}
          </p>
        </div>
        <woot-button
          size="small"
          variant="smooth"
          icon="settings"
          @click="showScoringModal = true"
        >
          {{ $t('TRACKING_CAMPAIGN_DETAIL.HANDOFF_SETTINGS.CONFIGURE') }}
        </woot-button>
      </div>
      <woot-modal
        v-if="isProspecting"
        :show.sync="showScoringModal"
        size="medium"
        :on-close="closeScoringModal"
      >
        <CampaignScoringSettings
          v-if="showScoringModal"
          :campaign="campaign"
          @saved="onScoringSaved"
          @close="closeScoringModal"
        />
      </woot-modal>

      <!-- prospeccion P3: prueba A/B de asuntos -->
      <div
        v-if="subjectTest"
        class="p-3 mb-3 rounded-lg bg-white dark:bg-slate-800 border border-slate-75 dark:border-slate-700 shadow-sm"
      >
        <span class="text-sm font-medium text-slate-700 dark:text-slate-200">
          {{ $t('TRACKING_CAMPAIGN_DETAIL.SUBJECT_TEST.TITLE') }}
        </span>
        <p class="mb-2 text-xs text-slate-500 dark:text-slate-400">
          {{ subjectStatus }}
        </p>
        <div
          v-for="row in subjectRows"
          :key="row.variant"
          class="flex items-center justify-between gap-3 py-1.5 border-b last:border-b-0 border-slate-100 dark:border-slate-700/60"
        >
          <div class="min-w-0 text-sm">
            <span class="font-semibold text-slate-700 dark:text-slate-200">
              {{ row.letter }}
            </span>
            <span class="ml-1 text-slate-600 dark:text-slate-300">
              {{ row.subject }}
            </span>
          </div>
          <div class="flex items-center gap-3 shrink-0 text-xs">
            <span class="text-slate-500 dark:text-slate-400">
              {{
                $t('TRACKING_CAMPAIGN_DETAIL.SUBJECT_TEST.NUMBERS', {
                  contacted: row.contacted,
                  replied: row.replied,
                })
              }}
            </span>
            <span
              class="font-semibold"
              :class="
                row.winner || row.leader
                  ? 'text-green-600 dark:text-green-500'
                  : 'text-slate-600 dark:text-slate-300'
              "
            >
              {{ row.rate }}%
            </span>
            <span
              v-if="row.winner"
              class="font-medium text-green-600 dark:text-green-500"
            >
              {{ $t('TRACKING_CAMPAIGN_DETAIL.SUBJECT_TEST.WINNER') }}
            </span>
            <woot-button
              v-else-if="!subjectTest.winner"
              size="tiny"
              variant="smooth"
              :is-loading="choosingSubject === row.variant"
              @click="chooseSubject(row.variant)"
            >
              {{ $t('TRACKING_CAMPAIGN_DETAIL.SUBJECT_TEST.CHOOSE') }}
            </woot-button>
          </div>
        </div>
      </div>
      <woot-modal
        v-if="isProspecting"
        :show.sync="showHandoffModal"
        :on-close="closeHandoffModal"
      >
        <CampaignHandoffSettings
          v-if="showHandoffModal"
          :campaign="campaign"
          @saved="onHandoffSaved"
          @close="closeHandoffModal"
        />
      </woot-modal>

      <!-- proyecto@automatizacion_campanas: Prospectos (sus seguimientos) e Inscritos
           (cada intento de inscripción, por lote o por automatización, y los omitidos). -->
      <woot-tabs
        class="mb-3 shrink-0"
        :index="activeTab"
        @change="index => (activeTab = index)"
      >
        <woot-tabs-item
          :index="0"
          :name="$t('TRACKING_CAMPAIGN_DETAIL.TABS.PROSPECTS')"
          :show-badge="false"
        />
        <woot-tabs-item
          :index="1"
          :name="$t('TRACKING_CAMPAIGN_DETAIL.TABS.ENTRIES')"
          :show-badge="false"
        />
      </woot-tabs>

      <CampaignEntries v-if="activeTab === 1" :campaign-id="campaignId" />

      <!-- Prospectos -->
      <div v-else class="mb-2 flex items-center gap-3 shrink-0">
        <h2 class="text-base font-semibold text-slate-700 dark:text-slate-200">
          {{ $t('TRACKING_CAMPAIGN_DETAIL.PROSPECTS') }} ({{ totalProspects }})
        </h2>
        <!-- Filtro activo desde un KPI -->
        <span
          v-if="activeFilter"
          class="inline-flex items-center gap-2 text-xs rounded-full border border-woot-200 dark:border-woot-700 bg-woot-50 dark:bg-woot-800/30 text-woot-700 dark:text-woot-300 pl-2.5 pr-1.5 py-1"
        >
          {{ $t('TRACKING_CAMPAIGN_DETAIL.FILTERED_BY') }}:
          {{ activeFilterLabel }}
          <button
            type="button"
            class="hover:text-woot-900 dark:hover:text-woot-100 font-medium underline"
            @click="clearFilter"
          >
            {{ $t('TRACKING_CAMPAIGN_DETAIL.SHOW_ALL') }}
          </button>
        </span>
        <!-- Descripción de qué mide el KPI filtrado -->
        <span
          v-if="activeFilterDesc"
          class="inline-flex items-center gap-1 text-sm text-slate-600 dark:text-slate-300"
        >
          ℹ️ {{ activeFilterDesc }}
        </span>
      </div>

      <div
        v-if="activeTab === 0 && totalProspects === 0"
        class="py-10 text-center text-slate-400 shrink-0"
      >
        {{
          activeFilter
            ? $t('TRACKING_CAMPAIGN_DETAIL.FILTER_EMPTY')
            : $t('TRACKING_CAMPAIGN_DETAIL.PROSPECTS_EMPTY')
        }}
      </div>

      <!-- Área de tabla: ocupa el alto restante y hace scroll interno -->
      <div v-else-if="activeTab === 0" class="flex flex-col flex-1 min-h-0">
        <div
          class="flex-1 min-h-0 overflow-y-auto border border-slate-75 dark:border-slate-700 rounded-md"
        >
          <table class="w-full text-sm border-collapse">
            <thead
              class="sticky top-0 z-10 bg-white dark:bg-slate-800 shadow-sm"
            >
              <tr class="text-left text-slate-500 dark:text-slate-400">
                <th class="p-3">
                  {{ $t('TRACKING_CAMPAIGN_DETAIL.COL.CONTACT') }}
                </th>
                <th class="p-3">
                  {{ $t('TRACKING_CAMPAIGN_DETAIL.COL.STATUS') }}
                </th>
                <th class="p-3">
                  {{ $t('TRACKING_CAMPAIGN_DETAIL.COL.DELIVERY') }}
                </th>
                <th class="p-3">
                  {{ $t('TRACKING_CAMPAIGN_DETAIL.COL.INTENT') }}
                </th>
                <th class="p-3">
                  {{ $t('TRACKING_CAMPAIGN_DETAIL.COL.OUTCOME') }}
                </th>
                <th class="p-3">
                  {{ $t('TRACKING_CAMPAIGN_DETAIL.COL.SCHEDULED') }}
                </th>
                <th class="p-3 text-center">
                  {{ $t('TRACKING_CAMPAIGN_DETAIL.COL.ATTEMPTS') }}
                </th>
                <!-- prospeccion P4: clic para ordenar de más a menos puntos -->
                <th
                  v-if="isProspecting"
                  class="p-3 text-center cursor-pointer select-none"
                  :class="sortByScore ? 'text-woot-600' : ''"
                  @click="sortByScore = !sortByScore"
                >
                  {{ scoreHeader }}
                </th>
                <th class="p-3 text-right">
                  {{ $t('TRACKING_CAMPAIGN_DETAIL.COL.ACTION') }}
                </th>
              </tr>
            </thead>
            <tbody>
              <tr
                v-for="p in paginatedProspects"
                :key="p.id"
                class="border-t border-slate-75 dark:border-slate-800 hover:bg-slate-25 dark:hover:bg-slate-800/40"
              >
                <td class="p-3 text-slate-700 dark:text-slate-200">
                  {{ p.contact_name || '—' }}
                </td>
                <td
                  class="p-3 font-medium"
                  :class="[
                    trackingStatusColor(p.status),
                    p.status === 'failed' ? 'cursor-help' : '',
                  ]"
                  :title="failureReason(p)"
                >
                  {{ trackingStatusLabel(p.status)
                  }}{{ p.status === 'failed' ? ' ℹ️' : '' }}
                </td>
                <td class="p-3">
                  <span
                    v-if="deliveryMeta(p)"
                    class="inline-flex items-center gap-1 font-medium"
                    :class="deliveryMeta(p).color"
                    :title="deliveryTitle(p)"
                  >
                    {{ deliveryMeta(p).icon }} {{ deliveryLabel(p) }}
                  </span>
                  <span v-else class="text-slate-300">—</span>
                </td>
                <td class="p-3 text-slate-500 dark:text-slate-400">
                  {{ intentLabel(p.last_intent) }}
                </td>
                <td class="p-3 text-slate-500 dark:text-slate-400">
                  {{ outcomeLabel(p.outcome) }}
                </td>
                <td
                  class="p-3 text-slate-500 dark:text-slate-400 whitespace-nowrap"
                >
                  {{ formatDate(p.scheduled_for) }}
                </td>
                <td class="p-3 text-center text-slate-500">
                  {{ p.attempt_count }}/{{ p.max_attempts }}
                </td>
                <td
                  v-if="isProspecting"
                  class="p-3 font-semibold text-center cursor-help"
                  :class="scoreClass(p)"
                  :title="scoreBreakdown(p)"
                >
                  {{ scoreLabel(p) }}
                </td>
                <td class="p-3 text-right whitespace-nowrap">
                  <!-- prospeccion V6: entregar un interesado a un vendedor -->
                  <woot-button
                    v-if="p.prospect_stage === 'interested'"
                    size="tiny"
                    variant="smooth"
                    class="mr-2"
                    :is-loading="handingOff === p.id"
                    @click="handOff(p)"
                  >
                    {{ $t('TRACKING_CAMPAIGN_DETAIL.HAND_OFF') }}
                  </woot-button>
                  <span
                    v-else-if="p.prospect_stage === 'handed_off'"
                    class="mr-2 text-xs font-medium"
                    :class="handoffClass(p)"
                  >
                    {{ handoffLabel(p) }}
                  </span>
                  <router-link
                    v-if="conversationUrl(p)"
                    :to="conversationUrl(p)"
                    class="text-woot-600 hover:text-woot-700 text-xs font-medium"
                  >
                    {{ $t('TRACKING_CAMPAIGN_DETAIL.OPEN_CONVERSATION') }}
                  </router-link>
                  <span v-else class="text-slate-300">—</span>
                </td>
              </tr>
            </tbody>
          </table>
        </div>

        <TableFooter
          class="shrink-0"
          :current-page="currentPage"
          :page-size="pageSize"
          :total-count="totalProspects"
          @pageChange="onPageChange"
        />
      </div>
    </template>
    <woot-delete-modal
      :show="showLaunchModal"
      :on-close="() => (showLaunchModal = false)"
      :on-confirm="confirmLaunch"
      :title="$t('TRACKING_CAMPAIGNS_VIEW.LAUNCH')"
      :message="$t('TRACKING_CAMPAIGNS_VIEW.LAUNCH_CONFIRM')"
      :message-value="campaign ? ` «${campaign.name}»?` : ''"
      :confirm-text="$t('TRACKING_CAMPAIGNS_VIEW.LAUNCH_YES')"
      :reject-text="$t('TRACKING_CAMPAIGNS_VIEW.DELETE_NO')"
    />
  </div>
</template>
