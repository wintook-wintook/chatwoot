<script>
// Motor 2.0 — el probador, siempre a la vista: tú eres el cliente y el agente contesta con lo
// que hay en la pantalla (sin guardar ni mandar nada). Bajo cada respuesta, qué hizo: qué
// fuente consultó y qué encontró, qué dato guardó, qué oferta dio, qué revisó el código.
// La memoria del cliente (datos, escalón, cita) va y viene en cada turno.
import Motor2AgentsAPI from 'dashboard/api/motor2Agents';

export default {
  props: {
    templateId: { type: Number, default: null },
    // () => payload de la ficha en la pantalla.
    payload: { type: Function, required: true },
  },
  emits: ['rate'],
  data() {
    return {
      chat: [],
      draft: '',
      testing: false,
      state: {},
      open: null,
      thumbs: { up: '👍', down: '👎' },
    };
  },
  methods: {
    t(key, args) {
      return this.$t(`MOTOR2.TEST.${key}`, args);
    },
    reset() {
      this.chat = [];
      this.state = {};
      this.open = null;
    },
    history(upTo = this.chat.length) {
      return this.chat
        .slice(0, upTo)
        .filter(m => m.role === 'user' || m.role === 'assistant')
        .map(({ role, content }) => ({ role, content }));
    },
    async send() {
      const text = this.draft.trim();
      if (!text || this.testing) return;
      this.chat.push({ role: 'user', content: text });
      this.draft = '';
      await this.ask();
    },
    // También lo usa el entrenador para «Probar de nuevo» el mismo mensaje.
    async ask(upTo = this.chat.length, extra = {}) {
      this.testing = true;
      try {
        const { data } = await Motor2AgentsAPI.test({
          id: this.templateId,
          agent: this.payload(),
          messages: this.history(upTo),
          state: this.state,
        });
        if (data.error) {
          this.chat.push({ role: 'error', content: data.error });
          return;
        }
        this.state = data.state || {};
        this.chat.push({
          role: 'assistant',
          content: data.reply || this.t('NO_MESSAGE'),
          trace: data.trace || {},
          decision: data.decision,
          files: data.files || [],
          ...extra,
        });
      } catch (e) {
        this.chat.push({
          role: 'error',
          content: e.response?.data?.error || this.t('ERROR'),
        });
      } finally {
        this.testing = false;
        this.$nextTick(() => {
          const box = this.$refs.chatBox;
          if (box) box.scrollTop = box.scrollHeight;
        });
      }
    },
    // Después de una corrección: vuelve a contestar el mismo mensaje del cliente, para comparar.
    async retryLast() {
      const last = this.chat.map(m => m.role).lastIndexOf('assistant');
      if (last < 0) return;
      await this.ask(last, { again: true });
    },
    lines(m) {
      const trace = m.trace || {};
      const out = (trace.sources || []).map(s => ({
        icon: '📚',
        text: s.found.length
          ? this.t('FOUND', { name: s.name, n: s.found.length })
          : this.t('NOT_FOUND', { name: s.name }),
        detail: s.found,
      }));
      (trace.events || []).forEach(e =>
        out.push({
          icon: '🧩',
          text: this.t(`EVENTS.${e.kind}`, { text: e.text }),
        })
      );
      (m.files || []).forEach(f =>
        out.push({ icon: '📎', text: this.t('FILE', { name: f }) })
      );
      if (m.decision)
        out.push({
          icon: '➡️',
          text: this.t(`DECISIONS.${m.decision[0]}`, { text: m.decision[1] }),
        });
      return out;
    },
    rate(index, value) {
      this.$set(this.chat[index], 'rating', value);
      this.$emit('rate', { index, value, message: this.chat[index] });
    },
  },
};
</script>

<template>
  <div
    class="flex flex-col h-full min-h-0 border rounded-lg border-slate-100 dark:border-slate-700"
  >
    <div
      class="flex items-center justify-between px-3 py-2 border-b border-slate-100 dark:border-slate-700"
    >
      <span class="text-sm font-medium">{{ t('TITLE') }}</span>
      <woot-button
        variant="clear"
        size="tiny"
        icon="arrow-clockwise"
        @click="reset"
      >
        {{ t('RESET') }}
      </woot-button>
    </div>
    <div ref="chatBox" class="flex-1 min-h-0 p-3 space-y-2 overflow-y-auto">
      <p v-if="!chat.length" class="m-0 text-xs text-slate-500">
        {{ t('HINT') }}
      </p>
      <div
        v-for="(m, i) in chat"
        :key="i"
        class="flex"
        :class="m.role === 'user' ? 'justify-start' : 'justify-end'"
      >
        <div
          class="max-w-[90%] px-3 py-2 text-sm rounded-lg whitespace-pre-line"
          :class="{
            'bg-slate-100 text-slate-800 dark:bg-slate-800 dark:text-slate-100':
              m.role === 'user',
            'bg-woot-50 text-slate-800 dark:bg-woot-900/30 dark:text-slate-100':
              m.role === 'assistant',
            'bg-red-50 text-red-700': m.role === 'error',
            'bg-amber-50 text-slate-800 dark:bg-amber-900/30 dark:text-slate-100':
              m.role === 'trainer',
          }"
        >
          <span
            v-if="m.again"
            class="block mb-1 text-[11px] font-medium text-woot-700"
          >
            {{ t('AGAIN') }}
          </span>
          <span>{{ m.content }}</span>
          <template v-if="m.role === 'assistant'">
            <button
              v-for="(line, j) in lines(m)"
              :key="j"
              type="button"
              class="block mt-1 text-left text-[11px] text-slate-500"
              @click="open = open === `${i}-${j}` ? null : `${i}-${j}`"
            >
              {{ line.icon }} {{ line.text }}
              <span
                v-if="open === `${i}-${j}` && line.detail"
                class="block mt-1 whitespace-pre-line text-slate-600 dark:text-slate-300"
                >{{ line.detail.join('\n—\n') }}</span
              >
            </button>
            <span class="flex justify-end gap-1 mt-1">
              <button
                type="button"
                class="px-1 rounded"
                :class="m.rating === 'up' ? 'bg-green-100' : 'opacity-60'"
                :title="t('UP')"
                @click="rate(i, 'up')"
              >
                {{ thumbs.up }}
              </button>
              <button
                type="button"
                class="px-1 rounded"
                :class="m.rating === 'down' ? 'bg-red-100' : 'opacity-60'"
                :title="t('DOWN')"
                @click="rate(i, 'down')"
              >
                {{ thumbs.down }}
              </button>
            </span>
          </template>
          <slot
            v-if="m.role === 'trainer'"
            name="trainer"
            :message="m"
            :index="i"
          />
        </div>
      </div>
      <p v-if="testing" class="m-0 text-xs text-right text-slate-400">
        {{ t('TYPING') }}
      </p>
    </div>
    <slot name="below" />
    <form
      class="flex gap-2 !p-2 !self-stretch border-t border-slate-100 dark:border-slate-700"
      @submit.prevent="send"
    >
      <input
        v-model="draft"
        type="text"
        class="flex-1 !mb-0 h-9 text-sm"
        :placeholder="t('PLACEHOLDER')"
      />
      <woot-button size="small" :is-loading="testing" :disabled="!draft.trim()">
        {{ t('SEND') }}
      </woot-button>
    </form>
  </div>
</template>
