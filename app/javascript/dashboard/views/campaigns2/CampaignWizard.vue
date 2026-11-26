<!--
  Campaña con IA (Motor 2.0) — la pantalla para crear o modificar una campaña (la 1.0, CampaignForm, no cambia). Pasos
  como pestañas, en el orden en que pasa la plática: Objetivo (tipo, qué cuenta como logrado, canal) · La ficha (lo que
  sabe la IA: datos, preguntas, ligas, archivos) · Audiencia · Mensajes (lo que se manda) · Respuestas y resultados
  (respuestas fijas y etiquetas del contacto) · Cómo atiende · Cuándo · Revisar y lanzar (con «Casos»). A la derecha,
  siempre: cómo se ve el mensaje (teléfono o correo) y «Probar».
  Invitar va en 5 pasos (INVITE_STEPS), en el orden en que piensa quien invita: El evento (con sus datos, cómo
  confirma y lo que solo sabe la empresa: InviteEvent) · Invitados (canal y a quién) · Mensajes (con recordatorios a
  los que confirmaron: EventReminders) · Respuestas (compactas; «Cómo atiende» en opciones avanzadas) · Revisar y
  lanzar (nombre, cuándo —termina al empezar el evento— y los Casos corren solos). La vista de «así le llega» solo
  en Mensajes y Revisar.
  El tipo se elige ANTES (cuadro de «Nueva campaña»: ?kind=…; si falta, CampaignKindPicker aquí) y ya no se cambia.
  Ruta: tracking-dashboard/campaigns2/new?kind=… | campaigns2/:campaignId/edit.
-->
<script>
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import Motor2CampaignsAPI from 'dashboard/api/motor2Campaigns';
import CatalogItemsAPI from 'dashboard/api/catalogItems';
import WizardTabs from 'dashboard/views/readyAgents/WizardTabs.vue';
import EmailPreview from './EmailPreview.vue';
import EmailEditor from './EmailEditor.vue';
import CampaignChat from './CampaignChat.vue';
import CampaignSimulator from './CampaignSimulator.vue';
import CampaignTestRun from './CampaignTestRun.vue';
import CampaignKnowledge from './CampaignKnowledge.vue';
import CampaignReplies from './CampaignReplies.vue';
import CampaignCases from './CampaignCases.vue';
import CampaignAttend from './CampaignAttend.vue';
import WhatsappFlow from './WhatsappFlow.vue';
import ConversationPreview from './ConversationPreview.vue';
import InviteEvent from './InviteEvent.vue';
import EventReminders from './EventReminders.vue';
import CampaignKindPicker from './CampaignKindPicker.vue';
import OfferProducts from './OfferProducts.vue';
import OfferInterest from './OfferInterest.vue';
import SurveyQuestions from './SurveyQuestions.vue';
import SurveyLow from './SurveyLow.vue';
import RenewDue from './RenewDue.vue';
import RenewPay from './RenewPay.vue';
import FollowUpPlan from 'dashboard/views/readyAgents/FollowUpPlan.vue';
import { fillTemplate, sampleValues } from './campaignFlow';

// En «Revisar»: probar la campaña completa, no solo al vendedor.
const TEST_TABS = ['cases', 'simulate', 'chat', 'real'];
// Invitar: los Casos corren solos y un solo chat; simular y la prueba real, en «Más pruebas».
const INVITE_TEST_TABS = ['cases', 'chat', 'more'];

const STEPS = [
  'goal',
  'knowledge',
  'audience',
  'messages',
  'replies',
  'attend',
  'when',
  'review',
];
// Invitar: en el orden en que piensa quien invita (evento → invitados → mensajes → respuestas → lanzar).
const INVITE_STEPS = ['event', 'audience', 'messages', 'replies', 'review'];
// Ofrecer: la oferta (productos y promoción) → qué hace cuando le interesa → a quién → mensajes → respuestas → lanzar.
const OFFER_STEPS = [
  'offer',
  'interest',
  'audience',
  'messages',
  'replies',
  'review',
];
// Reactivar: primero a quién (los que no compran desde N días), luego qué les ofreces y lo demás como Ofrecer.
const REACTIVATE_STEPS = [
  'audience',
  'offer',
  'interest',
  'messages',
  'replies',
  'review',
];
// Encuesta: las preguntas con tipo → si califica bajo → a quién (atendidos hace poco) → mensajes → respuestas → lanzar.
const SURVEY_STEPS = [
  'questions',
  'low',
  'audience',
  'messages',
  'replies',
  'review',
];
// Recordar: qué contratos y en qué días antes de vencer → cómo se paga → mensajes → respuestas → lanzar.
const RENEW_STEPS = ['due', 'pay', 'messages', 'replies', 'review'];
const KINDS = ['offer', 'invite', 'reactivate', 'renew', 'survey'];
const FILTER_TYPE_CONTACT = 'contact';
const ATTENDEE_STATUSES = [
  'invited',
  'confirmed',
  'attended',
  'no_show',
  'cancelled',
];

const blankForm = () => ({
  name: '',
  // «Cómo atiende» (la campaña arma su agente): se llena con lo de la última campaña al abrir.
  attend: null,
  inbox_id: '',
  brief: {
    kind: 'offer',
    offer_what: '',
    offer_goal: 'relay',
    goal_keyword: '',
    // La ficha (lo que sabe la IA), sus ligas, las respuestas fijas y las etiquetas del contacto (CampaignKit).
    facts: {},
    links: [],
    replies: {},
    labels: null,
    event_id: '',
    survey_questions: ['', '', ''],
    low_score: 7,
    rest_days: 7,
    warmup: false,
    // De esta oferta (además de las generales del vendedor) y quién atiende a los de esta campaña.
    objections: [],
    // WhatsApp: la apertura si la ventana está abierta y el «Mensaje 2» (sale tal cual si pide información).
    opener: '',
    content: '',
    relay: 'agent',
    relay_user_id: '',
    relay_team_id: '',
    // Invitar: recordatorios a los que confirmaron (EventReminders).
    reminders: {},
  },
  touches: {
    attempts: 2,
    every_value: 2,
    every_unit: 'days',
    templates: [],
    template_vars: {},
    emails: [],
  },
  audience: { source: { type: 'segment' }, excluded_contact_ids: [] },
  event_status: 'invited',
  start: 'now',
  scheduled_for: '',
  ends_at: '',
  respect_working_hours: true,
  daily_cap: '',
  entry_delay_minutes: 0,
  email_subject: '',
  email_subject_b: '',
});

