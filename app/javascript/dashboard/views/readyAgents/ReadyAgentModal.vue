<!--
  Activar o cambiar un agente listo: a la izquierda lo que la empresa contesta (nombre, bandejas,
  objetivo, preguntas, cuándo califica o se descarta, a quién lo pasa, tono, qué hacer con quien
  ya es cliente) y a la derecha el chat de prueba: tú eres el cliente y ves qué contesta y qué
  hizo, sin guardar ni mandar nada. Emite `saved` con el agente.
-->
<script>
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import ReadyAgentsAPI from 'dashboard/api/readyAgents';

const T = 'READY_AGENTS';
const blank = kind => ({
  kind,
  name: '',
  enabled: true,
  inbox_ids: [],
  settings: {
    objective: 'handoff',
    questions: '',
    qualified_when: '',
    discard_when: '',
    tone: 'cercano',
    instructions: '',
    handoff_user_id: '',
    handoff_team_id: '',
    client_user_id: '',
    client_team_id: '',
    only_prospects: true,
  },
});

export default {
  name: 'ReadyAgentModal',
  props: {
    show: { type: Boolean, default: false },
    kind: { type: String, default: 'prospects' },
    title: { type: String, default: '' },
    agent: { type: Object, default: null },
    inboxes: { type: Array, default: () => [] },
    // Bandejas que ya tienen otro agente listo prendido (no se pueden elegir).
    takenInboxIds: { type: Array, default: () => [] },
  },
  emits: ['close', 'saved'],
  data() {
    return {
      form: blank(this.kind),
      saving: false,
      chat: [],
      draft: '',
      testing: false,
    };
  },
  computed: {
    ...mapGetters({ agents: 'agents/getAgents', teams: 'teams/getTeams' }),
    objectives() {
      return ['handoff', 'opportunity', 'collect'];
    },
    tones() {
      return ['cercano', 'formal', 'directo'];
    },
    canSave() {
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
            settings: { ...base.settings, ...(this.agent.settings || {}) },
          }
        : base;
      this.chat = [];
      this.draft = '';
      this.$store.dispatch('agents/get');
      this.$store.dispatch('teams/get');
    },
    toggleInbox(id) {
      const ids = this.form.inbox_ids;
      this.form.inbox_ids = ids.includes(id)
        ? ids.filter(i => i !== id)
        : [...ids, id];
    },
    payload() {
      return { ...this.form, name: this.form.name.trim() };
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
          this.chat.map(({ role, content }) => ({ role, content }))
        );
        this.chat.push({
          role: 'assistant',
          content: data.reply || this.t('TEST.NO_MESSAGE'),
          tools: data.tools || [],
          decision: data.decision,
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
      return detail ? `${label}: ${detail}` : label;
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
        class="grid flex-1 min-h-0 grid-cols-1 gap-5 px-8 pb-4 overflow-hidden md:grid-cols-2 md:grid-rows-1"
      >
        <!-- Lo que contesta la empresa -->
        <form
          class="ready-form flex flex-col gap-2.5 overflow-y-auto !p-0 !pr-1 !self-stretch"
          @submit.prevent="save"
        >
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
              <span class="field-label">{{ t('FIELDS.TONE') }}</span>
              <select v-model="form.settings.tone">
                <option v-for="tone in tones" :key="tone" :value="tone">
                  {{ t(`TONES.${tone}`) }}
                </option>
              </select>
            </label>
          </div>
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
          <label class="block">
            <span class="field-label">{{ t('FIELDS.OBJECTIVE') }}</span>
            <select v-model="form.settings.objective">
              <option v-for="o in objectives" :key="o" :value="o">
                {{ t(`OBJECTIVES.${o}`) }}
              </option>
            </select>
          </label>
          <label class="block">
            <span class="field-label">{{ t('FIELDS.QUESTIONS') }}</span>
            <textarea
              v-model="form.settings.questions"
              rows="2"
              :placeholder="t('FIELDS.QUESTIONS_PLACEHOLDER')"
            />
          </label>
          <div class="grid grid-cols-2 gap-3">
            <label class="block">
              <span class="field-label">{{ t('FIELDS.QUALIFIED_WHEN') }}</span>
              <textarea
                v-model="form.settings.qualified_when"
                rows="2"
                :placeholder="t('FIELDS.QUALIFIED_PLACEHOLDER')"
              />
            </label>
            <label class="block">
              <span class="field-label">{{ t('FIELDS.DISCARD_WHEN') }}</span>
              <textarea
                v-model="form.settings.discard_when"
                rows="2"
                :placeholder="t('FIELDS.DISCARD_PLACEHOLDER')"
              />
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
          <label class="block">
            <span class="field-label">{{ t('FIELDS.INSTRUCTIONS') }}</span>
            <textarea
              v-model="form.settings.instructions"
              rows="2"
              :placeholder="t('FIELDS.INSTRUCTIONS_PLACEHOLDER')"
            />
          </label>
          <label
            class="flex items-center gap-2 text-sm font-medium text-slate-800 dark:text-slate-100"
          >
            <input v-model="form.enabled" type="checkbox" class="!m-0" />
            {{ t('FIELDS.ENABLED') }}
          </label>
        </form>

        <!-- Chat de prueba: tú eres el cliente -->
        <div
          class="flex flex-col min-h-0 border rounded-lg border-slate-100 dark:border-slate-700"
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
                  v-if="m.decision"
                  class="block mt-1 text-[11px] font-medium text-woot-700"
                >
                  {{
                    t('TEST.DECISION', {
                      decision: t(`DECISIONS.${m.decision[0]}`),
                    })
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
        <woot-button :is-loading="saving" :disabled="!canSave" @click="save">
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
