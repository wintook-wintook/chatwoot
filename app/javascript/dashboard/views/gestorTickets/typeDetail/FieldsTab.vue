<!--
  @tickets_cases
  Pestaña "Campos" del detalle de un Tipo de Caso. Tabla nativa (vue-easytable)
  con los campos personalizados + paginado inferior, y un modal enfocado para
  alta/edición. Estos campos se piden al crear/editar un ticket de este tipo.
-->
<script>
import { mapGetters } from 'vuex';
import { VeTable } from 'vue-easytable';
import TableFooter from 'dashboard/components/widgets/TableFooter.vue';

const FIELD_TYPE_KEYS = ['text', 'number', 'date', 'list', 'checkbox'];
const PER_PAGE_OPTIONS = [25, 50, 100];

const emptyForm = () => ({
  key: '',
  label: '',
  field_type: 'text',
  required: false,
  optionsText: '',
});

export default {
  name: 'FieldsTab',
  components: { VeTable, TableFooter },
  props: {
    caseTypeId: {
      type: Number,
      required: true,
    },
  },
  data() {
    return {
      fieldTypeKeys: FIELD_TYPE_KEYS,
      showModal: false,
      editingField: null,
      form: emptyForm(),
      showDeleteModal: false,
      fieldToDelete: null,
      deletingId: null,
      currentPage: 1,
      perPage: 25,
      perPageOptions: PER_PAGE_OPTIONS,
    };
  },
  computed: {
    ...mapGetters({
      getTypeFields: 'caseTickets/getTypeFields',
      uiFlags: 'caseTickets/getTypeFieldsUIFlags',
    }),
    fields() {
      return this.getTypeFields(this.caseTypeId);
    },
    isFetching() {
      return this.uiFlags.isFetching;
    },
    isSaving() {
      return this.uiFlags.isSaving;
    },
    pagedFields() {
      const start = (this.currentPage - 1) * this.perPage;
      return this.fields.slice(start, start + this.perPage);
    },
    parsedOptions() {
      return (this.form.optionsText || '')
        .split(',')
        .map(o => o.trim())
        .filter(Boolean);
    },
    formValid() {
      if (!this.form.label.trim() || !/^[a-z][a-z0-9_]*$/.test(this.form.key)) {
        return false;
      }
      if (this.form.field_type === 'list') return this.parsedOptions.length > 0;
      return true;
    },
    deleteMessageValue() {
      return this.fieldToDelete ? ` "${this.fieldToDelete.label}"?` : '';
    },
    columns() {
      return [
        {
          field: 'label',
          key: 'label',
          title: this.$t('CASE_TICKETS.CUSTOM_FIELDS.LABEL_LABEL'),
          align: 'left',
          renderBodyCell: ({ row }) => (
            <div class="flex items-center gap-2 min-w-0">
              <span class="text-sm font-medium truncate text-slate-800 dark:text-slate-100">
                {row.label}
              </span>
              {row.required ? (
                <span class="px-1.5 py-0.5 text-xs rounded bg-red-100 text-red-700 dark:bg-red-900/40 dark:text-red-300">
                  {this.$t('CASE_TICKETS.CUSTOM_FIELDS.REQUIRED_BADGE')}
                </span>
              ) : null}
            </div>
          ),
        },
        {
          field: 'key',
          key: 'key',
          title: this.$t('CASE_TICKETS.CUSTOM_FIELDS.KEY_LABEL'),
          align: 'left',
          width: 180,
          renderBodyCell: ({ row }) => (
            <span class="font-mono text-xs text-slate-500 dark:text-slate-400">
              {row.key}
            </span>
          ),
        },
        {
          field: 'field_type',
          key: 'field_type',
          title: this.$t('CASE_TICKETS.CUSTOM_FIELDS.TYPE_LABEL'),
          align: 'left',
          width: 140,
          renderBodyCell: ({ row }) => (
            <span class="text-sm text-slate-600 dark:text-slate-300">
              {this.$t(`CASE_TICKETS.CUSTOM_FIELDS.TYPES.${row.field_type}`)}
            </span>
          ),
        },
        {
          field: 'options',
          key: 'options',
          title: this.$t('CASE_TICKETS.CUSTOM_FIELDS.OPTIONS_HEADER'),
          align: 'left',
          renderBodyCell: ({ row }) =>
            row.field_type === 'list' && (row.options || []).length ? (
              <span class="text-xs text-slate-500 dark:text-slate-400">
                {(row.options || []).join(', ')}
              </span>
            ) : (
              <span class="text-slate-300 dark:text-slate-600">—</span>
            ),
        },
        {
          field: 'actions',
          key: 'actions',
          title: '',
          align: 'right',
          width: 100,
          renderBodyCell: ({ row }) => (
            <div class="flex items-center justify-end gap-1">
              <woot-button
                size="tiny"
                variant="clear"
                color-scheme="secondary"
                icon="edit"
                onClick={() => this.openEdit(row)}
              />
              <woot-button
                size="tiny"
                variant="clear"
                color-scheme="alert"
                icon="delete"
                isLoading={this.deletingId === row.id}
                onClick={() => this.openDelete(row)}
              />
            </div>
          ),
        },
      ];
    },
  },
  mounted() {
    this.$store.dispatch('caseTickets/fetchTypeFields', this.caseTypeId);
  },
  methods: {
    openCreate() {
      this.editingField = null;
      this.form = emptyForm();
      this.showModal = true;
    },
    openEdit(field) {
      this.editingField = field;
      this.form = {
        key: field.key,
        label: field.label,
        field_type: field.field_type,
        required: field.required,
        optionsText: (field.options || []).join(', '),
      };
      this.showModal = true;
    },
    closeModal() {
      this.showModal = false;
      this.editingField = null;
      this.form = emptyForm();
    },
    onKeyInput() {
      this.form.key = (this.form.key || '')
        .toLowerCase()
        .replace(/[^a-z0-9_]/g, '');
    },
    async save() {
      if (!this.formValid) return;
      const payload = {
        caseTypeId: this.caseTypeId,
        key: this.form.key,
        label: this.form.label.trim(),
        field_type: this.form.field_type,
        required: this.form.required,
        options: this.form.field_type === 'list' ? this.parsedOptions : [],
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
        this.closeModal();
        this.$emit('changed');
      } catch (e) {
        const msg =
          e?.response?.data?.error?.[0] ||
          this.$t('CASE_TICKETS.CUSTOM_FIELDS.SAVE_ERROR');
        this.$emitter.emit('newToastMessage', { message: msg });
      }
    },
    openDelete(field) {
      this.fieldToDelete = field;
      this.showDeleteModal = true;
    },
    closeDelete() {
      this.showDeleteModal = false;
      this.fieldToDelete = null;
    },
    async confirmDelete() {
      const field = this.fieldToDelete;
      if (!field) return;
      this.showDeleteModal = false;
      this.deletingId = field.id;
      try {
        await this.$store.dispatch('caseTickets/deleteTypeField', {
          caseTypeId: this.caseTypeId,
          id: field.id,
        });
        this.$emit('changed');
      } finally {
        this.deletingId = null;
        this.fieldToDelete = null;
      }
    },
    changePage(page) {
      this.currentPage = page;
    },
    changePerPage() {
      this.currentPage = 1;
    },
  },
};
</script>

