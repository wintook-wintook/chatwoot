<!--
  @tickets_cases
  Vista principal del Gestor de Tickets — búsqueda, filtros (fecha/estado/prioridad/tipo),
  orden configurable y paginación. Tailwind + dark mode.
-->
<template>
  <div
    class="flex flex-col flex-1 w-full h-full overflow-hidden bg-slate-25 dark:bg-slate-900"
  >
    <!-- Header -->
    <div
      class="flex-shrink-0 px-6 pt-4 bg-white border-b dark:bg-slate-900 border-slate-50 dark:border-slate-800/50"
    >
      <div class="flex items-center justify-between mb-3">
        <h1 class="m-0 text-xl font-bold text-slate-800 dark:text-slate-100">
          {{ $t('CASE_TICKETS.SIDEBAR.TITLE') }}
        </h1>
        <!-- @tickets_cases Fase C — alta de ticket interno (agente→agente) -->
        <woot-button size="small" icon="add" @click="showInternalModal = true">
          {{ $t('CASE_TICKETS.INTERNAL.NEW_BUTTON') }}
        </woot-button>
      </div>

      <!-- Filtros rápidos como pestañas nativas -->
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

      <!-- Toolbar compacto: búsqueda + dropdowns + fecha + orden -->
      <div class="flex flex-wrap items-center gap-2 py-3">
        <!-- Búsqueda -->
        <div class="relative flex-1 min-w-[220px]">
          <fluent-icon
            icon="search"
            size="16"
            class="absolute -translate-y-1/2 left-3 top-1/2 text-slate-400 dark:text-slate-500"
          />
          <input
            v-model="search"
            type="text"
            class="w-full pl-9 pr-9 !mb-0"
            :placeholder="$t('CASE_TICKETS.LIST.SEARCH_PLACEHOLDER')"
            @input="onSearchInput"
          />
          <button
            v-if="search"
            type="button"
            class="absolute -translate-y-1/2 right-3 top-1/2 text-slate-400 hover:text-slate-600 dark:hover:text-slate-200"
            @click="clearSearch"
          >
            <fluent-icon icon="dismiss" size="14" />
          </button>
        </div>

        <!-- Estado -->
        <select
          v-model="statusFilter"
          class="!mb-0 w-40 text-sm"
          @change="onFilterChange"
        >
          <option value="">{{ $t('CASE_TICKETS.LIST.ALL_STATUSES') }}</option>
          <option v-for="s in statusOptions" :key="s" :value="s">
            {{ statusLabel(s) }}
          </option>
        </select>

        <!-- Prioridad -->
        <select
          v-model="priorityFilter"
          class="!mb-0 w-36 text-sm"
          @change="onFilterChange"
        >
          <option value="">{{ $t('CASE_TICKETS.LIST.ALL_PRIORITIES') }}</option>
          <option v-for="p in priorityOptions" :key="p" :value="p">
            {{ priorityLabel(p) }}
          </option>
        </select>

        <!-- Tipo (dinámico desde la cuenta) -->
        <select
          v-model="activeType"
          class="!mb-0 w-40 text-sm"
          @change="onFilterChange"
        >
          <option v-for="t in typeFilters" :key="t.id" :value="t.id">
            {{ t.name }}
          </option>
        </select>

        <!-- Origen (@tickets_cases Fase C) -->
        <select
          v-model="originFilter"
          class="!mb-0 w-36 text-sm"
          @change="onFilterChange"
        >
          <option value="">{{ $t('CASE_TICKETS.LIST.ALL_ORIGINS') }}</option>
          <option v-for="o in originOptions" :key="o" :value="o">
            {{ originLabel(o) }}
          </option>
        </select>

        <!-- Rango de fechas (no-margin + auto-width para alinear y acotar el ancho como los selects) -->
        <WootDateRangePicker
          class="no-margin auto-width w-56"
          :value="dateRange"
          :placeholder="$t('CASE_TICKETS.LIST.DATE_RANGE')"
          :confirm-text="$t('CASE_TICKETS.LIST.APPLY')"
          @change="onDateChange"
        />

        <!-- Ordenar por -->
        <div class="flex items-center gap-1">
          <select
            v-model="sortBy"
            class="!mb-0 w-40 text-sm"
            @change="onFilterChange"
          >
            <option v-for="o in sortOptions" :key="o.value" :value="o.value">
              {{ $t('CASE_TICKETS.LIST.SORT_BY') }}: {{ o.label }}
            </option>
          </select>
          <button
            type="button"
            class="flex items-center justify-center w-8 h-8 border rounded bg-white dark:bg-slate-800 border-slate-100 dark:border-slate-700 text-slate-600 dark:text-slate-300 hover:border-woot-500"
            :title="
              sortOrder === 'asc'
                ? $t('CASE_TICKETS.LIST.SORT_ASC')
                : $t('CASE_TICKETS.LIST.SORT_DESC')
            "
            @click="toggleSortOrder"
          >
            <fluent-icon
              :icon="sortOrder === 'asc' ? 'chevron-up' : 'chevron-down'"
              size="16"
            />
          </button>
        </div>

        <!-- Limpiar -->
        <button
          v-if="hasActiveFilters"
          type="button"
          class="px-3 py-1 text-sm rounded text-woot-600 dark:text-woot-400 hover:bg-woot-50 dark:hover:bg-woot-800/30"
          @click="clearFilters"
        >
          ✕ {{ $t('CASE_TICKETS.LIST.CLEAR_FILTERS') }}
        </button>
      </div>
    </div>

    <!-- Loading (solo en la carga inicial; al ordenar/paginar la tabla se
         mantiene montada y solo se refrescan las filas, como en Contactos). -->
    <div
      v-if="isFetchingList && !tickets.length"
      class="flex items-center justify-center flex-1 text-slate-400 dark:text-slate-500"
    >
      <span>{{ $t('CASE_TICKETS.LIST.LOADING') }}</span>
    </div>

    <!-- Empty state -->
    <div
      v-else-if="!tickets.length"
      class="flex flex-col items-center justify-center flex-1 gap-4 text-slate-400 dark:text-slate-500"
    >
      <fluent-icon icon="clipboard" size="40" />
      <p>{{ $t('CASE_TICKETS.LIST.EMPTY') }}</p>
    </div>

    <!-- Cola (tabla densa estilo osTicket) + acciones en lote -->
    <div v-else class="flex flex-col flex-1 min-h-0">
      <!-- Barra de acciones en lote (aparece al seleccionar) -->
      <div
        v-if="selected.length"
        class="relative flex flex-wrap items-center gap-2 px-6 py-2 border-b bg-woot-25 dark:bg-woot-800/20 border-slate-100 dark:border-slate-700"
      >
        <span class="text-sm font-medium text-slate-700 dark:text-slate-200">
          {{ $t('CASE_TICKETS.BULK.SELECTED', { n: selected.length }) }}
        </span>
        <woot-button
          size="tiny"
          variant="smooth"
          color-scheme="secondary"
          icon="person-add"
          :is-loading="uiFlags.isTransitioning"
          @click="bulkClaim"
        >
          {{ $t('CASE_TICKETS.CLAIM.BUTTON') }}
        </woot-button>

        <!-- Asignar a -->
        <div class="relative">
          <woot-button
            size="tiny"
            variant="smooth"
            color-scheme="secondary"
            icon="chevron-down"
            @click="
              showBulkAssign = !showBulkAssign;
              showBulkStatus = false;
            "
          >
            {{ $t('CASE_TICKETS.BULK.ASSIGN') }}
          </woot-button>
          <ul
            v-if="showBulkAssign"
            class="absolute left-0 z-50 py-1 mt-1 list-none overflow-y-auto bg-white border rounded-md shadow-md top-full dark:bg-slate-800 border-slate-100 dark:border-slate-700 min-w-[180px] max-h-64"
          >
            <li
              class="px-4 py-2 text-sm cursor-pointer text-slate-500 dark:text-slate-400 hover:bg-slate-50 dark:hover:bg-slate-700"
              @click="bulkUnassign"
            >
              {{ $t('CASE_TICKETS.ASSIGN.NONE') }}
            </li>
            <li
              v-for="ag in assignableAgents"
              :key="ag.id"
              class="px-4 py-2 text-sm cursor-pointer text-slate-600 dark:text-slate-300 hover:bg-slate-50 dark:hover:bg-slate-700"
              @click="bulkAssign(ag.id)"
            >
              {{ ag.name }}
            </li>
          </ul>
        </div>

        <!-- Cambiar estado -->
        <div class="relative">
          <woot-button
            size="tiny"
            variant="smooth"
            color-scheme="secondary"
            icon="chevron-down"
            @click="
              showBulkStatus = !showBulkStatus;
              showBulkAssign = false;
            "
          >
            {{ $t('CASE_TICKETS.STATUS_QUICK.LABEL') }}
          </woot-button>
          <ul
            v-if="showBulkStatus"
            class="absolute left-0 z-50 py-1 mt-1 list-none overflow-y-auto bg-white border rounded-md shadow-md top-full dark:bg-slate-800 border-slate-100 dark:border-slate-700 min-w-[180px] max-h-64"
          >
            <li
              v-for="s in bulkStatusOptions"
              :key="s"
              class="px-4 py-2 text-sm cursor-pointer text-slate-600 dark:text-slate-300 hover:bg-slate-50 dark:hover:bg-slate-700"
              @click="bulkStatus(s)"
            >
              {{ statusLabel(s) }}
            </li>
          </ul>
        </div>

        <woot-button
          size="tiny"
          variant="smooth"
          color-scheme="alert"
          icon="dismiss-circle"
          @click="bulkClose"
        >
          {{ $t('CASE_TICKETS.BULK.CLOSE') }}
        </woot-button>

        <button
          type="button"
          class="ml-auto text-xs text-slate-500 hover:text-slate-700 dark:text-slate-400 dark:hover:text-slate-200"
          @click="clearSelection"
        >
          ✕ {{ $t('CASE_TICKETS.BULK.CLEAR') }}
        </button>
      </div>

      <!-- Tabla nativa de Chatwoot (vue-easytable), igual que Contactos/Notas/
           Tareas. `fixed-header` + `max-height` hacen que scrolleen solo las
           filas. Click en la fila abre el detalle; el orden de las columnas
           marcadas es en servidor (sortChange → onSortChange → fetch). -->
      <div class="flex-1 min-h-0 tickets-table-wrap">
        <VeTable
          fixed-header
          max-height="100%"
          row-key-field-name="id"
          :columns="columns"
          :table-data="tickets"
          :border-around="false"
          :sort-option="sortOption"
          :event-custom-option="eventCustomOption"
          :row-style-option="rowStyleOption"
          :cell-style-option="cellStyleOption"
        />
      </div>
    </div>

    <!-- Paginación estándar de Chatwoot (igual que Notas/Tareas/Seguimientos) +
         selector de "por página" a la izquierda (server-side). -->
    <div
      v-if="tickets.length"
      class="flex items-center justify-between flex-shrink-0 bg-white border-t dark:bg-slate-900 border-slate-50 dark:border-slate-800/50"
    >
      <label
        class="flex items-center gap-1 pl-6 text-xs text-slate-500 dark:text-slate-400"
      >
        {{ $t('CASE_TICKETS.LIST.PER_PAGE') }}
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
        :total-count="meta.total_count || 0"
        :page-size="perPage"
        @pageChange="changePage"
      />
    </div>

    <!-- @tickets_cases Fase C — modal de alta de ticket interno -->
    <CaseTicketInternalModal
      v-if="showInternalModal"
      :show="showInternalModal"
      @created="onInternalCreated"
      @close="showInternalModal = false"
    />

    <!-- @tickets_cases — edición desde la cola (mismo modal, modo edición) -->
    <CaseTicketInternalModal
      v-if="editingTicket"
      :show="!!editingTicket"
      :ticket="editingTicket"
      @updated="onInternalUpdated"
      @close="editingTicket = null"
    />
  </div>
