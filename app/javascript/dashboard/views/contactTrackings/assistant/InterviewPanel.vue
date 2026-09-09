<script>
// proyecto@asistente_agentes_ia — F4
// ============================================================================
// La conversación con el asistente. El hilo vive acá y se manda entero en cada
// turno: el backend no guarda sesión, así que el cliente es el dueño del hilo.
// ============================================================================
import Spinner from 'shared/components/Spinner.vue';

export default {
  components: { Spinner },
  props: {
    messages: { type: Array, default: () => [] },
    isThinking: { type: Boolean, default: false },
  },
  emits: ['send'],
  data() {
    return { input: '' };
  },
  watch: {
    messages() {
      this.$nextTick(this.scrollToBottom);
    },
  },
  methods: {
    send() {
      const content = this.input.trim();
      if (!content || this.isThinking) return;
      this.input = '';
      this.$emit('send', content);
    },
    scrollToBottom() {
      const el = this.$refs.thread;
      if (el) el.scrollTop = el.scrollHeight;
    },
  },
};
</script>

<template>
  <div class="flex flex-col h-full min-h-0">
    <div
      ref="thread"
      class="flex-1 min-h-0 overflow-y-auto flex flex-col gap-3"
    >
      <div
        v-for="(message, index) in messages"
        :key="index"
        class="flex"
        :class="message.role === 'user' ? 'justify-end' : 'justify-start'"
      >
        <div
          class="max-w-[85%] text-sm px-3 py-2 rounded-lg whitespace-pre-wrap"
          :class="
            message.role === 'user'
              ? 'bg-woot-500 text-white'
              : 'bg-slate-100 dark:bg-slate-700 text-slate-800 dark:text-slate-100'
          "
        >
          {{ message.content }}
        </div>
      </div>

      <div v-if="isThinking" class="flex justify-start">
        <div class="px-3 py-2 rounded-lg bg-slate-100 dark:bg-slate-700">
          <Spinner size="" />
        </div>
      </div>
    </div>

    <div class="pt-3 shrink-0">
      <textarea
        v-model="input"
        rows="2"
        class="w-full text-sm"
        :placeholder="$t('TRACKING_ASSISTANT_VIEW.INPUT_PLACEHOLDER')"
        :disabled="isThinking"
        @keydown.enter.exact.prevent="send"
      />
      <woot-button
        class="w-full"
        :is-disabled="!input.trim() || isThinking"
        @click="send"
      >
        {{ $t('TRACKING_ASSISTANT_VIEW.SEND') }}
      </woot-button>
    </div>
  </div>
</template>
