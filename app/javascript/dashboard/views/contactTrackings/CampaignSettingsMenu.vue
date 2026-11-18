<script>
// ================================================================================
// @campanas_vendedor — menú «⚙ Ajustes» de la cabecera del detalle de campaña.
// Reemplaza las tarjetas de Entrega de interesados (prospeccion P2) y Puntuación
// (prospeccion P4) para dejar el alto a las tablas. Cada opción muestra su resumen
// y emite el evento para que el detalle abra la misma ventana de configuración.
// Al pasar el mouse sobre el botón, el tooltip trae los dos resúmenes.
// ================================================================================
export default {
  props: {
    handoffSummary: { type: String, default: '' },
    scoringSummary: { type: String, default: '' },
  },
  emits: ['handoff', 'scoring'],
  data() {
    return { open: false };
  },
  computed: {
    options() {
      return [
        {
          key: 'handoff',
          title: this.$t('TRACKING_CAMPAIGN_DETAIL.HANDOFF_SETTINGS.TITLE'),
          summary: this.handoffSummary,
          choose: this.chooseHandoff,
        },
        {
          key: 'scoring',
          title: this.$t('TRACKING_CAMPAIGN_DETAIL.SCORING.TITLE'),
          summary: this.scoringSummary,
          choose: this.chooseScoring,
        },
      ];
    },
    tooltip() {
      return this.options.map(o => `${o.title}: ${o.summary}`).join('\n');
    },
  },
  watch: {
    open(isOpen) {
      if (isOpen) window.addEventListener('keydown', this.onKeydown);
      else window.removeEventListener('keydown', this.onKeydown);
    },
  },
  beforeDestroy() {
    window.removeEventListener('keydown', this.onKeydown);
  },
  methods: {
    close() {
      this.open = false;
    },
    onKeydown(event) {
      if (event.key === 'Escape') this.close();
    },
    chooseHandoff() {
      this.close();
      this.$emit('handoff');
    },
    chooseScoring() {
      this.close();
      this.$emit('scoring');
    },
  },
};
</script>

<template>
  <div v-on-clickaway="close" class="relative">
    <woot-button
      variant="smooth"
      color-scheme="secondary"
      size="small"
      icon="settings"
      :title="open ? '' : tooltip"
      :aria-expanded="open ? 'true' : 'false'"
      @click="open = !open"
    >
      {{ $t('TRACKING_CAMPAIGN_DETAIL.SETTINGS_MENU.BUTTON') }}
      <fluent-icon icon="chevron-down" size="12" class="inline-block" />
    </woot-button>
    <div
      v-if="open"
      class="absolute left-0 z-30 p-1 mt-1 bg-white border rounded-md shadow-xl w-80 top-full dark:bg-slate-800 border-slate-50 dark:border-slate-700"
    >
      <button
        v-for="(option, index) in options"
        :key="option.key"
        type="button"
        class="block w-full px-3 py-2 text-left rounded-md hover:bg-slate-50 dark:hover:bg-slate-700"
        :class="index ? 'border-t border-slate-75 dark:border-slate-700' : ''"
        @click="option.choose"
      >
        <span
          class="block text-sm font-medium text-slate-700 dark:text-slate-200"
        >
          {{ option.title }}
        </span>
        <span class="block text-xs text-slate-500 dark:text-slate-400">
          {{ option.summary }}
        </span>
      </button>
    </div>
  </div>
</template>
