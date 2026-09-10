<script>
// ============================================================================
// @knowledge_sources — ELEGIR QUÉ SABE EL AGENTE
// ============================================================================
// El paso 2 del modelo: conectar no es indexar. Acá se decide qué entra.
//
// DE A DOS NIVELES, Y ESE ORDEN ES EL DISEÑO:
//   arriba la CATEGORÍA, que es la regla y cubre el 95% con dos clics;
//   abajo la LISTA, que es para las excepciones.
// Al revés serían mil casillas que nadie revisa — y un sitio real tiene 1.106
// entradas, así que eso no es una hipótesis.
//
// CADA TIPO SE FILTRA DISTINTO, Y TRATARLOS IGUAL ERA UN FALLO SILENCIOSO:
//   entradas   por categoría del blog
//   páginas    NO tienen categorías: solo la lista. WordPress ignora el filtro y
//              devuelve todas, así que ofrecerlo hacía creer que se acotó algo.
//   productos  por categoría de la TIENDA, que es otra taxonomía con otros ids
//
// LA EXCEPCIÓN GANA SOBRE LA REGLA:
//   Una entrada desmarcada a mano queda desmarcada aunque su categoría esté
//   elegida. Si no, deseleccionar no serviría de nada: la próxima sincronización
//   la traería de vuelta y nadie entendería por qué.
//
// LO QUE SE GUARDA SON DECISIONES, NO CONTENIDO:
//   categories (la regla), excluded_ids y included_ids (las excepciones). El
//   catálogo de títulos se vuelve a pedir cada vez —son 3 segundos— porque
//   guardarlo obligaría a mantenerlo sincronizado con el sitio.
// ============================================================================
import KnowledgeBaseAPI from './api';
import Spinner from 'shared/components/Spinner.vue';

// Medido sobre un sitio real: 2,07 chunks por entrada, 8 ms por chunk en lotes.
const CHUNKS_POR_ENTRADA = 2.07;
const MS_POR_CHUNK = 8;

// Explícitas y no armadas por concatenación: una clave dinámica no la puede
// verificar nadie —ni un linter ni quien traduce— y el día que el backend soporte
// un tipo nuevo, la etiqueta sale en blanco sin que falle nada.
const TYPE_LABEL = {
  posts: 'KNOWLEDGE_SOURCES.WORDPRESS.TYPE_POSTS',
  pages: 'KNOWLEDGE_SOURCES.WORDPRESS.TYPE_PAGES',
  products: 'KNOWLEDGE_SOURCES.WORDPRESS.TYPE_PRODUCTS',
};

