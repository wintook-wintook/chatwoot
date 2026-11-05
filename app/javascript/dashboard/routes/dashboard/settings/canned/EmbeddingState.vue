<script>
// proyecto@respuestas_predefinidas R1 — ¿ESTÁ EN LA FUENTE DE DATOS DEL AGENTE?
// ============================================================================
// Plan: docs/respuestas_predefinidas_plan.md §3–4. El estado lo calcula el backend
// (CannedResponse#embedding_state). Aquí se dice en palabras y, cuando hace falta, se
// ofrece vectorizarla: UNA a la vez (D4), porque al activar OpenAI no se manda todo.
//
//   ready    ✓ En la fuente de datos
//   pending  ⏳ Vectorizando…
//   missing  ⚠ No está en la fuente de datos        [Vectorizar]
//   no_key   ⚠ No está: falta activar OpenAI
//   failed   ✗ No se pudo vectorizar (motivo)       [Reintentar]
//   stale    ⚠ Desactualizada (motivo)              [Reintentar]
// ============================================================================
const STYLES = {
  ready: 'bg-green-50 text-green-700 dark:bg-green-900/30 dark:text-green-300',
  pending: 'bg-slate-100 text-slate-600 dark:bg-slate-700 dark:text-slate-300',
  missing:
    'bg-amber-50 text-amber-800 dark:bg-amber-900/30 dark:text-amber-800',
  no_key: 'bg-amber-50 text-amber-800 dark:bg-amber-900/30 dark:text-amber-800',
  failed: 'bg-red-50 text-red-700 dark:bg-red-900/30 dark:text-red-300',
  stale: 'bg-amber-50 text-amber-800 dark:bg-amber-900/30 dark:text-amber-800',
};
const ACTIONS = { missing: 'VECTORIZE', failed: 'RETRY', stale: 'RETRY' };
const KNOWN_ERRORS = ['invalid_key', 'quota', 'no_connection'];

export default {
  props: {
    // La predefinida tal como la regresa la API (embedding_state, embedding_error).
    item: { type: Object, required: true },
    busy: { type: Boolean, default: false },
  },
  emits: ['vectorize'],
  computed: {
    state() {
      return this.item.embedding_state || 'missing';
    },
    label() {
      return this.$t(`CANNED_MGMT.EMBEDDING.STATE_${this.state.toUpperCase()}`);
    },
    style() {
      return STYLES[this.state] || STYLES.pending;
    },
    action() {
      return ACTIONS[this.state] || null;
    },
    reason() {
      if (!['failed', 'stale'].includes(this.state)) return '';
      const codigo = this.item.embedding_error || '';
      if (KNOWN_ERRORS.includes(codigo))
        return this.$t(`CANNED_MGMT.EMBEDDING.ERROR_${codigo.toUpperCase()}`);
      return this.$t('CANNED_MGMT.EMBEDDING.ERROR_OTHER', { code: codigo });
    },
  },
};
</script>

<template>
  <div class="flex flex-col items-start gap-1">
    <span
      class="px-1.5 py-0.5 text-xs rounded whitespace-nowrap"
      :class="style"
      :title="reason"
    >
      {{ label }}
    </span>
    <span v-if="reason" class="text-xs text-slate-500 dark:text-slate-400">
      {{ reason }}
    </span>
    <woot-button
      v-if="action"
      size="tiny"
      variant="smooth"
      color-scheme="primary"
      icon="arrow-clockwise"
      :is-loading="busy"
      @click="$emit('vectorize', item)"
    >
      {{ $t(`CANNED_MGMT.EMBEDDING.${action}`) }}
    </woot-button>
  </div>
</template>
