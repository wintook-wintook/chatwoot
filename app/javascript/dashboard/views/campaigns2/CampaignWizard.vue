<!--
  Campaña con IA (Motor 2.0) — la pantalla para crear o modificar una campaña (la 1.0, CampaignForm, no cambia). Pasos
  como pestañas, en el orden en que pasa la plática: Objetivo (tipo, qué cuenta como logrado, canal) · La ficha (lo que
  sabe la IA: datos, preguntas, ligas, archivos) · Audiencia · Mensajes (lo que se manda) · Respuestas y resultados
  (respuestas fijas y etiquetas del contacto) · Cómo atiende · Cuándo · Revisar y lanzar (con «Casos»). A la derecha,
  siempre: cómo se ve el mensaje (teléfono o correo) y «Probar».
  Ruta: tracking-dashboard/campaigns2/new | campaigns2/:campaignId/edit.
-->
<script>
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import Motor2CampaignsAPI from 'dashboard/api/motor2Campaigns';
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
import { fillTemplate, sampleValues } from './campaignFlow';

// En «Revisar»: probar la campaña completa, no solo al vendedor.
const TEST_TABS = ['cases', 'simulate', 'chat', 'real'];

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
      testTabs: TEST_TABS,
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
    steps() {
      return STEPS;
    },
    kinds() {
      return KINDS;
    },
    attendeeStatuses() {
      return ATTENDEE_STATUSES;
    },
    stepLabels() {
      return Object.fromEntries(STEPS.map(s => [s, this.t(`STEPS.${s}`)]));
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
      if (src.type === 'event' && this.form.brief.event_id) {
        return [
          {
            attribute_key: 'event',
            filter_operator: 'equal_to',
            values: [`${this.form.brief.event_id}:${this.form.event_status}`],
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
        f.ends_at
          ? this.t('REVIEW.ENDS_AT', { at: fmt(f.ends_at) })
          : this.t('REVIEW.NO_END'),
        this.t('REVIEW.PACE', {
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
      else this.applyDefaults();
      if (this.campaignId && this.$route.query.step === 'review') {
        this.$nextTick(() => this.go('review'));
      }
    } catch (e) {
      this.loadFailed = !!this.$route.params.campaignId;
      useAlert(this.t('LOAD_ERROR'));
    } finally {
      this.loading = false;
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
      if (step === 'audience') this.loadPreview();
      if (step === 'review') this.saveAndCheck();
    },
    next() {
      const i = STEPS.indexOf(this.step);
      if (i < STEPS.length - 1) this.go(STEPS[i + 1]);
    },
    back() {
      const i = STEPS.indexOf(this.step);
      if (i > 0) this.go(STEPS[i - 1]);
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
      if (!this.form.brief.labels) this.resetLabels();
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
          objections: f.brief.objections.filter(
            o => o.objection.trim() && o.answer.trim()
          ),
          links: (f.brief.links || []).filter(l => (l.url || '').trim()),
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
    defaultName() {
      const what =
        this.kind === 'invite' ? this.event?.name : this.form.brief.offer_what;
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
        if (!this.form.name.trim()) this.form.name = data.name;
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
          <h1 class="m-0 text-xl font-bold text-slate-800 dark:text-slate-100">
            {{ campaignId ? t('EDIT_TITLE') : t('NEW_TITLE') }}
          </h1>
          <p class="m-0 mt-1 text-sm text-slate-600 dark:text-slate-400">
            {{ t('SUBTITLE') }}
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
        <!-- Izquierda: el paso -->
        <div class="flex flex-col gap-3 pr-1 md:col-span-3 md:overflow-y-auto">
          <p class="m-0 text-xs text-slate-500">{{ t(`HINTS.${step}`) }}</p>

          <!-- 1 · Objetivo: tipo, qué cuenta como logrado, nombre corto y canal -->
          <template v-if="step === 'goal'">
            <div class="grid grid-cols-1 gap-2 sm:grid-cols-2">
              <button
                v-for="k in kinds"
                :key="k"
                type="button"
                class="flex flex-col gap-1 p-3 text-left border rounded-lg"
                :class="
                  kind === k
                    ? 'border-woot-500 bg-woot-25 dark:bg-woot-900/20'
                    : 'border-slate-100 dark:border-slate-700 hover:border-woot-200'
                "
                @click="form.brief.kind = k"
              >
                <span
                  class="text-sm font-semibold text-slate-800 dark:text-slate-100"
                >
                  {{ t(`KINDS.${k}.TITLE`) }}
                </span>
                <span class="text-xs text-slate-500">
                  {{ t(`KINDS.${k}.ABOUT`) }}
                </span>
              </button>
            </div>
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

          <!-- 3 · Audiencia -->
          <template v-if="step === 'audience'">
            <div class="flex flex-wrap gap-2">
              <button
                v-for="type in [
                  'segment',
                  'label',
                  'event',
                  'continuous',
                  ...(isWhatsapp ? [] : ['list']),
                ]"
                :key="type"
                type="button"
                class="px-3 py-1.5 text-sm border rounded-full"
                :class="
                  sourceType === type
                    ? 'border-woot-500 text-woot-700 bg-woot-25 dark:bg-woot-900/20'
                    : 'border-slate-200 dark:border-slate-600 text-slate-600 dark:text-slate-300'
                "
                @click="setSource(type)"
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
                <span class="field-label">{{ t('OFFER.EVENT') }}</span>
                <select v-model="form.brief.event_id" @change="loadPreview">
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
            <div class="flex flex-wrap items-center gap-2 text-sm">
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
            <p class="m-0 text-xs text-slate-500">
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
          </template>

          <!-- 5 · Respuestas y resultados -->
          <CampaignReplies
            v-if="step === 'replies'"
            :brief.sync="form.brief"
            :kind="kind"
            :kit="kit"
          />

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
            />
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
          v-if="step !== 'goal'"
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
  </div>
</template>
