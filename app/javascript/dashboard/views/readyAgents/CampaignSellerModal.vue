<!--
  Asistente de la función «Vendedor de campaña» (Plan-Motor-Agentes §11.16): toca la puerta en tus
  campañas. Pasos:
    1 el agente · 2 qué ofreces (para qué es: invitar, ofrecer, reactivar, renovar, encuesta) ·
    3 canal y toques (plantilla por toque) · 4 tu negocio y qué sabe · 5 cómo platica y el relevo ·
    6 indicaciones · 7 pruébalo (el chat empieza con el mensaje de la campaña)
  No atiende bandejas: se elige en la pantalla de campañas. Emite `saved` con el agente.
-->
<script>
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import ReadyAgentsAPI from 'dashboard/api/readyAgents';
import ReadyAgentChat from './ReadyAgentChat.vue';
import AiAgentAttachmentsAPI from 'dashboard/api/aiAgentAttachments';
import AgentFiles from './AgentFiles.vue';
import SourceOrder, { addSource } from './SourceOrder.vue';
import WizardTabs from './WizardTabs.vue';
import SubTabs from './SubTabs.vue';
import AgentVoice from './AgentVoice.vue';
import FollowUpPlan from './FollowUpPlan.vue';
import AfterHandoff from './AfterHandoff.vue';
import QuoteMode from './QuoteMode.vue';
import FichaChannel from '../contactTrackings/ficha/FichaChannel.vue';

const T = 'READY_AGENTS';
const STEPS = ['agent', 'offer', 'channel', 'knows', 'talk', 'follow', 'files'];
const PURPOSES = ['offer', 'invite', 'reactivate', 'renew', 'survey'];
const MAX_QUESTIONS = 3;
const MAX_OBJECTIONS = 15;
const BUSINESS = ['what', 'who', 'coverage', 'why', 'practical'];

const blank = () => ({
  kind: 'campaign_seller',
  name: '',
  display_name: '',
  enabled: true,
  sources: [],
  inbox_ids: [],
  // Cuándo se manda cada imagen o archivo (AgentFiles).
  files: {},
  channel: {
    inboxId: '',
    retryValue: 2,
    retryUnit: 'days',
    attempts: 2,
    whatsappTemplates: [],
    emailSignature: '',
  },
  settings: {
    tone: 'cercano',
    // «Cómo habla tu empresa» que cambió solo para este agente (AgentVoice).
    voice: {},
    purpose: 'offer',
    offer_what: '',
    offer_details: '',
    offer_goal: 'relay',
    event_id: '',
    survey_questions: [{ text: '' }],
    low_score: 7,
    relay: 'agent',
    user_id: '',
    team_id: '',
    appointment_user_ids: [],
    appointment_minutes: '30',
    price_source: '',
    objections: [],
    instructions: '',
    business_what: '',
    business_who: '',
    business_coverage: '',
    business_why: '',
    business_practical: '',
    // Lo que comparten los tres agentes (Motor2::Functions::Extras).
    follow_up: { nudges: 2, templates: [], template_days: 2 },
    attend_hours: 1,
    appointment_notice: { on: true, template: '' },
    quote: { mode: 'off', follow_days: 3 },
  },
});

