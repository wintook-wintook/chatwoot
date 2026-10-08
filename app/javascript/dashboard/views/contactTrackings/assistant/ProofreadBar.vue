<script>
// proyecto@asistente_agentes_ia — "MEJORAR LA REDACCIÓN" DE UN CAMPO
// ============================================================================
// El botón que corrige la redacción de un campo de texto con la IA, y el que
// vuelve al original. Lo usan todos los campos de la Estructura del Agente:
// Objetivo, Contexto, las frases del cliente y el alcance de una rama, y las
// instrucciones de una sección. `kind` le dice al backend qué campo es, porque cada
// uno se corrige distinto (ver Proofreader): las frases del cliente, por ejemplo,
// NO se formalizan.
//
// La corrección se propone, no se impone: queda lo que había antes y un clic lo
// devuelve. Y si el backend la descartó por tocar una directiva, una etiqueta o un
// número, se dice cuál — el texto se queda como estaba.
//
// El estado vive acá y se pierde al cerrar el modal (woot-modal desmonta su
// contenido): volver al original es para el rato en que se está editando.
// ============================================================================
import AssistantAPI from 'dashboard/api/assistant';

export default {
  props: {
    text: { type: String, default: '' },
    // objective | ai_context | route_phrases | route_scope | section_body
    kind: { type: String, required: true },
    inboxId: { type: Number, default: null },
  },
  emits: ['input'],
  data() {
    return {
      running: false,
      previous: null,
      notes: [],
      error: '',
    };
  },
  computed: {
    canRun() {
      return Boolean(this.text.trim()) && !this.running;
    },
  },
  methods: {
    async run() {
      if (!this.canRun) return;
      const original = this.text;
      this.running = true;
      this.error = '';
      try {
        const { data } = await AssistantAPI.proofread(
          original.trim(),
          this.kind,
          this.inboxId
        );
        this.previous = original;
        this.notes = data.notes || [];
        this.$emit('input', data.text);
      } catch (e) {
        const cuerpo = e.response?.data || {};
        this.error =
          cuerpo.error === 'changed_protected'
            ? this.$t('TRACKING_ASSISTANT_VIEW.FIX_PROTECTED', {
                items: (cuerpo.lost || []).join(' · '),
              })
            : this.$t('TRACKING_ASSISTANT_VIEW.DEFINITION_FIX_ERROR');
      } finally {
        this.running = false;
      }
    },
    undo() {
      if (this.previous === null) return;
      this.$emit('input', this.previous);
      this.previous = null;
      this.notes = [];
    },
  },
};
</script>

<template>
  <div class="flex flex-wrap items-center gap-2 mt-1">
    <woot-button
      type="button"
      size="tiny"
      variant="smooth"
      color-scheme="secondary"
      icon="wand-outline"
      :is-loading="running"
      :is-disabled="!canRun"
      @click="run"
    >
      {{ $t('TRACKING_ASSISTANT_VIEW.DEFINITION_FIX') }}
    </woot-button>
    <woot-button
      v-if="previous !== null && !running"
      type="button"
      size="tiny"
      variant="clear"
      color-scheme="secondary"
      icon="arrow-rotate-counter-clockwise-outline"
      @click="undo"
    >
      {{ $t('TRACKING_ASSISTANT_VIEW.DEFINITION_FIX_UNDO') }}
    </woot-button>
    <span
      v-if="notes.length"
      class="text-xs text-slate-500 dark:text-slate-400"
    >
      {{ notes.join(' · ') }}
    </span>
    <span v-if="error" class="text-xs text-red-600 dark:text-red-400">
      {{ error }}
    </span>
  </div>
</template>
