<!--
  @tickets_cases
  Pestaña "Columnas" del detalle de un Tipo de Caso. Tabla con filas que se
  REORDENAN ARRASTRANDO (vuedraggable sobre un <tbody>), y modal por columna para
  alta/edición. El backend guarda por reemplazo total (replaceTypeColumns) y
  exige que las columnas cubran los 13 estados del ciclo de vida, así que se
  trabaja sobre un borrador local y se persiste todo con "Guardar columnas".
-->
<script>
import { mapGetters } from 'vuex';
import draggable from 'vuedraggable';

// Los 13 estados del ciclo de vida (mismo orden del enum).
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

const COLUMN_PALETTE = [
  '#3b82f6',
  '#8b5cf6',
  '#f59e0b',
  '#f97316',
  '#10b981',
  '#64748b',
];

let columnKeySeq = 0;
const nextKey = () => {
  columnKeySeq += 1;
  return `col-${columnKeySeq}`;
};

export default {
  name: 'ColumnsTab',
  components: { Draggable: draggable },
  props: {
    caseTypeId: {
      type: Number,
      required: true,
    },
  },
  data() {
    return {
      statusKeys: STATUS_KEYS,
      draft: [],
      dirty: false,
      // Modal por columna
      showModal: false,
      editingIndex: null,
      modalForm: { label: '', color: COLUMN_PALETTE[0], statuses: [] },
    };
  },
  computed: {
    ...mapGetters({
      getTypeColumns: 'caseTickets/getTypeColumns',
      uiFlags: 'caseTickets/getTypeColumnsUIFlags',
    }),
    isFetching() {
      return this.uiFlags.isFetching;
    },
    isSaving() {
      return this.uiFlags.isSaving;
    },
    coveredStatuses() {
      const set = new Set();
      this.draft.forEach(c => (c.statuses || []).forEach(s => set.add(s)));
      return set;
    },
    missingStatuses() {
      return this.statusKeys.filter(s => !this.coveredStatuses.has(s));
    },
    overlapStatuses() {
      const count = {};
      this.draft.forEach(c =>
        (c.statuses || []).forEach(s => {
          count[s] = (count[s] || 0) + 1;
        })
      );
      return this.statusKeys.filter(s => count[s] > 1);
    },
    columnsValid() {
      if (!this.draft.length) return false;
      const allLabeled = this.draft.every(c => c.label.trim());
      const allHaveStates = this.draft.every(c => (c.statuses || []).length);
      return allLabeled && allHaveStates && !this.missingStatuses.length;
    },
    modalValid() {
      return (
        !!this.modalForm.label.trim() && (this.modalForm.statuses || []).length
      );
    },
  },
  async mounted() {
    await this.load();
  },
  methods: {
    statusLabel(key) {
      return this.$t(`CASE_TICKETS.STATUSES.${key}`) || key;
    },
    async load() {
      try {
        await this.$store.dispatch(
          'caseTickets/fetchTypeColumns',
          this.caseTypeId
        );
      } catch (_e) {
        /* borrador vacío: se puede empezar de cero */
      }
      const columns = this.getTypeColumns(this.caseTypeId) || [];
      this.draft = columns.map((c, i) => ({
        _key: nextKey(),
        id: c.id,
        label: c.label,
        color: c.color || COLUMN_PALETTE[i % COLUMN_PALETTE.length],
        statuses: [...(c.statuses || [])],
      }));
      this.dirty = false;
    },
    // Reordenar arrastrando: vuedraggable ya mutó `draft` por v-model; solo
    // marcamos que hay cambios sin guardar.
    onDragEnd() {
      this.dirty = true;
    },
    // ── Modal por columna ──────────────────────────────────────────
    openCreate() {
      this.editingIndex = null;
      this.modalForm = {
        label: '',
        color: COLUMN_PALETTE[this.draft.length % COLUMN_PALETTE.length],
        statuses: [],
      };
      this.showModal = true;
    },
    openEdit(index) {
      const col = this.draft[index];
      this.editingIndex = index;
      this.modalForm = {
        label: col.label,
        color: col.color,
        statuses: [...(col.statuses || [])],
      };
      this.showModal = true;
    },
    closeModal() {
      this.showModal = false;
      this.editingIndex = null;
    },
    toggleModalStatus(statusKey) {
      const i = this.modalForm.statuses.indexOf(statusKey);
      if (i === -1) this.modalForm.statuses.push(statusKey);
      else this.modalForm.statuses.splice(i, 1);
    },
    saveModal() {
      if (!this.modalValid) return;
      if (this.editingIndex === null) {
        this.draft.push({
          _key: nextKey(),
          id: null,
          label: this.modalForm.label.trim(),
          color: this.modalForm.color,
          statuses: [...this.modalForm.statuses],
        });
      } else {
        const col = this.draft[this.editingIndex];
        col.label = this.modalForm.label.trim();
        col.color = this.modalForm.color;
        col.statuses = [...this.modalForm.statuses];
      }
      this.dirty = true;
      this.closeModal();
    },
    remove(index) {
      this.draft.splice(index, 1);
      this.dirty = true;
    },
    assignRemainingToLast() {
      if (!this.draft.length || !this.missingStatuses.length) return;
      const last = this.draft[this.draft.length - 1];
      last.statuses = [...last.statuses, ...this.missingStatuses];
      this.dirty = true;
    },
    // ── Guardado (reemplazo total) ─────────────────────────────────
    async save() {
      if (!this.columnsValid) {
        let msg = this.$t('CASE_TICKETS.COLUMNS_CFG.NEED_LABEL');
        if (this.draft.some(c => !(c.statuses || []).length)) {
          msg = this.$t('CASE_TICKETS.COLUMNS_CFG.NEED_STATES');
        } else if (this.missingStatuses.length) {
          msg = this.$t('CASE_TICKETS.COLUMNS_CFG.NEED_COVERAGE');
        }
        this.$emitter.emit('newToastMessage', { message: msg });
        return;
      }
      const columns = this.draft.map((c, i) => ({
        id: c.id || undefined,
        label: c.label.trim(),
        color: c.color,
        position: i,
        statuses: c.statuses,
      }));
      try {
        await this.$store.dispatch('caseTickets/replaceTypeColumns', {
          caseTypeId: this.caseTypeId,
          columns,
        });
        this.$emitter.emit('newToastMessage', {
          message: this.$t('CASE_TICKETS.COLUMNS_CFG.SAVED'),
        });
        await this.load();
        this.$emit('changed');
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
  <div class="flex flex-col flex-1 min-h-0">
    <!-- Toolbar -->
    <div class="flex items-center justify-between flex-shrink-0 px-6 py-3">
      <p class="m-0 mr-4 text-sm text-slate-500 dark:text-slate-400">
        {{ $t('CASE_TICKETS.COLUMNS_CFG.SUBTITLE') }}
      </p>
      <div class="flex items-center flex-shrink-0 gap-2">
        <span
          v-if="dirty"
          class="text-xs font-medium text-amber-600 dark:text-amber-400"
        >
          {{ $t('CASE_TICKETS.COLUMNS_CFG.UNSAVED') }}
        </span>
        <woot-button
          size="small"
          variant="clear"
          color-scheme="secondary"
          icon="add-circle"
          @click="openCreate"
        >
          {{ $t('CASE_TICKETS.COLUMNS_CFG.ADD_BUTTON') }}
        </woot-button>
        <woot-button
          size="small"
          icon="save"
          :is-loading="isSaving"
          :disabled="!columnsValid || !dirty"
          @click="save"
        >
          {{ $t('CASE_TICKETS.COLUMNS_CFG.SAVE') }}
        </woot-button>
      </div>
    </div>

    <!-- Loading inicial -->
    <div
      v-if="isFetching && !draft.length"
      class="flex items-center justify-center flex-1 text-slate-400 dark:text-slate-500"
    >
      <span>{{ $t('CASE_TICKETS.COLUMNS_CFG.LOADING') }}</span>
    </div>

    <!-- Empty state -->
    <div
      v-else-if="!draft.length"
      class="flex flex-col items-center justify-center flex-1 gap-4 text-slate-400 dark:text-slate-500"
    >
      <fluent-icon icon="kanban" size="36" />
      <p class="max-w-md text-center">
        {{ $t('CASE_TICKETS.COLUMNS_CFG.EMPTY') }}
      </p>
      <woot-button size="small" icon="add-circle" @click="openCreate">
        {{ $t('CASE_TICKETS.COLUMNS_CFG.ADD_BUTTON') }}
      </woot-button>
    </div>

    <!-- Tabla arrastrable + avisos de cobertura -->
    <div v-else class="flex flex-col flex-1 min-h-0">
      <div class="flex-1 min-h-0 px-6 pb-2 overflow-auto">
        <p
          class="flex items-center gap-1 mb-2 text-xs text-slate-400 dark:text-slate-500"
        >
          <fluent-icon icon="drag" size="12" />
          {{ $t('CASE_TICKETS.COLUMNS_CFG.DRAG_HINT') }}
        </p>
        <table class="w-full text-sm border-collapse columns-table">
          <thead>
            <tr class="text-slate-500 dark:text-slate-400">
              <th class="w-8" />
              <th class="w-10 text-center">
                {{ $t('CASE_TICKETS.COLUMNS_CFG.POSITION') }}
              </th>
              <th class="text-left">
                {{ $t('CASE_TICKETS.COLUMNS_CFG.LABEL_LABEL') }}
              </th>
              <th class="text-left">
                {{ $t('CASE_TICKETS.COLUMNS_CFG.STATES_SUMMARY') }}
              </th>
              <th class="w-24" />
            </tr>
          </thead>
          <Draggable
            v-model="draft"
            tag="tbody"
            handle=".drag-handle"
            ghost-class="col-row--ghost"
            :animation="150"
            @end="onDragEnd"
          >
            <tr
              v-for="(col, index) in draft"
              :key="col._key"
              class="border-t border-slate-75 dark:border-slate-700"
            >
              <td class="text-center">
                <span
                  class="inline-flex text-slate-400 cursor-grab active:cursor-grabbing drag-handle dark:text-slate-500 hover:text-slate-600 dark:hover:text-slate-300"
                  :title="$t('CASE_TICKETS.COLUMNS_CFG.REORDER')"
                >
                  <fluent-icon icon="drag" size="16" />
                </span>
              </td>
              <td class="text-center">
                <span
                  class="inline-flex items-center justify-center w-6 h-6 text-xs font-semibold rounded-full bg-slate-200 text-slate-600 dark:bg-slate-700 dark:text-slate-300"
                  >{{ index + 1 }}</span
                >
              </td>
              <td>
                <div class="flex items-center gap-2 min-w-0">
                  <span
                    class="flex-shrink-0 w-3 h-3 rounded-full"
                    :style="{ backgroundColor: col.color }"
                  />
                  <span
                    v-if="col.label"
                    class="text-sm font-medium truncate text-slate-800 dark:text-slate-100"
                    >{{ col.label }}</span
                  >
                  <span v-else class="text-sm italic text-slate-400">{{
                    $t('CASE_TICKETS.COLUMNS_CFG.LABEL_PLACEHOLDER')
                  }}</span>
                </div>
              </td>
              <td>
                <div
                  v-if="(col.statuses || []).length"
                  class="flex flex-wrap gap-1"
                >
                  <span
                    v-for="s in col.statuses"
                    :key="s"
                    class="px-1.5 py-0.5 text-[10px] rounded-full bg-slate-100 text-slate-600 dark:bg-slate-700 dark:text-slate-300"
                    >{{ statusLabel(s) }}</span
                  >
                </div>
                <span v-else class="text-xs text-red-500">{{
                  $t('CASE_TICKETS.COLUMNS_CFG.NEED_STATES')
                }}</span>
              </td>
              <td>
                <div class="flex items-center justify-end gap-1">
                  <woot-button
                    size="tiny"
                    variant="clear"
                    color-scheme="secondary"
                    icon="edit"
                    @click="openEdit(index)"
                  />
                  <woot-button
                    size="tiny"
                    variant="clear"
                    color-scheme="alert"
                    icon="delete"
                    :title="$t('CASE_TICKETS.COLUMNS_CFG.REMOVE')"
                    @click="remove(index)"
                  />
                </div>
              </td>
            </tr>
          </Draggable>
        </table>
      </div>

      <!-- Avisos: cobertura y solape -->
      <div class="flex flex-col flex-shrink-0 gap-2 px-6 pb-3">
        <div
          v-if="missingStatuses.length"
          class="flex flex-wrap items-center gap-2 p-3 text-xs rounded-lg bg-amber-50 dark:bg-amber-900/20 text-amber-800 dark:text-amber-200"
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
        <p v-else class="m-0 text-xs text-green-600 dark:text-green-400">
          {{ $t('CASE_TICKETS.COLUMNS_CFG.COVERAGE_OK') }}
        </p>
        <div
          v-if="overlapStatuses.length"
          class="flex items-start gap-2 p-3 text-xs rounded-lg bg-woot-50 dark:bg-woot-800/30 text-woot-800 dark:text-woot-100"
        >
          <fluent-icon icon="info" size="14" class="mt-0.5 flex-shrink-0" />
          <span>{{ $t('CASE_TICKETS.COLUMNS_CFG.OVERLAP_INFO') }}</span>
        </div>
      </div>
    </div>

    <!-- Modal alta/edición de columna -->
    <woot-modal
      v-if="showModal"
      :show="showModal"
      :on-close="closeModal"
      size="medium"
    >
      <div class="flex flex-col h-auto overflow-auto">
        <woot-modal-header
          :header-title="
            editingIndex === null
              ? $t('CASE_TICKETS.COLUMNS_CFG.NEW_TITLE')
              : $t('CASE_TICKETS.COLUMNS_CFG.EDIT_TITLE')
          "
        />
        <form
          class="flex flex-col self-stretch w-full gap-4 px-8 pb-8"
          @submit.prevent="saveModal"
        >
          <div class="flex flex-wrap items-end gap-3">
            <label class="flex flex-col flex-1 min-w-[160px] gap-1">
              <span
                class="text-xs font-medium text-slate-600 dark:text-slate-300"
                >{{ $t('CASE_TICKETS.COLUMNS_CFG.LABEL_LABEL') }} *</span
              >
              <input
                v-model="modalForm.label"
                type="text"
                class="w-full !mb-0"
                maxlength="60"
                :placeholder="$t('CASE_TICKETS.COLUMNS_CFG.LABEL_PLACEHOLDER')"
              />
            </label>
            <label class="flex flex-col gap-1">
              <span
                class="text-xs font-medium text-slate-600 dark:text-slate-300"
                >{{ $t('CASE_TICKETS.COLUMNS_CFG.COLOR_LABEL') }}</span
              >
              <input
                v-model="modalForm.color"
                type="color"
                class="w-10 p-0 bg-transparent border-0 rounded cursor-pointer h-9"
              />
            </label>
          </div>

          <div class="flex flex-col gap-1.5">
            <span class="text-xs font-medium text-slate-600 dark:text-slate-300"
              >{{ $t('CASE_TICKETS.COLUMNS_CFG.STATES_LABEL') }} *</span
            >
            <div class="flex flex-wrap gap-1.5">
              <button
                v-for="s in statusKeys"
                :key="s"
                type="button"
                class="px-2 py-1 text-xs border rounded-full transition-colors"
                :class="
                  modalForm.statuses.includes(s)
                    ? 'bg-woot-500 border-woot-500 text-white'
                    : 'bg-white dark:bg-slate-800 border-slate-200 dark:border-slate-600 text-slate-500 dark:text-slate-400 hover:border-woot-400'
                "
                @click="toggleModalStatus(s)"
              >
                {{ statusLabel(s) }}
              </button>
            </div>
          </div>

          <div class="flex justify-end gap-2 mt-2">
            <woot-button
              variant="clear"
              color-scheme="secondary"
              type="button"
              @click="closeModal"
            >
              {{ $t('CASE_TICKETS.COLUMNS_CFG.CANCEL') }}
            </woot-button>
            <woot-button type="submit" :disabled="!modalValid">
              {{ $t('CASE_TICKETS.CUSTOM_FIELDS.SAVE') }}
            </woot-button>
          </div>
        </form>
      </div>
    </woot-modal>
  </div>
</template>

<style lang="scss" scoped>
.columns-table {
  th {
    @apply px-2 py-2 text-xs font-semibold uppercase tracking-wide;
  }
  td {
    @apply px-2 py-2 align-middle;
  }
  tbody tr:hover {
    @apply bg-slate-25 dark:bg-slate-800/40;
  }
}

// Fila fantasma mientras se arrastra.
.col-row--ghost {
  @apply opacity-50 bg-woot-25 dark:bg-woot-800/20;
}
</style>
