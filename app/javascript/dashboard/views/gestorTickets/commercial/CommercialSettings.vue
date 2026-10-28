<!--
  @tickets_cases — Plan-Clase-Comercial F4
  Ajustes de Comercial: cotizaciones y moneda por defecto de las oportunidades. Es
  la página Configuración → Comercial (CommercialConfig.vue). Los motivos de
  cierre pasaron a Catálogos (OutcomeReasons.vue).
-->
<script>
import { mapGetters } from 'vuex';

export default {
  name: 'CommercialSettings',
  data() {
    return {
      currencyDraft: '',
    };
  },
  computed: {
    ...mapGetters({
      settings: 'caseTickets/getCaseSettings',
      uiFlags: 'caseTickets/getSettingsUIFlags',
    }),
    currencyValid() {
      return /^[A-Z]{3}$/.test(this.currencyDraft);
    },
    currencyDirty() {
      return this.currencyDraft !== (this.settings.default_currency || '');
    },
  },
  watch: {
    'settings.default_currency': {
      immediate: true,
      handler(value) {
        this.currencyDraft = value || '';
      },
    },
  },
  methods: {
    toast(key, type) {
      this.$emitter.emit('newToastMessage', {
        message: this.$t(`CASE_TICKETS.COMMERCIAL.SETTINGS.${key}`),
        ...(type ? { type } : {}),
      });
    },
    async saveCurrency() {
      if (!this.currencyValid) return;
      try {
        await this.$store.dispatch('caseTickets/updateSettings', {
          default_currency: this.currencyDraft,
        });
        this.$emitter.emit('newToastMessage', {
          message: this.$t('CASE_TICKETS.SETTINGS.SAVED'),
        });
      } catch (_e) {
        this.currencyDraft = this.settings.default_currency || '';
        this.toast('CURRENCY_INVALID', 'error');
      }
    },
    // Plan-Catalogo-Cotizaciones — ¿la cotización exige oportunidad? e impuesto por defecto.
    async saveQuoteSetting(changes) {
      try {
        await this.$store.dispatch('caseTickets/updateSettings', changes);
        this.$emitter.emit('newToastMessage', {
          message: this.$t('CASE_TICKETS.SETTINGS.SAVED'),
        });
      } catch (_e) {
        this.toast('ERROR', 'error');
      }
    },
  },
};
</script>

<template>
  <div class="flex flex-col gap-2">
    <!-- Plan-Catalogo-Cotizaciones — cotizaciones -->
    <div
      class="flex flex-col gap-3 p-4 bg-white border rounded-lg dark:bg-slate-800 border-slate-75 dark:border-slate-700"
    >
      <span class="text-base font-semibold text-slate-800 dark:text-slate-100">
        {{ $t('QUOTES.TITLE') }}
      </span>
      <label class="flex items-start gap-2 mb-0">
        <input
          type="checkbox"
          class="mt-1"
          :checked="settings.quotes_require_opportunity"
          @change="
            saveQuoteSetting({
              quotes_require_opportunity: $event.target.checked,
            })
          "
        />
        <span class="flex flex-col">
          <span class="text-sm text-slate-800 dark:text-slate-100">
            {{ $t('QUOTES.SETTINGS.REQUIRE_OPPORTUNITY') }}
          </span>
          <span class="text-xs text-slate-500 dark:text-slate-400">
            {{ $t('QUOTES.SETTINGS.REQUIRE_OPPORTUNITY_HINT') }}
          </span>
        </span>
      </label>
      <label class="flex items-center gap-2 mb-0 text-sm">
        {{ $t('QUOTES.SETTINGS.DEFAULT_TAX') }}
        <input
          type="number"
          min="0"
          max="100"
          step="0.01"
          class="!mb-0 w-24"
          :value="settings.default_tax_percent"
          @change="
            saveQuoteSetting({ default_tax_percent: $event.target.value })
          "
        />
      </label>
    </div>
    <!-- Moneda por defecto -->
    <div
      class="flex items-start gap-4 p-4 bg-white border rounded-lg dark:bg-slate-800 border-slate-75 dark:border-slate-700"
    >
      <div class="flex-1">
        <span
          class="text-base font-semibold text-slate-800 dark:text-slate-100"
        >
          {{ $t('CASE_TICKETS.COMMERCIAL.SETTINGS.CURRENCY_TITLE') }}
        </span>
        <p class="mt-1 mb-0 text-sm text-slate-500 dark:text-slate-400">
          {{ $t('CASE_TICKETS.COMMERCIAL.SETTINGS.CURRENCY_DESC') }}
        </p>
      </div>
      <div class="flex items-center flex-shrink-0 gap-2">
        <input
          v-model="currencyDraft"
          type="text"
          maxlength="3"
          class="w-20 h-9 !mb-0 text-sm text-center uppercase"
          @input="currencyDraft = currencyDraft.toUpperCase()"
        />
        <woot-button
          size="small"
          :is-loading="uiFlags.isSaving"
          :disabled="!currencyDirty || !currencyValid"
          @click="saveCurrency"
        >
          {{ $t('CASE_TICKETS.COMMERCIAL.SETTINGS.SAVE') }}
        </woot-button>
      </div>
    </div>
  </div>
</template>
