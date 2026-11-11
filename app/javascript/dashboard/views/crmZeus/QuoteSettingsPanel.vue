<!--
  CrmZeus Q3.1 — parámetros de las cotizaciones de la cuenta (preferencias de la
  empresa en CRMZeus), dentro de Catálogos. Cada casilla se guarda al cambiarla.
  Solo el Administrador las cambia; los demás las ven deshabilitadas.
-->
<script>
import { useAlert } from 'dashboard/composables';
import CrmCatalogs from 'dashboard/api/crmCatalogs';
import Spinner from 'shared/components/Spinner.vue';
import { errorMessage } from './crmHelpers';

export default {
  name: 'CrmQuoteSettingsPanel',
  components: { Spinner },
  props: {
    isAdmin: { type: Boolean, default: false },
  },
  data() {
    return { settings: null, saving: false };
  },
  mounted() {
    this.fetch();
  },
  methods: {
    async fetch() {
      try {
        const { data } = await CrmCatalogs.settings();
        this.settings = data.settings;
      } catch (error) {
        useAlert(errorMessage(error, this.$t('CRM_ZEUS.ERROR')));
      }
    },
    async toggle(key, value) {
      const previous = this.settings[key];
      this.settings[key] = value;
      this.saving = true;
      try {
        const { data } = await CrmCatalogs.updateSettings({ [key]: value });
        this.settings = data.settings;
        useAlert(this.$t('CRM_ZEUS.CATALOGS.SAVED'));
      } catch (error) {
        this.settings[key] = previous;
        useAlert(errorMessage(error, this.$t('CRM_ZEUS.ERROR')));
      } finally {
        this.saving = false;
      }
    },
  },
};
</script>

<template>
  <div>
    <p class="max-w-xl m-0 mb-4 text-sm text-slate-600 dark:text-slate-300">
      {{ $t('CRM_ZEUS.QUOTE_SETTINGS.DESCRIPTION') }}
    </p>
    <Spinner v-if="!settings" />
    <label v-else class="flex items-start max-w-xl gap-2 text-sm">
      <input
        :checked="settings.require_delivery_date"
        type="checkbox"
        class="!m-0 mt-0.5"
        :disabled="!isAdmin || saving"
        @change="toggle('require_delivery_date', $event.target.checked)"
      />
      <span>
        {{ $t('CRM_ZEUS.QUOTE_SETTINGS.REQUIRE_DELIVERY_DATE') }}
        <span class="block text-xs text-slate-500">
          {{ $t('CRM_ZEUS.QUOTE_SETTINGS.REQUIRE_DELIVERY_DATE_HINT') }}
        </span>
      </span>
    </label>
  </div>
</template>