</template>

<script>
import { mapGetters } from 'vuex';
import { VeTable } from 'vue-easytable';
import WootDateRangePicker from 'dashboard/components/ui/DateRangePicker.vue';
import TableFooter from 'dashboard/components/widgets/TableFooter.vue'; // @tickets_cases — paginado estándar
import CaseTicketInternalModal from './CaseTicketInternalModal.vue'; // @tickets_cases Fase C
import {
  SIMPLE_FILTER_STATUSES,
  toSimpleStatus,
} from 'dashboard/helper/caseSimpleStatus'; // modo simple/ITIL

const QUICK_FILTERS = [
  { key: 'mine', label: 'Mis Tickets' },
  { key: 'unassigned', label: 'Sin Asignar' },
  { key: 'all', label: 'Todos' },
  { key: 'sla_overdue', label: 'SLA vencidos' },
];

// Los 13 estados de ticket (sin los estados SLA que comparten el bloque STATUSES).
// Orden = flujo del ciclo de vida ITIL (@tickets_cases 2A).
const STATUS_OPTIONS = [
  'open',
  'classified',
  'assigned',
  'in_diagnosis',
  'in_progress',
  'waiting_on_customer',
  'waiting_on_third_party',
  'waiting_on_internal',
  'escalated',
  'resolved',
  'validating',
  'closed',
  'cancelled',
];
const PRIORITY_OPTIONS = ['low', 'medium', 'high', 'urgent'];
// @tickets_cases Fase C — orígenes del ticket (incluye 'internal').
const ORIGIN_OPTIONS = [
  'whatsapp',
  'web',
  'email',
  'bot',
  'manual',
  'internal',
];
const SORT_FIELDS = ['created_at', 'priority', 'status', 'sla_status'];
const PER_PAGE_OPTIONS = [25, 50, 100];

