<!--
  CrmZeus O1 — lista de organizaciones (clientes y prospectos), como «Clientes» /
  «Prospectos» de CRMZeus. Paginación en servidor (50 por página). La búsqueda cubre
  clave, razón social y nombre comercial. El formulario llega en O2.
-->
<script>
import CrmOrganizations from 'dashboard/api/crmOrganizations';
import CrmCatalogs from 'dashboard/api/crmCatalogs';
import TableFooter from 'dashboard/components/widgets/TableFooter.vue';

const TABS = ['customer', 'prospect', 'all'];
const STATUS_BADGES = {
  active: 'bg-green-50 text-green-800 dark:bg-green-900/30 dark:text-green-300',
  inactive: 'bg-slate-100 text-slate-600 dark:bg-slate-700 dark:text-slate-300',
};
const WARNING_BADGE =
  'bg-amber-50 text-amber-800 dark:bg-amber-900/30 dark:text-amber-300';

export default {
  name: 'CrmZeusOrganizations',
  components: { TableFooter },
  data() {
    return {
      tabs: TABS,
      tab: 'customer',
      rows: [],
      meta: { count: 0, page: 1, per_page: 50, counts: {} },
      filters: { q: '', status: '', seller_id: '' },
      sellers: [],
      statuses: [],
      page: 1,
      isFetching: false,
      error: '',
      searchDebounce: null,
    };
  },
  mounted() {
    this.fetchCatalogs();
    this.fetch();
  },
  beforeDestroy() {
    clearTimeout(this.searchDebounce);
  },
  methods: {
    async fetchCatalogs() {
      try {
        const { data } = await CrmCatalogs.fetch();
        this.sellers = data.sellers;
        this.statuses = data.statuses;
      } catch (e) {
        // Sin catálogos la lista sigue sirviendo; solo faltan los filtros.
      }
    },
    async fetch() {
      this.isFetching = true;
      this.error = '';
      try {
        const params = { ...this.filters, page: this.page };
        if (this.tab !== 'all') params.type = this.tab;
        Object.keys(params).forEach(k => !params[k] && delete params[k]);
        const { data } = await CrmOrganizations.list(params);
        this.rows = data.organizations;
        this.meta = data.meta;
      } catch (e) {
        this.rows = [];
        this.error =
          e.response?.data?.message || e.response?.data?.error || e.message;
      } finally {
        this.isFetching = false;
      }
    },
    selectTab(tab) {
      this.tab = tab;
      this.onFilterChange();
    },
    onFilterChange() {
      this.page = 1;
      this.fetch();
    },
    onSearch() {
      clearTimeout(this.searchDebounce);
      this.searchDebounce = setTimeout(this.onFilterChange, 400);
    },
    onPageChange(page) {
      this.page = page;
      this.fetch();
    },
    statusBadge(status) {
      return STATUS_BADGES[status] || WARNING_BADGE;
    },
  },
};
</script>

