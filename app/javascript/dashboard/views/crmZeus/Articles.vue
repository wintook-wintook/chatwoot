<!--
  CrmZeus A2 — lista de artículos (catalogados y no catalogados), como «Artículos» /
  «No catalogados» de CRMZeus. Paginación en servidor (50 por página). La búsqueda cubre
  nombre (sin acentos) y clave. Un clic abre el formulario.
-->
<script>
import CrmArticles from 'dashboard/api/crmArticles';
import CrmCatalogs from 'dashboard/api/crmCatalogs';
import TableFooter from 'dashboard/components/widgets/TableFooter.vue';
import { formatMoney } from 'dashboard/helper/caseCommercial';

const TABS = ['catalogued', 'uncatalogued', 'all'];
const STATUS_BADGES = {
  active: 'bg-green-50 text-green-800 dark:bg-green-900/30 dark:text-green-300',
  inactive: 'bg-slate-100 text-slate-600 dark:bg-slate-700 dark:text-slate-300',
};
const WARNING_BADGE =
  'bg-amber-50 text-amber-800 dark:bg-amber-900/30 dark:text-amber-300';

export default {
  name: 'CrmZeusArticles',
  components: { TableFooter },
  data() {
    return {
      tabs: TABS,
      tab: 'catalogued',
      rows: [],
      meta: { count: 0, page: 1, per_page: 50, counts: {} },
      filters: { q: '', status: '', line_id: '' },
      lines: [],
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
    formatMoney,
    async fetchCatalogs() {
      try {
        const { data } = await CrmCatalogs.fetch();
        this.lines = data.article_lines;
        this.statuses = data.article_statuses;
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
        const { data } = await CrmArticles.list(params);
        this.rows = data.articles;
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
    openNew() {
      this.$router.push({
        name: 'crmzeus_article_new',
        query: this.tab === 'all' ? {} : { type: this.tab },
      });
    },
    open(row) {
      this.$router.push({
        name: 'crmzeus_article_edit',
        params: { articleId: row.id },
      });
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
      class="relative flex flex-col flex-shrink-0 gap-3 px-6 py-4 bg-white border-b dark:bg-slate-900 border-slate-50 dark:border-slate-800/50"
    >
      <div>
        <h1 class="m-0 text-xl font-bold text-slate-800 dark:text-slate-100">
          {{ $t('CRM_ZEUS.ARTICLES.TITLE') }}
        </h1>
        <p class="m-0 text-sm text-slate-500 dark:text-slate-400">
          {{ $t('CRM_ZEUS.ARTICLES.SUBTITLE') }}
        </p>
      </div>
      <div v-if="meta.can_edit" class="absolute right-6 top-4">
        <woot-button size="small" icon="add" @click="openNew">
          {{ $t('CRM_ZEUS.ARTICLES.NEW') }}
        </woot-button>
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
          {{ $t(`CRM_ZEUS.ARTICLES.TABS.${t.toUpperCase()}`) }}
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
            class="!mb-0 text-sm w-52"
            @change="onFilterChange"
          >
            <option value="">
              {{ $t('CRM_ZEUS.ARTICLES.ALL_STATUSES') }}
            </option>
            <option v-for="s in statuses" :key="s" :value="s">
              {{ $t(`CRM_ZEUS.ARTICLE_STATUS.${s.toUpperCase()}`) }}
            </option>
          </select>
          <select
            v-if="lines.length"
            v-model="filters.line_id"
            class="!mb-0 text-sm w-52"
            @change="onFilterChange"
          >
            <option value="">{{ $t('CRM_ZEUS.ARTICLES.ALL_LINES') }}</option>
            <option v-for="line in lines" :key="line.id" :value="line.id">
              {{ line.name }}
            </option>
          </select>
        </div>
        <input
          v-model="filters.q"
          type="search"
          class="!mb-0 text-sm"
          :placeholder="$t('CRM_ZEUS.ARTICLES.SEARCH')"
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
            <th class="w-12 px-3 py-2" />
            <th class="px-3 py-2">
              {{ $t('CRM_ZEUS.ARTICLES.COLUMNS.KEY') }}
            </th>
            <th class="px-3 py-2">
              {{ $t('CRM_ZEUS.ARTICLES.COLUMNS.NAME') }}
            </th>
            <th v-if="tab === 'all'" class="px-3 py-2">
              {{ $t('CRM_ZEUS.ARTICLES.COLUMNS.TYPE') }}
            </th>
            <th class="px-3 py-2">
              {{ $t('CRM_ZEUS.ARTICLES.COLUMNS.LINE') }}
            </th>
            <th class="px-3 py-2">
              {{ $t('CRM_ZEUS.ARTICLES.COLUMNS.UNIT') }}
            </th>
            <th class="px-3 py-2 text-right">
              {{ $t('CRM_ZEUS.ARTICLES.COLUMNS.PRICE') }}
            </th>
            <th class="px-3 py-2">
              {{ $t('CRM_ZEUS.ARTICLES.COLUMNS.STATUS') }}
            </th>
          </tr>
        </thead>
        <tbody>
          <tr
            v-for="row in rows"
            :key="row.id"
            class="border-t cursor-pointer border-slate-50 dark:border-slate-700 hover:bg-slate-25 dark:hover:bg-slate-700/50"
            @click="open(row)"
          >
            <td class="px-3 py-1.5">
              <img
                v-if="row.image_url"
                :src="row.image_url"
                :alt="row.name"
                class="object-cover w-8 h-8 rounded"
              />
              <span
                v-else
                class="flex items-center justify-center w-8 h-8 rounded bg-slate-50 dark:bg-slate-700"
              >
                <fluent-icon icon="tag" size="14" class="text-slate-400" />
              </span>
            </td>
            <td class="px-3 py-2 text-slate-500">{{ row.key || '—' }}</td>
            <td
              class="px-3 py-2 font-medium text-slate-800 dark:text-slate-100"
            >
              {{ row.name }}
              <span
                v-if="row.is_kit"
                class="ml-1 px-1.5 py-0.5 text-xs font-normal rounded bg-slate-50 dark:bg-slate-700 text-slate-600 dark:text-slate-300"
              >
                {{ $t('CRM_ZEUS.ARTICLES.KIT') }}
              </span>
            </td>
            <td v-if="tab === 'all'" class="px-3 py-2">
              {{
                $t(
                  `CRM_ZEUS.CATALOG_STATUS.${row.catalog_status.toUpperCase()}`
                )
              }}
            </td>
            <td class="px-3 py-2">{{ row.line ? row.line.name : '—' }}</td>
            <td class="px-3 py-2">{{ row.unit ? row.unit.name : '—' }}</td>
            <td class="px-3 py-2 text-right whitespace-nowrap">
              <template v-if="row.default_price">
                {{
                  formatMoney(
                    row.default_price.price,
                    row.default_price.currency
                  )
                }}
              </template>
              <template v-else>—</template>
            </td>
            <td class="px-3 py-2">
              <span
                class="px-2 py-0.5 text-xs rounded-full whitespace-nowrap"
                :class="statusBadge(row.status)"
              >
                {{ $t(`CRM_ZEUS.ARTICLE_STATUS.${row.status.toUpperCase()}`) }}
              </span>
            </td>
          </tr>
        </tbody>
      </table>
      <p
        v-else-if="!isFetching && !error"
        class="py-10 text-center text-slate-500"
      >
        {{ $t('CRM_ZEUS.ARTICLES.EMPTY') }}
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