export default {
  name: 'GestorTicketsIndex',
  components: { VeTable, TableFooter, WootDateRangePicker, CaseTicketInternalModal },
  data() {
    return {
      showInternalModal: false, // @tickets_cases Fase C
      editingTicket: null, // @tickets_cases — ticket en edición (modal)
      selected: [], // @tickets_cases P3 — ids seleccionados para acciones en lote
      // @tickets_cases — orden en servidor a través de VeTable. `sortConfig`
      // mapea el campo activo → 'asc'|'desc' (lo que espera cada columna en su
      // `sortBy`); `sortChange` reenvía el cambio a `onSortChange` → fetch.
      sortConfig: {},
      sortOption: {
        sortAlways: true,
        sortChange: params => this.onSortChange(params),
      },
      // Click en la fila = abrir el detalle (como el <tr @click> anterior). Las
      // celdas de checkbox/lápiz cortan la propagación para no navegar.
      eventCustomOption: {
        bodyRowEvents: ({ row }) => ({
          click: () => this.openDetail(row),
        }),
      },
      // Sin rayado, con hover como el resto de las tablas del fork.
      rowStyleOption: {
        stripe: false,
        clickHighlight: false,
        hoverHighlight: true,
      },
      // Resalta la fila seleccionada: vue-easytable no expone una clase por
      // fila, así que se pinta cada celda de la fila (bodyCellClass) y el color
      // de fondo lo pone el CSS `.row--selected`.
      cellStyleOption: {
        bodyCellClass: ({ row }) =>
          this.isSelected(row.id) ? 'row--selected' : '',
      },
      showBulkAssign: false,
      showBulkStatus: false,
      search: '',
      searchDebounce: null,
      dateRange: [], // [Date, Date]
      statusFilter: '',
      priorityFilter: '',
      originFilter: '', // @tickets_cases Fase C
      activeFilter: 'mine',
      activeType: '', // '' = todos, o un case_type_id
      sortBy: 'created_at',
      sortOrder: 'desc',
      currentPage: 1,
      perPage: 25,
    };
  },
  computed: {
    ...mapGetters({
      tickets: 'caseTickets/getTicketsList',
      meta: 'caseTickets/getTicketsMeta',
      uiFlags: 'caseTickets/getUIFlags',
      types: 'caseTickets/getTypes',
      currentUserID: 'getCurrentUserID', // @tickets_cases — filtro "Mis Tickets"
      itilEnabled: 'caseTickets/getItilEnabled', // modo simple/ITIL
      agents: 'agents/getAgents', // @tickets_cases P3 — nombre del asignado + lote
    }),
    isFetchingList() {
      return this.uiFlags.isFetchingList;
    },
    // @tickets_cases P3 — selección múltiple para acciones en lote
    pageIds() {
      return this.tickets.map(t => t.id);
    },
    allSelected() {
      return (
        this.tickets.length > 0 &&
        this.pageIds.every(id => this.selected.includes(id))
      );
    },
    someSelected() {
      return this.selected.length > 0 && !this.allSelected;
    },
    assignableAgents() {
      return this.agents;
    },
    bulkStatusOptions() {
      return this.statusOptions;
    },
    quickFilters() {
      return QUICK_FILTERS;
    },
    activeQuickTabIndex() {
      const i = QUICK_FILTERS.findIndex(f => f.key === this.activeFilter);
      return i < 0 ? 0 : i;
    },
    slaOverdueCount() {
      return this.meta.sla_overdue_count || 0;
    },
    statusOptions() {
      return this.itilEnabled ? STATUS_OPTIONS : SIMPLE_FILTER_STATUSES;
    },
    priorityOptions() {
      return PRIORITY_OPTIONS;
    },
    originOptions() {
      return ORIGIN_OPTIONS;
    },
    perPageOptions() {
      return PER_PAGE_OPTIONS;
    },
    sortOptions() {
      return SORT_FIELDS.map(value => ({
        value,
        label: this.$t(`CASE_TICKETS.LIST.SORT_FIELDS.${value}`),
      }));
    },
    typeFilters() {
      return [{ id: '', name: 'Todos los tipos' }, ...this.types];
    },
    hasActiveFilters() {
      return (
        !!this.search ||
        this.dateRange.length > 0 ||
        !!this.statusFilter ||
        !!this.priorityFilter ||
        !!this.originFilter ||
        this.activeFilter !== 'mine' ||
        !!this.activeType
      );
    },
    // @tickets_cases — columnas de la cola en VeTable (tabla nativa de Chatwoot,
    // igual que Contactos/Notas/Tareas). Las celdas se pintan con renderBodyCell
    // (JSX). El orden de prioridad/estado/vence/creado es en servidor: cada
    // columna declara su `sortBy` desde `sortConfig` y VeTable emite `sortChange`.
    columns() {
      return [
        {
          field: 'select',
          key: 'select',
          align: 'left',
          width: 44,
          // Checkbox "seleccionar todo" en la cabecera (indeterminado si es parcial).
          renderHeaderCell: () => (
            <input
              type="checkbox"
              class="!mb-0 align-middle"
              domPropsChecked={this.allSelected}
              domPropsIndeterminate={this.someSelected}
              onClick={e => e.stopPropagation()}
              onChange={() => this.toggleSelectAll()}
            />
          ),
          renderBodyCell: ({ row }) => (
            <div onClick={e => e.stopPropagation()}>
              <input
                type="checkbox"
                class="!mb-0 align-middle"
                domPropsChecked={this.isSelected(row.id)}
                onChange={() => this.toggleSelect(row.id)}
              />
            </div>
          ),
        },
        {
          field: 'edit',
          key: 'edit',
          align: 'left',
          width: 48,
          // Editar desde la cola. El .stop en el wrapper impide abrir el detalle.
          // Oculto en cerrado/cancelado (solo lectura).
          renderBodyCell: ({ row }) =>
            ['closed', 'cancelled'].includes(row.status) ? null : (
              <div onClick={e => e.stopPropagation()}>
                <woot-button
                  size="tiny"
                  variant="clear"
                  color-scheme="secondary"
                  icon="edit"
                  title={this.$t('CASE_TICKETS.EDIT.BUTTON')}
                  onClick={() => this.openEdit(row)}
                />
              </div>
            ),
        },
        {
          field: 'folio',
          key: 'folio',
          title: this.$t('CASE_TICKETS.TABLE.FOLIO'),
          align: 'left',
          width: 130,
          // El propio folio se colorea según el SLA (verde a tiempo, ámbar en
          // riesgo, rojo vencido); reemplaza al punto de color anterior.
          renderBodyCell: ({ row }) => (
            <span
              class={`font-mono text-sm font-semibold whitespace-nowrap ${this.slaTextColor(
                row.sla_status
              )}`}
              title={row.sla_status}
            >
              {row.folio || '—'}
            </span>
          ),
        },
        {
          field: 'title',
          key: 'title',
          title: this.$t('CASE_TICKETS.TABLE.CONTACT_SUBJECT'),
          align: 'left',
          width: 360,
          // Dos líneas: arriba el contacto, abajo el asunto (badges + título).
          renderBodyCell: ({ row }) => (
            <div class="min-w-0">
              <p class="m-0 text-base font-semibold truncate text-slate-700 dark:text-slate-200">
                {row.contact_name || this.$t('CASE_TICKETS.INTERNAL.NO_CONTACT')}
              </p>
              <div class="flex items-center gap-2 mt-1.5 min-w-0">
                {row.case_type ? (
                  <span
                    class="px-1.5 py-0.5 text-[10px] font-medium uppercase tracking-wide rounded text-white flex-shrink-0"
                    style={{ backgroundColor: row.case_type.color }}
                  >
                    {row.case_type.name}
                  </span>
                ) : null}
                {row.is_internal ? (
                  <span class="px-1.5 py-0.5 text-[10px] font-medium uppercase tracking-wide rounded bg-violet-100 text-violet-800 dark:bg-violet-900 dark:text-violet-300 flex-shrink-0">
                    {this.$t('CASE_TICKETS.INTERNAL.BADGE')}
                  </span>
                ) : null}
                <span class="text-xs truncate text-slate-500 dark:text-slate-400">
                  {row.title}
                </span>
              </div>
            </div>
          ),
        },
        {
          field: 'assignee',
          key: 'assignee',
          title: this.$t('CASE_TICKETS.TABLE.ASSIGNEE'),
          align: 'left',
          width: 150,
          renderBodyCell: ({ row }) => (
            <span class="whitespace-nowrap text-slate-600 dark:text-slate-300">
              {this.assigneeName(row) || '—'}
            </span>
          ),
        },
        {
          field: 'priority',
          key: 'priority',
          title: this.$t('CASE_TICKETS.TABLE.PRIORITY'),
          align: 'left',
          width: 120,
          sortBy: this.sortConfig.priority || '',
          renderBodyCell: ({ row }) => (
            <span
              class={`px-1.5 py-0.5 text-[10px] font-medium uppercase tracking-wide rounded ${this.priorityBadge(
                row.priority
              )}`}
            >
              {this.priorityLabel(row.priority)}
            </span>
          ),
        },
        {
          field: 'status',
          key: 'status',
          title: this.$t('CASE_TICKETS.TABLE.STATUS'),
          align: 'left',
          width: 150,
          sortBy: this.sortConfig.status || '',
          renderBodyCell: ({ row }) => (
            <span class="whitespace-nowrap text-slate-600 dark:text-slate-300">
              {this.statusLabel(this.displayStatus(row.status))}
            </span>
          ),
        },
        {
          field: 'due_at',
          key: 'due_at',
          title: this.$t('CASE_TICKETS.TABLE.DUE'),
          align: 'left',
          width: 140,
          sortBy: this.sortConfig.due_at || '',
          renderBodyCell: ({ row }) => (
            <span
              class={
                row.due_overdue
                  ? 'text-xs font-bold text-red-600 dark:text-red-400 whitespace-nowrap'
                  : 'text-xs text-slate-600 dark:text-slate-300 whitespace-nowrap'
              }
            >
              {this.formatDue(row)}
            </span>
          ),
        },
        {
          field: 'created_at',
          key: 'created_at',
          title: this.$t('CASE_TICKETS.TABLE.CREATED'),
          align: 'left',
          width: 130,
          sortBy: this.sortConfig.created_at || '',
          renderBodyCell: ({ row }) => (
            <span class="text-xs whitespace-nowrap text-slate-400 dark:text-slate-500">
              {this.formatDate(row.created_at)}
            </span>
          ),
        },
      ];
    },
  },
  watch: {
    // Mantiene el estado visual del orden en VeTable en sync con los controles
    // del toolbar (select "Ordenar por" + botón asc/desc).
    sortBy() {
      this.setSortConfig();
    },
    sortOrder() {
      this.setSortConfig();
    },
  },
  mounted() {
    this.setSortConfig();
    this.$store.dispatch('caseTickets/fetchTypes');
    this.$store.dispatch('caseTickets/fetchSettings'); // modo simple/ITIL
    this.$store.dispatch('agents/get'); // @tickets_cases P3 — para asignar y mostrar nombre
    this.fetch();
  },
  methods: {
    // @tickets_cases Fase C — tras crear un ticket interno, refresca el listado.
    onInternalCreated() {
      this.showInternalModal = false;
      this.currentPage = 1;
      this.fetch();
    },
    // @tickets_cases — editar desde la cola: el listado ya trae el ticket
    // completo (mismo ticket_json que el detalle), así que se pasa tal cual.
    openEdit(ticket) {
      this.editingTicket = ticket;
    },
    onInternalUpdated() {
      this.editingTicket = null;
      this.fetch();
    },
    fetch() {
      this.selected = []; // @tickets_cases P3 — la selección es por vista
      const filters = { page: this.currentPage, per_page: this.perPage };
      if (this.search.trim()) filters.q = this.search.trim();
      if (this.dateRange[0])
        filters.date_from = this.formatDateParam(this.dateRange[0]);
      if (this.dateRange[1])
        filters.date_to = this.formatDateParam(this.dateRange[1]);
      if (this.statusFilter) filters.status = this.statusFilter;
      if (this.priorityFilter) filters.priority = this.priorityFilter;
      if (this.originFilter) filters.origin = this.originFilter;
      if (this.activeFilter === 'sla_overdue') filters.sla_status = 'overdue';
      if (this.activeFilter === 'unassigned') filters.assignee_id = 'null';
      if (this.activeFilter === 'mine')
        filters.assignee_id = this.currentUserID;
      if (this.activeType) filters.case_type_id = this.activeType;
      filters.sort_by = this.sortBy;
      filters.sort_order = this.sortOrder;
      this.$store.dispatch('caseTickets/fetchTickets', filters);
    },
    onSearchInput() {
      clearTimeout(this.searchDebounce);
      this.searchDebounce = setTimeout(() => {
        this.currentPage = 1;
        this.fetch();
      }, 350);
    },
    clearSearch() {
      this.search = '';
      this.currentPage = 1;
      this.fetch();
    },
    onDateChange(value) {
      this.dateRange = value || [];
      this.currentPage = 1;
      this.fetch();
    },
    onFilterChange() {
      this.currentPage = 1;
      this.fetch();
    },
    toggleSortOrder() {
      this.sortOrder = this.sortOrder === 'asc' ? 'desc' : 'asc';
      this.fetch();
    },
    applyFilter(key) {
      this.activeFilter = key;
      this.currentPage = 1;
      this.fetch();
    },
    onQuickTabChange(index) {
      this.applyFilter(QUICK_FILTERS[index].key);
    },
    clearFilters() {
      this.search = '';
      this.dateRange = [];
      this.statusFilter = '';
      this.priorityFilter = '';
      this.originFilter = '';
      this.activeFilter = 'mine';
      this.activeType = '';
      this.currentPage = 1;
      this.fetch();
    },
    changePage(page) {
      this.currentPage = page;
      this.fetch();
    },
    changePerPage() {
      this.currentPage = 1;
      this.fetch();
    },
    openDetail(ticket) {
      this.$router.push({
        name: 'gestorTickets_detail',
        params: { id: ticket.id },
      });
    },
    // @tickets_cases P3 — selección múltiple
    isSelected(id) {
      return this.selected.includes(id);
    },
    toggleSelect(id) {
      const i = this.selected.indexOf(id);
      if (i === -1) this.selected.push(id);
      else this.selected.splice(i, 1);
    },
    toggleSelectAll() {
      if (this.allSelected) {
        this.selected = this.selected.filter(id => !this.pageIds.includes(id));
      } else {
        this.selected = [...new Set([...this.selected, ...this.pageIds])];
      }
    },
    clearSelection() {
      this.selected = [];
      this.showBulkAssign = false;
      this.showBulkStatus = false;
    },
    // Refleja el orden actual en el `sortBy` de cada columna de VeTable.
    setSortConfig() {
      this.sortConfig = { [this.sortBy]: this.sortOrder };
    },
    // VeTable emite el estado de orden de todas las columnas; se toma la que
    // quedó activa (valor 'asc'/'desc') y se pide al servidor con ese orden.
    onSortChange(params) {
      const field = Object.keys(params).find(k => params[k]);
      if (!field) return;
      this.sortBy = field;
      this.sortOrder = params[field];
      this.currentPage = 1;
      this.fetch();
    },
    assigneeName(ticket) {
      if (!ticket.assignee_id) return null;
      const a = this.agents.find(x => x.id === ticket.assignee_id);
      return a ? a.name : `#${ticket.assignee_id}`;
    },
    // @tickets_cases P3 — acciones en lote
    async runBulk(params) {
      if (!this.selected.length) return;
      try {
        const res = await this.$store.dispatch('caseTickets/bulkAction', {
          ids: this.selected,
          ...params,
        });
        this.$emitter.emit('newToastMessage', {
          message: this.$t('CASE_TICKETS.BULK.SUCCESS', {
            n: res.updated || 0,
          }),
        });
        this.clearSelection();
        this.fetch();
      } catch (e) {
        this.$emitter.emit('newToastMessage', {
          message:
            e.response?.data?.error || this.$t('CASE_TICKETS.BULK.ERROR'),
        });
      }
    },
    bulkClaim() {
      this.runBulk({ bulk_action: 'assign', assignee_id: 'me' });
    },
    bulkAssign(agentId) {
      this.showBulkAssign = false;
      this.runBulk({ bulk_action: 'assign', assignee_id: agentId });
    },
    bulkUnassign() {
      this.showBulkAssign = false;
      this.runBulk({ bulk_action: 'assign', assignee_id: '' });
    },
    bulkStatus(status) {
      this.showBulkStatus = false;
      this.runBulk({ bulk_action: 'transition', status });
    },
    bulkClose() {
      this.runBulk({ bulk_action: 'transition', status: 'closed' });
    },
    formatDateParam(d) {
      const date = d instanceof Date ? d : new Date(d);
      const y = date.getFullYear();
      const m = String(date.getMonth() + 1).padStart(2, '0');
      const day = String(date.getDate()).padStart(2, '0');
      return `${y}-${m}-${day}`;
    },
    // @tickets_cases — color del folio según el SLA (verde a tiempo, ámbar en
    // riesgo, rojo vencido). Antes era un punto; ahora tiñe el propio número.
    slaTextColor(sla) {
      return (
        {
          on_time: 'text-green-600 dark:text-green-400',
          at_risk: 'text-yellow-600 dark:text-yellow-400',
          overdue: 'text-red-600 dark:text-red-400',
        }[sla] || 'text-green-600 dark:text-green-400'
      );
    },
    priorityBadge(p) {
      return (
        {
          low: 'bg-slate-100 text-slate-700 dark:bg-slate-700 dark:text-slate-300',
          medium:
            'bg-blue-100 text-blue-800 dark:bg-blue-900 dark:text-blue-300',
          high: 'bg-yellow-100 text-yellow-800 dark:bg-yellow-900 dark:text-yellow-300',
          urgent: 'bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-300',
        }[p] || 'bg-slate-100 text-slate-700'
      );
    },
    statusLabel(key) {
      return this.$t(`CASE_TICKETS.STATUSES.${key}`) || key;
    },
    displayStatus(s) {
      return this.itilEnabled ? s : toSimpleStatus(s);
    },
    priorityLabel(key) {
      return this.$t(`CASE_TICKETS.PRIORITIES.${key}`) || key;
    },
    originLabel(key) {
      return this.$t(`CASE_TICKETS.ORIGINS.${key}`) || key;
    },
    formatDate(dateStr) {
      if (!dateStr) return '';
      return new Date(dateStr).toLocaleDateString(undefined, {
        day: '2-digit',
        month: '2-digit',
        year: 'numeric',
      });
    },
    // @tickets_cases P4 — vencimiento (osTicket "Due Date"): fecha efectiva corta.
    formatDue(ticket) {
      if (!ticket.effective_due_at) return '—';
      return new Date(ticket.effective_due_at).toLocaleString(undefined, {
        day: '2-digit',
        month: '2-digit',
        hour: '2-digit',
        minute: '2-digit',
      });
    },
  },
};
</script>

<style lang="scss" scoped>
// @tickets_cases — mismos ajustes que Notas/Tareas: celdas compactas, cabecera
// mini y la cadena de alturas que hace que scrolleen solo las filas.
.tickets-table-wrap {
  overflow: hidden;
}

.tickets-table-wrap::v-deep {
  // Sin esta altura el `max-height: 100%` de la tabla no resuelve (porcentaje
  // contra `auto`) y la cola se desborda del contenedor en vez de scrollear.
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

  // Fila seleccionada: la clase la pinta `cellStyleOption.bodyCellClass` en cada
  // celda, así que el fondo va sobre la propia celda.
  .ve-table-body-td.row--selected {
    @apply bg-woot-25 dark:bg-woot-800/20;
  }
}
</style>
