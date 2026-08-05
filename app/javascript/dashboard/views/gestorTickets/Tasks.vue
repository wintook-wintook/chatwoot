<!--
  @tickets_cases — Bandeja de tareas (nivel cuenta)
  Responde "¿qué tengo asignado?" sin entrar ticket por ticket. Ahora usa la
  MISMA tabla nativa (vue-easytable) + modal de edición que las tareas dentro del
  ticket, sumando una columna con el contexto del ticket (folio, tipo, prioridad)
  porque aquí las tareas son de todos los tickets. Paginación en servidor.
-->
<script>
import { mapGetters } from 'vuex';
import { VeTable } from 'vue-easytable';
import TableFooter from 'dashboard/components/widgets/TableFooter.vue';
import WootMessageEditor from 'dashboard/components/widgets/WootWriter/Editor.vue';
import WootDropdownMenu from 'shared/components/ui/dropdown/DropdownMenu.vue';
import WootDropdownItem from 'shared/components/ui/dropdown/DropdownItem.vue';
import MessageFormatter from 'shared/helpers/MessageFormatter';
import CaseTasksAPI from 'dashboard/api/caseTasks';
import caseAiWriter from 'dashboard/mixins/caseAiWriter';

// Filtros rápidos por ámbito de asignación (mismo patrón que el Kanban).
const QUICK_FILTERS = [
  { key: 'mine', label: 'MINE' },
  { key: 'unassigned', label: 'UNASSIGNED' },
  { key: 'all', label: 'ALL' },
  { key: 'overdue', label: 'OVERDUE' },
];

const PRIORITY_DOT = {
  urgent: 'bg-red-500',
  high: 'bg-orange-500',
  medium: 'bg-blue-500',
  low: 'bg-slate-400',
};

// El backend pagina de 25 en 25 (CaseTasksIndexController::PER_PAGE).
const PER_PAGE = 25;

