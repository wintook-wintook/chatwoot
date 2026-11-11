<!--
  CrmZeus A3 — buscador de artículos para los componentes de un kit: se teclea nombre o
  clave y se elige. No ofrece kits (un kit no va dentro de otro) ni los ids de `excludeIds`
  (el propio kit y los que ya están). Emite `pick` con el artículo de la lista.
  Q2: también lo usa la partida de una cotización (con su propio `placeholder`).
  Q3: con `allowKits` también ofrece kits (la partida de una cotización sí puede ser un kit).
-->
<script>
import CrmArticles from 'dashboard/api/crmArticles';

export default {
  name: 'CrmArticlePicker',
  props: {
    excludeIds: { type: Array, default: () => [] },
    placeholder: { type: String, default: '' },
    allowKits: { type: Boolean, default: false },
  },
  data() {
    return {
      query: '',
      results: [],
      open: false,
      searching: false,
      debounce: null,
    };
  },
  computed: {
    options() {
      return this.results.filter(
        article =>
          (this.allowKits || !article.is_kit) &&
          !this.excludeIds.includes(article.id)
      );
    },
  },
  beforeDestroy() {
    clearTimeout(this.debounce);
  },
  methods: {
    onInput() {
      this.open = true;
      clearTimeout(this.debounce);
      this.debounce = setTimeout(this.search, 300);
    },
    async search() {
      if (!this.query.trim()) {
        this.results = [];
        return;
      }
      this.searching = true;
      try {
        const { data } = await CrmArticles.list({ q: this.query });
        this.results = data.articles;
      } finally {
        this.searching = false;
      }
    },
    pick(article) {
      this.$emit('pick', article);
      this.query = '';
      this.results = [];
      this.open = false;
    },
    close() {
      // Deja tiempo al clic de un resultado antes de cerrar la lista.
      setTimeout(() => {
        this.open = false;
      }, 200);
    },
  },
};
</script>

<template>
  <div class="relative">
    <input
      v-model="query"
      type="search"
      class="block w-full h-10 p-2 !mb-0 text-base box-border rounded-md bg-white dark:bg-slate-900 text-slate-900 dark:text-slate-100 border border-solid border-slate-200 dark:border-slate-600 focus:border-woot-500 dark:focus:border-woot-600"
      :placeholder="placeholder || $t('CRM_ZEUS.ARTICLE_FORM.COMPONENT_SEARCH')"
      @input="onInput"
      @focus="open = true"
      @blur="close"
    />
    <ul
      v-if="open && query.trim()"
      class="absolute z-20 w-full p-1 mt-1 overflow-auto bg-white border rounded-md shadow-lg max-h-60 dark:bg-slate-800 border-slate-100 dark:border-slate-700"
    >
      <li
        v-for="article in options"
        :key="article.id"
        class="flex items-center gap-2 px-3 py-1.5 text-sm rounded cursor-pointer hover:bg-slate-50 dark:hover:bg-slate-700"
        @mousedown.prevent="pick(article)"
      >
        <span v-if="article.key" class="text-slate-500">{{ article.key }}</span>
        <span class="flex-1 text-slate-800 dark:text-slate-100">
          {{ article.name }}
        </span>
        <span
          v-if="article.is_kit"
          class="px-1.5 py-0.5 text-xs rounded bg-slate-50 dark:bg-slate-700 text-slate-600 dark:text-slate-300"
        >
          {{ $t('CRM_ZEUS.ARTICLES.KIT') }}
        </span>
        <span class="text-xs text-slate-500">
          {{
            $t(
              `CRM_ZEUS.CATALOG_STATUS.${article.catalog_status.toUpperCase()}`
            )
          }}
        </span>
      </li>
      <li
        v-if="!searching && !options.length"
        class="px-3 py-1.5 text-sm text-slate-500"
      >
        {{ $t('CRM_ZEUS.ARTICLE_FORM.COMPONENT_NONE') }}
      </li>
    </ul>
  </div>
</template>
