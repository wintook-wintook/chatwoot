<!--
  @tickets_cases 2C
  Tablero Kanban operativo de tickets. Columnas = estados agrupados.
  Drag&drop nativo HTML5: al soltar una tarjeta se valida la transición contra
  can_transition_to (backend) y se pide una nota opcional (reason del evento).
-->
<script>
import { mapGetters } from 'vuex';
import CaseTicketInternalModal from './CaseTicketInternalModal.vue'; // @tickets_cases Fase C

// Filtros rápidos (pestañas) — mismo set que el listado (Index.vue).
const QUICK_FILTERS = [
  { key: 'mine', label: 'Mis Tickets' },
  { key: 'unassigned', label: 'Sin Asignar' },
  { key: 'all', label: 'Todos' },
  { key: 'sla_overdue', label: 'SLA vencidos' },
];

// Columnas operativas: cada una agrupa uno o más estados del ciclo de vida (2A).
const COLUMNS = [
  { key: 'new', statuses: ['open', 'classified'] },
  { key: 'assigned', statuses: ['assigned', 'in_diagnosis'] },
  { key: 'progress', statuses: ['in_progress', 'escalated'] },
  {
    key: 'waiting',
    statuses: [
      'waiting_on_customer',
      'waiting_on_third_party',
      'waiting_on_internal',
    ],
  },
  { key: 'resolved', statuses: ['resolved', 'validating'] },
  { key: 'closed', statuses: ['closed', 'cancelled'] },
];

const PRIORITY_DOT = {
  urgent: 'bg-red-500',
  high: 'bg-orange-500',
  medium: 'bg-blue-500',
  low: 'bg-slate-400',
};

const SLA_BADGE = {
  on_time:
    'bg-green-100 text-green-700 dark:bg-green-900/40 dark:text-green-300',
  at_risk:
    'bg-amber-100 text-amber-700 dark:bg-amber-900/40 dark:text-amber-300',
  overdue: 'bg-red-100 text-red-700 dark:bg-red-900/40 dark:text-red-300',
};

