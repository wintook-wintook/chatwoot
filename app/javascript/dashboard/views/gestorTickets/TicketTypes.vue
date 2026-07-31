<!--
  @tickets_cases
  Gestión de tipos de caso configurables por cuenta — Tailwind + dark mode.
-->
<script>
import { mapGetters } from 'vuex';

const PALETTE = [
  '#3b82f6',
  '#8b5cf6',
  '#06b6d4',
  '#f59e0b',
  '#ef4444',
  '#22c55e',
  '#ec4899',
  '#64748b',
];
const FIELD_TYPE_KEYS = ['text', 'number', 'date', 'list', 'checkbox'];

// Los 13 estados del ciclo de vida (mismo orden del enum) — para el multiselect
// de estados por columna. Las etiquetas salen de CASE_TICKETS.STATUSES.<key>.
const STATUS_KEYS = [
  'open',
  'classified',
  'assigned',
  'in_diagnosis',
  'in_progress',
  'waiting_on_customer',
  'waiting_on_third_party',
  'waiting_on_internal',
  'escalated',
  'resolved',
  'validating',
  'closed',
  'cancelled',
];

// Paleta por defecto para columnas nuevas (se recicla por posición).
const COLUMN_PALETTE = [
  '#3b82f6',
  '#8b5cf6',
  '#f59e0b',
  '#f97316',
  '#10b981',
  '#64748b',
];

let columnKeySeq = 0;
const newColumnDraft = position => {
  columnKeySeq += 1;
  return {
    _key: `new-${columnKeySeq}`,
    id: null,
    label: '',
    color: COLUMN_PALETTE[position % COLUMN_PALETTE.length],
    statuses: [],
  };
};

const emptyFieldForm = () => ({
  key: '',
  label: '',
  field_type: 'text',
  required: false,
  optionsText: '',
});

