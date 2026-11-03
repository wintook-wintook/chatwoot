<script>
// feat/licencias (F2b) — «PLANES»
// ============================================================================
// El catálogo. Crear y editar solo con «Gestionar licencias»; no se borran, se desactivan.
// Uno es el de registro: la demo que recibe toda cuenta nueva.
// Se ve como la lista de plantillas de WhatsApp: filtros en recuadro, tabla con encabezado
// fijo y solo ella con scroll, clic en la columna para ordenar, editar junto al nombre y
// paginado con «por página». «Nuevo plan» (en el encabezado de la página) y editar llevan
// a la página de captura (PlanForm.vue); al guardar se regresa aquí.
// ============================================================================
import TableFooter from 'dashboard/components/widgets/TableFooter.vue';

const PER_PAGE_OPTIONS = [10, 25, 50];
const SORTABLE = {
  NAME: plan => plan.name.toLowerCase(),
  DAYS: plan => plan.duration_days,
  AGENTS: plan => plan.default_max_agents,
  ACCOUNTS: plan => plan.accounts_count || 0,
};

export default {
  components: { TableFooter },
  props: {
    plans: { type: Array, default: () => [] },
    canManage: { type: Boolean, default: false },
  },
  data() {
    return {
      q: '',
      typeFilter: '',
      statusFilter: '',
      sortKey: 'NAME',
      sortDir: 'asc',
      page: 1,
      perPage: 25,
      perPageOptions: PER_PAGE_OPTIONS,
    };
  },
  computed: {
    columns() {
      return [
        'NAME',
        'ACTIONS',
        'DAYS',
        'AGENTS',
        'TYPE',
        'FEATURES',
        'ACCOUNTS',
      ].map(key => ({ key, sortable: key in SORTABLE }));
    },
    hasActiveFilters() {
      return Boolean(this.q || this.typeFilter || this.statusFilter);
    },
    filteredPlans() {
      const texto = this.q.trim().toLowerCase();
      const lista = this.plans.filter(
        plan =>
          (!texto || plan.name.toLowerCase().includes(texto)) &&
          (!this.typeFilter || plan.license_type === this.typeFilter) &&
          (!this.statusFilter ||
            plan.active === (this.statusFilter === 'active'))
      );
      const valor = SORTABLE[this.sortKey];
      const signo = this.sortDir === 'asc' ? 1 : -1;
      const compara = (a, b) => {
        if (valor(a) === valor(b)) return 0;
        return valor(a) > valor(b) ? signo : -signo;
      };
      return [...lista].sort(compara);
    },
    pagedPlans() {
      const inicio = (this.page - 1) * this.perPage;
      return this.filteredPlans.slice(inicio, inicio + this.perPage);
    },
  },
  watch: {
    q() {
      this.page = 1;
    },
    typeFilter() {
      this.page = 1;
    },
    statusFilter() {
      this.page = 1;
    },
    perPage() {
      this.page = 1;
    },
  },
  methods: {
    t(key, args) {
      return this.$t(`LICENSES.${key}`, args);
    },
    edit(plan) {
      this.$router.push({
        name: 'licenses_plans_edit',
        params: { planId: plan.id },
      });
    },
    clearFilters() {
      this.q = '';
      this.typeFilter = '';
      this.statusFilter = '';
    },
    sortBy(key) {
      if (this.sortKey === key) {
        this.sortDir = this.sortDir === 'asc' ? 'desc' : 'asc';
      } else {
        this.sortKey = key;
        this.sortDir = 'asc';
      }
    },
    sortIcon(key) {
      if (this.sortKey !== key) return 'arrow-sort';
      return this.sortDir === 'asc' ? 'chevron-up' : 'chevron-down';
    },
    onPageChange(page) {
      this.page = page;
    },
  },
};
</script>

