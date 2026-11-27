<script>
// proyecto@crear_agente_conversando — F4: EL MENÚ «EXPORTAR»
// ============================================================================
// Plan: docs/creacion_conversacional_agentes_plan.md §8. Dos archivos en un solo menú:
//   - Instrucciones del agente: para pegar en ChatGPT, Claude u otra IA. Lo arma el
//     backend (AgentExport) con los datos fijos sustituidos como en el motor; aquí
//     solo se pide (evento `instructions`).
//   - Recursos del motor: lo mismo que se descarga en la pestaña Recursos.
// ============================================================================
import WootDropdownMenu from 'shared/components/ui/dropdown/DropdownMenu.vue';
import WootDropdownItem from 'shared/components/ui/dropdown/DropdownItem.vue';
import { downloadEngineCatalog } from './engineCatalogMarkdown';

export default {
  components: { WootDropdownMenu, WootDropdownItem },
  props: {
    // El catálogo del motor (inventory.catalog).
    catalog: { type: Array, default: () => [] },
    // Si hay algo del agente que exportar (Entrenamiento, instrucciones o pestañas).
    hasAgent: { type: Boolean, default: false },
    busy: { type: Boolean, default: false },
  },
  emits: ['instructions'],
  data() {
    return { open: false };
  },
  methods: {
    close() {
      this.open = false;
    },
    instructions() {
      this.close();
      this.$emit('instructions');
    },
    resources() {
      this.close();
      const cuenta = this.$store.getters['accounts/getAccount'](
        this.$store.getters.getCurrentAccountId
      );
      downloadEngineCatalog(this.catalog, this.$t.bind(this), {
        accountName: (cuenta && cuenta.name) || '',
        locale: this.$i18n.locale,
      });
    },
  },
};
</script>

<template>
  <div class="relative">
    <woot-button
      variant="clear"
      size="tiny"
      color-scheme="secondary"
      icon="arrow-download"
      :is-loading="busy"
      :title="$t('TRACKING_ASSISTANT_VIEW.EXPORT_HINT')"
      @click="open = !open"
    >
      {{ $t('TRACKING_ASSISTANT_VIEW.EXPORT') }}
    </woot-button>
    <div
      v-if="open"
      v-on-clickaway="close"
      class="absolute right-0 z-30 p-1 mt-1 bg-white border rounded-md shadow-xl w-72 top-full dark:bg-slate-800 border-slate-50 dark:border-slate-700"
    >
      <WootDropdownMenu>
        <WootDropdownItem v-if="hasAgent">
          <woot-button
            variant="clear"
            color-scheme="secondary"
            size="small"
            icon="document"
            @click="instructions"
          >
            {{ $t('TRACKING_ASSISTANT_VIEW.EXPORT_INSTRUCTIONS') }}
          </woot-button>
        </WootDropdownItem>
        <WootDropdownItem v-if="catalog.length">
          <woot-button
            variant="clear"
            color-scheme="secondary"
            size="small"
            icon="book-open-globe"
            @click="resources"
          >
            {{ $t('TRACKING_ASSISTANT_VIEW.EXPORT_RESOURCES') }}
          </woot-button>
        </WootDropdownItem>
      </WootDropdownMenu>
    </div>
  </div>
</template>
