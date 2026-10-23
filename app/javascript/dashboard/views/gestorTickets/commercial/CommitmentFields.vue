<!--
  @tickets_cases — Plan-Metricas-Comercial: casilla «Comprometida por el cliente»
  («esta semana te pago») + nota. Se usa en el alta, la edición y el panel del
  detalle. No hay segunda fecha: marcada, la fecha de cierre deja de ser un
  estimado y pasa a ser la fecha comprometida (quien lo usa cambia la etiqueta del
  campo y lo vuelve obligatorio). Props con `.sync`: committed, note.
-->
<script>
export default {
  name: 'CommitmentFields',
  props: {
    committed: { type: Boolean, default: false },
    note: { type: String, default: '' },
    // Panel del detalle: controles bajos (h-8) en una sola línea.
    compact: { type: Boolean, default: false },
  },
  emits: ['update:committed', 'update:note'],
};
</script>

<template>
  <div
    class="flex flex-wrap items-center gap-x-4 gap-y-2"
    :class="compact ? '' : 'col-span-4'"
  >
    <label
      class="flex items-center gap-2 cursor-pointer"
      :title="$t('CASE_TICKETS.COMMERCIAL.COMMITMENT.HINT')"
    >
      <input
        type="checkbox"
        class="!mb-0"
        :checked="committed"
        @change="$emit('update:committed', $event.target.checked)"
      />
      <span
        class="text-sm font-medium text-slate-700 dark:text-slate-200"
        :class="compact ? 'text-xs uppercase' : ''"
      >
        {{ $t('CASE_TICKETS.COMMERCIAL.COMMITMENT.LABEL') }}
      </span>
    </label>
    <input
      v-if="committed"
      type="text"
      maxlength="500"
      class="flex-1 min-w-[14rem] !mb-0 text-sm"
      :class="compact ? 'h-8' : 'input'"
      :value="note"
      :placeholder="$t('CASE_TICKETS.COMMERCIAL.COMMITMENT.NOTE_PLACEHOLDER')"
      :aria-label="$t('CASE_TICKETS.COMMERCIAL.COMMITMENT.NOTE')"
      @input="$emit('update:note', $event.target.value)"
    />
    <p
      v-else-if="!compact"
      class="m-0 text-xs text-slate-500 dark:text-slate-400"
    >
      {{ $t('CASE_TICKETS.COMMERCIAL.COMMITMENT.HINT') }}
    </p>
  </div>
</template>
