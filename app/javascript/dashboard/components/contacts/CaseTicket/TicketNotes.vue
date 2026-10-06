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
import caseAiWriter from 'dashboard/mixins/caseAiWriter';

const PER_PAGE = 10;

export default {
  name: 'TicketNotes',
  components: { VeTable, TableFooter, WootMessageEditor },
  mixins: [caseAiWriter],
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
      // Filtro de texto (contenido / autor / folio de tarea).
      filterText: '',
      // Orden por click en encabezado. Por defecto la más reciente primero.
      sortConfig: { sequence: 'desc' },
      sortOption: {
        sortAlways: true,
        sortChange: params => this.onSortChange(params),
      },
      showModal: false,
      editingId: null,
      viewing: false, // modal en modo lectura (ticket cerrado)
      form: { content: '' },
      // @tickets_cases — tarea a la que se atará la nota nueva (desde la fila de
      // la tabla de tareas). null = nota del ticket. Solo aplica al crear.
      contextTask: null,
      // Modal de confirmación de borrado
      showDeleteConfirm: false,
      pendingDelete: null,
    };
  },
  computed: {
    // Campo de `form` sobre el que actúa la IA (mixin caseAiWriter).
    aiFieldName() {
      return 'content';
    },
    // Filtro de texto: contenido (plano), autor y folio de la tarea.
    filteredNotes() {
      const q = this.filterText.trim().toLowerCase();
      if (!q) return this.notes;
      return this.notes.filter(n => {
        const folio = n.case_task
          ? this.taskFolio(n.case_task.sequence).toLowerCase()
          : '';
        return (
          this.plainPreview(n.content).toLowerCase().includes(q) ||
          (n.actor?.name || '').toLowerCase().includes(q) ||
          folio.includes(q) ||
          (n.case_task?.title || '').toLowerCase().includes(q)
        );
      });
    },
    // Orden por la columna activa (una sola a la vez).
    sortedNotes() {
      const [field, dir] = Object.entries(this.sortConfig)[0] || [];
      const rows = [...this.filteredNotes];
      if (!field || !dir) return rows;
      const factor = dir === 'asc' ? 1 : -1;
      return rows.sort((a, b) => this.compareBy(a, b, field) * factor);
    },
    totalPages() {
      return Math.max(1, Math.ceil(this.sortedNotes.length / this.perPage));
    },
    paginatedNotes() {
      const start = (this.currentPage - 1) * this.perPage;
      return this.sortedNotes.slice(start, start + this.perPage);
    },
    isEditing() {
      return !!this.editingId;
    },
    // Subtítulo del modal según el modo (crear / editar / ver).
    modalDescription() {
      if (this.viewing) return this.$t('CASE_TICKETS.NOTES.MODAL_VIEW_DESC');
      if (this.isEditing) return this.$t('CASE_TICKETS.NOTES.MODAL_EDIT_DESC');
      return this.$t('CASE_TICKETS.NOTES.MODAL_DESC');
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
          sortBy: this.sortConfig.sequence || '',
          renderBodyCell: ({ row }) => (
            <span class="font-mono text-sm font-semibold whitespace-nowrap text-slate-300 dark:text-slate-500">
              {this.seqLabel(row.sequence)}
            </span>
          ),
        },
        {
          // @tickets_cases — de qué es la nota: folio T00N si cuelga de una
          // tarea, o "—" (guion) si es del ticket mismo (case_task vacío).
          field: 'case_task',
          key: 'case_task',
          title: this.$t('CASE_TICKETS.NOTES.TABLE.TASK'),
          align: 'left',
          width: 90,
          sortBy: this.sortConfig.case_task || '',
          renderBodyCell: ({ row }) =>
            row.case_task ? (
              <span
                class="inline-block px-1.5 py-0.5 font-mono text-xs font-semibold rounded whitespace-nowrap bg-woot-50 text-woot-700 dark:bg-woot-800/40 dark:text-woot-200"
                title={row.case_task.title}
              >
                {this.taskFolio(row.case_task.sequence)}
              </span>
            ) : (
              <span class="text-slate-300 dark:text-slate-600">—</span>
            ),
        },
        {
          field: 'content',
          key: 'content',
          title: this.$t('CASE_TICKETS.NOTES.TABLE.NOTE'),
          align: 'left',
          width: 560,
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
              {/* Debajo de la nota: siempre "Creada el …"; y si se editó,
                  además "Editada el … por …". */}
              <p class="m-0 mt-0.5 text-xs truncate text-slate-400 dark:text-slate-500">
                <span>
                  {this.$t('CASE_TICKETS.NOTES.CREATED', {
                    date: this.formatDate(row.created_at),
                  })}
                </span>
                {row.edited_at ? (
                  <span class="italic">
                    {' · '}
                    {this.$t('CASE_TICKETS.NOTES.EDITED', {
                      date: this.formatDate(row.edited_at),
                      name: row.edited_by || '',
                    })}
                  </span>
                ) : null}
              </p>
            </div>
          ),
        },
        {
          field: 'actor',
          key: 'actor',
          title: this.$t('CASE_TICKETS.NOTES.TABLE.AUTHOR'),
          align: 'left',
          width: 150,
          sortBy: this.sortConfig.actor || '',
          renderBodyCell: ({ row }) => (row.actor ? row.actor.name : '—'),
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
                  size="large"
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
    // Al filtrar, vuelve a la primera página para no quedar en una vacía.
    filterText() {
      this.currentPage = 1;
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
    // @tickets_cases — `task` opcional: si viene (desde la tabla de tareas), la
    // nota nueva queda atada a esa tarea (folio T00N).
    openCreate(task = null) {
      this.editingId = null;
      this.viewing = false;
      this.contextTask = task || null;
      this.form = { content: '' };
      this.resetAi();
      this.showModal = true;
      this.$nextTick(() => this.$refs.contentInput?.focus());
    },
    openEdit(note) {
      this.editingId = note.id;
      this.viewing = false;
      this.contextTask = note.case_task || null;
      this.form = { content: note.content || '' };
      this.resetAi();
      this.showModal = true;
      this.$nextTick(() => this.$refs.contentInput?.focus());
    },
    // Ticket cerrado: abre la nota en modo lectura (ver el detalle, no cambiarlo).
    openView(note) {
      this.editingId = note.id;
      this.viewing = true;
      this.contextTask = note.case_task || null;
      this.form = { content: note.content || '' };
      this.resetAi();
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
            // @tickets_cases — ata la nota a la tarea si se abrió desde su fila.
            case_task_id: this.contextTask?.id || null,
          });
          // Por defecto la más reciente va primero: saltamos a la página 1 para
          // ver la nota recién creada arriba.
          this.notes = [...this.notes, data.case_note];
          this.currentPage = 1;
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
    // Recarga la tabla desde el servidor (botón "Actualizar").
    refresh() {
      this.load();
    },
    // Filtra la tabla por el folio de una tarea (desde la columna "Notas" de la
    // tabla de tareas). El filtro de texto ya matchea el folio T00N.
    showTaskNotes(task) {
      this.filterText = this.taskFolio(task.sequence);
      this.currentPage = 1;
    },
    // VeTable emite { field: 'asc'|'desc'|'' }. Solo una columna activa a la vez.
    onSortChange(params) {
      const field = Object.keys(params).find(k => params[k]);
      this.sortConfig = field ? { [field]: params[field] } : {};
      this.currentPage = 1;
    },
    // Comparador por campo para el orden en cliente.
    compareBy(a, b, field) {
      if (field === 'sequence') return (a.sequence || 0) - (b.sequence || 0);
      if (field === 'created_at')
        return new Date(a.created_at) - new Date(b.created_at);
      if (field === 'case_task')
        return (a.case_task?.sequence || 0) - (b.case_task?.sequence || 0);
      if (field === 'actor')
        return (a.actor?.name || '').localeCompare(b.actor?.name || '');
      return 0;
    },
    seqLabel(n) {
      if (!n) return '';
      return `N${String(n).padStart(3, '0')}`;
    },
    // Folio de la tarea dueña de la nota: T001, T012…
    taskFolio(n) {
      if (!n) return '';
      return `T${String(n).padStart(3, '0')}`;
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
      <div class="flex items-center gap-2">
        <woot-button
          v-tooltip.top="$t('CASE_TICKETS.NOTES.REFRESH')"
          size="small"
          variant="clear"
          color-scheme="secondary"
          icon="arrow-clockwise"
          :is-loading="isLoading"
          @click="refresh"
        />
        <woot-button
          v-if="!isFrozen"
          size="small"
          icon="add"
          @click="openCreate"
        >
          {{ $t('CASE_TICKETS.NOTES.ADD_NEW') }}
        </woot-button>
      </div>
    </div>

    <!-- Filtro rápido de la tabla -->
    <div v-if="notes.length" class="flex-shrink-0 mb-3">
      <div class="relative w-full max-w-xs">
        <fluent-icon
          icon="search"
          size="16"
          class="absolute pointer-events-none text-slate-400 dark:text-slate-500 left-2.5 top-1/2 -translate-y-1/2"
        />
        <input
          v-model="filterText"
          type="text"
          :placeholder="$t('CASE_TICKETS.NOTES.FILTER_PLACEHOLDER')"
          class="filter-search"
        />
        <button
          v-if="filterText"
          class="absolute -translate-y-1/2 right-2 top-1/2 text-slate-400 hover:text-slate-600 dark:hover:text-slate-200"
          @click="filterText = ''"
        >
          <fluent-icon icon="dismiss" size="14" />
        </button>
      </div>
    </div>

    <div v-if="isLoading && !notes.length" class="py-2 text-sm text-slate-400">
      {{ $t('CASE_TICKETS.NOTES.LOADING') }}
    </div>
    <div
      v-else-if="!notes.length"
      class="py-2 text-sm text-slate-400 dark:text-slate-500"
    >
      {{ $t('CASE_TICKETS.NOTES.EMPTY') }}
    </div>
    <div
      v-else-if="!sortedNotes.length"
      class="py-2 text-sm text-slate-400 dark:text-slate-500"
    >
      {{ $t('CASE_TICKETS.NOTES.NO_MATCHES') }}
    </div>

    <div v-else class="flex-1 min-h-0 notes-table-wrap">
      <VeTable
        fixed-header
        max-height="100%"
        row-key-field-name="id"
        :columns="columns"
        :table-data="paginatedNotes"
        :event-custom-option="eventCustomOption"
        :sort-option="sortOption"
        :border-around="false"
      />
    </div>

    <TableFooter
      v-if="sortedNotes.length"
      :current-page="currentPage"
      :total-count="sortedNotes.length"
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
          :header-content="modalDescription"
        />

        <!-- @tickets_cases — a qué pertenece la nota: tarea T00N o el ticket. -->
        <div
          v-if="contextTask"
          class="flex items-center gap-2 px-8 mt-2 mb-1 text-sm text-slate-600 dark:text-slate-300"
        >
          <fluent-icon icon="clipboard" size="16" />
          <span>{{ $t('CASE_TICKETS.NOTES.MODAL_TASK_SCOPE') }}</span>
          <span
            class="inline-block px-1.5 py-0.5 font-mono text-xs font-semibold rounded bg-woot-50 text-woot-700 dark:bg-woot-800/40 dark:text-woot-200"
          >
            {{ taskFolio(contextTask.sequence) }}
          </span>
          <span class="truncate text-slate-500 dark:text-slate-400">{{
            contextTask.title
          }}</span>
        </div>

        <form
          class="flex flex-col self-stretch w-full gap-3 pb-8"
          @submit.prevent="submitForm"
        >
          <!-- OJO: contenedor <div>, NO <label>. El editor incluye un
               <input type=file> oculto; si estuviera dentro de un <label>,
               cualquier click reenviaría al input y abriría "adjuntar archivo". -->
          <div class="block">
            <span class="text-sm text-slate-700 dark:text-slate-200">{{
              $t('CASE_TICKETS.NOTES.CONTENT_LABEL')
            }}</span>
            <!-- Editor enriquecido, montado igual que en Respuestas predefinidas. -->
            <div v-if="!viewing" class="editor-wrap">
              <WootMessageEditor
                v-model="form.content"
                class="message-editor"
                :enable-suggestions="false"
                :enable-canned-responses="false"
                focus-on-mount
                :placeholder="$t('CASE_TICKETS.NOTES.PLACEHOLDER')"
              />
            </div>
            <!-- Ticket cerrado: solo lectura, con el formato ya renderizado. -->
            <div
              v-else
              class="prose-note min-h-[16rem] p-2 text-sm border rounded-md border-slate-200 dark:border-slate-600 text-slate-700 dark:text-slate-100"
              v-html="formatMarkdown(form.content) || '—'"
            />

            <!-- Escritura asistida por IA (mixin caseAiWriter). -->
            <div
              v-if="!viewing && aiEnabled"
              class="flex flex-wrap items-center gap-2 mt-2"
            >
              <woot-button
                type="button"
                size="tiny"
                variant="smooth"
                color-scheme="secondary"
                icon="wand"
                :is-loading="aiLoading === 'fix_spelling_grammar'"
                :disabled="!form.content.trim() || !!aiLoading"
                @click="aiImprove('fix_spelling_grammar')"
              >
                {{ $t('CASE_TICKETS.AI.FIX') }}
              </woot-button>
              <woot-button
                type="button"
                size="tiny"
                variant="smooth"
                color-scheme="secondary"
                icon="wand"
                :is-loading="aiLoading === 'rephrase'"
                :disabled="!form.content.trim() || !!aiLoading"
                @click="aiImprove('rephrase')"
              >
                {{ $t('CASE_TICKETS.AI.IMPROVE') }}
              </woot-button>
              <woot-button
                v-if="canRevertAi"
                type="button"
                size="tiny"
                variant="clear"
                color-scheme="secondary"
                icon="arrow-undo"
                :disabled="!!aiLoading"
                @click="aiRevert"
              >
                {{ $t('CASE_TICKETS.AI.REVERT') }}
              </woot-button>
            </div>
          </div>

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

// Buscador de la tabla: input con lupa a la izquierda, estilo Chatwoot.
.filter-search {
  @apply w-full py-1.5 pl-8 pr-7 text-sm bg-white border rounded-md outline-none
    border-slate-100 dark:border-slate-600 dark:bg-slate-900
    text-slate-700 dark:text-slate-100;

  &::placeholder {
    @apply text-slate-400 dark:text-slate-500;
  }

  &:focus {
    @apply border-woot-500;
  }
}

// Editor enriquecido dentro del modal: caja con borde, barra de formato pegada
// arriba con separador (SIN margen negativo, que era lo que la hacía sobresalir
// por encima del borde) y contenido con su propio padding.
.editor-wrap {
  @apply overflow-hidden bg-white border rounded-md border-slate-200 dark:border-slate-600 dark:bg-slate-900;
}

.message-editor::v-deep {
  .ProseMirror-menubar {
    @apply px-2 py-1 m-0 border-b border-slate-100 dark:border-slate-700 bg-slate-50 dark:bg-slate-800/60;
    min-height: unset;
    border-top-left-radius: 0.375rem;
    border-top-right-radius: 0.375rem;
  }

  .ProseMirror-woot-style {
    @apply px-3 py-2;
    min-height: 9rem;
    max-height: 20rem;
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