<template>
  <div
    class="flex flex-col flex-1 w-full h-full overflow-hidden bg-slate-25 dark:bg-slate-900"
  >
    <div
      class="flex flex-col flex-shrink-0 gap-3 px-6 py-4 bg-white border-b dark:bg-slate-900 border-slate-50 dark:border-slate-800/50"
    >
      <div>
        <h1 class="m-0 text-xl font-bold text-slate-800 dark:text-slate-100">
          {{ $t('CRM_ZEUS.ORGANIZATIONS.TITLE') }}
        </h1>
        <p class="m-0 text-sm text-slate-500 dark:text-slate-400">
          {{ $t('CRM_ZEUS.ORGANIZATIONS.SUBTITLE') }}
        </p>
      </div>
      <div class="flex flex-wrap gap-1">
        <button
          v-for="t in tabs"
          :key="t"
          type="button"
          class="px-3 py-1 text-sm rounded-md"
          :class="
            tab === t
              ? 'bg-woot-500 text-white'
              : 'bg-slate-50 text-slate-700 dark:bg-slate-800 dark:text-slate-200'
          "
          @click="selectTab(t)"
        >
          {{ $t(`CRM_ZEUS.ORGANIZATIONS.TABS.${t.toUpperCase()}`) }}
          <span class="ml-1 opacity-75">({{ meta.counts[t] || 0 }})</span>
        </button>
      </div>
      <div class="grid items-start grid-cols-1 gap-2 lg:grid-cols-[7fr_3fr]">
        <div class="flex flex-wrap items-center gap-2">
          <woot-button
            size="small"
            color-scheme="primary"
            icon="arrow-clockwise"
            :is-loading="isFetching"
            @click="fetch"
          >
            {{ $t('CRM_ZEUS.REFRESH') }}
          </woot-button>
          <select
            v-model="filters.status"
            class="!mb-0 text-sm w-48"
            @change="onFilterChange"
          >
            <option value="">
              {{ $t('CRM_ZEUS.ORGANIZATIONS.ALL_STATUSES') }}
            </option>
            <option v-for="s in statuses" :key="s" :value="s">
              {{ $t(`CRM_ZEUS.STATUS.${s.toUpperCase()}`) }}
            </option>
          </select>
          <select
            v-if="sellers.length"
            v-model="filters.seller_id"
            class="!mb-0 text-sm w-48"
            @change="onFilterChange"
          >
            <option value="">
              {{ $t('CRM_ZEUS.ORGANIZATIONS.ALL_SELLERS') }}
            </option>
            <option v-for="s in sellers" :key="s.id" :value="s.id">
              {{ s.name }}
            </option>
          </select>
        </div>
        <input
          v-model="filters.q"
          type="search"
          class="!mb-0 text-sm"
          :placeholder="$t('CRM_ZEUS.ORGANIZATIONS.SEARCH')"
          @input="onSearch"
        />
      </div>
    </div>

    <div class="flex-1 px-6 py-4 overflow-auto">
      <div
        v-if="error"
        class="p-3 mb-3 text-sm text-red-800 rounded-md bg-red-50 dark:bg-red-900/30 dark:text-red-300"
      >
        {{ error }}
      </div>
      <table
        v-if="rows.length"
        class="w-full text-sm bg-white rounded-md dark:bg-slate-800"
      >
        <thead>
          <tr class="text-left text-slate-500 dark:text-slate-400">
            <th class="px-3 py-2">
              {{ $t('CRM_ZEUS.ORGANIZATIONS.COLUMNS.KEY') }}
            </th>
            <th class="px-3 py-2">
              {{ $t('CRM_ZEUS.ORGANIZATIONS.COLUMNS.TRADE_NAME') }}
            </th>
            <th class="px-3 py-2">
              {{ $t('CRM_ZEUS.ORGANIZATIONS.COLUMNS.LEGAL_NAME') }}
            </th>
            <th v-if="tab === 'all'" class="px-3 py-2">
              {{ $t('CRM_ZEUS.ORGANIZATIONS.COLUMNS.TYPE') }}
            </th>
            <th class="px-3 py-2">
              {{ $t('CRM_ZEUS.ORGANIZATIONS.COLUMNS.SELLER') }}
            </th>
            <th class="px-3 py-2">
              {{ $t('CRM_ZEUS.ORGANIZATIONS.COLUMNS.RATING') }}
            </th>
            <th class="px-3 py-2">
              {{ $t('CRM_ZEUS.ORGANIZATIONS.COLUMNS.PHONE') }}
            </th>
            <th class="px-3 py-2">
              {{ $t('CRM_ZEUS.ORGANIZATIONS.COLUMNS.CITY') }}
            </th>
            <th class="px-3 py-2">
              {{ $t('CRM_ZEUS.ORGANIZATIONS.COLUMNS.STATUS') }}
            </th>
          </tr>
        </thead>
        <tbody>
          <tr
            v-for="row in rows"
            :key="row.id"
            class="border-t border-slate-50 dark:border-slate-700"
          >
            <td class="px-3 py-2 text-slate-500">{{ row.key || '—' }}</td>
            <td
              class="px-3 py-2 font-medium text-slate-800 dark:text-slate-100"
            >
              {{ row.trade_name }}
            </td>
            <td class="px-3 py-2">{{ row.legal_name }}</td>
            <td v-if="tab === 'all'" class="px-3 py-2">
              {{ $t(`CRM_ZEUS.TYPE.${row.organization_type.toUpperCase()}`) }}
            </td>
            <td class="px-3 py-2">{{ row.seller ? row.seller.name : '—' }}</td>
            <td class="px-3 py-2">{{ row.rating ? row.rating.name : '—' }}</td>
            <td class="px-3 py-2 whitespace-nowrap">{{ row.phone || '—' }}</td>
            <td class="px-3 py-2">{{ row.city || '—' }}</td>
            <td class="px-3 py-2">
              <span
                class="px-2 py-0.5 text-xs rounded-full whitespace-nowrap"
                :class="statusBadge(row.status)"
              >
                {{ $t(`CRM_ZEUS.STATUS.${row.status.toUpperCase()}`) }}
              </span>
            </td>
          </tr>
        </tbody>
      </table>
      <p
        v-else-if="!isFetching && !error"
        class="py-10 text-center text-slate-500"
      >
        {{ $t('CRM_ZEUS.ORGANIZATIONS.EMPTY') }}
      </p>
      <p v-else-if="isFetching" class="py-10 text-center text-slate-500">
        {{ $t('CRM_ZEUS.LOADING') }}
      </p>
    </div>
    <TableFooter
      :current-page="page"
      :page-size="meta.per_page"
      :total-count="meta.count"
      @pageChange="onPageChange"
    />
  </div>
</template>