export default {
  components: { Spinner },
  props: {
    show: { type: Boolean, default: false },
    source: { type: Object, default: null },
  },
  emits: ['close', 'save'],
  data() {
    return {
      contentTypes: [],
      categories: [],
      productCategories: [],
      excludedIds: [],
      includedIds: [],
      catalog: [],
      isLoading: false,
      error: '',
      search: '',
      onlySelected: false,
      activeType: 'posts',
    };
  },
  computed: {
    probe() {
      return this.source?.config?.probe || {};
    },
    availableTypes() {
      const counts = this.probe.counts || {};
      return ['posts', 'pages', 'products']
        .filter(type => counts[type])
        .map(type => ({ type, count: counts[type] }));
    },
    // Las del blog filtran entradas; las de la tienda, productos. Se ofrecen solo
    // si el tipo correspondiente está elegido: un filtro que no aplica a nada
    // confunde más de lo que ayuda.
    availableCategories() {
      return this.probe.categories || [];
    },
    availableProductCategories() {
      return this.probe.product_categories || [];
    },
    showBlogCategories() {
      return (
        this.contentTypes.includes('posts') &&
        this.availableCategories.length > 0
      );
    },
    showProductCategories() {
      return (
        this.contentTypes.includes('products') &&
        this.availableProductCategories.length > 0
      );
    },
    // La resolución tiene que dar lo mismo que Wordpress::Selection en el backend:
    // si divergieran, la pantalla prometería algo distinto de lo que se indexa.
    isSelected() {
      const excluded = new Set(this.excludedIds);
      const included = new Set(this.includedIds);
      // La taxonomía depende del tipo que se está viendo. Las páginas no tienen,
      // así que para ellas la regla es "todas" y solo mandan las excepciones.
      const cats = new Set(
        this.activeType === 'products'
          ? this.productCategories
          : this.categories
      );
      const filterable = this.activeType !== 'pages';

      return item => {
        if (excluded.has(item.id)) return false;
        if (included.has(item.id)) return true;
        if (!filterable || !cats.size) return true;
        return (item.category_ids || []).some(id => cats.has(id));
      };
    },
    visibleCatalog() {
      const needle = this.search.trim().toLowerCase();
      return this.catalog.filter(item => {
        if (this.onlySelected && !this.isSelected(item)) return false;
        if (!needle) return true;
        return (item.title || '').toLowerCase().includes(needle);
      });
    },
    selectedCount() {
      return this.catalog.filter(this.isSelected).length;
    },
    // Que alguien vea "2 segundos" o "4 minutos" antes de apretar es la diferencia
    // entre esperar y creer que se colgó.
    estimate() {
      const chunks = Math.round(this.selectedCount * CHUNKS_POR_ENTRADA);
      const seconds = Math.max(1, Math.round((chunks * MS_POR_CHUNK) / 1000));
      return { chunks, seconds };
    },
    canSave() {
      return this.contentTypes.length > 0 && !this.isLoading;
    },
  },
  watch: {
    show(value) {
      if (value) this.load();
    },
    activeType() {
      this.fetchCatalog();
    },
  },
  methods: {
    load() {
      const config = this.source?.config || {};
      this.contentTypes = [...(config.content_types || ['posts'])];
      this.categories = [...(config.categories || [])];
      this.productCategories = [...(config.product_categories || [])];
      this.excludedIds = [...(config.excluded_ids || [])];
      this.includedIds = [...(config.included_ids || [])];
      this.activeType = this.contentTypes[0] || 'posts';
      this.search = '';
      this.onlySelected = false;
      this.fetchCatalog();
    },
    async fetchCatalog() {
      if (!this.source) return;
      this.isLoading = true;
      this.error = '';
      try {
        const { data } = await KnowledgeBaseAPI.getWordpressCatalog(
          this.source.account_id,
          this.source.id,
          this.activeType
        );
        this.catalog = data;
      } catch (error) {
        this.error = this.$t('KNOWLEDGE_SOURCES.WORDPRESS.CATALOG_ERROR');
        this.catalog = [];
      } finally {
        this.isLoading = false;
      }
    },
    typeLabel(type) {
      return TYPE_LABEL[type];
    },
    toggleType(type) {
      const index = this.contentTypes.indexOf(type);
      if (index >= 0) this.contentTypes.splice(index, 1);
      else this.contentTypes.push(type);
    },
    toggleCategory(id) {
      const index = this.categories.indexOf(id);
      if (index >= 0) this.categories.splice(index, 1);
      else this.categories.push(id);
    },
    toggleProductCategory(id) {
      const index = this.productCategories.indexOf(id);
      if (index >= 0) this.productCategories.splice(index, 1);
      else this.productCategories.push(id);
    },
    // Marcar y desmarcar se guardan como EXCEPCIONES, no como una lista completa:
    // así una entrada que se publique mañana en una categoría elegida entra sola.
    toggleItem(item) {
      const wasSelected = this.isSelected(item);
      this.excludedIds = this.excludedIds.filter(id => id !== item.id);
      this.includedIds = this.includedIds.filter(id => id !== item.id);

      if (wasSelected) this.excludedIds.push(item.id);
      else this.includedIds.push(item.id);
    },
    submit() {
      if (!this.canSave) return;
      this.$emit('save', {
        content_types: this.contentTypes,
        categories: this.categories,
        product_categories: this.productCategories,
        excluded_ids: this.excludedIds,
        included_ids: this.includedIds,
      });
    },
  },
};
</script>

