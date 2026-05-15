<!--
  ================================================================================
  proyecto@contact_tracking
  ================================================================================
  Componente: KeywordActionsEditor.vue
  Descripción: Editor de palabras clave de acción para plantillas y seguimientos.
               Permite agregar/editar/eliminar entradas { keyword, action, direction }.
               Las acciones son silenciosas: no generan respuesta al contacto.
  ================================================================================
-->
<template>
  <div class="keyword-actions-editor">

    <div class="flex items-center justify-between mb-2">
      <div>
        <h4 class="text-sm font-semibold text-slate-700 dark:text-slate-300">
          ⌨️ {{ $t('CONTACT_TRACKING.KEYWORD_ACTIONS.SECTION_TITLE') }}
        </h4>
        <p class="text-xs text-slate-500 dark:text-slate-400 mt-0.5">
          {{ $t('CONTACT_TRACKING.KEYWORD_ACTIONS.SECTION_DESCRIPTION') }}
        </p>
      </div>
      <woot-button
        type="button"
        size="tiny"
        variant="smooth"
        color-scheme="secondary"
        icon="add"
        @click="addRow"
      >
        {{ $t('CONTACT_TRACKING.KEYWORD_ACTIONS.ADD_BTN') }}
      </woot-button>
    </div>

    <!-- Lista vacía -->
    <p
      v-if="localItems.length === 0"
      class="text-xs text-slate-400 dark:text-slate-500 italic py-1"
    >
      {{ $t('CONTACT_TRACKING.KEYWORD_ACTIONS.EMPTY') }}
    </p>

    <!-- Filas -->
    <div v-else class="space-y-2">
      <div
        v-for="(item, idx) in localItems"
        :key="idx"
        class="flex gap-2 items-center"
      >
        <!-- Palabra clave -->
        <input
          v-model="item.keyword"
          type="text"
          :placeholder="$t('CONTACT_TRACKING.KEYWORD_ACTIONS.KEYWORD_PLACEHOLDER')"
          class="flex-1 rounded-md border border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-900 text-slate-900 dark:text-slate-100 px-3 py-1.5 text-sm focus:outline-none focus:ring-1 focus:ring-woot-500"
          @input="emitUpdate"
        />

        <!-- Acción -->
        <select
          v-model="item.action"
          class="w-44 rounded-md border border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-900 text-slate-900 dark:text-slate-100 px-2 py-1.5 text-sm focus:outline-none focus:ring-1 focus:ring-woot-500"
          @change="emitUpdate"
        >
          <option value="cancel">
            {{ $t('CONTACT_TRACKING.KEYWORD_ACTIONS.ACTIONS.CANCEL') }}
          </option>
          <option value="pause">
            {{ $t('CONTACT_TRACKING.KEYWORD_ACTIONS.ACTIONS.PAUSE') }}
          </option>
        </select>

        <!-- Dirección -->
        <select
          v-model="item.direction"
          class="w-40 rounded-md border border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-900 text-slate-900 dark:text-slate-100 px-2 py-1.5 text-sm focus:outline-none focus:ring-1 focus:ring-woot-500"
          @change="emitUpdate"
        >
          <option value="incoming">
            {{ $t('CONTACT_TRACKING.KEYWORD_ACTIONS.DIRECTIONS.INCOMING') }}
          </option>
          <option value="outgoing">
            {{ $t('CONTACT_TRACKING.KEYWORD_ACTIONS.DIRECTIONS.OUTGOING') }}
          </option>
          <option value="both">
            {{ $t('CONTACT_TRACKING.KEYWORD_ACTIONS.DIRECTIONS.BOTH') }}
          </option>
        </select>

        <!-- Eliminar -->
        <button
          type="button"
          class="text-slate-400 hover:text-red-500 dark:hover:text-red-400 transition-colors flex-shrink-0"
          :title="$t('CONTACT_TRACKING.KEYWORD_ACTIONS.REMOVE')"
          @click="removeRow(idx)"
        >
          <fluent-icon icon="dismiss" size="16" />
        </button>
      </div>
    </div>

  </div>
</template>

<script>
export default {
  name: 'KeywordActionsEditor',

  // Vue 2: v-model usa prop "value" + evento "input"
  props: {
    value: {
      type: Array,
      default: () => [],
    },
  },

  data() {
    return {
      localItems: this.cloneItems(this.value),
      // Evita que el watcher resetee localItems cuando el propio componente emitió el cambio
      isSelfUpdate: false,
    };
  },

  watch: {
    value: {
      handler(newVal) {
        if (this.isSelfUpdate) {
          this.isSelfUpdate = false;
          return;
        }
        // Sincronizar solo cuando el cambio viene del padre (ej: carga de plantilla)
        this.localItems = this.cloneItems(newVal);
      },
      deep: true,
    },
  },

  methods: {
    cloneItems(items) {
      if (!Array.isArray(items)) return [];
      return items.map(item => ({ ...item }));
    },

    addRow() {
      // Solo agregar la fila visualmente — no emitir (la keyword está vacía todavía)
      this.localItems.push({ keyword: '', action: 'cancel', direction: 'incoming' });
    },

    removeRow(idx) {
      this.localItems.splice(idx, 1);
      this.emitUpdate();
    },

    emitUpdate() {
      // Marcar que este cambio viene de nosotros para que el watcher no resetee
      this.isSelfUpdate = true;
      const valid = this.localItems.filter(item => item.keyword && item.keyword.trim() !== '');
      this.$emit('input', valid.map(item => ({ ...item, keyword: item.keyword.trim() })));
    },
  },
};
</script>

<style scoped>
select,
input[type='text'] {
  height: 34px !important;
  font-size: 13px !important;
}

.keyword-actions-editor {
  padding: var(--space-normal);
  background: var(--color-background-light);
  border: 1px solid var(--color-border);
  border-radius: var(--border-radius-normal);
}
</style>
