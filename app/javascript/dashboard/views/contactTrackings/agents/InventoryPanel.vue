<script>
// feat/agentes_ia_unificado — «RECURSOS», ahora en la lista de Agentes IA
// ============================================================================
// El catálogo del motor (cada directiva con su estado en la cuenta y los nombres
// exactos para copiar) y las frases de clientes. Antes era una pestaña del
// Asistente; vale para todos los agentes, así que vive en la lista.
// ============================================================================
import AssistantAPI from 'dashboard/api/assistant';
import EngineCatalog from '../assistant/EngineCatalog.vue';

export default {
  components: { EngineCatalog },
  data() {
    return { inventory: null, isLoading: false, error: '' };
  },
  computed: {
    catalog() {
      return (this.inventory && this.inventory.catalog) || [];
    },
    phrases() {
      return (this.inventory && this.inventory.customer_phrases) || [];
    },
  },
  mounted() {
    this.fetchInventory();
  },
  methods: {
    async fetchInventory() {
      this.isLoading = true;
      this.error = '';
      try {
        const { data } = await AssistantAPI.getInventory(null);
        this.inventory = data;
      } catch (error) {
        const status = error && error.response && error.response.status;
        this.error =
          status === 401
            ? this.$t('TRACKING_ASSISTANT_VIEW.ERROR_FORBIDDEN')
            : this.$t('TRACKING_ASSISTANT_VIEW.ERROR_GENERIC');
      } finally {
        this.isLoading = false;
      }
    },
  },
};
</script>

<template>
  <div class="flex-1 min-h-0 overflow-y-auto">
    <p class="mb-3 text-xs text-slate-500 dark:text-slate-400">
      {{ $t('TRACKING_ASSISTANT_VIEW.CATALOG_HINT') }}
    </p>
    <p v-if="error" class="mb-3 text-xs text-red-600 dark:text-red-400">
      {{ error }}
    </p>

    <EngineCatalog :catalog="catalog" />

    <section
      class="p-4 mt-4 bg-white border rounded-lg dark:bg-slate-800 border-slate-100 dark:border-slate-700"
    >
      <h3 class="mb-1 text-sm font-semibold text-slate-800 dark:text-slate-100">
        {{ $t('TRACKING_ASSISTANT_VIEW.PHRASES_TITLE') }}
      </h3>
      <p class="mb-3 text-xs text-slate-500 dark:text-slate-400">
        {{ $t('TRACKING_ASSISTANT_VIEW.PHRASES_HINT') }}
      </p>
      <ul class="grid gap-1 md:grid-cols-2">
        <li
          v-for="phrase in phrases"
          :key="phrase"
          class="text-xs text-slate-600 dark:text-slate-400"
        >
          · {{ phrase }}
        </li>
        <li
          v-if="!phrases.length"
          class="text-xs text-slate-400 dark:text-slate-500"
        >
          {{ $t('TRACKING_ASSISTANT_VIEW.PHRASES_EMPTY') }}
        </li>
      </ul>
    </section>
  </div>
</template>