export default {
  name: 'CampaignSellerModal',
  components: {
    ReadyAgentChat,
    FichaChannel,
    AgentFiles,
    SourceOrder,
    FollowUpPlan,
    AfterHandoff,
    QuoteMode,
    AgentVoice,
    WizardTabs,
    SubTabs,
  },
  props: {
    show: { type: Boolean, default: false },
    title: { type: String, default: '' },
    agent: { type: Object, default: null },
    calendarUsers: { type: Array, default: () => [] },
    sources: { type: Array, default: () => [] },
    events: { type: Array, default: () => [] },
  },
  emits: ['close', 'saved'],
  data() {
    return {
      followTab: 'reminders', // pestañas dentro de «Seguimiento»
      form: blank(),
      saving: false,
      step: 'agent',
      opener: '',
      pendingFiles: [],
    };
  },
  computed: {
    ...mapGetters({ agents: 'agents/getAgents', teams: 'teams/getTeams' }),
    steps() {
      return STEPS;
    },
    purposes() {
      return PURPOSES;
    },
    business() {
      return BUSINESS;
    },
    tones() {
      return ['cercano', 'formal', 'directo', 'empresa'];
    },
    stepLabels() {
      return Object.fromEntries(STEPS.map(s => [s, this.c(`STEPS.${s}`)]));
    },
    stepIndex() {
      return STEPS.indexOf(this.step);
    },
    isLast() {
      return this.stepIndex === STEPS.length - 1;
    },
    purpose() {
      return this.form.settings.purpose;
    },
    hasCatalog() {
      return this.sources.some(s => s.key === 'catalog');
    },
    // Las plantillas aprobadas de la bandeja por la que escribe (para después de las 24 h).
    waTemplates() {
      if (!this.form.channel.inboxId) return [];
      const list =
        this.$store.getters['inboxes/getWhatsAppTemplates'](
          Number(this.form.channel.inboxId)
        ) || [];
      return [...new Set(list.map(item => item.name))];
    },
    isSurvey() {
      return this.purpose === 'survey';
    },
    isInvite() {
      return this.purpose === 'invite';
    },
    // Lo mínimo para guardar: nombre y lo que necesita su «para qué».
    offerReady() {
      const s = this.form.settings;
      if (this.isSurvey) return s.survey_questions.some(q => q.text.trim());
      if (this.isInvite) return !!s.event_id;
      return !!s.offer_what.trim();
    },
    agentReady() {
      return !!this.form.name.trim();
    },
    canSave() {
      return this.agentReady && this.offerReady;
    },
    priceOptions() {
      const options = this.sources
        .filter(s => s.kind === 'catalog' || s.kind === 'google_sheet')
        .map(s => ({ value: s.key, label: s.name, about: s.about }));
      return [
        ...options,
        { value: 'canned', label: this.t('KNOWS.PRICES.canned') },
        { value: 'none', label: this.t('KNOWS.PRICES.none') },
      ];
    },
    otherSources() {
      return this.sources.filter(
        s => s.key !== 'canned_response' && s.kind !== 'catalog'
      );
    },
    // El mensaje con el que empieza la prueba (como si la campaña ya le hubiera escrito).
    defaultOpener() {
      const s = this.form.settings;
      const event = this.events.find(e => e.id === Number(s.event_id));
      return this.c(`OPENERS.${this.purpose}`, {
        what: s.offer_what.trim() || this.c('OPENERS.SOMETHING'),
        event: event ? event.name : this.c('OPENERS.EVENT'),
      });
    },
  },
  watch: {
    show: {
      immediate: true,
      handler(open) {
        if (open) this.reset();
      },
    },
    purpose() {
      this.opener = this.defaultOpener;
    },
  },
  methods: {
    t(key, params) {
      return this.$t(`${T}.${key}`, params);
    },
    c(key, params) {
      return this.$t(`${T}.CAMPAIGN.${key}`, params);
    },
    reset() {
      const base = blank();
      if (this.agent) {
        const saved = JSON.parse(JSON.stringify(this.agent));
        const settings = saved.settings || {};
        const channel = saved.channel || {};
        const questions = (settings.survey_questions || []).map(text => ({
          text,
        }));
        this.form = {
          ...base,
          ...saved,
          files: saved.files || {},
          channel: {
            inboxId: channel.inbox_id || '',
            retryValue: channel.retry_value || 2,
            retryUnit: channel.retry_unit || 'days',
            attempts: channel.attempts || 2,
            whatsappTemplates: channel.whatsapp_templates || [],
            emailSignature: channel.email_signature || '',
          },
          settings: {
            ...base.settings,
            ...settings,
            event_id: settings.event_id || '',
            user_id: settings.user_id || '',
            team_id: settings.team_id || '',
            objections: settings.objections || [],
            appointment_user_ids: settings.appointment_user_ids || [],
            survey_questions: questions.length ? questions : [{ text: '' }],
            // Los agentes de antes no tenían esto: queda apagado hasta que lo prendan.
            follow_up: {
              nudges: 0,
              templates: [],
              template_days: 2,
              ...(settings.follow_up || {}),
            },
            attend_hours: settings.attend_hours ?? 0,
            appointment_notice: {
              on: false,
              template: '',
              ...(settings.appointment_notice || {}),
            },
            quote: { mode: 'off', follow_days: 3, ...(settings.quote || {}) },
          },
        };
      } else {
        const hasCatalog = this.sources.some(s => s.kind === 'catalog');
        base.settings.price_source = hasCatalog ? 'catalog' : 'canned';
        base.settings.quote.mode = hasCatalog ? 'draft' : 'off';
        this.form = base;
      }
      this.step = 'agent';
      this.pendingFiles = [];
      this.opener = this.defaultOpener;
      this.$store.dispatch('agents/get');
      this.$store.dispatch('teams/get');
    },
    go(step) {
      if (!this.agent && step !== 'agent' && !this.agentReady) return;
      this.step = step;
    },
    next() {
      if (this.step === 'offer') this.opener = this.defaultOpener;
      if (!this.isLast) this.go(STEPS[this.stepIndex + 1]);
    },
    back() {
      if (this.stepIndex > 0) this.step = STEPS[this.stepIndex - 1];
    },
    toggleSource(key) {
      const list = this.form.sources;
      this.form.sources = list.includes(key)
        ? list.filter(k => k !== key)
        : addSource(list, key);
    },
    addQuestion() {
      const list = this.form.settings.survey_questions;
      if (list.length < MAX_QUESTIONS) list.push({ text: '' });
    },
    removeQuestion(index) {
      this.form.settings.survey_questions.splice(index, 1);
    },
    addObjection() {
      const list = this.form.settings.objections;
      if (list.length < MAX_OBJECTIONS)
        list.push({ objection: '', answer: '' });
    },
    removeObjection(index) {
      this.form.settings.objections.splice(index, 1);
    },
    toggleCalendarUser(id) {
      const s = this.form.settings;
      const ids = s.appointment_user_ids.map(String);
      s.appointment_user_ids = ids.includes(String(id))
        ? ids.filter(i => i !== String(id))
        : [...ids, String(id)];
    },
    calendarUserOn(id) {
      return this.form.settings.appointment_user_ids
        .map(String)
        .includes(String(id));
    },
    payload() {
      const { settings, channel } = this.form;
      return {
        kind: 'campaign_seller',
        name: this.form.name.trim() || 'Agente',
        display_name: this.form.display_name,
        enabled: true,
        sources: this.form.sources,
        files: this.form.files,
        channel: {
          inbox_id: channel.inboxId,
          retry_value: channel.retryValue,
          retry_unit: channel.retryUnit,
          attempts: channel.attempts,
          whatsapp_templates: channel.whatsappTemplates,
          email_signature: channel.emailSignature,
        },
        settings: {
          ...settings,
          survey_questions: settings.survey_questions
            .map(q => q.text.trim())
            .filter(Boolean),
          objections: settings.objections.filter(
            o => o.objection.trim() && o.answer.trim()
          ),
        },
      };
    },
    // Agente nuevo: los archivos que eligió en «Imágenes y archivos» se suben ya que existe.
    async uploadPending(agentId) {
      if (this.agent || !this.pendingFiles.length) return;
      try {
        await Promise.all(
          this.pendingFiles.map(f => AiAgentAttachmentsAPI.upload(agentId, f))
        );
      } catch (e) {
        useAlert(e.response?.data?.message || this.t('FILES.UPLOAD_ERROR'));
      }
    },
    async save() {
      if (!this.canSave || this.saving) return;
      this.saving = true;
      try {
        const { data } = this.agent
          ? await ReadyAgentsAPI.update(this.agent.id, {
              ready_agent: this.payload(),
            })
          : await ReadyAgentsAPI.create({ ready_agent: this.payload() });
        await this.uploadPending(data.agent.id);
        this.$emit('saved', data.agent);
      } catch (e) {
        useAlert(e.response?.data?.error || this.t('SAVE_ERROR'));
      } finally {
        this.saving = false;
      }
    },
  },
};
</script>

