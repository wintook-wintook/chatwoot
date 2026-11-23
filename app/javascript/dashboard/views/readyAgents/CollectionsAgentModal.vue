<!--
  Agentes listos › «Cobranza» — el asistente del agente de cobranza (Motor2::Functions::Collections). Pestañas:
  El agente · Tu empresa · Canal y plantillas · Cuándo cobra · Datos para pagar · Cómo platica · Seguimiento · Probar.
  La cartera no se captura aquí: vive en Ventas › Cobranza (Excel hoy; el sistema administrativo después).
-->
<script>
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import ReadyAgentsAPI from 'dashboard/api/readyAgents';
import WizardTabs from './WizardTabs.vue';
import AgentBusiness from './AgentBusiness.vue';
import AgentVoice from './AgentVoice.vue';
import FollowUpPlan from './FollowUpPlan.vue';
import ReadyAgentChat from './ReadyAgentChat.vue';

const STEPS = [
  'agent',
  'business',
  'channel',
  'rules',
  'pay',
  'talk',
  'follow',
  'test',
];
const STAGES = [
  'preventive',
  'due',
  'overdue_30',
  'overdue_60',
  'overdue_plus',
];
const TONES = ['cercano', 'formal'];

const blank = () => ({
  name: '',
  display_name: '',
  inbox_id: '',
  email_signature: '',
  settings: {
    tone: 'cercano',
    payment_info: '',
    user_id: '',
    team_id: '',
    outreach_on: false,
    send_hour: 10,
    weekdays_only: true,
    remind_before_days: 3,
    every_days: 7,
    max_per_day: 100,
    min_balance: 1,
    templates: {},
    instructions: '',
    follow_up: { nudges: 1, templates: [], template_days: 2 },
    voice: {},
    voice_mode: 'company',
  },
});

