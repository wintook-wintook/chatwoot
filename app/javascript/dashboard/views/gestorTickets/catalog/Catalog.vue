<!--
  Plan-Catalogo-Cotizaciones C1 — Ventas › Catálogo de productos y servicios.
  Un solo catálogo para las cotizaciones (Ventas) y los materiales de las
  órdenes (Servicio). Lo edita Ventas con «Todo»; el resto solo lo consulta.
  El costo solo se muestra con «Ver montos». No se borra: se desactiva.
-->
<script>
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import CatalogItemsAPI from 'dashboard/api/catalogItems';
import Spinner from 'shared/components/Spinner.vue';
import CatalogItemForm from './CatalogItemForm.vue';
import { formatMoney } from 'dashboard/helper/caseCommercial';
import { canDo, getUserAccess } from 'dashboard/helper/accessHelper';

const KINDS = ['service', 'product', 'part'];

export default {
  name: 'CatalogView',
  components: { Spinner, CatalogItemForm },
  data() {
    return {
      items: [],
      count: 0,
      page: 1,
      perPage: 50,
      canEdit: false,
      loading: true,
      categories: [],
      filters: { q: '', kind: '', category: '', active: 'true' },
      showForm: false,
      editing: null,
      timer: null,
    };
  },
  computed: {
    ...mapGetters({
      caseSettings: 'caseTickets/getCaseSettings',
      currentUser: 'getCurrentUser',
    }),
    kinds() {
      return KINDS;
    },
    showCost() {
      return canDo(
        getUserAccess(this.currentUser, this.$route.params.accountId),
        'see_amounts'
      );
    },
    defaultCurrency() {
      return (this.caseSettings && this.caseSettings.default_currency) || 'MXN';
    },
    pages() {
      return Math.max(1, Math.ceil(this.count / this.perPage));
    },
  },
  watch: {
    'filters.kind': 'reload',
    'filters.category': 'reload',
    'filters.active': 'reload',
  },
  mounted() {
    this.$store.dispatch('caseTickets/fetchSettings');
    this.fetch();
    this.fetchCategories();
  },
  methods: {
    reload() {
      this.page = 1;
      this.fetch();
    },
    onSearch() {
      clearTimeout(this.timer);
      this.timer = setTimeout(this.reload, 300);
    },
    async fetch() {
      this.loading = true;
      try {
        const { data } = await CatalogItemsAPI.search({
          ...this.filters,
          page: this.page,
        });
        this.items = data.catalog_items || [];
        this.count = data.meta.count;
        this.perPage = data.meta.per_page;
        this.canEdit = data.meta.can_edit;
      } catch {
        this.items = [];
      } finally {
        this.loading = false;
      }
    },
    async fetchCategories() {
      try {
        const { data } = await CatalogItemsAPI.categories();
        this.categories = data.categories || [];
      } catch {
        this.categories = [];
      }
    },
    money(value, currency) {
      return value === null || value === undefined
        ? '—'
        : formatMoney(value, currency);
    },
    openNew() {
      this.editing = null;
      this.showForm = true;
    },
    openEdit(item) {
      if (!this.canEdit) return;
      this.editing = item;
      this.showForm = true;
    },
    onSaved() {
      this.showForm = false;
      this.fetch();
      this.fetchCategories();
    },
    goTo(page) {
      this.page = page;
      this.fetch();
    },
    async exportCsv() {
      const { data } = await CatalogItemsAPI.exportCsv();
      const url = URL.createObjectURL(data);
      const link = document.createElement('a');
      link.href = url;
      link.download = 'catalogo.csv';
      link.click();
      URL.revokeObjectURL(url);
    },
    async importCsv(event) {
      const [file] = event.target.files || [];
      event.target.value = '';
      if (!file) return;
      try {
        const { data } = await CatalogItemsAPI.importCsv(file);
        useAlert(
          this.$t('CATALOG.IMPORT_DONE', {
            created: data.created,
            updated: data.updated,
          })
        );
        if (data.errors && data.errors.length) {
          const [first] = data.errors;
          useAlert(
            this.$t('CATALOG.IMPORT_ERRORS', {
              count: data.errors.length,
              line: first.line,
              error: first.error,
            })
          );
        }
        this.reload();
        this.fetchCategories();
      } catch (error) {
        useAlert(error?.response?.data?.error || this.$t('CATALOG.ERROR'));
      }
    },
  },
};
</script>

