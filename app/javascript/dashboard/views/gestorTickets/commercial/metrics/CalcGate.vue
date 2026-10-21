<!--
  @tickets_cases — Plan-Metricas-Comercial: el botón «Calcular» de los cálculos
  pesados (estancadas, mes a mes). Sin resultado: tarjeta con qué calcula y el
  botón. Con resultado: «Calculado hace 5 min · Actualizar» y el contenido
  (slot). Si los filtros cambiaron desde el cálculo, franja ámbar «Los filtros
  cambiaron · Recalcular»: nunca recalcula solo. La memoria (caseMetricsCalc)
  la lleva quien lo usa; este componente solo pinta y avisa.
-->
<script>
import { timeAgo } from 'dashboard/helper/caseMetricsCalc';

export default {
  name: 'CalcGate',
  props: {
    title: { type: String, required: true },
    description: { type: String, default: '' },
    calculatedAt: { type: Number, default: null },
    loading: { type: Boolean, default: false },
    filtersChanged: { type: Boolean, default: false },
  },
  emits: ['calculate'],
  data() {
    return { now: Date.now(), timer: null };
  },
  computed: {
    ago() {
      return this.calculatedAt ? timeAgo(this.calculatedAt, this.now) : '';
    },
  },
  mounted() {
    // Refresca el «hace X min» sin recalcular nada.
    this.timer = setInterval(() => {
      this.now = Date.now();
    }, 30000);
  },
  beforeDestroy() {
    clearInterval(this.timer);
  },
};
</script>

<template>
  <section
    class="p-4 bg-white border rounded-lg dark:bg-slate-800 border-slate-75 dark:border-slate-700"
  >
    <div class="flex flex-wrap items-center gap-2">
      <h2 class="m-0 text-sm font-semibold text-slate-800 dark:text-slate-100">
        {{ title }}
      </h2>
      <slot name="controls" />
      <span
        v-if="calculatedAt"
        class="ml-auto text-xs text-slate-500 dark:text-slate-400"
      >
        {{ $t('CASE_TICKETS.COMMERCIAL.METRICS.CALC.DONE', { ago }) }}
      </span>
      <woot-button
        v-if="calculatedAt"
        size="tiny"
        variant="smooth"
        color-scheme="secondary"
        icon="arrow-clockwise"
        :is-loading="loading"
        @click="$emit('calculate')"
      >
        {{ $t('CASE_TICKETS.COMMERCIAL.METRICS.CALC.REFRESH') }}
      </woot-button>
    </div>

    <div
      v-if="calculatedAt && filtersChanged"
      class="flex flex-wrap items-center gap-2 px-3 py-2 mt-3 text-sm border rounded-lg bg-amber-50 border-amber-200 text-amber-800 dark:bg-amber-900/30 dark:border-amber-800 dark:text-amber-300"
      role="status"
    >
      <fluent-icon icon="alert" size="14" />
      <span class="flex-1">
        {{ $t('CASE_TICKETS.COMMERCIAL.METRICS.CALC.FILTERS_CHANGED') }}
      </span>
      <woot-button
        size="tiny"
        color-scheme="warning"
        :is-loading="loading"
        @click="$emit('calculate')"
      >
        {{ $t('CASE_TICKETS.COMMERCIAL.METRICS.CALC.RECALCULATE') }}
      </woot-button>
    </div>

    <div
      v-if="!calculatedAt"
      class="flex flex-col items-start gap-3 py-6 sm:flex-row sm:items-center"
    >
      <p class="flex-1 m-0 text-sm text-slate-600 dark:text-slate-300">
        {{ description }}
      </p>
      <woot-button
        icon="arrow-clockwise"
        :is-loading="loading"
        @click="$emit('calculate')"
      >
        {{ $t('CASE_TICKETS.COMMERCIAL.METRICS.CALC.CALCULATE') }}
      </woot-button>
    </div>
    <div v-else class="mt-3" :class="loading ? 'opacity-60' : ''">
      <slot />
    </div>
  </section>
</template>
