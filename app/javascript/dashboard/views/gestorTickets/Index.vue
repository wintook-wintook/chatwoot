<!--
  @tickets_cases
  Vista principal del Gestor de Tickets — Lista por clase (Plan-Casos E1/E1.1):
  clase + tipo, ¿de quién?, estado, búsqueda y filtros finos; orden desde los
  encabezados de la tabla y paginación. Tailwind + dark mode.
-->
<template>
  <div
    class="flex flex-col flex-1 w-full h-full overflow-hidden bg-slate-25 dark:bg-slate-900"
  >
    <!-- Header — Plan-Casos E1.1: los filtros por niveles.
         1) clase · vistas · nuevo  2) ¿de quién?
         3) tipo + estado/resultado + búsqueda + filtros finos (+ SLA), todo a
         32 px de alto. El orden se cambia desde los encabezados de la tabla. -->
    <div
      class="flex-shrink-0 px-6 pt-4 bg-white border-b dark:bg-slate-900 border-slate-50 dark:border-slate-800/50"
    >
      <div class="flex flex-wrap items-center justify-between gap-3 mb-3">
        <!-- Plan-Casos E1 — el selector Comercial | Soporte es el título -->
        <CaseClassSwitcher :case-class="caseClass" :title="listTitle" />

        <div class="flex items-center gap-2">
          <!-- @tickets_cases F3 — vistas guardadas, en un solo menú -->
          <div v-on-clickaway="closeViewsMenu" class="relative">
            <woot-button
              size="small"
              variant="smooth"
              color-scheme="secondary"
              icon="chevron-down"
              @click="showViewsMenu = !showViewsMenu"
            >
              {{
                activeView ? activeView.name : $t('CASE_TICKETS.FILTERS.VIEWS')
              }}
              <span
                v-if="isViewDirty"
                class="inline-block w-1.5 h-1.5 ml-1 rounded-full bg-amber-500"
                :title="$t('CASE_TICKETS.VIEWS.DIRTY_HINT')"
              />
            </woot-button>
            <woot-button
              v-if="activeView"
              size="small"
              variant="clear"
              color-scheme="secondary"
              icon="dismiss"
              class="!ml-0.5"
              :title="$t('CASE_TICKETS.VIEWS.DETACH_HINT')"
              :aria-label="$t('CASE_TICKETS.VIEWS.DETACH')"
              @click="detachView"
            />
            <div
              v-if="showViewsMenu"
              class="absolute right-0 z-50 py-1 mt-1 overflow-y-auto bg-white border rounded-md shadow-md top-full dark:bg-slate-800 border-slate-100 dark:border-slate-700 min-w-[240px] max-h-96"
            >
              <button
                v-if="activeView"
                type="button"
                class="flex items-center w-full gap-2 px-4 py-1.5 text-sm text-left text-slate-600 dark:text-slate-300 hover:bg-slate-50 dark:hover:bg-slate-700"
                :title="$t('CASE_TICKETS.VIEWS.DETACH_HINT')"
                @click="detachView"
              >
                <fluent-icon icon="dismiss" size="14" />
                {{ $t('CASE_TICKETS.VIEWS.DETACH') }}
              </button>
              <div
                v-if="activeView"
                class="my-1 border-t border-slate-100 dark:border-slate-700"
              />
              <template v-for="group in viewGroups">
                <p
                  :key="`h-${group.key}`"
                  class="px-4 pt-2 pb-1 m-0 text-[11px] font-semibold tracking-wide uppercase text-slate-400 dark:text-slate-500"
                >
                  {{ group.label }}
                </p>
                <button
                  v-for="v in group.views"
                  :key="v.id"
                  type="button"
                  class="flex items-center w-full gap-2 px-4 py-1.5 text-sm text-left text-slate-600 dark:text-slate-300 hover:bg-slate-50 dark:hover:bg-slate-700"
                  @click="selectView(v)"
                >
                  <span class="flex-1 truncate">
                    {{ v.name
                    }}<span
                      v-if="group.key === 'shared'"
                      class="text-xs text-slate-400"
                    >
                      · {{ v.owner_name }}</span
                    >
                  </span>
                  <fluent-icon
                    v-if="v.id === activeViewId"
                    icon="checkmark"
                    size="14"
                    class="text-woot-500"
                  />
                </button>
              </template>
              <p
                v-if="!viewGroups.length"
                class="px-4 py-2 m-0 text-sm text-slate-400 dark:text-slate-500"
              >
                {{ $t('CASE_TICKETS.VIEWS.PLACEHOLDER') }}
              </p>
              <div
                class="my-1 border-t border-slate-100 dark:border-slate-700"
              />
              <button
                v-if="isViewDirty && canOverwriteView"
                type="button"
                class="flex items-center w-full gap-2 px-4 py-1.5 text-sm text-left text-slate-600 dark:text-slate-300 hover:bg-slate-50 dark:hover:bg-slate-700"
                @click="
                  overwriteView();
                  showViewsMenu = false;
                "
              >
                <fluent-icon icon="save" size="14" />
                {{ $t('CASE_TICKETS.VIEWS.SAVE') }}
              </button>
              <button
                type="button"
                class="flex items-center w-full gap-2 px-4 py-1.5 text-sm text-left text-slate-600 dark:text-slate-300 hover:bg-slate-50 dark:hover:bg-slate-700"
                @click="
                  showSaveViewModal = true;
                  showViewsMenu = false;
                "
              >
                <fluent-icon icon="copy" size="14" />
                {{ $t('CASE_TICKETS.VIEWS.SAVE_AS') }}
              </button>
              <button
                type="button"
                class="flex items-center w-full gap-2 px-4 py-1.5 text-sm text-left text-slate-600 dark:text-slate-300 hover:bg-slate-50 dark:hover:bg-slate-700"
                @click="
                  showManageViewsModal = true;
                  showViewsMenu = false;
                "
              >
                <fluent-icon icon="settings" size="14" />
                {{ $t('CASE_TICKETS.VIEWS.MANAGE.TITLE') }}
              </button>
            </div>
          </div>

          <!-- Plan-Casos E2 — «+ {tipo}» o, en «Todos los tipos», «+ {clase}» -->
          <woot-button
            size="small"
            icon="add"
            @click="showInternalModal = true"
          >
            {{ createLabel }}
          </woot-button>
        </div>
      </div>

      <!-- ¿De quién? (fila 2) y la fila de filtros: tipo · estado/resultado ·
           búsqueda · filtros finos · SLA -->
      <CaseScopeBar
        :case-class="caseClass"
        :scope="activeFilter"
        :status="statusFilter"
        :outcome="outcomeFilter"
        :stage="stageFilter"
        :sla-only="slaOverdueOnly"
        :sla-count="slaOverdueCount"
        @scope="applyFilter"
        @status="onStatusChange"
        @outcome="onOutcomeChange"
        @stage="onStageChange"
        @sla="onSlaChange"
      >
        <template #before>
          <CaseTypeSelect
            :case-class="caseClass"
            :value="activeType"
            @input="onTypeChange"
          />
        </template>
        <div class="relative flex-1 min-w-[220px] max-w-md">
          <fluent-icon
            icon="search"
            size="16"
            class="absolute -translate-y-1/2 left-3 top-1/2 text-slate-400 dark:text-slate-500"
          />
          <input
            v-model="search"
            type="text"
            class="w-full !h-8 pl-9 pr-9 !mb-0 text-sm"
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
        <CaseFineFilters
          :case-class="caseClass"
          :value="fine"
          :scope="activeFilter"
          :case-type-id="activeType"
          :itil="filteredTypeItilEnabled"
          :status="statusFilter"
          :outcome="outcomeFilter"
          :stage="stageFilter"
          @input="onFineChange"
        />
      </CaseScopeBar>
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
          {{ $t('CASE_TICKETS.BULK.CLEAR') }}
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
      :case-class="caseClass"
      :preset-type-id="activeType"
      @created="onInternalCreated"
      @close="showInternalModal = false"
    />

    <!-- @tickets_cases F3 — guardar los filtros actuales como vista -->
    <AddCustomViews
      v-if="showSaveViewModal"
      :filter-type="viewFilterType"
      :custom-views-query="viewQuery"
      allow-shared
      :success-message="$t('CASE_TICKETS.VIEWS.SAVED')"
      :open-last-saved-item="onViewSaved"
      @close="showSaveViewModal = false"
    />

    <!-- @tickets_cases F5 — gestionar las vistas guardadas -->
    <SavedViewsModal
      v-if="showManageViewsModal"
      @changed="onViewsChanged"
      @close="showManageViewsModal = false"
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

