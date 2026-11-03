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
// Las tres son opciones del menú secundario (una ruta cada una, meta.tab): aquí no hay
// pestañas. El filtro de la tarjeta viaja en la dirección (?estado=&dias=).
// Crear y editar un plan (meta.tab = plan_form) es una página de captura: PlanForm trae su
// propio encabezado y, si se sale con cambios, lo pregunta (guardas de ruta de aquí). La ficha
// de una cuenta (meta.tab = account, F6) también trae su propio encabezado.
// Plan: docs/licencias_plan_v1.md §9 y §10 (F2)
// ============================================================================
import { mapGetters } from 'vuex';
import LicensesAPI from 'dashboard/api/licenses';
import BaseSettingsHeader from 'dashboard/routes/dashboard/settings/components/BaseSettingsHeader.vue';
import SummaryTab from './SummaryTab.vue';
import AccountsTab from './AccountsTab.vue';
import PlansTab from './PlansTab.vue';
import PlanForm from './PlanForm.vue';
import AccountDetail from './AccountDetail.vue';
import IssueForm from './IssueForm.vue';

export default {
  components: {
    BaseSettingsHeader,
    SummaryTab,
    AccountsTab,
    PlansTab,
    PlanForm,
    AccountDetail,
    IssueForm,
  },
  // Las rutas comparten esta pantalla: cambiar de una a otra es «update», salir es «leave».
  beforeRouteUpdate(to, from, next) {
    this.guardPlanForm(next, to, from);
  },
  beforeRouteLeave(to, from, next) {
    this.guardPlanForm(next, to, from);
  },
  data() {
    return {
      plans: [],
      plansLoaded: false,
      availableFeatures: [],
      defaultFeatures: [],
      noAccess: false,
      loadError: false,
    };
  },
  computed: {
    ...mapGetters({ currentUser: 'getCurrentUser' }),
    canManage() {
      return Boolean(this.currentUser && this.currentUser.can_manage_licenses);
    },
    tab() {
      return this.$route.meta.tab || 'summary';
    },
    // Las páginas que traen su propio encabezado.
    ownHeader() {
      return ['plan_form', 'account', 'issue'].includes(this.tab);
    },
    licensedAccountId() {
      return Number(this.$route.params.licensedAccountId);
    },
    // El plan que se captura: nuevo, o el de la dirección (null si no existe).
    formPlan() {
      if (this.$route.name === 'licenses_plans_new') return { id: null };
      const id = Number(this.$route.params.planId);
      return this.plans.find(plan => plan.id === id) || null;
    },
    // Como «Nueva plantilla»: agregar va en el encabezado.
    showNewPlan() {
      return (
        this.tab === 'plans' &&
        this.canManage &&
        !this.noAccess &&
        !this.loadError
      );
    },
    // Lo que pidió una tarjeta del resumen.
    accountsEstado() {
      return String(this.$route.query.estado || '');
    },
    accountsDias() {
      const dias = Number(this.$route.query.dias);
      return dias > 0 ? dias : 7;
    },
  },
  mounted() {
    this.fetchPlans();
  },
  methods: {
    t(key, args) {
      return this.$t(`LICENSES.${key}`, args);
    },
    async guardPlanForm(next, to, from) {
      // Cambiar de pestaña en la ficha cambia la dirección (?tab=): no se pregunta por eso.
      if (
        to &&
        from &&
        to.name === from.name &&
        to.name === 'licenses_accounts_show'
      ) {
        next();
        return;
      }
      const form =
        this.$refs.planForm || this.$refs.issueForm || this.$refs.accountDetail;
      next(form ? await form.confirmLeave() : true);
    },
    openNew() {
      this.$router.push({ name: 'licenses_plans_new' });
    },
    openAccounts({ estado, dias }) {
      this.$router.push({
        name: 'licenses_accounts',
        query: { estado: estado || undefined, dias: dias || undefined },
      });
    },
    async fetchPlans() {
      this.loadError = false;
      try {
        const { data } = await LicensesAPI.getPlans();
        this.plans = data.plans || [];
        this.availableFeatures = data.available_features || [];
        this.defaultFeatures = data.default_features || [];
        this.plansLoaded = true;
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
      <div v-if="!ownHeader" class="shrink-0">
        <BaseSettingsHeader
          :title="t(`TABS.${tab.toUpperCase()}`)"
          :description="t('DESCRIPTION')"
        >
          <template #actions>
            <woot-button v-if="showNewPlan" icon="add-circle" @click="openNew">
              {{ t('PLANS.NEW') }}
            </woot-button>
          </template>
        </BaseSettingsHeader>
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
      <div
        v-else
        class="flex flex-col flex-1 min-h-0"
        :class="{ 'mt-6': !ownHeader }"
      >
        <SummaryTab v-if="tab === 'summary'" @filter="openAccounts" />
        <AccountsTab
          v-else-if="tab === 'accounts'"
          :key="$route.fullPath"
          :can-manage="canManage"
          :initial-estado="accountsEstado"
          :initial-dias="accountsDias"
        />
        <template v-else-if="tab === 'issue'">
          <IssueForm
            v-if="canManage"
            ref="issueForm"
            :key="$route.fullPath"
            :licensed-account-id="licensedAccountId"
            :plans="plans"
          />
          <p v-else class="text-sm text-slate-600 dark:text-slate-300">
            {{ t('ISSUE.NO_MANAGE') }}
          </p>
        </template>
        <AccountDetail
          v-else-if="tab === 'account'"
          ref="accountDetail"
          :licensed-account-id="licensedAccountId"
          :can-manage="canManage"
          :available-features="availableFeatures"
        />
        <template v-else-if="tab === 'plan_form'">
          <PlanForm
            v-if="formPlan && canManage"
            ref="planForm"
            :key="$route.fullPath"
            :plan="formPlan"
            :available-features="availableFeatures"
            :default-features="defaultFeatures"
            @saved="fetchPlans"
          />
          <p
            v-else-if="plansLoaded"
            class="text-sm text-slate-600 dark:text-slate-300"
          >
            {{
              canManage ? t('PLAN_FORM.NOT_FOUND') : t('PLAN_FORM.NO_MANAGE')
            }}
          </p>
        </template>
        <PlansTab v-else :plans="plans" :can-manage="canManage" />
      </div>
    </div>
  </div>
</template>
