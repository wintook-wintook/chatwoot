<!--
  Asistente (Dali) — la plática: mensajes, tarjetas (ProposalCard, AssistantDataCard),
  preguntas para seguir y el cuadro para escribir (o dictar, con `voice`).
  La usan el panel lateral (AssistantPanel) y el portal del teléfono (views/dali/DaliApp).
  Props:
    context        lo que el usuario está viendo (página, caso, contacto…)
    autoNavigate   true: si Dali abre una pantalla, se va ahí (panel); false: deja el
                   enlace «Abrir» bajo la respuesta (portal, para no salirse de Dali)
    voice          botón de micrófono: graba, se pasa a texto y queda en el cuadro
  Eventos: navigate(path), loaded(data del GET), done(proposal).
  Métodos para el padre (ref): load, ask(text), reset, focus.
  Slot `above-input`: lo que va justo arriba del cuadro (los botones rápidos del portal).
-->
<script>
import AssistantAPI from 'dashboard/api/platformAssistant';
import MessageFormatter from 'shared/helpers/MessageFormatter';
import {
  assistantState,
  DEFAULT_ASSISTANT_NAME,
} from 'dashboard/helper/assistantState';
import ProposalCard from './ProposalCard.vue';
import AssistantDataCard from './AssistantDataCard.vue';

const T = 'ASSISTANT';
const MAX_RECORDING_SECONDS = 120;
const AUDIO_TYPES = ['audio/webm', 'audio/mp4', 'audio/ogg'];

const recordingType = () =>
  AUDIO_TYPES.find(type => window.MediaRecorder?.isTypeSupported?.(type)) || '';

