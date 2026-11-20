<!--
  Campaña con Vendedor IA (Motor 2.0) — la pantalla nueva para crear o modificar una campaña (la 1.0, CampaignForm,
  no cambia). Seis pasos como pestañas: Objetivo · Oferta y vendedor · Audiencia · Mensajes · Cuándo · Revisar y
  lanzar. A la derecha, siempre: cómo se ve el mensaje (teléfono o correo) y «Probar» con el vendedor.
  Ruta: tracking-dashboard/campaigns2/new | campaigns2/:campaignId/edit.
-->
<script>
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import Motor2CampaignsAPI from 'dashboard/api/motor2Campaigns';
import WizardTabs from 'dashboard/views/readyAgents/WizardTabs.vue';
import PhonePreview from './PhonePreview.vue';
import EmailPreview from './EmailPreview.vue';
import EmailEditor from './EmailEditor.vue';
import CampaignChat from './CampaignChat.vue';

const STEPS = ['goal', 'offer', 'audience', 'messages', 'when', 'review'];
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
  tracking_template_id: '',
  inbox_id: '',
  brief: {
    kind: 'offer',
    offer_what: '',
    offer_details: '',
    offer_goal: 'relay',
    event_id: '',
    survey_questions: ['', '', ''],
    low_score: 7,
    rest_days: 7,
  },
  touches: {
    attempts: 2,
    every_value: 2,
    every_unit: 'days',
    templates: [],
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
    PhonePreview,
    EmailPreview,
    EmailEditor,
    CampaignChat,
  },
  data() {
    return {
      step: 'goal',
      form: blankForm(),
      options: { sellers: [], inboxes: [], events: [] },
      loading: true,
      saving: false,
      campaignId: null,
      preview: null,
      previewLoading: false,
      checks: [],
      touchTab: 1,
      sendingTest: false,
    };
  },
  computed: {
    ...mapGetters({ labels: 'labels/getLabels' }),
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
    seller() {
      return this.options.sellers.find(
        s => s.id === Number(this.form.tracking_template_id)
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
    kind() {
      return this.form.brief.kind;
    },
    event() {
      return this.options.events.find(
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
        return tpl ? (tpl.body || '').replace(/\{\{\s*1\s*\}\}/g, 'Mario') : '';
      }
      return (this.form.touches.emails[0]?.body || '')
        .replace(/\{\{\s*contacto\s*\}\}/gi, 'Mario')
        .replace(/\{\{\s*empresa\s*\}\}/gi, 'Grúas del Norte');
    },
    errors() {
      return this.checks.filter(c => c.level === 'error');
    },
    canSave() {
      return !!(this.form.tracking_template_id && this.form.inbox_id);
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
    'form.tracking_template_id'() {
      this.prefillFromSeller();
    },
    'form.brief.kind'(kind) {
      if (kind === 'invite' && this.sourceType === 'segment') {
        this.form.audience.source = { type: 'event' };
      }
    },
  },
  async mounted() {
    try {
      const [{ data }] = await Promise.all([
        Motor2CampaignsAPI.options(),
        this.$store.dispatch('customViews/get', FILTER_TYPE_CONTACT),
        this.$store.dispatch('labels/get'),
      ]);
      this.options = data;
      const id = this.$route.params.campaignId;
      if (id) await this.load(Number(id));
      else this.applyDefaults();
    } catch (e) {
      useAlert(this.t('LOAD_ERROR'));
    } finally {
      this.loading = false;
    }
  },
  methods: {
    t(key, params) {
      return this.$t(`CAMPAIGNS2.${key}`, params);
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
    applyDefaults() {
      if (this.options.sellers.length === 1) {
        this.form.tracking_template_id = this.options.sellers[0].id;
      }
      if (this.options.inboxes.length === 1) {
        this.form.inbox_id = this.options.inboxes[0].id;
      }
      this.form.touches.emails = this.touchNumbers.map(() => ({
        body: '',
        blocks: [],
      }));
    },
    // Agente nuevo en la campaña: su oferta de ejemplo llena lo que falte.
    prefillFromSeller() {
      const example = this.seller?.example || {};
      const brief = this.form.brief;
      if (!brief.offer_what && example.offer_what) {
        brief.offer_what = example.offer_what;
      }
      if (!brief.offer_details && example.offer_details) {
        brief.offer_details = example.offer_details;
      }
    },
    async load(id) {
      const { data } = await Motor2CampaignsAPI.show(id);
      this.campaignId = data.id;
      const blank = blankForm();
      const questions = [...(data.brief?.survey_questions || []), '', '', ''];
      this.form = {
        ...blank,
        name: data.name,
        tracking_template_id: data.tracking_template_id || '',
        inbox_id: data.inbox_id || '',
        brief: {
          ...blank.brief,
          ...data.brief,
          event_id: data.brief?.event_id || '',
          survey_questions: questions.slice(0, 3),
        },
        touches: {
          ...blank.touches,
          ...data.touches,
          templates: data.touches?.templates || [],
          emails: (data.touches?.emails || []).map(e => ({
            body: e.body || '',
            blocks: e.blocks || [],
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
    },
    body() {
      const f = this.form;
      return {
        name: f.name.trim() || this.defaultName(),
        tracking_template_id: f.tracking_template_id,
        inbox_id: f.inbox_id,
        mode: this.continuous ? 'continuous' : 'batch',
        brief: {
          ...f.brief,
          survey_questions: f.brief.survey_questions.filter(q => q.trim()),
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
    async save() {
      if (!this.canSave) {
        useAlert(this.t('NEEDS_SELLER_AND_CHANNEL'));
        return false;
      }
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
      if (!(await this.save())) return;
      const { data } = await Motor2CampaignsAPI.check(this.campaignId);
      this.checks = data.items || [];
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
      if (this.continuous || !this.filterPayload.length || !this.canSave) {
        this.preview = null;
        return;
      }
      this.previewLoading = true;
      try {
        const { data } = await Motor2CampaignsAPI.preview({
          payload: this.filterPayload,
          template_id: this.form.tracking_template_id,
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
    async sendTestEmail() {
      this.sendingTest = true;
      try {
        const { data } = await Motor2CampaignsAPI.testEmail({
          template_id: this.form.tracking_template_id,
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
    chatPayload() {
      return {
        template_id: this.form.tracking_template_id,
        brief: this.body().brief,
      };
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
      <p
        v-if="!options.sellers.length"
        class="p-3 mb-2 text-sm rounded-md text-amber-800 bg-amber-50 dark:bg-amber-900/20"
      >
        {{ t('NO_SELLERS') }}
      </p>
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

          <!-- 1 · Objetivo -->
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
            <fieldset
              v-if="!['invite', 'survey'].includes(kind)"
              class="flex flex-col gap-1"
            >
              <legend class="field-label">{{ t('GOAL.QUESTION') }}</legend>
              <label
                v-for="g in ['relay', 'appointment']"
                :key="g"
                class="flex items-center gap-2 text-sm"
              >
                <input
                  v-model="form.brief.offer_goal"
                  type="radio"
                  class="!m-0"
                  :value="g"
                />
                {{ t(`GOAL.${g}`) }}
              </label>
            </fieldset>
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

          <!-- 2 · Oferta y vendedor -->
          <template v-if="step === 'offer'">
            <label class="block">
              <span class="field-label">{{ t('OFFER.SELLER') }}</span>
              <select v-model="form.tracking_template_id">
                <option value="">{{ t('OFFER.SELLER_PICK') }}</option>
                <option v-for="s in options.sellers" :key="s.id" :value="s.id">
                  {{ s.name }}
                </option>
              </select>
              <span class="block text-xs text-slate-500">
                {{
                  seller
                    ? t(`OFFER.RELAY.${seller.relay}`)
                    : t('OFFER.SELLER_HINT')
                }}
              </span>
            </label>
            <template v-if="kind === 'invite'">
              <label class="block">
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
            </template>
            <template v-else-if="kind === 'survey'">
              <label
                v-for="(_q, i) in form.brief.survey_questions"
                :key="i"
                class="block"
              >
                <span class="field-label">
                  {{ t('OFFER.QUESTION', { n: i + 1 }) }}
                </span>
                <input
                  v-model="form.brief.survey_questions[i]"
                  type="text"
                  maxlength="300"
                  :placeholder="t(`OFFER.QUESTION_PLACEHOLDER_${i + 1}`)"
                />
              </label>
              <label class="flex items-center gap-2 text-sm">
                {{ t('OFFER.LOW_SCORE') }}
                <input
                  v-model.number="form.brief.low_score"
                  type="number"
                  min="1"
                  max="10"
                  class="!mb-0 !w-20"
                />
              </label>
            </template>
            <template v-if="kind !== 'survey'">
              <label class="block">
                <span class="field-label">{{ t(`OFFER.WHAT.${kind}`) }}</span>
                <textarea
                  v-model="form.brief.offer_what"
                  rows="3"
                  maxlength="1500"
                  :placeholder="t(`OFFER.WHAT_PLACEHOLDER.${kind}`)"
                />
              </label>
              <label class="block">
                <span class="field-label">{{ t('OFFER.DETAILS') }}</span>
                <textarea
                  v-model="form.brief.offer_details"
                  rows="2"
                  maxlength="1500"
                  :placeholder="t('OFFER.DETAILS_PLACEHOLDER')"
                />
              </label>
            </template>
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
          </template>

          <!-- 3 · Audiencia -->
          <template v-if="step === 'audience'">
            <div class="flex flex-wrap gap-2">
              <button
                v-for="type in ['segment', 'label', 'event', 'continuous']"
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
            <div v-if="sourceType === 'event'" class="grid grid-cols-2 gap-2">
              <label class="block">
                <span class="field-label">{{ t('OFFER.EVENT') }}</span>
                <select v-model="form.brief.event_id" @change="loadPreview">
                  <option value="">{{ t('OFFER.EVENT_PICK') }}</option>
                  <option v-for="e in options.events" :key="e.id" :value="e.id">
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

            <!-- Cuántos le llegan y quiénes se excluyen -->
            <div
              v-if="!continuous && sourceType !== 'campaign'"
              class="p-3 rounded-md bg-slate-25 dark:bg-slate-800"
            >
              <p v-if="!canSave" class="m-0 text-xs text-amber-700">
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

            <template v-if="isWhatsapp">
              <label v-for="n in touchNumbers" :key="n" class="block">
                <span class="field-label">
                  {{ t('MESSAGES.TEMPLATE_FOR', { n }) }}
                </span>
                <select
                  :value="form.touches.templates[n - 1] || ''"
                  @change="setTemplate(n, $event.target.value)"
                >
                  <option value="">{{ t('MESSAGES.TEMPLATE_PICK') }}</option>
                  <option
                    v-for="tpl in inbox.templates"
                    :key="tpl.name"
                    :value="tpl.name"
                  >
                    {{ tpl.name }}
                  </option>
                </select>
              </label>
              <p
                v-if="!inbox.templates.length"
                class="m-0 text-xs text-amber-700"
              >
                {{ t('MESSAGES.NO_TEMPLATES') }}
              </p>
            </template>

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
                :signature="seller && seller.email_signature"
                @input="setEmail(touchTab, $event)"
              />
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

          <!-- 5 · Cuándo -->
          <template v-if="step === 'when'">
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
                    seller: seller ? seller.name : '—',
                    channel: inbox ? inbox.name : '—',
                    touches: attempts,
                  })
                }}
              </p>
              <p v-if="readyCount !== null" class="m-0 text-xs text-slate-500">
                {{ t('REVIEW.AUDIENCE', { n: readyCount }) }}
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
            <p v-if="!checks.length" class="m-0 text-xs text-slate-500">
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
          <PhonePreview v-if="isWhatsapp" :template="templateFor(1)" />
          <EmailPreview
            v-else-if="isEmail"
            :subject="form.email_subject"
            :from="inbox ? inbox.name : ''"
            :blocks="currentEmail.blocks || []"
            :signature="seller ? seller.email_signature || '' : ''"
          />
          <p v-else class="m-0 text-xs text-slate-500">
            {{ t('PREVIEW.PICK_CHANNEL') }}
          </p>
          <CampaignChat
            class="flex-1"
            :payload="chatPayload"
            :opener="opener"
            :disabled="!form.tracking_template_id"
          />
        </div>
      </div>

      <div
        class="flex flex-wrap justify-end gap-2 pt-3 mt-2 border-t shrink-0 border-slate-100 dark:border-slate-700"
      >
        <woot-button
          variant="clear"
          :is-loading="saving"
          :disabled="!canSave"
          @click="saveDraft"
        >
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
          :disabled="!!errors.length || !checks.length"
          @click="launch"
        >
          {{ form.start === 'later' ? t('SCHEDULE') : t('LAUNCH') }}
        </woot-button>
      </div>
    </template>
  </div>
</template>
