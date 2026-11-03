<script>
// proyecto@crear_agente_conversando — F1: MODAL DE VARIABLES
// ============================================================================
// Plan: docs/creacion_conversacional_agentes_plan.md §3. Lo que el agente recuerda de
// cada cliente (CARRERA, LIGA_ENTREGADA…). A diferencia del Objetivo y el Contexto,
// las Variables SÍ son texto del Entrenamiento: este modal escribe la sección
// [VARIABLES] (ver agentVariables.js), así que pasan por el comprobador, entran a las
// versiones y se publican con el agente.
//
// Si hay variables escritas fuera de [VARIABLES] (V5), lo dice arriba y ofrece
// pasarlas: el motor solo guarda las de esa sección.
// ============================================================================
import { cleanVariableName, variableKey } from './agentVariables';

const emptyRow = () => ({ name: '', values: '', free: false, initial: '' });

const toRow = v => ({
  name: v.name,
  values: v.options.join(' | '),
  free: v.free,
  initial: v.initial || '',
});

const optionsOf = row =>
  (row.values || '')
    .split('|')
    .map(o => o.trim())
    .filter(Boolean);

export default {
  props: {
    show: { type: Boolean, default: false },
    // { variables: [{ name, options, free, initial }], extra: [...] }
    value: { type: Object, default: () => ({ variables: [], extra: [] }) },
    // Cuántas variables hay escritas fuera de [VARIABLES] (V5).
    strayCount: { type: Number, default: 0 },
    // null = la lista completa; un número = solo esa variable; 'new' = agregar una.
    focus: { type: [Number, String], default: null },
  },
  emits: ['close', 'save', 'moveStray'],
  data() {
    return { rows: [], tried: false, only: null };
  },
  computed: {
    title() {
      if (this.focus === 'new')
        return this.$t('TRACKING_ASSISTANT_VIEW.VARIABLES_TITLE_ADD');
      if (this.only !== null)
        return this.$t('TRACKING_ASSISTANT_VIEW.VARIABLES_TITLE_EDIT');
      return this.$t('TRACKING_ASSISTANT_VIEW.VARIABLES_TITLE');
    },
    errors() {
      const vistos = new Set();
      return this.rows.map(row => {
        const nombre = cleanVariableName(row.name);
        if (!nombre && !row.values.trim()) return '';
        if (!nombre) return 'VARIABLES_ERROR_NO_NAME';
        const clave = variableKey(nombre);
        if (vistos.has(clave)) return 'VARIABLES_ERROR_DUPLICATE';
        vistos.add(clave);
        if (!row.free && !optionsOf(row).length)
          return 'VARIABLES_ERROR_NO_VALUES';
        return '';
      });
    },
    // Solo cuentan los que se ven: uno escondido no puede bloquear sin que se vea.
    hasErrors() {
      return this.errors.some((error, index) => error && this.isShown(index));
    },
    hasNotes() {
      return (this.value.extra || []).some(l => l.trim());
    },
  },
  watch: {
    show(abierto) {
      if (abierto) this.load();
    },
    // «Pasarlas a Variables» cambia la lista con el modal abierto.
    value() {
      if (this.show) this.load();
    },
  },
  methods: {
    load() {
      const actuales = (this.value.variables || []).map(toRow);
      if (this.focus === 'new') {
        this.rows = [...actuales, emptyRow()];
        this.only = actuales.length;
      } else {
        this.rows = actuales.length ? actuales : [emptyRow()];
        this.only = typeof this.focus === 'number' ? this.focus : null;
      }
      this.tried = false;
    },
    // Con `focus` se edita uno solo (el árbol: Editar / Agregar); sin él, la lista.
    isShown(index) {
      return this.only === null || index === this.only;
    },
    addRow() {
      this.rows = [...this.rows, emptyRow()];
    },
    removeRow(index) {
      this.rows = this.rows.filter((_, i) => i !== index);
      if (!this.rows.length) this.rows = [emptyRow()];
    },
    // El valor inicial solo puede ser uno de la lista (o cualquiera, si es libre).
    initialChoices(row) {
      return optionsOf(row);
    },
    save() {
      this.tried = true;
      if (this.hasErrors) return;
      const variables = this.rows
        .filter(row => cleanVariableName(row.name))
        .map(row => {
          const options = optionsOf(row);
          const inicial = (row.initial || '').trim();
          return {
            name: cleanVariableName(row.name),
            options,
            free: row.free,
            initial: row.free || options.includes(inicial) ? inicial : '',
          };
        });
      this.$emit('save', { variables, extra: this.value.extra || [] });
    },
  },
};
</script>

