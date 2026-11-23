<!--
  Tareas que se repiten — «Cada cuánto» y «Hasta cuándo». v-model = el objeto de
  defaultRecurrence() (recurrence.js).
-->
<script>
import { UNITS, WEEKDAYS, describeRecurrence } from './recurrence';

export default {
  name: 'RecurrenceFields',
  model: { prop: 'value', event: 'input' },
  props: {
    value: { type: Object, required: true },
    atTime: { type: String, default: '' },
  },
  data() {
    return { units: UNITS, weekdays: WEEKDAYS };
  },
  computed: {
    summary() {
      return describeRecurrence({ ...this.value, at_time: this.atTime }, this);
    },
  },
  methods: {
    set(field, val) {
      this.$emit('input', { ...this.value, [field]: val });
    },
    toggleDay(day) {
      const days = this.value.weekdays.includes(day)
        ? this.value.weekdays.filter(d => d !== day)
        : [...this.value.weekdays, day];
      this.set('weekdays', days);
    },
  },
};
</script>

<template>
  <div
    class="flex flex-col gap-2 p-3 border rounded-lg border-slate-200 dark:border-slate-600 bg-slate-50 dark:bg-slate-800/50"
  >
    <!-- Fecha fija o después de hacerla -->
    <div class="grid grid-cols-2 gap-2">
      <label
        v-for="mode in ['fixed', 'after_done']"
        :key="mode"
        class="flex items-start gap-2 p-2 bg-white border rounded-md cursor-pointer dark:bg-slate-900"
        :class="
          value.mode === mode
            ? 'border-woot-500'
            : 'border-slate-200 dark:border-slate-600'
        "
      >
        <input
          type="radio"
          class="mt-0.5"
          :checked="value.mode === mode"
          @change="set('mode', mode)"
        />
        <span class="text-xs">
          <span class="block font-medium text-slate-800 dark:text-slate-100">
            {{ $t(`RECURRING_TASKS.MODE_${mode.toUpperCase()}`) }}
          </span>
          <span class="text-slate-500 dark:text-slate-400">
            {{ $t(`RECURRING_TASKS.MODE_${mode.toUpperCase()}_HINT`) }}
          </span>
        </span>
      </label>
    </div>

    <!-- Cada N días / semanas / meses -->
    <div class="flex items-center gap-2 text-sm">
      <span class="text-slate-600 dark:text-slate-300">
        {{ $t('RECURRING_TASKS.EVERY') }}
      </span>
      <input
        :value="value.every"
        type="number"
        min="1"
        max="365"
        class="!w-16 !mb-0 h-8 text-sm"
        @input="set('every', Number($event.target.value) || 1)"
      />
      <select
        :value="value.unit"
        class="!w-auto !mb-0 h-8 text-sm"
        @change="set('unit', $event.target.value)"
      >
        <option v-for="unit in units" :key="unit" :value="unit">
          {{ $tc(`RECURRING_TASKS.UNIT_${unit.toUpperCase()}`, value.every) }}
        </option>
      </select>
      <span
        v-if="value.mode === 'after_done'"
        class="text-slate-600 dark:text-slate-300"
      >
        {{ $t('RECURRING_TASKS.AFTER_DOING_IT') }}
      </span>
    </div>

    <!-- Los días (solo fecha fija semanal) -->
    <div
      v-if="value.mode === 'fixed' && value.unit === 'week'"
      class="flex flex-wrap gap-1"
    >
      <button
        v-for="day in weekdays"
        :key="day"
        type="button"
        class="w-9 h-8 text-xs border rounded-md"
        :class="
          value.weekdays.includes(day)
            ? 'bg-woot-500 border-woot-500 text-white'
            : 'bg-white dark:bg-slate-900 border-slate-200 dark:border-slate-600 text-slate-700 dark:text-slate-200'
        "
        @click="toggleDay(day)"
      >
        {{ $t(`RECURRING_TASKS.DAYS_SHORT.${day}`) }}
      </button>
    </div>

    <!-- Hasta cuándo -->
    <div class="flex flex-wrap items-center gap-2 text-sm">
      <span class="text-slate-600 dark:text-slate-300">
        {{ $t('RECURRING_TASKS.ENDS') }}
      </span>
      <select
        :value="value.ends"
        class="!w-auto !mb-0 h-8 text-sm"
        @change="set('ends', $event.target.value)"
      >
        <option value="never">{{ $t('RECURRING_TASKS.ENDS_NEVER') }}</option>
        <option value="on">{{ $t('RECURRING_TASKS.ENDS_ON') }}</option>
        <option value="after">{{ $t('RECURRING_TASKS.ENDS_AFTER') }}</option>
      </select>
      <input
        v-if="value.ends === 'on'"
        :value="value.ends_on"
        type="date"
        class="!w-auto !mb-0 h-8 text-sm"
        @input="set('ends_on', $event.target.value)"
      />
      <template v-if="value.ends === 'after'">
        <input
          :value="value.max_count"
          type="number"
          min="1"
          class="!w-16 !mb-0 h-8 text-sm"
          @input="set('max_count', Number($event.target.value) || 1)"
        />
        <span class="text-slate-600 dark:text-slate-300">
          {{ $t('RECURRING_TASKS.TIMES') }}
        </span>
      </template>
    </div>

    <p class="m-0 text-xs font-medium text-woot-700 dark:text-woot-300">
      {{ summary }}
    </p>
  </div>
</template>
