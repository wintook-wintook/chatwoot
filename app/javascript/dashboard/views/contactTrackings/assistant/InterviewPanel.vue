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

    <!-- El compositor va en una fila: el texto a la izquierda y Enviar a la
         derecha. Apilados —textarea arriba, botón de ancho completo abajo— se
         llevaban cuatro líneas de alto de la columna donde vive el hilo, que es
         lo único que hay que leer acá.
         items-end alinea el botón con la base del textarea; resize-none impide
         que arrastrarlo le coma alto a la conversación. -->
    <div class="flex items-end gap-2 pt-3 shrink-0">
      <textarea
        v-model="input"
        rows="2"
        class="flex-1 min-w-0 text-sm resize-none !mb-0"
        :placeholder="$t('TRACKING_ASSISTANT_VIEW.INPUT_PLACEHOLDER')"
        :disabled="isThinking"
        @keydown.enter.exact.prevent="send"
      />
      <woot-button
        class="shrink-0"
        :is-disabled="!input.trim() || isThinking"
        :is-loading="isThinking"
        @click="send"
      >
        {{ $t('TRACKING_ASSISTANT_VIEW.SEND') }}
      </woot-button>
    </div>
  </div>
</template>
