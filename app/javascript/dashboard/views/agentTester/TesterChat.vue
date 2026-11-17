<script>
// Probador de agentes › Probar: eliges un agente (1.0 o 2.0) y le escribes como cliente. Contesta
// el motor real en el canal de pruebas (no sale nada a WhatsApp). Bajo cada respuesta, qué hizo.
// Con 👎 el entrenador dice de quién es el error: prompt, contenido, modelo o motor.
import { useAlert } from 'dashboard/composables';
import AgentTesterAPI from 'dashboard/api/agentTester';

const POLL_MS = 2000;
const QUIET_MS = 8000;
const MAX_WAIT_MS = 60000;
const ICONS = {
  prompt: '✏️',
  content: '📚',
  model: '🧠',
  engine: '🔧',
  question: '❓',
  error: '⚠️',
};

export default {
  props: {
    agents: { type: Array, default: () => [] },
    // Aplicar correcciones y corregir fuentes: solo quien puede cambiar agentes.
    canEdit: { type: Boolean, default: false },
  },
  emits: ['saved'],
  data() {
    return {
      templateId: '',
      session: null,
      chat: [],
      draft: '',
      waiting: false,
      pending: null,
      feedback: '',
      sending: false,
      fixText: {},
      saveExpected: '',
      icons: { up: '👍', down: '👎' },
    };
  },
  computed: {
    agent() {
      return this.agents.find(a => a.id === Number(this.templateId));
    },
  },
  methods: {
    t(key, args) {
      return this.$t(`AGENT_TESTER.${key}`, args);
    },
    icon(kind) {
      return ICONS[kind] || '🎓';
    },
    async start() {
      if (!this.templateId) return;
      try {
        const { data } = await AgentTesterAPI.start(Number(this.templateId));
        this.session = data;
        this.chat = [];
      } catch (e) {
        useAlert(this.errorText(e));
      }
    },
    errorText(e) {
      const data = e && e.response ? e.response.data : null;
      return (data && data.error) || this.t('ERROR');
    },
    async send() {
      const text = this.draft.trim();
      if (!text || this.waiting || !this.session) return;
      this.draft = '';
      this.chat.push({ role: 'user', content: text });
      this.waiting = true;
      try {
        const { data } = await AgentTesterAPI.say(
          this.session.conversation_id,
          text
        );
        await this.waitReplies(data.message_id);
      } catch (e) {
        useAlert(this.errorText(e));
      } finally {
        this.waiting = false;
      }
    },
    // El motor contesta por su cuenta (como con un cliente real): se espera a que conteste y se
    // quede callado unos segundos.
    async waitReplies(after) {
      const started = Date.now();
      let lastId = after;
      let lastAt = 0;
      while (Date.now() - started < MAX_WAIT_MS) {
        // eslint-disable-next-line no-await-in-loop
        await new Promise(r => {
          setTimeout(r, POLL_MS);
        });
        // eslint-disable-next-line no-await-in-loop
        const { data } = await AgentTesterAPI.since(
          this.session.conversation_id,
          lastId
        );
        if (data.messages.length) {
          this.chat.push(
            ...data.messages.map(m => ({
              role: m.private ? 'note' : 'assistant',
              ...m,
            }))
          );
          lastId = data.messages[data.messages.length - 1].id;
          lastAt = Date.now();
        }
        this.$set(this.session, 'tracking_status', data.tracking_status);
        this.$set(this.session, 'outdated', data.outdated);
        this.scroll();
        if (lastAt && Date.now() - lastAt > QUIET_MS) return;
      }
      if (!lastAt)
        this.chat.push({ role: 'note', content: this.t('NO_REPLY') });
    },
    scroll() {
      this.$nextTick(() => {
        const box = this.$refs.chatBox;
        if (box) box.scrollTop = box.scrollHeight;
      });
    },
    rate(index, value) {
      this.$set(this.chat[index], 'rating', value);
      this.pending = value === 'down' ? index : null;
      this.feedback = '';
    },
    async sendFeedback() {
      const bad = this.chat[this.pending];
      this.sending = true;
      try {
        const { data } = await AgentTesterAPI.feedback(
          this.session.conversation_id,
          bad.id,
          this.feedback
        );
        (data.messages || []).forEach(info =>
          this.chat.push({
            role: 'trainer',
            content: `${this.icon(info.kind)} ${info.text}`,
            info,
          })
        );
        if (data.saved_in)
          this.chat.push({
            role: 'note',
            content: this.t('AUTO_SAVED', { batch: data.saved_in }),
          });
        this.pending = null;
        this.$emit('saved');
        this.scroll();
      } catch (e) {
        useAlert(this.errorText(e));
      } finally {
        this.sending = false;
      }
    },
    async apply(message) {
      try {
        const { data } = await AgentTesterAPI.apply(message.info.log_id);
        this.$set(message.info, 'applied', true);
        this.chat.push({
          role: 'trainer',
          content: `✏️ ${data.message.text}`,
          info: data.message,
        });
      } catch (e) {
        useAlert(this.errorText(e));
      }
    },
    fixValue(info) {
      const typed = this.fixText[info.canned_id];
      return typed === undefined ? info.should : typed;
    },
    async fixSource(message) {
      try {
        await AgentTesterAPI.fixSource(
          message.info.canned_id,
          this.fixValue(message.info)
        );
        this.$set(message.info, 'fixed', true);
      } catch (e) {
        useAlert(this.errorText(e));
      }
    },
    copy(text) {
      if (navigator.clipboard) navigator.clipboard.writeText(text);
      useAlert(this.t('COPIED'));
    },
    openTraining() {
      const id = String(this.session.template_id);
      const route =
        this.session.engine === '2'
          ? { name: 'motor2_agent', params: { templateId: id } }
          : {
              name: 'contact_trackings_agent',
              params: { templateId: id },
              query: { seccion: 'training' },
            };
      window.open(this.$router.resolve(route).href, '_blank');
    },
    answer(message) {
      this.pending = this.chat.map(m => m.role).lastIndexOf('assistant');
      this.feedback = `${message.info.text} → `;
    },
    // Lo que escribió el cliente en esta plática, como prueba: va sola al lote del agente y del día.
    async saveAsCase() {
      if (!this.session || !this.saveExpected.trim()) return;
      try {
        const { data } = await AgentTesterAPI.saveCase(
          this.session.conversation_id,
          this.saveExpected
        );
        this.saveExpected = '';
        useAlert(this.t('CASE_SAVED', { batch: data.saved_in }));
        this.$emit('saved');
      } catch (e) {
        useAlert(this.errorText(e));
      }
    },
  },
};
</script>