export default {
  name: 'AssistantChat',
  components: { ProposalCard, AssistantDataCard },
  props: {
    context: { type: Object, default: () => ({}) },
    autoNavigate: { type: Boolean, default: true },
    voice: { type: Boolean, default: false },
  },
  data() {
    return {
      state: assistantState,
      messages: [],
      starters: [], // preguntas de ejemplo según el rol (Assistant::Capabilities)
      available: true,
      loaded: false,
      draft: '',
      sending: false,
      error: '',
      // dictado: idle | recording | transcribing
      recording: 'idle',
      seconds: 0,
    };
  },
  computed: {
    name() {
      return this.state.name || DEFAULT_ASSISTANT_NAME;
    },
    lastSuggestions() {
      const last = this.messages[this.messages.length - 1];
      return (last && last.role === 'assistant' && last.suggestions) || [];
    },
    canDictate() {
      return (
        this.voice &&
        !!navigator.mediaDevices?.getUserMedia &&
        !!recordingType()
      );
    },
    busy() {
      return this.sending || this.recording !== 'idle';
    },
  },
  mounted() {
    this.load();
  },
  beforeDestroy() {
    this.stopTimer();
    this.releaseMic();
  },
  methods: {
    t(key, params) {
      return this.$t(`${T}.${key}`, { name: this.name, ...params });
    },
    async load() {
      try {
        const { data } = await AssistantAPI.show();
        this.state.name = data.name || DEFAULT_ASSISTANT_NAME;
        this.available = data.available;
        this.messages = data.messages || [];
        this.starters = data.starters || [];
        this.loaded = true;
        this.$emit('loaded', data);
        this.scrollDown();
      } catch (_e) {
        this.loaded = false;
      }
    },
    focus() {
      this.$nextTick(() => {
        this.$refs.input?.focus();
        this.scrollDown();
      });
    },
    onInputKeydown(event) {
      if (event.key === 'Enter' && !event.shiftKey) {
        event.preventDefault();
        this.send();
      }
    },
    ask(text) {
      this.draft = text;
      this.send();
    },
    async send() {
      const content = this.draft.trim();
      if (!content || this.sending) return;
      this.sending = true;
      this.error = '';
      this.draft = '';
      this.messages.push({
        id: `tmp-${Date.now()}`,
        role: 'user',
        content,
      });
      this.scrollDown();
      try {
        const { data } = await AssistantAPI.send(content, this.context);
        // El servidor devuelve el turno guardado (pregunta + respuesta).
        this.messages.splice(-1, 1, ...data.messages);
        if (data.message.navigate && this.autoNavigate) {
          this.$emit('navigate', data.message.navigate);
        }
      } catch (_e) {
        this.error = this.t('ERROR');
        this.draft = content;
        this.messages.pop();
      } finally {
        this.sending = false;
        this.scrollDown();
        this.$nextTick(() => this.$refs.input?.focus());
      }
    },
    async reset() {
      const { data } = await AssistantAPI.reset();
      this.messages = data.messages || [];
      this.starters = data.starters || this.starters;
    },
    onProposalUpdated(message, proposal) {
      const idx = message.proposals.findIndex(p => p.id === proposal.id);
      if (idx > -1) message.proposals.splice(idx, 1, proposal);
      // La pantalla abierta (p. ej. el caso) se refresca con lo que se acaba de hacer.
      if (proposal.status === 'done') this.$emit('done', proposal);
    },
    go(path) {
      this.$emit('navigate', path);
    },
    html(content) {
      return new MessageFormatter(content || '').formattedMessage;
    },
    scrollDown() {
      this.$nextTick(() => {
        const box = this.$refs.list;
        if (box) box.scrollTop = box.scrollHeight;
      });
    },
    // --- dictado ---------------------------------------------------------------
    toggleRecording() {
      if (this.recording === 'recording') this.stopRecording();
      else if (this.recording === 'idle') this.startRecording();
    },
    async startRecording() {
      this.error = '';
      try {
        this.stream = await navigator.mediaDevices.getUserMedia({
          audio: true,
        });
      } catch (_e) {
        this.error = this.t('VOICE.NO_MIC');
        return;
      }
      const type = recordingType();
      this.chunks = [];
      this.recorder = new MediaRecorder(this.stream, { mimeType: type });
      this.recorder.ondataavailable = e => {
        if (e.data.size) this.chunks.push(e.data);
      };
      this.recorder.onstop = () =>
        this.transcribe(new Blob(this.chunks, { type }));
      this.recorder.start();
      this.recording = 'recording';
      this.seconds = 0;
      this.timer = setInterval(() => {
        this.seconds += 1;
        if (this.seconds >= MAX_RECORDING_SECONDS) this.stopRecording();
      }, 1000);
    },
    stopRecording() {
      this.stopTimer();
      if (this.recorder && this.recorder.state !== 'inactive') {
        this.recording = 'transcribing';
        this.recorder.stop();
      }
      this.releaseMic();
    },
    stopTimer() {
      if (this.timer) clearInterval(this.timer);
      this.timer = null;
    },
    releaseMic() {
      (this.stream?.getTracks() || []).forEach(track => track.stop());
      this.stream = null;
    },
    async transcribe(blob) {
      if (!blob.size) {
        this.recording = 'idle';
        return;
      }
      try {
        const { data } = await AssistantAPI.transcribe(blob);
        this.draft = [this.draft.trim(), data.text].filter(Boolean).join(' ');
        this.focus();
      } catch (e) {
        this.error = e.response?.data?.error || this.t('VOICE.ERROR');
      } finally {
        this.recording = 'idle';
      }
    },
  },
};
</script>

