<!--
  Asistente de la función «Atención a clientes» (Plan-Motor-Agentes §11.15.3): crear o cambiar un
  agente, paso a paso:
    1 el agente y sus bandejas · 2 tu negocio · 3 qué atiende (áreas: Soporte, Comercial,
    Administrativo y «Otra», con ejemplos sí/no, qué hace y a quién se pasa) · 4 qué sabe ·
    5 cómo platica · 6 indicaciones · 7 pruébalo («Probar la matriz» + chat de prueba)
  Qué área toca en cada mensaje lo decide el clasificador del código (Motor2::Triage); los ejemplos
  le enseñan y «Probar la matriz» los corre todos. Emite `saved` con el agente.
-->
<script>
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import ReadyAgentsAPI from 'dashboard/api/readyAgents';
import ReadyAgentChat from './ReadyAgentChat.vue';
import AiAgentAttachmentsAPI from 'dashboard/api/aiAgentAttachments';
import AgentFiles from './AgentFiles.vue';

const T = 'READY_AGENTS';
const STEPS = [
  'agent',
  'business',
  'areas',
  'knows',
  'files',
  'talk',
  'instructions',
  'test',
];
const AREA_KEYS = ['support', 'sales', 'admin', 'other'];
const MAX_EXAMPLES = 20;
// Los ejemplos de la matriz del plan (los mismos que trae el servidor si no se mandan).
const EXAMPLES = {
  support: {
    yes: [
      'No puedo enviar una cotización a pedido',
      'La cotización no se genera',
      'El módulo de facturación no carga',
      'No puedo generar mi factura porque marca error',
    ],
    no: ['Quiero una cotización', 'Mi factura tiene mal el RFC'],
  },
  sales: {
    yes: [
      '¿Qué planes tienen?',
      '¿Cuánto cuestan las licencias?',
      'Quiero una cotización',
      'Quiero cotización para 10 usuarios',
      'Quiero hablar con un vendedor',
      'Quiero una demo',
      'Quiero que un vendedor venga a verme',
      'Quiero contratar',
    ],
    no: [
      'No puedo enviar una cotización a pedido',
      'La cotización no se genera',
    ],
  },
  admin: {
    yes: [
      'Mi factura tiene mal el RFC',
      'Necesito mi factura',
      'Quiero enviar un comprobante de pago',
      'Quiero saber mi saldo',
    ],
    no: [
      'El módulo de facturación no carga',
      'No puedo generar mi factura porque marca error',
    ],
  },
  other: { yes: [], no: [] },
};
const AREA_DEFAULTS = {
  support: { on: true, action: 'case', details: true, case_type_id: '' },
  sales: {
    on: true,
    quote: 'opportunity',
    demo: 'handoff',
    visit: 'handoff',
    appointment_user_ids: [],
    appointment_minutes: '30',
    case_type_id: '',
  },
  admin: { on: true, case: false, case_type_id: '' },
  other: { on: false, name: '', description: '' },
};

const blankArea = key => ({
  ...JSON.parse(JSON.stringify(AREA_DEFAULTS[key])),
  user_id: '',
  team_id: '',
  // En la pantalla: [{ text }]; se mandan como lista de textos.
  examples_yes: EXAMPLES[key].yes.map(text => ({ text })),
  examples_no: EXAMPLES[key].no.map(text => ({ text })),
});

const blank = () => ({
  kind: 'customers',
  name: '',
  display_name: '',
  enabled: true,
  sources: [],
  inbox_ids: [],
  files: {},
  settings: {
    tone: 'cercano',
    welcome: '',
    instructions: '',
    human: 'understand_first',
    not_client: 'serve',
    user_id: '',
    team_id: '',
    price_source: '',
    business_what: '',
    business_who: '',
    business_coverage: '',
    business_why: '',
    business_practical: '',
    areas: Object.fromEntries(AREA_KEYS.map(k => [k, blankArea(k)])),
  },
});

