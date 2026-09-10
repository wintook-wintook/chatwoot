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
    // Las preguntas del último turno, en forma de lista, para mostrarlas como
    // botones. Llega null cuando el asistente no preguntó nada con opciones
    // —una pregunta abierta como "qué temas atiende" no tiene lista— y entonces
    // la conversación funciona como siempre, escribiendo.
    options: { type: Array, default: null },
  },
  emits: ['send'],
  data() {
    // Lo elegido en cada pregunta, por índice: { 0: '#demo', 2: 'responde' }.
    return { input: '', picked: {} };
  },
  computed: {
    // Cuántas de las preguntas ofrecidas ya tienen respuesta elegida.
    pickedCount() {
      return Object.keys(this.picked).length;
    },
  },
  watch: {
    messages() {
      this.$nextTick(this.scrollToBottom);
    },
    // Cada turno trae sus propias preguntas: lo elegido en el anterior ya se
    // envió y dejarlo marcado haría que la respuesta siguiente arrastre cosas
    // que la persona no volvió a elegir.
    options() {
      this.picked = {};
      this.$nextTick(this.scrollToBottom);
    },
  },
  methods: {
    isOpenChoice(choice) {
      return /^otr[ao]s?$/i.test(choice.trim());
    },
    // "otra" no se puede contestar con un botón: hay que decir CUÁL. Al tocarla,
    // todo lo elegido hasta ahí se pasa al campo de texto ya numerado y se deja
    // el cursor listo para escribir.
    //
    // Se mueve TODO y no solo esa pregunta a propósito: si la respuesta queda
    // partida entre los botones y el texto, enviar por un lado pierde el otro.
    // Con todo en el campo, lo que se ve es exactamente lo que se manda.
    openOther(index) {
      const yaElegido = this.composeAnswer();
      this.input = `${yaElegido ? `${yaElegido} · ` : ''}${index + 1}) `;
      this.picked = {};

      this.$nextTick(() => {
        const box = this.$refs.composer;
        if (!box) return;

        box.focus();
        box.setSelectionRange(this.input.length, this.input.length);
      });
    },
    pick(index, choice) {
      if (this.isOpenChoice(choice)) {
        this.openOther(index);
        return;
      }
      // Volver a tocar la misma la deselecciona: es la única forma de corregirse
      // sin recargar.
      this.picked =
        this.picked[index] === choice
          ? Object.fromEntries(
              Object.entries(this.picked).filter(
                ([key]) => Number(key) !== index
              )
            )
          : { ...this.picked, [index]: choice };
    },
    // En la misma clave numerada que el asistente usó al preguntar, para que sepa
    // qué contestó a qué. Solo van las elegidas: mandar las vacías haría que las
    // dé por respondidas.
    composeAnswer() {
      return Object.entries(this.picked)
        .sort(([a], [b]) => Number(a) - Number(b))
        .map(([index, choice]) => `${Number(index) + 1}) ${choice}`)
        .join(' · ');
    },
    sendPicked() {
      if (!this.pickedCount || this.isThinking) return;

      const respuesta = this.composeAnswer();
      this.picked = {};
      this.$emit('send', respuesta);
    },
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

      <!-- Los botones van SOLO bajo el último mensaje del asistente: el hilo de
           arriba es historial, y un botón de tres turnos atrás contestaría una
           pregunta que ya se respondió. -->
      <div
        v-if="options && options.length && !isThinking"
        class="flex flex-col gap-2 pl-1"
      >
        <div
          v-for="(question, index) in options"
          :key="index"
          class="flex flex-col gap-1"
        >
          <span class="text-xs text-slate-500 dark:text-slate-400">
            {{ index + 1 }}. {{ question.question }}
          </span>
          <div class="flex flex-wrap items-center gap-1">
            <button
              v-for="choice in question.choices"
              :key="choice"
              class="px-2 py-1 text-xs border rounded cursor-pointer"
              :class="
                picked[index] === choice
                  ? 'bg-woot-500 text-white border-woot-500'
                  : 'bg-white dark:bg-slate-800 text-slate-700 dark:text-slate-200 border-slate-200 dark:border-slate-600 hover:border-woot-400'
              "
              :title="
                isOpenChoice(choice)
                  ? $t('TRACKING_ASSISTANT_VIEW.PICK_OTHER_HINT')
                  : ''
              "
              @click="pick(index, choice)"
            >
              {{ choice }}
              <!-- La flecha dice que esa opción no se resuelve acá: sigue en el
                   campo de texto. -->
              <fluent-icon
                v-if="isOpenChoice(choice)"
                icon="arrow-right"
                size="12"
                class="inline-block"
              />
            </button>
          </div>
        </div>

        <div>
          <woot-button
            size="small"
            :is-disabled="!pickedCount"
            @click="sendPicked"
          >
            {{
              $t('TRACKING_ASSISTANT_VIEW.SEND_PICKED', { count: pickedCount })
            }}
          </woot-button>
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
         items-stretch le da al botón el ALTO del textarea: alineado solo a la
         base quedaba un botón chico flotando junto a una caja de dos renglones.
         resize-none impide que arrastrar el textarea le coma alto al hilo. -->
    <div class="flex items-stretch gap-2 pt-3 shrink-0">
      <textarea
        ref="composer"
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