<template>
  <woot-modal :show="show" size="medium" :on-close="() => $emit('close')">
    <div class="flex flex-col gap-4 p-8 text-sm max-h-[85vh] overflow-y-auto">
      <div>
        <h2
          class="!m-0 text-base font-semibold leading-6 text-slate-800 dark:text-slate-50"
        >
          {{ title }}
        </h2>
        <p class="!mt-1 !mb-0 text-sm text-slate-600 dark:text-slate-300">
          {{ $t('TRACKING_ASSISTANT_VIEW.VARIABLES_HINT') }}
        </p>
      </div>

      <div
        v-if="strayCount && only === null"
        class="flex items-center gap-3 px-3 py-2 border rounded-md border-amber-200 bg-amber-50 dark:border-amber-700 dark:bg-amber-900/30"
      >
        <p class="flex-1 !m-0 text-sm text-amber-800 dark:text-amber-200">
          {{
            $tc('TRACKING_ASSISTANT_VIEW.VARIABLES_STRAY', strayCount, {
              count: strayCount,
            })
          }}
        </p>
        <woot-button
          size="small"
          color-scheme="warning"
          icon="arrow-download"
          @click="$emit('moveStray')"
        >
          {{ $t('TRACKING_ASSISTANT_VIEW.VARIABLES_STRAY_MOVE') }}
        </woot-button>
      </div>

      <div class="flex flex-col gap-3">
        <template v-for="(row, index) in rows">
          <div
            v-if="isShown(index)"
            :key="index"
            class="flex flex-col gap-2 p-3 border rounded-md border-slate-100 dark:border-slate-700"
          >
            <div class="flex items-end gap-2">
              <div class="w-2/5">
                <label class="!mb-1 text-xs text-slate-500 dark:text-slate-400">
                  {{ $t('TRACKING_ASSISTANT_VIEW.VARIABLES_NAME') }}
                </label>
                <input
                  v-model="row.name"
                  type="text"
                  class="w-full !mb-0 font-mono uppercase"
                  :placeholder="
                    $t('TRACKING_ASSISTANT_VIEW.VARIABLES_NAME_HINT')
                  "
                />
              </div>
              <div class="flex-1">
                <label class="!mb-1 text-xs text-slate-500 dark:text-slate-400">
                  {{ $t('TRACKING_ASSISTANT_VIEW.VARIABLES_VALUES') }}
                </label>
                <input
                  v-model="row.values"
                  type="text"
                  class="w-full !mb-0"
                  :placeholder="
                    $t('TRACKING_ASSISTANT_VIEW.VARIABLES_VALUES_HINT')
                  "
                />
              </div>
              <woot-button
                v-if="only === null"
                variant="clear"
                color-scheme="secondary"
                icon="delete"
                size="small"
                :title="$t('TRACKING_ASSISTANT_VIEW.VARIABLES_REMOVE')"
                @click="removeRow(index)"
              />
            </div>
            <div class="flex flex-wrap items-center gap-4">
              <label
                class="flex items-center gap-2 !mb-0 text-sm text-slate-700 dark:text-slate-200"
              >
                <input v-model="row.free" type="checkbox" class="!mb-0" />
                {{ $t('TRACKING_ASSISTANT_VIEW.VARIABLES_FREE') }}
              </label>
              <label
                class="flex items-center gap-2 !mb-0 text-sm text-slate-700 dark:text-slate-200"
              >
                {{ $t('TRACKING_ASSISTANT_VIEW.VARIABLES_INITIAL') }}
                <input
                  v-if="row.free && !initialChoices(row).length"
                  v-model="row.initial"
                  type="text"
                  class="!mb-0 w-40"
                  :placeholder="
                    $t('TRACKING_ASSISTANT_VIEW.VARIABLES_INITIAL_EMPTY')
                  "
                />
                <select v-else v-model="row.initial" class="!mb-0 w-40">
                  <option value="">
                    {{ $t('TRACKING_ASSISTANT_VIEW.VARIABLES_INITIAL_FIRST') }}
                  </option>
                  <option
                    v-for="opcion in initialChoices(row)"
                    :key="opcion"
                    :value="opcion"
                  >
                    {{ opcion }}
                  </option>
                </select>
              </label>
            </div>
            <p
              v-if="tried && errors[index]"
              class="!m-0 text-xs text-red-600 dark:text-red-400"
            >
              {{ $t(`TRACKING_ASSISTANT_VIEW.${errors[index]}`) }}
            </p>
          </div>
        </template>
      </div>

      <div v-if="only === null">
        <woot-button
          variant="smooth"
          color-scheme="success"
          size="small"
          icon="add"
          @click="addRow"
        >
          {{ $t('TRACKING_ASSISTANT_VIEW.VARIABLES_ADD') }}
        </woot-button>
      </div>

      <p class="!m-0 text-xs text-slate-500 dark:text-slate-400">
        {{ $t('TRACKING_ASSISTANT_VIEW.VARIABLES_IN_TEXT') }}
        <template v-if="hasNotes">
          {{ $t('TRACKING_ASSISTANT_VIEW.VARIABLES_NOTES_KEPT') }}
        </template>
      </p>

      <div class="flex items-center justify-end gap-2">
        <woot-button
          variant="clear"
          color-scheme="secondary"
          @click="$emit('close')"
        >
          {{ $t('TRACKING_TEMPLATES.FORM.TRAINING.ROUTE_MODAL_CANCEL') }}
        </woot-button>
        <woot-button @click="save">
          {{ $t('TRACKING_ASSISTANT_VIEW.VARIABLES_SAVE') }}
        </woot-button>
      </div>
    </div>
  </woot-modal>
</template>
