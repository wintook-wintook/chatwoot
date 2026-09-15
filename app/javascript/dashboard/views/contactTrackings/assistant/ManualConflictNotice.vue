<script>
// proyecto@asistente_agentes_ia — fase B de PROMPT STUDIO
// ============================================================================
// El asistente cambió, sin que se lo pidieran, piezas que la persona había
// editado a mano. En el editor ya está la versión de la persona en esas piezas
// —con el resto del cambio del asistente aplicado—: esto solo avisa y deja
// elegir la del asistente, o ver las dos lado a lado antes de decidir.
//
// Arriba del editor y no en un modal: hay que poder leer el Entrenamiento
// mientras se decide.
// ============================================================================
export default {
  props: {
    // { assistant_draft, items: [{ key, mine, theirs }] }
    conflict: { type: Object, required: true },
  },
  emits: ['useAssistant', 'keep'],
  data() {
    return { showDetail: false };
  },
  computed: {
    items() {
      return Array.isArray(this.conflict.items) ? this.conflict.items : [];
    },
    keys() {
      return this.items.map(item => item.key).join(' · ');
    },
  },
};
</script>

<template>
  <div
    class="flex flex-col gap-2 p-3 mb-2 text-xs border rounded shrink-0 border-woot-200 bg-woot-25 text-slate-800 dark:bg-slate-700 dark:border-slate-600 dark:text-slate-100"
  >
    <p class="!m-0 font-semibold">
      {{ $t('TRACKING_ASSISTANT_VIEW.MANUAL_CONFLICT_TITLE') }}
    </p>
    <p class="!m-0">
      {{ $t('TRACKING_ASSISTANT_VIEW.MANUAL_CONFLICT_HINT', { keys }) }}
    </p>

    <div v-if="showDetail" class="flex flex-col gap-3 max-h-64 overflow-y-auto">
      <div v-for="item in items" :key="item.key" class="flex flex-col gap-1">
        <p class="!m-0 font-mono font-semibold">{{ item.key }}</p>
        <div class="grid grid-cols-1 gap-2 md:grid-cols-2">
          <div>
            <p class="!m-0 mb-1 text-slate-500 dark:text-slate-300">
              {{ $t('TRACKING_ASSISTANT_VIEW.MANUAL_MINE') }}
            </p>
            <pre
              class="!m-0 p-2 overflow-x-auto font-mono whitespace-pre-wrap rounded bg-white dark:bg-slate-800"
              >{{ item.mine || $t('TRACKING_ASSISTANT_VIEW.MANUAL_MINE_REMOVED') }}</pre
            >
          </div>
          <div>
            <p class="!m-0 mb-1 text-slate-500 dark:text-slate-300">
              {{ $t('TRACKING_ASSISTANT_VIEW.MANUAL_THEIRS') }}
            </p>
            <pre
              class="!m-0 p-2 overflow-x-auto font-mono whitespace-pre-wrap rounded bg-white dark:bg-slate-800"
              >{{ item.theirs || $t('TRACKING_ASSISTANT_VIEW.MANUAL_THEIRS_REMOVED') }}</pre
            >
          </div>
        </div>
      </div>
    </div>

    <div class="flex flex-wrap gap-2">
      <woot-button size="tiny" variant="smooth" @click="$emit('keep')">
        {{ $t('TRACKING_ASSISTANT_VIEW.MANUAL_KEEP') }}
      </woot-button>
      <woot-button
        size="tiny"
        variant="clear"
        color-scheme="secondary"
        @click="showDetail = !showDetail"
      >
        {{
          showDetail
            ? $t('TRACKING_ASSISTANT_VIEW.MANUAL_HIDE')
            : $t('TRACKING_ASSISTANT_VIEW.MANUAL_SHOW')
        }}
      </woot-button>
      <woot-button
        size="tiny"
        variant="clear"
        color-scheme="secondary"
        @click="$emit('useAssistant')"
      >
        {{ $t('TRACKING_ASSISTANT_VIEW.MANUAL_USE_ASSISTANT') }}
      </woot-button>
    </div>
  </div>
</template>
