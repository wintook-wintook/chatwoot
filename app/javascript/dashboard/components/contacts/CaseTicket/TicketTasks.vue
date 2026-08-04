<!--
  @tickets_cases — Tareas / subtareas del ticket (osTicket "Tasks").
  Tabla con paginación + modal de alta/edición. El completado deja firma
  (fecha/hora + quién), que el backend deriva del cambio de estado.
  Autónomo (usa caseTasks API).
-->
<script>
import { mapGetters } from 'vuex';
import { VeTable } from 'vue-easytable';
import CaseTasksAPI from 'dashboard/api/caseTasks';
import TableFooter from 'dashboard/components/widgets/TableFooter.vue';
import WootMessageEditor from 'dashboard/components/widgets/WootWriter/Editor.vue';
import MessageFormatter from 'shared/helpers/MessageFormatter';
import caseAiWriter from 'dashboard/mixins/caseAiWriter';

const PER_PAGE = 10;

// Prioridad PROPIA de la tarea (no la del ticket). Mismos colores que usa la
// bandeja de tareas para que un punto rojo signifique lo mismo en las dos.
const PRIORITY_DOT = {
  urgent: 'bg-red-500',
  high: 'bg-orange-500',
  medium: 'bg-blue-500',
  low: 'bg-slate-400',
};

// Para ordenar por importancia real, no alfabéticamente ("alta" < "baja").
const PRIORITY_RANK = { low: 0, medium: 1, high: 2, urgent: 3 };