<template>
  <div
    class="flex flex-col flex-1 w-full h-full overflow-hidden bg-white dark:bg-slate-900"
  >
    <header
      class="flex flex-wrap items-start justify-between gap-3 px-6 pt-5 pb-3"
    >
      <div>
        <h1 class="m-0 text-xl font-bold text-slate-800 dark:text-slate-100">
          {{ $t('CATALOG.TITLE') }}
        </h1>
        <p class="m-0 text-sm text-slate-600 dark:text-slate-300">
          {{ $t('CATALOG.DESCRIPTION') }}
        </p>
      </div>
      <div class="flex items-center gap-2">
        <label
          v-if="canEdit"
          v-tooltip="$t('CATALOG.IMPORT_HELP')"
          class="mb-0 cursor-pointer button smooth secondary small"
        >
          {{ $t('CATALOG.IMPORT') }}
          <input
            type="file"
            accept=".csv,text/csv"
            class="hidden"
            @change="importCsv"
          />
        </label>
        <woot-button
          variant="smooth"
          color-scheme="secondary"
          size="small"
          icon="arrow-download"
          @click="exportCsv"
        >
          {{ $t('CATALOG.EXPORT') }}
        </woot-button>
        <woot-button v-if="canEdit" size="small" icon="add" @click="openNew">
          {{ $t('CATALOG.NEW') }}
        </woot-button>
      </div>
    </header>

    <div class="flex flex-wrap items-center gap-2 px-6 pb-3">
      <input
        v-model="filters.q"
        type="search"
        class="!mb-0 max-w-xs"
        :placeholder="$t('CATALOG.SEARCH')"
        @input="onSearch"
      />
      <select v-model="filters.kind" class="!mb-0 w-44">
        <option value="">{{ $t('CATALOG.ALL_KINDS') }}</option>
        <option v-for="kind in kinds" :key="kind" :value="kind">
          {{ $t(`CATALOG.KINDS.${kind}`) }}
        </option>
      </select>
      <select v-model="filters.category" class="!mb-0 w-48">
        <option value="">{{ $t('CATALOG.ALL_CATEGORIES') }}</option>
        <option
          v-for="category in categories"
          :key="category"
          :value="category"
        >
          {{ category }}
        </option>
      </select>
      <select v-model="filters.active" class="!mb-0 w-36">
        <option v-for="key in ['true', 'false', 'all']" :key="key" :value="key">
          {{ $t(`CATALOG.ACTIVE.${key}`) }}
        </option>
      </select>
    </div>

    <div class="flex-1 px-6 pb-4 overflow-auto">
      <Spinner v-if="loading" />
      <p
        v-else-if="!items.length"
        class="py-12 text-sm text-center text-slate-500 dark:text-slate-400"
      >
        {{ $t('CATALOG.EMPTY') }}
      </p>
      <table v-else class="w-full text-sm">
        <thead>
          <tr
            class="text-left border-b text-slate-500 dark:text-slate-400 border-slate-50 dark:border-slate-800"
          >
            <th class="px-3 py-2 font-medium">
              {{ $t('CATALOG.COLUMNS.SKU') }}
            </th>
            <th class="px-3 py-2 font-medium">
              {{ $t('CATALOG.COLUMNS.NAME') }}
            </th>
            <th class="px-3 py-2 font-medium">
              {{ $t('CATALOG.COLUMNS.KIND') }}
            </th>
            <th class="px-3 py-2 font-medium">
              {{ $t('CATALOG.COLUMNS.CATEGORY') }}
            </th>
            <th class="px-3 py-2 font-medium">
              {{ $t('CATALOG.COLUMNS.UNIT') }}
            </th>
            <th class="px-3 py-2 font-medium text-right">
              {{ $t('CATALOG.COLUMNS.PRICE') }}
            </th>
            <th v-if="showCost" class="px-3 py-2 font-medium text-right">
              {{ $t('CATALOG.COLUMNS.COST') }}
            </th>
            <th class="px-3 py-2 font-medium">
              {{ $t('CATALOG.COLUMNS.ACTIVE') }}
            </th>
          </tr>
        </thead>
        <tbody class="divide-y divide-slate-50 dark:divide-slate-800">
          <tr
            v-for="item in items"
            :key="item.id"
            :class="{
              'cursor-pointer hover:bg-slate-25 dark:hover:bg-slate-800':
                canEdit,
              'opacity-60': !item.active,
            }"
            @click="openEdit(item)"
          >
            <td class="px-3 py-2 font-mono whitespace-nowrap">
              {{ item.sku || '—' }}
            </td>
            <td class="px-3 py-2 text-slate-800 dark:text-slate-100">
              {{ item.name }}
            </td>
            <td class="px-3 py-2 whitespace-nowrap">
              {{ $t(`CATALOG.KINDS.${item.kind}`) }}
            </td>
            <td class="px-3 py-2">{{ item.category || '—' }}</td>
            <td class="px-3 py-2">{{ item.unit || '—' }}</td>
            <td class="px-3 py-2 text-right whitespace-nowrap">
              {{ money(item.price, item.currency) }}
            </td>
            <td v-if="showCost" class="px-3 py-2 text-right whitespace-nowrap">
              {{ money(item.cost, item.currency) }}
            </td>
            <td class="px-3 py-2">
              <fluent-icon
                v-if="item.active"
                icon="checkmark"
                size="16"
                class="text-green-600"
              />
            </td>
          </tr>
        </tbody>
      </table>
      <div
        v-if="pages > 1"
        class="flex items-center justify-end gap-2 pt-3 text-sm"
      >
        <woot-button
          size="tiny"
          variant="clear"
          :disabled="page <= 1"
          icon="chevron-left"
          @click="goTo(page - 1)"
        />
        <span>{{ page }} / {{ pages }}</span>
        <woot-button
          size="tiny"
          variant="clear"
          :disabled="page >= pages"
          icon="chevron-right"
          @click="goTo(page + 1)"
        />
      </div>
    </div>

    <CatalogItemForm
      :show="showForm"
      :item="editing"
      :categories="categories"
      :default-currency="defaultCurrency"
      :show-cost="showCost"
      @close="showForm = false"
      @saved="onSaved"
    />
  </div>
</template>
