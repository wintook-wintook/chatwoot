<script>
// Motor 2.0 — el probador con su entrenador. Al dar 👎 se pide qué estuvo mal y cómo debió
// responder; el entrenador contesta en el mismo chat con una de tres salidas (plan §11.11):
//   ✏️ agente: «Ya lo corregí, pruébalo de nuevo» · Ver cambio · Deshacer
//   📚 fuente: lo que dice hoy la fuente · «Arréglalo tú» (predefinidas) · «Lo corrijo yo»
//   🔧 motor: «búscalo con tu Kontrolya» (el reporte ya se mandó)
// El agente debe estar guardado: si hay cambios sin guardar, se pide guardar primero.
import { useAlert } from 'dashboard/composables';
import Motor2AgentsAPI from 'dashboard/api/motor2Agents';
import Tester from './Tester.vue';

const ICONS = {
  agent: '✏️',
  agent_blocked: '✏️',
  source: '📚',
  engine: '🔧',
  question: '❓',
  error: '⚠️',
};

export default {
  components: { Tester },
  props: {
    templateId: { type: Number, default: null },
    payload: { type: Function, required: true },
    dirty: { type: Boolean, default: false },
  },
  emits: ['changed', 'go'],
  data() {
    return {
      pending: null,
      feedback: '',
      lastFeedback: '',
      correcting: false,
      showDiff: null,
      fixText: {},
      saving: false,
      testName: '',
    };
  },
  methods: {
    t(key, args) {
      return this.$t(`MOTOR2.TRAINER.${key}`, args);
    },
    icon(kind) {
      return ICONS[kind] || '🎓';
    },
    chat() {
      return this.$refs.tester.chat;
    },
    onRate({ index, value }) {
      if (value === 'down') {
        this.pending = index;
        this.feedback = '';
      } else if (this.pending === index) this.pending = null;
    },
    async sendCorrection() {
      if (!this.templateId || this.dirty) {
        useAlert(this.t('SAVE_FIRST'));
        return;
      }
      const chat = this.chat();
      const bad = chat[this.pending];
      const messages = chat
        .slice(0, this.pending + 1)
        .filter(m => m.role === 'user' || m.role === 'assistant')
        .map(({ role, content }) => ({ role, content }));
      this.correcting = true;
      this.lastFeedback = this.feedback;
      try {
        const { data } = await Motor2AgentsAPI.correct(this.templateId, {
          messages,
          reply: bad.content,
          feedback: this.feedback,
          trace: bad.trace,
        });
        (data.messages || []).forEach(msg =>
          chat.push({
            role: 'trainer',
            content: `${this.icon(msg.kind)} ${msg.text}`,
            info: msg,
          })
        );
        if (data.agent) this.$emit('changed', data.agent);
        this.pending = null;
      } catch (e) {
        useAlert(e.response?.data?.error || this.t('ERROR'));
      } finally {
        this.correcting = false;
      }
    },
    // ❓ El entrenador preguntó: la respuesta se escribe junto a lo que ya se había dicho.
    answer(message) {
      const chat = this.chat();
      this.pending = chat.map(m => m.role).lastIndexOf('assistant');
      this.feedback = `${this.lastFeedback}\n${message.info.text} → `;
    },
    async undo(message) {
      try {
        const { data } = await Motor2AgentsAPI.restore(
          this.templateId,
          message.info.undo_version_id
        );
        this.$emit('changed', data);
        this.$set(message.info, 'undone', true);
        useAlert(this.t('UNDONE'));
      } catch (e) {
        useAlert(e.response?.data?.error || this.t('ERROR'));
      }
    },
    retry() {
      this.$refs.tester.retryLast();
    },
    async fixSource(message) {
      const content =
        this.fixText[message.info.canned_id] ?? message.info.should;
      try {
        await Motor2AgentsAPI.fixSource(this.templateId, {
          cannedId: message.info.canned_id,
          content,
        });
        this.$set(message.info, 'fixed', true);
        useAlert(this.t('SOURCE_FIXED'));
      } catch (e) {
        useAlert(e.response?.data?.error || this.t('ERROR'));
      }
    },
    async saveAsTest() {
      const turns = this.chat()
        .filter(m => m.role === 'user' || m.role === 'assistant')
        .map(({ role, content }) => ({ role, content }));
      if (!this.templateId || !turns.length) return;
      this.saving = true;
      try {
        await Motor2AgentsAPI.saveTest(this.templateId, {
          name: this.testName || turns[0].content.slice(0, 60),
          turns,
          expected: this.t('EXPECTED_DEFAULT'),
        });
        this.testName = '';
        useAlert(this.t('TEST_SAVED'));
      } finally {
        this.saving = false;
      }
    },
  },
};
</script>