export default {
  name: 'TicketTasks',
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
      tasks: [],
      isLoading: false,
      isSaving: false,
      // Paginación en cliente: un ticket tiene decenas de tareas, no miles;
      // traerlas todas evita un contrato de `meta` en el endpoint.
      currentPage: 1,
      perPage: PER_PAGE,
      // Filtro de texto (título / descripción / responsable).
      filterText: '',
      // Orden por click en encabezado. Por defecto la más reciente primero.
      sortConfig: { sequence: 'desc' },
      sortOption: {
        sortAlways: true,
        sortChange: params => this.onSortChange(params),
      },
      // Modal de alta/edición
      showModal: false,
      editingId: null,
      viewing: false, // modal en modo lectura (ticket cerrado)
      form: {
        title: '',
        description: '',
        assignee_id: '',
        due_at: '',
        status: 'pending',
        priority: 'medium',
      },
      // Tarea que se está completando desde la fila (para el spinner del botón).
      completingId: null,
      // Modal de confirmación de borrado
      showDeleteConfirm: false,
      pendingDelete: null,
    };
  },
  computed: {
    ...mapGetters({ agents: 'agents/getAgents' }),
    // Campo de `form` sobre el que actúa la IA (mixin caseAiWriter).
    aiFieldName() {
      return 'description';
    },
    doneCount() {
      return this.tasks.filter(t => t.status === 'done').length;
    },
    // Etiquetas de prioridad: las mismas que usa el ticket, para no traducir dos veces.
    priorityOptions() {
      return this.$t('CASE_TICKETS.PRIORITIES');
    },
    // Filtro de texto: título, descripción y responsable.
    filteredTasks() {
      const q = this.filterText.trim().toLowerCase();
      if (!q) return this.tasks;
      return this.tasks.filter(
        t =>
          (t.title || '').toLowerCase().includes(q) ||
          this.plainPreview(t.description).toLowerCase().includes(q) ||
          (this.assigneeName(t) || '').toLowerCase().includes(q)
      );
    },
    // Orden por la columna activa (una sola a la vez).
    sortedTasks() {
      const [field, dir] = Object.entries(this.sortConfig)[0] || [];
      const rows = [...this.filteredTasks];
      if (!field || !dir) return rows;
      const factor = dir === 'asc' ? 1 : -1;
      return rows.sort((a, b) => this.compareBy(a, b, field) * factor);
    },
    totalPages() {
      return Math.max(1, Math.ceil(this.sortedTasks.length / this.perPage));
    },
    paginatedTasks() {
      const start = (this.currentPage - 1) * this.perPage;
      return this.sortedTasks.slice(start, start + this.perPage);
    },
    isEditing() {
      return !!this.editingId;
    },
    // Subtítulo del modal según el modo (crear / editar / ver).
    modalDescription() {
      if (this.viewing) return this.$t('CASE_TICKETS.TASKS.MODAL.VIEW_DESC');
      if (this.isEditing) return this.$t('CASE_TICKETS.TASKS.MODAL.EDIT_DESC');
      return this.$t('CASE_TICKETS.TASKS.MODAL.NEW_DESC');
    },
    // Click en la fila abre editar (o ver, si el ticket está cerrado). Se ignora
    // si el click fue sobre el checkbox o un botón de acción de la fila.
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
    // Columnas de VeTable. Las celdas se pintan con renderBodyCell (JSX), que es
    // como lo hace Chatwoot en ContactsTable.
    columns() {
      return [
        {
          // Consecutivo estable por ticket (T001, T002…), estilo osTicket.
          field: 'sequence',
          key: 'sequence',
          title: this.$t('CASE_TICKETS.TASKS.TABLE.NUM'),
          align: 'left',
          width: 64,
          sortBy: this.sortConfig.sequence || '',
          // Color del folio según estado: verde concluida, rojo atrasada, azul
          // en tiempo. Tonos claros (shade 300/400) para que no pesen.
          renderBodyCell: ({ row }) => (
            <span
              class={`font-mono text-sm font-semibold whitespace-nowrap ${this.seqClass(
                row
              )}`}
            >
              {this.seqLabel(row.sequence)}
            </span>
          ),
        },
        {
          field: 'title',
          key: 'title',
          title: this.$t('CASE_TICKETS.TASKS.TABLE.TASK'),
          align: 'left',
          width: 340,
          sortBy: this.sortConfig.title || '',
          // Título + descripción recortados a una línea al ancho de la columna
          // (como las notas). El contenido completo con formato va en el modal.
          renderBodyCell: ({ row }) => (
            <div class="overflow-hidden">
              <p
                class={
                  row.status === 'done'
                    ? 'm-0 text-sm truncate line-through text-slate-400 dark:text-slate-500'
                    : 'm-0 text-sm truncate text-slate-800 dark:text-slate-100'
                }
                title={row.title}
              >
                {row.title}
              </p>
              {row.description ? (
                <p
                  class="m-0 mt-0.5 text-xs truncate text-slate-500 dark:text-slate-400"
                  title={this.plainPreview(row.description)}
                >
                  {this.plainPreview(row.description)}
                </p>
              ) : null}
            </div>
          ),
        },
        {
          // Prioridad de la TAREA, independiente de la del ticket.
          field: 'priority',
          key: 'priority',
          title: this.$t('CASE_TICKETS.TASKS.TABLE.PRIORITY'),
          align: 'left',
          width: 120,
          sortBy: this.sortConfig.priority || '',
          renderBodyCell: ({ row }) => (
            <span class="inline-flex items-center gap-1.5 whitespace-nowrap">
              <span
                class={`inline-block w-2 h-2 rounded-full flex-shrink-0 ${this.priorityDot(
                  row.priority
                )}`}
              />
              <span class="text-sm text-slate-600 dark:text-slate-300">
                {this.priorityLabel(row.priority)}
              </span>
            </span>
          ),
        },
        {
          field: 'assignee',
          key: 'assignee',
          title: this.$t('CASE_TICKETS.TASKS.TABLE.ASSIGNEE'),
          align: 'left',
          width: 150,
          sortBy: this.sortConfig.assignee || '',
          renderBodyCell: ({ row }) => this.assigneeName(row) || '—',
        },
        {
          field: 'due_at',
          key: 'due_at',
          title: this.$t('CASE_TICKETS.TASKS.TABLE.DUE'),
          align: 'left',
          width: 160,
          sortBy: this.sortConfig.due_at || '',
          renderBodyCell: ({ row }) => (
            <span
              class={
                this.isOverdue(row)
                  ? 'text-xs font-bold text-red-600 dark:text-red-400'
                  : 'text-xs text-slate-600 dark:text-slate-300'
              }
            >
              {this.formatDate(row.due_at) || '—'}
            </span>
          ),
        },
        {
          // @tickets_cases — Estado y firma de completado en UNA columna: tener
          // "Estado: Concluida" al lado de la fecha decía dos veces lo mismo.
          //   pendiente → botón rojo "Completar" (el propio botón es el estado)
          //   concluida → "03/08/2026, 11:24" y debajo quién la cerró
          field: 'status',
          key: 'status',
          title: this.$t('CASE_TICKETS.TASKS.TABLE.STATUS'),
          align: 'left',
          width: 180,
          sortBy: this.sortConfig.status || '',
          renderBodyCell: ({ row }) => {
            if (row.status !== 'done') {
              // Ticket cerrado: no hay acción posible, pero el estado se sigue
              // leyendo (antes esta celda quedaba en blanco).
              if (this.isFrozen) {
                return (
                  <span class="text-sm text-slate-600 dark:text-slate-300">
                    {this.statusLabel(row.status)}
                  </span>
                );
              }
              return (
                <woot-button
                  size="small"
                  class-names="!px-3.5"
                  variant="smooth"
                  color-scheme="alert"
                  icon="checkmark"
                  is-loading={this.completingId === row.id}
                  disabled={!!this.completingId}
                  title={this.$t('CASE_TICKETS.TASKS.COMPLETE_TITLE')}
                  onClick={() => this.complete(row)}
                >
                  {this.$t('CASE_TICKETS.TASKS.COMPLETE')}
                </woot-button>
              );
            }
            // Concluida sin firma (tareas anteriores a completed_at): no se
            // inventa fecha ni autor, pero sí se dice que está concluida.
            if (!row.completed_at) {
              return (
                <span class="text-sm text-green-600 dark:text-green-400">
                  {this.statusLabel(row.status)}
                </span>
              );
            }
            return (
              <div>
                <span class="text-xs text-green-600 dark:text-green-400">
                  {this.formatDate(row.completed_at)}
                </span>
                {row.completed_by ? (
                  <span class="block text-xs text-slate-400 dark:text-slate-500">
                    {row.completed_by.name}
                  </span>
                ) : null}
              </div>
            );
          },
        },
        {
          // @tickets_cases — cuántas notas cuelgan de la tarea. Click = ver esas
          // notas (abre la pestaña Notas filtrada por su folio).
          field: 'notes_count',
          key: 'notes_count',
          title: this.$t('CASE_TICKETS.TASKS.TABLE.NOTES'),
          align: 'right',
          width: 90,
          sortBy: this.sortConfig.notes_count || '',
          renderBodyCell: ({ row }) => {
            const count = row.notes_count || 0;
            return (
              <button
                class={`inline-flex items-center gap-1 px-1.5 py-0.5 rounded text-xs font-semibold transition-colors ${
                  count
                    ? 'text-woot-600 dark:text-woot-300 hover:bg-woot-50 dark:hover:bg-woot-800/40'
                    : 'text-slate-300 dark:text-slate-600'
                }`}
                title={
                  count
                    ? this.$t('CASE_TICKETS.TASKS.NOTES_COUNT_TITLE', { count })
                    : this.$t('CASE_TICKETS.TASKS.NOTES_NONE')
                }
                onClick={() => this.onNotesClick(row)}
              >
                <fluent-icon icon="clipboard" size="14" />
                {count}
              </button>
            );
          },
        },
        {
          field: 'id',
          key: 'actions',
          title: '',
          width: 120,
          align: 'left',
          // Editar/ver es por click en la fila. Aquí quedan "agregar nota" (crea
          // una nota atada a esta tarea) y borrar (con confirmación).
          // Cerrado: solo lectura, sin acciones.
          renderBodyCell: ({ row }) =>
            this.isFrozen ? null : (
              <div class="button-wrapper">
                <woot-button
                  size="large"
                  variant="clear"
                  color-scheme="secondary"
                  icon="comment-add"
                  title={this.$t('CASE_TICKETS.TASKS.ADD_NOTE')}
                  onClick={() => this.$emit('addNote', row)}
                />
                <woot-button
                  size="large"
                  variant="clear"
                  color-scheme="alert"
                  icon="delete"
                  title={this.$t('CASE_TICKETS.TASKS.DELETE')}
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
    // @tickets_cases P4 — reporta el total al padre (badge del tab "Tareas").
    tasks() {
      this.$emit('count', this.tasks.length);
      // Si borrar dejó la última página vacía, retroceder para no ver un hueco.
      if (this.currentPage > this.totalPages)
        this.currentPage = this.totalPages;
    },
    // Al filtrar, vuelve a la primera página para no quedar en una vacía.
    filterText() {
      this.currentPage = 1;
    },
  },
  mounted() {
    this.$store.dispatch('agents/get');
    this.load();
  },
  methods: {
    // Recarga la tabla desde el servidor (botón "Actualizar").
    refresh() {
      this.load();
    },
    // Click en el contador de notas: si hay notas las muestra; si no, solo avisa
    // (no tiene sentido ir a Notas para no encontrar nada).
    onNotesClick(task) {
      if (task.notes_count > 0) {
        this.$emit('viewNotes', task);
      } else {
        this.$emitter.emit('caseToastMessage', {
          message: this.$t('CASE_TICKETS.TASKS.NOTES_NONE_TOAST', {
            folio: this.seqLabel(task.sequence),
          }),
          icon: 'clipboard',
        });
      }
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
      if (field === 'notes_count')
        return (a.notes_count || 0) - (b.notes_count || 0);
      if (field === 'title')
        return (a.title || '').localeCompare(b.title || '');
      // Columna Estado: primero las pendientes, y entre las concluidas por
      // fecha de completado (la firma es lo que se ve en la celda).
      if (field === 'status') {
        const rank = t => (t.status === 'done' ? 1 : 0);
        return (
          rank(a) - rank(b) ||
          new Date(a.completed_at || 0) - new Date(b.completed_at || 0)
        );
      }
      // Por importancia, no por nombre: "Alta" iría antes que "Baja" alfabéticamente.
      if (field === 'priority')
        return (
          (PRIORITY_RANK[a.priority] ?? 1) - (PRIORITY_RANK[b.priority] ?? 1)
        );
      if (field === 'assignee')
        return (this.assigneeName(a) || '').localeCompare(
          this.assigneeName(b) || ''
        );
      if (field === 'due_at')
        return new Date(a.due_at || 0) - new Date(b.due_at || 0);
      return 0;
    },
    async load() {
      if (!this.ticketId) return;
      this.isLoading = true;
      try {
        const { data } = await CaseTasksAPI.getAll(this.ticketId);
        this.tasks = data.case_tasks || [];
      } finally {
        this.isLoading = false;
      }
    },
    // Completa la tarea desde la fila, sin abrir el modal. El backend deriva la
    // firma (fecha + quién) del cambio de estado, así que basta con el status.
    async complete(task) {
      if (this.completingId) return;
      this.completingId = task.id;
      try {
        const { data } = await CaseTasksAPI.updateTask(this.ticketId, task.id, {
          status: 'done',
        });
        this.replace(data.case_task);
        this.$emitter.emit('caseToastMessage', {
          message: this.$t('CASE_TICKETS.TASKS.TOAST_COMPLETED', {
            task: task.title,
          }),
          icon: 'checkmark',
        });
      } catch (e) {
        this.$emitter.emit('newToastMessage', {
          message: this.$t('CASE_TICKETS.TASKS.COMPLETE_ERROR'),
        });
      } finally {
        this.completingId = null;
      }
    },
    priorityDot(priority) {
      return PRIORITY_DOT[priority] || PRIORITY_DOT.medium;
    },
    priorityLabel(key) {
      return this.priorityOptions[key] || key;
    },
    openCreate() {
      this.editingId = null;
      this.viewing = false;
      this.form = {
        title: '',
        description: '',
        assignee_id: '',
        due_at: '',
        status: 'pending',
        priority: 'medium',
      };
      this.resetAi();
      this.showModal = true;
      this.$nextTick(() => this.$refs.titleInput?.focus());
    },
    openEdit(task) {
      this.editingId = task.id;
      this.viewing = false;
      this.loadForm(task);
      this.resetAi();
      this.showModal = true;
      this.$nextTick(() => this.$refs.titleInput?.focus());
    },
    // Ticket cerrado: abre la tarea en modo lectura (ver el detalle, no cambiarlo).
    openView(task) {
      this.editingId = task.id;
      this.viewing = true;
      this.loadForm(task);
      this.resetAi();
      this.showModal = true;
    },
    loadForm(task) {
      this.form = {
        title: task.title || '',
        description: task.description || '',
        assignee_id: task.assignee_id || '',
        due_at: this.toInputDate(task.due_at),
        status: task.status || 'pending',
        priority: task.priority || 'medium',
      };
    },
    async submitForm() {
      const title = this.form.title.trim();
      if (!title || this.isSaving) return;
      const payload = {
        title,
        description: this.form.description.trim(),
        assignee_id: this.form.assignee_id || '',
        due_at: this.form.due_at || null,
        status: this.form.status || 'pending',
        priority: this.form.priority || 'medium',
      };
      this.isSaving = true;
      try {
        if (this.isEditing) {
          const { data } = await CaseTasksAPI.updateTask(
            this.ticketId,
            this.editingId,
            payload
          );
          this.replace(data.case_task);
        } else {
          const { data } = await CaseTasksAPI.createTask(
            this.ticketId,
            payload
          );
          this.tasks = [...this.tasks, data.case_task];
          // Por defecto la más reciente va primero: saltamos a la página 1 para
          // ver la tarea recién creada arriba.
          this.currentPage = 1;
        }
        this.showModal = false;
      } finally {
        this.isSaving = false;
      }
    },
    // Etiqueta del estado (como la tabla de tickets muestra el estado del ticket).
    statusLabel(status) {
      return status === 'done'
        ? this.$t('CASE_TICKETS.TASKS.STATUS.DONE')
        : this.$t('CASE_TICKETS.TASKS.STATUS.PENDING');
    },
    // Preview en texto plano para la tabla: renderiza el markdown y le quita las
    // etiquetas, así la fila no muestra `**` ni HTML.
    plainPreview(text) {
      if (!text) return '';
      const tmp = document.createElement('div');
      tmp.innerHTML = this.formatMarkdown(text);
      return (tmp.textContent || '').replace(/\s+/g, ' ').trim();
    },
    // Pide confirmación antes de borrar (modal estándar de Chatwoot).
    remove(task) {
      this.pendingDelete = task;
      this.showDeleteConfirm = true;
    },
    closeDeleteConfirm() {
      this.showDeleteConfirm = false;
      this.pendingDelete = null;
    },
    async confirmRemove() {
      const task = this.pendingDelete;
      if (!task) return;
      this.showDeleteConfirm = false;
      await CaseTasksAPI.deleteTask(this.ticketId, task.id);
      this.tasks = this.tasks.filter(t => t.id !== task.id);
      this.pendingDelete = null;
      // Aviso en rojo (mismo toast que asignar/completar, variante danger).
      this.$emitter.emit('caseToastMessage', {
        message: this.$t('CASE_TICKETS.TASKS.TOAST_DELETED', {
          task: task.title,
        }),
        icon: 'delete',
        variant: 'danger',
      });
    },
    replace(updated) {
      this.tasks = this.tasks.map(t => (t.id === updated.id ? updated : t));
    },
    changePage(page) {
      this.currentPage = Math.min(Math.max(1, page), this.totalPages);
    },
    assigneeName(task) {
      return task.assignee ? task.assignee.name : '';
    },
    // Etiqueta del consecutivo: T001, T012… (relleno a 3 dígitos).
    seqLabel(n) {
      if (!n) return '';
      return `T${String(n).padStart(3, '0')}`;
    },
    // Color del folio por estado (tonos claros): verde concluida, rojo atrasada,
    // azul en tiempo.
    seqClass(task) {
      if (task.status === 'done') return 'text-green-400 dark:text-green-300';
      if (this.isOverdue(task)) return 'text-red-400 dark:text-red-300';
      return 'text-woot-400 dark:text-woot-300';
    },
    // Renderiza el markdown de la descripción a HTML seguro (mismo formateador
    // que usan las notas de contacto).
    formatMarkdown(text) {
      if (!text) return '';
      return new MessageFormatter(text).formattedMessage;
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
    // `datetime-local` necesita `YYYY-MM-DDTHH:mm` en hora local, no el ISO UTC.
    toInputDate(iso) {
      if (!iso) return '';
      const d = new Date(iso);
      const pad = n => String(n).padStart(2, '0');
      return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(
        d.getDate()
      )}T${pad(d.getHours())}:${pad(d.getMinutes())}`;
    },
    isOverdue(task) {
      return (
        task.status !== 'done' &&
        task.due_at &&
        new Date(task.due_at) < new Date()
      );
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
        {{ $t('CASE_TICKETS.TASKS.TITLE') }}
        <span
          v-if="tasks.length"
          class="ml-1 text-sm font-normal text-slate-400 dark:text-slate-500"
          >{{ doneCount }}/{{ tasks.length }}</span
        >
      </h3>
      <div class="flex items-center gap-2">
        <woot-button
          v-tooltip.top="$t('CASE_TICKETS.TASKS.REFRESH')"
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
          {{ $t('CASE_TICKETS.TASKS.ADD') }}
        </woot-button>
      </div>
    </div>

    <!-- Filtro rápido de la tabla -->
    <div v-if="tasks.length" class="flex-shrink-0 mb-3">
      <div class="relative w-full max-w-xs">
        <fluent-icon
          icon="search"
          size="16"
          class="absolute pointer-events-none text-slate-400 dark:text-slate-500 left-2.5 top-1/2 -translate-y-1/2"
        />
        <input
          v-model="filterText"
          type="text"
          :placeholder="$t('CASE_TICKETS.TASKS.FILTER_PLACEHOLDER')"
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

    <div v-if="isLoading && !tasks.length" class="py-2 text-sm text-slate-400">
      {{ $t('CASE_TICKETS.TASKS.LOADING') }}
    </div>
    <div
      v-else-if="!tasks.length"
      class="py-2 text-sm text-slate-400 dark:text-slate-500"
    >
      {{ $t('CASE_TICKETS.TASKS.EMPTY') }}
    </div>
    <div
      v-else-if="!sortedTasks.length"
      class="py-2 text-sm text-slate-400 dark:text-slate-500"
    >
      {{ $t('CASE_TICKETS.TASKS.NO_MATCHES') }}
    </div>

    <!-- Tabla nativa de Chatwoot (vue-easytable). `fixed-header` + `max-height`
         hacen que scrolleen solo las filas; el pie queda siempre abajo. -->
    <div v-else class="flex-1 min-h-0 tasks-table-wrap">
      <VeTable
        fixed-header
        max-height="100%"
        row-key-field-name="id"
        :columns="columns"
        :table-data="paginatedTasks"
        :event-custom-option="eventCustomOption"
        :sort-option="sortOption"
        :border-around="false"
      />
    </div>

    <!-- Paginación: componente estándar de Chatwoot, igual que en Seguimientos.
         Se queda abajo aunque haya una sola tarea (solo desaparece con cero). -->
    <TableFooter
      v-if="sortedTasks.length"
      :current-page="currentPage"
      :total-count="sortedTasks.length"
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
              ? $t('CASE_TICKETS.TASKS.MODAL.VIEW_TITLE')
              : isEditing
              ? $t('CASE_TICKETS.TASKS.MODAL.EDIT_TITLE')
              : $t('CASE_TICKETS.TASKS.MODAL.NEW_TITLE')
          "
          :header-content="modalDescription"
        />

        <form
          class="flex flex-col self-stretch w-full gap-3 pb-8"
          @submit.prevent="submitForm"
        >
          <label class="block mb-3">
            <span class="text-sm text-slate-700 dark:text-slate-200">{{
              $t('CASE_TICKETS.TASKS.MODAL.TITLE_LABEL')
            }}</span>
            <input
              ref="titleInput"
              v-model="form.title"
              type="text"
              maxlength="255"
              :readonly="viewing"
              class="read-only:opacity-70 read-only:cursor-default"
              :placeholder="$t('CASE_TICKETS.TASKS.ADD_PLACEHOLDER')"
            />
          </label>

          <!-- OJO: contenedor <div>, NO <label>. El editor incluye un
               <input type=file> oculto; si estuviera dentro de un <label>,
               cualquier click reenviaría al input y abriría "adjuntar archivo". -->
          <div class="block mb-3">
            <span class="text-sm text-slate-700 dark:text-slate-200">{{
              $t('CASE_TICKETS.TASKS.MODAL.DESCRIPTION_LABEL')
            }}</span>
            <!-- Editor enriquecido, montado igual que en Respuestas predefinidas. -->
            <div v-if="!viewing" class="editor-wrap">
              <WootMessageEditor
                v-model="form.description"
                class="message-editor"
                :enable-suggestions="false"
                :enable-canned-responses="false"
                :focus-on-mount="false"
                :placeholder="
                  $t('CASE_TICKETS.TASKS.MODAL.DESCRIPTION_PLACEHOLDER')
                "
              />
            </div>
            <!-- Ticket cerrado: solo lectura, se muestra el formato ya renderizado. -->
            <div
              v-else
              class="prose-note p-2 text-sm border rounded-md border-slate-200 dark:border-slate-600 text-slate-700 dark:text-slate-100"
              v-html="formatMarkdown(form.description) || '—'"
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
                :disabled="!form.description.trim() || !!aiLoading"
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
                :disabled="!form.description.trim() || !!aiLoading"
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

          <div class="flex gap-3">
            <label class="flex-1">
              <span class="text-sm text-slate-700 dark:text-slate-200">{{
                $t('CASE_TICKETS.TASKS.MODAL.ASSIGNEE_LABEL')
              }}</span>
              <select v-model="form.assignee_id" :disabled="viewing">
                <option value="">
                  {{ $t('CASE_TICKETS.TASKS.UNASSIGNED') }}
                </option>
                <option v-for="a in agents" :key="a.id" :value="a.id">
                  {{ a.name }}
                </option>
              </select>
            </label>

            <label class="flex-1">
              <span class="text-sm text-slate-700 dark:text-slate-200">{{
                $t('CASE_TICKETS.TASKS.MODAL.DUE_LABEL')
              }}</span>
              <input
                v-model="form.due_at"
                type="datetime-local"
                :readonly="viewing"
                class="w-full h-10 p-2 bg-white border rounded-md border-slate-200 dark:border-slate-600 dark:bg-slate-900 text-slate-800 dark:text-slate-100"
              />
            </label>
          </div>

          <!-- Estado y prioridad. El estado también se cambia desde la fila con
               el botón "Completar"; aquí además se puede reabrir la tarea. -->
          <div class="flex gap-3">
            <label class="flex-1">
              <span class="text-sm text-slate-700 dark:text-slate-200">{{
                $t('CASE_TICKETS.TASKS.MODAL.STATUS_LABEL')
              }}</span>
              <select v-model="form.status" :disabled="viewing">
                <option value="pending">
                  {{ $t('CASE_TICKETS.TASKS.STATUS.PENDING') }}
                </option>
                <option value="done">
                  {{ $t('CASE_TICKETS.TASKS.STATUS.DONE') }}
                </option>
              </select>
            </label>

            <!-- Prioridad propia de la tarea: no se hereda del ticket. -->
            <label class="flex-1">
              <span class="text-sm text-slate-700 dark:text-slate-200">{{
                $t('CASE_TICKETS.TASKS.MODAL.PRIORITY_LABEL')
              }}</span>
              <select v-model="form.priority" :disabled="viewing">
                <option
                  v-for="(label, key) in priorityOptions"
                  :key="key"
                  :value="key"
                >
                  {{ label }}
                </option>
              </select>
            </label>
          </div>

          <div class="flex items-center justify-end gap-2 mt-4">
            <woot-button
              variant="clear"
              type="button"
              @click="showModal = false"
            >
              {{
                viewing
                  ? $t('CASE_TICKETS.TASKS.MODAL.CLOSE')
                  : $t('CASE_TICKETS.TASKS.MODAL.CANCEL')
              }}
            </woot-button>
            <woot-button
              v-if="!viewing"
              :is-loading="isSaving"
              :disabled="!form.title.trim()"
              type="submit"
            >
              {{ $t('CASE_TICKETS.TASKS.MODAL.SAVE') }}
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
      :title="$t('CASE_TICKETS.TASKS.DELETE_CONFIRM.TITLE')"
      :message="$t('CASE_TICKETS.TASKS.DELETE_CONFIRM.MESSAGE')"
      :message-value="pendingDelete ? `“${pendingDelete.title}”` : ''"
      :confirm-text="$t('CASE_TICKETS.TASKS.DELETE_CONFIRM.CONFIRM')"
      :reject-text="$t('CASE_TICKETS.TASKS.DELETE_CONFIRM.CANCEL')"
    />
  </div>
</template>

<style lang="scss" scoped>
// Mismos ajustes que usan las otras tablas del fork: celdas compactas y
// cabecera en minúscula-mini. El resto del tema (colores claro/oscuro) sale del
// global `_woot-tables.scss`.
.tasks-table-wrap {
  overflow: hidden;
}

.tasks-table-wrap::v-deep {
  // VeTable mete un div `.ve-table` entre el wrapper y el contenedor scrolleable.
  // Sin altura definida aquí, el `max-height: 100%` del contenedor no resuelve
  // (porcentaje contra `auto`) y la tabla se desborda de la card en vez de
  // scrollear. Con esto la cadena de alturas queda completa.
  .ve-table {
    height: 100%;
  }

  .ve-table-header-th {
    padding: var(--space-small) var(--space-one) !important;
    font-size: var(--font-size-mini) !important;
  }

  // Centrado vertical: las filas tienen alturas distintas (la tarea puede traer
  // descripción, el estado fecha + autor). Con `top` los textos de una sola
  // línea quedaban pegados arriba y la fila se leía desalineada.
  .ve-table-body-td {
    padding: var(--space-small) var(--space-one) !important;
    vertical-align: middle;
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

// Markdown renderizado (celda de la tabla y modo lectura): recupera viñetas y
// márgenes que el reset de Tailwind quita.
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
