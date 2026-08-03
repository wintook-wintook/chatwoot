<!--
  @tickets_cases
  Lista de tipos de caso — tabla nativa de Chatwoot (vue-easytable) + paginado
  inferior (TableFooter), igual que la cola de tickets. Cada fila abre el detalle
  del tipo (campos personalizados + columnas del tablero) en su propia pantalla.
-->
<script>
import { mapGetters } from 'vuex';
import { VeTable } from 'vue-easytable';
import TableFooter from 'dashboard/components/widgets/TableFooter.vue';
import TypeFormModal from './typeDetail/TypeFormModal.vue';

const PER_PAGE_OPTIONS = [25, 50, 100];

export default {
  name: 'TicketTypes',
  components: { VeTable, TableFooter, TypeFormModal },
  data() {
    return {
      showModal: false,
      editing: null,
      deletingId: null,
      showDeleteModal: false,
      typeToDelete: null,
      currentPage: 1,
      perPage: 25,
      perPageOptions: PER_PAGE_OPTIONS,
      // Fila = abrir el detalle del tipo; los botones de acción cortan la
      // propagación para no navegar.
      eventCustomOption: {
        bodyRowEvents: ({ row }) => ({
          click: () => this.openDetail(row),
        }),
      },
      rowStyleOption: {
        stripe: false,
        clickHighlight: false,
        hoverHighlight: true,
      },
    };
  },
  computed: {
    ...mapGetters({
      types: 'caseTickets/getTypes',
      typesUiFlags: 'caseTickets/getTypesUIFlags',
    }),
    isFetching() {
      return this.typesUiFlags.isFetching;
    },
    deleteMessageValue() {
      return this.typeToDelete ? ` "${this.typeToDelete.name}"?` : '';
    },
    pagedTypes() {
      const start = (this.currentPage - 1) * this.perPage;
      return this.types.slice(start, start + this.perPage);
    },
    columns() {
      return [
        {
          field: 'name',
          key: 'name',
          title: this.$t('CASE_TICKETS.TYPES.TABLE.NAME'),
          align: 'left',
          renderBodyCell: ({ row }) => (
            <div class="flex items-center min-w-0 gap-3">
              <span
                class="flex-shrink-0 w-3 h-3 rounded-full"
                style={{ backgroundColor: row.color }}
              />
              <span class="text-sm font-medium truncate text-slate-800 dark:text-slate-100">
                {row.name}
              </span>
            </div>
          ),
        },
        {
          field: 'prefix',
          key: 'prefix',
          title: this.$t('CASE_TICKETS.TYPES.TABLE.PREFIX'),
          align: 'left',
          width: 120,
          renderBodyCell: ({ row }) =>
            row.prefix ? (
              <span class="px-1.5 py-0.5 font-mono text-xs rounded bg-slate-100 text-slate-600 dark:bg-slate-700 dark:text-slate-300">
                {row.prefix}
              </span>
            ) : (
              <span class="text-slate-300 dark:text-slate-600">—</span>
            ),
        },
        {
          field: 'fields',
          key: 'fields',
          title: this.$t('CASE_TICKETS.TYPES.TABLE.FIELDS'),
          align: 'center',
          width: 100,
          renderBodyCell: ({ row }) => this.countBadge(this.fieldsCount(row)),
        },
        {
          field: 'columns',
          key: 'columns',
          title: this.$t('CASE_TICKETS.TYPES.TABLE.COLUMNS'),
          align: 'center',
          width: 100,
          renderBodyCell: ({ row }) => this.countBadge(this.columnsCount(row)),
        },
        {
          field: 'visibility',
          key: 'visibility',
          title: this.$t('CASE_TICKETS.TYPES.TABLE.VISIBILITY'),
          align: 'left',
          width: 130,
          renderBodyCell: ({ row }) => (
            <div onClick={e => e.stopPropagation()}>
              <woot-button
                size="tiny"
                variant={row.public ? 'smooth' : 'clear'}
                color-scheme={row.public ? 'success' : 'secondary'}
                icon="globe"
                onClick={() => this.togglePublic(row)}
              >
                {row.public
                  ? this.$t('CASE_TICKETS.TYPES.PUBLIC_ON')
                  : this.$t('CASE_TICKETS.TYPES.PUBLIC_OFF')}
              </woot-button>
            </div>
          ),
        },
        {
          field: 'actions',
          key: 'actions',
          title: this.$t('CASE_TICKETS.TYPES.TABLE.ACTIONS'),
          align: 'right',
          width: 140,
          renderBodyCell: ({ row }) => (
            <div
              class="flex items-center justify-end gap-1"
              onClick={e => e.stopPropagation()}
            >
              <woot-button
                size="tiny"
                variant="clear"
                color-scheme="secondary"
                icon="edit"
                title={this.$t('CASE_TICKETS.TYPES.EDIT_TITLE')}
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
              <woot-button
                size="tiny"
                variant="clear"
                color-scheme="secondary"
                icon="chevron-right"
                title={this.$t('CASE_TICKETS.TYPES.OPEN')}
                onClick={() => this.openDetail(row)}
              />
            </div>
          ),
        },
      ];
    },
  },
  mounted() {
    this.$store.dispatch('caseTickets/fetchTypes');
  },
  methods: {
    fieldsCount(type) {
      return (type.custom_fields || []).length;
    },
    columnsCount(type) {
      return (type.columns || []).length;
    },
    countBadge(n) {
      const cls = n
        ? 'bg-woot-100 text-woot-700 dark:bg-woot-800 dark:text-woot-100'
        : 'bg-slate-100 text-slate-400 dark:bg-slate-700 dark:text-slate-500';
      return (
        <span class={`px-2 py-0.5 text-xs font-medium rounded-full ${cls}`}>
          {n}
        </span>
      );
    },
    openDetail(type) {
      this.$router.push({
        name: 'gestorTickets_type_detail',
        params: { typeId: type.id },
      });
    },
    openCreate() {
      this.editing = null;
      this.showModal = true;
    },
    openEdit(type) {
      this.editing = type;
      this.showModal = true;
    },
    onSaved() {
      this.$store.dispatch('caseTickets/fetchTypes');
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
          {{ $t('CASE_TICKETS.TYPES.DETAIL.BACK') }}
        </woot-button>
        <h1 class="m-0 text-xl font-bold text-slate-800 dark:text-slate-100">
          {{ $t('CASE_TICKETS.TYPES.TITLE') }}
        </h1>
      </div>
      <woot-button size="small" icon="add-circle" @click="openCreate">
        {{ $t('CASE_TICKETS.TYPES.CREATE_BUTTON') }}
      </woot-button>
    </div>

    <!-- Loading inicial -->
    <div
      v-if="isFetching && !types.length"
      class="flex items-center justify-center flex-1 text-slate-400 dark:text-slate-500"
    >
      <span>{{ $t('CASE_TICKETS.TYPES.DETAIL.LOADING') }}</span>
    </div>

    <!-- Empty state -->
    <div
      v-else-if="!types.length"
      class="flex flex-col items-center justify-center flex-1 gap-4 text-slate-400 dark:text-slate-500"
    >
      <fluent-icon icon="tag" size="40" />
      <p class="max-w-sm text-center">{{ $t('CASE_TICKETS.TYPES.EMPTY') }}</p>
      <woot-button size="small" icon="add-circle" @click="openCreate">
        {{ $t('CASE_TICKETS.TYPES.CREATE_BUTTON') }}
      </woot-button>
    </div>

    <!-- Tabla + ayuda -->
    <div v-else class="flex flex-col flex-1 min-h-0">
      <p
        class="flex-shrink-0 px-6 pt-4 m-0 text-sm text-slate-500 dark:text-slate-400"
      >
        {{ $t('CASE_TICKETS.TYPES.HELP') }}
      </p>
      <div class="flex-1 min-h-0 px-6 py-4 types-table-wrap">
        <VeTable
          fixed-header
          max-height="100%"
          row-key-field-name="id"
          :columns="columns"
          :table-data="pagedTypes"
          :border-around="false"
          :event-custom-option="eventCustomOption"
          :row-style-option="rowStyleOption"
        />
      </div>
    </div>

    <!-- Paginado inferior estándar de Chatwoot -->
    <div
      v-if="types.length"
      class="flex items-center justify-between flex-shrink-0 bg-white border-t dark:bg-slate-900 border-slate-50 dark:border-slate-800/50"
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
        :total-count="types.length"
        :page-size="perPage"
        @pageChange="changePage"
      />
    </div>

    <!-- Modal crear/editar tipo (compartido con el detalle) -->
    <TypeFormModal
      :show="showModal"
      :editing="editing"
      @saved="onSaved"
      @close="showModal = false"
    />

    <!-- Confirmación de borrado -->
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

<style lang="scss" scoped>
// Mismos ajustes de densidad que la cola de tickets: cabecera mini, celdas
// compactas y que scrolleen solo las filas.
.types-table-wrap {
  overflow: hidden;
}

.types-table-wrap::v-deep {
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
    cursor: pointer;
  }
}
</style>
