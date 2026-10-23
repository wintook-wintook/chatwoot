<!--
  @tickets_cases — «Al iniciar sesión, ir a…»: dónde aterriza este usuario al
  entrar a la app. Se guarda en sus ui_settings (`landing_page`) y lo aplica el
  router (routes/index.js → landingRoute). Por defecto, «Inicio» (Mi resumen).
-->
<script>
import { useAlert } from 'dashboard/composables';
import { useUISettings } from 'dashboard/composables/useUISettings';

const OPTIONS = ['summary', 'conversations', 'my_day'];

export default {
  name: 'LandingPageSetting',
  setup() {
    const { uiSettings, updateUISettings } = useUISettings();
    return { uiSettings, updateUISettings };
  },
  data() {
    return { options: OPTIONS };
  },
  computed: {
    current() {
      const value = this.uiSettings && this.uiSettings.landing_page;
      return OPTIONS.includes(value) ? value : 'summary';
    },
  },
  methods: {
    async choose(value) {
      await this.updateUISettings({ landing_page: value });
      useAlert(this.$t('PROFILE_SETTINGS.FORM.LANDING.SAVED'));
    },
  },
};
</script>

<template>
  <div class="flex flex-col gap-2">
    <label
      v-for="option in options"
      :key="option"
      class="flex items-start gap-2 cursor-pointer"
    >
      <input
        type="radio"
        name="landing_page"
        class="!mb-0 mt-1"
        :checked="current === option"
        @change="choose(option)"
      />
      <span class="flex flex-col">
        <span class="text-sm font-medium text-slate-800 dark:text-slate-100">
          {{ $t(`PROFILE_SETTINGS.FORM.LANDING.OPTIONS.${option}.LABEL`) }}
        </span>
        <span class="text-xs text-slate-500 dark:text-slate-400">
          {{ $t(`PROFILE_SETTINGS.FORM.LANDING.OPTIONS.${option}.HINT`) }}
        </span>
      </span>
    </label>
  </div>
</template>
