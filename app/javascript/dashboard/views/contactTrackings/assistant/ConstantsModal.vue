<script>
// proyecto@crear_agente_conversando — F2: MODAL DE DATOS FIJOS
// ============================================================================
// Plan: docs/creacion_conversacional_agentes_plan.md §4.3. Lo que se escribe una vez y
// se cita en cualquier parte con %NOMBRE%: el nombre de la empresa, una liga, una
// pregunta que el agente hace (y en qué variable guarda la respuesta), un mensaje que
// siempre sale igual. Escribe la sección [DATOS FIJOS] (ver agentConstants.js); el
// motor sustituye cada %NOMBRE% antes de mandar el texto al modelo.
// ============================================================================
import CopyChip from './CopyChip.vue';
import {
  CONSTANT_TYPES,
  cleanConstantName,
  constantRef,
} from './agentConstants';

const emptyRow = () => ({ name: '', type: 'texto', value: '', savesTo: '' });

export default {
  components: { CopyChip },
  props: {
    show: { type: Boolean, default: false },
    // { constants: [{ name, type, value, savesTo }], extra: [...] }
    value: { type: Object, default: () => ({ constants: [], extra: [] }) },
    // Los nombres de las Variables del agente: a dónde puede guardar una pregunta.
    variables: { type: Array, default: () => [] },
    // { NOMBRE: { count, places } } (constantUsage).
    usage: { type: Object, default: () => ({}) },
    // null = la lista completa; un número = solo ese dato; 'new' = agregar uno.
    focus: { type: [Number, String], default: null },
  },
  emits: ['close', 'save'],
  data() {
    return { rows: [], tried: false, types: CONSTANT_TYPES, only: null };
  },
  computed: {
    title() {
      if (this.focus === 'new')
        return this.$t('TRACKING_ASSISTANT_VIEW.CONSTANTS_TITLE_ADD');
      if (this.only !== null)
        return this.$t('TRACKING_ASSISTANT_VIEW.CONSTANTS_TITLE_EDIT');
      return this.$t('TRACKING_ASSISTANT_VIEW.CONSTANTS_TITLE');
    },
    errors() {
      const vistos = new Set();
      return this.rows.map(row => {
        const nombre = cleanConstantName(row.name);
        if (!nombre && !row.value.trim()) return '';
        if (!nombre) return 'CONSTANTS_ERROR_NO_NAME';
        if (vistos.has(nombre)) return 'CONSTANTS_ERROR_DUPLICATE';
        vistos.add(nombre);
        if (!row.value.trim()) return 'CONSTANTS_ERROR_NO_VALUE';
        return '';
      });
    },
    // Solo cuentan los que se ven: uno escondido no puede bloquear sin que se vea.
    hasErrors() {
      return this.errors.some((error, index) => error && this.isShown(index));
    },
  },
  watch: {
    show(abierto) {
      if (abierto) this.load();
    },
  },
  methods: {
    load() {
      const actuales = (this.value.constants || []).map(c => ({ ...c }));
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
    refOf(row) {
      const nombre = cleanConstantName(row.name);
      return nombre ? constantRef(nombre) : '';
    },
    // «Se usa en @demo, BIENVENIDA» o «No se usa todavía».
    usageText(row) {
      const uso = this.usage[cleanConstantName(row.name)];
      if (!uso || !uso.count)
        return this.$t('TRACKING_ASSISTANT_VIEW.CONSTANTS_UNUSED');
      const lugares = [...new Set(uso.places)].map(
        p => p || this.$t('TRACKING_TEMPLATES.FORM.TRAINING.PREAMBLE')
      );
      return this.$t('TRACKING_ASSISTANT_VIEW.CONSTANTS_USED_IN', {
        places: lugares.join(', '),
      });
    },
    isUsed(row) {
      const uso = this.usage[cleanConstantName(row.name)];
      return Boolean(uso && uso.count);
    },
    save() {
      this.tried = true;
      if (this.hasErrors) return;
      const constants = this.rows
        .filter(row => cleanConstantName(row.name) && row.value.trim())
        .map(row => ({
          name: cleanConstantName(row.name),
          type: row.type,
          value: row.type === 'texto' ? row.value.trimEnd() : row.value.trim(),
          savesTo: row.type === 'pregunta' ? row.savesTo : '',
        }));
      this.$emit('save', { constants, extra: this.value.extra || [] });
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
          {{ $t('TRACKING_ASSISTANT_VIEW.CONSTANTS_HINT') }}
        </p>
      </div>

      <div class="flex flex-col gap-3">
        <template v-for="(row, index) in rows">
          <div
            v-if="isShown(index)"
            :key="index"
            class="flex flex-col gap-2 p-3 border rounded-md border-slate-100 dark:border-slate-700"
          >
            <div class="flex items-end gap-2">
              <div class="flex-1">
                <label class="!mb-1 text-xs text-slate-500 dark:text-slate-400">
                  {{ $t('TRACKING_ASSISTANT_VIEW.CONSTANTS_NAME') }}
                </label>
                <input
                  v-model="row.name"
                  type="text"
                  class="w-full !mb-0 font-mono uppercase"
                  :placeholder="
                    $t('TRACKING_ASSISTANT_VIEW.CONSTANTS_NAME_HINT')
                  "
                />
              </div>
              <div class="w-40">
                <label class="!mb-1 text-xs text-slate-500 dark:text-slate-400">
                  {{ $t('TRACKING_ASSISTANT_VIEW.CONSTANTS_TYPE') }}
                </label>
                <select v-model="row.type" class="w-full !mb-0">
                  <option v-for="tipo in types" :key="tipo" :value="tipo">
                    {{ $t(`TRACKING_ASSISTANT_VIEW.CONSTANTS_TYPE_${tipo}`) }}
                  </option>
                </select>
              </div>
              <woot-button
                v-if="only === null"
                variant="clear"
                color-scheme="secondary"
                icon="delete"
                size="small"
                :title="$t('TRACKING_ASSISTANT_VIEW.CONSTANTS_REMOVE')"
                @click="removeRow(index)"
              />
            </div>
            <div>
              <label class="!mb-1 text-xs text-slate-500 dark:text-slate-400">
                {{ $t('TRACKING_ASSISTANT_VIEW.CONSTANTS_VALUE') }}
              </label>
              <textarea
                v-if="row.type === 'texto'"
                v-model="row.value"
                rows="3"
                class="w-full !mb-0 text-sm bg-white dark:bg-slate-900 text-slate-900 dark:text-slate-100 border border-slate-200 dark:border-slate-600 rounded-md px-3 py-2"
                :placeholder="
                  $t('TRACKING_ASSISTANT_VIEW.CONSTANTS_VALUE_HINT_texto')
                "
              />
              <input
                v-else
                v-model="row.value"
                type="text"
                class="w-full !mb-0"
                :placeholder="
                  $t(`TRACKING_ASSISTANT_VIEW.CONSTANTS_VALUE_HINT_${row.type}`)
                "
              />
            </div>
            <label
              v-if="row.type === 'pregunta'"
              class="flex items-center gap-2 !mb-0 text-sm text-slate-700 dark:text-slate-200"
            >
              {{ $t('TRACKING_ASSISTANT_VIEW.CONSTANTS_SAVES_TO') }}
              <select v-model="row.savesTo" class="!mb-0 w-56">
                <option value="">
                  {{ $t('TRACKING_ASSISTANT_VIEW.CONSTANTS_SAVES_NONE') }}
                </option>
                <option v-for="v in variables" :key="v" :value="v">
                  {{ v }}
                </option>
              </select>
            </label>
            <div class="flex flex-wrap items-center gap-2">
              <CopyChip v-if="refOf(row)" :text="refOf(row)" />
              <span
                class="text-xs"
                :class="
                  isUsed(row)
                    ? 'text-slate-500 dark:text-slate-400'
                    : 'text-amber-800 dark:text-amber-800'
                "
              >
                {{ usageText(row) }}
              </span>
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
          {{ $t('TRACKING_ASSISTANT_VIEW.CONSTANTS_ADD') }}
        </woot-button>
      </div>

      <p class="!m-0 text-xs text-slate-500 dark:text-slate-400">
        {{ $t('TRACKING_ASSISTANT_VIEW.CONSTANTS_IN_TEXT') }}
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
          {{ $t('TRACKING_ASSISTANT_VIEW.CONSTANTS_SAVE') }}
        </woot-button>
      </div>
    </div>
  </woot-modal>
</template>
