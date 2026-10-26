<!--
  @tickets_cases — Plan-Clase-Comercial F4
  Ajustes de Comercial: moneda por defecto de las oportunidades y catálogo de
  motivos (ganada, perdida, pospuesta, cancelada). Es la página Configuración →
  Comercial (CommercialConfig.vue).
-->
<script>
import { mapGetters } from 'vuex';
import CaseOutcomeReasonsAPI from 'dashboard/api/caseOutcomeReasons';

// Mismo orden que los resultados de la Lista: Ganadas · Perdidas · Pospuestas · Canceladas.
const REASON_OUTCOMES = ['won', 'lost', 'postponed', 'cancelled'];

export default {
  name: 'CommercialSettings',
  data() {
    return {
      currencyDraft: '',
      reasons: [],
      newLabels: { won: '', lost: '', postponed: '', cancelled: '' },
      isLoadingReasons: false,
    };
  },
  computed: {
    ...mapGetters({
      settings: 'caseTickets/getCaseSettings',
      uiFlags: 'caseTickets/getSettingsUIFlags',
    }),
    reasonOutcomes() {
      return REASON_OUTCOMES;
    },
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
  mounted() {
    this.fetchReasons();
  },
  methods: {
    reasonsFor(outcome) {
      return this.reasons.filter(r => r.outcome === outcome);
    },
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
    async fetchReasons() {
      this.isLoadingReasons = true;
      try {
        const { data } = await CaseOutcomeReasonsAPI.get();
        this.reasons = data.case_outcome_reasons || [];
      } finally {
        this.isLoadingReasons = false;
      }
    },
    async addReason(outcome) {
      const label = this.newLabels[outcome].trim();
      if (!label) return;
      try {
        await CaseOutcomeReasonsAPI.create({
          case_outcome_reason: { outcome, label },
        });
        this.newLabels[outcome] = '';
        await this.fetchReasons();
        this.toast('SAVED');
      } catch (_e) {
        this.toast('ERROR', 'error');
      }
    },
    async updateReason(reason, changes) {
      try {
        await CaseOutcomeReasonsAPI.update(reason.id, {
          case_outcome_reason: changes,
        });
        await this.fetchReasons();
        this.toast('SAVED');
      } catch (_e) {
        this.toast('ERROR', 'error');
      }
    },
    renameReason(reason, event) {
      const label = event.target.value.trim();
      if (!label || label === reason.label) {
        event.target.value = reason.label;
        return;
      }
      this.updateReason(reason, { label });
    },
    async deleteReason(reason) {
      try {
        await CaseOutcomeReasonsAPI.delete(reason.id);
        await this.fetchReasons();
        this.toast('DELETED');
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

    <!-- Catálogo de motivos -->
    <div
      class="flex flex-col gap-3 p-4 mt-2 bg-white border rounded-lg dark:bg-slate-800 border-slate-75 dark:border-slate-700"
    >
      <div>
        <span
          class="text-base font-semibold text-slate-800 dark:text-slate-100"
        >
          {{ $t('CASE_TICKETS.COMMERCIAL.SETTINGS.REASONS_TITLE') }}
        </span>
        <p class="mt-1 mb-0 text-sm text-slate-500 dark:text-slate-400">
          {{ $t('CASE_TICKETS.COMMERCIAL.SETTINGS.REASONS_DESC') }}
        </p>
      </div>

      <div class="grid gap-4 md:grid-cols-2">
        <div
          v-for="outcome in reasonOutcomes"
          :key="outcome"
          class="flex flex-col gap-2"
        >
          <span
            class="text-xs font-semibold tracking-wide uppercase text-slate-500 dark:text-slate-400"
          >
            {{ $t(`CASE_TICKETS.COMMERCIAL.SETTINGS.GROUPS.${outcome}`) }}
          </span>
          <p
            v-if="!isLoadingReasons && !reasonsFor(outcome).length"
            class="m-0 text-sm text-slate-400 dark:text-slate-500"
          >
            {{ $t('CASE_TICKETS.COMMERCIAL.SETTINGS.EMPTY') }}
          </p>
          <div
            v-for="reason in reasonsFor(outcome)"
            :key="reason.id"
            class="flex items-center gap-2"
          >
            <input
              type="text"
              class="flex-1 h-8 !mb-0 text-sm"
              :class="reason.active ? '' : 'opacity-50'"
              :value="reason.label"
              maxlength="100"
              @change="renameReason(reason, $event)"
            />
            <label
              class="flex items-center gap-1 text-xs text-slate-500 dark:text-slate-400"
            >
              <input
                type="checkbox"
                class="!mb-0"
                :checked="reason.active"
                @change="updateReason(reason, { active: !reason.active })"
              />
              {{ $t('CASE_TICKETS.COMMERCIAL.SETTINGS.ACTIVE') }}
            </label>
            <woot-button
              size="tiny"
              variant="clear"
              color-scheme="alert"
              icon="delete"
              :title="$t('CASE_TICKETS.COMMERCIAL.SETTINGS.DELETE')"
              @click="deleteReason(reason)"
            />
          </div>
          <form class="flex gap-2" @submit.prevent="addReason(outcome)">
            <input
              v-model="newLabels[outcome]"
              type="text"
              maxlength="100"
              class="flex-1 h-8 !mb-0 text-sm"
              :placeholder="
                $t('CASE_TICKETS.COMMERCIAL.SETTINGS.LABEL_PLACEHOLDER')
              "
            />
            <woot-button
              size="small"
              variant="smooth"
              icon="add"
              type="submit"
              :disabled="!newLabels[outcome].trim()"
            >
              {{ $t('CASE_TICKETS.COMMERCIAL.SETTINGS.ADD') }}
            </woot-button>
          </form>
        </div>
      </div>
    </div>
  </div>
</template>