<!-- eslint-disable vue/block-order -- legacy file has <template> before
     <script>; reordering is a large unrelated diff, left for a dedicated
     cleanup instead of bundling it into an unrelated change. -->
<script>
import { mapGetters } from 'vuex';
import { VeTable } from 'vue-easytable';
import { useAlert } from 'dashboard/composables';
import TableFooter from 'dashboard/components/widgets/TableFooter.vue'; // @tickets_cases — paginado estándar
import CaseTicketInternalModal from './CaseTicketInternalModal.vue'; // @tickets_cases Fase C
import AddCustomViews from 'dashboard/routes/dashboard/customviews/AddCustomViews.vue'; // @tickets_cases F3 — vistas guardadas
import SavedViewsModal from './SavedViewsModal.vue'; // @tickets_cases F5 — gestion de vistas
import CaseClassSwitcher from './CaseClassSwitcher.vue'; // Plan-Casos E1
// Plan-Casos E1.1 — filtros por niveles.
import CaseTypeSelect from './filters/CaseTypeSelect.vue';
import CaseScopeBar from './filters/CaseScopeBar.vue';
import CaseFineFilters from './filters/CaseFineFilters.vue';
import {
  SCOPES,
  emptyFineFilters,
  fineFiltersToParams,
  scopeToParams,
  statusForResult,
  stageToParams,
  hasStages,
  alertApplies,
  classAlertParams,
  DEFAULT_COMMERCIAL_RESULT,
  DEFAULT_WORK_ORDER_STAGE,
} from 'dashboard/helper/caseFilters';
import {
  CLASS_VIEW_ROUTES,
  classHasSla,
  classI18nBase,
  loadCaseState,
  saveCaseState,
  typesOfClass,
} from 'dashboard/helper/caseClasses';
import {
  SIMPLE_FILTER_STATUSES,
  toSimpleStatus,
} from 'dashboard/helper/caseSimpleStatus'; // modo simple/ITIL
// Plan-Clase-Comercial F4 — lista de oportunidades.
import { formatHours } from 'dashboard/helper/caseWorkOrder'; // Plan-Clase-Orden-de-Trabajo F2b
import {
  COMMERCIAL_CLASS,
  OUTCOME_BADGE,
  POSTPONED_BADGE,
  formatDay,
  formatMoney,
} from 'dashboard/helper/caseCommercial';

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
const SORT_FIELDS = ['created_at', 'priority', 'status', 'sla_status'];

// Diseño de la tabla (2026-10-20): una sola forma de etiqueta —píldora de 11 px,
// sin mayúsculas— para tipo, prioridad, estado y etapa.
const PILL =
  'inline-flex items-center px-2 py-0.5 text-[11px] font-medium rounded-full whitespace-nowrap';
// Estado → color por grupo del ciclo de vida (en curso, en espera, resuelto,
// cerrado). Se agrupa sobre el estado real, así sirve en modo simple e ITIL.
const STATUS_PILL = {
  open: 'bg-sky-50 text-sky-800 dark:bg-sky-900/40 dark:text-sky-300',
  in_progress: 'bg-sky-50 text-sky-800 dark:bg-sky-900/40 dark:text-sky-300',
  waiting_on_customer:
    'bg-amber-50 text-amber-800 dark:bg-amber-900/40 dark:text-amber-300',
  resolved:
    'bg-emerald-50 text-emerald-800 dark:bg-emerald-900/40 dark:text-emerald-300',
  closed:
    'bg-slate-100 text-slate-600 dark:bg-slate-700/60 dark:text-slate-300',
  cancelled:
    'bg-slate-100 text-slate-500 line-through dark:bg-slate-700/60 dark:text-slate-400',
};
// Etapa abierta de una oportunidad: el violeta de la clase Comercial.
const STAGE_PILL =
  'bg-violet-50 text-violet-800 dark:bg-violet-900/40 dark:text-violet-300';
