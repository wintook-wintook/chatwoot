<!--
  @tickets_cases — Plan-Clase-Comercial F4
  Ajustes de Comercial: cotizaciones y moneda por defecto de las oportunidades. Es
  la página Configuración → Comercial (CommercialConfig.vue). Los motivos de
  cierre pasaron a Catálogos (OutcomeReasons.vue).
-->
<script>
import { mapGetters } from 'vuex';

// Plan-Organizaciones O3 — qué pasa a una organización a prospecto o a cliente sola.
const ORGANIZATION_RULES = {
  prospect: ['prospect_on_opportunity', 'prospect_on_quote_sent'],
  customer: [
    'customer_on_won',
    'customer_on_contract',
    'customer_on_quote_accepted',
  ],
};

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
    organizationRuleGroups() {
      return ORGANIZATION_RULES;
    },
    organizationRules() {
      return this.settings.organization_rules || {};
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
    toggleOrganizationRule(rule, value) {
      this.saveQuoteSetting({
        organization_rules: { ...this.organizationRules, [rule]: value },
      });
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
    <!-- Plan-Organizaciones O3 — prospectos y clientes automáticos -->
    <div
      class="flex flex-col gap-3 p-4 bg-white border rounded-lg dark:bg-slate-800 border-slate-75 dark:border-slate-700"
    >
      <div>
        <span
          class="text-base font-semibold text-slate-800 dark:text-slate-100"
        >
          {{ $t('ORGANIZATIONS.RULES.TITLE') }}
        </span>
        <p class="mt-1 mb-0 text-sm text-slate-500 dark:text-slate-400">
          {{ $t('ORGANIZATIONS.RULES.DESCRIPTION') }}
        </p>
      </div>
      <div
        v-for="(rules, group) in organizationRuleGroups"
        :key="group"
        class="flex flex-col gap-2"
      >
        <span
          class="text-xs font-semibold tracking-wide uppercase text-slate-500 dark:text-slate-400"
        >
          {{ $t(`ORGANIZATIONS.RULES.GROUPS.${group}`) }}
        </span>
        <label
          v-for="rule in rules"
          :key="rule"
          class="flex items-start gap-2 mb-0"
        >
          <input
            type="checkbox"
            class="mt-1"
            :checked="organizationRules[rule] === true"
            @change="toggleOrganizationRule(rule, $event.target.checked)"
          />
          <span class="text-sm text-slate-800 dark:text-slate-100">
            {{ $t(`ORGANIZATIONS.RULES.ITEMS.${rule}`) }}
          </span>
        </label>
      </div>
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
