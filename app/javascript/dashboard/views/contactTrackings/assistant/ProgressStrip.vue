<script>
// proyecto@asistente_agentes_ia — EN QUÉ VA EL TRABAJO
// ============================================================================
// Una tira de cuatro hitos arriba del Entrenamiento. No es decoración: la
// pantalla tenía tres paneles y ninguno decía en qué estado estaba lo que
// estabas armando. Se podía llegar a guardar un agente sin haberlo probado
// nunca, y nada lo señalaba.
//
// NO GUARDA NADA. Los cuatro estados se derivan de lo que ya hay en la vista
// —la conversación, el borrador, la última comprobación, la última prueba—, así
// que no puede desincronizarse de la realidad: si el borrador cambia, la
// comprobación cambia con él y el hito lo refleja solo.
//
// "Comprobado" es el único que puede quedar en ROJO en vez de en gris: los
// demás son "hecho o todavía no", pero una comprobación con hallazgos
// bloqueantes es una parada, no una etapa pendiente.
//
// "Probado" se apaga cuando el borrador cambia después de la prueba: un
// resultado de hace tres ediciones no dice nada del texto que hay ahora, y
// dejarlo en verde sería peor que no mostrarlo.
// ============================================================================
export default {
  props: {
    messages: { type: Array, default: () => [] },
    draft: { type: String, default: '' },
    validation: { type: Object, default: null },
    dryRun: { type: Object, default: null },
    // El Agente IA del que salió el borrador, si salió de uno.
    editingTemplate: { type: Object, default: null },
  },
  computed: {
    hasDraft() {
      return this.draft.trim().length > 0;
    },
    blockingCount() {
      return this.validation?.blocking?.length || 0;
    },
    routeCount() {
      return this.validation?.routes?.length || 0;
    },
    // Qué se muestra al lado de "Comprobado": los problemas si los hay, y si no,
    // cuántos temas leyó el motor. Nunca las dos cosas — la tira es una línea.
    checkedDetail() {
      if (this.blockingCount > 0) {
        return this.$t('TRACKING_ASSISTANT_VIEW.STEP_CHECKED_BLOCKED', {
          count: this.blockingCount,
        });
      }
      if (!this.routeCount) return null;

      return this.$t('TRACKING_ASSISTANT_VIEW.STEP_CHECKED_ROUTES', {
        count: this.routeCount,
      });
    },
    steps() {
      return [
        {
          key: 'interview',
          label: this.$t('TRACKING_ASSISTANT_VIEW.STEP_INTERVIEW'),
          done: this.messages.length > 0 || Boolean(this.editingTemplate),
          detail: null,
        },
        {
          key: 'draft',
          label: this.$t('TRACKING_ASSISTANT_VIEW.STEP_DRAFT'),
          done: this.hasDraft,
          detail: null,
        },
        {
          key: 'checked',
          label: this.$t('TRACKING_ASSISTANT_VIEW.STEP_CHECKED'),
          // Comprobado y limpio. Con bloqueantes NO está hecho: está frenado.
          done: Boolean(this.validation) && this.blockingCount === 0,
          alert: this.blockingCount > 0,
          detail: this.checkedDetail,
        },
        {
          key: 'tested',
          label: this.$t('TRACKING_ASSISTANT_VIEW.STEP_TESTED'),
          done: Boolean(this.dryRun),
          detail: this.dryRun?.routes?.chosen || null,
        },
      ];
    },
  },
};
</script>

<template>
  <div class="flex items-center flex-wrap gap-x-1 gap-y-1 text-xs">
    <span
      v-for="(step, index) in steps"
      :key="step.key"
      class="flex items-center gap-1"
      :class="{
        'text-red-600 dark:text-red-400': step.alert,
        'text-slate-700 dark:text-slate-200': step.done && !step.alert,
        'text-slate-400 dark:text-slate-500': !step.done && !step.alert,
      }"
    >
      <fluent-icon
        v-if="index > 0"
        icon="chevron-right"
        size="12"
        class="shrink-0 text-slate-300 dark:text-slate-600"
      />
      <fluent-icon
        v-if="step.alert"
        icon="warning"
        size="12"
        class="shrink-0"
      />
      <fluent-icon
        v-else-if="step.done"
        icon="checkmark"
        size="12"
        class="shrink-0"
      />
      <span
        v-else
        class="w-1.5 h-1.5 rounded-full bg-slate-300 dark:bg-slate-600 shrink-0"
      />
      {{ step.label }}
      <span
        v-if="step.detail"
        class="text-slate-400 dark:text-slate-500 font-normal"
      >
        {{ step.detail }}
      </span>
    </span>
  </div>
</template>
