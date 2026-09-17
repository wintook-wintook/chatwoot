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
import AssistantAPI from 'dashboard/api/assistant';

export default {
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
      // Por campo: { running, notes, previous } — `previous` es lo que había antes
      // de corregir, que es lo que devuelve "Volver al original".
      fixing: {},
      error: '',
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
      this.fixing = {};
      this.error = '';
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
    valueOf(campo) {
      return campo === 'ai_context' ? this.aiContext : this.objective;
    },
    setValue(campo, texto) {
      if (campo === 'ai_context') this.aiContext = texto;
      else this.objective = texto;
    },
    state(campo) {
      return this.fixing[campo] || {};
    },
    // Corrige la redacción del campo. Guarda lo que había: mientras no se cierre el
    // modal se puede volver a eso con un clic.
    async proofread(campo) {
      const texto = this.valueOf(campo).trim();
      if (!texto || this.state(campo).running) return;
      this.error = '';
      this.fixing = {
        ...this.fixing,
        [campo]: { running: true, previous: texto, notes: [] },
      };
      try {
        const { data } = await AssistantAPI.proofread(
          texto,
          campo,
          this.inboxId
        );
        this.setValue(campo, data.text);
        this.fixing = {
          ...this.fixing,
          [campo]: { running: false, previous: texto, notes: data.notes || [] },
        };
      } catch (e) {
        this.fixing = { ...this.fixing, [campo]: {} };
        this.error = this.$t('TRACKING_ASSISTANT_VIEW.DEFINITION_FIX_ERROR');
      }
    },
    undoProofread(campo) {
      const anterior = this.state(campo).previous;
      if (anterior === undefined) return;
      this.setValue(campo, anterior);
      this.fixing = { ...this.fixing, [campo]: {} };
    },
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
        <!-- Corregir la redacción: se propone y se puede deshacer. Nunca toca un
             dato (ver Proofreader). -->
        <div v-if="canProofread" class="flex flex-wrap items-center gap-2 mt-1">
          <woot-button
            size="tiny"
            variant="smooth"
            color-scheme="secondary"
            icon="wand-outline"
            :is-loading="state('objective').running"
            :is-disabled="!valueOf('objective').trim()"
            @click="proofread('objective')"
          >
            {{ $t('TRACKING_ASSISTANT_VIEW.DEFINITION_FIX') }}
          </woot-button>
          <woot-button
            v-if="
              state('objective').previous !== undefined &&
              !state('objective').running
            "
            size="tiny"
            variant="clear"
            color-scheme="secondary"
            icon="arrow-rotate-counter-clockwise-outline"
            @click="undoProofread('objective')"
          >
            {{ $t('TRACKING_ASSISTANT_VIEW.DEFINITION_FIX_UNDO') }}
          </woot-button>
          <span
            v-if="state('objective').notes && state('objective').notes.length"
            class="text-xs text-slate-500 dark:text-slate-400"
          >
            {{ state('objective').notes.join(' · ') }}
          </span>
        </div>
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
        <!-- Corregir la redacción: se propone y se puede deshacer. Nunca toca un
             dato (ver Proofreader). -->
        <div v-if="canProofread" class="flex flex-wrap items-center gap-2 mt-1">
          <woot-button
            size="tiny"
            variant="smooth"
            color-scheme="secondary"
            icon="wand-outline"
            :is-loading="state('ai_context').running"
            :is-disabled="!valueOf('ai_context').trim()"
            @click="proofread('ai_context')"
          >
            {{ $t('TRACKING_ASSISTANT_VIEW.DEFINITION_FIX') }}
          </woot-button>
          <woot-button
            v-if="
              state('ai_context').previous !== undefined &&
              !state('ai_context').running
            "
            size="tiny"
            variant="clear"
            color-scheme="secondary"
            icon="arrow-rotate-counter-clockwise-outline"
            @click="undoProofread('ai_context')"
          >
            {{ $t('TRACKING_ASSISTANT_VIEW.DEFINITION_FIX_UNDO') }}
          </woot-button>
          <span
            v-if="state('ai_context').notes && state('ai_context').notes.length"
            class="text-xs text-slate-500 dark:text-slate-400"
          >
            {{ state('ai_context').notes.join(' · ') }}
          </span>
        </div>
      </div>

      <p v-if="error" class="!m-0 text-xs text-red-600 dark:text-red-400">
        {{ error }}
      </p>

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
