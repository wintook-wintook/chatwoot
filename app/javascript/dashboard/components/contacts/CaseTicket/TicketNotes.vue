<!--
  @tickets_cases — Notas internas del ticket (osTicket "Internal notes").
  Misma estructura que TicketTasks: VeTable + TableFooter + modal de alta/edición.
  La nota NUNCA sale al cliente: vive en case_events, que el User Portal no expone.
-->
<script>
import { VeTable } from 'vue-easytable';
import CaseNotesAPI from 'dashboard/api/caseNotes';
import TableFooter from 'dashboard/components/widgets/TableFooter.vue';

const PER_PAGE = 10;

export default {
  name: 'TicketNotes',
  components: { VeTable, TableFooter },
  props: {
    ticketId: { type: [Number, String], required: true },
    // Ticket cerrado/cancelado = solo lectura: se ocultan las acciones para no
    // ofrecer botones que el backend va a rechazar con 422.
    isFrozen: { type: Boolean, default: false },
  },
  data() {
    return {
      notes: [],
      isLoading: false,
      isSaving: false,
      currentPage: 1,
      perPage: PER_PAGE,
      showModal: false,
      editingId: null,
      form: { content: '' },
    };
  },
  computed: {
    totalPages() {
      return Math.max(1, Math.ceil(this.notes.length / this.perPage));
    },
    paginatedNotes() {
      const start = (this.currentPage - 1) * this.perPage;
      return this.notes.slice(start, start + this.perPage);
    },
    isEditing() {
      return !!this.editingId;
    },
    columns() {
      return [
        {
          field: 'content',
          key: 'content',
          title: this.$t('CASE_TICKETS.NOTES.TABLE.NOTE'),
          align: 'left',
          width: 460,
          // La nota se recorta a una línea con "…" para que la fila no crezca;
          // el texto completo va en el `title` (hover) y en el modal de edición.
          renderBodyCell: ({ row }) => (
            <div class="overflow-hidden">
              <p
                class="m-0 text-sm truncate text-slate-800 dark:text-slate-100"
                title={row.content}
              >
                {row.content}
              </p>
              {row.edited_at ? (
                <p class="m-0 mt-0.5 text-xs italic truncate text-slate-400 dark:text-slate-500">
                  {this.$t('CASE_TICKETS.NOTES.EDITED', {
                    date: this.formatDate(row.edited_at),
                    name: row.edited_by || '',
                  })}
                </p>
              ) : null}
            </div>
          ),
        },
        {
          field: 'actor',
          key: 'actor',
          title: this.$t('CASE_TICKETS.NOTES.TABLE.AUTHOR'),
          align: 'left',
          width: 150,
          renderBodyCell: ({ row }) => (row.actor ? row.actor.name : '—'),
        },
        {
          field: 'created_at',
          key: 'created_at',
          title: this.$t('CASE_TICKETS.NOTES.TABLE.DATE'),
          align: 'left',
          width: 170,
          renderBodyCell: ({ row }) => (
            <span class="text-xs text-slate-600 dark:text-slate-300">
              {this.formatDate(row.created_at)}
            </span>
          ),
        },
        {
          field: 'id',
          key: 'actions',
          title: '',
          width: 90,
          align: 'left',
          // Cerrado = solo lectura: sin editar ni borrar.
          renderBodyCell: ({ row }) =>
            this.isFrozen ? null : (
              <div class="button-wrapper">
                <woot-button
                  size="tiny"
                  variant="clear"
                  color-scheme="secondary"
                  icon="edit"
                  title={this.$t('CASE_TICKETS.NOTES.EDIT')}
                  onClick={() => this.openEdit(row)}
                />
                <woot-button
                  size="tiny"
                  variant="clear"
                  color-scheme="alert"
                  icon="delete"
                  title={this.$t('CASE_TICKETS.NOTES.DELETE')}
                  onClick={() => this.remove(row)}
                />
              </div>
            ),
        },
      ];
    },
  },
  watch: {
    ticketId() {
      this.currentPage = 1;
      this.load();
    },
    // Reporta el total al padre (badge del tab "Notas").
    notes() {
      this.$emit('count', this.notes.length);
      if (this.currentPage > this.totalPages)
        this.currentPage = this.totalPages;
    },
  },
  mounted() {
    this.load();
  },
  methods: {
    async load() {
      if (!this.ticketId) return;
      this.isLoading = true;
      try {
        const { data } = await CaseNotesAPI.getAll(this.ticketId);
        this.notes = data.case_notes || [];
      } finally {
        this.isLoading = false;
      }
    },
    openCreate() {
      this.editingId = null;
      this.form = { content: '' };
      this.showModal = true;
      this.$nextTick(() => this.$refs.contentInput?.focus());
    },
    openEdit(note) {
      this.editingId = note.id;
      this.form = { content: note.content || '' };
      this.showModal = true;
      this.$nextTick(() => this.$refs.contentInput?.focus());
    },
    async submitForm() {
      const content = this.form.content.trim();
      if (!content || this.isSaving) return;
      this.isSaving = true;
      try {
        if (this.isEditing) {
          const { data } = await CaseNotesAPI.updateNote(
            this.ticketId,
            this.editingId,
            { content }
          );
          this.notes = this.notes.map(n =>
            n.id === data.case_note.id ? data.case_note : n
          );
        } else {
          const { data } = await CaseNotesAPI.createNote(this.ticketId, {
            content,
          });
          // Orden cronológico: la nueva va al final. Saltamos a la última
          // página para que se vea recién creada.
          this.notes = [...this.notes, data.case_note];
          this.currentPage = this.totalPages;
        }
        this.showModal = false;
        // El Avance lee los mismos case_events, así que se refresca.
        this.$emit('changed');
      } catch (e) {
        this.$emitter.emit('newToastMessage', {
          message:
            e.response?.data?.error || this.$t('CASE_TICKETS.NOTES.ERROR'),
        });
      } finally {
        this.isSaving = false;
      }
    },
    async remove(note) {
      await CaseNotesAPI.deleteNote(this.ticketId, note.id);
      this.notes = this.notes.filter(n => n.id !== note.id);
      this.$emit('changed');
    },
    changePage(page) {
      this.currentPage = Math.min(Math.max(1, page), this.totalPages);
    },
    formatDate(d) {
      if (!d) return '';
      return new Date(d).toLocaleString(undefined, {
        day: '2-digit',
        month: '2-digit',
        year: 'numeric',
        hour: '2-digit',
        minute: '2-digit',
      });
    },
  },
};
</script>

