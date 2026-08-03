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
  components: { VeTable, TableFooter, WootMessageEditor },
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
      },
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
    }),
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
          field: 'sequence',
          key: 'sequence',
          title: this.$t('CASE_TICKETS.TASKS.TABLE.NUM'),
          align: 'left',
          width: 72,
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
          field: 'status',
          key: 'status',
          title: this.$t('CASE_TICKETS.TASKS.TABLE.STATUS'),
          align: 'left',
          width: 110,
          renderBodyCell: ({ row }) => (
            <span class="text-sm whitespace-nowrap text-slate-600 dark:text-slate-300">
              {this.statusLabel(row.status)}
            </span>
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
          field: 'completed_at',
          key: 'completed_at',
          title: this.$t('CASE_TICKETS.TASKS.TABLE.COMPLETED'),
          align: 'left',
          width: 170,
          renderBodyCell: ({ row }) => {
            if (!row.completed_at) {
              return (
                <span class="text-xs text-slate-400 dark:text-slate-500">
                  —
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
          field: 'id',
          key: 'actions',
          title: '',
          align: 'left',
          width: 70,
          renderBodyCell: ({ row }) =>
            this.ticketFrozen(row) ? null : (
              <div class="button-wrapper">
                <woot-button
                  size="tiny"
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
      };
    },
    async submitForm() {
      const title = this.form.title.trim();
      if (!title || this.isSaving || !this.editingTask) return;
      const payload = {
        title,
        description: this.form.description.trim(),
        assignee_id: this.form.assignee_id || '',
        due_at: this.form.due_at || null,
        status: this.form.status || 'pending',
      };
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
      <div class="flex flex-col h-auto overflow-auto">
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

          <!-- Contenedor <div>, NO <label>: el editor lleva un <input type=file>
               oculto y un <label> reenviaría el click a "adjuntar archivo". -->
          <div class="block mb-3">
            <span class="text-sm text-slate-700 dark:text-slate-200">{{
              $t('CASE_TICKETS.TASKS.MODAL.DESCRIPTION_LABEL')
            }}</span>
            <div v-if="!viewing" class="editor-wrap">
              <WootMessageEditor
                v-model="form.description"
                class="message-editor [&>div]:px-1"
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

          <label class="block">
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
  .ve-table-body-td {
    padding: var(--space-small) var(--space-one) !important;
    vertical-align: top;
    cursor: pointer;
  }
  .button-wrapper {
    @apply flex flex-row gap-1;
  }
}

.editor-wrap {
  @apply border border-slate-200 dark:border-slate-600 rounded-md px-2 bg-white dark:bg-slate-900;
}

.message-editor::v-deep {
  .ProseMirror-menubar {
    padding: 0;
    margin-top: var(--space-minus-small);
  }
  .ProseMirror-woot-style {
    min-height: 6rem;
    max-height: 18rem;
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
