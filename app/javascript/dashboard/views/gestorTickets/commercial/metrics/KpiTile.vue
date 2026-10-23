<!--
  @tickets_cases — Plan-Metricas-Comercial: tarjeta de indicador. `delta` (opcional)
  compara con el período anterior: { text, good } — good true/false pinta verde o
  rojo, null gris; la flecha va en el texto (▲ ▼ =), nunca solo el color.
-->
<script>
export default {
  name: 'KpiTile',
  props: {
    label: { type: String, required: true },
    value: { type: [String, Number], default: '—' },
    sub: { type: String, default: '' },
    delta: { type: Object, default: null },
  },
  computed: {
    deltaClass() {
      if (!this.delta || this.delta.good === null) {
        return 'text-slate-500 dark:text-slate-400';
      }
      return this.delta.good
        ? 'text-green-700 dark:text-green-400'
        : 'text-red-700 dark:text-red-400';
    },
  },
};
</script>

<template>
  <div
    class="p-4 bg-white border rounded-lg dark:bg-slate-800 border-slate-75 dark:border-slate-700"
  >
    <p class="m-0 text-xs uppercase text-slate-500 dark:text-slate-400">
      {{ label }}
    </p>
    <p
      class="m-0 mt-1 text-xl font-bold tabular-nums text-slate-800 dark:text-slate-100"
    >
      {{ value }}
    </p>
    <p
      v-if="delta"
      class="m-0 mt-1 text-xs font-semibold tabular-nums"
      :class="deltaClass"
    >
      {{ delta.text }}
    </p>
    <p v-if="sub" class="m-0 mt-1 text-xs text-slate-500 dark:text-slate-400">
      {{ sub }}
    </p>
  </div>
</template>
