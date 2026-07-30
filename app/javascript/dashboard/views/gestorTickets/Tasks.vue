<!--
  @tickets_cases — Bandeja de tareas (F2)
  Responde "¿qué tengo asignado?" sin entrar ticket por ticket. Lista las tareas
  a nivel cuenta (endpoint no anidado), con el contexto de su ticket, y permite
  marcarlas completadas inline reusando el PATCH anidado que ya existe.
-->
<script>
import { mapGetters } from 'vuex';
import CaseTasksAPI from 'dashboard/api/caseTasks';

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

export default {
  name: 'TicketTasks',
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
      savingId: null,
    };
  },
  computed: {
    ...mapGetters({
      tasks: 'caseTickets/getMyTasks',
      uiFlags: 'caseTickets/getMyTasksUIFlags',
      types: 'caseTickets/getTypes',
      agents: 'agents/getAgents',
      currentUserID: 'getCurrentUserID',
    }),
    isFetching() {
      return this.uiFlags.isFetching;
    },
    activeQuickTabIndex() {
      const i = QUICK_FILTERS.findIndex(f => f.key === this.quickFilter);
      return i < 0 ? 0 : i;
    },
    priorityOptions() {
      return this.$t('CASE_TICKETS.PRIORITIES');
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
      const p = { assignee_id: this.resolveAssignee() };
      if (this.filters.status) p.status = this.filters.status;
      if (this.filters.case_type_id) p.case_type_id = this.filters.case_type_id;
      if (this.filters.q) p.q = this.filters.q;
      // La pestaña "Vencidas" fija el filtro de vencimiento; si no, el dropdown.
      const due = this.quickFilter === 'overdue' ? 'overdue' : this.filters.due;
      if (due) p.due = due;
      return p;
    },
    fetch() {
      this.$store.dispatch('caseTickets/fetchMyTasks', this.buildParams());
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
      this.fetch();
    },
    onSearchInput() {
      clearTimeout(this.searchDebounce);
      this.searchDebounce = setTimeout(() => this.fetch(), 350);
    },
    clearSearch() {
      this.filters.q = '';
      this.fetch();
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
    dueLabel(task) {
      if (!task.due_at) return '';
      const d = new Date(task.due_at);
      const today = new Date();
      const isToday = d.toDateString() === today.toDateString();
      if (isToday) return this.$t('CASE_TICKETS.TASKS.INBOX.DUE_TODAY');
      return d.toLocaleDateString();
    },
    isOverdue(task) {
      return (
        task.status === 'pending' &&
        task.due_at &&
        new Date(task.due_at) < new Date()
      );
    },
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
    // Marcar/desmarcar completada reusa el PATCH anidado (el index ya trae el ticketId).
    async toggleDone(task) {
      if (this.ticketFrozen(task) || this.savingId) return;
      const next = task.status === 'done' ? 'pending' : 'done';
      this.savingId = task.id;
      try {
        await CaseTasksAPI.updateTask(task.case_ticket.id, task.id, {
          status: next,
        });
        this.fetch();
        this.refreshOverdueCount();
      } catch (e) {
        this.$emitter.emit('newToastMessage', {
          message: this.$t('CASE_TICKETS.TASKS.INBOX.SAVE_ERROR'),
          type: 'error',
        });
      } finally {
        this.savingId = null;
      }
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
          @change="fetch"
        >
          <option value="">{{ $t('CASE_TICKETS.TASKS.INBOX.BY_TAB') }}</option>
          <option v-for="a in agents" :key="a.id" :value="a.id">
            {{ a.name }}
          </option>
        </select>
        <select
          v-model="filters.status"
          class="!mb-0 text-sm w-36"
          @change="fetch"
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
          @change="fetch"
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
          @change="fetch"
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

    <!-- Lista -->
    <div
      v-if="isFetching"
      class="flex items-center justify-center flex-1 text-slate-400"
    >
      {{ $t('CASE_TICKETS.LIST.LOADING') }}
    </div>
    <div
      v-else-if="!tasks.length"
      class="flex items-center justify-center flex-1 text-slate-400"
    >
      {{ $t('CASE_TICKETS.TASKS.INBOX.EMPTY') }}
    </div>
    <div v-else class="flex-1 px-4 py-4 overflow-y-auto">
      <ul class="flex flex-col gap-2 m-0 list-none">
        <li
          v-for="task in tasks"
          :key="task.id"
          class="flex items-start gap-3 p-3 bg-white border rounded-lg dark:bg-slate-800 border-slate-75 dark:border-slate-700"
        >
          <input
            type="checkbox"
            class="mt-1 cursor-pointer"
            :checked="task.status === 'done'"
            :disabled="ticketFrozen(task) || savingId === task.id"
            :title="
              ticketFrozen(task)
                ? $t('CASE_TICKETS.TASKS.INBOX.FROZEN_HINT')
                : ''
            "
            @change="toggleDone(task)"
          />
          <div class="flex-1 min-w-0">
            <p
              class="m-0 text-sm font-medium text-slate-800 dark:text-slate-100"
              :class="{
                'line-through text-slate-400 dark:text-slate-500':
                  task.status === 'done',
              }"
            >
              {{ task.title }}
            </p>
            <div
              class="flex flex-wrap items-center gap-2 mt-1 text-xs text-slate-500 dark:text-slate-400"
            >
              <button
                type="button"
                class="font-mono text-woot-600 hover:underline dark:text-woot-400"
                @click="openTicket(task)"
              >
                {{
                  task.case_ticket
                    ? task.case_ticket.folio || `#${task.case_ticket.id}`
                    : ''
                }}
              </button>
              <span v-if="task.case_ticket" class="truncate max-w-[22rem]">
                {{ task.case_ticket.title }}
              </span>
              <span
                v-if="typeName(task)"
                class="px-1.5 py-0.5 rounded"
                :style="
                  task.case_ticket && task.case_ticket.case_type
                    ? {
                        backgroundColor:
                          task.case_ticket.case_type.color + '22',
                        color: task.case_ticket.case_type.color,
                      }
                    : {}
                "
              >
                {{ typeName(task) }}
              </span>
              <span
                v-if="task.case_ticket"
                class="inline-flex items-center gap-1"
              >
                <span
                  class="inline-block w-2 h-2 rounded-full"
                  :class="priorityDot(task.case_ticket.priority)"
                  :title="priorityLabel(task.case_ticket.priority)"
                />
                {{ priorityLabel(task.case_ticket.priority) }}
              </span>
            </div>
          </div>
          <div class="flex flex-col items-end flex-shrink-0 gap-1 text-xs">
            <span
              v-if="task.status === 'done'"
              class="text-slate-400 dark:text-slate-500"
            >
              {{ $t('CASE_TICKETS.TASKS.INBOX.COMPLETED') }}
              <template v-if="task.completed_by">
                · {{ task.completed_by.name }}
              </template>
            </span>
            <span
              v-else-if="task.due_at"
              :class="
                isOverdue(task)
                  ? 'text-red-600 dark:text-red-400 font-semibold'
                  : 'text-slate-500 dark:text-slate-400'
              "
            >
              {{ $t('CASE_TICKETS.TASKS.INBOX.DUE_PREFIX') }}
              {{ dueLabel(task) }}
            </span>
            <span
              v-if="task.assignee"
              class="truncate max-w-[9rem] text-slate-400 dark:text-slate-500"
            >
              {{ task.assignee.name }}
            </span>
            <span v-else class="text-slate-300 dark:text-slate-600">
              {{ $t('CASE_TICKETS.TASKS.INBOX.UNASSIGNED') }}
            </span>
          </div>
        </li>
      </ul>
    </div>
  </div>
</template>