export default {
  name: 'CustomersAgentModal',
  components: { ReadyAgentChat, AgentFiles },
  props: {
    show: { type: Boolean, default: false },
    title: { type: String, default: '' },
    agent: { type: Object, default: null },
    inboxes: { type: Array, default: () => [] },
    takenInboxIds: { type: Array, default: () => [] },
    calendarUsers: { type: Array, default: () => [] },
    sources: { type: Array, default: () => [] },
    caseTypes: { type: Array, default: () => [] },
  },
  emits: ['close', 'saved'],
  data() {
    return {
      form: blank(),
      saving: false,
      step: 'agent',
      openArea: 'support',
      matrix: null,
      matrixRunning: false,
      pendingFiles: [],
    };
  },
  computed: {
    ...mapGetters({ agents: 'agents/getAgents', teams: 'teams/getTeams' }),
    steps() {
      return STEPS;
    },
    areaKeys() {
      return AREA_KEYS;
    },
    tones() {
      return ['cercano', 'formal', 'directo'];
    },
    stepIndex() {
      return STEPS.indexOf(this.step);
    },
    isLast() {
      return this.stepIndex === STEPS.length - 1;
    },
    agentReady() {
      return !!(this.form.name.trim() && this.form.inbox_ids.length);
    },
    areasOn() {
      return AREA_KEYS.filter(k => this.form.settings.areas[k].on);
    },
    canSave() {
      return this.agentReady && this.areasOn.length > 0;
    },
    cannedSource() {
      return this.sources.find(s => s.key === 'canned_response');
    },
    otherSources() {
      return this.sources.filter(
        s => s.key !== 'canned_response' && s.kind !== 'catalog'
      );
    },
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
    matrixOk() {
      return (this.matrix || []).filter(r => r.ok).length;
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
    c(key, params) {
      return this.$t(`${T}.CUSTOMERS.${key}`, params);
    },
    reset() {
      const base = blank();
      if (this.agent) {
        const saved = JSON.parse(JSON.stringify(this.agent));
        const settings = saved.settings || {};
        this.form = {
          ...base,
          ...saved,
          files: saved.files || {},
          settings: {
            ...base.settings,
            ...settings,
            user_id: settings.user_id || '',
            team_id: settings.team_id || '',
            price_source: settings.price_source || 'canned',
            areas: this.areasOf(settings.areas || {}),
          },
        };
      } else {
        const hasCatalog = this.sources.some(s => s.kind === 'catalog');
        base.settings.price_source = hasCatalog ? 'catalog' : 'canned';
        this.form = base;
      }
      this.step = 'agent';
      this.pendingFiles = [];
      this.matrix = null;
      this.$store.dispatch('agents/get');
      this.$store.dispatch('teams/get');
    },
    // Lo guardado sobre los valores de cada área (los ejemplos guardados mandan, aunque estén vacíos).
    areasOf(saved) {
      return Object.fromEntries(
        AREA_KEYS.map(key => {
          const area = { ...blankArea(key), ...(saved[key] || {}) };
          ['examples_yes', 'examples_no'].forEach(field => {
            area[field] = Array.isArray(saved[key]?.[field])
              ? saved[key][field].map(text => ({ text }))
              : blankArea(key)[field];
          });
          area.user_id = area.user_id || '';
          area.team_id = area.team_id || '';
          area.case_type_id = area.case_type_id || '';
          return [key, area];
        })
      );
    },
    go(step) {
      if (!this.agent && step !== 'agent' && !this.agentReady) return;
      this.step = step;
    },
    next() {
      if (!this.isLast) this.go(STEPS[this.stepIndex + 1]);
    },
    back() {
      if (this.stepIndex > 0) this.step = STEPS[this.stepIndex - 1];
    },
    toggleInbox(id) {
      const ids = this.form.inbox_ids;
      this.form.inbox_ids = ids.includes(id)
        ? ids.filter(i => i !== id)
        : [...ids, id];
    },
    toggleSource(key) {
      const list = this.form.sources;
      this.form.sources = list.includes(key)
        ? list.filter(k => k !== key)
        : [...list, key];
    },
    area(key) {
      return this.form.settings.areas[key];
    },
    areaTitle(key) {
      if (key === 'other' && this.area('other').name.trim())
        return this.area('other').name.trim();
      return this.c(`AREAS.${key}.TITLE`);
    },
    addExample(key, field) {
      const list = this.area(key)[field];
      if (list.length < MAX_EXAMPLES) list.push({ text: '' });
    },
    removeExample(key, field, index) {
      this.area(key)[field].splice(index, 1);
    },
    casesOf(klass) {
      return this.caseTypes.filter(ct => ct.case_class === klass);
    },
    salesAppointments() {
      const sales = this.area('sales');
      return sales.demo === 'appointment' || sales.visit === 'appointment';
    },
    toggleCalendarUser(id) {
      const sales = this.area('sales');
      const ids = sales.appointment_user_ids.map(String);
      const key = String(id);
      sales.appointment_user_ids = ids.includes(key)
        ? ids.filter(i => i !== key)
        : [...ids, key];
    },
    calendarUserOn(id) {
      return this.area('sales')
        .appointment_user_ids.map(String)
        .includes(String(id));
    },
    payload() {
      const { settings } = this.form;
      const areas = Object.fromEntries(
        AREA_KEYS.map(key => {
          const area = settings.areas[key];
          return [
            key,
            {
              ...area,
              examples_yes: area.examples_yes
                .map(e => e.text.trim())
                .filter(Boolean),
              examples_no: area.examples_no
                .map(e => e.text.trim())
                .filter(Boolean),
            },
          ];
        })
      );
      return {
        ...this.form,
        name: this.form.name.trim() || 'Agente',
        settings: { ...settings, areas },
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
    // «Probar la matriz»: cada ejemplo sí/no por el clasificador.
    async runMatrix() {
      if (this.matrixRunning) return;
      this.matrixRunning = true;
      try {
        const { data } = await ReadyAgentsAPI.matrix(this.payload(), {
          id: this.agent && this.agent.id,
        });
        this.matrix = data.rows || [];
      } catch (e) {
        useAlert(e.response?.data?.error || this.c('MATRIX.ERROR'));
      } finally {
        this.matrixRunning = false;
      }
    },
    matrixRow(row) {
      return this.c('MATRIX.ROW', {
        icon: row.ok ? '✅' : '❌',
        example: row.example,
        line: this.matrixLine(row),
      });
    },
    matrixLine(row) {
      const expected =
        row.kind === 'yes'
          ? this.areaTitle(row.area)
          : this.c('MATRIX.NOT', { area: this.areaTitle(row.area) });
      const got =
        row.got && row.got !== 'none'
          ? this.areaTitle(row.got)
          : this.c('MATRIX.NONE');
      return this.c('MATRIX.LINE', { expected, got });
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
        :header-content="c('SUBTITLE')"
      />
      <div
        class="grid flex-1 min-h-0 grid-cols-1 gap-5 px-4 pb-4 overflow-y-auto md:px-8 md:grid-cols-2 md:grid-rows-1 md:overflow-hidden"
      >
        <form
          class="ready-form flex flex-col gap-2.5 overflow-y-auto !p-0 !pr-1 !self-stretch"
          @submit.prevent="isLast || agent ? save() : next()"
        >
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
                {{ t('STEPS.NUMBERED', { n: i + 1, step: c(`STEPS.${s}`) }) }}
              </button>
            </li>
          </ol>
          <p class="m-0 text-xs text-slate-500">
            {{ c(`STEP_HINTS.${step}`) }}
          </p>

          <!-- 1 · El agente y sus bandejas -->
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
              <p class="m-0 mt-1 text-xs text-slate-500">
                {{ c('PAIR_HINT') }}
              </p>
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
            <label
              v-for="field in ['what', 'who', 'coverage', 'why', 'practical']"
              :key="field"
              class="block"
            >
              <span class="field-label">{{
                t(`BUSINESS.${field.toUpperCase()}`)
              }}</span>
              <textarea
                v-model="form.settings[`business_${field}`]"
                rows="2"
                :placeholder="t(`BUSINESS.${field.toUpperCase()}_PLACEHOLDER`)"
              />
            </label>
          </template>

          <!-- 3 · Qué atiende: las áreas -->
          <template v-if="step === 'areas'">
            <p v-if="!areasOn.length" class="m-0 text-xs text-red-600">
              {{ c('AREAS_NONE') }}
            </p>
            <section
              v-for="key in areaKeys"
              :key="key"
              class="border rounded-md border-slate-100 dark:border-slate-700"
            >
              <header class="flex items-center gap-2 px-2 py-1.5">
                <input
                  v-model="area(key).on"
                  type="checkbox"
                  class="!m-0"
                  :aria-label="areaTitle(key)"
                />
                <button
                  type="button"
                  class="flex-1 text-sm font-medium text-left text-slate-800 dark:text-slate-100"
                  @click="openArea = openArea === key ? '' : key"
                >
                  {{ areaTitle(key) }}
                  <span class="block text-xs font-normal text-slate-500">
                    {{ c(`AREAS.${key}.ABOUT`) }}
                  </span>
                </button>
                <fluent-icon
                  :icon="openArea === key ? 'chevron-up' : 'chevron-down'"
                  size="14"
                  class="text-slate-400"
                />
              </header>
              <div
                v-if="openArea === key && area(key).on"
                class="flex flex-col gap-2 px-2 pb-2"
              >
                <template v-if="key === 'other'">
                  <label class="block">
                    <span class="field-label">{{ c('OTHER.NAME') }}</span>
                    <input
                      v-model="area('other').name"
                      type="text"
                      maxlength="60"
                      :placeholder="c('OTHER.NAME_PLACEHOLDER')"
                    />
                  </label>
                  <label class="block">
                    <span class="field-label">{{
                      c('OTHER.DESCRIPTION')
                    }}</span>
                    <textarea
                      v-model="area('other').description"
                      rows="2"
                      maxlength="300"
                      :placeholder="c('OTHER.DESCRIPTION_PLACEHOLDER')"
                    />
                  </label>
                </template>

                <!-- Cómo se reconoce: ejemplos sí / no -->
                <div
                  v-for="field in ['examples_yes', 'examples_no']"
                  :key="field"
                >
                  <span class="field-label">
                    {{
                      c(
                        field === 'examples_yes'
                          ? 'EXAMPLES.YES'
                          : 'EXAMPLES.NO'
                      )
                    }}
                  </span>
                  <div
                    v-for="(e, i) in area(key)[field]"
                    :key="i"
                    class="flex items-center gap-1 mb-1"
                  >
                    <input
                      v-model="e.text"
                      type="text"
                      maxlength="200"
                      class="flex-1 !mb-0 h-8 text-sm"
                      :placeholder="c('EXAMPLES.PLACEHOLDER')"
                    />
                    <button
                      type="button"
                      class="px-1 text-slate-400 hover:text-red-600"
                      :title="c('EXAMPLES.REMOVE')"
                      @click="removeExample(key, field, i)"
                    >
                      <fluent-icon icon="dismiss" size="14" />
                    </button>
                  </div>
                  <button
                    type="button"
                    class="text-xs text-woot-600 hover:underline"
                    @click="addExample(key, field)"
                  >
                    {{ c('EXAMPLES.ADD') }}
                  </button>
                </div>

                <!-- Qué hace -->
                <template v-if="key === 'support'">
                  <span class="field-label">{{ c('SUPPORT.ACTION') }}</span>
                  <label
                    v-for="value in ['case', 'handoff']"
                    :key="value"
                    class="flex items-center gap-2 text-sm"
                  >
                    <input
                      v-model="area('support').action"
                      type="radio"
                      class="!m-0"
                      :value="value"
                    />
                    {{ c(`SUPPORT.ACTIONS.${value}`) }}
                  </label>
                  <label v-if="area('support').action === 'case'" class="block">
                    <span class="field-label">{{ c('CASE_TYPE') }}</span>
                    <select v-model="area('support').case_type_id">
                      <option value="">{{ c('CASE_TYPE_FIRST') }}</option>
                      <option
                        v-for="ct in casesOf('support')"
                        :key="ct.id"
                        :value="ct.id"
                      >
                        {{ ct.name }}
                      </option>
                    </select>
                  </label>
                  <label class="flex items-center gap-2 text-sm">
                    <input
                      v-model="area('support').details"
                      type="checkbox"
                      class="!m-0"
                    />
                    {{ c('SUPPORT.DETAILS') }}
                  </label>
                  <p class="m-0 text-xs text-slate-500">
                    {{ c('SUPPORT.SEVERITY') }}
                  </p>
                </template>

                <template v-if="key === 'sales'">
                  <div v-for="field in ['quote', 'demo', 'visit']" :key="field">
                    <span class="field-label">{{
                      c(`SALES.${field}.LABEL`)
                    }}</span>
                    <select v-model="area('sales')[field]">
                      <option
                        v-for="value in field === 'quote'
                          ? ['opportunity', 'handoff']
                          : ['handoff', 'appointment']"
                        :key="value"
                        :value="value"
                      >
                        {{ c(`SALES.${field}.${value}`) }}
                      </option>
                    </select>
                  </div>
                  <label
                    v-if="area('sales').quote === 'opportunity'"
                    class="block"
                  >
                    <span class="field-label">{{ c('CASE_TYPE') }}</span>
                    <select v-model="area('sales').case_type_id">
                      <option value="">{{ c('CASE_TYPE_FIRST') }}</option>
                      <option
                        v-for="ct in casesOf('commercial')"
                        :key="ct.id"
                        :value="ct.id"
                      >
                        {{ ct.name }}
                      </option>
                    </select>
                  </label>
                  <div v-if="salesAppointments()">
                    <span class="field-label">{{
                      t('FIELDS.APPOINTMENT_USERS')
                    }}</span>
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
                  <p class="m-0 text-xs text-slate-500">
                    {{ c('SALES.EVIDENCE') }}
                  </p>
                </template>

                <template v-if="key === 'admin'">
                  <label class="flex items-center gap-2 text-sm">
                    <input
                      v-model="area('admin').case"
                      type="checkbox"
                      class="!m-0"
                    />
                    {{ c('ADMIN.CASE') }}
                  </label>
                  <label v-if="area('admin').case" class="block">
                    <span class="field-label">{{ c('CASE_TYPE') }}</span>
                    <select v-model="area('admin').case_type_id">
                      <option value="">{{ c('CASE_TYPE_FIRST') }}</option>
                      <option
                        v-for="ct in caseTypes"
                        :key="ct.id"
                        :value="ct.id"
                      >
                        {{ ct.name }}
                      </option>
                    </select>
                  </label>
                  <p class="m-0 text-xs text-slate-500">
                    {{ c('ADMIN.NO_SOURCES') }}
                  </p>
                </template>

                <!-- A quién se pasa -->
                <div class="grid grid-cols-2 gap-2">
                  <label class="block">
                    <span class="field-label">{{ c('AREA_USER') }}</span>
                    <select v-model="area(key).user_id">
                      <option value="">{{ c('GENERAL') }}</option>
                      <option v-for="u in agents" :key="u.id" :value="u.id">
                        {{ u.name }}
                      </option>
                    </select>
                  </label>
                  <label class="block">
                    <span class="field-label">{{ c('AREA_TEAM') }}</span>
                    <select v-model="area(key).team_id">
                      <option value="">{{ t('FIELDS.NO_TEAM') }}</option>
                      <option
                        v-for="team in teams"
                        :key="team.id"
                        :value="team.id"
                      >
                        {{ team.name }}
                      </option>
                    </select>
                  </label>
                </div>
              </div>
            </section>
          </template>

          <!-- 4 · Qué sabe -->
          <template v-if="step === 'knows'">
            <fieldset
              class="flex flex-col gap-1 p-2 m-0 border rounded-md border-slate-100 dark:border-slate-700"
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
                @change="toggleSource(src.key)"
              />
              <span class="text-sm">
                <span class="block font-medium">{{ src.name }}</span>
                <span class="block text-xs text-slate-500">{{
                  src.about
                }}</span>
              </span>
            </label>
            <p class="m-0 text-xs text-slate-500">{{ c('KNOWS_HINT') }}</p>
          </template>

          <!-- Imágenes y archivos -->
          <template v-if="step === 'files'">
            <AgentFiles
              v-model="form.files"
              kind="customers"
              :agent-id="agent ? agent.id : null"
              @pending="pendingFiles = $event"
            />
          </template>

          <!-- 5 · Cómo platica -->
          <template v-if="step === 'talk'">
            <label class="block">
              <span class="field-label">{{ t('TALK.WELCOME') }}</span>
              <textarea
                v-model="form.settings.welcome"
                rows="2"
                maxlength="500"
                :placeholder="c('WELCOME_PLACEHOLDER')"
              />
            </label>
            <div v-for="rule in ['human', 'not_client']" :key="rule">
              <span class="field-label">{{ c(`TALK.${rule}.LABEL`) }}</span>
              <label
                v-for="value in rule === 'human'
                  ? ['understand_first', 'now']
                  : ['serve', 'handoff']"
                :key="value"
                class="flex items-start gap-2 text-sm"
              >
                <input
                  v-model="form.settings[rule]"
                  type="radio"
                  class="!m-0 mt-1"
                  :value="value"
                />
                {{ c(`TALK.${rule}.${value}`) }}
              </label>
            </div>
            <p class="m-0 text-xs text-slate-500">{{ c('TALK.MULTI') }}</p>
            <div class="grid grid-cols-2 gap-2">
              <label class="block">
                <span class="field-label">{{ c('GENERAL_USER') }}</span>
                <select v-model="form.settings.user_id">
                  <option value="">{{ t('FIELDS.NOBODY') }}</option>
                  <option v-for="u in agents" :key="u.id" :value="u.id">
                    {{ u.name }}
                  </option>
                </select>
              </label>
              <label class="block">
                <span class="field-label">{{ c('GENERAL_TEAM') }}</span>
                <select v-model="form.settings.team_id">
                  <option value="">{{ t('FIELDS.NO_TEAM') }}</option>
                  <option v-for="team in teams" :key="team.id" :value="team.id">
                    {{ team.name }}
                  </option>
                </select>
              </label>
            </div>
          </template>

          <!-- 6 · Indicaciones -->
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

          <!-- 7 · Pruébalo: la matriz y el chat -->
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
            <div class="p-2 rounded-md bg-slate-25 dark:bg-slate-800">
              <div class="flex items-center justify-between gap-2">
                <span
                  class="text-sm font-medium text-slate-800 dark:text-slate-100"
                >
                  {{ c('MATRIX.TITLE') }}
                </span>
                <woot-button
                  size="small"
                  variant="smooth"
                  type="button"
                  :is-loading="matrixRunning"
                  @click="runMatrix"
                >
                  {{ c('MATRIX.RUN') }}
                </woot-button>
              </div>
              <p class="m-0 mt-1 text-xs text-slate-500">
                {{ c('MATRIX.HINT') }}
              </p>
              <template v-if="matrix">
                <p class="m-0 mt-2 text-xs font-medium">
                  {{
                    c('MATRIX.RESULT', { ok: matrixOk, total: matrix.length })
                  }}
                </p>
                <ul class="p-0 m-0 mt-1 text-xs list-none">
                  <li
                    v-for="(row, i) in matrix"
                    :key="i"
                    class="py-0.5"
                    :class="
                      row.ok
                        ? 'text-slate-600 dark:text-slate-300'
                        : 'text-red-600'
                    "
                  >
                    {{ matrixRow(row) }}
                  </li>
                </ul>
              </template>
            </div>
          </template>
        </form>

        <ReadyAgentChat
          :payload="payload"
          :agent-id="agent ? agent.id : null"
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
