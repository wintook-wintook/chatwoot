<!--
  Tareas que se repiten — «Cada cuánto» y «Hasta cuándo», en un renglón. v-model = el objeto de
  defaultRecurrence() (recurrence.js).
-->
<script>
import { UNITS, WEEKDAYS } from './recurrence';

export default {
  name: 'RecurrenceFields',
  model: { prop: 'value', event: 'input' },
  props: {
    value: { type: Object, required: true },
  },
  data() {
    return { units: UNITS, weekdays: WEEKDAYS };
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
  <!-- Todo en un renglón (se acomoda en dos si no cabe): tipo · cada N … · días · termina. -->
  <div class="flex flex-wrap items-center gap-1.5 text-sm">
    <!-- La casilla «Se repite» (o lo que quiera poner quien lo usa) en el mismo renglón -->
    <slot name="before" />
    <select
      :value="value.mode"
      class="!w-auto !mb-0 h-8 text-sm"
      :title="$t(`RECURRING_TASKS.MODE_${value.mode.toUpperCase()}_HINT`)"
      @change="set('mode', $event.target.value)"
    >
      <option v-for="mode in ['fixed', 'after_done']" :key="mode" :value="mode">
        {{ $t(`RECURRING_TASKS.MODE_${mode.toUpperCase()}`) }}
      </option>
    </select>
    <span class="text-slate-600 dark:text-slate-300">
      {{ $t('RECURRING_TASKS.EVERY') }}
    </span>
    <input
      :value="value.every"
      type="number"
      min="1"
      max="365"
      class="!w-14 !mb-0 h-8 text-sm"
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
    <span
      v-if="value.mode === 'fixed' && value.unit === 'week'"
      class="inline-flex gap-0.5"
    >
      <button
        v-for="day in weekdays"
        :key="day"
        type="button"
        class="w-7 h-8 text-xs border rounded"
        :class="
          value.weekdays.includes(day)
            ? 'bg-woot-500 border-woot-500 text-white'
            : 'bg-white dark:bg-slate-900 border-slate-200 dark:border-slate-600 text-slate-700 dark:text-slate-200'
        "
        @click="toggleDay(day)"
      >
        {{ $t(`RECURRING_TASKS.DAYS_SHORT.${day}`) }}
      </button>
    </span>
    <span class="text-slate-600 dark:text-slate-300 ltr:ml-1 rtl:mr-1">
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
        class="!w-14 !mb-0 h-8 text-sm"
        @input="set('max_count', Number($event.target.value) || 1)"
      />
      <span class="text-slate-600 dark:text-slate-300">
        {{ $t('RECURRING_TASKS.TIMES') }}
      </span>
    </template>
  </div>
</template>
