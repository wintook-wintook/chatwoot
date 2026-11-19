<!--
  Agentes listos — el chat de prueba de un asistente (motor 2.0 real, sin guardar ni mandar nada):
  tú eres el cliente y ves qué contesta, qué herramientas usó y qué decidió. `payload` es una
  función que regresa lo que hay en el asistente; `agentId` el agente que se está cambiando.
  Lo usa el asistente de «Atención a clientes» (CustomersAgentModal).
-->
<script>
import ReadyAgentsAPI from 'dashboard/api/readyAgents';

const T = 'READY_AGENTS';

export default {
  name: 'ReadyAgentChat',
  props: {
    payload: { type: Function, required: true },
    agentId: { type: Number, default: null },
    hint: { type: String, default: '' },
  },
  data() {
    return { chat: [], chatState: {}, draft: '', testing: false };
  },
  methods: {
    t(key, params) {
      return this.$t(`${T}.${key}`, params);
    },
    reset() {
      this.chat = [];
      this.chatState = {};
    },
    async send() {
      const text = this.draft.trim();
      if (!text || this.testing) return;
      this.chat.push({ role: 'user', content: text });
      this.draft = '';
      this.testing = true;
      try {
        const { data } = await ReadyAgentsAPI.test(
          this.payload(),
          this.chat
            .filter(m => ['user', 'assistant'].includes(m.role))
            .map(({ role, content }) => ({ role, content })),
          { id: this.agentId, state: this.chatState }
        );
        this.chatState = data.state || this.chatState;
        this.chat.push({
          role: 'assistant',
          content: data.reply || this.t('TEST.NO_MESSAGE'),
          tools: data.tools || [],
          decision: data.decision,
          area: this.areaOf(data.state),
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
    // «Atención a clientes»: qué área detectó el clasificador en ese mensaje.
    areaOf(state) {
      const area = state?.triage?.area;
      return area && area !== 'none' ? area : null;
    },
    toolLine(tool) {
      const label = this.$te(`${T}.TOOLS.${tool.name}`)
        ? this.t(`TOOLS.${tool.name}`)
        : tool.name;
      const detail = Object.values(tool.args || {})
        .filter(Boolean)
        .join(' · ');
      const line = detail ? `${label}: ${detail}` : label;
      return tool.ok === false ? `${line} ${this.t('TEST.NOT_DONE')}` : line;
    },
    decisionText(decision) {
      const key = `${T}.DECISIONS.${decision[0]}`;
      return this.$te(key) ? this.$t(key) : decision[0];
    },
  },
};
</script>

<template>
  <div
    class="flex flex-col min-h-[22rem] border rounded-lg md:min-h-0 border-slate-100 dark:border-slate-700"
  >
    <div
      class="flex items-center justify-between px-3 py-2 border-b border-slate-100 dark:border-slate-700"
    >
      <span class="text-sm font-medium text-slate-800 dark:text-slate-100">
        {{ t('TEST.TITLE') }}
      </span>
      <button
        type="button"
        class="text-xs text-woot-600 hover:underline"
        @click="reset"
      >
        {{ t('TEST.RESET') }}
      </button>
    </div>
    <div ref="chatBox" class="flex-1 min-h-0 p-3 space-y-2 overflow-y-auto">
      <p v-if="!chat.length" class="m-0 text-xs text-slate-500">
        {{ hint || t('TEST.HINT') }}
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
          <span v-if="m.area" class="block mt-1 text-[11px] text-slate-500">
            {{
              t('CUSTOMERS.TEST_AREA', {
                area: t(`CUSTOMERS.AREAS.${m.area}.TITLE`),
              })
            }}
          </span>
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
            {{ t('TEST.DECISION', { decision: decisionText(m.decision) }) }}
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
      <woot-button size="small" :is-loading="testing" :disabled="!draft.trim()">
        {{ t('TEST.SEND') }}
      </woot-button>
    </form>
  </div>
</template>
