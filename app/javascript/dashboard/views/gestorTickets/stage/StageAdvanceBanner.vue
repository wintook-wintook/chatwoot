<!--
  @tickets_cases — Plan-Plantilla-Tareas-Etapa T3/T4
  Avance de la etapa en el detalle del caso. Listo (se terminaron las
  obligatorias, en «Sugerir»): aviso verde que propone pasar a la siguiente; si
  pasar pide documentar (cierre, resultado o fecha), el botón abre ese mismo flujo
  y nunca mueve sin documentar. Si no, una línea discreta con cuántas lleva y qué
  pasa al terminar.
-->
<script>
export default {
  name: 'StageAdvanceBanner',
  props: {
    advance: { type: Object, required: true },
  },
  emits: ['advance'],
  computed: {
    actionable() {
      const a = this.advance;
      return a.ready && !!a.next && a.mode !== 'manual';
    },
    params() {
      const a = this.advance;
      return {
        stage: a.stage.label,
        next: a.next ? a.next.label : '',
        done: a.required_done,
        total: a.required_total,
      };
    },
    exitKey() {
      return this.advance.next ? this.advance.mode : 'manual';
    },
  },
  methods: {
    t(key, params) {
      return this.$t(`CASE_TICKETS.STAGE_ADVANCE.${key}`, params);
    },
  },
};
</script>

<template>
  <div
    v-if="actionable"
    class="flex flex-wrap items-center gap-3 p-3 border rounded-lg border-green-200 bg-green-50 dark:border-green-800 dark:bg-green-900/20"
  >
    <fluent-icon
      icon="checkmark-circle"
      size="18"
      class="flex-shrink-0 text-green-600 dark:text-green-400"
    />
    <p class="flex-1 min-w-0 m-0 text-sm text-green-800 dark:text-green-100">
      <strong>{{ t('READY', params) }}</strong>
      {{ advance.needs_doc ? t('NEEDS_DOC', params) : t('SUGGEST', params) }}
    </p>
    <woot-button
      size="small"
      color-scheme="success"
      @click="$emit('advance', advance.next.id)"
    >
      {{
        advance.needs_doc ? t('DOCUMENT_BUTTON', params) : t('BUTTON', params)
      }}
    </woot-button>
  </div>
  <p
    v-else
    class="flex items-center gap-1.5 m-0 text-xs text-slate-500 dark:text-slate-400"
  >
    <fluent-icon icon="checkmark-circle" size="14" />
    {{ t('PROGRESS', params) }}
    {{ t(`PROGRESS_EXIT.${exitKey}`, params) }}
  </p>
</template>