<template>
  <div class="flex flex-col flex-1 min-h-0">
    <div ref="list" class="flex flex-col flex-1 gap-3 p-4 overflow-y-auto">
      <p
        v-if="!available"
        class="p-3 m-0 text-sm rounded-lg bg-amber-50 text-amber-800 dark:bg-amber-900/30 dark:text-amber-200"
      >
        {{ t('UNAVAILABLE') }}
      </p>
      <div
        v-if="!messages.length"
        class="p-3 text-sm rounded-lg bg-slate-50 text-slate-600 dark:bg-slate-800 dark:text-slate-300"
      >
        {{ t('HELLO') }}
        <div v-if="starters.length" class="flex flex-wrap gap-1.5 mt-2">
          <button
            v-for="text in starters"
            :key="text"
            type="button"
            class="px-2.5 py-1 text-xs bg-white border rounded-full border-woot-200 text-woot-700 hover:bg-woot-50 dark:bg-slate-900 dark:border-woot-700 dark:text-woot-200 dark:hover:bg-woot-900/40"
            @click="ask(text)"
          >
            {{ text }}
          </button>
        </div>
      </div>
      <div
        v-for="message in messages"
        :key="message.id"
        class="flex flex-col gap-2"
        :class="message.role === 'user' ? 'items-end' : 'items-start'"
      >
        <div
          v-if="message.content"
          class="px-3 py-2 text-sm rounded-lg max-w-[90%] assistant-text"
          :class="
            message.role === 'user'
              ? 'bg-woot-500 text-white'
              : 'bg-slate-50 text-slate-800 dark:bg-slate-800 dark:text-slate-100'
          "
          v-html="html(message.content)"
        />
        <!-- Portal: la pantalla que abriría Dali queda como enlace. -->
        <button
          v-if="!autoNavigate && message.navigate"
          type="button"
          class="inline-flex items-center gap-1 text-xs text-woot-600 hover:underline dark:text-woot-300"
          @click="go(message.navigate)"
        >
          <fluent-icon icon="open" size="12" />
          {{ t('OPEN_IN_PLATFORM') }}
        </button>
        <!-- D5a — cifras de ventas que acompañan la respuesta -->
        <AssistantDataCard
          v-for="(card, i) in message.cards || []"
          :key="`card-${message.id}-${i}`"
          :card="card"
          @navigate="go"
        />
        <ProposalCard
          v-for="proposal in message.proposals || []"
          :key="proposal.id"
          :proposal="proposal"
          class="w-full"
          @updated="p => onProposalUpdated(message, p)"
          @navigate="go"
        />
      </div>
      <!-- Preguntas para seguir: solo las de la última respuesta. -->
      <div
        v-if="lastSuggestions.length && !sending"
        class="flex flex-wrap gap-1.5"
      >
        <button
          v-for="text in lastSuggestions"
          :key="text"
          type="button"
          class="px-2.5 py-1 text-xs border rounded-full border-woot-200 text-woot-700 hover:bg-woot-50 dark:border-woot-700 dark:text-woot-200 dark:hover:bg-woot-900/40"
          @click="ask(text)"
        >
          {{ text }}
        </button>
      </div>
      <p v-if="sending" class="m-0 text-xs text-slate-500">
        {{ t('THINKING') }}
      </p>
      <p v-if="error" class="m-0 text-xs text-red-600">{{ error }}</p>
    </div>

    <footer class="p-3 border-t border-slate-100 dark:border-slate-800">
      <slot name="above-input" :ask="ask" :busy="busy" />
      <div class="flex items-end gap-2">
        <textarea
          ref="input"
          v-model="draft"
          rows="2"
          class="flex-1 !mb-0 text-sm resize-none"
          :placeholder="
            recording === 'recording'
              ? t('VOICE.LISTENING', { seconds })
              : recording === 'transcribing'
              ? t('VOICE.TRANSCRIBING')
              : t('PLACEHOLDER')
          "
          :disabled="!available || recording !== 'idle'"
          @keydown="onInputKeydown"
        />
        <woot-button
          v-if="canDictate"
          v-tooltip="
            recording === 'recording' ? t('VOICE.STOP') : t('VOICE.START')
          "
          :aria-label="
            recording === 'recording' ? t('VOICE.STOP') : t('VOICE.START')
          "
          :icon="recording === 'recording' ? 'microphone-stop' : 'microphone'"
          :color-scheme="recording === 'recording' ? 'alert' : 'secondary'"
          variant="smooth"
          :is-loading="recording === 'transcribing'"
          :is-disabled="!available || sending"
          :class="{ 'animate-pulse': recording === 'recording' }"
          @click="toggleRecording"
        />
        <woot-button
          icon="send"
          :aria-label="t('SEND')"
          :is-loading="sending"
          :is-disabled="!draft.trim() || !available || recording !== 'idle'"
          @click="send"
        />
      </div>
    </footer>
  </div>
</template>

<style scoped>
.assistant-text ::v-deep p {
  margin: 0 0 0.25rem;
}
.assistant-text ::v-deep ul,
.assistant-text ::v-deep ol {
  margin: 0.25rem 0 0.25rem 1.1rem;
}
</style>
