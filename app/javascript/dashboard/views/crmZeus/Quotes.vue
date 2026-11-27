<!--
  CrmZeus Q2 — lista de cotizaciones con los filtros de CRMZeus: Pendientes
  (predeterminado) · Ganadas este mes · Últimos 2 meses · Todas; «Solo las mías» y
  búsqueda por folio u organización. Paginación en servidor (50). Con `organizationId`
  va incrustada en la pestaña «Cotizaciones» de la organización (sin encabezado de página).
-->
<script>
import { mapGetters } from 'vuex';
import CrmQuotes from 'dashboard/api/crmQuotes';
import TableFooter from 'dashboard/components/widgets/TableFooter.vue';
import { formatMoney } from 'dashboard/helper/caseCommercial';
import { QUOTE_STATUS_BADGES, errorMessage } from './crmHelpers';

const VIEWS = ['pending', 'won_this_month', 'recent', 'all'];

export default {
  name: 'CrmZeusQuotes',
  components: { TableFooter },
  props: {
    organizationId: { type: [String, Number], default: '' },
  },
  data() {
    return {
      views: VIEWS,
      // En la organización se ven todas de entrada (suelen ser pocas).
      view: this.organizationId ? 'all' : 'pending',
      onlyMine: false,
      q: '',
      rows: [],
      meta: { count: 0, page: 1, per_page: 50 },
      page: 1,
      isFetching: false,
      error: '',
      searchDebounce: null,
    };
  },
  computed: {
    ...mapGetters({ currentUser: 'getCurrentUser' }),
    embedded() {
      return !!this.organizationId;
    },
  },
  mounted() {
    this.fetch();
  },
  beforeDestroy() {
    clearTimeout(this.searchDebounce);
  },
  methods: {
    formatMoney,
    statusBadge(status) {
      return QUOTE_STATUS_BADGES[status];
    },
    async fetch() {
      this.isFetching = true;
      this.error = '';
      try {
        const params = { view: this.view, q: this.q, page: this.page };
        if (this.embedded) params.organization_id = this.organizationId;
        if (this.onlyMine) params.created_by_id = this.currentUser.id;
        Object.keys(params).forEach(k => !params[k] && delete params[k]);
        const { data } = await CrmQuotes.list(params);
        this.rows = data.quotes;
        this.meta = data.meta;
      } catch (e) {
        this.rows = [];
        this.error = errorMessage(e, e.message);
      } finally {
        this.isFetching = false;
      }
    },
    selectView(view) {
      this.view = view;
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
    openNew() {
      this.$router.push({
        name: 'crmzeus_quote_new',
        query: this.embedded ? { organization_id: this.organizationId } : {},
      });
    },
    open(row) {
      this.$router.push({
        name: 'crmzeus_quote_edit',
        params: { quoteId: row.id },
      });
    },
    formatDate(value) {
      return value ? new Date(`${value}T00:00:00`).toLocaleDateString() : '—';
    },
  },
};
</script>

<template>
  <div
    class="flex flex-col flex-1 w-full overflow-hidden"
    :class="embedded ? '' : 'h-full bg-slate-25 dark:bg-slate-900'"
  >
    <div
      class="relative flex flex-col flex-shrink-0 gap-3"
      :class="
        embedded
          ? 'pb-3'
          : 'px-6 py-4 bg-white border-b dark:bg-slate-900 border-slate-50 dark:border-slate-800/50'
      "
    >
      <div v-if="!embedded">
        <h1 class="m-0 text-xl font-bold text-slate-800 dark:text-slate-100">
          {{ $t('CRM_ZEUS.QUOTES.TITLE') }}
        </h1>
        <p class="m-0 text-sm text-slate-500 dark:text-slate-400">
          {{ $t('CRM_ZEUS.QUOTES.SUBTITLE') }}
        </p>
      </div>
      <div
        v-if="meta.can_edit && meta.has_series"
        :class="embedded ? 'absolute right-0 top-0' : 'absolute right-6 top-4'"
      >
        <woot-button type="button" size="small" icon="add" @click="openNew">
          {{ $t('CRM_ZEUS.QUOTES.NEW') }}
        </woot-button>
      </div>
      <div class="flex flex-wrap gap-1">
        <button
          v-for="v in views"
          :key="v"
          type="button"
          class="px-3 py-1 text-sm rounded-md"
          :class="
            view === v
              ? 'bg-woot-500 text-white'
              : 'bg-slate-50 text-slate-700 dark:bg-slate-800 dark:text-slate-200'
          "
          @click="selectView(v)"
        >
          {{ $t(`CRM_ZEUS.QUOTES.VIEWS.${v.toUpperCase()}`) }}
        </button>
      </div>
      <div class="grid items-center grid-cols-1 gap-2 lg:grid-cols-[7fr_3fr]">
        <div class="flex flex-wrap items-center gap-3">
          <woot-button
            type="button"
            size="small"
            color-scheme="primary"
            icon="arrow-clockwise"
            :is-loading="isFetching"
            @click="fetch"
          >
            {{ $t('CRM_ZEUS.REFRESH') }}
          </woot-button>
          <label class="flex items-center gap-2 text-sm">
            <input
              v-model="onlyMine"
              type="checkbox"
              class="!m-0"
              @change="onFilterChange"
            />
            {{ $t('CRM_ZEUS.QUOTES.ONLY_MINE') }}
          </label>
        </div>
        <input
          v-model="q"
          type="search"
          class="!mb-0 text-sm"
          :placeholder="$t('CRM_ZEUS.QUOTES.SEARCH')"
          @input="onSearch"
        />
      </div>
    </div>

    <div class="flex-1 overflow-auto" :class="embedded ? '' : 'px-6 py-4'">
      <div
        v-if="error"
        class="p-3 mb-3 text-sm text-red-800 rounded-md bg-red-50 dark:bg-red-900/30 dark:text-red-300"
      >
        {{ error }}
      </div>
      <p
        v-if="!embedded && meta.can_edit && meta.has_series === false"
        class="p-3 mb-3 text-sm rounded-md text-amber-800 bg-amber-50 dark:bg-amber-900/30 dark:text-amber-300"
      >
        {{ $t('CRM_ZEUS.QUOTES.NO_SERIES') }}
      </p>
      <table
        v-if="rows.length"
        class="w-full text-sm bg-white rounded-md dark:bg-slate-800"
      >
        <thead>
          <tr class="text-left text-slate-500 dark:text-slate-400">
            <th class="px-3 py-2">{{ $t('CRM_ZEUS.QUOTES.COLUMNS.DATE') }}</th>
            <th class="px-3 py-2">
              {{ $t('CRM_ZEUS.QUOTES.COLUMNS.FOLIO') }}
            </th>
            <th v-if="!embedded" class="px-3 py-2">
              {{ $t('CRM_ZEUS.QUOTES.COLUMNS.ORGANIZATION') }}
            </th>
            <th class="px-3 py-2">
              {{ $t('CRM_ZEUS.QUOTES.COLUMNS.CONTACT') }}
            </th>
            <th class="px-3 py-2 text-right">
              {{ $t('CRM_ZEUS.QUOTES.COLUMNS.TOTAL') }}
            </th>
            <th class="px-3 py-2">
              {{ $t('CRM_ZEUS.QUOTES.COLUMNS.STATUS') }}
            </th>
            <th class="px-3 py-2">
              {{ $t('CRM_ZEUS.QUOTES.COLUMNS.CREATED_BY') }}
            </th>
            <th class="px-3 py-2">{{ $t('CRM_ZEUS.QUOTES.COLUMNS.PO') }}</th>
          </tr>
        </thead>
        <tbody>
          <tr
            v-for="row in rows"
            :key="row.id"
            class="border-t cursor-pointer border-slate-50 dark:border-slate-700 hover:bg-slate-25 dark:hover:bg-slate-700/50"
            @click="open(row)"
          >
            <td class="px-3 py-2 whitespace-nowrap">
              {{ formatDate(row.quote_date) }}
            </td>
            <td
              class="px-3 py-2 font-medium text-slate-800 dark:text-slate-100"
            >
              {{ row.folio }}
            </td>
            <td v-if="!embedded" class="px-3 py-2">
              {{ row.organization ? row.organization.name : '—' }}
              <span
                v-if="
                  row.organization &&
                  row.organization.organization_type === 'prospect'
                "
                class="ml-1 text-xs text-amber-700"
              >
                {{ $t('CRM_ZEUS.TYPE.PROSPECT') }}
              </span>
            </td>
            <td class="px-3 py-2">
              {{ row.contact ? row.contact.name : '—' }}
            </td>
            <td class="px-3 py-2 text-right whitespace-nowrap">
              {{ formatMoney(row.total, row.currency) }}
            </td>
            <td class="px-3 py-2">
              <span
                class="px-2 py-0.5 text-xs rounded-full whitespace-nowrap"
                :class="statusBadge(row.status)"
              >
                {{ row.status_label }}
              </span>
            </td>
            <td class="px-3 py-2">
              {{ row.created_by ? row.created_by.name : '—' }}
            </td>
            <td class="px-3 py-2 text-slate-500">
              {{ row.purchase_order || '—' }}
            </td>
          </tr>
        </tbody>
      </table>
      <p
        v-else-if="!isFetching && !error"
        class="py-10 text-center text-slate-500"
      >
        {{ $t('CRM_ZEUS.QUOTES.EMPTY') }}
      </p>
      <p v-else-if="isFetching" class="py-10 text-center text-slate-500">
        {{ $t('CRM_ZEUS.LOADING') }}
      </p>
    </div>
    <TableFooter
      v-if="meta.count > meta.per_page || !embedded"
      :current-page="page"
      :page-size="meta.per_page"
      :total-count="meta.count"
      @pageChange="onPageChange"
    />
  </div>
</template>
