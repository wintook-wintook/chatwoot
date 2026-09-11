<script>
// proyecto@asistente_agentes_ia — F6 · BANCO DE PRUEBAS
// ============================================================================
// Un modal con forma de conversación: se hacen varias preguntas seguidas y las
// anteriores quedan a la vista.
//
// POR QUÉ CON HISTORIAL:
//   Probar un agente no es hacerle UNA pregunta. Es tirarle cinco y ver si cada
//   una cae donde corresponde. Con un panel de un solo resultado, cada prueba
//   borraba la anterior y no había forma de comparar "¿cuánto cuesta?" contra
//   "no puedo entrar" — que es justo la comparación que revela un ruteo malo.
//
// ⚠ LO QUE CONTESTA NO ES EL AGENTE.
//   La prueba en seco no redacta la respuesta al cliente (ver DryRunService: eso
//   exige el prompt completo, el objetivo y el historial de una conversación que
//   acá no existe, y una respuesta armada por un segundo camino se vería igual de
//   autoritaria y diría otra cosa que el agente en vivo). Lo que vuelve es la
//   DECISIÓN del motor: a qué rama cae, qué fuente consulta, qué fragmentos trae
//   con su similitud, con qué etiqueta cierra y si abre caso.
//
// EL BORRADOR CAMBIA MIENTRAS SE PRUEBA, y eso no invalida lo ya probado: las
// corridas viejas se marcan como de una versión anterior en vez de borrarse.
// Borrarlas perdería justo la comparación que se vino a hacer; dejarlas sin
// marcar haría creer que describen el texto de ahora.
// ============================================================================
import DryRunPanel from './DryRunPanel.vue';

export default {
  components: { DryRunPanel },
  props: {
    show: { type: Boolean, default: false },
    draft: { type: String, default: '' },
    // [{ question, result, version }] — la más nueva al final.
    history: { type: Array, default: () => [] },
    // Versión actual del borrador. Una corrida con otra ya no lo describe.
    draftVersion: { type: Number, default: 0 },
    isRunning: { type: Boolean, default: false },
    error: { type: String, default: '' },
  },
  emits: ['close', 'run'],
  data() {
    return { question: '' };
  },
  computed: {
    canRun() {
      return this.question.trim().length > 2 && this.draft.trim().length > 0;
    },
  },
  watch: {
    history() {
      this.$nextTick(this.scrollToBottom);
    },
    show(value) {
      if (value) this.$nextTick(this.focusInput);
    },
  },
  methods: {
    run() {
      if (!this.canRun || this.isRunning) return;

      const pregunta = this.question.trim();
      this.question = '';
      this.$emit('run', pregunta);
    },
    focusInput() {
      this.$refs.question?.focus();
      this.scrollToBottom();
    },
    scrollToBottom() {
      const el = this.$refs.thread;
      if (el) el.scrollTop = el.scrollHeight;
    },
    isStale(entry) {
      return entry.version !== this.draftVersion;
    },
  },
};
</script>

<template>
  <woot-modal :show="show" size="dry-run-wide" :on-close="() => $emit('close')">
    <div class="flex flex-col p-8 h-[80vh]">
      <h2 class="mb-1 text-lg font-medium text-slate-800 dark:text-slate-100">
        {{ $t('TRACKING_ASSISTANT_VIEW.DRY_RUN_TITLE') }}
      </h2>
      <p class="mb-4 text-xs shrink-0 text-slate-500 dark:text-slate-400">
        {{ $t('TRACKING_ASSISTANT_VIEW.DRY_RUN_HINT') }}
      </p>

      <div
        ref="thread"
        class="flex flex-col flex-1 min-h-0 gap-4 overflow-y-auto"
      >
        <p
          v-if="!history.length"
          class="text-xs text-slate-400 dark:text-slate-500"
        >
          {{ $t('TRACKING_ASSISTANT_VIEW.DRY_RUN_EMPTY') }}
        </p>

        <div
          v-for="(entry, index) in history"
          :key="index"
          class="flex flex-col gap-2"
        >
          <!-- La pregunta, como la escribiría un cliente. -->
          <div class="flex justify-end">
            <div
              class="max-w-[80%] px-3 py-2 text-sm text-white rounded-lg bg-woot-500"
            >
              {{ entry.question }}
            </div>
          </div>

          <!-- Y lo que el motor haría con ella. No es el agente hablando. -->
          <div
            class="p-3 border rounded-lg bg-slate-25 dark:bg-slate-900/40 border-slate-100 dark:border-slate-700"
            :class="{ 'opacity-60': isStale(entry) }"
          >
            <p
              v-if="isStale(entry)"
              class="mb-2 text-xs text-amber-700 dark:text-amber-400"
            >
              {{ $t('TRACKING_ASSISTANT_VIEW.DRY_RUN_STALE') }}
            </p>
            <DryRunPanel :result="entry.result" />
          </div>
        </div>

        <div
          v-if="isRunning"
          class="text-xs text-slate-400 dark:text-slate-500"
        >
          {{ $t('TRACKING_ASSISTANT_VIEW.DRY_RUN_RUNNING') }}
        </div>
      </div>

      <p v-if="error" class="mt-2 text-xs text-red-600 dark:text-red-400">
        {{ error }}
      </p>

      <div class="flex items-stretch gap-2 pt-4 shrink-0">
        <input
          ref="question"
          v-model="question"
          type="text"
          class="flex-1 min-w-0 !mb-0"
          :placeholder="$t('TRACKING_ASSISTANT_VIEW.DRY_RUN_PLACEHOLDER')"
          @keyup.enter="run"
        />
        <woot-button
          class="shrink-0"
          :is-disabled="!canRun"
          :is-loading="isRunning"
          @click="run"
        >
          {{ $t('TRACKING_ASSISTANT_VIEW.DRY_RUN_BUTTON') }}
        </woot-button>
      </div>
    </div>
  </woot-modal>
</template>

<style lang="scss">
// `size` en woot-modal es solo un nombre de clase: el ancho lo define el CSS —
// el mismo camino que usa el modal de plantillas de WhatsApp.
//
// El ancho por defecto (37.5rem) alcanza para un formulario, no para esto: acá
// conviven la pregunta, la rama elegida con su descripción, los fragmentos con
// su similitud y el informe del caso. Angosto, cada informe se vuelve una
// columna de ocho renglones y se pierde justo lo que se vino a comparar.
//
// El alto va en vh y no en rem porque el largo lo pone el historial, que crece
// con cada pregunta; los topes lo dejan usable en una laptop y en un monitor.
.modal-container.dry-run-wide {
  @apply w-[58rem] max-w-[94vw];
}
</style>
