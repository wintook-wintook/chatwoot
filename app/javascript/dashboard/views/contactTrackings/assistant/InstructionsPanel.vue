<script>
// proyecto@asistente_agentes_ia — LAS INSTRUCCIONES INICIALES QUE SE LLENAN CONVERSANDO
// ============================================================================
// Mientras no hay Entrenamiento, la conversación del Asistente (DraftingChat) va
// llenando la plantilla de instrucciones iniciales (pedido del usuario, 24/09/2026).
// Acá se ven armarse, sección por sección, y se pueden corregir a mano: lo editado
// viaja en el turno siguiente y el Asistente lo toma como está.
//
// «Crear el Entrenamiento» las manda por el mismo camino que un .md subido
// (…/briefs/from_instructions → el modal de siempre: Esto entendí / Me falta saber).
// ============================================================================
import { instructionsProgress } from './instructionsProgress';

export default {
  props: {
    value: { type: String, default: '' },
    busy: { type: Boolean, default: false },
  },
  emits: ['input', 'create', 'download'],
  computed: {
    progress() {
      return instructionsProgress(this.value);
    },
  },
};
</script>

<template>
  <div class="flex flex-col h-full min-h-0 gap-3">
    <p
      v-if="!value.trim()"
      class="!m-0 text-sm text-slate-600 dark:text-slate-300"
    >
      {{ $t('TRACKING_ASSISTANT_VIEW.INSTRUCTIONS_EMPTY') }}
    </p>

    <template v-else>
      <div class="flex flex-wrap gap-1.5 shrink-0">
        <span
          v-for="section in progress.sections"
          :key="section.title"
          class="px-2 py-0.5 text-xs rounded"
          :class="
            section.filled
              ? 'bg-green-50 text-green-700 dark:bg-green-900/20 dark:text-green-300'
              : 'bg-slate-100 text-slate-500 dark:bg-slate-700 dark:text-slate-300'
          "
        >
          {{ section.filled ? '✓' : '·' }} {{ section.title }}
        </span>
      </div>
      <textarea
        class="flex-1 min-h-0 !mb-0 font-mono text-xs resize-none"
        :value="value"
        :disabled="busy"
        @input="$emit('input', $event.target.value)"
      />
      <p class="!m-0 text-xs text-slate-500 dark:text-slate-400 shrink-0">
        {{ $t('TRACKING_ASSISTANT_VIEW.INSTRUCTIONS_HINT') }}
      </p>
      <div class="flex flex-wrap items-center justify-end gap-2 shrink-0">
        <woot-button
          size="small"
          variant="smooth"
          color-scheme="secondary"
          icon="arrow-download"
          @click="$emit('download')"
        >
          {{ $t('TRACKING_ASSISTANT_VIEW.CATALOG_DOWNLOAD') }}
        </woot-button>
        <woot-button
          size="small"
          :is-loading="busy"
          :is-disabled="busy"
          @click="$emit('create')"
        >
          {{ $t('TRACKING_ASSISTANT_VIEW.BRIEF_WRITE') }}
        </woot-button>
      </div>
    </template>
  </div>
</template>