export default {
  name: 'TicketTasksInbox',
  components: {
    VeTable,
    TableFooter,
    WootMessageEditor,
    WootDropdownMenu,
    WootDropdownItem,
  },
  mixins: [caseAiWriter],
  data() {
    return {
      quickFilters: QUICK_FILTERS,
      quickFilter: 'mine',
      filters: {
        status: 'pending',
        due: '',
        assignee_id: '',
        case_type_id: '',
        q: '',
      },
      searchDebounce: null,
      overdueCount: 0,
      currentPage: 1,
      perPage: PER_PAGE,
      // Modal de edición / lectura (no hay alta: una tarea nace dentro de un ticket).
      showModal: false,
      editingTask: null,
      viewing: false,
      isSaving: false,
      form: {
        title: '',
        description: '',
        assignee_id: '',
        due_at: '',
        status: 'pending',
        priority: 'medium',
        // Solicitante: fijo si ya existe (requester_locked=true); en tareas
        // antiguas sin solicitante se puede elegir de la lista y se guarda.
        requester_name: '',
        requester_id: '',
        requester_locked: true,
      },
      // Menú de acciones por fila (posición fija fuera de la tabla). { row, top, left }.
      rowMenu: null,
      // Tarea que se está completando desde la fila (para el spinner del botón).
      completingId: null,
      // Confirmación de borrado
      showDeleteConfirm: false,
      pendingDelete: null,
    };
  },
  computed: {
    ...mapGetters({
      tasks: 'caseTickets/getMyTasks',
      meta: 'caseTickets/getMyTasksMeta',
      uiFlags: 'caseTickets/getMyTasksUIFlags',
      types: 'caseTickets/getTypes',
      agents: 'agents/getAgents',
      currentUserID: 'getCurrentUserID',
      currentUser: 'getCurrentUser',
    }),
    // Nombre del agente actual (fallback del solicitante en tareas antiguas).
    currentUserName() {
      return this.currentUser ? this.currentUser.name : '';
    },
    // Campo de `form` sobre el que actúa la IA (mixin caseAiWriter).
    aiFieldName() {
      return 'description';
    },
    isFetching() {
      return this.uiFlags.isFetching;
    },
    totalCount() {
      return this.meta.count || 0;
    },
    activeQuickTabIndex() {
      const i = QUICK_FILTERS.findIndex(f => f.key === this.quickFilter);
      return i < 0 ? 0 : i;
    },
    priorityOptions() {
      return this.$t('CASE_TICKETS.PRIORITIES');
    },
    isEditing() {
      return !!this.editingTask;
    },
    // Click en la fila abre editar (o ver, si el ticket está cerrado). Ignora el
    // click si cayó sobre un botón/input/enlace (folio, acciones).
    eventCustomOption() {
      return {
        bodyRowEvents: ({ row }) => ({
          click: event => {
            if (event.target.closest('button, input, a')) return;
            if (this.ticketFrozen(row)) this.openView(row);
            else this.openEdit(row);
          },
        }),
      };
    },
    columns() {
      return [
        {
          // Folio consecutivo de la tarea (T001…), coloreado por estado igual
          // que dentro del ticket: verde concluida, rojo atrasada, azul en tiempo.
          // A su izquierda, el botón "…" con el menú de acciones (misma columna).
          field: 'sequence',
          key: 'sequence',
          title: this.$t('CASE_TICKETS.TASKS.TABLE.NUM'),
          align: 'left',
          width: 112,
          renderBodyCell: ({ row }) => (
            <div class="flex items-center gap-2">
              {this.ticketFrozen(row) ? null : (
                <woot-button
                  size="small"
                  variant="smooth"
                  color-scheme="secondary"
                  icon="navigation"
                  title={this.$t('CASE_TICKETS.TASKS.ACTIONS')}
                  onClick={e => this.openRowMenu(e, row)}
                />
              )}
              <span
                class={`font-mono text-sm font-semibold whitespace-nowrap ${this.seqClass(
                  row
                )}`}
              >
                {this.seqLabel(row.sequence)}
              </span>
            </div>
          ),
        },
        {
          field: 'ticket',
          key: 'ticket',
          title: this.$t('CASE_TICKETS.TASKS.INBOX.TICKET_COL'),
          align: 'left',
          width: 260,
          renderBodyCell: ({ row }) => {
            const t = row.case_ticket;
            if (!t) {
              return <span class="text-slate-300 dark:text-slate-600">—</span>;
            }
            return (
              <div class="min-w-0">
                <button
                  type="button"
                  class={`font-mono text-sm font-semibold hover:underline ${this.slaTextColor(
                    t.sla_status
                  )}`}
                  title={this.$t('CASE_TICKETS.TASKS.INBOX.OPEN_TICKET')}
                  onClick={() => this.openTicket(row)}
                >
                  {t.folio || `#${t.id}`}
                </button>
                <div class="flex items-center gap-1.5 mt-1 min-w-0">
                  {t.case_type ? (
                    <span
                      class="px-1.5 py-0.5 text-[10px] font-medium uppercase tracking-wide rounded text-white flex-shrink-0"
                      style={{ backgroundColor: t.case_type.color }}
                    >
                      {t.case_type.name}
                    </span>
                  ) : null}
                  <span
                    class={`inline-block w-2 h-2 rounded-full flex-shrink-0 ${this.priorityDot(
                      t.priority
                    )}`}
                    title={this.priorityLabel(t.priority)}
                  />
                  <span class="text-xs truncate text-slate-500 dark:text-slate-400">
                    {t.title}
                  </span>
                </div>
              </div>
            );
          },
        },
        {
          field: 'title',
          key: 'title',
          title: this.$t('CASE_TICKETS.TASKS.TABLE.TASK'),
          align: 'left',
          width: 320,
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
          // Prioridad de la TAREA. No confundir con el punto de color de la
          // columna "Ticket", que es la prioridad del ticket padre.
          field: 'priority',
          key: 'priority',
          title: this.$t('CASE_TICKETS.TASKS.TABLE.PRIORITY'),
          align: 'left',
          width: 115,
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
          // @tickets_cases — solicitante (quién abrió la tarea). Solo lectura.
          field: 'requester',
          key: 'requester',
          title: this.$t('CASE_TICKETS.TASKS.TABLE.REQUESTER'),
          align: 'left',
          width: 140,
          renderBodyCell: ({ row }) =>
            this.requesterName(row) || (
              <span class="text-slate-300 dark:text-slate-600">—</span>
            ),
        },
        {
          field: 'assignee',
          key: 'assignee',
          title: this.$t('CASE_TICKETS.TASKS.TABLE.ASSIGNEE'),
          align: 'left',
          width: 140,
          renderBodyCell: ({ row }) =>
            this.assigneeName(row) || (
              <span class="text-slate-300 dark:text-slate-600">
                {this.$t('CASE_TICKETS.TASKS.INBOX.UNASSIGNED')}
              </span>
            ),
        },
        {
          field: 'due_at',
          key: 'due_at',
          title: this.$t('CASE_TICKETS.TASKS.TABLE.DUE'),
          align: 'left',
          width: 150,
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
          width: 170,
          renderBodyCell: ({ row }) => {
            if (row.status !== 'done') {
              // Ticket cerrado: no hay acción posible, pero el estado se sigue
              // leyendo (antes esta celda quedaba en blanco).
              if (this.ticketFrozen(row)) {
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
      ];
    },
  },
  mounted() {
    this.$store.dispatch('agents/get');
    this.$store.dispatch('caseTickets/fetchTypes');
    this.fetch();
    this.refreshOverdueCount();
  },
  methods: {
    // Traduce ámbito (pestaña + dropdown de agente) a `assignee_id` del endpoint.
    resolveAssignee() {
      if (this.filters.assignee_id !== '') return this.filters.assignee_id;
      if (this.quickFilter === 'unassigned') return 'unassigned';
      if (this.quickFilter === 'mine') return this.currentUserID;
      return 'all'; // all / overdue
    },
    buildParams() {
      const p = { assignee_id: this.resolveAssignee(), page: this.currentPage };
      if (this.filters.status) p.status = this.filters.status;
      if (this.filters.case_type_id) p.case_type_id = this.filters.case_type_id;
      if (this.filters.q) p.q = this.filters.q;
      const due = this.quickFilter === 'overdue' ? 'overdue' : this.filters.due;
      if (due) p.due = due;
      return p;
    },
    async fetch() {
      await this.$store.dispatch(
        'caseTickets/fetchMyTasks',
        this.buildParams()
      );
      // Si un borrado dejó la página actual vacía, retrocede para no ver un hueco.
      if (!this.tasks.length && this.currentPage > 1 && this.totalCount > 0) {
        this.currentPage = Math.max(
          1,
          Math.ceil(this.totalCount / this.perPage)
        );
        this.$store.dispatch('caseTickets/fetchMyTasks', this.buildParams());
      }
    },
    async refreshOverdueCount() {
      try {
        const { data } = await CaseTasksAPI.getMine({
          assignee_id: 'all',
          status: 'pending',
          due: 'overdue',
          page: 1,
        });
        this.overdueCount = (data.meta && data.meta.count) || 0;
      } catch (e) {
        this.overdueCount = 0;
      }
    },
    onQuickTabChange(index) {
      this.quickFilter = QUICK_FILTERS[index].key;
      this.currentPage = 1;
      this.fetch();
    },
    onFilterChange() {
      this.currentPage = 1;
      this.fetch();
    },
    onSearchInput() {
      clearTimeout(this.searchDebounce);
      this.searchDebounce = setTimeout(() => {
        this.currentPage = 1;
        this.fetch();
      }, 350);
    },
    clearSearch() {
      this.filters.q = '';
      this.currentPage = 1;
      this.fetch();
    },
    changePage(page) {
      this.currentPage = page;
      this.fetch();
    },
    // ── Contexto / navegación ──────────────────────────────────────
    ticketFrozen(task) {
      const st = task.case_ticket && task.case_ticket.status;
      return st === 'closed' || st === 'cancelled';
    },
    openTicket(task) {
      if (!task.case_ticket) return;
      this.$router.push({
        name: 'gestorTickets_detail',
        params: { id: task.case_ticket.id },
      });
    },
    // ── Menú de acciones por fila ──────────────────────────────────
    // Menú anclado al botón "…" con posición FIJA (fuera de la tabla, que
    // recorta con overflow). Decide arriba/abajo según el espacio libre.
    openRowMenu(event, row) {
      const btn = (event.target && event.target.closest('button')) || null;
      if (!btn) return;
      const rect = btn.getBoundingClientRect();
      const MENU_W = 224;
      const MENU_H = 150;
      const up = rect.bottom + MENU_H > window.innerHeight;
      // Se abre hacia la DERECHA (borde izquierdo alineado al botón); si no cabe,
      // se recorta para no salirse por el lado derecho de la ventana.
      this.rowMenu = {
        row,
        left: Math.min(rect.left, window.innerWidth - MENU_W - 8),
        top: up ? rect.top - MENU_H : rect.bottom + 4,
      };
      this.$nextTick(() => {
        window.addEventListener('scroll', this.closeRowMenu, {
          capture: true,
          once: true,
        });
      });
    },
    closeRowMenu() {
      this.rowMenu = null;
      window.removeEventListener('scroll', this.closeRowMenu, {
        capture: true,
      });
    },
    menuViewNotes() {
      const task = this.rowMenu && this.rowMenu.row;
      this.closeRowMenu();
      if (task) this.openTaskNotes(task);
    },
    menuAddNote() {
      const task = this.rowMenu && this.rowMenu.row;
      this.closeRowMenu();
      if (task) this.addNoteForTask(task);
    },
    menuDelete() {
      const task = this.rowMenu && this.rowMenu.row;
      this.closeRowMenu();
      if (task) this.remove(task);
    },
    // @tickets_cases — abre el ticket en la pestaña Notas filtrada por la tarea.
    // Con 0 notas no navega: solo avisa (no hay nada que ver todavía).
    openTaskNotes(task) {
      if (!(task.notes_count > 0)) {
        this.$emitter.emit('caseToastMessage', {
          message: this.$t('CASE_TICKETS.TASKS.NOTES_NONE_TOAST', {
            folio: this.seqLabel(task.sequence),
          }),
          icon: 'clipboard',
        });
        return;
      }
      if (!task.case_ticket) return;
      this.$router.push({
        name: 'gestorTickets_detail',
        params: { id: task.case_ticket.id },
        query: { tab: 'notes', task: task.sequence },
      });
    },
    // @tickets_cases — abre el ticket y el modal de alta de nota atado a la tarea.
    addNoteForTask(task) {
      if (!task.case_ticket) return;
      this.$router.push({
        name: 'gestorTickets_detail',
        params: { id: task.case_ticket.id },
        query: {
          tab: 'notes',
          task: task.sequence,
          taskId: task.id,
          compose: '1',
        },
      });
    },
    priorityDot(priority) {
      return PRIORITY_DOT[priority] || 'bg-slate-400';
    },
    priorityLabel(key) {
      return this.priorityOptions[key] || key;
    },
    typeName(task) {
      return task.case_ticket && task.case_ticket.case_type
        ? task.case_ticket.case_type.name
        : '';
    },
    assigneeName(task) {
      return task.assignee ? task.assignee.name : '';
    },
    requesterName(task) {
      return task.requester ? task.requester.name : '';
    },
    statusLabel(status) {
      return status === 'done'
        ? this.$t('CASE_TICKETS.TASKS.STATUS.DONE')
        : this.$t('CASE_TICKETS.TASKS.STATUS.PENDING');
    },
    isOverdue(task) {
      return (
        task.status !== 'done' &&
        task.due_at &&
        new Date(task.due_at) < new Date()
      );
    },
    // Color del folio del ticket por SLA (verde a tiempo, ámbar en riesgo, rojo vencido).
    slaTextColor(sla) {
      return (
        {
          on_time: 'text-green-600 dark:text-green-400',
          at_risk: 'text-yellow-600 dark:text-yellow-400',
          overdue: 'text-red-600 dark:text-red-400',
        }[sla] || 'text-woot-600 dark:text-woot-400'
      );
    },
    // Folio de la tarea: T001, T012… (relleno a 3 dígitos), como dentro del ticket.
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
    // ── Modal de edición ───────────────────────────────────────────
    openEdit(task) {
      this.editingTask = task;
      this.viewing = false;
      this.loadForm(task);
      this.resetAi();
      this.showModal = true;
      this.$nextTick(() => this.$refs.titleInput?.focus());
    },
    openView(task) {
      this.editingTask = task;
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
        // Con solicitante: se muestra fijo. Sin solicitante (tarea antigua): la
        // lista queda editable para asignarlo y guardarlo.
        requester_name: (task.requester && task.requester.name) || '',
        requester_id: task.requester_id || '',
        requester_locked: !!task.requester,
      };
    },
    // Completa la tarea desde la fila, sin abrir el modal. La firma (fecha +
    // quién) la deriva el backend del cambio de estado.
    async complete(task) {
      if (this.completingId || !task.case_ticket) return;
      this.completingId = task.id;
      try {
        await CaseTasksAPI.updateTask(task.case_ticket.id, task.id, {
          status: 'done',
        });
        this.$emitter.emit('caseToastMessage', {
          message: this.$t('CASE_TICKETS.TASKS.TOAST_COMPLETED', {
            task: task.title,
          }),
          icon: 'checkmark',
        });
        this.fetch();
        this.refreshOverdueCount();
      } catch (e) {
        this.$emitter.emit('newToastMessage', {
          message: this.$t('CASE_TICKETS.TASKS.COMPLETE_ERROR'),
        });
      } finally {
        this.completingId = null;
      }
    },
    async submitForm() {
      const title = this.form.title.trim();
      if (!title || this.isSaving || !this.editingTask) return;
      const payload = {
        title,
        description: this.form.description.trim(),
        assignee_id: this.form.assignee_id || '',
        due_at: this.toIsoUtc(this.form.due_at),
        status: this.form.status || 'pending',
        priority: this.form.priority || 'medium',
      };
      // Solicitante editable (tarea sin solicitante previo): se manda para fijarlo.
      if (!this.form.requester_locked) {
        payload.requester_id = this.form.requester_id || '';
      }
      this.isSaving = true;
      try {
        await CaseTasksAPI.updateTask(
          this.editingTask.case_ticket.id,
          this.editingTask.id,
          payload
        );
        this.showModal = false;
        this.fetch();
        this.refreshOverdueCount();
      } catch (e) {
        this.$emitter.emit('newToastMessage', {
          message: this.$t('CASE_TICKETS.TASKS.INBOX.SAVE_ERROR'),
        });
      } finally {
        this.isSaving = false;
      }
    },
    // ── Borrado ────────────────────────────────────────────────────
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
      if (!task || !task.case_ticket) return;
      this.showDeleteConfirm = false;
      try {
        await CaseTasksAPI.deleteTask(task.case_ticket.id, task.id);
        this.$emitter.emit('caseToastMessage', {
          message: this.$t('CASE_TICKETS.TASKS.TOAST_DELETED', {
            task: task.title,
          }),
          icon: 'delete',
          variant: 'danger',
        });
        this.fetch();
        this.refreshOverdueCount();
      } catch (e) {
        this.$emitter.emit('newToastMessage', {
          message: this.$t('CASE_TICKETS.TASKS.INBOX.DELETE_ERROR'),
        });
      } finally {
        this.pendingDelete = null;
      }
    },
    // ── Utilidades de formato ──────────────────────────────────────
    plainPreview(text) {
      if (!text) return '';
      const tmp = document.createElement('div');
      tmp.innerHTML = this.formatMarkdown(text);
      return (tmp.textContent || '').replace(/\s+/g, ' ').trim();
    },
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
    toInputDate(iso) {
      if (!iso) return '';
      const d = new Date(iso);
      const pad = n => String(n).padStart(2, '0');
      return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(
        d.getDate()
      )}T${pad(d.getHours())}:${pad(d.getMinutes())}`;
    },
    // Inversa de toInputDate: el input datetime-local da hora LOCAL sin zona; si
    // se manda tal cual, Rails la castea como UTC y el vencimiento se corre.
    toIsoUtc(local) {
      if (!local) return null;
      const d = new Date(local);
      return Number.isNaN(d.getTime()) ? null : d.toISOString();
    },
    quickTabLabel(key) {
      return this.$t(`CASE_TICKETS.TASKS.INBOX.TABS.${key}`);
    },
  },
};
</script>

<template>
  <div
    class="flex flex-col flex-1 w-full h-full overflow-hidden bg-slate-25 dark:bg-slate-900"
  >
    <!-- Header + filtros -->
    <div
      class="flex flex-col flex-shrink-0 gap-3 px-6 py-4 bg-white border-b dark:bg-slate-900 border-slate-50 dark:border-slate-800/50"
    >
      <h1 class="m-0 text-xl font-bold text-slate-800 dark:text-slate-100">
        {{ $t('CASE_TICKETS.TASKS.INBOX.TITLE') }}
      </h1>

      <woot-tabs :index="activeQuickTabIndex" @change="onQuickTabChange">
        <woot-tabs-item
          v-for="(f, i) in quickFilters"
          :key="f.key"
          :index="i"
          :name="quickTabLabel(f.key)"
          :count="f.key === 'overdue' ? overdueCount : 0"
          :show-badge="f.key === 'overdue' && overdueCount > 0"
        />
      </woot-tabs>

      <div class="flex flex-wrap items-center gap-2">
        <div class="relative flex-1 min-w-[220px]">
          <fluent-icon
            icon="search"
            size="16"
            class="absolute -translate-y-1/2 left-3 top-1/2 text-slate-400 dark:text-slate-500"
          />
          <input
            v-model="filters.q"
            type="text"
            class="w-full pl-9 pr-9 !mb-0 text-sm"
            :placeholder="$t('CASE_TICKETS.TASKS.INBOX.SEARCH_PLACEHOLDER')"
            @input="onSearchInput"
          />
          <button
            v-if="filters.q"
            type="button"
            class="absolute -translate-y-1/2 right-3 top-1/2 text-slate-400 hover:text-slate-600 dark:hover:text-slate-200"
            @click="clearSearch"
          >
            <fluent-icon icon="dismiss" size="14" />
          </button>
        </div>
        <select
          v-model="filters.assignee_id"
          class="!mb-0 text-sm w-40"
          @change="onFilterChange"
        >
          <option value="">{{ $t('CASE_TICKETS.TASKS.INBOX.BY_TAB') }}</option>
          <option v-for="a in agents" :key="a.id" :value="a.id">
            {{ a.name }}
          </option>
        </select>
        <select
          v-model="filters.status"
          class="!mb-0 text-sm w-36"
          @change="onFilterChange"
        >
          <option value="pending">
            {{ $t('CASE_TICKETS.TASKS.INBOX.STATUS.PENDING') }}
          </option>
          <option value="done">
            {{ $t('CASE_TICKETS.TASKS.INBOX.STATUS.DONE') }}
          </option>
          <option value="all">
            {{ $t('CASE_TICKETS.TASKS.INBOX.STATUS.ALL') }}
          </option>
        </select>
        <select
          v-model="filters.due"
          class="!mb-0 text-sm w-36"
          :disabled="quickFilter === 'overdue'"
          @change="onFilterChange"
        >
          <option value="">{{ $t('CASE_TICKETS.TASKS.INBOX.DUE.ANY') }}</option>
          <option value="overdue">
            {{ $t('CASE_TICKETS.TASKS.INBOX.DUE.OVERDUE') }}
          </option>
          <option value="today">
            {{ $t('CASE_TICKETS.TASKS.INBOX.DUE.TODAY') }}
          </option>
          <option value="week">
            {{ $t('CASE_TICKETS.TASKS.INBOX.DUE.WEEK') }}
          </option>
        </select>
        <select
          v-model="filters.case_type_id"
          class="!mb-0 text-sm w-40"
          @change="onFilterChange"
        >
          <option value="">
            {{ $t('CASE_TICKETS.TASKS.INBOX.ALL_TYPES') }}
          </option>
          <option v-for="t in types" :key="t.id" :value="t.id">
            {{ t.name }}
          </option>
        </select>
      </div>
    </div>

    <!-- Loading inicial -->
    <div
      v-if="isFetching && !tasks.length"
      class="flex items-center justify-center flex-1 text-slate-400"
    >
      {{ $t('CASE_TICKETS.LIST.LOADING') }}
    </div>
    <!-- Empty state -->
    <div
      v-else-if="!tasks.length"
      class="flex flex-col items-center justify-center flex-1 gap-3 text-slate-400 dark:text-slate-500"
    >
      <fluent-icon icon="checkmark-circle" size="36" />
      <p>{{ $t('CASE_TICKETS.TASKS.INBOX.EMPTY') }}</p>
    </div>

    <!-- Tabla + paginación -->
    <template v-else>
      <div class="flex-1 min-h-0 px-6 py-4 tasks-inbox-table-wrap">
        <VeTable
          fixed-header
          max-height="100%"
          row-key-field-name="id"
          :columns="columns"
          :table-data="tasks"
          :border-around="false"
          :event-custom-option="eventCustomOption"
        />
      </div>
      <div
        class="flex-shrink-0 bg-white border-t dark:bg-slate-900 border-slate-50 dark:border-slate-800/50"
      >
        <TableFooter
          :current-page="currentPage"
          :total-count="totalCount"
          :page-size="perPage"
          @pageChange="changePage"
        />
      </div>
    </template>

    <!-- Modal de edición / lectura -->
    <woot-modal
      v-if="showModal"
      :show="showModal"
      :on-close="() => (showModal = false)"
      :close-on-backdrop-click="false"
      size="medium"
    >
      <!-- El modal no scrollea: el alto lo absorbe el editor de la descripción
           (alto fijo con su propio scroll). -->
      <div class="flex flex-col h-auto overflow-visible">
        <woot-modal-header
          :header-title="
            viewing
              ? $t('CASE_TICKETS.TASKS.MODAL.VIEW_TITLE')
              : $t('CASE_TICKETS.TASKS.MODAL.EDIT_TITLE')
          "
          :header-content="
            editingTask && editingTask.case_ticket
              ? editingTask.case_ticket.folio
              : ''
          "
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

          <!-- Solicitante + Responsable (editable). El solicitante es fijo si la
               tarea ya lo tiene; si no (tarea antigua), se elige de la lista. -->
          <div class="flex gap-3 mb-3">
            <label class="flex-1">
              <span class="text-sm text-slate-700 dark:text-slate-200">{{
                $t('CASE_TICKETS.TASKS.MODAL.REQUESTER_LABEL')
              }}</span>
              <input
                v-if="form.requester_locked"
                :value="form.requester_name"
                type="text"
                readonly
                class="opacity-70 cursor-default"
              />
              <select v-else v-model="form.requester_id" :disabled="viewing">
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
          </div>

          <!-- Contenedor <div>, NO <label>: el editor lleva un <input type=file>
               oculto y un <label> reenviaría el click a "adjuntar archivo". -->
          <div class="block mb-3">
            <span class="text-sm text-slate-700 dark:text-slate-200">{{
              $t('CASE_TICKETS.TASKS.MODAL.DESCRIPTION_LABEL')
            }}</span>
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
            <div
              v-else
              class="p-2 text-sm border rounded-md prose-note border-slate-200 dark:border-slate-600 text-slate-700 dark:text-slate-100"
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

          <!-- Debajo de la descripción: vencimiento, prioridad y estado. El
               estado también se cambia desde la fila con "Completar"; aquí
               además se puede reabrir la tarea. Prioridad propia (no heredada). -->
          <div class="flex gap-3">
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

    <!-- Confirmación de borrado -->
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

    <!-- Menú de acciones de la fila. Posición FIJA anclada al botón "…": así no
         lo recorta el overflow de la tabla. Se cierra al hacer click fuera. -->
    <div
      v-if="rowMenu"
      v-on-clickaway="closeRowMenu"
      class="fixed z-[9999] w-56 p-1 bg-white border rounded-md shadow-xl dark:bg-slate-800 border-slate-50 dark:border-slate-700"
      :style="{ top: `${rowMenu.top}px`, left: `${rowMenu.left}px` }"
    >
      <WootDropdownMenu>
        <WootDropdownItem>
          <woot-button
            variant="clear"
            color-scheme="secondary"
            size="small"
            icon="clipboard"
            @click="menuViewNotes"
          >
            {{
              $t('CASE_TICKETS.TASKS.MENU.NOTES', {
                count: rowMenu.row.notes_count || 0,
              })
            }}
          </woot-button>
        </WootDropdownItem>
        <WootDropdownItem>
          <woot-button
            variant="clear"
            color-scheme="secondary"
            size="small"
            icon="comment-add"
            @click="menuAddNote"
          >
            {{ $t('CASE_TICKETS.TASKS.ADD_NOTE') }}
          </woot-button>
        </WootDropdownItem>
        <WootDropdownItem>
          <woot-button
            variant="clear"
            color-scheme="alert"
            size="small"
            icon="delete"
            @click="menuDelete"
          >
            {{ $t('CASE_TICKETS.TASKS.DELETE') }}
          </woot-button>
        </WootDropdownItem>
      </WootDropdownMenu>
    </div>
  </div>
</template>

<style lang="scss" scoped>
// Mismos ajustes de densidad que la tabla de tareas dentro del ticket.
.tasks-inbox-table-wrap {
  overflow: hidden;
}

.tasks-inbox-table-wrap::v-deep {
  .ve-table {
    height: 100%;
  }
  .ve-table-header-th {
    padding: var(--space-small) var(--space-one) !important;
    font-size: var(--font-size-mini) !important;
  }
  // Centrado vertical: las filas tienen alturas distintas (la tarea puede traer
  // descripción, el ticket folio + tipo + título). Con `top` los textos de una
  // sola línea quedaban pegados arriba y la fila se leía desalineada.
  .ve-table-body-td {
    padding: var(--space-small) var(--space-one) !important;
    vertical-align: middle;
    cursor: pointer;
  }
  .button-wrapper {
    @apply flex flex-row gap-1;
  }
}

// Editor enriquecido dentro del modal: caja con borde, barra de formato pegada
// arriba con separador (SIN margen negativo, que era lo que la hacía sobresalir
// por encima del borde) y contenido con su propio padding. Mismos valores que
// el modal de tareas dentro del ticket: es el mismo formulario en otro sitio.
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

  // Alto FIJO: el editor no crece con el texto, scrollea por dentro. Así el
  // modal completo nunca necesita scroll.
  .ProseMirror-woot-style {
    @apply px-3 py-2 overflow-y-auto;
    height: 8rem;
  }
}

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
