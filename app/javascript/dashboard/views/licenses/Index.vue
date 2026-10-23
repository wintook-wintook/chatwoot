<script>
// feat/licencias (F2b) — GESTIÓN DE LICENCIAS
// ============================================================================
// Solo aparece en el menú de una cuenta de Wintook y para quien tenga «Ver licencias»
// (Sidebar.vue); el servidor lo vuelve a validar y, si responde 401, la pantalla lo dice.
//
//   Resumen  indicadores y gráficos (F4); una tarjeta abre Cuentas con su filtro
//   Cuentas  todas las cuentas con su estado de licencia; asignar y ver historial
//   Planes   el catálogo (crear y editar; solo con «Gestionar licencias»)
//
// Contenedor, encabezado y pestañas como el espacio del agente (componentes nativos).
// Plan: docs/licencias_plan_v1.md §9 y §10 (F2)
// ============================================================================
import { mapGetters } from 'vuex';
import LicensesAPI from 'dashboard/api/licenses';
import BaseSettingsHeader from 'dashboard/routes/dashboard/settings/components/BaseSettingsHeader.vue';
import SummaryTab from './SummaryTab.vue';
import AccountsTab from './AccountsTab.vue';
import PlansTab from './PlansTab.vue';

const TABS = ['summary', 'accounts', 'plans'];

export default {
  components: { BaseSettingsHeader, SummaryTab, AccountsTab, PlansTab },
  data() {
    return {
      tab: 'summary',
      tabs: TABS,
      // Lo que pidió una tarjeta del resumen: { estado, dias }. Cambia la llave de la
      // pestaña Cuentas para que arranque con ese filtro.
      accountsFilter: { estado: '', dias: 7 },
      accountsKey: 0,
      plans: [],
      availableFeatures: [],
      noAccess: false,
      loadError: false,
    };
  },
  computed: {
    ...mapGetters({ currentUser: 'getCurrentUser' }),
    canManage() {
      return Boolean(this.currentUser && this.currentUser.can_manage_licenses);
    },
    tabPosition() {
      return Math.max(0, TABS.indexOf(this.tab));
    },
  },
  mounted() {
    this.fetchPlans();
  },
  methods: {
    t(key, args) {
      return this.$t(`LICENSES.${key}`, args);
    },
    openAccounts(filter) {
      this.accountsFilter = filter;
      this.accountsKey += 1;
      this.tab = 'accounts';
    },
    async fetchPlans() {
      this.loadError = false;
      try {
        const { data } = await LicensesAPI.getPlans();
        this.plans = data.plans || [];
        this.availableFeatures = data.available_features || [];
      } catch (error) {
        const status = error && error.response && error.response.status;
        if (status === 401) this.noAccess = true;
        else this.loadError = true;
      }
    },
  },
};
</script>

<template>
  <div
    class="flex flex-col flex-1 w-full h-full min-h-0 p-6 overflow-hidden bg-white sm:py-8 lg:px-16 dark:bg-slate-900 font-inter"
  >
    <div class="flex flex-col flex-1 w-full min-h-0 mx-auto max-w-8xl">
      <div class="shrink-0">
        <BaseSettingsHeader
          :title="t('HEADER')"
          :description="t('DESCRIPTION')"
        />
        <woot-tabs
          v-if="!noAccess"
          class="mt-4"
          :index="tabPosition"
          :border="false"
          @change="tab = tabs[$event]"
        >
          <woot-tabs-item
            v-for="(item, position) in tabs"
            :key="item"
            :index="position"
            :name="t(`TABS.${item.toUpperCase()}`)"
            :show-badge="false"
          />
        </woot-tabs>
      </div>

      <p
        v-if="noAccess"
        class="mt-6 text-sm text-slate-600 dark:text-slate-300"
      >
        {{ t('NO_ACCESS') }}
      </p>
      <p
        v-else-if="loadError"
        class="mt-6 text-sm text-red-600 dark:text-red-400"
      >
        {{ t('LOAD_ERROR') }}
      </p>
      <div v-else class="flex flex-col flex-1 min-h-0 mt-6">
        <SummaryTab v-if="tab === 'summary'" @filter="openAccounts" />
        <AccountsTab
          v-else-if="tab === 'accounts'"
          :key="`accounts-${accountsKey}`"
          :plans="plans"
          :can-manage="canManage"
          :initial-estado="accountsFilter.estado"
          :initial-dias="accountsFilter.dias"
        />
        <PlansTab
          v-else
          :plans="plans"
          :available-features="availableFeatures"
          :can-manage="canManage"
          @changed="fetchPlans"
        />
      </div>
    </div>
  </div>
</template>