export default {
  name: 'TicketTypes',
  data() {
    return {
      showModal: false,
      editing: null,
      form: { name: '', color: '#3b82f6', prefix: '' },
      deletingId: null,
      palette: PALETTE,
      showDeleteModal: false,
      typeToDelete: null,
      // 2K — gestión de campos personalizados
      fieldTypeKeys: FIELD_TYPE_KEYS,
      showFieldsModal: false,
      fieldsType: null,
      editingField: null,
      fieldForm: emptyFieldForm(),
      deletingFieldId: null,
      // Columnas del Kanban por tipo (A+)
      statusKeys: STATUS_KEYS,
      showColumnsModal: false,
      columnsType: null,
      columnDraft: [],
    };
  },
  computed: {
    ...mapGetters({
      types: 'caseTickets/getTypes',
      typesUiFlags: 'caseTickets/getTypesUIFlags',
      getTypeFields: 'caseTickets/getTypeFields',
      typeFieldsUiFlags: 'caseTickets/getTypeFieldsUIFlags',
      typeColumnsUiFlags: 'caseTickets/getTypeColumnsUIFlags',
    }),
    isFetching() {
      return this.typesUiFlags.isFetching;
    },
    isSaving() {
      return this.typesUiFlags.isSaving;
    },
    deleteMessageValue() {
      return this.typeToDelete ? ` "${this.typeToDelete.name}"?` : '';
    },
    currentFields() {
      return this.fieldsType ? this.getTypeFields(this.fieldsType.id) : [];
    },
    fieldsLoading() {
      return this.typeFieldsUiFlags.isFetching;
    },
    fieldSaving() {
      return this.typeFieldsUiFlags.isSaving;
    },
    fieldFormValid() {
      if (
        !this.fieldForm.label.trim() ||
        !/^[a-z][a-z0-9_]*$/.test(this.fieldForm.key)
      ) {
        return false;
      }
      if (this.fieldForm.field_type === 'list') {
        return this.parsedOptions.length > 0;
      }
      return true;
    },
    parsedOptions() {
      return (this.fieldForm.optionsText || '')
        .split(',')
        .map(o => o.trim())
        .filter(Boolean);
    },
    // ── Columnas del Kanban por tipo (A+) ──────────────────────────
    columnsSaving() {
      return this.typeColumnsUiFlags.isSaving;
    },
    // Estados cubiertos por el borrador (unión de todas las columnas).
    coveredStatuses() {
      const set = new Set();
      this.columnDraft.forEach(c =>
        (c.statuses || []).forEach(s => set.add(s))
      );
      return set;
    },
    // Estados de los 13 que ninguna columna cubre aún.
    missingStatuses() {
      return this.statusKeys.filter(s => !this.coveredStatuses.has(s));
    },
    // Estados cubiertos por MÁS de una columna (para el aviso informativo).
    overlapStatuses() {
      const count = {};
      this.columnDraft.forEach(c =>
        (c.statuses || []).forEach(s => {
          count[s] = (count[s] || 0) + 1;
        })
      );
      return this.statusKeys.filter(s => count[s] > 1);
    },
    columnsValid() {
      if (!this.columnDraft.length) return false;
      const allLabeled = this.columnDraft.every(c => c.label.trim());
      const allHaveStates = this.columnDraft.every(
        c => (c.statuses || []).length
      );
      return allLabeled && allHaveStates && !this.missingStatuses.length;
    },
  },
  mounted() {
    this.$store.dispatch('caseTickets/fetchTypes');
  },
  methods: {
    openCreate() {
      this.editing = null;
      this.form = { name: '', color: '#3b82f6', prefix: '', public: false };
      this.showModal = true;
    },
    openEdit(type) {
      this.editing = type;
      this.form = {
        name: type.name,
        color: type.color,
        prefix: type.prefix || '',
        public: !!type.public,
      };
      this.showModal = true;
    },
    async togglePublic(type) {
      try {
        await this.$store.dispatch('caseTickets/updateType', {
          id: type.id,
          public: !type.public,
        });
      } catch (_e) {
        /* silent */
      }
    },
    async save() {
      try {
        if (this.editing) {
          await this.$store.dispatch('caseTickets/updateType', {
            id: this.editing.id,
            ...this.form,
          });
        } else {
          await this.$store.dispatch('caseTickets/createType', this.form);
        }
        this.showModal = false;
      } catch (_e) {
        /* silent */
      }
    },
    openDelete(type) {
      this.typeToDelete = type;
      this.showDeleteModal = true;
    },
    closeDelete() {
      this.showDeleteModal = false;
      this.typeToDelete = null;
    },
    async confirmDelete() {
      const type = this.typeToDelete;
      if (!type) return;
      this.showDeleteModal = false;
      this.deletingId = type.id;
      try {
        await this.$store.dispatch('caseTickets/deleteType', type.id);
      } finally {
        this.deletingId = null;
        this.typeToDelete = null;
      }
    },

    // ── 2K — Campos personalizados ──────────────────────────────
    openFields(type) {
      this.fieldsType = type;
      this.resetFieldForm();
      this.showFieldsModal = true;
      this.$store.dispatch('caseTickets/fetchTypeFields', type.id);
    },
    closeFields() {
      this.showFieldsModal = false;
      this.fieldsType = null;
      this.resetFieldForm();
      // refresca el contador de campos en la lista de tipos
      this.$store.dispatch('caseTickets/fetchTypes');
    },
    resetFieldForm() {
      this.editingField = null;
      this.fieldForm = emptyFieldForm();
    },
    onKeyInput() {
      this.fieldForm.key = (this.fieldForm.key || '')
        .toLowerCase()
        .replace(/[^a-z0-9_]/g, '');
    },
    editField(field) {
      this.editingField = field;
      this.fieldForm = {
        key: field.key,
        label: field.label,
        field_type: field.field_type,
        required: field.required,
        optionsText: (field.options || []).join(', '),
      };
    },
    async saveField() {
      if (!this.fieldFormValid) return;
      const payload = {
        caseTypeId: this.fieldsType.id,
        key: this.fieldForm.key,
        label: this.fieldForm.label.trim(),
        field_type: this.fieldForm.field_type,
        required: this.fieldForm.required,
        options: this.fieldForm.field_type === 'list' ? this.parsedOptions : [],
      };
      try {
        if (this.editingField) {
          await this.$store.dispatch('caseTickets/updateTypeField', {
            id: this.editingField.id,
            ...payload,
          });
        } else {
          await this.$store.dispatch('caseTickets/createTypeField', payload);
        }
        this.resetFieldForm();
      } catch (e) {
        const msg =
          e?.response?.data?.error?.[0] ||
          this.$t('CASE_TICKETS.CUSTOM_FIELDS.SAVE_ERROR');
        this.$emitter.emit('newToastMessage', { message: msg });
      }
    },
    async removeField(field) {
      this.deletingFieldId = field.id;
      try {
        await this.$store.dispatch('caseTickets/deleteTypeField', {
          caseTypeId: this.fieldsType.id,
          id: field.id,
        });
        if (this.editingField && this.editingField.id === field.id) {
          this.resetFieldForm();
        }
      } finally {
        this.deletingFieldId = null;
      }
    },

    // ── Columnas del Kanban por tipo (A+) ──────────────────────────
    statusLabel(key) {
      return this.$t(`CASE_TICKETS.STATUSES.${key}`) || key;
    },
    async openColumns(type) {
      this.columnsType = type;
      this.columnDraft = [];
      this.showColumnsModal = true;
      try {
        await this.$store.dispatch('caseTickets/fetchTypeColumns', type.id);
      } catch (_e) {
        /* el borrador queda vacío; se puede empezar de cero */
      }
      // El getter ya tiene las columnas; construimos el borrador editable.
      const columns = this.$store.getters['caseTickets/getTypeColumns'](
        type.id
      );
      this.columnDraft = (columns || []).map((c, i) => ({
        _key: `db-${c.id}`,
        id: c.id,
        label: c.label,
        color: c.color || COLUMN_PALETTE[i % COLUMN_PALETTE.length],
        statuses: [...(c.statuses || [])],
      }));
    },
    closeColumns() {
      this.showColumnsModal = false;
      this.columnsType = null;
      this.columnDraft = [];
      // refresca el contador en la lista de tipos
      this.$store.dispatch('caseTickets/fetchTypes');
    },
    addColumn() {
      this.columnDraft.push(newColumnDraft(this.columnDraft.length));
    },
    removeColumn(index) {
      this.columnDraft.splice(index, 1);
    },
    moveColumn(index, delta) {
      const target = index + delta;
      if (target < 0 || target >= this.columnDraft.length) return;
      const arr = this.columnDraft;
      [arr[index], arr[target]] = [arr[target], arr[index]];
    },
    toggleStatus(column, statusKey) {
      const i = column.statuses.indexOf(statusKey);
      if (i === -1) column.statuses.push(statusKey);
      else column.statuses.splice(i, 1);
    },
    assignRemainingToLast() {
      if (!this.columnDraft.length || !this.missingStatuses.length) return;
      const last = this.columnDraft[this.columnDraft.length - 1];
      last.statuses = [...last.statuses, ...this.missingStatuses];
    },
    async saveColumns() {
      if (!this.columnsValid) {
        let msg = this.$t('CASE_TICKETS.COLUMNS_CFG.NEED_LABEL');
        if (this.columnDraft.some(c => !(c.statuses || []).length)) {
          msg = this.$t('CASE_TICKETS.COLUMNS_CFG.NEED_STATES');
        } else if (this.missingStatuses.length) {
          msg = this.$t('CASE_TICKETS.COLUMNS_CFG.NEED_COVERAGE');
        }
        this.$emitter.emit('newToastMessage', { message: msg });
        return;
      }
      const columns = this.columnDraft.map((c, i) => ({
        id: c.id || undefined,
        label: c.label.trim(),
        color: c.color,
        position: i,
        statuses: c.statuses,
      }));
      try {
        await this.$store.dispatch('caseTickets/replaceTypeColumns', {
          caseTypeId: this.columnsType.id,
          columns,
        });
        this.$emitter.emit('newToastMessage', {
          message: this.$t('CASE_TICKETS.COLUMNS_CFG.SAVED'),
        });
        this.closeColumns();
      } catch (e) {
        const msg =
          e?.response?.data?.error?.[0] ||
          this.$t('CASE_TICKETS.COLUMNS_CFG.SAVE_ERROR');
        this.$emitter.emit('newToastMessage', { message: msg });
      }
    },
  },
};
</script>