<template>
  <div class="grid gap-4 lg:grid-cols-[minmax(0,1fr)_320px] min-h-0 h-full">
    <div
      class="flex flex-col min-h-0 border rounded-lg border-slate-100 dark:border-slate-700"
    >
      <div
        class="flex flex-wrap items-center gap-2 p-3 border-b border-slate-100 dark:border-slate-700"
      >
        <select
          v-model="templateId"
          class="flex-1 !mb-0 h-9 text-sm min-w-[200px]"
        >
          <option value="">{{ t('PICK_AGENT') }}</option>
          <option v-for="a in agents" :key="a.id" :value="a.id">
            {{
              t('AGENT_OPTION', {
                name: a.name,
                engine: a.engine === '2' ? '2.0' : '1.0',
              })
            }}
          </option>
        </select>
        <woot-button size="small" :disabled="!templateId" @click="start">
          {{ session ? t('NEW_CHAT') : t('START') }}
        </woot-button>
      </div>
      <div
        ref="chatBox"
        class="flex-1 min-h-[360px] p-3 space-y-2 overflow-y-auto"
      >
        <p v-if="!agents.length" class="m-0 text-sm text-slate-500">
          {{ t('NO_AGENTS') }}
        </p>
        <p v-else-if="!session" class="m-0 text-sm text-slate-500">
          {{ t('HINT') }}
        </p>
        <p v-else-if="!chat.length" class="m-0 text-sm text-slate-500">
          {{
            t('READY', {
              name: session.name,
              engine: session.engine === '2' ? '2.0' : '1.0',
            })
          }}
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
              'bg-yellow-50 text-slate-600 text-xs italic dark:bg-yellow-900/20 dark:text-slate-300':
                m.role === 'note',
              'bg-amber-50 text-slate-800 dark:bg-amber-900/30 dark:text-slate-100':
                m.role === 'trainer',
            }"
          >
            <span>{{ m.content }}</span>
            <template v-if="m.role === 'assistant'">
              <span
                v-for="(f, j) in m.files || []"
                :key="`f${j}`"
                class="block mt-1 text-[11px] text-slate-500"
              >
                {{ t('FILE', { name: f }) }}
              </span>
              <span
                v-for="(line, j) in m.lines || []"
                :key="j"
                class="block mt-1 text-[11px] text-slate-500"
              >
                {{ line }}
              </span>
              <span class="flex justify-end gap-1 mt-1">
                <button
                  type="button"
                  class="px-1 rounded"
                  :class="m.rating === 'up' ? 'bg-green-100' : 'opacity-60'"
                  @click="rate(i, 'up')"
                >
                  {{ icons.up }}
                </button>
                <button
                  type="button"
                  class="px-1 rounded"
                  :class="m.rating === 'down' ? 'bg-red-100' : 'opacity-60'"
                  @click="rate(i, 'down')"
                >
                  {{ icons.down }}
                </button>
              </span>
            </template>
            <template v-if="m.role === 'trainer'">
              <span
                v-if="
                  !canEdit &&
                  (m.info.kind === 'prompt' || m.info.kind === 'content')
                "
                class="block mt-1 text-xs text-slate-500"
              >
                {{ t('ASK_ADMIN') }}
              </span>
              <span v-if="m.info.kind === 'prompt'" class="block mt-1 text-xs">
                <span
                  class="block p-2 mt-1 rounded bg-white/70 dark:bg-slate-800"
                  >{{ m.info.suggestion }}</span
                >
                <span class="flex flex-wrap gap-2 mt-1">
                  <woot-button
                    v-if="canEdit && m.info.engine === '2' && !m.info.applied"
                    size="tiny"
                    @click="apply(m)"
                  >
                    {{ t('APPLY') }}
                  </woot-button>
                  <woot-button
                    v-if="m.info.engine === '1'"
                    size="tiny"
                    variant="smooth"
                    @click="copy(m.info.suggestion)"
                  >
                    {{ t('COPY') }}
                  </woot-button>
                  <woot-button
                    v-if="canEdit"
                    size="tiny"
                    variant="smooth"
                    @click="openTraining"
                  >
                    {{ t('OPEN_AGENT') }}
                  </woot-button>
                </span>
              </span>
              <span
                v-else-if="m.info.kind === 'content'"
                class="block mt-1 text-xs"
              >
                <span
                  v-if="m.info.found"
                  class="block p-2 mt-1 rounded bg-white/70 dark:bg-slate-800"
                  >{{ m.info.found }}</span
                >
                <template v-if="canEdit && m.info.can_fix && !m.info.fixed">
                  <span class="block mt-1">{{ t('SHOULD_SAY') }}</span>
                  <textarea
                    class="!mb-1 text-xs"
                    rows="3"
                    :value="fixValue(m.info)"
                    @input="
                      $set(fixText, m.info.canned_id, $event.target.value)
                    "
                  />
                  <span class="block text-[11px] text-slate-500">{{
                    t('SHARED')
                  }}</span>
                  <woot-button size="tiny" @click="fixSource(m)">{{
                    t('FIX_IT')
                  }}</woot-button>
                </template>
                <span v-else-if="m.info.should" class="block mt-1">{{
                  t('SHOULD', { text: m.info.should })
                }}</span>
                <span v-if="m.info.fixed" class="block mt-1 text-green-700">{{
                  t('FIXED')
                }}</span>
              </span>
              <span v-else-if="m.info.kind === 'question'" class="block mt-1">
                <woot-button size="tiny" variant="smooth" @click="answer(m)">{{
                  t('ANSWER')
                }}</woot-button>
              </span>
            </template>
          </div>
        </div>
        <p v-if="waiting" class="m-0 text-xs text-right text-slate-400">
          {{ t('TYPING') }}
        </p>
        <p
          v-if="
            session &&
            session.tracking_status &&
            session.tracking_status !== 'active'
          "
          class="m-0 text-xs text-amber-700"
        >
          {{ t('TRACKING_STATUS', { status: session.tracking_status }) }}
        </p>
        <p
          v-if="session && session.outdated"
          class="m-0 text-xs text-amber-700"
        >
          {{ t('OUTDATED') }}
        </p>
      </div>
      <div
        v-if="pending !== null"
        class="p-2 space-y-1 border-t border-slate-100 dark:border-slate-700"
      >
        <span class="block text-xs font-medium">{{ t('WHAT_WRONG') }}</span>
        <textarea
          v-model="feedback"
          rows="3"
          class="!mb-0 text-sm"
          :placeholder="t('WHAT_WRONG_PH')"
        />
        <span class="flex justify-end gap-2">
          <woot-button size="tiny" variant="clear" @click="pending = null">{{
            t('CANCEL')
          }}</woot-button>
          <woot-button
            size="tiny"
            :is-loading="sending"
            :disabled="!feedback.trim()"
            @click="sendFeedback"
          >
            {{ t('SEND_TRAINER') }}
          </woot-button>
        </span>
      </div>
      <form
        class="flex gap-2 !p-2 border-t border-slate-100 dark:border-slate-700"
        @submit.prevent="send"
      >
        <input
          v-model="draft"
          type="text"
          class="flex-1 !mb-0 h-9 text-sm"
          :disabled="!session"
          :placeholder="t('PLACEHOLDER')"
        />
        <woot-button
          size="small"
          :is-loading="waiting"
          :disabled="!draft.trim() || !session"
        >
          {{ t('SEND') }}
        </woot-button>
      </form>
    </div>

    <aside
      class="flex flex-col gap-3 p-3 border rounded-lg h-fit border-slate-100 dark:border-slate-700"
    >
      <h3 class="m-0 text-sm font-semibold">{{ t('SAVE_CASE_TITLE') }}</h3>
      <p class="m-0 text-xs text-slate-500">{{ t('SAVE_CASE_HINT') }}</p>
      <textarea
        v-model="saveExpected"
        rows="3"
        class="!mb-0 text-sm"
        :placeholder="t('EXPECTED_PH')"
      />
      <woot-button
        size="small"
        variant="smooth"
        :disabled="!session || !chat.length || !saveExpected.trim()"
        @click="saveAsCase"
      >
        {{ t('SAVE_CASE') }}
      </woot-button>
    </aside>
  </div>
</template>