export default {
  name: 'CollectionsAgentModal',
  components: {
    WizardTabs,
    AgentBusiness,
    AgentVoice,
    FollowUpPlan,
    ReadyAgentChat,
  },
  props: {
    show: { type: Boolean, default: false },
    title: { type: String, default: '' },
    agent: { type: Object, default: null },
    inboxes: { type: Array, default: () => [] },
  },
  emits: ['close', 'saved'],
  data() {
    return { step: 'agent', form: blank(), saving: false };
  },
  computed: {
    ...mapGetters({ users: 'agents/getAgents', teams: 'teams/getTeams' }),
    steps() {
      return STEPS;
    },
    stages() {
      return STAGES;
    },
    tones() {
      return TONES;
    },
    stepLabels() {
      return Object.fromEntries(STEPS.map(s => [s, this.c(`STEPS.${s}`)]));
    },
    channels() {
      return this.inboxes.filter(
        i =>
          /whatsapp/i.test(i.channel_type) ||
          i.channel_type === 'Channel::Email'
      );
    },
    inbox() {
      return this.channels.find(i => i.id === Number(this.form.inbox_id));
    },
    isWhatsapp() {
      return /whatsapp/i.test(this.inbox?.channel_type || '');
    },
    waTemplates() {
      if (!this.isWhatsapp) return [];
      const list =
        this.$store.getters['inboxes/getWhatsAppTemplates'](this.inbox.id) ||
        [];
      return [...new Set(list.map(item => item.name))];
    },
    canSave() {
      return !!this.form.name.trim() && !!this.form.inbox_id;
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
    c(key, params) {
      return this.$t(`READY_AGENTS.COLLECTIONS.${key}`, params);
    },
    reset() {
      this.step = 'agent';
      const base = blank();
      if (!this.agent) {
        this.form = base;
        return;
      }
      const a = this.agent;
      this.form = {
        ...base,
        name: a.name,
        display_name: a.display_name || '',
        inbox_id: a.channel?.inbox_id || '',
        email_signature: a.channel?.email_signature || '',
        settings: {
          ...base.settings,
          ...a.settings,
          templates: { ...(a.settings?.templates || {}) },
          follow_up: {
            ...base.settings.follow_up,
            ...(a.settings?.follow_up || {}),
          },
        },
      };
    },
    go(step) {
      this.step = step;
    },
    setTemplate(stage, name) {
      this.form.settings.templates = {
        ...this.form.settings.templates,
        [stage]: name,
      };
    },
    payload() {
      return {
        kind: 'collections',
        name: this.form.name.trim() || 'Cobranza',
        display_name: this.form.display_name,
        enabled: true,
        channel: {
          inbox_id: this.form.inbox_id,
          email_signature: this.form.email_signature,
        },
        settings: this.form.settings,
      };
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
        this.$emit('saved', data.agent);
      } catch (e) {
        useAlert(e.response?.data?.error || this.c('SAVE_ERROR'));
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
        :header-title="agent ? c('EDIT_TITLE', { name: agent.name }) : title"
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
        class="grid flex-1 min-h-0 grid-cols-1 gap-5 px-4 pb-4 overflow-y-auto md:px-8 md:grid-cols-2 md:overflow-hidden"
      >
        <form
          class="ready-form flex flex-col gap-2.5 overflow-y-auto !p-0 !pr-1 !self-stretch"
          @submit.prevent="save"
        >
          <p class="m-0 text-xs text-slate-500">{{ c(`HINTS.${step}`) }}</p>

          <template v-if="step === 'agent'">
            <label class="block">
              <span class="field-label">{{ c('NAME') }}</span>
              <input v-model="form.name" type="text" maxlength="100" />
            </label>
            <label class="block">
              <span class="field-label">{{ c('DISPLAY_NAME') }}</span>
              <input
                v-model="form.display_name"
                type="text"
                maxlength="30"
                :placeholder="c('DISPLAY_NAME_PLACEHOLDER')"
              />
            </label>
            <div class="grid grid-cols-2 gap-2">
              <label class="block">
                <span class="field-label">{{ c('COLLECTOR') }}</span>
                <select v-model="form.settings.user_id">
                  <option value="">{{ c('NOBODY') }}</option>
                  <option v-for="u in users" :key="u.id" :value="u.id">
                    {{ u.name }}
                  </option>
                </select>
              </label>
              <label class="block">
                <span class="field-label">{{ c('TEAM') }}</span>
                <select v-model="form.settings.team_id">
                  <option value="">{{ c('NOBODY') }}</option>
                  <option v-for="tm in teams" :key="tm.id" :value="tm.id">
                    {{ tm.name }}
                  </option>
                </select>
              </label>
            </div>
            <p class="m-0 text-xs text-slate-500">{{ c('COLLECTOR_HINT') }}</p>
          </template>

          <template v-if="step === 'business'">
            <AgentBusiness v-model="form.settings" />
            <AgentVoice v-model="form.settings" />
          </template>

          <template v-if="step === 'channel'">
            <label class="block">
              <span class="field-label">{{ c('CHANNEL') }}</span>
              <select v-model="form.inbox_id">
                <option value="">{{ c('CHANNEL_PICK') }}</option>
                <option v-for="i in channels" :key="i.id" :value="i.id">
                  {{ i.name }}
                </option>
              </select>
            </label>
            <template v-if="isWhatsapp">
              <p class="m-0 text-xs text-slate-500">
                {{ c('TEMPLATES_HINT') }}
              </p>
              <label v-for="s in stages" :key="s" class="block">
                <span class="field-label">{{ c(`STAGES.${s}`) }}</span>
                <select
                  :value="form.settings.templates[s] || ''"
                  @change="setTemplate(s, $event.target.value)"
                >
                  <option value="">{{ c('NO_TEMPLATE') }}</option>
                  <option v-for="tpl in waTemplates" :key="tpl" :value="tpl">
                    {{ tpl }}
                  </option>
                </select>
              </label>
              <p class="m-0 text-xs text-amber-700">
                {{ c('NO_TEMPLATE_HINT') }}
              </p>
            </template>
            <label v-else-if="inbox" class="block">
              <span class="field-label">{{ c('SIGNATURE') }}</span>
              <textarea
                v-model="form.email_signature"
                rows="3"
                maxlength="1000"
              />
            </label>
          </template>

          <template v-if="step === 'rules'">
            <label class="flex items-start gap-2 text-sm">
              <input
                v-model="form.settings.outreach_on"
                type="checkbox"
                class="!m-0 mt-1"
              />
              <span>
                <span class="font-medium">{{ c('OUTREACH_ON') }}</span>
                <span class="block text-xs text-slate-500">
                  {{ c('OUTREACH_HINT') }}
                </span>
              </span>
            </label>
            <div class="flex flex-wrap items-center gap-2 text-sm">
              {{ c('SEND_AT') }}
              <select
                v-model.number="form.settings.send_hour"
                class="!mb-0 !w-24"
              >
                <option v-for="h in 14" :key="h" :value="h + 6">
                  {{ c('HOUR', { h: h + 6 }) }}
                </option>
              </select>
              <label class="flex items-center gap-1">
                <input
                  v-model="form.settings.weekdays_only"
                  type="checkbox"
                  class="!m-0"
                />
                {{ c('WEEKDAYS') }}
              </label>
            </div>
            <label class="flex flex-wrap items-center gap-2 text-sm">
              {{ c('REMIND_BEFORE') }}
              <input
                v-model.number="form.settings.remind_before_days"
                type="number"
                min="0"
                max="15"
                class="!mb-0 !w-20"
              />
              {{ c('DAYS_BEFORE') }}
            </label>
            <label class="flex flex-wrap items-center gap-2 text-sm">
              {{ c('EVERY') }}
              <input
                v-model.number="form.settings.every_days"
                type="number"
                min="1"
                max="30"
                class="!mb-0 !w-20"
              />
              {{ c('DAYS') }}
            </label>
            <label class="flex flex-wrap items-center gap-2 text-sm">
              {{ c('MAX_PER_DAY') }}
              <input
                v-model.number="form.settings.max_per_day"
                type="number"
                min="1"
                class="!mb-0 !w-24"
              />
            </label>
            <label class="flex flex-wrap items-center gap-2 text-sm">
              {{ c('MIN_BALANCE') }}
              <input
                v-model.number="form.settings.min_balance"
                type="number"
                min="0"
                step="0.01"
                class="!mb-0 !w-28"
              />
            </label>
            <p class="m-0 text-xs text-slate-500">{{ c('RULES_HINT') }}</p>
          </template>

          <template v-if="step === 'pay'">
            <label class="block">
              <span class="field-label">{{ c('PAYMENT_INFO') }}</span>
              <textarea
                v-model="form.settings.payment_info"
                rows="6"
                maxlength="1500"
                :placeholder="c('PAYMENT_PLACEHOLDER')"
              />
            </label>
            <p class="m-0 text-xs text-slate-500">{{ c('PAYMENT_HINT') }}</p>
          </template>

          <template v-if="step === 'talk'">
            <span class="field-label">{{ c('TONE') }}</span>
            <label
              v-for="tone in tones"
              :key="tone"
              class="flex items-center gap-2 text-sm"
            >
              <input
                v-model="form.settings.tone"
                type="radio"
                class="!m-0"
                :value="tone"
              />
              {{ c(`TONES.${tone}`) }}
            </label>
            <label class="block">
              <span class="field-label">{{ c('INSTRUCTIONS') }}</span>
              <textarea
                v-model="form.settings.instructions"
                rows="6"
                :placeholder="c('INSTRUCTIONS_PLACEHOLDER')"
              />
            </label>
          </template>

          <template v-if="step === 'follow'">
            <FollowUpPlan
              v-model="form.settings.follow_up"
              :templates="waTemplates"
              kind="collections"
            />
          </template>

          <template v-if="step === 'test'">
            <p class="m-0 text-sm">{{ c('TEST_HINT') }}</p>
          </template>
        </form>

        <ReadyAgentChat
          :payload="payload"
          :agent-id="agent ? agent.id : null"
          :hint="c('CHAT_HINT')"
        />
      </div>
      <div class="flex justify-end gap-2 px-8 pb-6">
        <woot-button variant="clear" type="button" @click="$emit('close')">
          {{ c('CANCEL') }}
        </woot-button>
        <woot-button :is-loading="saving" :disabled="!canSave" @click="save">
          {{ c('SAVE') }}
        </woot-button>
      </div>
    </div>
  </woot-modal>
</template>
