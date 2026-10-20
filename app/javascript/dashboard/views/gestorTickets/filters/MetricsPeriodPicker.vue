<!--
  @tickets_cases — Plan-Casos E1.3
  Período de las Métricas (Soporte y Comercial usan el mismo): 7 días ·
  30 días · 90 días · 12 meses · Todo. v-model = clave de METRIC_PERIODS.
-->
<script>
import { METRIC_PERIODS } from 'dashboard/helper/caseFilters';

export default {
  name: 'MetricsPeriodPicker',
  props: {
    value: { type: String, required: true },
  },
  emits: ['input'],
  computed: {
    periods() {
      return METRIC_PERIODS;
    },
  },
};
</script>

<template>
  <div
    class="inline-flex p-0.5 rounded-lg bg-slate-100 dark:bg-slate-800"
    role="tablist"
  >
    <button
      v-for="p in periods"
      :key="p.key"
      type="button"
      role="tab"
      class="px-3 py-1 text-sm font-medium rounded-md"
      :class="
        value === p.key
          ? 'bg-white text-slate-800 shadow-sm dark:bg-slate-700 dark:text-slate-100'
          : 'text-slate-500 hover:text-slate-700 dark:text-slate-400 dark:hover:text-slate-200'
      "
      :aria-selected="value === p.key"
      @click="$emit('input', p.key)"
    >
      {{ $t(`CASE_TICKETS.FILTERS.PERIODS.${p.key}`) }}
    </button>
  </div>
</template>
