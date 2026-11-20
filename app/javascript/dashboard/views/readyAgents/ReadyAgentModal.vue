<!--
  Asistente de la función «Atención a prospectos» (Plan-Motor-Agentes §11.14.5): crear o cambiar
  un agente, paso a paso, sin tener que pensar, solo contestar:
    1 el agente y sus bandejas · 2 tu negocio · 3 qué sabe (sus fuentes) · 4 qué le preguntas ·
    5 cómo platica (dudas, lo que no encuentra, fuera de tema) · 6 cuándo califica y cuándo no ·
    7 qué hacer al calificar y a quién · 8 objeciones · 9 indicaciones · 10 pruébalo y guarda
  A la derecha, el chat de prueba con el motor 2.0 real: tú eres el cliente y ves qué contesta y
  qué hizo, sin guardar ni mandar nada. Al editar se puede saltar a cualquier paso y guardar.
  El agente queda en la lista de agentes. Emite `saved` con el agente.
-->
<script>
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import ReadyAgentsAPI from 'dashboard/api/readyAgents';
import AiAgentAttachmentsAPI from 'dashboard/api/aiAgentAttachments';
import AgentFiles from './AgentFiles.vue';
import SourceOrder, { addSource } from './SourceOrder.vue';
import AgentVoice from './AgentVoice.vue';
import FollowUpPlan from './FollowUpPlan.vue';
import QuoteMode from './QuoteMode.vue';

const T = 'READY_AGENTS';
// Las preguntas para calificar: una sola lista, en orden, que se hacen tal cual. Un agente nuevo
// trae unas de ejemplo (se quitan o cambian). Los de antes traían armadas con casilla
// (`qualify`) y preguntas propias en texto (`questions`): se pasan a la lista.
const QUALIFY_KEYS = [
  'need',
  'when',
  'budget',
  'decides',
  'location',
  'quantity',
  'source',
];
const EXAMPLE_KEYS = ['need', 'when', 'budget'];
const MAX_QUESTIONS = 10;
// «Cómo platica»: opciones, no texto libre (Motor2::Functions::ProspectRules). La primera es la
// recomendada.
const RULES = {
  doubts: ['answer', 'defer'],
  not_found: ['advisor', 'silent'],
  off_topic: ['redirect', 'answer'],
  human: ['finish_first', 'now'],
};
// Solo aplican si contesta dudas (con «No contesta dudas» se ven en gris).
const NEEDS_DOUBTS = ['not_found', 'off_topic'];
// Valores de antes: «lo pasa a una persona» y «lo descarta» se quitaron.
const LEGACY = {
  not_found: { continue: 'advisor', handoff: 'advisor' },
  off_topic: { discard: 'redirect' },
};
const CONTACT_FIELDS = ['name', 'email', 'company', 'city'];
const STEPS = [
  'agent',
  'business',
  'knows',
  'questions',
  'talk',
  'qualify',
  'after',
  'follow',
  'objections',
  'files',
  'instructions',
  'test',
];
const blank = kind => ({
  kind,
  name: '',
  display_name: '',
  enabled: true,
  // Fuentes que marcó en «Qué sabe» (las predefinidas van siempre, no se marcan).
  sources: [],
  // Cuándo se manda cada imagen o archivo (AgentFiles).
  files: {},
  inbox_ids: [],
  settings: {
    objective: 'handoff',
    // [{ text }] en la pantalla; se manda como lista de textos (question_list).
    question_list: [],
    doubts: 'answer',
    not_found: 'advisor',
    off_topic: 'redirect',
    human: 'finish_first',
    // Bienvenida: va tal cual al inicio de su primera respuesta (motor2['welcome']).
    welcome: '',
    qualified_when: '',
    // Cuándo es «caliente» (si no, la regla de siempre: lo necesita este mes y tiene presupuesto o decide).
    hot_when: '',
    discard_when: '',
    tone: 'cercano',
    // «Cómo habla tu empresa» que cambió solo para este agente (AgentVoice).
    voice: {},
    instructions: '',
    handoff_user_id: '',
    handoff_team_id: '',
    client_user_id: '',
    client_team_id: '',
    only_prospects: true,
    // Citas: con quién (Google conectado), duración, tipo y lugar o liga.
    appointment_user_ids: [],
    appointment_minutes: '30',
    appointment_kind: 'llamada',
    appointment_location: '',
    // Tu negocio
    business_what: '',
    // ¿Dónde están tus productos y precios? catalog | google_sheet:<id> | canned | none (paso «Qué sabe»).
    price_source: '',
    business_who: '',
    business_coverage: '',
    business_why: '',
    business_practical: '',
    // Calificar, objeciones y datos antes de pasarlo
    objections: [],
    required_contact: [],
    // Si deja de contestar (Motor2::FollowUp): recordatorios en 24 h y plantillas después.
    follow_up: { nudges: 2, templates: [], template_days: 2 },
    // Recordatorio de la cita y «¿otro horario?» si no llegó (Motor2::AppointmentNotice).
    appointment_notice: { on: true, template: '' },
    // En cuántas horas hábiles le debe escribir el vendedor (0 = sin aviso).
    attend_hours: 1,
    // Cotizar (Motor2::Skills::Quote): off | draft | send.
    quote: { mode: 'off', follow_days: 3 },
  },
});