<template>
  <div
    class="flex flex-col flex-1 w-full h-full overflow-hidden bg-slate-25 dark:bg-slate-900"
  >
    <!-- Header -->
    <div
      class="flex items-center justify-between flex-shrink-0 px-6 py-4 bg-white border-b dark:bg-slate-900 border-slate-50 dark:border-slate-800/50"
    >
      <div class="flex items-center gap-4">
        <woot-button
          size="small"
          variant="clear"
          color-scheme="secondary"
          icon="chevron-left"
          @click="$router.push({ name: 'gestorTickets_index' })"
        >
          Volver
        </woot-button>
        <h1 class="m-0 text-xl font-bold text-slate-800 dark:text-slate-100">
          {{ $t('CASE_TICKETS.TYPES.TITLE') }}
        </h1>
      </div>
      <woot-button size="small" icon="add-circle" @click="openCreate">
        {{ $t('CASE_TICKETS.TYPES.CREATE_BUTTON') }}
      </woot-button>
    </div>

    <!-- Loading -->
    <div
      v-if="isFetching"
      class="flex items-center justify-center flex-1 text-slate-400 dark:text-slate-500"
    >
      <span>Cargando tipos...</span>
    </div>

    <!-- Lista -->
    <div v-else class="flex flex-col flex-1 gap-2 px-6 py-4 overflow-y-auto">
      <p class="m-0 mb-2 text-sm text-slate-500 dark:text-slate-400">
        {{ $t('CASE_TICKETS.TYPES.HELP') }}
      </p>
      <div
        v-for="type in types"
        :key="type.id"
        class="flex items-center gap-3 p-3 bg-white border rounded-lg dark:bg-slate-800 border-slate-75 dark:border-slate-700"
      >
        <span
          class="flex-shrink-0 w-4 h-4 rounded-full"
          :style="{ backgroundColor: type.color }"
        />
        <span
          class="flex-1 text-sm font-medium text-slate-800 dark:text-slate-100"
          >{{ type.name }}</span
        >
        <span
          v-if="type.prefix"
          class="px-1.5 py-0.5 font-mono text-xs rounded bg-slate-100 text-slate-600 dark:bg-slate-700 dark:text-slate-300"
          >{{ type.prefix }}</span
        >
        <woot-button
          size="tiny"
          :variant="type.public ? 'smooth' : 'clear'"
          :color-scheme="type.public ? 'success' : 'secondary'"
          icon="globe"
          @click="togglePublic(type)"
        >
          {{
            type.public
              ? $t('CASE_TICKETS.TYPES.PUBLIC_ON')
              : $t('CASE_TICKETS.TYPES.PUBLIC_OFF')
          }}
        </woot-button>
        <woot-button
          size="tiny"
          variant="clear"
          color-scheme="secondary"
          icon="list"
          @click="openFields(type)"
        >
          {{ $t('CASE_TICKETS.CUSTOM_FIELDS.MANAGE_BUTTON') }}
          <span
            v-if="(type.custom_fields || []).length"
            class="ml-1 px-1.5 py-0.5 text-xs rounded-full bg-woot-100 text-woot-700 dark:bg-woot-800 dark:text-woot-100"
            >{{ type.custom_fields.length }}</span
          >
        </woot-button>
        <woot-button
          size="tiny"
          variant="clear"
          color-scheme="secondary"
          icon="kanban"
          @click="openColumns(type)"
        >
          {{ $t('CASE_TICKETS.COLUMNS_CFG.MANAGE_BUTTON') }}
          <span
            v-if="(type.columns || []).length"
            class="ml-1 px-1.5 py-0.5 text-xs rounded-full bg-woot-100 text-woot-700 dark:bg-woot-800 dark:text-woot-100"
            >{{ type.columns.length }}</span
          >
        </woot-button>
        <woot-button
          size="tiny"
          variant="clear"
          color-scheme="secondary"
          icon="edit"
          @click="openEdit(type)"
        />
        <woot-button
          size="tiny"
          variant="clear"
          color-scheme="alert"
          icon="delete"
          :is-loading="deletingId === type.id"
          @click="openDelete(type)"
        />
      </div>
    </div>

    <!-- Modal crear/editar -->
    <woot-modal
      v-if="showModal"
      :show="showModal"
      :on-close="() => (showModal = false)"
      size="small"
    >
      <div class="flex flex-col h-auto overflow-auto">
        <woot-modal-header
          :header-title="
            editing
              ? $t('CASE_TICKETS.TYPES.EDIT_TITLE')
              : $t('CASE_TICKETS.TYPES.CREATE_TITLE')
          "
        />

        <form
          class="flex flex-col self-stretch w-full gap-4 pb-8"
          @submit.prevent="save"
        >
          <label class="flex flex-col gap-1">
            <span class="text-sm font-medium text-slate-700 dark:text-slate-200"
              >{{ $t('CASE_TICKETS.TYPES.NAME_LABEL') }} *</span
            >
            <input
              v-model="form.name"
              type="text"
              class="w-full"
              required
              maxlength="100"
              placeholder="Ej: Postventa"
            />
          </label>

          <div class="flex flex-col gap-1">
            <span
              class="text-sm font-medium text-slate-700 dark:text-slate-200"
              >{{ $t('CASE_TICKETS.TYPES.COLOR_LABEL') }}</span
            >
            <div class="flex items-center gap-2">
              <button
                v-for="c in palette"
                :key="c"
                type="button"
                class="w-7 h-7 rounded-full border-2 transition-transform"
                :class="
                  form.color === c
                    ? 'border-slate-800 dark:border-white scale-110'
                    : 'border-transparent'
                "
                :style="{ backgroundColor: c }"
                @click="form.color = c"
              />
              <input
                v-model="form.color"
                type="color"
                class="w-8 h-8 p-0 border-0 rounded cursor-pointer bg-transparent"
              />
            </div>
          </div>

          <label class="flex flex-col gap-1">
            <span
              class="text-sm font-medium text-slate-700 dark:text-slate-200"
              >{{ $t('CASE_TICKETS.TYPES.PREFIX_LABEL') }}</span
            >
            <input
              v-model="form.prefix"
              type="text"
              class="w-32 font-mono uppercase"
              maxlength="8"
              placeholder="SOP"
              @input="form.prefix = form.prefix.toUpperCase()"
            />
            <span class="text-xs text-slate-400 dark:text-slate-500">{{
              $t('CASE_TICKETS.TYPES.PREFIX_HELP')
            }}</span>
          </label>

          <label class="flex items-start gap-2">
            <input v-model="form.public" type="checkbox" class="mt-1" />
            <span class="flex flex-col">
              <span
                class="text-sm font-medium text-slate-700 dark:text-slate-200"
                >{{ $t('CASE_TICKETS.TYPES.PUBLIC_LABEL') }}</span
              >
              <span class="text-xs text-slate-400 dark:text-slate-500">{{
                $t('CASE_TICKETS.TYPES.PUBLIC_HELP')
              }}</span>
            </span>
          </label>

          <div class="flex justify-end gap-2 mt-2">
            <woot-button
              variant="clear"
              color-scheme="secondary"
              type="button"
              @click="showModal = false"
            >
              Cancelar
            </woot-button>
            <woot-button
              type="submit"
              :is-loading="isSaving"
              :disabled="!form.name.trim()"
            >
              {{ editing ? 'Guardar' : 'Crear' }}
            </woot-button>
          </div>
        </form>
      </div>
    </woot-modal>

    <!-- Modal: campos personalizados del tipo (2K) -->
    <woot-modal
      v-if="showFieldsModal"
      :show="showFieldsModal"
      :on-close="closeFields"
      size="medium"
    >
      <div class="flex flex-col overflow-hidden max-h-[90vh]">
        <woot-modal-header
          :header-title="$t('CASE_TICKETS.CUSTOM_FIELDS.MODAL_TITLE')"
          :header-content="fieldsType ? fieldsType.name : ''"
        />

        <div
          class="flex flex-col self-stretch w-full gap-4 px-8 pb-8 overflow-y-auto"
        >
          <!-- Formulario alta/edición (arriba, a lo ancho — estilo reglas) -->
          <form
            class="flex flex-col w-full gap-3 p-4 border rounded-lg bg-slate-25 dark:bg-slate-800/50 border-slate-100 dark:border-slate-700"
            @submit.prevent="saveField"
          >
            <span
              class="text-sm font-semibold text-slate-800 dark:text-slate-100"
            >
              {{
                editingField
                  ? $t('CASE_TICKETS.CUSTOM_FIELDS.EDIT_TITLE')
                  : $t('CASE_TICKETS.CUSTOM_FIELDS.ADD_TITLE')
              }}
            </span>
            <!-- Campos en una sola fila ancha -->
            <div class="flex flex-wrap items-end gap-3">
              <label class="flex flex-col flex-1 min-w-[160px] gap-1">
                <span
                  class="text-xs font-medium text-slate-600 dark:text-slate-300"
                  >{{ $t('CASE_TICKETS.CUSTOM_FIELDS.LABEL_LABEL') }} *</span
                >
                <input
                  v-model="fieldForm.label"
                  type="text"
                  class="w-full !mb-0"
                  maxlength="100"
                  required
                />
              </label>
              <label class="flex flex-col flex-1 min-w-[160px] gap-1">
                <span
                  class="text-xs font-medium text-slate-600 dark:text-slate-300"
                  >{{ $t('CASE_TICKETS.CUSTOM_FIELDS.KEY_LABEL') }} *</span
                >
                <input
                  v-model="fieldForm.key"
                  type="text"
                  class="w-full font-mono !mb-0"
                  maxlength="60"
                  :disabled="!!editingField"
                  :placeholder="
                    $t('CASE_TICKETS.CUSTOM_FIELDS.KEY_PLACEHOLDER')
                  "
                  @input="onKeyInput"
                />
              </label>
              <label class="flex flex-col w-44 gap-1">
                <span
                  class="text-xs font-medium text-slate-600 dark:text-slate-300"
                  >{{ $t('CASE_TICKETS.CUSTOM_FIELDS.TYPE_LABEL') }}</span
                >
                <select v-model="fieldForm.field_type" class="w-full !mb-0">
                  <option v-for="t in fieldTypeKeys" :key="t" :value="t">
                    {{ $t(`CASE_TICKETS.CUSTOM_FIELDS.TYPES.${t}`) }}
                  </option>
                </select>
              </label>
              <label class="flex items-center gap-2 pb-2.5">
                <input v-model="fieldForm.required" type="checkbox" />
                <span
                  class="text-xs font-medium text-slate-600 dark:text-slate-300"
                  >{{ $t('CASE_TICKETS.CUSTOM_FIELDS.REQUIRED_LABEL') }}</span
                >
              </label>
            </div>
            <label
              v-if="fieldForm.field_type === 'list'"
              class="flex flex-col gap-1"
            >
              <span
                class="text-xs font-medium text-slate-600 dark:text-slate-300"
                >{{ $t('CASE_TICKETS.CUSTOM_FIELDS.OPTIONS_LABEL') }}</span
              >
              <input
                v-model="fieldForm.optionsText"
                type="text"
                class="w-full !mb-0"
                :placeholder="
                  $t('CASE_TICKETS.CUSTOM_FIELDS.OPTIONS_PLACEHOLDER')
                "
              />
            </label>
            <div class="flex justify-end gap-2">
              <woot-button
                v-if="editingField"
                variant="clear"
                color-scheme="secondary"
                type="button"
                @click="resetFieldForm"
              >
                {{ $t('CASE_TICKETS.CUSTOM_FIELDS.CANCEL_EDIT') }}
              </woot-button>
              <woot-button
                type="submit"
                :is-loading="fieldSaving"
                :disabled="!fieldFormValid"
              >
                {{
                  editingField
                    ? $t('CASE_TICKETS.CUSTOM_FIELDS.SAVE')
                    : $t('CASE_TICKETS.CUSTOM_FIELDS.ADD')
                }}
              </woot-button>
            </div>
          </form>

          <!-- Sección: campos definidos (abajo, scroll a 3 — estilo reglas) -->
          <div
            class="flex flex-col w-full gap-2 p-4 border rounded-lg bg-slate-25 dark:bg-slate-800/50 border-slate-100 dark:border-slate-700"
          >
            <span
              class="text-sm font-semibold text-slate-800 dark:text-slate-100"
            >
              {{ $t('CASE_TICKETS.CUSTOM_FIELDS.DEFINED_TITLE') }}
            </span>

            <div
              v-if="fieldsLoading"
              class="py-2 text-sm text-center text-slate-400"
            >
              {{ $t('CASE_TICKETS.CUSTOM_FIELDS.LOADING') }}
            </div>
            <div
              v-else-if="!currentFields.length"
              class="py-2 text-sm text-center text-slate-400 dark:text-slate-500"
            >
              {{ $t('CASE_TICKETS.CUSTOM_FIELDS.EMPTY') }}
            </div>
            <div
              v-else
              class="flex flex-col gap-2 pr-1 overflow-y-auto max-h-[12.5rem]"
            >
              <div
                v-for="field in currentFields"
                :key="field.id"
                class="flex items-center gap-3 p-2.5 bg-white border rounded-lg dark:bg-slate-800 border-slate-100 dark:border-slate-700"
              >
                <div class="flex-1 min-w-0">
                  <div class="flex items-center gap-2">
                    <span
                      class="text-sm font-medium text-slate-800 dark:text-slate-100"
                      >{{ field.label }}</span
                    >
                    <span
                      v-if="field.required"
                      class="px-1.5 py-0.5 text-xs rounded bg-red-100 text-red-700 dark:bg-red-900/40 dark:text-red-300"
                      >{{
                        $t('CASE_TICKETS.CUSTOM_FIELDS.REQUIRED_BADGE')
                      }}</span
                    >
                  </div>
                  <span
                    class="font-mono text-xs text-slate-400 dark:text-slate-500"
                  >
                    {{ field.key }} ·
                    {{
                      $t(`CASE_TICKETS.CUSTOM_FIELDS.TYPES.${field.field_type}`)
                    }}
                    <template v-if="field.field_type === 'list'">
                      ({{ (field.options || []).join(', ') }})</template
                    >
                  </span>
                </div>
                <woot-button
                  size="tiny"
                  variant="clear"
                  color-scheme="secondary"
                  icon="edit"
                  @click="editField(field)"
                />
                <woot-button
                  size="tiny"
                  variant="clear"
                  color-scheme="alert"
                  icon="delete"
                  :is-loading="deletingFieldId === field.id"
                  @click="removeField(field)"
                />
              </div>
            </div>
          </div>

          <div
            class="flex justify-end flex-shrink-0 gap-4 pt-4 border-t border-slate-100 dark:border-slate-700"
          >
            <woot-button
              variant="clear"
              color-scheme="secondary"
              @click="closeFields"
            >
              {{ $t('CASE_TICKETS.CUSTOM_FIELDS.CLOSE') }}
            </woot-button>
          </div>
        </div>
      </div>
    </woot-modal>

    <!-- Modal: columnas del Kanban por tipo (A+) -->
    <woot-modal
      v-if="showColumnsModal"
      :show="showColumnsModal"
      :on-close="closeColumns"
      size="medium"
    >
      <div class="flex flex-col overflow-hidden max-h-[90vh]">
        <woot-modal-header
          :header-title="$t('CASE_TICKETS.COLUMNS_CFG.MODAL_TITLE')"
          :header-content="columnsType ? columnsType.name : ''"
        />

        <div
          class="flex flex-col self-stretch w-full gap-4 px-8 pb-8 overflow-y-auto"
        >
          <p class="m-0 text-sm text-slate-500 dark:text-slate-400">
            {{ $t('CASE_TICKETS.COLUMNS_CFG.MODAL_SUBTITLE') }}
          </p>

          <!-- Vacío -->
          <div
            v-if="!columnDraft.length"
            class="py-6 text-sm text-center text-slate-400 dark:text-slate-500"
          >
            {{ $t('CASE_TICKETS.COLUMNS_CFG.EMPTY') }}
          </div>

          <!-- Lista de columnas del borrador -->
          <div
            v-for="(col, index) in columnDraft"
            :key="col._key"
            class="flex flex-col w-full gap-3 p-4 border rounded-lg bg-slate-25 dark:bg-slate-800/50 border-slate-100 dark:border-slate-700"
          >
            <div class="flex flex-wrap items-end gap-3">
              <span
                class="flex items-center justify-center w-6 h-6 mb-1 text-xs font-semibold rounded-full bg-slate-200 text-slate-600 dark:bg-slate-700 dark:text-slate-300"
                >{{ index + 1 }}</span
              >
              <label class="flex flex-col flex-1 min-w-[160px] gap-1">
                <span
                  class="text-xs font-medium text-slate-600 dark:text-slate-300"
                  >{{ $t('CASE_TICKETS.COLUMNS_CFG.LABEL_LABEL') }} *</span
                >
                <input
                  v-model="col.label"
                  type="text"
                  class="w-full !mb-0"
                  maxlength="60"
                  :placeholder="
                    $t('CASE_TICKETS.COLUMNS_CFG.LABEL_PLACEHOLDER')
                  "
                />
              </label>
              <label class="flex flex-col gap-1">
                <span
                  class="text-xs font-medium text-slate-600 dark:text-slate-300"
                  >{{ $t('CASE_TICKETS.COLUMNS_CFG.COLOR_LABEL') }}</span
                >
                <input
                  v-model="col.color"
                  type="color"
                  class="w-10 h-9 p-0 border-0 rounded cursor-pointer bg-transparent"
                />
              </label>
              <div class="flex items-center gap-1 pb-1">
                <woot-button
                  size="tiny"
                  variant="clear"
                  color-scheme="secondary"
                  icon="chevron-up"
                  :disabled="index === 0"
                  :title="$t('CASE_TICKETS.COLUMNS_CFG.MOVE_UP')"
                  @click="moveColumn(index, -1)"
                />
                <woot-button
                  size="tiny"
                  variant="clear"
                  color-scheme="secondary"
                  icon="chevron-down"
                  :disabled="index === columnDraft.length - 1"
                  :title="$t('CASE_TICKETS.COLUMNS_CFG.MOVE_DOWN')"
                  @click="moveColumn(index, 1)"
                />
                <woot-button
                  size="tiny"
                  variant="clear"
                  color-scheme="alert"
                  icon="delete"
                  :title="$t('CASE_TICKETS.COLUMNS_CFG.REMOVE')"
                  @click="removeColumn(index)"
                />
              </div>
            </div>
            <!-- Multiselect de estados (chips) -->
            <div class="flex flex-col gap-1.5">
              <span
                class="text-xs font-medium text-slate-600 dark:text-slate-300"
                >{{ $t('CASE_TICKETS.COLUMNS_CFG.STATES_LABEL') }} *</span
              >
              <div class="flex flex-wrap gap-1.5">
                <button
                  v-for="s in statusKeys"
                  :key="s"
                  type="button"
                  class="px-2 py-1 text-xs rounded-full border transition-colors"
                  :class="
                    col.statuses.includes(s)
                      ? 'bg-woot-500 border-woot-500 text-white'
                      : 'bg-white dark:bg-slate-800 border-slate-200 dark:border-slate-600 text-slate-500 dark:text-slate-400 hover:border-woot-400'
                  "
                  @click="toggleStatus(col, s)"
                >
                  {{ statusLabel(s) }}
                </button>
              </div>
            </div>
          </div>

          <woot-button
            size="small"
            variant="clear"
            color-scheme="secondary"
            icon="add-circle"
            @click="addColumn"
          >
            {{ $t('CASE_TICKETS.COLUMNS_CFG.ADD_COLUMN') }}
          </woot-button>

          <!-- Aviso informativo de solape -->
          <div
            v-if="overlapStatuses.length"
            class="flex items-start gap-2 p-3 text-xs rounded-lg bg-woot-50 dark:bg-woot-800/30 text-woot-800 dark:text-woot-100"
          >
            <fluent-icon icon="info" size="14" class="mt-0.5 flex-shrink-0" />
            <span>{{ $t('CASE_TICKETS.COLUMNS_CFG.OVERLAP_INFO') }}</span>
          </div>

          <!-- Cobertura -->
          <div
            v-if="columnDraft.length && missingStatuses.length"
            class="flex flex-col gap-2 p-3 text-xs rounded-lg bg-amber-50 dark:bg-amber-900/20 text-amber-800 dark:text-amber-200"
          >
            <span>
              <strong>{{
                $t('CASE_TICKETS.COLUMNS_CFG.MISSING_COVERAGE')
              }}</strong>
              {{ missingStatuses.map(statusLabel).join(', ') }}
            </span>
            <woot-button
              size="tiny"
              variant="smooth"
              color-scheme="warning"
              @click="assignRemainingToLast"
            >
              {{ $t('CASE_TICKETS.COLUMNS_CFG.ASSIGN_REMAINING') }}
            </woot-button>
          </div>
          <p
            v-else-if="columnDraft.length"
            class="m-0 text-xs text-green-600 dark:text-green-400"
          >
            {{ $t('CASE_TICKETS.COLUMNS_CFG.COVERAGE_OK') }}
          </p>

          <div
            class="flex justify-end flex-shrink-0 gap-2 pt-4 border-t border-slate-100 dark:border-slate-700"
          >
            <woot-button
              variant="clear"
              color-scheme="secondary"
              @click="closeColumns"
            >
              {{ $t('CASE_TICKETS.COLUMNS_CFG.CLOSE') }}
            </woot-button>
            <woot-button
              :is-loading="columnsSaving"
              :disabled="!columnsValid"
              @click="saveColumns"
            >
              {{ $t('CASE_TICKETS.COLUMNS_CFG.SAVE') }}
            </woot-button>
          </div>
        </div>
      </div>
    </woot-modal>

    <!-- Confirmación de borrado (estilo Chatwoot) -->
    <woot-delete-modal
      :show.sync="showDeleteModal"
      :on-close="closeDelete"
      :on-confirm="confirmDelete"
      :title="$t('CASE_TICKETS.TYPES.DELETE.TITLE')"
      :message="$t('CASE_TICKETS.TYPES.DELETE.MESSAGE')"
      :message-value="deleteMessageValue"
      :confirm-text="$t('CASE_TICKETS.TYPES.DELETE.YES')"
      :reject-text="$t('CASE_TICKETS.TYPES.DELETE.NO')"
    />
  </div>
</template>