<template>
  <woot-modal :show="show" size="medium" :on-close="() => $emit('close')">
    <div class="p-8 flex flex-col max-h-[80vh]">
      <h2 class="text-lg font-medium text-slate-800 dark:text-slate-100">
        {{ $t('KNOWLEDGE_SOURCES.WORDPRESS.PICKER_TITLE') }}
      </h2>
      <p class="text-xs text-slate-500 dark:text-slate-400 mt-1 mb-4">
        {{ $t('KNOWLEDGE_SOURCES.WORDPRESS.PICKER_HINT') }}
      </p>

      <!-- Qué tipo de contenido. Solo se ofrecen los que el sitio tiene. -->
      <div class="mb-4">
        <h3
          class="text-sm font-semibold text-slate-800 dark:text-slate-100 mb-2"
        >
          {{ $t('KNOWLEDGE_SOURCES.WORDPRESS.TYPES') }}
        </h3>
        <div class="flex flex-wrap gap-3">
          <label
            v-for="entry in availableTypes"
            :key="entry.type"
            class="flex items-center gap-2 text-sm"
          >
            <input
              type="checkbox"
              :checked="contentTypes.includes(entry.type)"
              @change="toggleType(entry.type)"
            />
            {{ $t(typeLabel(entry.type)) }}
            <span class="text-slate-400">({{ entry.count }})</span>
          </label>
          <span
            v-if="!availableTypes.length"
            class="text-xs text-slate-500 dark:text-slate-400"
          >
            {{ $t('KNOWLEDGE_SOURCES.WORDPRESS.NO_TYPES') }}
          </span>
        </div>
      </div>

      <!-- Categorías del BLOG: filtran entradas. Solo si hay entradas elegidas. -->
      <div v-if="showBlogCategories" class="mb-4">
        <h3
          class="text-sm font-semibold text-slate-800 dark:text-slate-100 mb-1"
        >
          {{ $t('KNOWLEDGE_SOURCES.WORDPRESS.CATEGORIES') }}
        </h3>
        <p class="text-xs text-slate-500 dark:text-slate-400 mb-2">
          {{ $t('KNOWLEDGE_SOURCES.WORDPRESS.CATEGORIES_HINT') }}
        </p>
        <div class="flex flex-wrap gap-3 max-h-24 overflow-y-auto">
          <label
            v-for="category in availableCategories"
            :key="category.id"
            class="flex items-center gap-2 text-sm"
          >
            <input
              type="checkbox"
              :checked="categories.includes(category.id)"
              @change="toggleCategory(category.id)"
            />
            {{ category.name }}
            <span class="text-slate-400">({{ category.count }})</span>
          </label>
        </div>
      </div>

      <!-- Categorías de la TIENDA: otra taxonomía, otros ids. Filtran productos. -->
      <div v-if="showProductCategories" class="mb-4">
        <h3
          class="text-sm font-semibold text-slate-800 dark:text-slate-100 mb-1"
        >
          {{ $t('KNOWLEDGE_SOURCES.WORDPRESS.PRODUCT_CATEGORIES') }}
        </h3>
        <div class="flex flex-wrap gap-3 max-h-24 overflow-y-auto">
          <label
            v-for="category in availableProductCategories"
            :key="category.id"
            class="flex items-center gap-2 text-sm"
          >
            <input
              type="checkbox"
              :checked="productCategories.includes(category.id)"
              @change="toggleProductCategory(category.id)"
            />
            {{ category.name }}
            <span class="text-slate-400">({{ category.count }})</span>
          </label>
        </div>
      </div>

      <!-- Las páginas no tienen categorías. Decirlo evita que alguien busque un
           filtro que no existe. -->
      <p
        v-if="activeType === 'pages'"
        class="text-xs text-slate-500 dark:text-slate-400 mb-3"
      >
        {{ $t('KNOWLEDGE_SOURCES.WORDPRESS.PAGES_NO_CATEGORIES') }}
      </p>

      <!-- La lista: para las excepciones. Con buscador y filtro, porque un sitio
           real tiene más de mil entradas. -->
      <!-- Qué tipo se está listando abajo: cada uno tiene su propia lista y su
           propio filtro, así que se ven de a uno. -->
      <div v-if="contentTypes.length > 1" class="flex items-center gap-3 mb-2">
        <label
          v-for="type in contentTypes"
          :key="type"
          class="flex items-center gap-1 text-xs"
        >
          <input v-model="activeType" type="radio" :value="type" />
          {{ $t(typeLabel(type)) }}
        </label>
      </div>

      <div class="flex items-center gap-3 mb-2">
        <input
          v-model="search"
          type="text"
          class="flex-1 !mb-0"
          :placeholder="$t('KNOWLEDGE_SOURCES.WORDPRESS.SEARCH')"
        />
        <label class="flex items-center gap-2 text-xs whitespace-nowrap">
          <input v-model="onlySelected" type="checkbox" />
          {{ $t('KNOWLEDGE_SOURCES.WORDPRESS.ONLY_SELECTED') }}
        </label>
      </div>

      <div
        class="flex-1 min-h-[12rem] overflow-y-auto border border-slate-100 dark:border-slate-700 rounded"
      >
        <div v-if="isLoading" class="flex items-center justify-center py-8">
          <Spinner size="" />
        </div>
        <p v-else-if="error" class="text-xs text-red-600 dark:text-red-400 p-3">
          {{ error }}
        </p>
        <ul v-else>
          <li
            v-for="item in visibleCatalog"
            :key="item.id"
            class="flex items-center gap-2 px-3 py-1.5 text-sm border-b border-slate-50 dark:border-slate-800"
          >
            <input
              type="checkbox"
              :checked="isSelected(item)"
              @change="toggleItem(item)"
            />
            <span class="flex-1 truncate text-slate-700 dark:text-slate-200">
              {{ item.title }}
            </span>
            <span v-if="item.date" class="text-xs text-slate-400 shrink-0">
              {{ item.date.slice(0, 10) }}
            </span>
          </li>
          <li
            v-if="!visibleCatalog.length"
            class="px-3 py-4 text-xs text-slate-500 dark:text-slate-400"
          >
            {{ $t('KNOWLEDGE_SOURCES.WORDPRESS.NO_RESULTS') }}
          </li>
        </ul>
      </div>

      <p class="text-xs text-slate-600 dark:text-slate-400 mt-3">
        {{
          $t('KNOWLEDGE_SOURCES.WORDPRESS.ESTIMATE', {
            selected: selectedCount,
            total: catalog.length,
            chunks: estimate.chunks,
            seconds: estimate.seconds,
          })
        }}
      </p>

      <div class="flex justify-end gap-2 mt-4">
        <woot-button variant="clear" @click="$emit('close')">
          {{ $t('KNOWLEDGE_SOURCES.WORDPRESS.CANCEL') }}
        </woot-button>
        <woot-button :is-disabled="!canSave" @click="submit">
          {{ $t('KNOWLEDGE_SOURCES.WORDPRESS.INDEX_SELECTED') }}
        </woot-button>
      </div>
    </div>
  </woot-modal>
</template>
