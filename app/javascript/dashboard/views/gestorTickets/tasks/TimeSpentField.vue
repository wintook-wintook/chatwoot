<!--
  Tiempo dedicado — en el reporte de cierre y en «Reportar actividad». v-model en
  minutos (o null). Atajos de 15 min a 2 h, y horas + minutos a mano.
-->
<script>
const PRESETS = [15, 30, 60, 120];

export default {
  name: 'TimeSpentField',
  model: { prop: 'value', event: 'input' },
  props: {
    value: { type: Number, default: null },
    required: { type: Boolean, default: false },
  },
  emits: ['input'],
  computed: {
    presets() {
      return PRESETS;
    },
    hours() {
      return this.value ? Math.floor(this.value / 60) : '';
    },
    minutes() {
      return this.value ? this.value % 60 : '';
    },
  },
  methods: {
    label(preset) {
      return preset < 60 ? `${preset} min` : `${preset / 60} h`;
    },
    set(hours, minutes) {
      const total = Number(hours || 0) * 60 + Number(minutes || 0);
      this.$emit('input', total > 0 ? Math.round(total) : null);
    },
    onHours(event) {
      this.set(event.target.value, this.minutes);
    },
    onMinutes(event) {
      this.set(this.hours, event.target.value);
    },
  },
};
</script>

<template>
  <div class="space-y-1">
    <span class="text-sm font-medium text-slate-700 dark:text-slate-200">
      {{ $t('TASK_REPORT.MINUTES.LABEL') }}
      <template v-if="!required">
        {{ $t('TASK_REPORT.MINUTES.OPTIONAL') }}
      </template>
    </span>
    <div class="flex flex-wrap items-center gap-2">
      <button
        v-for="preset in presets"
        :key="preset"
        type="button"
        class="h-8 px-3 text-xs border rounded-full"
        :class="
          value === preset
            ? 'bg-woot-50 border-woot-300 text-woot-700 dark:bg-woot-900/40 dark:border-woot-600 dark:text-woot-200'
            : 'border-slate-200 text-slate-600 hover:bg-slate-50 dark:border-slate-600 dark:text-slate-300 dark:hover:bg-slate-700'
        "
        @click="$emit('input', preset)"
      >
        {{ label(preset) }}
      </button>
      <label class="flex items-center gap-1 text-xs text-slate-600">
        <input
          type="number"
          min="0"
          max="24"
          class="!mb-0 !w-16 text-sm"
          :value="hours"
          :aria-label="$t('TASK_REPORT.MINUTES.HOURS')"
          @input="onHours"
        />
        {{ $t('TASK_REPORT.MINUTES.HOURS') }}
      </label>
      <label class="flex items-center gap-1 text-xs text-slate-600">
        <input
          type="number"
          min="0"
          max="59"
          step="5"
          class="!mb-0 !w-16 text-sm"
          :value="minutes"
          :aria-label="$t('TASK_REPORT.MINUTES.MINUTES')"
          @input="onMinutes"
        />
        {{ $t('TASK_REPORT.MINUTES.MINUTES') }}
      </label>
    </div>
  </div>
</template>
