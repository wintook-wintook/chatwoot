<!--
  @tickets_cases — Plan-Metricas-Comercial: período de calendario (Este mes ·
  Mes pasado · Este trimestre · Trimestre pasado · Este año · Año pasado ·
  Personalizado), en las Métricas de todas las clases (estado: caseMetricsPeriodMixin).
  v-model = clave de CALENDAR_PERIODS; con «Personalizado»
  aparecen dos fechas (`from`/`to`, 'YYYY-MM-DD') y emite `custom` solo cuando
  el rango es válido (desde ≤ hasta).
-->
<script>
import {
  CALENDAR_PERIODS,
  dayString,
} from 'dashboard/helper/caseMetricsPeriod';

export default {
  name: 'CalendarPeriodPicker',
  props: {
    value: { type: String, required: true },
    from: { type: String, default: '' },
    to: { type: String, default: '' },
  },
  emits: ['input', 'custom'],
  data() {
    return { draftFrom: this.from, draftTo: this.to };
  },
  computed: {
    periods() {
      return CALENDAR_PERIODS;
    },
    today() {
      return dayString(new Date());
    },
    invalid() {
      return (
        !!this.draftFrom && !!this.draftTo && this.draftFrom > this.draftTo
      );
    },
  },
  watch: {
    from(v) {
      this.draftFrom = v;
    },
    to(v) {
      this.draftTo = v;
    },
  },
  methods: {
    onDate() {
      if (this.draftFrom && this.draftTo && !this.invalid) {
        this.$emit('custom', { from: this.draftFrom, to: this.draftTo });
      }
    },
  },
};
</script>

<template>
  <div class="flex flex-wrap items-center gap-2">
    <select
      :value="value"
      class="!mb-0 text-sm w-44"
      :aria-label="$t('CASE_TICKETS.FILTERS.CAL_PERIODS.LABEL')"
      @change="$emit('input', $event.target.value)"
    >
      <option v-for="p in periods" :key="p" :value="p">
        {{ $t(`CASE_TICKETS.FILTERS.CAL_PERIODS.${p}`) }}
      </option>
    </select>
    <template v-if="value === 'custom'">
      <input
        v-model="draftFrom"
        type="date"
        class="!mb-0 !w-auto text-sm"
        :max="draftTo || today"
        :aria-label="$t('CASE_TICKETS.FILTERS.CAL_PERIODS.FROM')"
        @change="onDate"
      />
      <span class="text-sm text-slate-500 dark:text-slate-400">–</span>
      <input
        v-model="draftTo"
        type="date"
        class="!mb-0 !w-auto text-sm"
        :min="draftFrom"
        :aria-label="$t('CASE_TICKETS.FILTERS.CAL_PERIODS.TO')"
        @change="onDate"
      />
      <span v-if="invalid" class="text-xs text-red-700 dark:text-red-400">
        {{ $t('CASE_TICKETS.FILTERS.CAL_PERIODS.INVALID') }}
      </span>
    </template>
  </div>
</template>