<template>
  <div
    class="flex flex-col min-h-0 p-4 bg-white border rounded-lg dark:bg-slate-800 border-slate-75 dark:border-slate-700"
  >
    <div class="flex items-center justify-between flex-shrink-0 mb-3">
      <h3
        class="m-0 text-base font-semibold text-slate-800 dark:text-slate-100"
      >
        {{ $t('CASE_TICKETS.NOTES.TITLE') }}
        <span
          v-if="notes.length"
          class="ml-1 text-sm font-normal text-slate-400 dark:text-slate-500"
          >{{ notes.length }}</span
        >
      </h3>
      <woot-button v-if="!isFrozen" size="small" icon="add" @click="openCreate">
        {{ $t('CASE_TICKETS.NOTES.ADD_NEW') }}
      </woot-button>
    </div>

    <div v-if="isLoading" class="py-2 text-sm text-slate-400">
      {{ $t('CASE_TICKETS.NOTES.LOADING') }}
    </div>
    <div
      v-else-if="!notes.length"
      class="py-2 text-sm text-slate-400 dark:text-slate-500"
    >
      {{ $t('CASE_TICKETS.NOTES.EMPTY') }}
    </div>

    <div v-else class="flex-1 min-h-0 notes-table-wrap">
      <VeTable
        fixed-header
        max-height="100%"
        row-key-field-name="id"
        :columns="columns"
        :table-data="paginatedNotes"
        :border-around="false"
      />
    </div>

    <TableFooter
      :current-page="currentPage"
      :total-count="notes.length"
      :page-size="perPage"
      class="flex-shrink-0 !px-0 border-t border-slate-75 dark:border-slate-700"
      @pageChange="changePage"
    />

    <!-- Modal de alta / edición -->
    <woot-modal
      v-if="showModal"
      :show="showModal"
      :on-close="() => (showModal = false)"
      size="medium"
    >
      <div class="flex flex-col h-auto overflow-auto">
        <woot-modal-header
          :header-title="
            isEditing
              ? $t('CASE_TICKETS.NOTES.MODAL_EDIT_TITLE')
              : $t('CASE_TICKETS.NOTES.MODAL_TITLE')
          "
        />

        <form
          class="flex flex-col self-stretch w-full gap-3 pb-8"
          @submit.prevent="submitForm"
        >
          <label class="block">
            <span class="text-sm text-slate-700 dark:text-slate-200">{{
              $t('CASE_TICKETS.NOTES.CONTENT_LABEL')
            }}</span>
            <textarea
              ref="contentInput"
              v-model="form.content"
              rows="12"
              class="min-h-[16rem] resize-y"
              :placeholder="$t('CASE_TICKETS.NOTES.PLACEHOLDER')"
            />
          </label>

          <p
            class="flex items-center gap-1 m-0 text-xs text-amber-700 dark:text-amber-300"
          >
            <fluent-icon icon="info" size="14" />
            {{ $t('CASE_TICKETS.NOTES.HINT') }}
          </p>

          <div class="flex items-center justify-end gap-2">
            <woot-button
              variant="clear"
              type="button"
              @click="showModal = false"
            >
              {{ $t('CASE_TICKETS.NOTES.CANCEL') }}
            </woot-button>
            <woot-button
              :is-loading="isSaving"
              :disabled="!form.content.trim()"
              type="submit"
            >
              {{ $t('CASE_TICKETS.NOTES.SAVE') }}
            </woot-button>
          </div>
        </form>
      </div>
    </woot-modal>
  </div>
</template>

<style lang="scss" scoped>
// Mismos ajustes que TicketTasks y el resto de tablas del fork.
.notes-table-wrap {
  overflow: hidden;
}

.notes-table-wrap::v-deep {
  // Ver TicketTasks.vue: sin `height: 100%` aquí, el `max-height: 100%` del
  // contenedor no resuelve y la tabla se desborda de la card.
  .ve-table {
    height: 100%;
  }

  .ve-table-header-th {
    padding: var(--space-small) var(--space-one) !important;
    font-size: var(--font-size-mini) !important;
  }

  .ve-table-body-td {
    padding: var(--space-small) var(--space-one) !important;
    vertical-align: top;
  }

  .button-wrapper {
    @apply flex flex-row gap-1;
  }
}
</style>
