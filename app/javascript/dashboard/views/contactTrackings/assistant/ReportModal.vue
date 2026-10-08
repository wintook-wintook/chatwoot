<script>
// proyecto@asistente_agentes_ia — EL INFORME DEL COMPROBADOR, EN UN MODAL
// ============================================================================
// "Lo que el motor va a leer" —las ramas que reconoce, los errores y los avisos—
// vivía en un acordeón fijo abajo del editor, y se llevaba hasta el 40% del alto
// de la columna. Acá el Entrenamiento tiene 46 líneas de mediana y llega a 645, así
// que ese espacio es del texto: el informe se abre cuando se lo quiere leer.
//
// Lo que NO se esconde es la señal: el resumen (ValidationBadge) queda en la
// cabecera del panel, revalidando en cada tecla, y es el botón que abre esto. Si la
// señal se escondiera junto con el detalle, el comprobador dejaría de existir para
// quien escribe.
//
// Ir a una rama o a una línea cierra el modal: el destino está en el editor, atrás.
// ============================================================================
import ValidationBadge from './ValidationBadge.vue';
import ValidationReport from './ValidationReport.vue';

export default {
  components: { ValidationBadge, ValidationReport },
  props: {
    show: { type: Boolean, default: false },
    validation: { type: Object, default: null },
    isChecking: { type: Boolean, default: false },
    pendingCount: { type: Number, default: 0 },
    // Fuentes guardadas que el asistente no sabe ofrecer: es del mismo informe.
    unsupported: { type: Array, default: () => [] },
  },
  emits: ['close', 'gotoRoute', 'gotoLine'],
  methods: {
    goToRoute(nombre) {
      this.$emit('gotoRoute', nombre);
      this.$emit('close');
    },
    goToLine(linea) {
      this.$emit('gotoLine', linea);
      this.$emit('close');
    },
  },
};
</script>

<template>
  <woot-modal :show="show" size="medium" :on-close="() => $emit('close')">
    <div class="flex flex-col gap-3 p-8 text-sm max-h-[85vh]">
      <div class="flex flex-wrap items-center gap-3 shrink-0">
        <h2 class="!m-0 text-lg font-medium text-slate-800 dark:text-slate-100">
          {{ $t('TRACKING_ASSISTANT_VIEW.REPORT_TITLE') }}
        </h2>
        <ValidationBadge
          :validation="validation"
          :is-checking="isChecking"
          :pending-count="pendingCount"
        />
      </div>

      <div class="flex-1 min-h-0 pr-1 overflow-y-auto">
        <ValidationReport
          :validation="validation"
          @gotoRoute="goToRoute"
          @gotoLine="goToLine"
        />
      </div>

      <p
        v-if="unsupported.length"
        class="!m-0 text-xs shrink-0 text-amber-800 dark:text-amber-800"
      >
        {{ $t('TRACKING_ASSISTANT_VIEW.UNSUPPORTED_HINT') }}
        {{ unsupported.map(s => s.name).join(' · ') }}
      </p>

      <div class="flex items-center justify-end shrink-0">
        <woot-button
          variant="clear"
          color-scheme="secondary"
          @click="$emit('close')"
        >
          {{ $t('TRACKING_TEMPLATES.FORM.TRAINING.ROUTE_MODAL_CANCEL') }}
        </woot-button>
      </div>
    </div>
  </woot-modal>
</template>