export default {
  name: 'TicketKanban',
  components: { CaseTicketInternalModal }, // @tickets_cases Fase C
  data() {
    return {
      columns: COLUMNS,
      quickFilters: QUICK_FILTERS,
      quickFilter: 'mine',
      showInternalModal: false, // @tickets_cases Fase C
      filters: {
        q: '',
        ticket_kind: '',
        priority: '',
        affected_service_id: '',
        assignee_id: '',
      },
      searchDebounce: null,
      draggedTicket: null,
      dragOverKey: null,
      // modal de movimiento
      showMoveModal: false,
      moveTicket: null,
      moveCandidates: [],
      moveTarget: null,
      moveReason: '',
    };
  },
  computed: {
    ...mapGetters({
      boardTickets: 'caseTickets/getBoardTickets',
      boardUiFlags: 'caseTickets/getBoardUIFlags',
      slaOverdueCount: 'caseTickets/getBoardSlaOverdue',
      services: 'caseTickets/getServices',
      agents: 'agents/getAgents',
      currentUserID: 'getCurrentUserID', // @tickets_cases — filtro "Mis Tickets"
    }),
    isFetching() {
      return this.boardUiFlags.isFetching;
    },
    activeQuickTabIndex() {
      const i = QUICK_FILTERS.findIndex(f => f.key === this.quickFilter);
      return i < 0 ? 0 : i;
    },
    priorityOptions() {
      return this.$t('CASE_TICKETS.PRIORITIES');
    },
    ticketKindOptions() {
      return this.$t('CASE_TICKETS.TICKET_KIND');
    },
    // Tickets agrupados por columna.
    grouped() {
      const map = {};
      this.columns.forEach(c => {
        map[c.key] = [];
      });
      (this.boardTickets || []).forEach(t => {
        const col = this.columns.find(c => c.statuses.includes(t.status));
        if (col) map[col.key].push(t);
      });
      return map;
    },
    moveTargetLabel() {
      return this.moveTicket
        ? `${this.moveTicket.folio || `#${this.moveTicket.id}`}`
        : '';
    },
  },
  mounted() {
    this.fetch();
    this.$store.dispatch('caseTickets/fetchServices');
    this.$store.dispatch('agents/get');
  },
  methods: {
    // @tickets_cases Fase C — tras crear un ticket interno, refresca el tablero.
    onInternalCreated() {
      this.showInternalModal = false;
      this.fetch();
    },
    fetch() {
      const f = {};
      Object.keys(this.filters).forEach(k => {
        if (this.filters[k] !== '' && this.filters[k] != null) {
          f[k] = this.filters[k];
        }
      });
      // Filtro rápido (pestañas): sobrescribe assignee / añade sla_status.
      if (this.quickFilter === 'sla_overdue') f.sla_status = 'overdue';
      if (this.quickFilter === 'unassigned') f.assignee_id = 'unassigned';
      if (this.quickFilter === 'mine') f.assignee_id = this.currentUserID;
      this.$store.dispatch('caseTickets/fetchBoardTickets', f);
    },
    onSearchInput() {
      clearTimeout(this.searchDebounce);
      this.searchDebounce = setTimeout(() => this.fetch(), 350);
    },
    clearSearch() {
      this.filters.q = '';
      this.fetch();
    },
    onQuickTabChange(index) {
      this.quickFilter = QUICK_FILTERS[index].key;
      this.fetch();
    },
    columnLabel(key) {
      return this.$t(`CASE_TICKETS.KANBAN.COLUMNS.${key}`);
    },
    statusLabel(key) {
      return this.$t(`CASE_TICKETS.STATUSES.${key}`) || key;
    },
    kindLabel(key) {
      return this.ticketKindOptions[key] || key;
    },
    priorityDot(priority) {
      return PRIORITY_DOT[priority] || 'bg-slate-400';
    },
    slaBadge(sla) {
      return SLA_BADGE[sla] || SLA_BADGE.on_time;
    },
    assigneeName(ticket) {
      if (!ticket.assignee_id) return null;
      const a = (this.agents || []).find(x => x.id === ticket.assignee_id);
      return a ? a.name : null;
    },
    openDetail(ticket) {
      this.$router.push({
        name: 'gestorTickets_detail',
        params: { id: ticket.id },
      });
    },
    // ── drag & drop ──
    onDragStart(ticket, event) {
      this.draggedTicket = ticket;
      if (event.dataTransfer) {
        event.dataTransfer.effectAllowed = 'move';
        event.dataTransfer.setData('text/plain', String(ticket.id));
      }
    },
    onDragEnd() {
      this.draggedTicket = null;
      this.dragOverKey = null;
    },
    onDragOver(columnKey, event) {
      // Imprescindible para que el drop sea válido en Chrome (si no, cursor "no-drop"
      // y la tarjeta revierte sin soltarse).
      if (event && event.dataTransfer) event.dataTransfer.dropEffect = 'move';
      this.dragOverKey = columnKey;
    },
    onDragLeave(columnKey, event) {
      // Solo quitar el resaltado si realmente salimos de la columna (no a un hijo).
      if (!event.currentTarget.contains(event.relatedTarget)) {
        if (this.dragOverKey === columnKey) this.dragOverKey = null;
      }
    },
    onDrop(column) {
      const ticket = this.draggedTicket;
      this.draggedTicket = null;
      this.dragOverKey = null;
      if (!ticket) return;
      // Soltado en su misma columna → no-op.
      if (column.statuses.includes(ticket.status)) return;

      const valid = ticket.can_transition_to || [];
      const candidates = column.statuses.filter(s => valid.includes(s));
      if (!candidates.length) {
        this.$emitter.emit('newToastMessage', {
          message: this.$t('CASE_TICKETS.KANBAN.INVALID_MOVE'),
          type: 'error',
        });
        return;
      }
      this.moveTicket = ticket;
      this.moveCandidates = candidates;
      this.moveTarget = candidates[0];
      this.moveReason = '';
      this.showMoveModal = true;
    },
    closeMove() {
      this.showMoveModal = false;
      this.moveTicket = null;
      this.moveCandidates = [];
      this.moveTarget = null;
      this.moveReason = '';
    },
    async confirmMove() {
      const ticket = this.moveTicket;
      const status = this.moveTarget;
      const reason = this.moveReason.trim() || undefined;
      this.showMoveModal = false;
      try {
        await this.$store.dispatch('caseTickets/transitionTicket', {
          ticketId: ticket.id,
          contactId: ticket.contact_id,
          status,
          reason,
        });
        this.fetch();
      } catch (e) {
        this.$emitter.emit('newToastMessage', {
          message: this.$t('CASE_TICKETS.KANBAN.MOVE_ERROR'),
          type: 'error',
        });
      } finally {
        this.closeMove();
      }
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
      <div class="flex items-center justify-between">
        <h1 class="m-0 text-xl font-bold text-slate-800 dark:text-slate-100">
          {{ $t('CASE_TICKETS.KANBAN.TITLE') }}
        </h1>
        <!-- @tickets_cases Fase C — alta de ticket interno -->
        <woot-button size="small" icon="add" @click="showInternalModal = true">
          {{ $t('CASE_TICKETS.INTERNAL.NEW_BUTTON') }}
        </woot-button>
      </div>

      <!-- Filtros rápidos como pestañas nativas (mismo estilo que el listado) -->
      <woot-tabs :index="activeQuickTabIndex" @change="onQuickTabChange">
        <woot-tabs-item
          v-for="(f, i) in quickFilters"
          :key="f.key"
          :index="i"
          :name="f.label"
          :count="f.key === 'sla_overdue' ? slaOverdueCount : 0"
          :show-badge="f.key === 'sla_overdue' && slaOverdueCount > 0"
        />
      </woot-tabs>

      <!-- Toolbar compacto: búsqueda + dropdowns -->
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
            :placeholder="$t('CASE_TICKETS.KANBAN.SEARCH_PLACEHOLDER')"
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
          v-model="filters.ticket_kind"
          class="!mb-0 text-sm w-40"
          @change="fetch"
        >
          <option value="">{{ $t('CASE_TICKETS.KANBAN.ALL_KINDS') }}</option>
          <option
            v-for="(label, key) in ticketKindOptions"
            :key="key"
            :value="key"
          >
            {{ label }}
          </option>
        </select>
        <select
          v-model="filters.priority"
          class="!mb-0 text-sm w-36"
          @change="fetch"
        >
          <option value="">{{ $t('CASE_TICKETS.LIST.ALL_PRIORITIES') }}</option>
          <option
            v-for="(label, key) in priorityOptions"
            :key="key"
            :value="key"
          >
            {{ label }}
          </option>
        </select>
        <select
          v-model="filters.affected_service_id"
          class="!mb-0 text-sm w-40"
          @change="fetch"
        >
          <option value="">{{ $t('CASE_TICKETS.KANBAN.ALL_SERVICES') }}</option>
          <option v-for="s in services" :key="s.id" :value="s.id">
            {{ s.name }}
          </option>
        </select>
        <select
          v-model="filters.assignee_id"
          class="!mb-0 text-sm w-40"
          @change="fetch"
        >
          <option value="">{{ $t('CASE_TICKETS.KANBAN.ALL_AGENTS') }}</option>
          <option v-for="a in agents" :key="a.id" :value="a.id">
            {{ a.name }}
          </option>
        </select>
      </div>
    </div>

    <!-- Tablero -->
    <div
      v-if="isFetching"
      class="flex items-center justify-center flex-1 text-slate-400"
    >
      {{ $t('CASE_TICKETS.LIST.LOADING') }}
    </div>
    <div v-else class="flex flex-1 gap-3 px-4 py-4 overflow-x-auto">
      <div
        v-for="col in columns"
        :key="col.key"
        class="flex flex-col flex-shrink-0 w-72 rounded-lg bg-slate-100 dark:bg-slate-800/50"
        :class="dragOverKey === col.key ? 'ring-2 ring-woot-500' : ''"
        @dragenter.prevent="dragOverKey = col.key"
        @dragover.prevent="onDragOver(col.key, $event)"
        @dragleave="onDragLeave(col.key, $event)"
        @drop.prevent="onDrop(col)"
      >
        <div
          class="flex items-center justify-between px-3 py-2 text-xs font-semibold tracking-wide uppercase text-slate-500 dark:text-slate-400"
        >
          <span>{{ columnLabel(col.key) }}</span>
          <span class="px-1.5 rounded bg-slate-200 dark:bg-slate-700">{{
            grouped[col.key].length
          }}</span>
        </div>
        <div class="flex flex-col flex-1 gap-2 p-2 overflow-y-auto">
          <div
            v-for="ticket in grouped[col.key]"
            :key="ticket.id"
            draggable="true"
            class="p-3 bg-white border rounded-lg cursor-pointer dark:bg-slate-800 border-slate-75 dark:border-slate-700 hover:shadow"
            @dragstart="onDragStart(ticket, $event)"
            @dragend="onDragEnd"
            @click="openDetail(ticket)"
          >
            <div class="flex items-center justify-between mb-1">
              <span
                class="font-mono text-xs text-slate-500 dark:text-slate-400"
              >
                {{ ticket.folio || `#${ticket.id}` }}
              </span>
              <span
                class="px-1.5 py-0.5 text-[10px] rounded"
                :class="slaBadge(ticket.sla_status)"
              >
                {{ statusLabel(ticket.sla_status) }}
              </span>
            </div>
            <p
              class="m-0 mb-2 text-sm font-medium text-slate-800 dark:text-slate-100 line-clamp-2"
            >
              {{ ticket.title }}
            </p>
            <div class="flex items-center gap-2 text-xs text-slate-500">
              <span
                class="inline-block w-2 h-2 rounded-full"
                :class="priorityDot(ticket.priority)"
                :title="priorityOptions[ticket.priority]"
              />
              <span
                v-if="ticket.ticket_kind"
                class="px-1.5 py-0.5 rounded bg-slate-100 dark:bg-slate-700 dark:text-slate-300"
              >
                {{ kindLabel(ticket.ticket_kind) }}
              </span>
              <span
                v-if="assigneeName(ticket)"
                class="ml-auto truncate max-w-[7rem]"
              >
                {{ assigneeName(ticket) }}
              </span>
            </div>
          </div>
          <p
            v-if="!grouped[col.key].length"
            class="px-2 py-4 text-xs text-center text-slate-400"
          >
            —
          </p>
        </div>
      </div>
    </div>

    <!-- Modal de movimiento (nota al avanzar) -->
    <woot-modal
      v-if="showMoveModal"
      :show="showMoveModal"
      :on-close="closeMove"
      size="small"
    >
      <div class="flex flex-col h-auto overflow-auto">
        <woot-modal-header
          :header-title="
            $t('CASE_TICKETS.KANBAN.MOVE_TITLE', { folio: moveTargetLabel })
          "
        />
        <form
          class="flex flex-col self-stretch w-full gap-4 pb-8"
          @submit.prevent="confirmMove"
        >
          <label v-if="moveCandidates.length > 1" class="flex flex-col gap-1">
            <span
              class="text-sm font-medium text-slate-700 dark:text-slate-200"
            >
              {{ $t('CASE_TICKETS.KANBAN.MOVE_TARGET') }}
            </span>
            <select v-model="moveTarget" class="input">
              <option v-for="s in moveCandidates" :key="s" :value="s">
                {{ statusLabel(s) }}
              </option>
            </select>
          </label>
          <p v-else class="m-0 text-sm text-slate-600 dark:text-slate-300">
            {{ $t('CASE_TICKETS.KANBAN.MOVE_TO') }}
            <strong>{{ statusLabel(moveTarget) }}</strong>
          </p>

          <label class="flex flex-col gap-1">
            <span
              class="text-sm font-medium text-slate-700 dark:text-slate-200"
            >
              {{ $t('CASE_TICKETS.KANBAN.MOVE_NOTE') }}
            </span>
            <textarea
              v-model="moveReason"
              class="input"
              rows="3"
              :placeholder="$t('CASE_TICKETS.KANBAN.MOVE_NOTE_PLACEHOLDER')"
            />
          </label>

          <div class="flex justify-end gap-2 mt-2">
            <woot-button
              variant="clear"
              color-scheme="secondary"
              type="button"
              @click="closeMove"
            >
              {{ $t('CASE_TICKETS.KANBAN.CANCEL') }}
            </woot-button>
            <woot-button type="submit">
              {{ $t('CASE_TICKETS.KANBAN.CONFIRM') }}
            </woot-button>
          </div>
        </form>
      </div>
    </woot-modal>

    <!-- @tickets_cases Fase C — modal de alta de ticket interno -->
    <CaseTicketInternalModal
      v-if="showInternalModal"
      :show="showInternalModal"
      @created="onInternalCreated"
      @close="showInternalModal = false"
    />
  </div>
</template>
