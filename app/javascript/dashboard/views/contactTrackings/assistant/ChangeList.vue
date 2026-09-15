<script>
// proyecto@asistente_agentes_ia — fase A de PROMPT STUDIO
// ============================================================================
// Debajo del mensaje que hizo una edición: lo que el asistente dice que cambió y,
// al lado, lo que cambió de verdad. Va dentro de la burbuja por la misma razón que
// los botones: es parte de ese turno, no un bloque suelto.
// ============================================================================
import { changeRows } from './changeList';

const KIND_SIGN = { added: '+', changed: '~', removed: '−' };

export default {
  props: {
    changes: { type: Object, required: true },
  },
  computed: {
    summary() {
      return Array.isArray(this.changes.summary) ? this.changes.summary : [];
    },
    rows() {
      return changeRows(this.changes);
    },
    undeclaredCount() {
      return this.rows.filter(row => row.undeclared).length;
    },
  },
  methods: {
    sign(kind) {
      return KIND_SIGN[kind];
    },
    kindLabel(kind) {
      return this.$t(`TRACKING_ASSISTANT_VIEW.CHANGE_${kind.toUpperCase()}`);
    },
  },
};
</script>

<template>
  <div
    class="flex flex-col gap-2 pt-3 mt-3 border-t border-slate-200 dark:border-slate-600"
  >
    <p class="text-xs font-semibold">
      {{ $t('TRACKING_ASSISTANT_VIEW.CHANGES_TITLE') }}
    </p>

    <ul v-if="summary.length" class="flex flex-col gap-0.5 !m-0 list-none">
      <li v-for="(line, index) in summary" :key="index" class="text-xs">
        {{ line }}
      </li>
    </ul>

    <div v-if="rows.length" class="flex flex-wrap gap-1">
      <span
        v-for="row in rows"
        :key="`${row.kind}-${row.key}`"
        class="px-1.5 py-0.5 font-mono text-xs border rounded"
        :class="
          row.undeclared
            ? 'border-amber-400 bg-amber-50 text-amber-800 dark:bg-amber-900/30 dark:text-amber-200'
            : 'border-slate-200 bg-white text-slate-700 dark:bg-slate-800 dark:text-slate-200 dark:border-slate-600'
        "
        :title="
          row.undeclared
            ? $t('TRACKING_ASSISTANT_VIEW.CHANGE_UNDECLARED_HINT')
            : kindLabel(row.kind)
        "
      >
        {{ sign(row.kind) }} {{ row.key }}
      </span>
    </div>

    <p
      v-if="undeclaredCount"
      class="text-xs text-amber-700 dark:text-amber-300"
    >
      {{
        $t('TRACKING_ASSISTANT_VIEW.CHANGE_UNDECLARED', {
          count: undeclaredCount,
        })
      }}
    </p>
  </div>
</template>
