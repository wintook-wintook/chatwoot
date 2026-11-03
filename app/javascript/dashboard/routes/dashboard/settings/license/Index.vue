<script>
// feat/licencias (F5) — LA LICENCIA DE ESTA CUENTA (solo lectura)
// ============================================================================
// El administrador de la cuenta ve su plan, cuántos agentes usa contra el tope, cuándo vence
// y la fila de licencias por activarse. No puede cambiar nada: eso lo hace Wintook (§8).
// Los datos vienen con la cuenta (license en accounts/show): sin pedir nada aparte. La
// tarjeta (LicenseStatusCard) también sale en Configuración › General.
// Plan: docs/licencias_plan_v1.md §8 y §10 (F5)
// ============================================================================
import { mapGetters } from 'vuex';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import LicenseStatusCard from './LicenseStatusCard.vue';

export default {
  components: { BaseSettingsHeader, LicenseStatusCard },
  computed: {
    ...mapGetters({
      accountId: 'getCurrentAccountId',
      getAccount: 'accounts/getAccount',
    }),
    license() {
      const account = this.getAccount(this.accountId);
      return (account && account.license) || null;
    },
  },
  methods: {
    t(key, args) {
      return this.$t(`LICENSES.ACCOUNT_VIEW.${key}`, args);
    },
  },
};
</script>

<template>
  <div class="flex flex-col w-full max-w-3xl gap-6">
    <BaseSettingsHeader :title="t('TITLE')" :description="t('DESCRIPTION')" />

    <p v-if="!license" class="text-sm text-slate-600 dark:text-slate-300">
      {{ t('NONE') }}
    </p>
    <LicenseStatusCard v-else :license="license" />
  </div>
</template>
