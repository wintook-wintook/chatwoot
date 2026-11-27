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

// Parámetros de master2: VALIDAR_FECHA_ENTREGA y MOSTRAR_NOTAS.
const KEYS = ['require_delivery_date', 'show_article_notes'];

export default {
  name: 'CrmQuoteSettingsPanel',
  components: { Spinner },
  props: {
    isAdmin: { type: Boolean, default: false },
  },
  data() {
    return { settings: null, saving: false, keys: KEYS };
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
    <div v-else class="flex flex-col gap-4">
      <label
        v-for="key in keys"
        :key="key"
        class="flex items-start max-w-xl gap-2 text-sm"
      >
        <input
          :checked="settings[key]"
          type="checkbox"
          class="!m-0 mt-0.5"
          :disabled="!isAdmin || saving"
          @change="toggle(key, $event.target.checked)"
        />
        <span>
          {{ $t(`CRM_ZEUS.QUOTE_SETTINGS.${key.toUpperCase()}`) }}
          <span class="block text-xs text-slate-500">
            {{ $t(`CRM_ZEUS.QUOTE_SETTINGS.${key.toUpperCase()}_HINT`) }}
          </span>
        </span>
      </label>
    </div>
  </div>
</template>