<template>
  <woot-modal :show="show" size="large" :on-close="() => $emit('close')">
    <div class="flex flex-col h-[85vh] min-h-0">
      <woot-modal-header
        :header-title="
          agent
            ? t('EDIT_TITLE', { name: agent.name })
            : t('NEW_TITLE', { title })
        "
        :header-content="c('SUBTITLE')"
      />
      <WizardTabs
        class="px-4 md:px-8"
        :steps="steps"
        :current="step"
        :labels="stepLabels"
        @go="go"
      />
      <div
        class="grid flex-1 min-h-0 grid-cols-1 gap-5 px-4 pb-4 overflow-y-auto md:px-8 md:grid-cols-2 md:grid-rows-1 md:overflow-hidden"
      >
        <form
          class="ready-form flex flex-col gap-2.5 overflow-y-auto !p-0 !pr-1 !self-stretch"
          @submit.prevent="isLast || agent ? save() : next()"
        >
          <p class="m-0 text-xs text-slate-500">
            {{ c(`STEP_HINTS.${step}`) }}
          </p>

          <!-- 1 · El agente -->
          <template v-if="step === 'agent'">
            <div class="grid grid-cols-2 gap-3">
              <label class="block">
                <span class="field-label">{{ t('FIELDS.NAME') }}</span>
                <input
                  v-model="form.name"
                  type="text"
                  :placeholder="c('NAME_PLACEHOLDER')"
                />
              </label>
              <label class="block">
                <span class="field-label">{{ t('FIELDS.DISPLAY_NAME') }}</span>
                <input
                  v-model="form.display_name"
                  type="text"
                  maxlength="30"
                  :placeholder="t('FIELDS.DISPLAY_NAME_PLACEHOLDER')"
                />
              </label>
            </div>
            <label class="block">
              <span class="field-label">{{ t('FIELDS.TONE') }}</span>
              <select v-model="form.settings.tone">
                <option v-for="tone in tones" :key="tone" :value="tone">
                  {{ t(`TONES.${tone}`) }}
                </option>
              </select>
            </label>
            <p class="m-0 text-xs text-slate-500">{{ c('WHERE_USED') }}</p>
          </template>

          <!-- 2 · Qué ofreces -->
          <template v-if="step === 'offer'">
            <span class="field-label">{{ c('PURPOSE') }}</span>
            <label
              v-for="value in purposes"
              :key="value"
              class="flex items-start gap-2 text-sm cursor-pointer"
            >
              <input
                v-model="form.settings.purpose"
                type="radio"
                class="!m-0 mt-1"
                :value="value"
              />
              <span>
                {{ c(`PURPOSES.${value}.TITLE`) }}
                <span class="block text-xs text-slate-500">
                  {{ c(`PURPOSES.${value}.ABOUT`) }}
                </span>
              </span>
            </label>

            <template v-if="isSurvey">
              <span class="field-label">{{ c('SURVEY.QUESTIONS') }}</span>
              <div
                v-for="(q, i) in form.settings.survey_questions"
                :key="i"
                class="flex items-center gap-1"
              >
                <input
                  v-model="q.text"
                  type="text"
                  maxlength="300"
                  class="flex-1"
                  :placeholder="c(`SURVEY.PLACEHOLDER_${i + 1}`)"
                />
                <button
                  type="button"
                  class="px-1 text-slate-400 hover:text-red-600"
                  :title="c('REMOVE')"
                  @click="removeQuestion(i)"
                >
                  <fluent-icon icon="dismiss" size="14" />
                </button>
              </div>
              <button
                v-if="form.settings.survey_questions.length < 3"
                type="button"
                class="self-start text-xs text-woot-600 hover:underline"
                @click="addQuestion"
              >
                {{ c('SURVEY.ADD') }}
              </button>
              <label class="block">
                <span class="field-label">{{ c('SURVEY.LOW_SCORE') }}</span>
                <input
                  v-model.number="form.settings.low_score"
                  type="number"
                  min="1"
                  max="10"
                  class="!w-24 h-9 text-sm"
                />
              </label>
            </template>

            <template v-else>
              <label v-if="isInvite" class="block">
                <span class="field-label">{{ c('EVENT') }}</span>
                <select v-model="form.settings.event_id">
                  <option value="">{{ c('EVENT_CHOOSE') }}</option>
                  <option v-for="e in events" :key="e.id" :value="e.id">
                    {{ e.name }}
                  </option>
                </select>
                <span
                  v-if="!events.length"
                  class="block mt-1 text-xs text-amber-700"
                >
                  {{ c('NO_EVENTS') }}
                </span>
              </label>
              <label class="block">
                <span class="field-label">
                  {{ c(isInvite ? 'INVITE_WHAT' : 'OFFER_WHAT') }}
                </span>
                <textarea
                  v-model="form.settings.offer_what"
                  rows="2"
                  maxlength="1000"
                  :placeholder="c(`PLACEHOLDERS.${purpose}`)"
                />
              </label>
              <label class="block">
                <span class="field-label">{{ c('OFFER_DETAILS') }}</span>
                <textarea
                  v-model="form.settings.offer_details"
                  rows="2"
                  maxlength="1000"
                  :placeholder="c('OFFER_DETAILS_PLACEHOLDER')"
                />
              </label>
              <template v-if="!isInvite">
                <span class="field-label">{{ c('GOAL') }}</span>
                <label
                  v-for="value in ['relay', 'appointment']"
                  :key="value"
                  class="flex items-center gap-2 text-sm"
                >
                  <input
                    v-model="form.settings.offer_goal"
                    type="radio"
                    class="!m-0"
                    :value="value"
                  />
                  {{ c(`GOALS.${value}`) }}
                </label>
                <div v-if="form.settings.offer_goal === 'appointment'">
                  <span class="field-label">
                    {{ t('FIELDS.APPOINTMENT_USERS') }}
                  </span>
                  <p
                    v-if="!calendarUsers.length"
                    class="m-0 text-xs text-amber-700"
                  >
                    {{ t('FIELDS.NO_CALENDARS') }}
                  </p>
                  <label
                    v-for="u in calendarUsers"
                    :key="u.id"
                    class="flex items-center gap-2 text-sm"
                  >
                    <input
                      type="checkbox"
                      class="!m-0"
                      :checked="calendarUserOn(u.id)"
                      @change="toggleCalendarUser(u.id)"
                    />
                    {{ u.name }}
                  </label>
                </div>
              </template>
            </template>
            <p v-if="!offerReady" class="m-0 text-xs text-amber-700">
              {{
                c(
                  `MISSING.${
                    isSurvey ? 'survey' : isInvite ? 'invite' : 'offer'
                  }`
                )
              }}
            </p>
          </template>

          <!-- 3 · Canal y toques -->
          <template v-if="step === 'channel'">
            <FichaChannel v-model="form.channel" />
          </template>

          <!-- 4 · Tu negocio y qué sabe -->
          <template v-if="step === 'knows'">
            <label v-for="field in business" :key="field" class="block">
              <span class="field-label">
                {{ t(`BUSINESS.${field.toUpperCase()}`) }}
              </span>
              <textarea
                v-model="form.settings[`business_${field}`]"
                rows="2"
                :placeholder="t(`BUSINESS.${field.toUpperCase()}_PLACEHOLDER`)"
              />
            </label>
            <template v-if="!isSurvey">
              <span class="field-label">{{ t('KNOWS.PRICES.QUESTION') }}</span>
              <label
                v-for="option in priceOptions"
                :key="option.value"
                class="flex items-start gap-2 text-sm"
              >
                <input
                  v-model="form.settings.price_source"
                  type="radio"
                  class="!m-0 mt-1"
                  :value="option.value"
                />
                <span>
                  {{ option.label }}
                  <span
                    v-if="option.about"
                    class="block text-xs text-slate-500"
                  >
                    {{ option.about }}
                  </span>
                </span>
              </label>
              <label
                v-for="src in otherSources"
                :key="src.key"
                class="flex items-start gap-2 p-2 border rounded-md cursor-pointer border-slate-100 dark:border-slate-700"
              >
                <input
                  type="checkbox"
                  class="!m-0 mt-0.5 shrink-0"
                  :checked="form.sources.includes(src.key)"
                  @change="toggleSource(src.key)"
                />
                <span class="text-sm">
                  <span class="block font-medium">{{ src.name }}</span>
                  <span class="block text-xs text-slate-500">
                    {{ src.about }}
                  </span>
                </span>
              </label>
              <SourceOrder v-model="form.sources" :sources="sources" />
            </template>
          </template>

          <!-- 5 · Cómo platica y el relevo -->
          <template v-if="step === 'talk'">
            <AgentVoice v-model="form.settings.voice" />
            <template v-if="!isSurvey && !isInvite">
              <span class="field-label">{{ c('RELAY') }}</span>
              <label
                v-for="value in ['agent', 'person']"
                :key="value"
                class="flex items-start gap-2 text-sm"
              >
                <input
                  v-model="form.settings.relay"
                  type="radio"
                  class="!m-0 mt-1"
                  :value="value"
                />
                {{ c(`RELAYS.${value}`) }}
              </label>
            </template>
            <div class="grid grid-cols-2 gap-2">
              <label class="block">
                <span class="field-label">{{ c('PERSON') }}</span>
                <select v-model="form.settings.user_id">
                  <option value="">{{ t('FIELDS.NOBODY') }}</option>
                  <option v-for="u in agents" :key="u.id" :value="u.id">
                    {{ u.name }}
                  </option>
                </select>
              </label>
              <label class="block">
                <span class="field-label">{{ c('TEAM') }}</span>
                <select v-model="form.settings.team_id">
                  <option value="">{{ t('FIELDS.NO_TEAM') }}</option>
                  <option v-for="team in teams" :key="team.id" :value="team.id">
                    {{ team.name }}
                  </option>
                </select>
              </label>
            </div>
            <p class="m-0 text-xs text-slate-500">{{ c('RULES') }}</p>
            <template v-if="!isSurvey">
              <span class="field-label">{{ c('OBJECTIONS') }}</span>
              <div
                v-for="(o, i) in form.settings.objections"
                :key="i"
                class="grid grid-cols-[1fr_1fr_auto] gap-1"
              >
                <input
                  v-model="o.objection"
                  type="text"
                  maxlength="300"
                  :placeholder="c('OBJECTION_PLACEHOLDER')"
                />
                <input
                  v-model="o.answer"
                  type="text"
                  maxlength="600"
                  :placeholder="c('ANSWER_PLACEHOLDER')"
                />
                <button
                  type="button"
                  class="px-1 text-slate-400 hover:text-red-600"
                  :title="c('REMOVE')"
                  @click="removeObjection(i)"
                >
                  <fluent-icon icon="dismiss" size="14" />
                </button>
              </div>
              <button
                type="button"
                class="self-start text-xs text-woot-600 hover:underline"
                @click="addObjection"
              >
                {{ c('ADD_OBJECTION') }}
              </button>
              <QuoteMode
                v-model="form.settings.quote"
                :has-catalog="hasCatalog"
              />
            </template>
          </template>

          <!-- Seguimiento: si deja de contestar a media plática, el plazo y el recordatorio de la cita -->
          <template v-if="step === 'follow'">
            <SubTabs
              v-model="followTab"
              :tabs="[
                { key: 'reminders', label: t('SUBTABS.REMINDERS') },
                { key: 'handoff', label: t('SUBTABS.HANDOFF') },
              ]"
            />
            <FollowUpPlan
              v-if="followTab === 'reminders'"
              v-model="form.settings.follow_up"
              :templates="waTemplates"
              kind="campaign_seller"
            />
            <AfterHandoff
              v-else
              v-model="form.settings"
              :templates="waTemplates"
              :appointments="!!form.settings.appointment_user_ids.length"
            />
          </template>

          <!-- 6 · Imágenes y archivos -->
          <template v-if="step === 'files'">
            <AgentFiles
              v-model="form.files"
              kind="campaign_seller"
              :agent-id="agent ? agent.id : null"
              :touches="Number(form.channel.attempts) || 0"
              :invite="isInvite"
              @pending="pendingFiles = $event"
            />
          </template>

          <!-- 7 · Indicaciones -->
          <template v-if="step === 'talk'">
            <label class="block">
              <span class="field-label">{{ t('FIELDS.INSTRUCTIONS') }}</span>
              <textarea
                v-model="form.settings.instructions"
                rows="6"
                :placeholder="t('FIELDS.INSTRUCTIONS_PLACEHOLDER')"
              />
            </label>
          </template>

          <!-- 7 · Pruébalo -->
          <template v-if="isLast">
            <p class="m-0 text-sm text-slate-700 dark:text-slate-200">
              {{ c('TEST_READY', { name: form.name.trim() || '—' }) }}
            </p>
            <label class="block">
              <span class="field-label">{{ c('OPENER') }}</span>
              <textarea v-model="opener" rows="3" maxlength="1000" />
            </label>
          </template>
        </form>

        <ReadyAgentChat
          :key="opener"
          :payload="payload"
          :agent-id="agent ? agent.id : null"
          :opener="opener"
          :hint="c('TEST_HINT')"
        />
      </div>
      <div class="flex justify-end gap-2 px-8 pb-6">
        <woot-button variant="clear" type="button" @click="$emit('close')">
          {{ t('CANCEL') }}
        </woot-button>
        <woot-button
          v-if="stepIndex > 0"
          variant="smooth"
          color-scheme="secondary"
          type="button"
          @click="back"
        >
          {{ t('BACK') }}
        </woot-button>
        <woot-button
          v-if="!isLast"
          :variant="agent ? 'smooth' : 'solid'"
          :disabled="!agent && !agentReady"
          type="button"
          @click="next"
        >
          {{ t('NEXT') }}
        </woot-button>
        <woot-button :is-loading="saving" :disabled="!canSave" @click="save">
          {{ t('SAVE') }}
        </woot-button>
      </div>
    </div>
  </woot-modal>
</template>

<style lang="scss" scoped>
.ready-form {
  .field-label {
    @apply block mb-1 text-xs font-medium text-slate-600 dark:text-slate-300;
  }

  input[type='text'] {
    @apply h-9 py-1 px-2 mb-0 text-sm;
  }

  select {
    @apply h-9 py-1 pl-2 pr-8 mb-0 text-sm;
  }

  textarea {
    @apply mb-0 text-sm;
  }
}
</style>
