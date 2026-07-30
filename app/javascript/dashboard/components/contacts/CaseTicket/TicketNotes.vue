<!--
  @tickets_cases — Notas internas del ticket (osTicket "Internal notes").
  Misma estructura que TicketTasks: VeTable + TableFooter + modal de alta/edición.
  La nota NUNCA sale al cliente: vive en case_events, que el User Portal no expone.
-->
<script>
import { VeTable } from 'vue-easytable';
import CaseNotesAPI from 'dashboard/api/caseNotes';
import TableFooter from 'dashboard/components/widgets/TableFooter.vue';
import WootMessageEditor from 'dashboard/components/widgets/WootWriter/Editor.vue';
import MessageFormatter from 'shared/helpers/MessageFormatter';

const PER_PAGE = 10;

export default {
  name: 'TicketNotes',
  components: { VeTable, TableFooter, WootMessageEditor },
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
      viewing: false, // modal en modo lectura (ticket cerrado)
      form: { content: '' },
      // Modal de confirmación de borrado
      showDeleteConfirm: false,
      pendingDelete: null,
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
    // Click en la fila abre editar (o ver, si el ticket está cerrado). Se ignora
    // si el click fue sobre un botón de acción de la fila.
    eventCustomOption() {
      return {
        bodyRowEvents: ({ row }) => ({
          click: event => {
            if (event.target.closest('button, input, a')) return;
            if (this.isFrozen) this.openView(row);
            else this.openEdit(row);
          },
        }),
      };
    },
    columns() {
      return [
        {
          // Consecutivo estable por ticket (N001, N002…), estilo osTicket.
          field: 'sequence',
          key: 'sequence',
          title: this.$t('CASE_TICKETS.NOTES.TABLE.NUM'),
          align: 'left',
          width: 64,
          renderBodyCell: ({ row }) => (
            <span class="font-mono text-sm font-semibold whitespace-nowrap text-slate-300 dark:text-slate-500">
              {this.seqLabel(row.sequence)}
            </span>
          ),
        },
        {
          field: 'content',
          key: 'content',
          title: this.$t('CASE_TICKETS.NOTES.TABLE.NOTE'),
          align: 'left',
          width: 460,
          // La nota se recorta a una línea con "…" para que la fila no crezca;
          // el texto completo (con formato) va en el modal. En la tabla se muestra
          // un preview en texto plano (sin marcas de markdown).
          renderBodyCell: ({ row }) => (
            <div class="overflow-hidden">
              <p
                class="m-0 text-sm truncate text-slate-800 dark:text-slate-100"
                title={this.plainPreview(row.content)}
              >
                {row.post_closure ? (
                  <span
                    class="inline-block mr-2 px-1.5 py-0.5 align-middle text-[10px] font-medium uppercase tracking-wide rounded bg-amber-100 text-amber-800 dark:bg-amber-900/40 dark:text-amber-300"
                    title={this.$t('CASE_TICKETS.NOTES.POST_CLOSURE_HINT')}
                  >
                    {this.$t('CASE_TICKETS.NOTES.POST_CLOSURE')}
                  </span>
                ) : null}
                {this.plainPreview(row.content)}
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
          // Cerrado: solo se puede ABRIR la nota para ver el detalle completo
          // (la tabla la recorta), pero no editarla ni borrarla.
          // Editar/ver es por click en la fila. Aquí solo queda borrar (con
          // confirmación). Cerrado: solo lectura, sin borrar.
          renderBodyCell: ({ row }) =>
            this.isFrozen ? null : (
              <div class="button-wrapper">
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
      this.viewing = false;
      this.form = { content: '' };
      this.showModal = true;
      this.$nextTick(() => this.$refs.contentInput?.focus());
    },
    openEdit(note) {
      this.editingId = note.id;
      this.viewing = false;
      this.form = { content: note.content || '' };
      this.showModal = true;
      this.$nextTick(() => this.$refs.contentInput?.focus());
    },
    // Ticket cerrado: abre la nota en modo lectura (ver el detalle, no cambiarlo).
    openView(note) {
      this.editingId = note.id;
      this.viewing = true;
      this.form = { content: note.content || '' };
      this.showModal = true;
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
    // Pide confirmación antes de borrar (modal estándar de Chatwoot).
    remove(note) {
      this.pendingDelete = note;
      this.showDeleteConfirm = true;
    },
    closeDeleteConfirm() {
      this.showDeleteConfirm = false;
      this.pendingDelete = null;
    },
    async confirmRemove() {
      const note = this.pendingDelete;
      if (!note) return;
      this.showDeleteConfirm = false;
      await CaseNotesAPI.deleteNote(this.ticketId, note.id);
      this.notes = this.notes.filter(n => n.id !== note.id);
      this.pendingDelete = null;
      this.$emit('changed');
      // Aviso en rojo (mismo toast que asignar/completar, variante danger).
      this.$emitter.emit('caseToastMessage', {
        message: this.$t('CASE_TICKETS.NOTES.TOAST_DELETED'),
        icon: 'delete',
        variant: 'danger',
      });
    },
    changePage(page) {
      this.currentPage = Math.min(Math.max(1, page), this.totalPages);
    },
    // Etiqueta del consecutivo: N001, N012… (relleno a 3 dígitos).
    seqLabel(n) {
      if (!n) return '';
      return `N${String(n).padStart(3, '0')}`;
    },
    // Markdown → HTML seguro (mismo formateador que las notas de contacto).
    formatMarkdown(text) {
      if (!text) return '';
      return new MessageFormatter(text).formattedMessage;
    },
    // Preview en texto plano para la tabla: renderiza el markdown y le quita las
    // etiquetas, así la fila no muestra `**` ni `#` ni HTML.
    plainPreview(text) {
      if (!text) return '';
      const tmp = document.createElement('div');
      tmp.innerHTML = this.formatMarkdown(text);
      return (tmp.textContent || '').replace(/\s+/g, ' ').trim();
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
        :event-custom-option="eventCustomOption"
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
      :close-on-backdrop-click="false"
      size="medium"
    >
      <div class="flex flex-col h-auto overflow-auto">
        <woot-modal-header
          :header-title="
            viewing
              ? $t('CASE_TICKETS.NOTES.MODAL_VIEW_TITLE')
              : isEditing
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
            <!-- Editor enriquecido (markdown), el mismo de las notas de contacto. -->
            <WootMessageEditor
              v-if="!viewing"
              v-model="form.content"
              class="input--rich"
              :enable-suggestions="false"
              :enable-canned-responses="false"
              focus-on-mount
              :placeholder="$t('CASE_TICKETS.NOTES.PLACEHOLDER')"
            />
            <!-- Ticket cerrado: solo lectura, con el formato ya renderizado. -->
            <div
              v-else
              class="prose-note min-h-[16rem] p-2 text-sm border rounded-md border-slate-200 dark:border-slate-600 text-slate-700 dark:text-slate-100"
              v-html="formatMarkdown(form.content) || '—'"
            />
          </label>

          <p
            v-if="!viewing"
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
              {{
                viewing
                  ? $t('CASE_TICKETS.NOTES.CLOSE')
                  : $t('CASE_TICKETS.NOTES.CANCEL')
              }}
            </woot-button>
            <woot-button
              v-if="!viewing"
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

    <!-- Confirmación de borrado (modal estándar de Chatwoot) -->
    <woot-delete-modal
      :show="showDeleteConfirm"
      :on-close="closeDeleteConfirm"
      :on-confirm="confirmRemove"
      :title="$t('CASE_TICKETS.NOTES.DELETE_CONFIRM.TITLE')"
      :message="$t('CASE_TICKETS.NOTES.DELETE_CONFIRM.MESSAGE')"
      :confirm-text="$t('CASE_TICKETS.NOTES.DELETE_CONFIRM.CONFIRM')"
      :reject-text="$t('CASE_TICKETS.NOTES.DELETE_CONFIRM.CANCEL')"
    />
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

// Editor enriquecido dentro del modal: mismo ajuste de menubar que las notas
// de contacto y una altura contenida.
.input--rich {
  @apply border border-slate-200 dark:border-slate-600 rounded-md px-2;

  ::v-deep .ProseMirror-menubar {
    padding: 0;
    margin-top: var(--space-minus-small);
  }

  ::v-deep .ProseMirror-woot-style {
    min-height: 16rem;
    max-height: 24rem;
  }
}

// Markdown renderizado (modo lectura): recupera viñetas y márgenes que el reset
// de Tailwind quita.
.prose-note::v-deep {
  ul {
    @apply list-disc ml-4;
  }
  ol {
    @apply list-decimal ml-4;
  }
  p {
    @apply m-0;
  }
  a {
    @apply underline text-woot-500;
  }
  code {
    @apply px-1 rounded bg-slate-100 dark:bg-slate-700;
  }
}
</style>