<template>
  <div class="flex flex-col flex-1 min-h-0">
    <!-- Toolbar de la pestaña -->
    <div class="flex items-center justify-between flex-shrink-0 px-6 py-3">
      <p class="m-0 text-sm text-slate-500 dark:text-slate-400">
        {{ $t('CASE_TICKETS.CUSTOM_FIELDS.SUBTITLE') }}
      </p>
      <woot-button size="small" icon="add-circle" @click="openCreate">
        {{ $t('CASE_TICKETS.CUSTOM_FIELDS.ADD_BUTTON') }}
      </woot-button>
    </div>

    <!-- Loading inicial -->
    <div
      v-if="isFetching && !fields.length"
      class="flex items-center justify-center flex-1 text-slate-400 dark:text-slate-500"
    >
      <span>{{ $t('CASE_TICKETS.CUSTOM_FIELDS.LOADING') }}</span>
    </div>

    <!-- Empty state -->
    <div
      v-else-if="!fields.length"
      class="flex flex-col items-center justify-center flex-1 gap-4 text-slate-400 dark:text-slate-500"
    >
      <fluent-icon icon="list" size="36" />
      <p class="max-w-sm text-center">
        {{ $t('CASE_TICKETS.CUSTOM_FIELDS.EMPTY') }}
      </p>
      <woot-button size="small" icon="add-circle" @click="openCreate">
        {{ $t('CASE_TICKETS.CUSTOM_FIELDS.ADD_BUTTON') }}
      </woot-button>
    </div>

    <!-- Tabla -->
    <div v-else class="flex-1 min-h-0 px-6 pb-2 fields-table-wrap">
      <VeTable
        fixed-header
        max-height="100%"
        row-key-field-name="id"
        :columns="columns"
        :table-data="pagedFields"
        :border-around="false"
      />
    </div>

    <!-- Paginado inferior -->
    <div
      v-if="fields.length"
      class="flex items-center justify-between flex-shrink-0 border-t border-slate-50 dark:border-slate-800/50"
    >
      <label
        class="flex items-center gap-1 pl-6 text-xs text-slate-500 dark:text-slate-400"
      >
        {{ $t('CASE_TICKETS.TYPES.PER_PAGE') }}
        <select
          v-model.number="perPage"
          class="!mb-0 w-20 text-sm"
          @change="changePerPage"
        >
          <option v-for="n in perPageOptions" :key="n" :value="n">
            {{ n }}
          </option>
        </select>
      </label>
      <TableFooter
        :current-page="currentPage"
        :total-count="fields.length"
        :page-size="perPage"
        @pageChange="changePage"
      />
    </div>

    <!-- Modal alta/edición de campo -->
    <woot-modal
      v-if="showModal"
      :show="showModal"
      :on-close="closeModal"
      size="medium"
    >
      <div class="flex flex-col h-auto overflow-auto">
        <woot-modal-header
          :header-title="
            editingField
              ? $t('CASE_TICKETS.CUSTOM_FIELDS.EDIT_TITLE')
              : $t('CASE_TICKETS.CUSTOM_FIELDS.ADD_TITLE')
          "
        />
        <form
          class="flex flex-col self-stretch w-full gap-4 px-8 pb-8"
          @submit.prevent="save"
        >
          <div class="flex flex-wrap items-end gap-3">
            <label class="flex flex-col flex-1 min-w-[160px] gap-1">
              <span
                class="text-xs font-medium text-slate-600 dark:text-slate-300"
                >{{ $t('CASE_TICKETS.CUSTOM_FIELDS.LABEL_LABEL') }} *</span
              >
              <input
                v-model="form.label"
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
                v-model="form.key"
                type="text"
                class="w-full font-mono !mb-0"
                maxlength="60"
                :disabled="!!editingField"
                :placeholder="$t('CASE_TICKETS.CUSTOM_FIELDS.KEY_PLACEHOLDER')"
                @input="onKeyInput"
              />
            </label>
          </div>
          <div class="flex flex-wrap items-end gap-3">
            <label class="flex flex-col w-44 gap-1">
              <span
                class="text-xs font-medium text-slate-600 dark:text-slate-300"
                >{{ $t('CASE_TICKETS.CUSTOM_FIELDS.TYPE_LABEL') }}</span
              >
              <select v-model="form.field_type" class="w-full !mb-0">
                <option v-for="t in fieldTypeKeys" :key="t" :value="t">
                  {{ $t(`CASE_TICKETS.CUSTOM_FIELDS.TYPES.${t}`) }}
                </option>
              </select>
            </label>
            <label class="flex items-center gap-2 pb-2.5">
              <input v-model="form.required" type="checkbox" />
              <span
                class="text-xs font-medium text-slate-600 dark:text-slate-300"
                >{{ $t('CASE_TICKETS.CUSTOM_FIELDS.REQUIRED_LABEL') }}</span
              >
            </label>
          </div>
          <label v-if="form.field_type === 'list'" class="flex flex-col gap-1">
            <span
              class="text-xs font-medium text-slate-600 dark:text-slate-300"
              >{{ $t('CASE_TICKETS.CUSTOM_FIELDS.OPTIONS_LABEL') }}</span
            >
            <input
              v-model="form.optionsText"
              type="text"
              class="w-full !mb-0"
              :placeholder="
                $t('CASE_TICKETS.CUSTOM_FIELDS.OPTIONS_PLACEHOLDER')
              "
            />
          </label>

          <div class="flex justify-end gap-2 mt-2">
            <woot-button
              variant="clear"
              color-scheme="secondary"
              type="button"
              @click="closeModal"
            >
              {{ $t('CASE_TICKETS.CUSTOM_FIELDS.CANCEL_EDIT') }}
            </woot-button>
            <woot-button
              type="submit"
              :is-loading="isSaving"
              :disabled="!formValid"
            >
              {{
                editingField
                  ? $t('CASE_TICKETS.CUSTOM_FIELDS.SAVE')
                  : $t('CASE_TICKETS.CUSTOM_FIELDS.ADD')
              }}
            </woot-button>
          </div>
        </form>
      </div>
    </woot-modal>

    <!-- Confirmación de borrado -->
    <woot-delete-modal
      :show.sync="showDeleteModal"
      :on-close="closeDelete"
      :on-confirm="confirmDelete"
      :title="$t('CASE_TICKETS.CUSTOM_FIELDS.DELETE.TITLE')"
      :message="$t('CASE_TICKETS.CUSTOM_FIELDS.DELETE.MESSAGE')"
      :message-value="deleteMessageValue"
      :confirm-text="$t('CASE_TICKETS.CUSTOM_FIELDS.DELETE.YES')"
      :reject-text="$t('CASE_TICKETS.CUSTOM_FIELDS.DELETE.NO')"
    />
  </div>
</template>

<style lang="scss" scoped>
.fields-table-wrap {
  overflow: hidden;
}

.fields-table-wrap::v-deep {
  .ve-table {
    height: 100%;
  }
  .ve-table-header-th {
    padding: var(--space-small) var(--space-one) !important;
    font-size: var(--font-size-mini) !important;
  }
  .ve-table-body-td {
    padding: var(--space-small) var(--space-one) !important;
    vertical-align: middle;
  }
}
</style>