// Plan-Clase-Comercial F4 — la lista de oportunidades ordena por sus datos, no por SLA.
const COMMERCIAL_SORT_FIELDS = [
  'created_at',
  'amount',
  'expected_close_at',
  'probability',
  'priority',
  'status',
];
// @tickets_cases F3 — las vistas guardadas se direccionan por nombre de tipo,
// igual que el Sidebar y el store de customViews.
const VIEW_FILTER_TYPE = 'case_ticket';
// Version de la forma del `query` guardado. v2 (Plan-Casos E1.1): clase,
// SLA vencido como aviso y filtros finos en `fine`. Una vista v1 se sigue
// abriendo: `normalizeViewQuery` traduce sus claves sueltas a la forma nueva.
const VIEW_QUERY_VERSION = 2;

// Cualquier `query` guardado (v1 o v2) → forma completa y comparable.
const normalizeViewQuery = (q = {}) => {
  const { postponed: legacyPostponed, ...savedFine } = q.fine || {};
  const fine = { ...emptyFineFilters(), ...savedFine };
  if (!q.fine) {
    fine.priority = q.priority || '';
    fine.origin = q.origin || '';
    const [from, to] = Array.isArray(q.date_range) ? q.date_range : [];
    fine.created_from = from || '';
    fine.created_to = to || '';
  }
  // v1 tenía «SLA vencidos» como pestaña: ahora es «Todos» + el aviso de SLA.
  const legacySla = q.quick === 'sla_overdue';
  let quick = legacySla ? 'all' : 'mine';
  if (SCOPES.includes(q.quick)) quick = q.quick;
  return {
    case_class: q.case_class || '',
    search: q.search || '',
    // E1.3: «Solo pospuestas» dejó de ser filtro fino; ahora es un resultado.
    status: legacyPostponed ? 'pending' : q.status ?? 'pending',
    outcome: legacyPostponed ? 'postponed' : q.outcome || '',
    stage: q.stage || '', // Plan-Clase-Orden-de-Trabajo F2b
    quick,
    sla_overdue: !!q.sla_overdue || legacySla,
    case_type_id: q.case_type_id || '',
    fine,
    sort_by: q.sort_by || 'created_at',
    sort_order: q.sort_order === 'asc' ? 'asc' : 'desc',
  };
};
const PER_PAGE_OPTIONS = [25, 50, 100];