export default {
  name: 'ReadyAgentModal',
  components: { AgentFiles, SourceOrder, FollowUpPlan, QuoteMode, AgentVoice },
  props: {
    show: { type: Boolean, default: false },
    kind: { type: String, default: 'prospects' },
    title: { type: String, default: '' },
    agent: { type: Object, default: null },
    inboxes: { type: Array, default: () => [] },
    // Bandejas que ya tienen otro agente listo prendido (no se pueden elegir).
    takenInboxIds: { type: Array, default: () => [] },
    // Personas con Google Calendar conectado (con quién se agenda la cita).
    calendarUsers: { type: Array, default: () => [] },
    // Las fuentes de la cuenta con qué hay en cada una (Motor2::SourceMap).
    sources: { type: Array, default: () => [] },
  },
  emits: ['close', 'saved'],
  data() {
    return {
      form: blank(this.kind),
      saving: false,
      suggesting: false,
      chat: [],
      // La memoria del cliente en el chat de prueba (respuestas, cita…): va y viene con el motor.
      chatState: {},
      draft: '',
      testing: false,
      step: 'agent',
      pendingFiles: [],
    };
  },
  computed: {
    ...mapGetters({ agents: 'agents/getAgents', teams: 'teams/getTeams' }),
    hasCatalog() {
      return this.sources.some(s => s.key === 'catalog');
    },
    // Las plantillas aprobadas de su primera bandeja de WhatsApp (para después de las 24 h).
    waTemplates() {
      const inbox = this.inboxes.find(
        i =>
          this.form.inbox_ids.includes(i.id) &&
          String(i.channel_type).includes('Whatsapp')
      );
      if (!inbox) return [];
      const list =
        this.$store.getters['inboxes/getWhatsAppTemplates'](inbox.id) || [];
      return [...new Set(list.map(item => item.name))];
    },
    objectives() {
      return ['handoff', 'appointment', 'opportunity', 'collect'];
    },
    appointment() {
      return this.form.settings.objective === 'appointment';
    },
    tones() {
      return ['cercano', 'formal', 'directo', 'empresa'];
    },
    contactFields() {
      return CONTACT_FIELDS;
    },
    rules() {
      return RULES;
    },
    // Sin contestar dudas no busca en ninguna fuente: «Qué sabe» no aplica.
    answersDoubts() {
      return this.form.settings.doubts !== 'defer';
    },
    canAddQuestion() {
      return this.form.settings.question_list.length < MAX_QUESTIONS;
    },
    cannedSource() {
      return this.sources.find(s => s.key === 'canned_response');
    },
    // Las que se marcan (el Catálogo de productos va en «productos y precios»).
    otherSources() {
      return this.sources.filter(
        s => s.key !== 'canned_response' && s.kind !== 'catalog'
      );
    },
    // ¿Dónde están tus productos y precios?: catálogo, cada hoja, predefinidas o no da precios.
    priceOptions() {
      const options = this.sources
        .filter(s => s.kind === 'catalog' || s.kind === 'google_sheet')
        .map(s => ({
          value: s.key,
          label: s.name,
          about: s.about,
          faq: s.sheet_mode === 'faq',
        }));
      return [
        ...options,
        { value: 'canned', label: this.t('KNOWS.PRICES.canned') },
        { value: 'none', label: this.t('KNOWS.PRICES.none') },
      ];
    },
    priceSheetFaq() {
      const picked = this.priceOptions.find(
        o => o.value === this.form.settings.price_source
      );
      return !!(picked && picked.faq);
    },
    steps() {
      return STEPS;
    },
    stepIndex() {
      return STEPS.indexOf(this.step);
    },
    isLast() {
      return this.stepIndex === STEPS.length - 1;
    },
    // Paso 1 completo: nombre y al menos una bandeja.
    agentReady() {
      return !!(this.form.name.trim() && this.form.inbox_ids.length);
    },
    canSave() {
      if (this.appointment && !this.form.settings.appointment_user_ids.length)
        return false;
      return this.form.name.trim() && this.form.inbox_ids.length;
    },
  },
  watch: {
    show: {
      immediate: true,
      handler(open) {
        if (open) this.reset();
      },
    },
  },
  methods: {
    t(key, params) {
      return this.$t(`${T}.${key}`, params);
    },
    reset() {
      const base = blank(this.kind);
      this.form = this.agent
        ? {
            ...base,
            ...JSON.parse(JSON.stringify(this.agent)),
            settings: {
              ...base.settings,
              ...JSON.parse(JSON.stringify(this.agent.settings || {})),
              question_list: this.questionsOf(this.agent.settings || {}),
              ...this.rulesOf(this.agent.settings || {}),
              price_source: this.priceSourceOf(this.agent.settings || {}),
              objections: this.agent.settings?.objections || [],
              required_contact: this.agent.settings?.required_contact || [],
              // Los agentes de antes no tenían recordatorios: siguen sin ellos hasta que los prendan.
              follow_up: {
                nudges: 0,
                templates: [],
                template_days: 2,
                ...(this.agent.settings?.follow_up || {}),
              },
              appointment_notice: {
                on: false,
                template: '',
                ...(this.agent.settings?.appointment_notice || {}),
              },
              attend_hours: this.agent.settings?.attend_hours ?? 0,
              quote: {
                mode: 'off',
                follow_days: 3,
                ...(this.agent.settings?.quote || {}),
              },
            },
          }
        : {
            ...base,
            settings: {
              ...base.settings,
              question_list: this.exampleQuestions(),
              price_source: this.priceSourceOf({}),
              // Nuevo: con Catálogo, borrador para el vendedor (recomendado).
              quote: {
                mode: this.hasCatalog ? 'draft' : 'off',
                follow_days: 3,
              },
            },
          };
      this.chat = [];
      this.chatState = {};
      this.draft = '';
      this.step = 'agent';
      this.pendingFiles = [];
      this.$store.dispatch('agents/get');
      this.$store.dispatch('teams/get');
    },
    go(step) {
      // Al crear, no se avanza sin nombre y bandeja; al editar se salta a cualquier paso.
      if (!this.agent && step !== 'agent' && !this.agentReady) return;
      this.step = step;
    },
    next() {
      if (!this.isLast) this.go(STEPS[this.stepIndex + 1]);
    },
    back() {
      if (this.stepIndex > 0) this.step = STEPS[this.stepIndex - 1];
    },
    // «No encontró» y «fuera de tema» solo aplican si contesta dudas.
    ruleOff(rule) {
      return !this.answersDoubts && NEEDS_DOUBTS.includes(rule);
    },
    toggleSource(key) {
      const list = this.form.sources;
      this.form.sources = list.includes(key)
        ? list.filter(k => k !== key)
        : addSource(list, key);
    },
    resetChat() {
      this.chat = [];
      this.chatState = {};
    },
    // Las de ejemplo (agente nuevo) o las guardadas; en un agente de antes, sus armadas prendidas
    // y sus preguntas propias.
    questionsOf(settings) {
      const saved = settings.question_list;
      if (Array.isArray(saved) && saved.length)
        return saved.map(text => ({ text }));
      if (!Array.isArray(settings.qualify) || !settings.qualify.length)
        return settings.questions
          ? [{ text: this.t('QUALIFY.need.ASK') }, { text: settings.questions }]
          : this.exampleQuestions();
      const armed = QUALIFY_KEYS.filter(key =>
        settings.qualify.some(q => q.key === key && q.on)
      ).map(key => {
        const row = settings.qualify.find(q => q.key === key);
        return { text: row.text || this.t(`QUALIFY.${key}.ASK`) };
      });
      const own = settings.questions ? [{ text: settings.questions }] : [];
      return [...armed, ...own];
    },
    // Lo guardado; los de antes con «mis precios están en el Catálogo» → el catálogo; un agente
    // nuevo, el catálogo si la cuenta tiene, si no las predefinidas.
    priceSourceOf(settings) {
      if (settings.price_source) return settings.price_source;
      const hasCatalog = this.sources.some(s => s.kind === 'catalog');
      if (settings.business_use_catalog || (!this.agent && hasCatalog))
        return 'catalog';
      return 'canned';
    },
    // Las opciones guardadas; las de antes pasan a la recomendada.
    rulesOf(settings) {
      return Object.fromEntries(
        Object.entries(RULES).map(([rule, values]) => {
          const saved = settings[rule];
          const value = (LEGACY[rule] && LEGACY[rule][saved]) || saved;
          return [rule, values.includes(value) ? value : values[0]];
        })
      );
    },
    exampleQuestions() {
      return EXAMPLE_KEYS.map(key => ({ text: this.t(`QUALIFY.${key}.ASK`) }));
    },
    // Ideas comunes para descartar (fuera de zona, presupuesto, no lo vendemos…): se agregan al texto.
    addDiscardIdea(idea) {
      const now = this.form.settings.discard_when.trim();
      if (now.includes(idea)) return;
      this.form.settings.discard_when = now ? `${now}; ${idea}` : idea;
    },
    // Preguntas para calificar según su negocio (cualquier giro); quedan para que las cambie.
    async suggestQuestions() {
      this.suggesting = true;
      try {
        const { data } = await ReadyAgentsAPI.suggest(
          'questions',
          this.form.settings
        );
        if (data.questions?.length)
          this.form.settings.question_list = data.questions.map(text => ({
            text,
          }));
      } catch (e) {
        useAlert(this.t('QUESTIONS_LIST.SUGGEST_ERROR'));
      } finally {
        this.suggesting = false;
      }
    },
    addQuestion() {
      if (this.canAddQuestion)
        this.form.settings.question_list.push({ text: '' });
    },
    removeQuestion(index) {
      this.form.settings.question_list.splice(index, 1);
    },
    // ↑ / ↓: el agente las hace en el orden de la lista.
    moveQuestion(index, step) {
      const list = this.form.settings.question_list;
      const to = index + step;
      if (to < 0 || to >= list.length) return;
      list.splice(to, 0, list.splice(index, 1)[0]);
    },
    toggleCalendarUser(id) {
      const ids = this.form.settings.appointment_user_ids.map(String);
      const key = String(id);
      this.form.settings.appointment_user_ids = ids.includes(key)
        ? ids.filter(i => i !== key)
        : [...ids, key];
    },
    calendarUserOn(id) {
      return this.form.settings.appointment_user_ids
        .map(String)
        .includes(String(id));
    },
    toggleContact(field) {
      const list = this.form.settings.required_contact;
      this.form.settings.required_contact = list.includes(field)
        ? list.filter(f => f !== field)
        : [...list, field];
    },
    addObjection() {
      this.form.settings.objections.push({ objection: '', answer: '' });
    },
    removeObjection(index) {
      this.form.settings.objections.splice(index, 1);
    },
    toggleInbox(id) {
      const ids = this.form.inbox_ids;
      this.form.inbox_ids = ids.includes(id)
        ? ids.filter(i => i !== id)
        : [...ids, id];
    },
    payload() {
      const { settings } = this.form;
      return {
        ...this.form,
        name: this.form.name.trim(),
        settings: {
          ...settings,
          // Una sola lista: lo de antes (armadas con casilla y preguntas propias) se deja vacío.
          question_list: settings.question_list
            .map(q => q.text.trim())
            .filter(Boolean),
          qualify: [],
          questions: '',
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
    // Chat de prueba: tú eres el cliente.
    async send() {
      const text = this.draft.trim();
      if (!text || this.testing) return;
      this.chat.push({ role: 'user', content: text });
      this.draft = '';
      this.testing = true;
      try {
        const { data } = await ReadyAgentsAPI.test(
          { ...this.payload(), name: this.form.name.trim() || 'Agente' },
          this.chat
            .filter(m => ['user', 'assistant'].includes(m.role))
            .map(({ role, content }) => ({ role, content })),
          { id: this.agent && this.agent.id, state: this.chatState }
        );
        this.chatState = data.state || this.chatState;
        this.chat.push({
          role: 'assistant',
          content: data.reply || this.t('TEST.NO_MESSAGE'),
          tools: data.tools || [],
          decision: data.decision,
          files: data.files || [],
          temperature: (data.state || {}).temperature,
        });
      } catch (e) {
        this.chat.push({
          role: 'error',
          content: e.response?.data?.error || this.t('TEST.ERROR'),
        });
      } finally {
        this.testing = false;
        this.$nextTick(() => {
          const box = this.$refs.chatBox;
          if (box) box.scrollTop = box.scrollHeight;
        });
      }
    },
    toolLine(tool) {
      const label = this.$te(`${T}.TOOLS.${tool.name}`)
        ? this.t(`TOOLS.${tool.name}`)
        : tool.name;
      const detail = Object.values(tool.args || {})
        .filter(Boolean)
        .join(' · ');
      const line = detail ? `${label}: ${detail}` : label;
      // Lo que el código no dejó hacer (p. ej. pasarlo antes de terminar las preguntas).
      return tool.ok === false ? `${line} ${this.t('TEST.NOT_DONE')}` : line;
    },
  },
};
</script>

<template>
  <woot-modal :show="show" size="medium" :on-close="() => $emit('close')">
    <div class="flex flex-col h-[85vh] min-h-0">
      <woot-modal-header
        :header-title="
          agent
            ? t('EDIT_TITLE', { name: agent.name })
            : t('NEW_TITLE', { title })
        "
        :header-content="t('MODAL_SUBTITLE')"
      />
      <div
        class="grid flex-1 min-h-0 grid-cols-1 gap-5 px-4 pb-4 overflow-y-auto md:px-8 md:grid-cols-2 md:grid-rows-1 md:overflow-hidden"
      >
        <!-- El asistente: un paso a la vez -->
        <form
          class="ready-form flex flex-col gap-2.5 overflow-y-auto !p-0 !pr-1 !self-stretch"
          @submit.prevent="isLast || agent ? save() : next()"
        >
          <!-- Los pasos: al editar se puede saltar a cualquiera -->
          <ol class="flex flex-wrap gap-1 p-0 m-0 list-none">
            <li v-for="(s, i) in steps" :key="s">
              <button
                type="button"
                class="px-2 py-0.5 text-xs border rounded-full"
                :class="
                  s === step
                    ? 'border-woot-500 bg-woot-50 text-woot-700 dark:bg-woot-900/30 dark:text-woot-200'
                    : 'border-slate-200 text-slate-500 dark:border-slate-700 dark:text-slate-400'
                "
                @click="go(s)"
              >
                {{ t('STEPS.NUMBERED', { n: i + 1, step: t(`STEPS.${s}`) }) }}
              </button>
            </li>
          </ol>
          <p class="m-0 text-xs text-slate-500">
            {{ t(`STEP_HINTS.${step}`) }}
          </p>

          <!-- 1 · El agente y sus bandejas -->
          <template v-if="step === 'agent'">
            <div class="grid grid-cols-2 gap-3">
              <label class="block">
                <span class="field-label">{{ t('FIELDS.NAME') }}</span>
                <input
                  v-model="form.name"
                  type="text"
                  :placeholder="t('FIELDS.NAME_PLACEHOLDER')"
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
            <div>
              <span class="field-label">{{ t('FIELDS.INBOXES') }}</span>
              <div class="flex flex-wrap gap-1.5">
                <button
                  v-for="inbox in inboxes"
                  :key="inbox.id"
                  type="button"
                  class="px-2.5 py-1 text-xs border rounded-full"
                  :disabled="takenInboxIds.includes(inbox.id)"
                  :title="
                    takenInboxIds.includes(inbox.id)
                      ? t('FIELDS.INBOX_TAKEN')
                      : ''
                  "
                  :class="
                    form.inbox_ids.includes(inbox.id)
                      ? 'border-woot-500 bg-woot-50 text-woot-700 dark:bg-woot-900/30 dark:text-woot-200'
                      : 'border-slate-200 text-slate-600 dark:border-slate-700 dark:text-slate-300 disabled:opacity-40'
                  "
                  @click="toggleInbox(inbox.id)"
                >
                  {{ inbox.name }}
                </button>
              </div>
            </div>
            <label
              class="flex items-center gap-2 text-sm font-medium text-slate-800 dark:text-slate-100"
            >
              <input v-model="form.enabled" type="checkbox" class="!m-0" />
              {{ t('FIELDS.ENABLED') }}
            </label>
          </template>

          <!-- 2 · Tu negocio -->
          <template v-if="step === 'business'">
            <label class="block">
              <span class="field-label">{{ t('BUSINESS.WHAT') }}</span>
              <textarea
                v-model="form.settings.business_what"
                rows="2"
                :placeholder="t('BUSINESS.WHAT_PLACEHOLDER')"
              />
            </label>
            <label class="block">
              <span class="field-label">{{ t('BUSINESS.WHO') }}</span>
              <textarea
                v-model="form.settings.business_who"
                rows="2"
                :placeholder="t('BUSINESS.WHO_PLACEHOLDER')"
              />
            </label>
            <label class="block">
              <span class="field-label">{{ t('BUSINESS.COVERAGE') }}</span>
              <textarea
                v-model="form.settings.business_coverage"
                rows="2"
                :placeholder="t('BUSINESS.COVERAGE_PLACEHOLDER')"
              />
            </label>
            <label class="block">
              <span class="field-label">{{ t('BUSINESS.WHY') }}</span>
              <textarea
                v-model="form.settings.business_why"
                rows="2"
                :placeholder="t('BUSINESS.WHY_PLACEHOLDER')"
              />
            </label>
            <label class="block">
              <span class="field-label">{{ t('BUSINESS.PRACTICAL') }}</span>
              <textarea
                v-model="form.settings.business_practical"
                rows="2"
                :placeholder="t('BUSINESS.PRACTICAL_PLACEHOLDER')"
              />
            </label>
          </template>

          <!-- 3 · Qué sabe: sus fuentes y qué hay en cada una -->
          <template v-if="step === 'knows'">
            <fieldset
              class="flex flex-col gap-1 p-2 m-0 border rounded-md border-slate-100 dark:border-slate-700"
              :disabled="!answersDoubts"
              :class="{ 'opacity-50': !answersDoubts }"
            >
              <legend
                class="px-1 text-xs font-medium text-slate-600 dark:text-slate-300"
              >
                {{ t('KNOWS.PRICES.QUESTION') }}
              </legend>
              <label
                v-for="option in priceOptions"
                :key="option.value"
                class="flex items-start gap-2 text-sm cursor-pointer text-slate-700 dark:text-slate-200"
              >
                <input
                  v-model="form.settings.price_source"
                  type="radio"
                  class="!m-0 mt-1 shrink-0"
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
              <p
                v-if="priceSheetFaq"
                class="m-0 text-xs text-amber-700 dark:text-amber-400"
              >
                {{ t('KNOWS.PRICES.SHEET_FAQ') }}
              </p>
            </fieldset>
            <p
              v-if="!answersDoubts"
              class="p-2 m-0 text-xs rounded-md bg-amber-50 text-amber-800 dark:bg-amber-900/30 dark:text-amber-200"
            >
              {{ t('KNOWS.NO_DOUBTS') }}
            </p>
            <div
              class="p-2 text-xs rounded-md bg-slate-25 dark:bg-slate-800 text-slate-600 dark:text-slate-300"
            >
              <span class="block font-medium">{{ t('KNOWS.CANNED') }}</span>
              <span v-if="cannedSource">{{ cannedSource.about }}</span>
              <span v-else class="text-amber-700">{{
                t('KNOWS.NO_CANNED')
              }}</span>
            </div>
            <p v-if="!otherSources.length" class="m-0 text-xs text-slate-500">
              {{ t('KNOWS.NO_OTHERS') }}
            </p>
            <label
              v-for="src in otherSources"
              :key="src.key"
              class="flex items-start gap-2 p-2 border rounded-md cursor-pointer border-slate-100 dark:border-slate-700"
            >
              <input
                type="checkbox"
                class="!m-0 mt-0.5 shrink-0"
                :checked="form.sources.includes(src.key)"
                :disabled="!answersDoubts"
                @change="toggleSource(src.key)"
              />
              <span class="text-sm">
                <span class="block font-medium">{{ src.name }}</span>
                <span class="block text-xs text-slate-500">{{
                  src.about
                }}</span>
              </span>
            </label>
            <SourceOrder v-model="form.sources" :sources="sources" />
            <p class="m-0 text-xs text-slate-500">
              {{ t('KNOWS.WHERE_HINT') }}
            </p>
          </template>

          <!-- 4 · Qué le preguntas -->
          <template v-if="step === 'questions'">
            <div class="flex items-center gap-2">
              <woot-button
                size="small"
                variant="smooth"
                icon="wand"
                :is-loading="suggesting"
                :disabled="!form.settings.business_what.trim()"
                @click="suggestQuestions"
              >
                {{ t('QUESTIONS_LIST.SUGGEST') }}
              </woot-button>
              <span class="text-xs text-slate-500">{{
                t('QUESTIONS_LIST.SUGGEST_HINT')
              }}</span>
            </div>
            <div
              v-for="(q, i) in form.settings.question_list"
              :key="i"
              class="flex items-center gap-2"
            >
              <span class="w-5 text-xs text-right shrink-0 text-slate-500">{{
                t('QUESTIONS_LIST.NUMBER', { n: i + 1 })
              }}</span>
              <input
                v-model="q.text"
                type="text"
                maxlength="300"
                class="flex-1 !mb-0 h-8 text-sm"
                :placeholder="t('QUESTIONS_LIST.PLACEHOLDER')"
              />
              <button
                type="button"
                class="px-1 text-slate-400 hover:text-slate-700 disabled:opacity-30"
                :title="t('QUESTIONS_LIST.UP')"
                :disabled="i === 0"
                @click="moveQuestion(i, -1)"
              >
                <fluent-icon icon="chevron-up" size="14" />
              </button>
              <button
                type="button"
                class="px-1 text-slate-400 hover:text-slate-700 disabled:opacity-30"
                :title="t('QUESTIONS_LIST.DOWN')"
                :disabled="i === form.settings.question_list.length - 1"
                @click="moveQuestion(i, 1)"
              >
                <fluent-icon icon="chevron-down" size="14" />
              </button>
              <button
                type="button"
                class="px-1 text-slate-400 hover:text-red-600"
                :title="t('QUESTIONS_LIST.REMOVE')"
                @click="removeQuestion(i)"
              >
                <fluent-icon icon="dismiss" size="14" />
              </button>
            </div>
            <p
              v-if="!form.settings.question_list.length"
              class="m-0 text-xs text-amber-700"
            >
              {{ t('QUESTIONS_LIST.EMPTY') }}
            </p>
            <button
              v-if="canAddQuestion"
              type="button"
              class="self-start text-xs text-woot-600 hover:underline"
              @click="addQuestion"
            >
              {{ t('QUESTIONS_LIST.ADD') }}
            </button>
            <p class="m-0 text-xs text-slate-500">
              {{ t('QUESTIONS_LIST.SMART') }}
            </p>
          </template>

          <!-- 5 · Cómo platica: dudas, lo que no encuentra y lo que no es del negocio -->
          <template v-if="step === 'talk'">
            <AgentVoice v-model="form.settings.voice" />
            <label class="block">
              <span class="field-label">{{ t('TALK.WELCOME') }}</span>
              <textarea
                v-model="form.settings.welcome"
                rows="3"
                maxlength="1500"
                :placeholder="t('TALK.WELCOME_PLACEHOLDER')"
              />
              <span class="block mt-1 text-xs text-slate-500">{{
                t('TALK.WELCOME_HINT')
              }}</span>
            </label>
            <fieldset
              v-for="(values, rule) in rules"
              :key="rule"
              :disabled="ruleOff(rule)"
              class="flex flex-col gap-1 p-2 m-0 border rounded-md border-slate-100 dark:border-slate-700"
              :class="{ 'opacity-50': ruleOff(rule) }"
            >
              <legend
                class="px-1 text-xs font-medium text-slate-600 dark:text-slate-300"
              >
                {{ t(`TALK.${rule}.QUESTION`) }}
              </legend>
              <p v-if="ruleOff(rule)" class="m-0 text-xs text-slate-500">
                {{ t('TALK.ONLY_IF_ANSWERS') }}
              </p>
              <label
                v-for="(value, i) in values"
                :key="value"
                class="flex items-start gap-2 text-sm cursor-pointer text-slate-700 dark:text-slate-200"
              >
                <input
                  v-model="form.settings[rule]"
                  type="radio"
                  class="!m-0 mt-1 shrink-0"
                  :value="value"
                />
                <span>
                  {{ t(`TALK.${rule}.${value}`) }}
                  <span v-if="i === 0" class="text-xs text-woot-600">{{
                    t('TALK.RECOMMENDED')
                  }}</span>
                </span>
              </label>
            </fieldset>
          </template>

          <!-- 6 · Cuándo califica y cuándo no -->
          <template v-if="step === 'qualify'">
            <label class="block">
              <span class="field-label">{{ t('FIELDS.QUALIFIED_WHEN') }}</span>
              <textarea
                v-model="form.settings.qualified_when"
                rows="3"
                :placeholder="t('FIELDS.QUALIFIED_PLACEHOLDER')"
              />
            </label>
            <label class="block">
              <span class="field-label">{{ t('FIELDS.DISCARD_WHEN') }}</span>
              <textarea
                v-model="form.settings.discard_when"
                rows="3"
                :placeholder="t('FIELDS.DISCARD_PLACEHOLDER')"
              />
            </label>
            <div class="flex flex-wrap gap-1.5">
              <button
                v-for="(idea, i) in t('FIELDS.DISCARD_IDEAS').split('|')"
                :key="i"
                type="button"
                class="px-2.5 py-1 text-xs border rounded-full border-slate-200 text-slate-600 dark:border-slate-700 dark:text-slate-300"
                @click="addDiscardIdea(idea)"
              >
                + {{ idea }}
              </button>
            </div>
            <label class="block">
              <span class="field-label">{{ t('FIELDS.HOT_WHEN') }}</span>
              <textarea
                v-model="form.settings.hot_when"
                rows="2"
                :placeholder="t('FIELDS.HOT_PLACEHOLDER')"
              />
            </label>
            <p class="m-0 text-xs text-slate-500">
              {{ t('SECTIONS.TEMPERATURE_HINT') }}
            </p>
          </template>

          <!-- 7 · Qué hacer al calificar y a quién -->
          <!-- Seguimiento: si deja de contestar (Motor2::FollowUp), con su línea de tiempo -->
          <template v-if="step === 'follow'">
            <FollowUpPlan
              v-model="form.settings.follow_up"
              :templates="waTemplates"
              kind="prospects"
            />
          </template>

          <template v-if="step === 'after'">
            <label class="block">
              <span class="field-label">{{ t('FIELDS.OBJECTIVE') }}</span>
              <select v-model="form.settings.objective">
                <option v-for="o in objectives" :key="o" :value="o">
                  {{ t(`OBJECTIVES.${o}`) }}
                </option>
              </select>
            </label>
            <!-- Citas: con quién, duración, tipo y lugar -->
            <div
              v-if="appointment"
              class="flex flex-col gap-2 p-3 rounded-lg bg-slate-25 dark:bg-slate-800"
            >
              <span class="field-label !mb-0">{{
                t('FIELDS.APPOINTMENT_USERS')
              }}</span>
              <p
                v-if="!calendarUsers.length"
                class="m-0 text-xs text-amber-700"
              >
                {{ t('FIELDS.NO_CALENDARS') }}
              </p>
              <div v-else class="flex flex-wrap gap-1.5">
                <button
                  v-for="u in calendarUsers"
                  :key="u.id"
                  type="button"
                  class="px-2.5 py-1 text-xs border rounded-full"
                  :class="
                    calendarUserOn(u.id)
                      ? 'border-woot-500 bg-woot-50 text-woot-700 dark:bg-woot-900/30 dark:text-woot-200'
                      : 'border-slate-200 text-slate-600 dark:border-slate-700 dark:text-slate-300'
                  "
                  @click="toggleCalendarUser(u.id)"
                >
                  {{ u.name }}
                </button>
              </div>
              <div class="grid grid-cols-3 gap-3">
                <label class="block">
                  <span class="field-label">{{
                    t('FIELDS.APPOINTMENT_MINUTES')
                  }}</span>
                  <select v-model="form.settings.appointment_minutes">
                    <option
                      v-for="m in ['15', '30', '45', '60', '90']"
                      :key="m"
                      :value="m"
                    >
                      {{ t('FIELDS.MINUTES', { n: m }) }}
                    </option>
                  </select>
                </label>
                <label class="block">
                  <span class="field-label">{{
                    t('FIELDS.APPOINTMENT_KIND')
                  }}</span>
                  <select v-model="form.settings.appointment_kind">
                    <option
                      v-for="k in [
                        'llamada',
                        'videollamada',
                        'visita',
                        'oficina',
                      ]"
                      :key="k"
                      :value="k"
                    >
                      {{ t(`APPOINTMENT_KINDS.${k}`) }}
                    </option>
                  </select>
                </label>
                <label class="block">
                  <span class="field-label">{{
                    t('FIELDS.APPOINTMENT_LOCATION')
                  }}</span>
                  <input
                    v-model="form.settings.appointment_location"
                    type="text"
                    :placeholder="t('FIELDS.APPOINTMENT_LOCATION_PLACEHOLDER')"
                  />
                </label>
              </div>
              <p class="m-0 text-xs text-slate-500">
                {{ t('FIELDS.APPOINTMENT_HINT') }}
              </p>
              <label class="flex items-start gap-2 text-sm">
                <input
                  v-model="form.settings.appointment_notice.on"
                  type="checkbox"
                  class="!m-0 mt-1"
                />
                {{ t('FIELDS.APPOINTMENT_NOTICE') }}
              </label>
              <label
                v-if="form.settings.appointment_notice.on && waTemplates.length"
                class="block"
              >
                <span class="field-label">{{
                  t('FIELDS.APPOINTMENT_NOTICE_TEMPLATE')
                }}</span>
                <select v-model="form.settings.appointment_notice.template">
                  <option value="">{{ t('FIELDS.NO_TEMPLATE') }}</option>
                  <option v-for="tpl in waTemplates" :key="tpl" :value="tpl">
                    {{ tpl }}
                  </option>
                </select>
              </label>
            </div>
            <div class="grid grid-cols-2 gap-3">
              <label class="block">
                <span class="field-label">{{ t('FIELDS.HANDOFF_USER') }}</span>
                <select v-model="form.settings.handoff_user_id">
                  <option value="">{{ t('FIELDS.NOBODY') }}</option>
                  <option v-for="a in agents" :key="a.id" :value="a.id">
                    {{ a.name }}
                  </option>
                </select>
              </label>
              <label class="block">
                <span class="field-label">{{ t('FIELDS.HANDOFF_TEAM') }}</span>
                <select v-model="form.settings.handoff_team_id">
                  <option value="">{{ t('FIELDS.NO_TEAM') }}</option>
                  <option v-for="team in teams" :key="team.id" :value="team.id">
                    {{ team.name }}
                  </option>
                </select>
              </label>
            </div>
            <label class="block">
              <span class="field-label">{{ t('FIELDS.ATTEND_HOURS') }}</span>
              <select v-model.number="form.settings.attend_hours">
                <option v-for="h in [0, 1, 2, 4, 8]" :key="h" :value="h">
                  {{
                    h
                      ? t('FIELDS.ATTEND_HOURS_N', { n: h })
                      : t('FIELDS.ATTEND_OFF')
                  }}
                </option>
              </select>
              <span class="block mt-1 text-xs text-slate-500">{{
                t('FIELDS.ATTEND_HINT')
              }}</span>
            </label>
            <QuoteMode
              v-model="form.settings.quote"
              :has-catalog="hasCatalog"
            />
            <span class="field-label">{{ t('FIELDS.REQUIRED_CONTACT') }}</span>
            <div class="flex flex-wrap gap-1.5">
              <button
                v-for="field in contactFields"
                :key="field"
                type="button"
                class="px-2.5 py-1 text-xs border rounded-full"
                :class="
                  form.settings.required_contact.includes(field)
                    ? 'border-woot-500 bg-woot-50 text-woot-700 dark:bg-woot-900/30 dark:text-woot-200'
                    : 'border-slate-200 text-slate-600 dark:border-slate-700 dark:text-slate-300'
                "
                @click="toggleContact(field)"
              >
                {{ t(`CONTACT_FIELDS.${field}`) }}
              </button>
            </div>
            <label
              class="flex items-center gap-2 text-sm text-slate-700 dark:text-slate-200"
            >
              <input
                v-model="form.settings.only_prospects"
                type="checkbox"
                class="!m-0"
              />
              {{ t('FIELDS.ONLY_PROSPECTS') }}
            </label>
            <div
              v-if="form.settings.only_prospects"
              class="grid grid-cols-2 gap-3"
            >
              <label class="block">
                <span class="field-label">{{ t('FIELDS.CLIENT_USER') }}</span>
                <select v-model="form.settings.client_user_id">
                  <option value="">{{ t('FIELDS.NOBODY') }}</option>
                  <option v-for="a in agents" :key="a.id" :value="a.id">
                    {{ a.name }}
                  </option>
                </select>
              </label>
              <label class="block">
                <span class="field-label">{{ t('FIELDS.CLIENT_TEAM') }}</span>
                <select v-model="form.settings.client_team_id">
                  <option value="">{{ t('FIELDS.NO_TEAM') }}</option>
                  <option v-for="team in teams" :key="team.id" :value="team.id">
                    {{ team.name }}
                  </option>
                </select>
              </label>
            </div>
          </template>

          <!-- 8 · Objeciones -->
          <template v-if="step === 'objections'">
            <div
              v-for="(o, i) in form.settings.objections"
              :key="i"
              class="flex flex-col gap-1 p-2 rounded-md bg-slate-25 dark:bg-slate-800"
            >
              <div class="flex items-center gap-2">
                <input
                  v-model="o.objection"
                  type="text"
                  class="flex-1 !mb-0 h-8 text-sm"
                  :placeholder="t('OBJECTIONS.OBJECTION_PLACEHOLDER')"
                />
                <button
                  type="button"
                  class="px-1 text-slate-400 hover:text-red-600"
                  :title="t('OBJECTIONS.REMOVE')"
                  @click="removeObjection(i)"
                >
                  <fluent-icon icon="dismiss" size="14" />
                </button>
              </div>
              <textarea
                v-model="o.answer"
                rows="2"
                class="!mb-0 text-sm"
                :placeholder="t('OBJECTIONS.ANSWER_PLACEHOLDER')"
              />
            </div>
            <button
              type="button"
              class="self-start text-xs text-woot-600 hover:underline"
              @click="addObjection"
            >
              {{ t('OBJECTIONS.ADD') }}
            </button>
          </template>

          <!-- 9 · Indicaciones -->
          <template v-if="step === 'files'">
            <AgentFiles
              v-model="form.files"
              kind="prospects"
              :agent-id="agent ? agent.id : null"
              :booking="appointment"
              @pending="pendingFiles = $event"
            />
          </template>

          <template v-if="step === 'instructions'">
            <label class="block">
              <span class="field-label">{{ t('FIELDS.INSTRUCTIONS') }}</span>
              <textarea
                v-model="form.settings.instructions"
                rows="6"
                :placeholder="t('FIELDS.INSTRUCTIONS_PLACEHOLDER')"
              />
            </label>
          </template>

          <!-- 10 · Pruébalo y guarda -->
          <template v-if="step === 'test'">
            <p class="m-0 text-sm text-slate-700 dark:text-slate-200">
              {{ t('STEP_TEST.READY', { name: form.name.trim() || '—' }) }}
            </p>
            <p
              v-if="!form.enabled"
              class="m-0 text-xs text-amber-700 dark:text-amber-400"
            >
              {{ t('STEP_TEST.OFF') }}
            </p>
          </template>
        </form>

        <!-- Chat de prueba: tú eres el cliente -->
        <div
          class="flex flex-col min-h-[22rem] border rounded-lg md:min-h-0 border-slate-100 dark:border-slate-700"
        >
          <div
            class="flex items-center justify-between px-3 py-2 border-b border-slate-100 dark:border-slate-700"
          >
            <span
              class="text-sm font-medium text-slate-800 dark:text-slate-100"
              >{{ t('TEST.TITLE') }}</span
            >
            <button
              type="button"
              class="text-xs text-woot-600 hover:underline"
              @click="chat = []"
            >
              {{ t('TEST.RESET') }}
            </button>
          </div>
          <div
            ref="chatBox"
            class="flex-1 min-h-0 p-3 space-y-2 overflow-y-auto"
          >
            <p v-if="!chat.length" class="m-0 text-xs text-slate-500">
              {{ t('TEST.HINT') }}
            </p>
            <div
              v-for="(m, i) in chat"
              :key="i"
              class="flex"
              :class="m.role === 'user' ? 'justify-start' : 'justify-end'"
            >
              <div
                class="max-w-[85%] px-3 py-2 text-sm rounded-lg whitespace-pre-line"
                :class="{
                  'bg-slate-100 text-slate-800 dark:bg-slate-800 dark:text-slate-100':
                    m.role === 'user',
                  'bg-woot-50 text-slate-800 dark:bg-woot-900/30 dark:text-slate-100':
                    m.role === 'assistant',
                  'bg-red-50 text-red-700': m.role === 'error',
                }"
              >
                <span>{{ m.content }}</span>
                <span
                  v-for="(tool, j) in m.tools || []"
                  :key="j"
                  class="block mt-1 text-[11px] text-slate-500"
                >
                  {{ t('TEST.TOOL', { tool: toolLine(tool) }) }}
                </span>
                <span
                  v-if="(m.files || []).length"
                  class="block mt-1 text-[11px] text-slate-500"
                >
                  {{ t('TEST.FILES', { files: m.files.join(', ') }) }}
                </span>
                <span
                  v-if="m.decision"
                  class="block mt-1 text-[11px] font-medium text-woot-700"
                >
                  {{
                    t('TEST.DECISION', {
                      decision: t(`DECISIONS.${m.decision[0]}`),
                    })
                  }}
                  {{
                    m.temperature
                      ? ` · ${t(`TEMPERATURES.${m.temperature}`)}`
                      : ''
                  }}
                </span>
              </div>
            </div>
            <p v-if="testing" class="m-0 text-xs text-right text-slate-400">
              {{ t('TEST.TYPING') }}
            </p>
          </div>
          <form
            class="flex gap-2 !p-2 !self-stretch border-t border-slate-100 dark:border-slate-700"
            @submit.prevent="send"
          >
            <input
              v-model="draft"
              type="text"
              class="flex-1 !mb-0 h-9 text-sm"
              :placeholder="t('TEST.PLACEHOLDER')"
            />
            <woot-button
              size="small"
              :is-loading="testing"
              :disabled="!draft.trim()"
            >
              {{ t('TEST.SEND') }}
            </woot-button>
          </form>
        </div>
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
        <woot-button
          v-if="isLast || agent"
          :is-loading="saving"
          :disabled="!canSave"
          @click="save"
        >
          {{ t('SAVE') }}
        </woot-button>
      </div>
    </div>
  </woot-modal>
</template>

<style lang="scss" scoped>
// Formulario compacto (como el de tareas): etiquetas chicas y campos de 36 px.
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