<template>
  <Tester
    ref="tester"
    :template-id="templateId"
    :payload="payload"
    @rate="onRate"
  >
    <template #trainer="{ message }">
      <span v-if="message.info.kind === 'source'" class="block mt-1 text-xs">
        <span
          v-if="message.info.found"
          class="block p-2 mt-1 rounded bg-white/70 dark:bg-slate-800"
        >
          {{ t('SOURCE_SAYS', { name: message.info.source }) }}
          <em class="block whitespace-pre-line">{{ message.info.found }}</em>
        </span>
        <template v-if="message.info.can_fix && !message.info.fixed">
          <span class="block mt-1">{{ t('SHOULD_SAY') }}</span>
          <textarea
            class="!mb-1 text-xs"
            rows="3"
            :value="fixText[message.info.canned_id] ?? message.info.should"
            @input="$set(fixText, message.info.canned_id, $event.target.value)"
          />
          <span class="block text-[11px] text-slate-500">{{
            t('SHARED')
          }}</span>
          <span class="flex gap-2 mt-1">
            <woot-button size="tiny" @click="fixSource(message)">{{
              t('FIX_IT')
            }}</woot-button>
            <woot-button
              size="tiny"
              variant="smooth"
              @click="$emit('go', 'knows')"
              >{{ t('I_FIX') }}</woot-button
            >
          </span>
        </template>
        <span v-else-if="!message.info.can_fix" class="block mt-1">
          {{ t('EXTERNAL', { name: message.info.source }) }}
          <span v-if="message.info.should" class="block">{{
            t('SHOULD', { text: message.info.should })
          }}</span>
        </span>
        <span v-if="message.info.fixed" class="block mt-1 text-green-700">{{
          t('SOURCE_FIXED_MARK')
        }}</span>
      </span>
      <span
        v-else-if="message.info.kind === 'agent'"
        class="flex flex-wrap gap-2 mt-1 text-xs"
      >
        <woot-button size="tiny" @click="retry">{{ t('RETRY') }}</woot-button>
        <button
          type="button"
          class="underline"
          @click="showDiff = showDiff === message ? null : message"
        >
          {{ t('SEE_CHANGE') }}
        </button>
        <button
          v-if="message.info.undo_version_id && !message.info.undone"
          type="button"
          class="underline"
          @click="undo(message)"
        >
          {{ t('UNDO') }}
        </button>
        <span
          v-if="showDiff === message"
          class="block w-full p-2 rounded bg-white/70 dark:bg-slate-800"
        >
          <span class="block text-red-700 line-through whitespace-pre-line">{{
            message.info.before
          }}</span>
          <span class="block text-green-700 whitespace-pre-line">{{
            message.info.after
          }}</span>
        </span>
      </span>
      <span v-else-if="message.info.kind === 'question'" class="block mt-1">
        <woot-button size="tiny" variant="smooth" @click="answer(message)">{{
          t('ANSWER')
        }}</woot-button>
      </span>
    </template>

    <template #below>
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
            :is-loading="correcting"
            :disabled="!feedback.trim()"
            @click="sendCorrection"
          >
            {{ t('SEND') }}
          </woot-button>
        </span>
      </div>
      <div v-else-if="templateId" class="flex items-center gap-2 px-2 pt-2">
        <input
          v-model="testName"
          type="text"
          class="flex-1 !mb-0 h-8 text-xs"
          :placeholder="t('TEST_NAME_PH')"
        />
        <woot-button
          size="tiny"
          variant="smooth"
          :is-loading="saving"
          @click="saveAsTest"
        >
          {{ t('SAVE_TEST') }}
        </woot-button>
      </div>
    </template>
  </Tester>
</template>