export default {
  name: 'GestorTicketsIndex',
  components: {
    VeTable,
    TableFooter,
    CaseTicketInternalModal,
    AddCustomViews,
    SavedViewsModal,
    CaseClassSwitcher,
    CaseTypeSelect,
    CaseScopeBar,
    CaseFineFilters,
  },
  props: {
    // Plan-Casos E1 — clase de la ruta `tickets/:caseClass/list`:
    // 'commercial' = oportunidades; 'support' = tickets.
    caseClass: { type: String, default: 'support' },
  },
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
      // @tickets_cases — default: solo pendientes. 'closed' agrupa
      // resuelto/validando/cerrado/cancelado; '' es "todos los estados".
      statusFilter: 'pending',
      // Plan-Casos E1.1 — ¿de quién? (mine|unassigned|all), aviso de SLA
      // vencido aparte, y los filtros finos del botón «Filtros».
      activeFilter: 'mine',
      slaOverdueOnly: false,
      fine: emptyFineFilters(),
      activeType: '', // '' = todos, o un case_type_id
      outcomeFilter: '', // Plan-Clase-Comercial F4 — won|lost|cancelled
      stageFilter: '', // Plan-Clase-Orden-de-Trabajo F2b — etapa de una orden
      sortBy: 'created_at',
      sortOrder: 'desc',
      currentPage: 1,
      perPage: 25,
      // @tickets_cases F3 — vistas guardadas
      activeViewId: '',
      pendingViewId: null, // vista de OTRA clase: se aplica al llegar a su ruta
      showViewsMenu: false,
      showSaveViewModal: false,
      showManageViewsModal: false,
    };
  },
  computed: {
    ...mapGetters({
      tickets: 'caseTickets/getTicketsList',
      meta: 'caseTickets/getTicketsMeta',
      uiFlags: 'caseTickets/getUIFlags',
      types: 'caseTickets/getTypes',
      currentUserID: 'getCurrentUserID', // @tickets_cases — filtro "Mis Casos"
      currentRole: 'getCurrentRole', // @tickets_cases F4 — quien puede sobreescribir una vista
      anyTypeItilEnabled: 'caseTickets/getAnyTypeItilEnabled',
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
    // ── Plan-Clase-Comercial F4 ──
    // Órdenes y Proyectos: combo de etapa en vez de Pendientes/Cerrados.
    hasStageFilter() {
      return hasStages(this.caseClass);
    },
    isProjectList() {
      return this.caseClass === 'project';
    },
    isWorkOrderList() {
      return this.caseClass === 'work_order';
    },
    isCommercialList() {
      return this.caseClass === COMMERCIAL_CLASS;
    },
    // Plan-Clase-Orden-de-Trabajo F1 — solo los tipos de la clase de la vista.
    visibleTypes() {
      return typesOfClass(this.types, this.caseClass);
    },
    // Plan-Casos E2 — etiqueta del botón de alta: el tipo elegido o la clase.
    createLabel() {
      const type = (this.types || []).find(
        t => String(t.id) === String(this.activeType)
      );
      return (
        type?.name || this.$t(`CASE_TICKETS.CLASSES.${this.caseClassKey}.NAME`)
      );
    },
    listTitle() {
      return this.$t(`${classI18nBase(this.caseClass)}.LIST`);
    },
    // Clave i18n de la clase (COMMERCIAL / SUPPORT / WORK_ORDER).
    caseClassKey() {
      return classI18nBase(this.caseClass).split('.').pop();
    },
    sortFields() {
      return this.isCommercialList ? COMMERCIAL_SORT_FIELDS : SORT_FIELDS;
    },
    // Contexto del aviso rojo: clase y lo que se ve (estado, resultado, etapa).
    alertContext() {
      return {
        caseClass: this.caseClass,
        status: this.statusFilter,
        outcome: this.outcomeFilter,
        stage: this.stageFilter,
      };
    },
    slaOverdueCount() {
      // Aviso rojo de la clase: SLA vencido / visitas vencidas / cierre vencido.
      return this.meta.alert_count || 0;
    },
    // Con un tipo filtrado, usa el modo de ESE tipo; sin filtro, no se oculta
    // nada relevante si al menos un tipo de la cuenta usa ITIL.
    filteredTypeItilEnabled() {
      if (!this.activeType) return this.anyTypeItilEnabled;
      const type = (this.types || []).find(
        t => String(t.id) === String(this.activeType)
      );
      return type ? !!type.itil_enabled : this.anyTypeItilEnabled;
    },
    statusOptions() {
      return this.filteredTypeItilEnabled
        ? STATUS_OPTIONS
        : SIMPLE_FILTER_STATUSES;
    },
    perPageOptions() {
      return PER_PAGE_OPTIONS;
    },
    // @tickets_cases F3 — vistas guardadas de tickets, separadas en dos grupos:
    // las mias y las que alguien de la cuenta compartio.
    viewFilterType() {
      return VIEW_FILTER_TYPE;
    },
    savedViews() {
      return this.$store.getters['customViews/getCustomViewsByFilterType'](
        VIEW_FILTER_TYPE
      );
    },
    myViews() {
      return this.savedViews.filter(v => v.user_id === this.currentUserID);
    },
    sharedViews() {
      return this.savedViews.filter(v => v.user_id !== this.currentUserID);
    },
    activeView() {
      return this.savedViews.find(v => v.id === this.activeViewId) || null;
    },
    // Menú «Vistas»: mis vistas y las compartidas (solo grupos con algo).
    viewGroups() {
      return [
        {
          key: 'mine',
          label: this.$t('CASE_TICKETS.VIEWS.MINE'),
          views: this.myViews,
        },
        {
          key: 'shared',
          label: this.$t('CASE_TICKETS.VIEWS.SHARED'),
          views: this.sharedViews,
        },
      ].filter(g => g.views.length);
    },
    // @tickets_cases F4 — ¿lo que se ve en pantalla sigue siendo la vista
    // cargada? Sin esta senal nadie sabe si esta viendo la vista o algo que
    // toco encima, que es la queja clasica de este tipo de barra.
    isViewDirty() {
      if (!this.activeView) return false;
      return (
        this.canonicalQuery(this.viewQuery) !==
        this.canonicalQuery(this.activeView.query)
      );
    },
    // Sobreescribe su dueno; un administrador tambien, pero solo sobre las
    // compartidas. Es la misma regla que aplica el backend, repetida aqui solo
    // para no ofrecer un boton que va a devolver 401.
    canOverwriteView() {
      if (!this.activeView) return false;
      if (this.activeView.user_id === this.currentUserID) return true;
      return this.currentRole === 'administrator' && this.activeView.shared;
    },
    // Lo que se guarda al pulsar "Guardar como": el estado de filtros, sin
    // pagina ni tamano de pagina, que son navegacion y no criterio.
    viewQuery() {
      return {
        v: VIEW_QUERY_VERSION,
        case_class: this.caseClass,
        search: this.search,
        status: this.statusFilter,
        outcome: this.outcomeFilter,
        stage: this.stageFilter,
        quick: this.activeFilter,
        sla_overdue: this.slaOverdueOnly,
        case_type_id: this.activeType,
        fine: this.fine,
        sort_by: this.sortBy,
        sort_order: this.sortOrder,
      };
    },
    // @tickets_cases — columnas de la cola en VeTable (tabla nativa de Chatwoot,
    // igual que Contactos/Notas/Tareas). Las celdas se pintan con renderBodyCell
    // (JSX). El orden de prioridad/estado/vence/creado es en servidor: cada
    // columna declara su `sortBy` desde `sortConfig` y VeTable emite `sortChange`.
    columns() {
      const cols = [
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
          // Folio en gris oscuro; el SLA va en un punto delante (verde a tiempo,
          // ámbar en riesgo, rojo vencido) con su nombre al pasar el mouse.
          // Solo las clases con SLA (Soporte) llevan punto.
          renderBodyCell: ({ row }) => (
            <span class="inline-flex items-center gap-1.5 font-mono text-sm font-semibold whitespace-nowrap text-slate-700 dark:text-slate-200">
              {!classHasSla(row.case_type?.case_class || 'support') ? null : (
                <span
                  class={`inline-block w-2 h-2 rounded-full flex-shrink-0 ${this.slaDotColor(
                    row.sla_status
                  )}`}
                  title={this.statusLabel(row.sla_status || 'on_time')}
                />
              )}
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
              <p class="m-0 text-sm font-semibold truncate text-slate-800 dark:text-slate-100">
                {row.contact_name || this.noContactName(row)}
              </p>
              <div class="flex items-center gap-2 mt-1 min-w-0">
                {row.case_type ? (
                  <span
                    class={`${PILL} text-white flex-shrink-0`}
                    style={{ backgroundColor: row.case_type.color }}
                  >
                    {row.case_type.name}
                  </span>
                ) : null}
                {row.is_internal ? (
                  <span
                    class={`${PILL} flex-shrink-0 bg-violet-100 text-violet-800 dark:bg-violet-900/40 dark:text-violet-300`}
                  >
                    {this.$t('CASE_TICKETS.INTERNAL.BADGE')}
                  </span>
                ) : null}
                <span class="text-[13px] truncate text-slate-500 dark:text-slate-400">
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
            <span class="text-sm whitespace-nowrap text-slate-700 dark:text-slate-300">
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
            <span class={`${PILL} ${this.priorityBadge(row.priority)}`}>
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
            <span class={`${PILL} ${this.statusPill(row.status)}`}>
              {this.statusLabel(this.displayStatus(row))}
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
                  ? 'text-[13px] tabular-nums font-semibold text-red-600 dark:text-red-400 whitespace-nowrap'
                  : 'text-[13px] tabular-nums text-slate-600 dark:text-slate-300 whitespace-nowrap'
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
            <span class="text-[13px] tabular-nums whitespace-nowrap text-slate-500 dark:text-slate-400">
              {this.formatDate(row.created_at)}
            </span>
          ),
        },
      ];
      if (this.isCommercialList) return this.commercialColumns(cols);
      if (this.isProjectList) return this.projectColumns(cols);
      return this.isWorkOrderList ? this.workOrderColumns(cols) : cols;
    },
  },
  watch: {
    // Plan-Clase-Comercial F4 — la misma instancia sirve a las dos rutas: al
    // pasar de casos a oportunidades (o al revés) se empieza de cero, salvo que
    // el cambio lo haya pedido una vista guardada de esa clase.
    caseClass() {
      const view = this.savedViews.find(v => v.id === this.pendingViewId);
      this.pendingViewId = null;
      if (view) {
        this.applyView(view);
        return;
      }
      // Plan-Casos E1.2 — cada clase vuelve como la dejaste.
      this.restoreState();
      this.setSortConfig();
      this.fetch();
    },
    // Mantiene el estado visual del orden en VeTable en sync con el orden
    // elegido desde los encabezados de columna.
    sortBy() {
      this.setSortConfig();
    },
    sortOrder() {
      this.setSortConfig();
    },
  },
  mounted() {
    this.restoreState();
    this.setSortConfig();
    this.$store.dispatch('caseTickets/fetchSettings'); // modo simple/ITIL
    this.$store.dispatch('agents/get'); // @tickets_cases P3 — para asignar y mostrar nombre
    this.$store.dispatch('customViews/get', VIEW_FILTER_TYPE); // @tickets_cases F3
    // Plan-Clase-Comercial F4 — los tipos primero: su clase decide si la cola
    // se acota a Soporte (ver fetch).
    this.$store.dispatch('caseTickets/fetchTypes').finally(() => this.fetch());
  },
  methods: {
    // Plan-Casos E1.2 — la Lista vuelve como la dejaste: lo compartido con el
    // Tablero (tipo, ¿de quién?, SLA, filtros finos, búsqueda) y lo suyo
    // (`list`: estado, resultado, orden, página, vista). Guardado por clase en
    // localStorage (helper/caseClasses.js); tolerante a claves ausentes.
    restoreState() {
      const st = loadCaseState(this.$route.params.accountId, this.caseClass);
      const list = st.list || {};
      this.search = st.search || '';
      this.activeFilter = SCOPES.includes(st.scope) ? st.scope : 'mine';
      this.slaOverdueOnly = !!st.sla;
      const { postponed: legacyPostponed, ...savedFine } = st.fine || {};
      this.fine = { ...emptyFineFilters(), ...savedFine };
      this.activeType = st.type ?? '';
      this.statusFilter = list.status ?? 'pending';
      // Comercial arranca en «En curso»; '' guardado = el agente eligió «Todas».
      this.outcomeFilter =
        list.outcome ??
        (this.isCommercialList ? DEFAULT_COMMERCIAL_RESULT : '');
      // E1.3 — «Solo pospuestas» (filtro fino) pasó a ser el resultado Pospuestas.
      if (legacyPostponed && this.isCommercialList) {
        this.outcomeFilter = 'postponed';
      }
      this.syncCommercialStatus();
      // Órdenes arranca en «Abiertas»; '' guardado = «Todas».
      this.stageFilter =
        list.stage ?? (this.hasStageFilter ? DEFAULT_WORK_ORDER_STAGE : '');
      this.sortBy = this.sortFields.includes(list.sortBy)
        ? list.sortBy
        : 'created_at';
      this.sortOrder = list.sortOrder === 'asc' ? 'asc' : 'desc';
      this.currentPage = list.currentPage || 1;
      this.perPage = list.perPage || 25;
      this.activeViewId = list.viewId || '';
    },
    // Se llama en cada fetch(): así no hay que vigilar cada filtro por separado.
    persistState() {
      saveCaseState(this.$route.params.accountId, this.caseClass, {
        search: this.search,
        scope: this.activeFilter,
        sla: this.slaOverdueOnly,
        fine: this.fine,
        type: this.activeType,
        list: {
          status: this.statusFilter,
          outcome: this.outcomeFilter,
          stage: this.stageFilter,
          sortBy: this.sortBy,
          sortOrder: this.sortOrder,
          currentPage: this.currentPage,
          perPage: this.perPage,
          viewId: this.activeViewId,
        },
      });
    },
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
      this.persistState();
      const filters = {
        page: this.currentPage,
        per_page: this.perPage,
        sort_by: this.sortBy,
        sort_order: this.sortOrder,
        ...scopeToParams(this.activeFilter, this.currentUserID),
        // Plan-Casos E1.1 — filtros finos (assignee solo en «Todos»).
        ...fineFiltersToParams(this.fine, this.caseClass, this.activeFilter, {
          itil: this.filteredTypeItilEnabled,
          status: this.statusFilter,
          outcome: this.outcomeFilter,
          stage: this.stageFilter,
        }),
      };
      if (this.search.trim()) filters.q = this.search.trim();
      if (this.statusFilter) filters.status = this.statusFilter;
      if (this.activeType) filters.case_type_id = this.activeType;
      // El aviso de SLA cuenta solo pendientes: en «Todos» acota a pendientes
      // (mismo número que el aviso) y en «Cerrados» no aplica.
      if (
        this.slaOverdueOnly &&
        classHasSla(this.caseClass) &&
        this.statusFilter !== 'closed'
      ) {
        filters.sla_status = 'overdue';
        filters.status = 'pending';
      }
      // Plan-Clase-Comercial F4 — las clases no se mezclan (Soporte incluye los
      // casos sin tipo; ver CaseTicket.of_class).
      filters.case_class = this.caseClass;
      // Plan-Casos E1.3 — resultado: Pospuestas es abierta (postponed); las
      // otras tres son el `outcome` de una cerrada.
      if (this.isCommercialList && this.outcomeFilter) {
        if (this.outcomeFilter === 'postponed') filters.postponed = true;
        else if (this.outcomeFilter === 'active') filters.postponed = false;
        else filters.outcome = this.outcomeFilter;
      }
      // Plan-Clase-Orden-de-Trabajo F2b — en Órdenes y Proyectos la etapa manda
      // sobre el estado.
      if (this.hasStageFilter) {
        delete filters.status;
        Object.assign(filters, stageToParams(this.stageFilter, this.caseClass));
      }
      // Aviso rojo de Órdenes / Comercial (el de Soporte va arriba, por SLA).
      if (this.slaOverdueOnly && alertApplies(this.alertContext)) {
        Object.assign(filters, classAlertParams(this.caseClass));
      }
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
    onFilterChange() {
      this.currentPage = 1;
      this.fetch();
    },
    applyFilter(key) {
      this.activeFilter = key;
      this.currentPage = 1;
      this.fetch();
    },
    // ── Plan-Casos E1.1 — cambios de cada nivel de filtro ──
    onTypeChange(id) {
      this.activeType = id;
      this.onFilterChange();
    },
    // Un resultado que no cabe en el estado elegido se suelta (Ganadas no
    // está entre las Abiertas); con «Todas» se conserva.
    onStatusChange(status) {
      this.statusFilter = status;
      if (status && this.outcomeFilter) {
        if (statusForResult(this.outcomeFilter) !== status)
          this.outcomeFilter = '';
      }
      this.onFilterChange();
    },
    // Elegir un resultado ajusta el estado: Pospuestas → Abiertas; Ganadas,
    // Perdidas y Canceladas → Cerradas.
    onStageChange(stage) {
      this.stageFilter = stage;
      this.onFilterChange();
    },
    onOutcomeChange(outcome) {
      this.outcomeFilter = outcome;
      this.syncCommercialStatus();
      this.onFilterChange();
    },
    // Comercial no ofrece Abiertas/Cerradas: el estado sale del resultado
    // (Pospuestas → pendientes; las otras → cerradas) y sin resultado es «Todas».
    // También corrige un estado guardado (local o en una vista) de antes.
    syncCommercialStatus() {
      if (!this.isCommercialList) return;
      this.statusFilter = this.outcomeFilter
        ? statusForResult(this.outcomeFilter)
        : '';
    },
    onSlaChange(on) {
      this.slaOverdueOnly = on;
      this.onFilterChange();
    },
    onFineChange(fine) {
      this.fine = fine;
      this.onFilterChange();
    },
    // @tickets_cases F3 — vistas guardadas ------------------------------------
    closeViewsMenu() {
      this.showViewsMenu = false;
    },
    selectView(view) {
      // Volver a elegir la vista activa la quita.
      if (view.id === this.activeViewId) {
        this.detachView();
        return;
      }
      this.showViewsMenu = false;
      this.activeViewId = view.id;
      this.applyView(view);
    },
    // Deja de aplicar la vista: los filtros se quedan como están en pantalla
    // (decisión del usuario); solo se suelta el nombre y se recuerda así.
    detachView() {
      this.showViewsMenu = false;
      this.activeViewId = '';
      this.persistState();
    },
    // Tolerante a proposito: una clave ausente deja su default en pie y una
    // desconocida se ignora. Una vista vieja tiene que seguir abriendo cuando
    // agreguemos filtros nuevos.
    applyView(view) {
      const q = normalizeViewQuery(view.query);
      // Plan-Casos E1.1 — una vista de oportunidades abierta desde Soporte (o
      // al revés) primero cambia de clase; el watcher de caseClass la aplica.
      if (q.case_class && q.case_class !== this.caseClass) {
        this.pendingViewId = view.id;
        this.$router.push({
          name: CLASS_VIEW_ROUTES.list,
          params: { caseClass: q.case_class },
        });
        return;
      }
      this.activeViewId = view.id;
      this.search = q.search;
      this.statusFilter = q.status;
      this.outcomeFilter = q.outcome;
      this.syncCommercialStatus();
      this.stageFilter = q.stage;
      this.activeFilter = q.quick;
      this.slaOverdueOnly = q.sla_overdue;
      this.fine = q.fine;
      this.activeType = this.resolveSavedType(q.case_type_id, view.name);
      this.sortBy = this.sortFields.includes(q.sort_by)
        ? q.sort_by
        : 'created_at';
      this.sortOrder = q.sort_order;

      this.currentPage = 1;
      this.setSortConfig();
      this.fetch();
    },
    // Los tipos de caso son una tabla configurable por cuenta: alguien pudo
    // borrar el tipo al que apunta una vista guardada. Eso no debe romperla.
    resolveSavedType(id, viewName) {
      if (!id) return '';
      if (this.types.some(t => t.id === id)) return id;

      useAlert(this.$t('CASE_TICKETS.VIEWS.MISSING_TYPE', { name: viewName }));
      return '';
    },
    // Compara dos `query` sin depender del orden de las claves ni de la
    // diferencia entre "ausente" y "vacio": el jsonb vuelve del servidor con
    // las claves en cualquier orden.
    canonicalQuery(q) {
      const norm = normalizeViewQuery(q);
      // La clase de una vista v1 es la de la lista donde se mira.
      norm.case_class = norm.case_class || this.caseClass;
      return JSON.stringify(
        Object.keys(norm)
          .sort()
          .map(k => [k, norm[k]])
      );
    },
    async overwriteView() {
      if (!this.canOverwriteView) return;
      try {
        await this.$store.dispatch('customViews/update', {
          id: this.activeView.id,
          query: this.viewQuery,
        });
        useAlert(this.$t('CASE_TICKETS.VIEWS.UPDATED'));
      } catch (error) {
        useAlert(this.$t('CASE_TICKETS.VIEWS.UPDATE_ERROR'));
      }
    },
    // Si la vista que estaba cargada se borro, hay que soltarla: dejarla
    // seleccionada mostraria un nombre que ya no existe.
    onViewsChanged(deletedId) {
      if (deletedId && deletedId === this.activeViewId) this.activeViewId = '';
      this.$store.dispatch('customViews/get', VIEW_FILTER_TYPE);
    },
    onViewSaved() {
      this.showSaveViewModal = false;
      this.$store.dispatch('customViews/get', VIEW_FILTER_TYPE);
    },
    clearFilters() {
      this.activeViewId = '';
      this.search = '';
      this.statusFilter = 'pending';
      this.outcomeFilter = this.isCommercialList
        ? DEFAULT_COMMERCIAL_RESULT
        : '';
      this.syncCommercialStatus();
      this.stageFilter = this.hasStageFilter ? DEFAULT_WORK_ORDER_STAGE : '';
      this.activeFilter = 'mine';
      this.slaOverdueOnly = false;
      this.fine = emptyFineFilters();
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
    // @tickets_cases Fase C — sin contacto la primera línea muestra al agente
    // asignado. Cae aquí el ticket interno (origin: internal, nunca tuvo
    // contacto) y también el externo cuyo contacto se borró después
    // (contact_id → NULL por la FK nullify), que no es interno.
    noContactName(ticket) {
      return (
        this.assigneeName(ticket) ||
        this.$t('CASE_TICKETS.INTERNAL.NO_ASSIGNEE')
      );
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
        // @tickets_cases F5 (§11.2) — el lote NUNCA cancela reuniones: cancelar
        // en masa mandaría correos a N clientes sin que nadie los vea. Solo se
        // avisa cuáles quedaron con citas vivas para revisarlos uno por uno.
        const pending = (res.tickets_with_meetings || []).length;
        if (pending) {
          this.$emitter.emit('newToastMessage', {
            message: this.$t('CASE_TICKETS.BULK.MEETINGS_PENDING', {
              n: pending,
            }),
          });
        }
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
    // @tickets_cases — punto de SLA delante del folio (verde a tiempo, ámbar
    // en riesgo, rojo vencido).
    slaDotColor(sla) {
      return (
        {
          on_time: 'bg-emerald-500',
          at_risk: 'bg-amber-500',
          overdue: 'bg-red-500',
        }[sla] || 'bg-emerald-500'
      );
    },
    // Media es neutra con borde: el azul queda para botones y fila elegida.
    priorityBadge(p) {
      return (
        {
          low: 'bg-slate-100 text-slate-600 dark:bg-slate-700/60 dark:text-slate-300',
          medium:
            'bg-white text-slate-700 ring-1 ring-inset ring-slate-200 dark:bg-slate-800 dark:text-slate-200 dark:ring-slate-600',
          high: 'bg-orange-100 text-orange-800 dark:bg-orange-900/40 dark:text-orange-300',
          urgent:
            'bg-red-100 text-red-800 font-semibold dark:bg-red-900/40 dark:text-red-300',
        }[p] || 'bg-slate-100 text-slate-600'
      );
    },
    statusPill(status) {
      return STATUS_PILL[toSimpleStatus(status)] || STATUS_PILL.closed;
    },
    statusLabel(key) {
      return this.$t(`CASE_TICKETS.STATUSES.${key}`) || key;
    },
    // ── Plan-Clase-Comercial F4 — columnas de la lista de oportunidades ──
    // Sobre la cola de siempre: Vence → Cierre estimado, se agregan Monto y
    // Probabilidad, y Estado muestra la etapa (columna del embudo) o el resultado.
    commercialColumns(cols) {
      const amount = {
        field: 'amount',
        key: 'amount',
        title: this.$t('CASE_TICKETS.COMMERCIAL.FIELDS.AMOUNT'),
        align: 'right',
        width: 150,
        sortBy: this.sortConfig.amount || '',
        renderBodyCell: ({ row }) => (
          <span class="text-sm font-semibold tabular-nums whitespace-nowrap text-slate-800 dark:text-slate-100">
            {formatMoney(row.amount, row.currency)}
          </span>
        ),
      };
      const probability = {
        field: 'probability',
        key: 'probability',
        title: this.$t('CASE_TICKETS.COMMERCIAL.FIELDS.PROBABILITY'),
        align: 'left',
        width: 120,
        sortBy: this.sortConfig.probability || '',
        // Barra delgada + el %: se compara de un vistazo entre filas.
        renderBodyCell: ({ row }) =>
          row.probability === null || row.probability === undefined ? (
            <span class="text-[13px] text-slate-400 dark:text-slate-500">
              —
            </span>
          ) : (
            <span class="inline-flex items-center gap-2 whitespace-nowrap">
              <span class="inline-block w-10 h-1.5 overflow-hidden rounded-full bg-slate-100 dark:bg-slate-700">
                <span
                  class="block h-full rounded-full bg-violet-500"
                  style={{ width: `${Math.min(100, row.probability)}%` }}
                />
              </span>
              <span class="text-[13px] tabular-nums text-slate-600 dark:text-slate-300">
                {`${row.probability}%`}
              </span>
            </span>
          ),
      };
      const expectedClose = {
        field: 'expected_close_at',
        key: 'expected_close_at',
        title: this.$t('CASE_TICKETS.COMMERCIAL.FIELDS.EXPECTED_CLOSE'),
        align: 'left',
        width: 130,
        sortBy: this.sortConfig.expected_close_at || '',
        renderBodyCell: ({ row }) => (
          <span class="text-[13px] tabular-nums whitespace-nowrap text-slate-600 dark:text-slate-300">
            {formatDay(row.expected_close_at)}
          </span>
        ),
      };
      const stage = {
        field: 'status',
        key: 'status',
        title: this.$t('CASE_TICKETS.COMMERCIAL.FIELDS.STAGE'),
        align: 'left',
        width: 170,
        sortBy: this.sortConfig.status || '',
        renderBodyCell: ({ row }) => this.renderStage(row),
      };
      const out = [];
      cols.forEach(col => {
        if (col.key === 'status') out.push(amount, probability, stage);
        else if (col.key === 'due_at') out.push(expectedClose);
        else out.push(col);
      });
      return out;
    },
    // ── Plan-Clase-Orden-de-Trabajo F2b — columnas de la lista de órdenes ──
    // Sobre la cola de siempre: Responsable → Técnico, Vence → Próxima visita
    // (en rojo si hay una vencida), se agregan Horas (real / estimado, con
    // «Facturable») y Estado muestra la etapa (columna del tipo).
    workOrderColumns(cols) {
      const visit = {
        field: 'next_visit_at',
        key: 'next_visit_at',
        title: this.$t('CASE_TICKETS.WORK_ORDER.TABLE.NEXT_VISIT'),
        align: 'left',
        width: 150,
        renderBodyCell: ({ row }) => {
          if (row.visit_overdue) {
            return (
              <span class="text-[13px] font-semibold whitespace-nowrap text-red-600 dark:text-red-400">
                {this.$t('CASE_TICKETS.WORK_ORDER.VISIT.OVERDUE')}
              </span>
            );
          }
          return (
            <span class="text-[13px] tabular-nums whitespace-nowrap text-slate-600 dark:text-slate-300">
              {row.next_visit_at ? this.formatDate(row.next_visit_at) : '—'}
            </span>
          );
        },
      };
      const hours = {
        field: 'hours',
        key: 'hours',
        title: this.$t('CASE_TICKETS.WORK_ORDER.TABLE.HOURS'),
        align: 'left',
        width: 130,
        renderBodyCell: ({ row }) => (
          <span class="inline-flex items-center gap-2 whitespace-nowrap">
            <span class="text-[13px] tabular-nums text-slate-600 dark:text-slate-300">
              {`${formatHours(row.actual_hours)} / ${formatHours(
                row.estimated_hours
              )}`}
            </span>
            {row.billable ? (
              <span
                class="inline-block w-2 h-2 rounded-full bg-emerald-500"
                title={this.$t('CASE_TICKETS.WORK_ORDER.FIELDS.BILLABLE')}
              />
            ) : null}
          </span>
        ),
      };
      const out = [];
      cols.forEach(col => {
        if (col.key === 'assignee') {
          out.push({
            ...col,
            title: this.$t('CASE_TICKETS.WORK_ORDER.TABLE.TECHNICIAN'),
          });
        } else if (col.key === 'status') {
          out.push(hours, {
            ...col,
            title: this.$t('CASE_TICKETS.WORK_ORDER.TABLE.STAGE'),
            renderBodyCell: ({ row }) => this.renderWorkOrderStage(row),
          });
        } else if (col.key === 'due_at') out.push(visit);
        else out.push(col);
      });
      return out;
    },
    // ── Plan-Clase-Proyecto P1 — columnas de la lista de proyectos ──
    // Vence → Fecha objetivo (en rojo si está atrasado); Estado → Avance (barra
    // índigo + %) y Fase (columna del tipo).
    projectColumns(cols) {
      const due = {
        field: 'project_due_on',
        key: 'project_due_on',
        title: this.$t('CASE_TICKETS.PROJECT.TABLE.DUE'),
        align: 'left',
        width: 140,
        renderBodyCell: ({ row }) => (
          <span
            class={
              row.project_overdue
                ? 'text-[13px] tabular-nums font-semibold whitespace-nowrap text-red-600 dark:text-red-400'
                : 'text-[13px] tabular-nums whitespace-nowrap text-slate-600 dark:text-slate-300'
            }
          >
            {row.project_due_on ? formatDay(row.project_due_on) : '—'}
          </span>
        ),
      };
      const progress = {
        field: 'progress',
        key: 'progress',
        title: this.$t('CASE_TICKETS.PROJECT.TABLE.PROGRESS'),
        align: 'left',
        width: 130,
        renderBodyCell: ({ row }) =>
          row.progress === null || row.progress === undefined ? (
            <span class="text-[13px] text-slate-400 dark:text-slate-500">
              —
            </span>
          ) : (
            <span class="inline-flex items-center gap-2 whitespace-nowrap">
              <span class="inline-block w-12 h-1.5 overflow-hidden rounded-full bg-slate-100 dark:bg-slate-700">
                <span
                  class="block h-full rounded-full bg-indigo-500"
                  style={{ width: `${Math.min(100, row.progress)}%` }}
                />
              </span>
              <span class="text-[13px] tabular-nums text-slate-600 dark:text-slate-300">
                {`${row.progress}%`}
              </span>
            </span>
          ),
      };
      const out = [];
      cols.forEach(col => {
        if (col.key === 'status') {
          out.push(progress, {
            ...col,
            title: this.$t('CASE_TICKETS.PROJECT.TABLE.STAGE'),
            renderBodyCell: ({ row }) => this.renderWorkOrderStage(row),
          });
        } else if (col.key === 'due_at') out.push(due);
        else out.push(col);
      });
      return out;
    },
    renderWorkOrderStage(row) {
      const column = (row.case_type?.columns || []).find(
        c => c.id === row.case_type_column_id
      );
      return (
        <span class={`${PILL} ${this.statusPill(row.status)}`}>
          {column ? column.label : this.statusLabel(this.displayStatus(row))}
        </span>
      );
    },
    renderStage(row) {
      const badge = PILL;
      if (row.outcome) {
        return (
          <span class={`${badge} ${OUTCOME_BADGE[row.outcome]}`}>
            {this.$t(`CASE_TICKETS.COMMERCIAL.OUTCOMES.${row.outcome}`)}
          </span>
        );
      }
      if (row.is_postponed) {
        return (
          <span class={`${badge} ${POSTPONED_BADGE}`}>
            {this.$t('CASE_TICKETS.COMMERCIAL.POSTPONED_UNTIL', {
              date: formatDay(row.postponed_until),
            })}
          </span>
        );
      }
      const column = (row.case_type?.columns || []).find(
        c => c.id === row.case_type_column_id
      );
      return (
        <span class={`${badge} ${STAGE_PILL}`}>
          {column ? column.label : this.statusLabel(this.displayStatus(row))}
        </span>
      );
    },
    // Colapsa el estado ITIL a etiqueta simple según el modo del PROPIO tipo del
    // ticket (cada fila puede ser de un tipo distinto).
    displayStatus(ticket) {
      return ticket?.case_type?.itil_enabled
        ? ticket.status
        : toSimpleStatus(ticket?.status);
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
