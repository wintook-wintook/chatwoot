<!--
  Plan-Catalogo-Cotizaciones — buscador del catálogo para las partidas de una
  cotización y los materiales de una orden. Escribes «capac…» y sale
  «Capacitor 35µF · $180». Emite `select(item)`; con `allowFree`, también
  `free(texto)` para usar algo que no está en el catálogo.
-->
<script>
import CatalogItemsAPI from 'dashboard/api/catalogItems';
import { formatMoney } from 'dashboard/helper/caseCommercial';

export default {
  name: 'CatalogPicker',
  props: {
    allowFree: { type: Boolean, default: true },
    placeholder: { type: String, default: '' },
  },
  emits: ['select', 'free'],
  data() {
    return { query: '', results: [], open: false, loading: false, timer: null };
  },
  methods: {
    onInput() {
      clearTimeout(this.timer);
      this.open = true;
      this.timer = setTimeout(this.search, 250);
    },
    async search() {
      const term = this.query.trim();
      if (!term) {
        this.results = [];
        return;
      }
      this.loading = true;
      try {
        const { data } = await CatalogItemsAPI.search({ q: term });
        this.results = data.catalog_items || [];
      } catch {
        this.results = [];
      } finally {
        this.loading = false;
      }
    },
    price(item) {
      return formatMoney(item.price, item.currency);
    },
    choose(item) {
      this.$emit('select', item);
      this.reset();
    },
    useFree() {
      if (!this.query.trim()) return;
      this.$emit('free', this.query.trim());
      this.reset();
    },
    reset() {
      this.query = '';
      this.results = [];
      this.open = false;
    },
  },
};
</script>

<template>
  <div v-on-clickaway="() => (open = false)" class="relative w-full">
    <input
      v-model="query"
      type="text"
      class="!mb-0"
      :placeholder="placeholder || $t('CATALOG.PICKER.PLACEHOLDER')"
      @input="onInput"
      @focus="open = !!query"
      @keydown.enter.prevent="results.length ? choose(results[0]) : useFree()"
    />
    <ul
      v-if="open && query"
      class="absolute z-50 w-full p-1 m-0 mt-1 overflow-y-auto list-none bg-white border rounded-md shadow-xl max-h-64 dark:bg-slate-800 border-slate-50 dark:border-slate-700"
    >
      <li v-for="item in results" :key="item.id">
        <button
          type="button"
          class="flex items-center w-full gap-2 px-3 py-2 text-sm text-left rounded-md hover:bg-slate-50 dark:hover:bg-slate-700"
          @click="choose(item)"
        >
          <span
            class="flex-1 min-w-0 truncate text-slate-800 dark:text-slate-100"
          >
            {{ item.name }}
            <small v-if="item.sku" class="text-xs text-slate-500">
              · {{ item.sku }}
            </small>
          </span>
          <span class="text-xs text-slate-500 dark:text-slate-400">
            {{ $t(`CATALOG.KINDS.${item.kind}`) }}
          </span>
          <span
            class="font-medium whitespace-nowrap text-slate-700 dark:text-slate-200"
          >
            {{ price(item) }}
          </span>
        </button>
      </li>
      <li
        v-if="!loading && !results.length"
        class="px-3 py-2 text-sm text-slate-500"
      >
        {{ $t('CATALOG.PICKER.EMPTY') }}
      </li>
      <li v-if="allowFree">
        <button
          type="button"
          class="w-full px-3 py-2 text-sm text-left rounded-md text-woot-600 hover:bg-slate-50 dark:hover:bg-slate-700"
          @click="useFree"
        >
          {{ $t('CATALOG.PICKER.FREE', { text: query }) }}
        </button>
      </li>
    </ul>
  </div>
</template>
