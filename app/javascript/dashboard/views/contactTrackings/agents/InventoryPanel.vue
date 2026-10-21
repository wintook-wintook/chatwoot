<script>
// feat/agentes_ia_unificado — «RECURSOS», ahora en la lista de Agentes IA
// ============================================================================
// El catálogo del motor (cada directiva con su estado en la cuenta y los nombres
// exactos para copiar) y las frases de clientes. Antes era una pestaña del
// Asistente; vale para todos los agentes, así que vive en la lista. Textos con los
// tamaños de las pantallas nativas (fase A del ajuste visual).
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
  <div class="overflow-y-auto text-slate-700 dark:text-slate-300">
    <p class="mb-4 text-base text-slate-600 dark:text-slate-300">
      {{ $t('TRACKING_ASSISTANT_VIEW.CATALOG_HINT') }}
    </p>
    <woot-loading-state
      v-if="isLoading && !inventory"
      :message="$t('TRACKING_TEMPLATES.RESOURCES_LOADING')"
    />
    <p v-if="error" class="mb-4 text-sm text-red-600 dark:text-red-400">
      {{ error }}
    </p>

    <EngineCatalog :catalog="catalog" />

    <section class="pt-6 mt-6 border-t border-slate-50 dark:border-slate-800">
      <h3
        class="mb-1 text-lg font-semibold font-interDisplay text-slate-900 dark:text-slate-25"
      >
        {{ $t('TRACKING_ASSISTANT_VIEW.PHRASES_TITLE') }}
      </h3>
      <p class="mb-4 text-base text-slate-600 dark:text-slate-300">
        {{ $t('TRACKING_ASSISTANT_VIEW.PHRASES_HINT') }}
      </p>
      <ul class="grid gap-1 md:grid-cols-2">
        <li v-for="phrase in phrases" :key="phrase" class="text-sm">
          · {{ phrase }}
        </li>
        <li
          v-if="!phrases.length"
          class="text-sm text-slate-500 dark:text-slate-400"
        >
          {{ $t('TRACKING_ASSISTANT_VIEW.PHRASES_EMPTY') }}
        </li>
      </ul>
    </section>
  </div>
</template>