<template>
  <div class="flex flex-col w-full h-[calc(100vh-13rem)] min-h-[20rem]">
    <div
      class="flex flex-wrap items-center gap-2 p-3 mb-4 border border-solid rounded-lg shrink-0 bg-white dark:bg-slate-800 border-slate-100 dark:border-slate-700"
    >
      <div class="relative w-56">
        <input
          v-model="q"
          type="text"
          :placeholder="t('PLANS.SEARCH')"
          class="reset-base box-border w-full h-9 m-0 text-sm rounded-md border border-solid border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-900 text-slate-900 dark:text-slate-100 pl-8 pr-2 outline-none focus:border-woot-500 dark:focus:border-woot-600"
        />
        <fluent-icon
          icon="search"
          size="16"
          class="absolute -translate-y-1/2 left-2 top-1/2 text-slate-400"
        />
      </div>
      <select v-model="typeFilter" class="list-filter">
        <option value="">{{ t('PLANS.ALL_TYPES') }}</option>
        <option value="demo">{{ t('TYPE.DEMO') }}</option>
        <option value="paid">{{ t('TYPE.PAID') }}</option>
      </select>
      <select v-model="statusFilter" class="list-filter">
        <option value="">{{ t('PLANS.ALL_STATUSES') }}</option>
        <option value="active">{{ t('PLANS.ONLY_ACTIVE') }}</option>
        <option value="inactive">{{ t('PLANS.ONLY_INACTIVE') }}</option>
      </select>
      <woot-button
        v-if="hasActiveFilters"
        variant="clear"
        size="small"
        @click="clearFilters"
      >
        {{ t('LIST.CLEAR') }}
      </woot-button>
    </div>

    <div class="flex-1 min-h-0 overflow-y-auto">
      <div
        v-if="!filteredPlans.length"
        class="py-16 text-center border border-dashed rounded-lg text-slate-400 border-slate-200 dark:border-slate-700"
      >
        {{ hasActiveFilters ? t('LIST.EMPTY_FILTERED') : t('PLANS.EMPTY') }}
      </div>
      <table v-else class="w-full text-sm">
        <thead
          class="sticky top-0 z-10 text-left bg-white border-b text-slate-400 border-slate-100 dark:border-slate-700 dark:bg-slate-900"
        >
          <tr>
            <th
              v-for="col in columns"
              :key="col.key"
              class="py-2 pr-3 font-medium whitespace-nowrap"
            >
              <button
                v-if="col.sortable"
                type="button"
                class="sort-header"
                :class="{ 'sort-header--active': sortKey === col.key }"
                @click="sortBy(col.key)"
              >
                {{ t(`PLANS.TABLE.${col.key}`) }}
                <fluent-icon :icon="sortIcon(col.key)" size="12" />
              </button>
              <span v-else>{{ t(`PLANS.TABLE.${col.key}`) }}</span>
            </th>
          </tr>
        </thead>
        <tbody>
          <tr
            v-for="plan in pagedPlans"
            :key="plan.id"
            class="border-b border-slate-50 dark:border-slate-800"
          >
            <td class="py-2 pr-3">
              <span class="font-medium text-slate-700 dark:text-slate-200">
                {{ plan.name }}
              </span>
              <woot-label
                v-if="plan.signup_default"
                small
                color-scheme="primary"
                class="!mb-0 ltr:ml-2 rtl:mr-2"
                :title="t('PLANS.SIGNUP')"
              />
              <woot-label
                v-if="!plan.active"
                small
                color-scheme="secondary"
                class="!mb-0 ltr:ml-2 rtl:mr-2"
                :title="t('PLANS.INACTIVE')"
              />
            </td>
            <td class="py-2 pr-3">
              <woot-button
                v-if="canManage"
                variant="smooth"
                color-scheme="secondary"
                size="small"
                icon="edit"
                :title="t('PLANS.EDIT')"
                @click="edit(plan)"
              />
              <span v-else class="text-slate-300">—</span>
            </td>
            <td class="py-2 pr-3 text-slate-500">{{ plan.duration_days }}</td>
            <td class="py-2 pr-3 text-slate-500">
              {{ plan.default_max_agents }}
            </td>
            <td class="py-2 pr-3 text-slate-500">
              {{ t(`TYPE.${plan.license_type.toUpperCase()}`) }}
            </td>
            <td class="py-2 pr-3 text-slate-500 whitespace-nowrap">
              {{ t('PLANS.FEATURES_COUNT', { count: plan.features.length }) }}
            </td>
            <td class="py-2 pr-3 text-slate-500">{{ plan.accounts_count }}</td>
          </tr>
        </tbody>
      </table>
    </div>

    <div
      v-if="filteredPlans.length"
      class="flex items-center gap-3 border-t shrink-0 border-slate-100 dark:border-slate-700"
    >
      <label
        class="flex items-center gap-2 mb-0 text-xs whitespace-nowrap text-slate-500"
      >
        {{ t('LIST.PER_PAGE') }}
        <select v-model.number="perPage" class="!w-auto h-8 !mb-0 text-xs">
          <option v-for="n in perPageOptions" :key="n" :value="n">
            {{ n }}
          </option>
        </select>
      </label>
      <TableFooter
        class="flex-1"
        :current-page="page"
        :total-count="filteredPlans.length"
        :page-size="perPage"
        @pageChange="onPageChange"
      />
    </div>
  </div>
</template>

<style scoped lang="scss">
.list-filter {
  @apply w-auto h-9 mb-0 text-sm;
}

.sort-header {
  @apply inline-flex items-center gap-1 p-0 font-medium bg-transparent border-0 cursor-pointer text-slate-400 hover:text-slate-700 dark:hover:text-slate-200;
}

.sort-header--active {
  @apply text-slate-700 dark:text-slate-200;
}
</style>
