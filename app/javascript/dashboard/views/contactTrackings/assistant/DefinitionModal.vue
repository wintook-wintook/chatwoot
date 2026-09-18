<script>
// proyecto@asistente_agentes_ia — DEFINICIÓN DEL AGENTE
// ============================================================================
// Plan: docs/estructura_agente_arbol_plan.md. El Objetivo y el Contexto del agente.
//
// ⚠ Estos dos NO son parte del Entrenamiento: son columnas del Agente IA
// (`objective` y `ai_context`), y mientras se arma viven en `proposal` de la
// conversación. Por eso no pasan por el comprobador ni cambian el texto: viajan al
// agente cuando se da "Guardar en un Agente IA". El modal lo dice, porque la
// pantalla entera está hecha de cosas que sí van al texto.
//
// El Contexto entra al prompt como "BASE DE CONOCIMIENTO" y el agente lo cita como
// si fuera cierto. Medido sobre 29 agentes: mediana 148 caracteres y hasta 788, seis
// pasan de 500 — de ahí la caja amplia (hoy se escribe en una de tres renglones
// dentro del modal de guardar).
// ============================================================================
import ProofreadBar from './ProofreadBar.vue';

export default {
  components: { ProofreadBar },
  props: {
    show: { type: Boolean, default: false },
    // { name, objective, ai_context } o null.
    definition: { type: Object, default: null },
    // En qué campo poner el foco: 'objective' | 'ai_context'.
    focusField: { type: String, default: 'objective' },
    // Corregir usa el endpoint del Asistente, que es solo de administradores.
    canProofread: { type: Boolean, default: false },
    // El canal elegido: decide con qué modelo se corrige.
    inboxId: { type: Number, default: null },
  },
  emits: ['close', 'save'],
  data() {
    return {
      objective: '',
      aiContext: '',
    };
  },
  computed: {
    agentName() {
      return (this.definition || {}).name || '';
    },
  },
  watch: {
    show(abierto) {
      if (!abierto) return;
      const actual = this.definition || {};
      this.objective = actual.objective || '';
      this.aiContext = actual.ai_context || '';
      this.$nextTick(() => {
        const campo =
          this.focusField === 'ai_context'
            ? this.$refs.contexto
            : this.$refs.objetivo;
        if (campo) campo.focus();
      });
    },
  },
  methods: {
    save() {
      this.$emit('save', {
        objective: this.objective.trim(),
        ai_context: this.aiContext.trim(),
      });
    },
  },
};
</script>

<template>
  <woot-modal :show="show" size="medium" :on-close="() => $emit('close')">
    <div class="flex flex-col gap-4 p-8 text-sm max-h-[85vh] overflow-y-auto">
      <div>
        <h2 class="!m-0 text-lg font-medium text-slate-800 dark:text-slate-100">
          {{ $t('TRACKING_ASSISTANT_VIEW.DEFINITION_TITLE') }}
        </h2>
        <p class="!mt-1 !mb-0 text-xs text-slate-500 dark:text-slate-400">
          {{ $t('TRACKING_ASSISTANT_VIEW.DEFINITION_HINT') }}
        </p>
      </div>

      <p
        v-if="agentName"
        class="!m-0 text-xs text-slate-500 dark:text-slate-400"
      >
        {{ $t('TRACKING_ASSISTANT_VIEW.DEFINITION_NAME', { name: agentName }) }}
      </p>

      <div>
        <label
          for="definition-objective"
          class="!mb-1 text-xs text-slate-500 dark:text-slate-400"
        >
          {{ $t('TRACKING_ASSISTANT_VIEW.TREE_OBJECTIVE') }}
        </label>
        <input
          id="definition-objective"
          ref="objetivo"
          v-model="objective"
          type="text"
          class="w-full !mb-1"
          :placeholder="$t('TRACKING_ASSISTANT_VIEW.DEFINITION_OBJECTIVE_HINT')"
        />
        <ProofreadBar
          v-if="canProofread"
          :text="objective"
          kind="objective"
          :inbox-id="inboxId"
          @input="objective = $event"
        />
      </div>

      <div>
        <label
          for="definition-context"
          class="!mb-1 text-xs text-slate-500 dark:text-slate-400"
        >
          {{ $t('TRACKING_ASSISTANT_VIEW.TREE_CONTEXT') }}
        </label>
        <textarea
          id="definition-context"
          ref="contexto"
          v-model="aiContext"
          rows="16"
          class="w-full !mb-1 min-h-[16rem] text-sm bg-white dark:bg-slate-900 text-slate-900 dark:text-slate-100 border border-slate-200 dark:border-slate-600 rounded-md px-3 py-2"
          :placeholder="$t('TRACKING_ASSISTANT_VIEW.DEFINITION_CONTEXT_HINT')"
        />
        <p class="!m-0 text-xs text-amber-600 dark:text-amber-400">
          {{ $t('TRACKING_ASSISTANT_VIEW.DEFINITION_CONTEXT_WARNING') }}
        </p>
        <ProofreadBar
          v-if="canProofread"
          :text="aiContext"
          kind="ai_context"
          :inbox-id="inboxId"
          @input="aiContext = $event"
        />
      </div>

      <div class="flex items-center justify-end gap-2">
        <woot-button
          variant="clear"
          color-scheme="secondary"
          @click="$emit('close')"
        >
          {{ $t('TRACKING_TEMPLATES.FORM.TRAINING.ROUTE_MODAL_CANCEL') }}
        </woot-button>
        <woot-button @click="save">
          {{ $t('TRACKING_ASSISTANT_VIEW.DEFINITION_SAVE') }}
        </woot-button>
      </div>
    </div>
  </woot-modal>
</template>