const localInput = value => {
  if (!value) return '';
  const d = new Date(value);
  const pad = n => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(
    d.getHours()
  )}:${pad(d.getMinutes())}`;
};

export default {
  name: 'CampaignWizard',
  components: {
    WizardTabs,
    EmailPreview,
    EmailEditor,
    CampaignChat,
    CampaignSimulator,
    CampaignTestRun,
    CampaignKnowledge,
    CampaignReplies,
    CampaignCases,
    CampaignAttend,
    WhatsappFlow,
    ConversationPreview,
    InviteEvent,
    EventReminders,
    CampaignKindPicker,
    OfferProducts,
    OfferInterest,
    SurveyQuestions,
    SurveyLow,
    RenewDue,
    RenewPay,
    FollowUpPlan,
  },
  data() {
    return {
      step: 'goal',
      form: blankForm(),
      options: {
        inboxes: [],
        events: [],
        users: [],
        teams: [],
        sources: [],
        calendar_users: [],
        attend: null,
      },
      loading: true,
      saving: false,
      campaignId: null,
      preview: null,
      previewLoading: false,
      checks: [],
      checkError: false,
      loadFailed: false, // editando, no se pudo traer la campaña: no se guarda (crearía otra)
      touchTab: 1,
      testTab: 'cases',
      moreTest: 'simulate',
      // El tipo se elige antes de entrar (?kind=…) y ya no se cambia; sin tipo, se pregunta primero.
      showKindPicker: false,
      // Ofrecer: los productos elegidos (sus datos del Catálogo) y la versión de «Imágenes y archivos» (al pegar la foto).
      offerItems: {},
      filesVersion: 0,
      catalogCategories: [], // Reactivar: para acotar por categoría
      showAdvanced: false,
      sendingTest: false,
      // Lista fría de correos (solo correo)
      listFile: null,
      listName: '',
      listDays: 30,
      listInfo: null,
      uploading: false,
    };
  },
  computed: {
    ...mapGetters({ labels: 'labels/getLabels' }),
    // Encuesta e invitación no llevan relevo: solo a quién pasa el que pide una persona.
    relayChoices() {
      return ['survey', 'invite'].includes(this.kind)
        ? ['person']
        : ['agent', 'person'];
    },
    // Las plantillas aprobadas de la bandeja (para el seguimiento pasadas 24 h y el aviso de la cita).
    inboxTemplates() {
      return (this.inbox?.templates || []).map(tpl => tpl.name);
    },
    isInvite() {
      return this.kind === 'invite';
    },
    isOffer() {
      return this.kind === 'offer';
    },
    isReactivate() {
      return this.kind === 'reactivate';
    },
    // Ofrecer y Reactivar: productos con promoción, «Cuando le interesa» y el seguimiento en Mensajes.
    offerLike() {
      return this.isOffer || this.isReactivate;
    },
    isSurvey() {
      return this.kind === 'survey';
    },
    isRenew() {
      return this.kind === 'renew';
    },
    // Las variables que se pueden poner en el correo según el tipo (las llena cada contacto: ContactFacts).
    emailVars() {
      const base = ['contacto', 'empresa'];
      if (this.isRenew) return [...base, 'que_vence', 'vence', 'monto'];
      if (this.kind === 'reactivate')
        return [...base, 'ultima_compra', 'oferta'];
      if (this.isSurvey || this.isInvite) return base;
      return [...base, 'oferta'];
    },
    // Recordar: los días antes de vencer en que salen sus toques.
    renewOffsets() {
      return ((this.form.brief.renew_source || {}).offsets || [7, 1, 0]).map(
        Number
      );
    },
    // Proceso guiado (sus propios pasos, respuestas compactas, «Cómo atiende» avanzado).
    guided() {
      return this.isInvite || this.offerLike || this.isSurvey || this.isRenew;
    },
    guideKey() {
      if (this.isInvite) return 'INVITE';
      if (this.isSurvey) return 'SURVEY_FLOW';
      if (this.isRenew) return 'RENEW_FLOW';
      return this.isReactivate ? 'REACT_FLOW' : 'OFFER_FLOW';
    },
    steps() {
      if (this.isInvite) return INVITE_STEPS;
      if (this.isReactivate) return REACTIVATE_STEPS;
      if (this.isSurvey) return SURVEY_STEPS;
      if (this.isRenew) return RENEW_STEPS;
      return this.isOffer ? OFFER_STEPS : STEPS;
    },
    // Las audiencias de cada tipo (Reactivar: primero «no compran desde N días»).
    audienceTypes() {
      const base = ['segment', 'label', 'event', 'continuous'];
      const list = this.isWhatsapp ? [] : ['list'];
      if (this.isReactivate) return ['inactive', 'segment', 'label', ...list];
      if (this.isSurvey) return ['served', ...base, ...list];
      if (this.isRenew) return ['contracts'];
      return [...base, ...list];
    },
    // Reactivar y Recordar: en la muestra sale lo último que compró o lo que le vence.
    previewFacts() {
      return this.isReactivate || this.kind === 'renew';
    },
    testTabs() {
      return this.guided ? INVITE_TEST_TABS : TEST_TABS;
    },
    // Guiados: «así le llega» y probar solo donde sirven.
    showSide() {
      return !this.guided || ['messages', 'review'].includes(this.step);
    },
    // Audiencia «asistentes de un evento»: su propio evento (puede ser otro, p. ej. la expo pasada).
    audienceEventId() {
      return this.form.audience.source.event_id || this.form.brief.event_id;
    },
    attendeeStatuses() {
      return ATTENDEE_STATUSES;
    },
    stepLabels() {
      const base = this.guided ? `${this.guideKey}.STEPS` : 'STEPS';
      return Object.fromEntries(
        this.steps.map(s => [s, this.t(`${base}.${s}`)])
      );
    },
    stepHint() {
      return this.t(
        this.guided
          ? `${this.guideKey}.HINTS.${this.step}`
          : `HINTS.${this.step}`
      );
    },
    segments() {
      return this.$store.getters['customViews/getCustomViewsByFilterType'](
        FILTER_TYPE_CONTACT
      );
    },
    inbox() {
      return this.options.inboxes.find(
        i => i.id === Number(this.form.inbox_id)
      );
    },
    isWhatsapp() {
      return /whatsapp/i.test(this.inbox?.channel_type || '');
    },
    isEmail() {
      return this.inbox?.channel_type === 'Channel::Email';
    },
    emailInboxes() {
      return this.options.inboxes.filter(
        i => i.channel_type === 'Channel::Email'
      );
    },
    isList() {
      return this.sourceType === 'list';
    },
    kind() {
      return this.form.brief.kind;
    },
    // Lo de fábrica del tipo (TrackingCampaigns::CampaignKit): objetivos, campos de la ficha, respuestas, etiquetas.
    kit() {
      return (this.options.kit || {})[this.kind] || null;
    },
    goals() {
      return this.kit ? this.kit.goals : ['relay'];
    },
    event() {
      return this.audienceEvents.find(
        e => e.id === Number(this.form.brief.event_id)
      );
    },
    attempts() {
      return Number(this.form.touches.attempts) || 1;
    },
    touchNumbers() {
      return Array.from({ length: this.attempts }, (_v, i) => i + 1);
    },
    sourceType() {
      return this.form.audience.source.type;
    },
    continuous() {
      return this.sourceType === 'continuous';
    },
    filterPayload() {
      const src = this.form.audience.source;
      if (src.type === 'segment' && src.segment_id) {
        const segment = this.segments.find(
          s => s.id === Number(src.segment_id)
        );
        return segment?.query?.payload || [];
      }
      if (src.type === 'label' && src.label) {
        return [
          {
            attribute_key: 'labels',
            filter_operator: 'equal_to',
            values: [src.label],
            query_operator: null,
          },
        ];
      }
      if (src.type === 'event' && this.audienceEventId) {
        return [
          {
            attribute_key: 'event',
            filter_operator: 'equal_to',
            values: [`${this.audienceEventId}:${this.form.event_status}`],
            query_operator: null,
          },
        ];
      }
      if (src.type === 'inactive') {
        return [
          {
            attribute_key: 'inactive_customer',
            filter_operator: 'equal_to',
            values: [`${src.days || 180}:${src.category_id || 'any'}`],
            query_operator: null,
          },
        ];
      }
      if (src.type === 'contracts') {
        const type = (this.form.brief.renew_source || {}).contract_type_id;
        return [
          {
            attribute_key: 'contract_due',
            filter_operator: 'equal_to',
            values: [
              `${Math.max(...this.renewOffsets, 0) || 7}:${type || 'any'}`,
            ],
            query_operator: null,
          },
        ];
      }
      if (src.type === 'served') {
        return [
          {
            attribute_key: 'served_recently',
            filter_operator: 'equal_to',
            values: [String(src.days || 30)],
            query_operator: null,
          },
        ];
      }
      if (src.type === 'campaign') return [];
      return [];
    },
    rulesFor() {
      return n => {
        const tpl = this.templateFor(n);
        return (tpl && (this.form.touches.template_vars || {})[tpl.name]) || {};
      };
    },
    templateFor() {
      return n =>
        (this.inbox?.templates || []).find(
          tpl => tpl.name === this.form.touches.templates[n - 1]
        ) || null;
    },
    currentEmail() {
      return this.form.touches.emails[this.touchTab - 1] || { blocks: [] };
    },
    opener() {
      if (this.isWhatsapp) {
        const tpl = this.templateFor(1);
        return tpl
          ? fillTemplate(
              tpl.body,
              this.rulesFor(1),
              sampleValues(this.form.brief, this.event)
            )
          : '';
      }
      return (this.form.touches.emails[0]?.body || '')
        .replace(/\{\{\s*contacto\s*\}\}/gi, 'Mario')
        .replace(/\{\{\s*empresa\s*\}\}/gi, 'Grúas del Norte');
    },
    errors() {
      return this.checks.filter(c => c.level === 'error');
    },
    // Contar la audiencia, subir una lista, simular y la prueba real necesitan el canal.
    hasChannel() {
      return !!this.form.inbox_id;
    },
    // «Más tarde» necesita una fecha futura, y el fin va después del inicio.
    // Audiencia por evento: también los recientes (seguimiento después de la expo: asistió, no se presentó).
    audienceEvents() {
      return [
        ...(this.options.events || []),
        ...(this.options.past_events || []),
      ];
    },
    scheduleProblem() {
      const f = this.form;
      const start =
        f.start === 'later' && f.scheduled_for
          ? new Date(f.scheduled_for)
          : new Date();
      if (f.start === 'later' && (!f.scheduled_for || start <= new Date()))
        return this.t('WHEN.NEEDS_FUTURE');
      if (f.ends_at && new Date(f.ends_at) <= start)
        return this.t('WHEN.ENDS_BEFORE');
      return '';
    },
    // El resumen de «Revisar»: cuándo, ritmo y horario.
    reviewLines() {
      const f = this.form;
      const fmt = v =>
        new Date(v).toLocaleString([], {
          dateStyle: 'medium',
          timeStyle: 'short',
        });
      const lines = [
        f.start === 'later' && f.scheduled_for
          ? this.t('REVIEW.STARTS_AT', { at: fmt(f.scheduled_for) })
          : this.t('REVIEW.STARTS_NOW'),
        this.reviewEnd(fmt),
        this.isRenew
          ? this.t('RENEW_FLOW.PACE', { days: this.renewOffsets.join(', ') })
          : this.t('REVIEW.PACE', {
              n: this.attempts,
              every: f.touches.every_value,
              unit: this.t(`SIM.UNITS.${f.touches.every_unit}`),
            }),
        f.daily_cap
          ? this.t(f.brief.warmup ? 'REVIEW.CAP_WARMUP' : 'REVIEW.CAP', {
              n: f.daily_cap,
            })
          : this.t('REVIEW.NO_CAP'),
        this.t(
          f.respect_working_hours ? 'REVIEW.HOURS_ON' : 'REVIEW.HOURS_OFF'
        ),
        this.t('REVIEW.ONE_A_DAY'),
      ];
      return lines;
    },
    // Invitar sin fecha de fin: termina cuando empieza el evento.
    reviewEnd() {
      return fmt => {
        if (this.form.ends_at)
          return this.t('REVIEW.ENDS_AT', { at: fmt(this.form.ends_at) });
        if (this.isInvite && this.event && this.event.starts_at)
          return this.t('REVIEW.ENDS_AT', { at: fmt(this.event.starts_at) });
        if (this.offerLike && this.form.brief.valid_until)
          return this.t('REVIEW.ENDS_AT', {
            at: fmt(`${this.form.brief.valid_until}T23:59`),
          });
        return this.t('REVIEW.NO_END');
      };
    },
    readyCount() {
      return this.preview?.counts?.ready ?? null;
    },
  },
  watch: {
    'form.touches.attempts'(n) {
      const count = Number(n) || 1;
      this.form.touches.templates = this.form.touches.templates.slice(0, count);
      while (this.form.touches.emails.length < count) {
        this.form.touches.emails.push({ body: '', blocks: [] });
      }
      this.form.touches.emails = this.form.touches.emails.slice(0, count);
      if (this.touchTab > count) this.touchTab = count;
    },
    // Solo cuando la persona cambia el tipo (no al abrir una campaña guardada).
    'form.brief.kind'(kind) {
      if (this.loading) return;
      if (kind === 'invite' && this.sourceType === 'segment') {
        this.form.audience.source = { type: 'event' };
      }
      // Invitar: el evento tiene fecha fija, la regla de «no escribirle si otra campaña…» no aplica por omisión.
      if (kind === 'invite') this.form.brief.rest_days = 0;
      // Recordar: los contratos por vencer, con sus toques en 7, 1 y 0 días antes (cada uno según su fecha).
      if (kind === 'renew') {
        this.form.audience.source = { type: 'contracts' };
        this.form.brief.rest_days = 0;
        if (!this.form.brief.renew_source) {
          this.form.brief.renew_source = { offsets: [7, 1, 0] };
        }
        this.form.touches.attempts = this.renewOffsets.length;
        this.form.brief.offer_goal = 'done';
      }
      // Encuesta: la audiencia de entrada es «atendidos en los últimos 30 días».
      if (kind === 'survey') {
        this.form.audience.source = { type: 'served', days: 30 };
        if (!(this.form.brief.survey_items || []).length) {
          this.form.brief.survey_items = [
            { text: '', type: 'scale10', low: 7 },
          ];
        }
      }
      // Reactivar: la audiencia de entrada es «no compran desde hace 180 días».
      if (kind === 'reactivate') {
        this.form.audience.source = { type: 'inactive', days: 180 };
        this.loadCategories();
      }
      if (!this.relayChoices.includes(this.form.brief.relay)) {
        [this.form.brief.relay] = this.relayChoices;
      }
      if (!this.goals.includes(this.form.brief.offer_goal)) {
        [this.form.brief.offer_goal] = this.goals;
      }
      this.resetLabels();
    },
    'form.brief.offer_goal'() {
      if (!this.loading) this.resetLabels();
    },
    // Recordar: un toque por cada día elegido; la muestra se vuelve a contar.
    'form.brief.renew_source': {
      deep: true,
      handler() {
        if (!this.isRenew) return;
        this.form.touches.attempts = this.renewOffsets.length;
        if (this.step === 'due') this.loadPreview();
      },
    },
    // Si el paso ya no existe en este tipo (Invitar tiene otros pasos), al primero.
    steps: {
      immediate: true,
      handler(list) {
        if (!list.includes(this.step)) [this.step] = list;
      },
    },
    // Invitar: lo que la ficha sabe del evento sale del evento.
    'form.brief.event_id'() {
      if (this.loading || !this.isInvite || !this.event) return;
      this.form.brief.offer_what = this.event.name;
    },
  },
  async mounted() {
    // Segmentos y etiquetas aparte: si fallan, los vendedores y canales igual se cargan.
    [['customViews/get', FILTER_TYPE_CONTACT], ['labels/get']].forEach(
      ([action, arg]) =>
        Promise.resolve(this.$store.dispatch(action, arg)).catch(() => {})
    );
    window.addEventListener('focus', this.refreshOptions);
    try {
      const { data } = await Motor2CampaignsAPI.formOptions();
      this.options = data;
      const id = this.$route.params.campaignId;
      if (id) await this.load(Number(id));
      else {
        this.applyDefaults();
        if (!KINDS.includes(this.$route.query.kind)) this.showKindPicker = true;
      }
      if (this.campaignId && this.$route.query.step === 'review') {
        this.$nextTick(() => this.go('review'));
      }
    } catch (e) {
      this.loadFailed = !!this.$route.params.campaignId;
      useAlert(this.t('LOAD_ERROR'));
    } finally {
      this.loading = false;
      // Nueva con su tipo: se aplica ya con la pantalla lista (sus valores de fábrica).
      const { kind } = this.$route.query;
      if (!this.campaignId && KINDS.includes(kind)) this.form.brief.kind = kind;
      if (this.isReactivate) this.loadCategories();
    }
  },
  beforeDestroy() {
    window.removeEventListener('focus', this.refreshOptions);
  },
  methods: {
    t(key, params) {
      return this.$t(`CAMPAIGNS2.${key}`, params);
    },
    // Al volver a la pestaña (p. ej. después de crear el vendedor en Agentes listos) se recargan vendedores y canales.
    async refreshOptions() {
      if (this.loading) return;
      try {
        const { data } = await Motor2CampaignsAPI.formOptions();
        this.options = data;
      } catch (e) {
        // se queda lo que había
      }
    },
    go(step) {
      this.step = step;
      if (step === 'audience' || step === 'due') this.loadPreview();
      if (step === 'review') this.saveAndCheck();
    },
    next() {
      const i = this.steps.indexOf(this.step);
      if (i < this.steps.length - 1) this.go(this.steps[i + 1]);
    },
    back() {
      const i = this.steps.indexOf(this.step);
      if (i > 0) this.go(this.steps[i - 1]);
    },
    // Invitar: cuándo y dónde (y de qué trata) para la IA, tomados del evento.
    eventFacts() {
      const e = this.event;
      if (!this.isInvite || !e) return {};
      const when = e.starts_at
        ? new Date(e.starts_at).toLocaleString('es-MX', {
            weekday: 'long',
            day: 'numeric',
            month: 'long',
            hour: '2-digit',
            minute: '2-digit',
          })
        : '';
      const place = [e.location, e.meeting_url].filter(Boolean).join(' · ');
      return {
        when,
        place,
        ...(this.form.brief.facts.agenda || !e.description
          ? {}
          : { agenda: e.description }),
      };
    },
    pickKind(kind) {
      this.showKindPicker = false;
      this.$router.replace({ query: { ...this.$route.query, kind } });
      this.form.brief.kind = kind;
    },
    leave() {
      this.$router.push({ name: 'contact_trackings_campaigns' });
    },
    // Creó o editó el evento sin salir: recarga los eventos y deja elegido ese.
    async onEventSaved(event) {
      await this.refreshOptions();
      if (!event) return;
      this.form.brief.event_id = event.id;
      this.form.brief.offer_what = event.name;
    },
    // Ofrecer: qué es, precio (normal → promoción) y vigencia para la IA, tomados de los productos.
    offerFacts() {
      const rows = (this.form.brief.products || [])
        .map(p => ({ ...p, item: this.offerItems[p.catalog_item_id] }))
        .filter(p => p.item);
      if (!this.offerLike || !rows.length) return {};
      const money = (v, item) =>
        `$${Number(v).toLocaleString('es-MX', { minimumFractionDigits: 2 })} ${
          item.currency || 'MXN'
        }`;
      const facts = {
        what_is: rows
          .map(r =>
            [r.item.name, r.item.description].filter(Boolean).join(': ')
          )
          .join(' · '),
        price: rows
          .map(r =>
            r.promo_price
              ? `${r.item.name}: ${money(r.promo_price, r.item)} (antes ${money(
                  r.item.price,
                  r.item
                )})`
              : `${r.item.name}: ${money(r.item.price, r.item)}`
          )
          .join(' · '),
      };
      // Reactivar: lo que se le ofrece para que vuelva es el incentivo.
      if (this.isReactivate) {
        facts.incentive = facts.price;
        delete facts.price;
        delete facts.what_is;
      }
      if (this.form.brief.valid_until) {
        facts.valid_until = new Date(
          `${this.form.brief.valid_until}T12:00`
        ).toLocaleDateString('es-MX', { day: 'numeric', month: 'long' });
      }
      return facts;
    },
    offerName() {
      const first = (this.form.brief.products || [])[0];
      const item = first && this.offerItems[first.catalog_item_id];
      if (this.offerLike && item) return item.name;
      if (this.isRenew) {
        const id = (this.form.brief.renew_source || {}).contract_type_id;
        const type = (this.options.contract_types || []).find(
          c => String(c.id) === String(id)
        );
        return type ? type.name : '';
      }
      return '';
    },
    // Ofrecer: la foto del producto como imagen de la campaña (hace falta guardarla primero).
    async attachPhoto(catalogItemId) {
      if (!this.campaignId && !(await this.save())) return;
      try {
        await Motor2CampaignsAPI.attachProductPhoto(
          this.campaignId,
          catalogItemId
        );
        this.filesVersion += 1;
      } catch {
        // se puede subir a mano en «Imágenes y archivos»
      }
    },
    // «Información completa» de WhatsApp armada con la oferta (se puede editar).
    buildOfferContent() {
      const facts = this.offerFacts();
      const f = this.form.brief.facts || {};
      const lines = [
        facts.what_is || f.what_is,
        facts.price || f.price,
        facts.valid_until || f.valid_until
          ? this.t('OFFER_FLOW.CONTENT_VALID', {
              date: facts.valid_until || f.valid_until,
            })
          : '',
        f.conditions,
      ].filter(Boolean);
      this.form.brief.content = lines.join('\n');
    },
    // Reactivar: las categorías del Catálogo para acotar «no compran desde N días».
    async loadCategories() {
      if (this.catalogCategories.length) return;
      try {
        const { data } = await CatalogItemsAPI.parameters();
        this.catalogCategories = (data.categories || []).flatMap(c => [
          { id: c.id, label: c.name },
          ...(c.children || []).map(k => ({ id: k.id, label: `· ${k.name}` })),
        ]);
      } catch {
        this.catalogCategories = [];
      }
    },
    setAudienceSource(changes) {
      this.form.audience.source = { ...this.form.audience.source, ...changes };
      this.loadPreview();
    },
    // Lo que se ve junto a cada contacto en la muestra (Reactivar y Recordar).
    factLine(c) {
      const f = c.facts || {};
      if (this.isReactivate && f.last_purchase)
        return this.t('REACT_FLOW.LAST_PURCHASE', {
          what: f.last_purchase,
          days: f.days_since || '—',
        });
      if (f.due_what)
        return this.t('RENEW_FLOW.DUE_LINE', {
          what: f.due_what,
          date: f.due_date || '—',
          amount: f.due_amount || '',
        });
      return '';
    },
    setInviteSource(type) {
      this.setSource(type);
      if (type === 'event') {
        this.form.audience.source = {
          type,
          event_id: this.form.brief.event_id,
        };
        this.loadPreview();
      }
    },
    // Las etiquetas de fábrica del tipo y objetivo (se pueden cambiar en «Respuestas y resultados»).
    resetLabels() {
      const labels = this.kit?.labels?.[this.form.brief.offer_goal];
      this.form.brief.labels = labels ? { ...labels } : {};
      if (
        this.form.brief.offer_goal === 'external' &&
        !this.form.brief.goal_keyword
      ) {
        this.form.brief.goal_keyword = this.kit?.keyword || '';
      }
    },
    applyDefaults() {
      this.form.attend = this.copyAttend(this.options.attend);
      [this.form.brief.offer_goal] = this.goals;
      this.resetLabels();
      if (this.options.inboxes.length === 1) {
        this.form.inbox_id = this.options.inboxes[0].id;
      }
      this.form.touches.emails = this.touchNumbers.map(() => ({
        body: '',
        blocks: [],
      }));
    },
    async load(id) {
      const { data } = await Motor2CampaignsAPI.show(id);
      // Solo se modifica Guardada: una en curso o terminada abre su tablero.
      if (data.status !== 'saved') {
        this.$router.replace({
          name: 'campaigns2_detail',
          params: { campaignId: data.id },
        });
        return;
      }
      this.campaignId = data.id;
      const blank = blankForm();
      const questions = [...(data.brief?.survey_questions || []), '', '', ''];
      this.form = {
        ...blank,
        name: data.name,
        attend: this.copyAttend(data.attend || this.options.attend),
        inbox_id: data.inbox_id || '',
        brief: {
          ...blank.brief,
          ...data.brief,
          event_id: data.brief?.event_id || '',
          objections: (data.brief?.objections || []).map(o => ({ ...o })),
          facts: { ...(data.brief?.facts || {}) },
          links: (data.brief?.links || []).map(l => ({ ...l })),
          replies: { ...(data.brief?.replies || {}) },
          labels: data.brief?.labels ? { ...data.brief.labels } : null,
          goal_keyword: data.brief?.goal_keyword || '',
          relay: data.brief?.relay || '',
          relay_user_id: data.brief?.relay_user_id || '',
          relay_team_id: data.brief?.relay_team_id || '',
          survey_questions: questions.slice(0, 3),
        },
        touches: {
          ...blank.touches,
          ...data.touches,
          templates: data.touches?.templates || [],
          emails: (data.touches?.emails || []).map(e => ({
            body: e.body || '',
            blocks: e.blocks || [],
            clicked_body: e.clicked_body || '',
          })),
        },
        audience: {
          source: data.audience?.source || {
            type: data.mode === 'continuous' ? 'continuous' : 'segment',
          },
          excluded_contact_ids: data.audience?.excluded_contact_ids || [],
          contact_ids: data.audience?.contact_ids || [],
        },
        event_status: data.event_status || 'invited',
        start:
          data.scheduled_for && new Date(data.scheduled_for) > new Date()
            ? 'later'
            : 'now',
        scheduled_for: localInput(data.scheduled_for),
        ends_at: localInput(data.ends_at),
        respect_working_hours: data.respect_working_hours,
        daily_cap: data.daily_cap || '',
        entry_delay_minutes: data.entry_delay_minutes || 0,
        email_subject: data.email_subject || '',
        email_subject_b: data.email_subject_b || '',
      };
      while (this.form.touches.emails.length < this.attempts) {
        this.form.touches.emails.push({ body: '', blocks: [] });
      }
      if (this.autoName(data.name)) this.form.name = '';
      if (!this.form.brief.labels) this.resetLabels();
      // Encuesta de antes (solo textos): pasa a preguntas con tipo.
      if (
        this.form.brief.kind === 'survey' &&
        !(this.form.brief.survey_items || []).length
      ) {
        this.form.brief.survey_items = this.form.brief.survey_questions
          .filter(q => q.trim())
          .map(text => {
            const ten = /\b[01]\s*(al|a|-)\s*10\b/i.test(text);
            const five = /\b1\s*(al|a|-)\s*5\b/i.test(text);
            if (ten)
              return { text, type: 'scale10', low: data.brief.low_score || 7 };
            if (five) return { text, type: 'scale5', low: 3 };
            return { text, type: 'open', low: null };
          });
      }
    },
    body() {
      const f = this.form;
      return {
        name: f.name.trim() || this.defaultName(),
        attend: f.attend,
        inbox_id: f.inbox_id,
        mode: this.continuous ? 'continuous' : 'batch',
        brief: {
          ...f.brief,
          survey_questions: f.brief.survey_questions.filter(q => q.trim()),
          survey_items: (f.brief.survey_items || []).filter(i =>
            (i.text || '').trim()
          ),
          objections: f.brief.objections.filter(
            o => o.objection.trim() && o.answer.trim()
          ),
          links: (f.brief.links || []).filter(l => (l.url || '').trim()),
          facts: {
            ...f.brief.facts,
            ...this.eventFacts(),
            ...this.offerFacts(),
          },
          offer_what:
            this.isInvite && this.event
              ? f.brief.offer_what || this.event.name
              : f.brief.offer_what || this.offerName(),
        },
        touches: f.touches,
        audience: {
          source: f.audience.source,
          filter_payload: this.filterPayload,
          excluded_contact_ids: f.audience.excluded_contact_ids,
          contact_ids: f.audience.contact_ids || [],
        },
        event_status: f.event_status,
        scheduled_for:
          f.start === 'later' && f.scheduled_for
            ? new Date(f.scheduled_for).toISOString()
            : null,
        ends_at: f.ends_at ? new Date(f.ends_at).toISOString() : null,
        respect_working_hours: f.respect_working_hours,
        daily_cap: f.daily_cap || null,
        entry_delay_minutes: f.entry_delay_minutes || 0,
        email_subject: f.email_subject,
        email_subject_b: f.email_subject_b,
      };
    },
    // El que se arma solo (o el de antes, que se quedaba en «Invitar»): se sigue armando con el evento/producto.
    autoName(name) {
      const title = this.t(`KINDS.${this.kind}.TITLE`);
      return (
        !name ||
        name === 'Campaña sin nombre' ||
        name === title ||
        name.startsWith(`${title} — `)
      );
    },
    defaultName() {
      const what =
        this.kind === 'invite'
          ? this.event?.name
          : this.form.brief.offer_what || this.offerName();
      return [this.t(`KINDS.${this.kind}.TITLE`), what]
        .filter(Boolean)
        .join(' — ')
        .slice(0, 120);
    },
    // Se guarda en cualquier momento (aunque falte el canal): lo que falte lo marca «Revisar y lanzar».
    // Editando (la dirección trae su número) siempre se modifica esa; si no se pudo cargar, no se guarda una copia.
    async save() {
      if (this.loadFailed) {
        useAlert(this.t('LOAD_ERROR'));
        return false;
      }
      this.campaignId =
        this.campaignId || Number(this.$route.params.campaignId) || null;
      this.saving = true;
      try {
        const { data } = this.campaignId
          ? await Motor2CampaignsAPI.update(this.campaignId, this.body())
          : await Motor2CampaignsAPI.create(this.body());
        this.campaignId = data.id;
        return true;
      } catch (e) {
        useAlert(e.response?.data?.error || this.t('SAVE_ERROR'));
        return false;
      } finally {
        this.saving = false;
      }
    },
    async saveDraft() {
      if (await this.save()) {
        useAlert(this.t('SAVED'));
        this.$router.push({ name: 'contact_trackings_campaigns' });
      }
    },
    async saveAndCheck() {
      this.checkError = false;
      if (!(await this.save())) {
        this.checkError = true;
        return;
      }
      try {
        const { data } = await Motor2CampaignsAPI.check(this.campaignId);
        this.checks = data.items || [];
      } catch (e) {
        this.checkError = true;
      }
    },
    async launch() {
      await this.saveAndCheck();
      if (this.errors.length) return;
      this.saving = true;
      try {
        await Motor2CampaignsAPI.launch(this.campaignId);
        useAlert(this.t('LAUNCHED'));
        this.$router.push({
          name: 'campaigns2_detail',
          params: { campaignId: this.campaignId },
        });
      } catch (e) {
        if (e.response?.data?.items) this.checks = e.response.data.items;
        useAlert(e.response?.data?.error || this.t('LAUNCH_ERROR'));
      } finally {
        this.saving = false;
      }
    },
    async loadPreview() {
      if (this.continuous || !this.filterPayload.length || !this.hasChannel) {
        this.preview = null;
        return;
      }
      this.previewLoading = true;
      try {
        const { data } = await Motor2CampaignsAPI.preview({
          payload: this.filterPayload,
          template_id: null,
          inbox_id: this.form.inbox_id,
          excluded_contact_ids: this.form.audience.excluded_contact_ids,
          facts: this.previewFacts ? 1 : undefined,
        });
        this.preview = data;
      } catch (e) {
        this.preview = null;
      } finally {
        this.previewLoading = false;
      }
    },
    setSource(type) {
      if (type === 'list' && !this.isEmail)
        this.form.inbox_id = this.emailInboxes[0]?.id || '';
      this.form.audience.source = { type };
      this.form.audience.excluded_contact_ids = [];
      this.loadPreview();
    },
    toggleExclude(id) {
      const list = this.form.audience.excluded_contact_ids;
      this.form.audience.excluded_contact_ids = list.includes(id)
        ? list.filter(x => x !== id)
        : [...list, id];
      this.loadPreview();
    },
    setTemplate(n, name) {
      const list = [...this.form.touches.templates];
      list[n - 1] = name;
      this.form.touches.templates = list;
    },
    setEmail(n, value) {
      const list = [...this.form.touches.emails];
      list[n - 1] = value;
      this.form.touches.emails = list;
    },
    async uploadList() {
      if (!this.listFile) return;
      if (!(await this.save())) return;
      this.uploading = true;
      try {
        const { data } = await Motor2CampaignsAPI.uploadList(
          this.campaignId,
          this.listFile,
          this.listName,
          this.listDays
        );
        this.listInfo = data.list;
        this.form.audience = {
          ...this.form.audience,
          source: data.campaign.audience.source,
          contact_ids: data.campaign.audience.contact_ids,
        };
        if (!this.form.daily_cap) this.form.daily_cap = 200;
        this.form.brief.warmup = true;
      } catch (e) {
        useAlert(e.response?.data?.error || this.t('LIST.ERROR'));
      } finally {
        this.uploading = false;
      }
    },
    async sendTestEmail() {
      this.sendingTest = true;
      try {
        const { data } = await Motor2CampaignsAPI.testEmail({
          email_signature: this.form.attend?.email_signature,
          subject: this.form.email_subject,
          body: this.currentEmail.body,
        });
        useAlert(this.t('EMAIL.TEST_SENT', { email: data.sent_to }));
      } catch (e) {
        useAlert(this.t('EMAIL.TEST_ERROR'));
      } finally {
        this.sendingTest = false;
      }
    },
    // «Probar»: con «Cómo atiende» y la oferta de la pantalla (sin guardar).
    chatPayload() {
      return {
        campaign_id: this.campaignId,
        brief: this.body().brief,
        attend: this.form.attend,
        opener: this.opener,
      };
    },
    setClickedBody(value) {
      this.setEmail(this.touchTab, {
        ...this.currentEmail,
        clicked_body: value,
      });
    },
    copyAttend(attend) {
      const base = attend || {
        display_name: '',
        sources: [],
        email_signature: '',
        settings: {},
      };
      return JSON.parse(
        JSON.stringify({ ...base, settings: base.settings || {} })
      );
    },
    levelClass(level) {
      return {
        ok: 'text-green-700 dark:text-green-400',
        warning: 'text-amber-700 dark:text-amber-400',
        error: 'text-red-600',
      }[level];
    },
    levelIcon(level) {
      return {
        ok: 'checkmark-circle',
        warning: 'warning',
        error: 'dismiss-circle',
      }[level];
    },
  },
};
</script>

<template>
  <div class="flex flex-col w-full h-full min-h-0 p-4 overflow-hidden">
    <div class="flex items-start justify-between gap-3 mb-2 shrink-0">
      <div class="flex items-start gap-2">
        <woot-sidemenu-icon />
        <div>
          <!-- Nueva/Modificar + tipo + nombre de la campaña (editable aquí mismo) -->
          <div class="flex flex-wrap items-center gap-2">
            <h1
              class="m-0 text-xl font-bold text-slate-800 dark:text-slate-100"
            >
              {{ campaignId ? t('EDIT_TITLE') : t('NEW_TITLE') }}
            </h1>
            <template v-if="!showKindPicker && !loading">
              <span
                class="px-2 py-0.5 text-xs font-semibold rounded-full bg-woot-50 text-woot-700 dark:bg-woot-900/30 dark:text-woot-200"
              >
                {{ t(`KINDS.${kind}.TITLE`) }}
              </span>
              <input
                v-model="form.name"
                v-tooltip.bottom="t('NAME')"
                type="text"
                maxlength="120"
                :aria-label="t('NAME')"
                class="!mb-0 !py-1 !w-[28rem] max-w-full !text-base font-semibold"
                :placeholder="defaultName() || t('NAME_PLACEHOLDER')"
              />
            </template>
          </div>
          <p
            v-if="showKindPicker || loading"
            class="m-0 mt-1 text-sm text-slate-600 dark:text-slate-400"
          >
            {{ t('SUBTITLE') }}
          </p>
          <p v-else class="m-0 mt-1 text-xs text-slate-500">
            {{ t('NAME') }} · {{ t('NAME_HINT') }}
          </p>
        </div>
      </div>
      <woot-button
        variant="smooth"
        color-scheme="secondary"
        icon="chevron-left"
        @click="$router.push({ name: 'contact_trackings_campaigns' })"
      >
        {{ t('BACK') }}
      </woot-button>
    </div>

    <p v-if="loading" class="text-sm text-slate-500">{{ t('LOADING') }}</p>
    <template v-else>
      <WizardTabs
        :steps="steps"
        :current="step"
        :labels="stepLabels"
        @go="go"
      />
      <div
        class="grid flex-1 min-h-0 grid-cols-1 gap-6 pt-3 overflow-y-auto md:grid-cols-5 md:overflow-hidden"
      >
        <!-- Izquierda: el paso (Invitar: a lo ancho donde no hace falta la vista previa) -->
        <div
          class="flex flex-col gap-3 pr-1 md:overflow-y-auto"
          :class="showSide ? 'md:col-span-3' : 'md:col-span-5 max-w-4xl'"
        >
          <p class="m-0 text-xs text-slate-500">{{ stepHint }}</p>

          <!-- Ofrecer · 1 · La oferta: productos, promoción, vigencia y lo que sabe la IA -->
          <OfferProducts
            v-if="step === 'offer'"
            :kind="kind"
            :brief.sync="form.brief"
            :kit="kit"
            :campaign-id="campaignId"
            :save="save"
            :attempts="attempts"
            :files-version="filesVersion"
            @photo="attachPhoto"
            @catalog="offerItems = { ...$event }"
          />

          <!-- Encuesta · 1 · Las preguntas con tipo · 2 · Si califica bajo -->
          <SurveyQuestions
            v-if="step === 'questions'"
            :brief.sync="form.brief"
            :kit="kit"
            :campaign-id="campaignId"
            :save="save"
            :attempts="attempts"
          />
          <SurveyLow
            v-if="step === 'low'"
            :brief.sync="form.brief"
            :kit="kit"
            :users="options.users"
            :teams="options.teams"
            :case-types="options.case_types || []"
          />

          <!-- Ofrecer · 2 · Cuando le interesa: el objetivo y lo que hace la IA -->
          <OfferInterest
            v-if="step === 'interest'"
            :brief.sync="form.brief"
            :attend.sync="form.attend"
            :kit="kit"
            :users="options.users"
            :teams="options.teams"
            :calendar-users="options.calendar_users || []"
            :sources="options.sources || []"
            :templates="inboxTemplates"
          />

          <!-- Invitar · 1 · El evento: tipo, evento, cómo confirma y lo que solo sabe la empresa -->
          <template v-if="step === 'event'">
            <InviteEvent
              :brief.sync="form.brief"
              :events="options.events"
              :event="event"
              :kit="kit"
              :goals="goals"
              :campaign-id="campaignId"
              :save="save"
              :attempts="attempts"
              @eventSaved="onEventSaved"
            />
          </template>

          <!-- 1 · Objetivo: tipo, qué cuenta como logrado, nombre corto y canal -->
          <template v-if="step === 'goal'">
            <fieldset v-if="goals.length > 1" class="flex flex-col gap-1">
              <legend class="field-label">{{ t('GOAL.QUESTION') }}</legend>
              <label
                v-for="g in goals"
                :key="g"
                class="flex items-start gap-2 text-sm"
              >
                <input
                  v-model="form.brief.offer_goal"
                  type="radio"
                  class="!m-0 mt-1"
                  :value="g"
                />
                <span>
                  {{ t(`GOAL.${g}.${kind}`) }}
                  <span class="block text-xs text-slate-500">
                    {{ t(`GOAL.${g}.ABOUT`) }}
                  </span>
                </span>
              </label>
            </fieldset>
            <label
              v-if="form.brief.offer_goal === 'external'"
              class="flex flex-wrap items-center gap-2 text-sm"
            >
              {{ t('GOAL.KEYWORD') }}
              <input
                v-model="form.brief.goal_keyword"
                type="text"
                maxlength="40"
                class="!mb-0 !w-40 uppercase"
                :placeholder="kit ? kit.keyword : ''"
              />
              <span class="block w-full text-xs text-slate-500">
                {{ t('GOAL.KEYWORD_HINT') }}
              </span>
            </label>
            <label v-if="kind === 'invite'" class="block">
              <span class="field-label">{{ t('OFFER.EVENT') }}</span>
              <select v-model="form.brief.event_id">
                <option value="">{{ t('OFFER.EVENT_PICK') }}</option>
                <option v-for="e in options.events" :key="e.id" :value="e.id">
                  {{ e.name }}
                </option>
              </select>
              <span
                v-if="!options.events.length"
                class="block text-xs text-amber-700"
              >
                {{ t('OFFER.NO_EVENTS') }}
              </span>
            </label>
            <label v-if="kind !== 'survey'" class="block">
              <span class="field-label">{{ t(`OFFER.WHAT.${kind}`) }}</span>
              <input
                v-model="form.brief.offer_what"
                type="text"
                maxlength="200"
                :placeholder="t(`OFFER.WHAT_PLACEHOLDER.${kind}`)"
              />
              <span class="block text-xs text-slate-500">
                {{ t('OFFER.WHAT_HINT') }}
              </span>
            </label>
            <label class="block">
              <span class="field-label">{{ t('MESSAGES.CHANNEL') }}</span>
              <select v-model="form.inbox_id">
                <option value="">{{ t('MESSAGES.CHANNEL_PICK') }}</option>
                <option v-for="i in options.inboxes" :key="i.id" :value="i.id">
                  {{ i.name }} ·
                  {{
                    t(
                      `MESSAGES.TYPES.${i.channel_type.replace(
                        'Channel::',
                        ''
                      )}`
                    )
                  }}
                </option>
              </select>
              <span class="block text-xs text-slate-500">
                {{ t('MESSAGES.CHANNEL_HINT') }}
              </span>
            </label>
            <label class="block">
              <span class="field-label">{{ t('NAME') }}</span>
              <input
                v-model="form.name"
                type="text"
                maxlength="120"
                :placeholder="defaultName() || t('NAME_PLACEHOLDER')"
              />
            </label>
          </template>

          <!-- 2 · La ficha: lo que sabe la IA -->
          <CampaignKnowledge
            v-if="step === 'knowledge'"
            :brief.sync="form.brief"
            :kind="kind"
            :kit="kit"
            :event="event"
            :campaign-id="campaignId"
            :save="save"
            :attempts="attempts"
          />

          <!-- 3 · Audiencia (Invitar: «Invitados», con el canal arriba) -->
          <!-- Recordar · 1 · Qué recuerdas: los contratos y los días; debajo, canal y muestra -->
          <RenewDue
            v-if="step === 'due'"
            :brief.sync="form.brief"
            :contract-types="options.contract_types || []"
          />
          <!-- Recordar · 2 · Cómo se paga -->
          <RenewPay
            v-if="step === 'pay'"
            :brief.sync="form.brief"
            :kit="kit"
            :users="options.users"
            :teams="options.teams"
            :campaign-id="campaignId"
            :save="save"
            :attempts="attempts"
          />
          <template v-if="step === 'audience' || step === 'due'">
            <label v-if="guided" class="block">
              <span class="field-label">{{ t('MESSAGES.CHANNEL') }}</span>
              <select v-model="form.inbox_id" @change="loadPreview">
                <option value="">{{ t('MESSAGES.CHANNEL_PICK') }}</option>
                <option v-for="i in options.inboxes" :key="i.id" :value="i.id">
                  {{ i.name }} ·
                  {{
                    t(
                      `MESSAGES.TYPES.${i.channel_type.replace(
                        'Channel::',
                        ''
                      )}`
                    )
                  }}
                </option>
              </select>
              <span class="block text-xs text-slate-500">
                {{ t('MESSAGES.CHANNEL_HINT') }}
              </span>
            </label>
            <span v-if="guided && audienceTypes.length > 1" class="field-label">
              {{ t(`${guideKey}.WHO`) }}
            </span>
            <div v-if="audienceTypes.length > 1" class="flex flex-wrap gap-2">
              <button
                v-for="type in audienceTypes"
                :key="type"
                type="button"
                class="px-3 py-1.5 text-sm border rounded-full"
                :class="
                  sourceType === type
                    ? 'border-woot-500 text-woot-700 bg-woot-25 dark:bg-woot-900/20'
                    : 'border-slate-200 dark:border-slate-600 text-slate-600 dark:text-slate-300'
                "
                @click="
                  isInvite
                    ? setInviteSource(type)
                    : type === 'inactive'
                    ? setAudienceSource({ type, days: 180 })
                    : type === 'served'
                    ? setAudienceSource({ type, days: 30 })
                    : setSource(type)
                "
              >
                {{ t(`AUDIENCE.${type}`) }}
              </button>
            </div>
            <p v-if="sourceType === 'campaign'" class="m-0 text-sm">
              {{
                t('AUDIENCE.FROM_CAMPAIGN', {
                  n: (form.audience.contact_ids || []).length,
                })
              }}
            </p>
            <!-- Encuesta: los que atendimos en los últimos N días -->
            <label v-if="sourceType === 'served'" class="block">
              <span class="field-label">{{ t('SURVEY_FLOW.DAYS') }}</span>
              <input
                :value="form.audience.source.days || 30"
                type="number"
                min="1"
                max="365"
                class="!mb-0 !w-40"
                @change="
                  setAudienceSource({ days: Number($event.target.value) || 30 })
                "
              />
              <span class="block text-xs text-slate-500">
                {{ t('SURVEY_FLOW.DAYS_HINT') }}
              </span>
            </label>
            <!-- Reactivar: no compran desde hace N días (y, si quieres, de una categoría) -->
            <div
              v-if="sourceType === 'inactive'"
              class="grid grid-cols-1 gap-2 sm:grid-cols-2"
            >
              <label class="block">
                <span class="field-label">{{ t('REACT_FLOW.DAYS') }}</span>
                <input
                  :value="form.audience.source.days || 180"
                  type="number"
                  min="1"
                  max="3650"
                  class="!mb-0"
                  @change="
                    setAudienceSource({
                      days: Number($event.target.value) || 180,
                    })
                  "
                />
              </label>
              <label class="block">
                <span class="field-label">{{ t('REACT_FLOW.CATEGORY') }}</span>
                <select
                  :value="form.audience.source.category_id || ''"
                  class="!mb-0"
                  @change="
                    setAudienceSource({ category_id: $event.target.value })
                  "
                >
                  <option value="">{{ t('REACT_FLOW.ANY_CATEGORY') }}</option>
                  <option
                    v-for="cat in catalogCategories"
                    :key="cat.id"
                    :value="cat.id"
                  >
                    {{ cat.label }}
                  </option>
                </select>
              </label>
              <p class="m-0 text-xs text-slate-500 sm:col-span-2">
                {{ t('REACT_FLOW.DAYS_HINT') }}
              </p>
            </div>
            <label v-if="sourceType === 'segment'" class="block">
              <span class="field-label">{{ t('AUDIENCE.SEGMENT') }}</span>
              <select
                v-model="form.audience.source.segment_id"
                @change="loadPreview"
              >
                <option :value="undefined">{{ t('AUDIENCE.PICK') }}</option>
                <option v-for="s in segments" :key="s.id" :value="s.id">
                  {{ s.name }}
                </option>
              </select>
            </label>
            <label v-if="sourceType === 'label'" class="block">
              <span class="field-label">{{ t('AUDIENCE.LABEL') }}</span>
              <select
                v-model="form.audience.source.label"
                @change="loadPreview"
              >
                <option :value="undefined">{{ t('AUDIENCE.PICK') }}</option>
                <option v-for="l in labels" :key="l.id" :value="l.title">
                  {{ l.title }}
                </option>
              </select>
            </label>
            <div
              v-if="sourceType === 'event'"
              class="grid grid-cols-1 gap-2 sm:grid-cols-2"
            >
              <label class="block">
                <span class="field-label">{{ t('AUDIENCE.EVENT_OF') }}</span>
                <select
                  :value="audienceEventId"
                  @change="
                    form.audience.source = {
                      ...form.audience.source,
                      event_id: $event.target.value,
                    };
                    loadPreview();
                  "
                >
                  <option value="">{{ t('OFFER.EVENT_PICK') }}</option>
                  <option v-for="e in audienceEvents" :key="e.id" :value="e.id">
                    {{ e.name }}
                  </option>
                </select>
              </label>
              <label class="block">
                <span class="field-label">{{ t('AUDIENCE.ATTENDEES') }}</span>
                <select v-model="form.event_status" @change="loadPreview">
                  <option v-for="s in attendeeStatuses" :key="s" :value="s">
                    {{ t(`AUDIENCE.STATUS.${s}`) }}
                  </option>
                </select>
              </label>
            </div>
            <p v-if="continuous" class="m-0 text-sm text-slate-600">
              {{ t('AUDIENCE.CONTINUOUS_HINT') }}
            </p>

            <!-- Lista fría de correos: solo correo; sus contactos nuevos quedan en cuarentena -->
            <div
              v-if="isList"
              class="flex flex-col gap-2 p-3 border rounded-md border-slate-100 dark:border-slate-700"
            >
              <p class="m-0 text-xs text-slate-600 dark:text-slate-300">
                {{ t('LIST.HINT') }}
              </p>
              <p class="m-0 text-xs text-amber-700">
                {{ t('LIST.ONLY_EMAIL') }}
              </p>
              <label class="block">
                <span class="field-label">{{ t('LIST.INBOX') }}</span>
                <select v-model="form.inbox_id">
                  <option value="">{{ t('MESSAGES.CHANNEL_PICK') }}</option>
                  <option v-for="i in emailInboxes" :key="i.id" :value="i.id">
                    {{ i.name }}
                  </option>
                </select>
                <span
                  v-if="!emailInboxes.length"
                  class="block text-xs text-red-600"
                >
                  {{ t('LIST.NO_EMAIL_INBOX') }}
                </span>
              </label>
              <template v-if="isEmail">
                <div class="grid grid-cols-1 gap-2 sm:grid-cols-2">
                  <label class="block">
                    <span class="field-label">{{ t('LIST.NAME') }}</span>
                    <input
                      v-model="listName"
                      type="text"
                      maxlength="160"
                      :placeholder="t('LIST.NAME_PLACEHOLDER')"
                    />
                  </label>
                  <label class="block">
                    <span class="field-label">{{ t('LIST.CLEANUP') }}</span>
                    <input
                      v-model.number="listDays"
                      type="number"
                      min="1"
                      max="365"
                    />
                  </label>
                </div>
                <p class="m-0 text-xs text-slate-500">
                  {{ t('LIST.COLUMNS') }}
                </p>
                <div class="flex flex-wrap items-center gap-2">
                  <input
                    type="file"
                    accept=".csv,text/csv"
                    class="!mb-0 text-sm"
                    @change="listFile = $event.target.files[0] || null"
                  />
                  <woot-button
                    size="small"
                    icon="arrow-upload"
                    :is-loading="uploading"
                    :disabled="!listFile || !hasChannel"
                    @click="uploadList"
                  >
                    {{ t('LIST.UPLOAD') }}
                  </woot-button>
                </div>
                <p v-if="!hasChannel" class="m-0 text-xs text-amber-700">
                  {{ t('LIST.NEEDS_SELLER') }}
                </p>
              </template>
              <div
                v-if="listInfo"
                class="p-2 text-sm rounded-md bg-slate-25 dark:bg-slate-800"
              >
                <p class="m-0 font-medium">
                  {{
                    t('LIST.RESULT', {
                      rows: listInfo.rows,
                      valid: listInfo.valid,
                      created: listInfo.created,
                      existing: listInfo.existing,
                    })
                  }}
                </p>
                <p
                  v-for="(n, reason) in listInfo.discarded"
                  :key="reason"
                  class="m-0 text-xs text-slate-500"
                >
                  {{ t(`LIST.DISCARDED.${reason}`, { n }) }}
                </p>
              </div>
              <p v-else-if="form.audience.source.list_id" class="m-0 text-sm">
                {{
                  t('LIST.LOADED', {
                    name: form.audience.source.name,
                    n: (form.audience.contact_ids || []).length,
                  })
                }}
              </p>
            </div>

            <!-- Cuántos le llegan y quiénes se excluyen -->
            <div
              v-if="!continuous && !isList && sourceType !== 'campaign'"
              class="p-3 rounded-md bg-slate-25 dark:bg-slate-800"
            >
              <p v-if="!hasChannel" class="m-0 text-xs text-amber-700">
                {{ t('AUDIENCE.NEEDS_CHANNEL') }}
              </p>
              <p v-else-if="previewLoading" class="m-0 text-xs text-slate-500">
                {{ t('AUDIENCE.COUNTING') }}
              </p>
              <template v-else-if="preview">
                <div class="grid grid-cols-2 gap-2 sm:grid-cols-4">
                  <div
                    v-for="b in [
                      'ready',
                      'in_tracking',
                      'unreachable',
                      'excluded',
                    ]"
                    :key="b"
                    class="p-2 bg-white rounded-md dark:bg-slate-900"
                  >
                    <p class="m-0 text-lg font-semibold">
                      {{ (preview.counts || {})[b] || 0 }}
                    </p>
                    <p class="m-0 text-xs text-slate-500">
                      {{ t(`AUDIENCE.BUCKETS.${b}`) }}
                    </p>
                  </div>
                </div>
                <div
                  v-if="(preview.contacts || []).length"
                  class="mt-2 overflow-y-auto max-h-60"
                >
                  <label
                    v-for="c in preview.contacts"
                    :key="c.id"
                    class="flex items-center justify-between gap-2 py-1 text-sm border-b border-slate-50 dark:border-slate-700"
                  >
                    <span class="flex items-center gap-2">
                      <input
                        type="checkbox"
                        class="!m-0"
                        :checked="!c.excluded"
                        @change="toggleExclude(c.id)"
                      />
                      {{ c.name }}
                      <span class="text-xs text-slate-500">
                        {{ isWhatsapp ? c.phone_number : c.email }}
                      </span>
                      <span
                        v-if="factLine(c)"
                        class="text-xs text-woot-700 dark:text-woot-300"
                      >
                        {{ factLine(c) }}
                      </span>
                    </span>
                    <span
                      v-if="c.bucket !== 'ready'"
                      class="text-xs text-amber-700"
                    >
                      {{ t(`AUDIENCE.BUCKETS.${c.bucket}`) }}
                    </span>
                  </label>
                </div>
              </template>
              <p v-else class="m-0 text-xs text-slate-500">
                {{ t('AUDIENCE.PICK_FIRST') }}
              </p>
            </div>
          </template>

          <!-- 4 · Mensajes -->
          <template v-if="step === 'messages'">
            <p class="m-0 text-xs text-slate-500">
              {{
                t('MESSAGES.CHANNEL_IS', {
                  name: inbox ? inbox.name : '—',
                })
              }}
            </p>
            <!-- Recordar: los toques salen en sus días antes de vencer (no «cada N días») -->
            <p v-if="isRenew" class="m-0 text-sm">
              {{ t('RENEW_FLOW.PACE', { days: renewOffsets.join(', ') }) }}
            </p>
            <div v-else class="flex flex-wrap items-center gap-2 text-sm">
              {{ t('MESSAGES.TOUCHES') }}
              <select
                v-model.number="form.touches.attempts"
                class="!mb-0 !w-20"
              >
                <option v-for="n in [1, 2, 3, 4, 5, 6]" :key="n" :value="n">
                  {{ n }}
                </option>
              </select>
              {{ t('MESSAGES.EVERY') }}
              <input
                v-model.number="form.touches.every_value"
                type="number"
                min="1"
                max="30"
                class="!mb-0 !w-16"
              />
              <select v-model="form.touches.every_unit" class="!mb-0 !w-28">
                <option value="hours">{{ t('MESSAGES.HOURS') }}</option>
                <option value="days">{{ t('MESSAGES.DAYS') }}</option>
              </select>
            </div>
            <p v-if="!isRenew" class="m-0 text-xs text-slate-500">
              {{ t('MESSAGES.TOUCHES_HINT') }}
            </p>

            <p v-if="isList && !isEmail" class="m-0 text-xs text-red-600">
              {{ t('LIST.ONLY_EMAIL') }}
            </p>
            <WhatsappFlow
              v-if="isWhatsapp"
              :touches.sync="form.touches"
              :brief.sync="form.brief"
              :templates="inbox.templates"
              :attempts="attempts"
              :kind="kind"
              :event="event"
              :links="form.brief.links"
            />

            <template v-if="isEmail">
              <div class="grid grid-cols-1 gap-2 sm:grid-cols-2">
                <label class="block">
                  <span class="field-label">{{ t('EMAIL.SUBJECT') }}</span>
                  <input
                    v-model="form.email_subject"
                    type="text"
                    maxlength="150"
                    :placeholder="t('EMAIL.SUBJECT_PLACEHOLDER')"
                  />
                </label>
                <label class="block">
                  <span class="field-label">{{ t('EMAIL.SUBJECT_B') }}</span>
                  <input
                    v-model="form.email_subject_b"
                    type="text"
                    maxlength="150"
                    :placeholder="t('EMAIL.SUBJECT_B_PLACEHOLDER')"
                  />
                </label>
              </div>
              <div class="flex flex-wrap gap-2">
                <button
                  v-for="n in touchNumbers"
                  :key="n"
                  type="button"
                  class="px-3 py-1 text-xs border rounded-full"
                  :class="
                    touchTab === n
                      ? 'border-woot-500 text-woot-700'
                      : 'border-slate-200 dark:border-slate-600 text-slate-600'
                  "
                  @click="touchTab = n"
                >
                  {{ t('EMAIL.TOUCH', { n }) }}
                </button>
              </div>
              <EmailEditor
                :key="touchTab"
                :value="currentEmail"
                :signature="form.attend ? form.attend.email_signature : ''"
                :vars="emailVars"
                @input="setEmail(touchTab, $event)"
              />
              <label v-if="touchTab > 1" class="block">
                <span class="field-label">{{ t('EMAIL.CLICKED') }}</span>
                <textarea
                  :value="currentEmail.clicked_body"
                  rows="3"
                  maxlength="6000"
                  :placeholder="t('EMAIL.CLICKED_PLACEHOLDER')"
                  @input="setClickedBody($event.target.value)"
                />
                <span class="block text-xs text-slate-500">
                  {{ t('EMAIL.CLICKED_HINT') }}
                </span>
              </label>
              <div>
                <woot-button
                  size="small"
                  variant="smooth"
                  icon="mail"
                  :is-loading="sendingTest"
                  :disabled="!currentEmail.body"
                  @click="sendTestEmail"
                >
                  {{ t('EMAIL.SEND_TEST') }}
                </woot-button>
              </div>
            </template>
            <p v-if="!inbox" class="m-0 text-xs text-slate-500">
              {{ t('MESSAGES.PICK_CHANNEL_FIRST') }}
            </p>
            <!-- Ofrecer: la información completa armada con la oferta y si contestó y se calla -->
            <template v-if="offerLike">
              <button
                v-if="isWhatsapp"
                type="button"
                class="self-start text-sm text-woot-600 hover:underline"
                @click="buildOfferContent"
              >
                {{ t('OFFER_FLOW.BUILD_CONTENT') }}
              </button>
              <section
                v-if="form.attend"
                class="flex flex-col gap-2 p-3 border rounded-md border-slate-100 dark:border-slate-700"
              >
                <p class="m-0 text-sm font-semibold">
                  {{ t('OFFER_FLOW.SILENT_TITLE') }}
                </p>
                <p class="m-0 text-xs text-slate-500">
                  {{ t('OFFER_FLOW.SILENT_HINT') }}
                </p>
                <FollowUpPlan
                  :value="
                    (form.attend.settings || {}).follow_up || {
                      nudges: 2,
                      templates: [],
                    }
                  "
                  :templates="inboxTemplates"
                  :quote="(form.attend.settings || {}).quote"
                  kind="campaign_seller"
                  @input="
                    form.attend = {
                      ...form.attend,
                      settings: { ...form.attend.settings, follow_up: $event },
                    }
                  "
                />
              </section>
            </template>
            <!-- Invitar: recordatorios a los que confirmaron -->
            <EventReminders
              v-if="isInvite"
              :brief.sync="form.brief"
              :is-whatsapp="isWhatsapp"
              :templates="inboxTemplates"
            />
          </template>

          <!-- 5 · Respuestas y resultados -->
          <CampaignReplies
            v-if="step === 'replies'"
            :brief.sync="form.brief"
            :kind="kind"
            :kit="kit"
            :compact="guided"
          />
          <!-- Invitar: a quién pasa si pide una persona y «Cómo atiende» en opciones avanzadas -->
          <template v-if="step === 'replies' && guided">
            <section
              v-if="isInvite"
              class="grid grid-cols-1 gap-2 p-3 border rounded-md sm:grid-cols-2 border-slate-100 dark:border-slate-700"
            >
              <p class="m-0 text-sm font-semibold sm:col-span-2">
                {{ t('INVITE.PERSON_TITLE') }}
              </p>
              <label class="block">
                <span class="field-label">{{ t('OFFER.RELAY_USER') }}</span>
                <select v-model="form.brief.relay_user_id">
                  <option value="">{{ t('OFFER.NOBODY') }}</option>
                  <option v-for="u in options.users" :key="u.id" :value="u.id">
                    {{ u.name }}
                  </option>
                </select>
              </label>
              <label class="block">
                <span class="field-label">{{ t('OFFER.RELAY_TEAM') }}</span>
                <select v-model="form.brief.relay_team_id">
                  <option value="">{{ t('OFFER.NO_TEAM') }}</option>
                  <option
                    v-for="team in options.teams"
                    :key="team.id"
                    :value="team.id"
                  >
                    {{ team.name }}
                  </option>
                </select>
              </label>
            </section>
            <button
              type="button"
              class="self-start text-sm text-woot-600 hover:underline"
              @click="showAdvanced = !showAdvanced"
            >
              {{
                showAdvanced ? t('INVITE.HIDE_ADVANCED') : t('INVITE.ADVANCED')
              }}
            </button>
            <CampaignAttend
              v-if="showAdvanced && form.attend"
              v-model="form.attend"
              :sources="options.sources || []"
              :calendar-users="options.calendar_users || []"
              :templates="inboxTemplates"
              :is-email="isEmail"
              :appointments="false"
              :only="['who', 'knows', 'notes']"
            />
          </template>

          <!-- 6 · Cómo atiende (la campaña arma su agente) -->
          <template v-if="step === 'attend'">
            <CampaignAttend
              v-if="form.attend"
              v-model="form.attend"
              :sources="options.sources || []"
              :calendar-users="options.calendar_users || []"
              :templates="inboxTemplates"
              :is-email="isEmail"
              :appointments="form.brief.offer_goal === 'appointment'"
            />
            <!-- Si le interesa (o pide una persona), a quién pasa -->
            <span class="field-label">{{ t('OFFER.RELAY_TITLE') }}</span>
            <label
              v-for="value in relayChoices"
              :key="value"
              class="flex items-start gap-2 text-sm"
            >
              <input
                v-model="form.brief.relay"
                type="radio"
                class="!m-0 mt-1"
                :value="value"
              />
              {{ t(`OFFER.RELAY_CHOICES.${value}`) }}
            </label>
            <div
              v-if="form.brief.relay === 'person' || relayChoices.length === 1"
              class="grid grid-cols-1 gap-2 sm:grid-cols-2"
            >
              <label class="block">
                <span class="field-label">{{ t('OFFER.RELAY_USER') }}</span>
                <select v-model="form.brief.relay_user_id">
                  <option value="">{{ t('OFFER.NOBODY') }}</option>
                  <option v-for="u in options.users" :key="u.id" :value="u.id">
                    {{ u.name }}
                  </option>
                </select>
              </label>
              <label class="block">
                <span class="field-label">{{ t('OFFER.RELAY_TEAM') }}</span>
                <select v-model="form.brief.relay_team_id">
                  <option value="">{{ t('OFFER.NO_TEAM') }}</option>
                  <option
                    v-for="team in options.teams"
                    :key="team.id"
                    :value="team.id"
                  >
                    {{ team.name }}
                  </option>
                </select>
              </label>
            </div>
          </template>

          <template v-if="step === 'when'">
            <label class="flex flex-wrap items-center gap-2 text-sm">
              {{ t('OFFER.REST_DAYS') }}
              <input
                v-model.number="form.brief.rest_days"
                type="number"
                min="0"
                max="90"
                class="!mb-0 !w-20"
              />
              {{ t('OFFER.DAYS') }}
            </label>
            <p class="m-0 text-xs text-slate-500">{{ t('OFFER.REST_HINT') }}</p>
            <fieldset class="flex flex-col gap-1">
              <legend class="field-label">{{ t('WHEN.START') }}</legend>
              <label class="flex items-center gap-2 text-sm">
                <input
                  v-model="form.start"
                  type="radio"
                  class="!m-0"
                  value="now"
                />
                {{ t('WHEN.NOW') }}
              </label>
              <label class="flex items-center gap-2 text-sm">
                <input
                  v-model="form.start"
                  type="radio"
                  class="!m-0"
                  value="later"
                />
                {{ t('WHEN.LATER') }}
              </label>
              <input
                v-if="form.start === 'later'"
                v-model="form.scheduled_for"
                type="datetime-local"
                class="!mb-0 !w-64"
              />
            </fieldset>
            <label class="block">
              <span class="field-label">{{ t('WHEN.ENDS') }}</span>
              <input
                v-model="form.ends_at"
                type="datetime-local"
                class="!mb-0 !w-64"
              />
            </label>
            <label class="flex items-center gap-2 text-sm">
              <input
                v-model="form.respect_working_hours"
                type="checkbox"
                class="!m-0"
              />
              {{ t('WHEN.WORKING_HOURS') }}
            </label>
            <label class="flex flex-wrap items-center gap-2 text-sm">
              {{ t('WHEN.DAILY_CAP') }}
              <input
                v-model.number="form.daily_cap"
                type="number"
                min="1"
                class="!mb-0 !w-24"
                :placeholder="t('WHEN.NO_CAP')"
              />
            </label>
            <p class="m-0 text-xs text-slate-500">
              {{ t('WHEN.DAILY_CAP_HINT') }}
            </p>
            <!-- Correo: calentar el dominio (el tope arranca en 50 y se duplica cada día) -->
            <label v-if="isEmail" class="flex items-start gap-2 text-sm">
              <input
                v-model="form.brief.warmup"
                type="checkbox"
                class="!m-0 mt-1"
                :disabled="!form.daily_cap"
              />
              <span>
                {{ t('WHEN.WARMUP') }}
                <span class="block text-xs text-slate-500">
                  {{ t('WHEN.WARMUP_HINT', { cap: form.daily_cap || '—' }) }}
                </span>
              </span>
            </label>
            <label
              v-if="continuous"
              class="flex flex-wrap items-center gap-2 text-sm"
            >
              {{ t('WHEN.DELAY') }}
              <input
                v-model.number="form.entry_delay_minutes"
                type="number"
                min="0"
                class="!mb-0 !w-24"
              />
              {{ t('WHEN.MINUTES') }}
            </label>
          </template>

          <!-- 6 · Revisar y lanzar -->
          <template v-if="step === 'review'">
            <!-- Proceso guiado: cuándo aquí (no hay paso «Cuándo»); el nombre va en el encabezado -->
            <section
              v-if="guided"
              class="flex flex-col gap-2 p-3 border rounded-md border-slate-100 dark:border-slate-700"
            >
              <fieldset class="flex flex-wrap items-center gap-3">
                <legend class="field-label">{{ t('WHEN.START') }}</legend>
                <label class="flex items-center gap-2 text-sm">
                  <input
                    v-model="form.start"
                    type="radio"
                    class="!m-0"
                    value="now"
                  />
                  {{ t('WHEN.NOW') }}
                </label>
                <label class="flex items-center gap-2 text-sm">
                  <input
                    v-model="form.start"
                    type="radio"
                    class="!m-0"
                    value="later"
                  />
                  {{ t('WHEN.LATER') }}
                </label>
                <input
                  v-if="form.start === 'later'"
                  v-model="form.scheduled_for"
                  type="datetime-local"
                  class="!mb-0 !w-64"
                />
              </fieldset>
              <p
                v-if="!form.ends_at && isInvite && event"
                class="m-0 text-xs text-slate-500"
              >
                {{ t('INVITE.ENDS_AT_EVENT') }}
              </p>
              <p
                v-if="!form.ends_at && offerLike && form.brief.valid_until"
                class="m-0 text-xs text-slate-500"
              >
                {{ t('OFFER_FLOW.ENDS_AT_VALIDITY') }}
              </p>
              <button
                type="button"
                class="self-start text-xs text-woot-600 hover:underline"
                @click="showAdvanced = !showAdvanced"
              >
                {{
                  showAdvanced
                    ? t('INVITE.HIDE_ADVANCED')
                    : t('INVITE.ADVANCED')
                }}
              </button>
              <div v-if="showAdvanced" class="flex flex-col gap-2">
                <label class="flex flex-wrap items-center gap-2 text-sm">
                  {{ t('WHEN.ENDS') }}
                  <input
                    v-model="form.ends_at"
                    type="datetime-local"
                    class="!mb-0 !w-64"
                  />
                </label>
                <label class="flex items-center gap-2 text-sm">
                  <input
                    v-model="form.respect_working_hours"
                    type="checkbox"
                    class="!m-0"
                  />
                  {{ t('WHEN.WORKING_HOURS') }}
                </label>
                <label class="flex flex-wrap items-center gap-2 text-sm">
                  {{ t('WHEN.DAILY_CAP') }}
                  <input
                    v-model.number="form.daily_cap"
                    type="number"
                    min="1"
                    class="!mb-0 !w-24"
                    :placeholder="t('WHEN.NO_CAP')"
                  />
                </label>
                <label class="flex flex-wrap items-center gap-2 text-sm">
                  {{ t('OFFER.REST_DAYS') }}
                  <input
                    v-model.number="form.brief.rest_days"
                    type="number"
                    min="0"
                    max="90"
                    class="!mb-0 !w-20"
                  />
                  {{ t('OFFER.DAYS') }}
                </label>
              </div>
            </section>
            <div
              class="flex flex-col gap-1 p-3 rounded-md bg-slate-25 dark:bg-slate-800"
            >
              <p class="m-0 text-sm font-medium">
                {{ form.name || defaultName() }}
              </p>
              <p class="m-0 text-xs text-slate-500">
                {{
                  t('REVIEW.SUMMARY', {
                    kind: t(`KINDS.${kind}.TITLE`),
                    seller: (form.attend && form.attend.display_name) || '—',
                    channel: inbox ? inbox.name : '—',
                    touches: attempts,
                  })
                }}
              </p>
              <p v-if="readyCount !== null" class="m-0 text-xs text-slate-500">
                {{ t('REVIEW.AUDIENCE', { n: readyCount }) }}
              </p>
              <ul
                class="m-0 text-xs list-disc text-slate-600 dark:text-slate-300 ltr:pl-4 rtl:pr-4"
              >
                <li v-for="line in reviewLines" :key="line">{{ line }}</li>
              </ul>
              <p v-if="scheduleProblem" class="m-0 text-xs text-red-600">
                {{ scheduleProblem }}
              </p>
            </div>
            <ul class="flex flex-col gap-1 m-0 list-none">
              <li
                v-for="c in checks"
                :key="c.key"
                class="flex items-start gap-2 text-sm"
                :class="levelClass(c.level)"
              >
                <fluent-icon
                  :icon="levelIcon(c.level)"
                  size="16"
                  class="mt-0.5"
                />
                <span>{{ c.text }}</span>
              </li>
            </ul>
            <p
              v-if="checkError"
              class="flex items-center gap-2 m-0 text-xs text-red-600"
            >
              {{ t('REVIEW.CHECK_ERROR') }}
              <button
                type="button"
                class="text-woot-600 hover:underline"
                @click="saveAndCheck"
              >
                {{ t('REVIEW.RETRY') }}
              </button>
            </p>
            <p v-else-if="!checks.length" class="m-0 text-xs text-slate-500">
              {{ t('REVIEW.CHECKING') }}
            </p>
          </template>
        </div>

        <!-- Derecha: cómo se ve y Probar -->
        <div
          v-if="showSide"
          class="flex flex-col min-h-0 gap-3 md:col-span-2 md:overflow-y-auto"
        >
          <p class="m-0 text-xs font-medium text-slate-600 dark:text-slate-300">
            {{ t('PREVIEW.TITLE') }}
          </p>
          <ConversationPreview
            v-if="isWhatsapp"
            :template="templateFor(1)"
            :rules="rulesFor(1)"
            :brief="form.brief"
            :kind="kind"
            :event="event"
          />
          <EmailPreview
            v-else-if="isEmail"
            :subject="form.email_subject"
            :from="inbox ? inbox.name : ''"
            :blocks="currentEmail.blocks || []"
            :signature="form.attend ? form.attend.email_signature || '' : ''"
            :brief="form.brief"
          />
          <p v-else class="m-0 text-xs text-slate-500">
            {{ t('PREVIEW.PICK_CHANNEL') }}
          </p>
          <CampaignChat
            v-if="step !== 'review'"
            class="flex-1"
            :payload="chatPayload"
            :opener="opener"
            :disabled="!hasChannel"
          />
          <template v-else>
            <div
              class="flex gap-1 p-1 rounded-md bg-slate-25 dark:bg-slate-800"
              role="tablist"
            >
              <button
                v-for="tab in testTabs"
                :key="tab"
                type="button"
                role="tab"
                :aria-selected="testTab === tab"
                class="flex-1 px-2 py-1 text-xs rounded"
                :class="
                  testTab === tab
                    ? 'bg-white dark:bg-slate-700 font-medium text-woot-700 dark:text-woot-300'
                    : 'text-slate-600 dark:text-slate-300'
                "
                @click="testTab = tab"
              >
                {{ t(`TEST_TABS.${tab}`) }}
              </button>
            </div>
            <CampaignCases
              v-if="testTab === 'cases'"
              :payload="chatPayload"
              :disabled="!hasChannel"
              :auto-run="guided"
            />
            <!-- Invitar: simular y la prueba real, juntas en «Más pruebas» -->
            <template v-else-if="testTab === 'more'">
              <div class="flex gap-2 text-xs">
                <button
                  v-for="key in ['simulate', 'real']"
                  :key="key"
                  type="button"
                  class="px-2 py-1 border rounded-full"
                  :class="
                    moreTest === key
                      ? 'border-woot-500 text-woot-700'
                      : 'border-slate-200 text-slate-600 dark:border-slate-600 dark:text-slate-300'
                  "
                  @click="moreTest = key"
                >
                  {{ t(`TEST_TABS.${key}`) }}
                </button>
              </div>
              <CampaignSimulator
                v-if="moreTest === 'simulate'"
                :campaign-id="campaignId"
                :save="save"
                :payload="chatPayload"
                :disabled="!hasChannel"
              />
              <CampaignTestRun
                v-else
                :campaign-id="campaignId"
                :save="save"
                :is-whatsapp="isWhatsapp"
                :disabled="!hasChannel"
              />
            </template>
            <CampaignSimulator
              v-else-if="testTab === 'simulate'"
              :campaign-id="campaignId"
              :save="save"
              :payload="chatPayload"
              :disabled="!hasChannel"
            />
            <CampaignChat
              v-else-if="testTab === 'chat'"
              class="flex-1"
              :payload="chatPayload"
              :opener="opener"
              :disabled="!hasChannel"
            />
            <CampaignTestRun
              v-else
              :campaign-id="campaignId"
              :save="save"
              :is-whatsapp="isWhatsapp"
              :disabled="!hasChannel"
            />
          </template>
        </div>
      </div>

      <div
        class="flex flex-wrap justify-end gap-2 pt-3 mt-2 border-t shrink-0 border-slate-100 dark:border-slate-700"
      >
        <woot-button variant="clear" :is-loading="saving" @click="saveDraft">
          {{ t('SAVE_DRAFT') }}
        </woot-button>
        <woot-button
          v-if="step !== steps[0]"
          variant="smooth"
          color-scheme="secondary"
          @click="back"
        >
          {{ t('PREV') }}
        </woot-button>
        <woot-button v-if="step !== 'review'" @click="next">
          {{ t('NEXT') }}
        </woot-button>
        <woot-button
          v-else
          icon="send"
          :is-loading="saving"
          :disabled="!!errors.length || !checks.length || !!scheduleProblem"
          @click="launch"
        >
          {{ form.start === 'later' ? t('SCHEDULE') : t('LAUNCH') }}
        </woot-button>
      </div>
    </template>
    <!-- Sin tipo (liga vieja o recarga): se elige antes de mostrar el asistente -->
    <woot-modal :show="showKindPicker" :on-close="leave">
      <woot-modal-header
        :header-title="t('CHOICE.KIND_TITLE')"
        :header-content="t('CHOICE.KIND_SUBTITLE')"
      />
      <div class="px-8 pb-8">
        <CampaignKindPicker @pick="pickKind" />
      </div>
    </woot-modal>
  </div>
</template>
