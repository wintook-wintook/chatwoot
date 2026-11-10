<script>
// feat/ficha_agente_ia — QUÉ CONTIENE UNA HOJA Y QUÉ HACE EL AGENTE CON ELLA
// ============================================================================
// Pedido del usuario (10/11/2026): «observar lo que contiene al seleccionar una hoja…
// para contextualizar lo que el agente debe hacer con ese contenido».
//   tabla con las primeras filas
//   ¿Para qué la usa el agente?  [Lista de precios: contestar el precio exacto…]
//   Busca por: [Producto ▾]    Contesta con: [Precio ✓] [Categoría]
// v-model: { purpose, search_by, answer_with: [] }  (Ficha::SheetUse en el servidor)
// ============================================================================
import FichaAPI from 'dashboard/api/fichaAgente';

export default {
  model: { prop: 'value', event: 'input' },
  props: {
    // La tarjeta de la hoja (id, name, columns, search_by, answer_with sugeridos).
    card: { type: Object, required: true },
    value: { type: Object, default: null },
    disabled: { type: Boolean, default: false },
  },
  emits: ['input'],
  data() {
    return { preview: null, loading: false, error: false };
  },
  computed: {
    columns() {
      return (this.preview && this.preview.columns) || this.card.columns || [];
    },
    config() {
      const actual = this.value || {};
      return {
        purpose: actual.purpose || '',
        search_by: actual.search_by || this.card.search_by || '',
        answer_with: actual.answer_with || this.card.answer_with || [],
      };
    },
    answerOptions() {
      return this.columns.filter(col => col !== this.config.search_by);
    },
  },
  mounted() {
    this.load();
  },
  methods: {
    t(key, args) {
      return this.$t(`TRACKING_TEMPLATES.FICHA.${key}`, args);
    },
    async load() {
      this.loading = true;
      try {
        const { data } = await FichaAPI.sheet(this.card.id);
        this.preview = data;
      } catch (error) {
        this.error = true;
      } finally {
        this.loading = false;
      }
    },
    set(campo, valor) {
      if (this.disabled) return;
      const siguiente = { ...this.config, [campo]: valor };
      if (campo === 'search_by')
        siguiente.answer_with = siguiente.answer_with.filter(c => c !== valor);
      this.$emit('input', siguiente);
    },
    toggleAnswer(columna) {
      const lista = this.config.answer_with.includes(columna)
        ? this.config.answer_with.filter(c => c !== columna)
        : [...this.config.answer_with, columna];
      this.set('answer_with', lista);
    },
  },
};
</script>

<template>
  <div class="flex flex-col gap-3 pl-6">
    <p v-if="loading" class="!m-0 text-xs text-slate-500">
      {{ t('LOADING') }}
    </p>
    <p v-else-if="error" class="!m-0 text-xs text-red-600">
      {{ t('SHEET_ERROR') }}
    </p>
    <div v-else-if="preview" class="flex flex-col gap-1">
      <span class="text-xs text-slate-500">
        {{
          t('SHEET_ROWS', {
            total: preview.total,
            shown: preview.rows.length,
          })
        }}
      </span>
      <div
        class="overflow-auto border rounded max-h-48 border-slate-200 dark:border-slate-700"
      >
        <table class="w-full text-xs border-collapse">
          <thead class="sticky top-0 bg-slate-50 dark:bg-slate-800">
            <tr>
              <th
                v-for="col in columns"
                :key="col"
                class="px-2 py-1 font-medium text-left whitespace-nowrap"
                :class="{
                  'text-woot-700 dark:text-woot-200': col === config.search_by,
                }"
              >
                {{ col }}
              </th>
            </tr>
          </thead>
          <tbody>
            <tr
              v-for="(fila, index) in preview.rows"
              :key="index"
              class="border-t border-slate-100 dark:border-slate-700"
            >
              <td
                v-for="(valor, col) in fila"
                :key="col"
                class="px-2 py-1 whitespace-nowrap text-slate-600 dark:text-slate-300"
              >
                {{ valor }}
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <label class="!m-0 text-sm">
      {{ t('SHEET_PURPOSE') }}
      <input
        type="text"
        maxlength="200"
        class="!mb-0"
        :value="config.purpose"
        :disabled="disabled"
        :placeholder="t('SHEET_PURPOSE_PLACEHOLDER')"
        @change="set('purpose', $event.target.value)"
      />
    </label>
    <div class="flex flex-wrap items-center gap-3 text-sm">
      <label class="flex items-center gap-2 !m-0">
        {{ t('SHEET_SEARCH_BY') }}
        <select
          class="!mb-0 !h-8 !py-0 !w-auto text-sm"
          :value="config.search_by"
          :disabled="disabled"
          @change="set('search_by', $event.target.value)"
        >
          <option v-for="col in columns" :key="col" :value="col">
            {{ col }}
          </option>
        </select>
      </label>
      <div class="flex flex-wrap items-center gap-1">
        <span>{{ t('SHEET_ANSWER_WITH') }}</span>
        <button
          v-for="col in answerOptions"
          :key="col"
          type="button"
          class="px-2 py-0.5 text-xs border rounded-full"
          :class="
            config.answer_with.includes(col)
              ? 'border-woot-500 bg-woot-500 text-white'
              : 'border-slate-200 text-slate-600 dark:border-slate-700 dark:text-slate-300'
          "
          :disabled="disabled"
          @click="toggleAnswer(col)"
        >
          {{ col }}
        </button>
      </div>
    </div>
  </div>
</template>
