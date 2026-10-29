<!--
  @tickets_cases — Configuración → Comercial: cotizaciones y moneda por defecto.
  Antes era una sección al final de Ajustes del módulo; ahora tiene su propia
  entrada en el menú. Los motivos de cierre están en OutcomeReasonsConfig.vue.
-->
<script>
import { mapGetters } from 'vuex';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import CommercialSettings from './commercial/CommercialSettings.vue';

export default {
  name: 'CommercialConfig',
  components: { CommercialSettings },
  computed: {
    ...mapGetters({
      accountId: 'getCurrentAccountId',
      isFeatureEnabledonAccount: 'accounts/isFeatureEnabledonAccount',
    }),
    commercialEnabled() {
      return this.isFeatureEnabledonAccount(
        this.accountId,
        FEATURE_FLAGS.CASE_COMMERCIAL
      );
    },
  },
  mounted() {
    this.$store.dispatch('caseTickets/fetchSettings');
  },
};
</script>

<template>
  <div
    class="flex flex-col flex-1 w-full h-full overflow-hidden bg-slate-25 dark:bg-slate-900"
  >
    <div
      class="flex items-center flex-shrink-0 px-6 py-4 bg-white border-b dark:bg-slate-900 border-slate-50 dark:border-slate-800/50"
    >
      <h1 class="m-0 text-xl font-bold text-slate-800 dark:text-slate-100">
        {{ $t('CASE_TICKETS.COMMERCIAL.SETTINGS.PAGE_TITLE') }}
      </h1>
    </div>

    <div class="flex flex-col flex-1 gap-2 px-6 py-4 overflow-y-auto">
      <CommercialSettings v-if="commercialEnabled" />
      <p v-else class="m-0 text-sm text-slate-500 dark:text-slate-400">
        {{ $t('CASE_TICKETS.COMMERCIAL.SETTINGS.DISABLED') }}
      </p>
    </div>
  </div>
</template>
