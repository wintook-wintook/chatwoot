<!--
  @tickets_cases 2C
  Tablero Kanban operativo de tickets. Columnas = estados agrupados.
  Drag&drop nativo HTML5: al soltar una tarjeta se valida la transición contra
  can_transition_to (backend) y se pide una nota opcional (reason del evento).
-->
<script>
import { mapGetters } from 'vuex';
import CaseTicketInternalModal from './CaseTicketInternalModal.vue'; // @tickets_cases Fase C
import MessageApi from 'dashboard/api/inbox/message'; // @tickets_cases — notificar al mover
import { toSimpleStatus } from 'dashboard/helper/caseSimpleStatus';
// Plan-Clase-Comercial F4 — tablero del embudo comercial.
import OutcomeModal from './commercial/OutcomeModal.vue';
import CaseClassSwitcher from './CaseClassSwitcher.vue'; // Plan-Casos E1
// Plan-Casos E1.1 — filtros por niveles (mismos que la Lista).
import CaseTypeSelect from './filters/CaseTypeSelect.vue';
import CaseScopeBar from './filters/CaseScopeBar.vue';
import CaseFineFilters from './filters/CaseFineFilters.vue';
import {
  BOARD_CLOSED_OPTIONS,
  DEFAULT_BOARD_CLOSED,
  SCOPES,
  emptyFineFilters,
  fineFiltersToParams,
  scopeToParams,
  classAlertParams,
} from 'dashboard/helper/caseFilters';
import {
  classHasSla,
  classI18nBase,
  loadCaseState,
  saveCaseState,
  typesOfClass,
} from 'dashboard/helper/caseClasses';
import PostponeModal from './commercial/PostponeModal.vue';
import {
  COMMERCIAL_CLASS,
  POSTPONED_BADGE,
  formatDay,
  formatMoney,
  totalsByCurrency,
  isoDayFromToday,
} from 'dashboard/helper/caseCommercial';
import { formatHours } from 'dashboard/helper/caseWorkOrder';

// Columnas por defecto del tablero cuando no hay un tipo de caso filtrado (así
// que no hay columnas propias de un tipo que mostrar). ITIL dejó de ser un modo
// de cuenta, así que esto ya no alterna entre "simple"/"ITIL": es una única
// plantilla neutra, agrupando estados del ciclo de vida (2A). "En proceso"
// agrupa classified/assigned/in_diagnosis/in_progress/escalated (igual que
// SIMPLE_STATUS_MAP) → arrastrar "Nuevo" (open) ahí es válido (open → classified).
const DEFAULT_COLUMNS = [
  { key: 'new', statuses: ['open'] },
  {
    key: 'progress',
    statuses: [
      'classified',
      'assigned',
      'in_diagnosis',
      'in_progress',
      'escalated',
    ],
  },
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

// Diseño del Tablero (2026-10-20): la prioridad solo se marca cuando sale de lo
// normal (Alta / Urgente), como píldora con texto y los colores de la Lista.
const PRIORITY_PILL = {
  urgent:
    'bg-red-100 text-red-800 font-semibold dark:bg-red-900/40 dark:text-red-300',
  high: 'bg-orange-100 text-orange-800 dark:bg-orange-900/40 dark:text-orange-300',
};
// Franja de color de las columnas fijas (sin columnas del tipo), por etapa.
const DEFAULT_COLUMN_COLORS = {
  new: '#0ea5e9',
  progress: '#0ea5e9',
  waiting: '#f59e0b',
  resolved: '#10b981',
  closed: '#64748b',
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
  components: {
    CaseTicketInternalModal, // @tickets_cases Fase C
    OutcomeModal,
    PostponeModal,
    CaseClassSwitcher,
    CaseTypeSelect,
    CaseScopeBar,
    CaseFineFilters,
  },
  props: {
    // Plan-Casos E1 — clase de la ruta `tickets/:caseClass/board`:
    // 'commercial' = embudo de oportunidades; 'support' = tablero de tickets.
    caseClass: { type: String, default: 'support' },
  },
  data() {
    return {
      // Plan-Casos E1.1 — ¿de quién? (mine|unassigned|all), aviso de SLA
      // vencido aparte y filtros finos del botón «Filtros».
      quickFilter: 'mine',
      slaOverdueOnly: false,
      fine: emptyFineFilters(),
      // Plan-Casos E1.3 — cerrados en el tablero: hide | 7 | 30 | 90 | all.
      closedWindow: DEFAULT_BOARD_CLOSED,
      showInternalModal: false, // @tickets_cases Fase C
      filters: {
        q: '',
        case_type_id: '', // columnas por tipo (A+) — lo elige CaseTypeSelect
      },
      searchDebounce: null,
      draggedTicket: null,
      dragOverKey: null,
      // modal de movimiento
      showMoveModal: false,
      moveTicket: null,
      moveCandidates: [],
      moveTarget: null,
      moveTargetColumn: null, // columna destino cuando el tablero es por tipo (A+)
      moveReason: '',
      // notificar al cliente al mover (reusa el envío de mensajes del inbox)
      notifyContact: false,
      notifyMessage: '',
      // Plan-Clase-Comercial F4 — soltar en Perdida/Cancelada o en la espera
      // pide datos: { ticket, column, outcome } / { ticket, column }.
      outcomeMove: null,
      postponeMove: null,
    };
  },
  computed: {
    ...mapGetters({
      boardTickets: 'caseTickets/getBoardTickets',
      boardUiFlags: 'caseTickets/getBoardUIFlags',
      slaOverdueCount: 'caseTickets/getBoardSlaOverdue',
      agents: 'agents/getAgents',
      currentUserID: 'getCurrentUserID', // @tickets_cases — filtro "Mis Casos"
      types: 'caseTickets/getTypes', // columnas por tipo (A+)
      anyTypeItilEnabled: 'caseTickets/getAnyTypeItilEnabled',
    }),
    // Naturaleza ITIL en «Filtros» solo si el tipo (o algún tipo) usa ITIL.
    itilEnabled() {
      const type = (this.types || []).find(
        t => String(t.id) === String(this.filters.case_type_id)
      );
      return type ? !!type.itil_enabled : this.anyTypeItilEnabled;
    },
    isFetching() {
      return this.boardUiFlags.isFetching;
    },
    // ── Plan-Clase-Comercial F4 ──
    // Solo las clases con SLA (Soporte) muestran la etiqueta de SLA en la tarjeta.
    hasSla() {
      return classHasSla(this.caseClass);
    },
    isCommercialBoard() {
      return this.caseClass === COMMERCIAL_CLASS;
    },

    // Plan-Clase-Orden-de-Trabajo F1 — solo los tipos de la clase del tablero.
    visibleTypes() {
      return typesOfClass(this.types, this.caseClass);
    },
    // Plan-Casos E2 — etiqueta del botón de alta: el tipo elegido o la clase.
    createLabel() {
      const type = (this.types || []).find(
        t => String(t.id) === String(this.filters.case_type_id)
      );
      return (
        type?.name || this.$t(`CASE_TICKETS.CLASSES.${this.caseClassKey}.NAME`)
      );
    },
    boardTitle() {
      return this.$t(`${classI18nBase(this.caseClass)}.BOARD`);
    },
    // Clave i18n de la clase (COMMERCIAL / SUPPORT / WORK_ORDER).
    caseClassKey() {
      return classI18nBase(this.caseClass).split('.').pop();
    },
    postponedBadge() {
      return POSTPONED_BADGE;
    },
    // Columnas propias del tipo seleccionado (A+). Vienen ya en el JSON del tipo.
    selectedTypeColumns() {
      if (!this.filters.case_type_id) return [];
      const type = (this.types || []).find(
        t => String(t.id) === String(this.filters.case_type_id)
      );
      return (type && type.columns) || [];
    },
    // Columnas del tablero: si hay un tipo con columnas configuradas, las suyas;
    // si no (sin filtro de tipo), las fijas por defecto.
    columns() {
      if (this.selectedTypeColumns.length) {
        return this.selectedTypeColumns.map(c => ({
          key: `col-${c.id}`,
          id: c.id,
          label: c.label,
          color: c.color,
          statuses: c.statuses || [],
          custom: true,
        }));
      }
      return DEFAULT_COLUMNS;
    },
    priorityOptions() {
      return this.$t('CASE_TICKETS.PRIORITIES');
    },
    closedOptions() {
      return BOARD_CLOSED_OPTIONS;
    },
    ticketKindOptions() {
      return this.$t('CASE_TICKETS.TICKET_KIND');
    },
    // Tickets agrupados por columna. En tablero por tipo (A+) manda el puntero
    // (case_type_column_id); si es NULL, cae al fallback por status (Regla 1).
    grouped() {
      const map = {};
      this.columns.forEach(c => {
        map[c.key] = [];
      });
      const custom = this.selectedTypeColumns.length > 0;
      (this.boardTickets || []).forEach(t => {
        let col = null;
        if (custom && t.case_type_column_id) {
          col = this.columns.find(c => c.id === t.case_type_column_id);
        }
        if (!col) col = this.columns.find(c => c.statuses.includes(t.status));
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
  watch: {
    // Plan-Clase-Comercial F4 — misma instancia para las dos rutas: al cambiar
    // de tablero se reinicia el tipo elegido y se vuelve a cargar.
    caseClass() {
      this.restoreState(); // Plan-Casos E1.2 — cada clase vuelve como la dejaste
      this.loadBoard();
    },
  },
  mounted() {
    this.$store.dispatch('caseTickets/fetchServices');
    this.$store.dispatch('agents/get');
    this.$store.dispatch('caseTickets/fetchSettings'); // modo simple/ITIL
    this.restoreState();
    this.loadBoard();
  },
  methods: {
    // Plan-Casos E1.2 — el Tablero comparte con la Lista (misma clase) el tipo,
    // ¿de quién?, el aviso de SLA, los filtros finos y la búsqueda: pasar de
    // una vista a otra, o salir y volver, conserva lo elegido.
    restoreState() {
      const st = loadCaseState(this.$route.params.accountId, this.caseClass);
      this.filters.q = st.search || '';
      this.filters.case_type_id = st.type ?? '';
      this.quickFilter = SCOPES.includes(st.scope) ? st.scope : 'mine';
      this.slaOverdueOnly = !!st.sla;
      this.fine = { ...emptyFineFilters(), ...(st.fine || {}) };
      const closed = st.board?.closed;
      this.closedWindow = BOARD_CLOSED_OPTIONS.includes(closed)
        ? closed
        : DEFAULT_BOARD_CLOSED;
    },
    persistState() {
      saveCaseState(this.$route.params.accountId, this.caseClass, {
        search: this.filters.q,
        type: this.filters.case_type_id,
        scope: this.quickFilter,
        sla: this.slaOverdueOnly,
        fine: this.fine,
        board: { closed: this.closedWindow },
      });
    },
    // Tipos primero (columnas por tipo A+): la clase del tablero decide qué se
    // pide, y el embudo arranca en su primer tipo Comercial.
    async loadBoard() {
      try {
        await this.$store.dispatch('caseTickets/fetchTypes');
      } finally {
        this.fetch();
      }
    },
    // @tickets_cases Fase C — tras crear un ticket interno, refresca el tablero.
    onInternalCreated() {
      this.showInternalModal = false;
      this.fetch();
    },
    fetch() {
      // El embudo pinta las columnas de UN tipo: espera a que CaseTypeSelect lo elija.
      if (this.isCommercialBoard && !this.filters.case_type_id) return;
      this.persistState();
      const f = {
        ...scopeToParams(this.quickFilter, this.currentUserID),
        ...fineFiltersToParams(this.fine, this.caseClass, this.quickFilter, {
          itil: this.itilEnabled,
          board: true,
        }),
      };
      if (this.filters.q) f.q = this.filters.q;
      if (this.filters.case_type_id) f.case_type_id = this.filters.case_type_id;
      if (this.slaOverdueOnly && classHasSla(this.caseClass))
        f.sla_status = 'overdue';
      // Plan-Casos E1.3 — los cerrados de siempre no tapan a los abiertos
      // (el tablero carga hasta 100 casos).
      if (this.closedWindow === 'hide') f.status = 'pending';
      else if (this.closedWindow !== 'all')
        f.closed_within_days = this.closedWindow;
      // Plan-Clase-Comercial F4 — las clases no se mezclan (Soporte incluye los
      // casos sin tipo; ver CaseTicket.of_class).
      f.case_class = this.caseClass;
      // Aviso rojo de Órdenes / Comercial (visitas / cierre vencido).
      if (this.slaOverdueOnly)
        Object.assign(f, classAlertParams(this.caseClass));
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
    // ── Plan-Casos E1.1 — cambios de cada nivel de filtro ──
    onTypeChange(id) {
      this.filters.case_type_id = id;
      this.fetch();
    },
    onScopeChange(scope) {
      this.quickFilter = scope;
      this.fetch();
    },
    onSlaChange(on) {
      this.slaOverdueOnly = on;
      this.fetch();
    },
    onFineChange(fine) {
      this.fine = fine;
      this.fetch();
    },
    onClosedWindowChange(event) {
      this.closedWindow = event.target.value;
      this.fetch();
    },
    // ── Plan-Clase-Comercial F4 ──
    money(amount, currency) {
      return formatMoney(amount, currency);
    },
    day(value) {
      return formatDay(value);
    },
    columnTotals(col) {
      return totalsByCurrency(this.grouped[col.key]);
    },
    // El backend decide: soltar en Ganada cierra; en Perdida/Cancelada responde
    // `requires_outcome` y en la espera `requires_postpone` → se abre el modal y
    // se reintenta el mismo movimiento con los datos.
    async commercialMove(ticket, column, extra = {}) {
      try {
        await this.$store.dispatch('caseTickets/moveTicketColumn', {
          ticketId: ticket.id,
          caseTypeColumnId: column.id,
          ...extra,
        });
        this.fetch();
      } catch (e) {
        const data = e.response?.data || {};
        if (data.requires_outcome) {
          this.outcomeMove = { ticket, column, outcome: data.outcome || null };
        } else if (data.requires_postpone) {
          this.postponeMove = { ticket, column };
        } else {
          this.$emitter.emit('newToastMessage', {
            message: data.error || this.$t('CASE_TICKETS.KANBAN.MOVE_ERROR'),
            type: 'error',
          });
        }
      }
    },
    confirmOutcomeMove(closure) {
      const { ticket, column } = this.outcomeMove;
      this.outcomeMove = null;
      this.commercialMove(ticket, column, { closure });
    },
    confirmPostponeMove({
      postponed_until: postponedUntil,
      postpone_reason_id: postponeReasonId,
      reason,
    }) {
      const { ticket, column } = this.postponeMove;
      this.postponeMove = null;
      this.commercialMove(ticket, column, {
        postponedUntil,
        postponeReasonId,
        reason,
      });
    },
    columnLabel(col) {
      // Columna del tipo (A+) → etiqueta libre de BD; fija → clave i18n.
      return col.custom
        ? col.label
        : this.$t(`CASE_TICKETS.KANBAN.COLUMNS.${col.key}`);
    },
    statusLabel(key) {
      return this.$t(`CASE_TICKETS.STATUSES.${key}`) || key;
    },
    kindLabel(key) {
      return this.ticketKindOptions[key] || key;
    },
    priorityPill(priority) {
      return PRIORITY_PILL[priority] || '';
    },
    columnColor(col) {
      return col.custom ? col.color : DEFAULT_COLUMN_COLORS[col.key];
    },
    // Iniciales del responsable para el circulito del pie (máx. 2 letras).
    initials(name) {
      return (name || '')
        .split(/\s+/)
        .filter(Boolean)
        .slice(0, 2)
        .map(w => w[0].toUpperCase())
        .join('');
    },
    isPastDay(value) {
      return !!value && String(value).slice(0, 10) < isoDayFromToday(0);
    },
    // Abierta con el cierre estimado ya pasado (oportunidad).
    closeOverdue(ticket) {
      return (
        ticket.is_commercial &&
        !ticket.outcome &&
        !['closed', 'cancelled'].includes(ticket.status) &&
        this.isPastDay(ticket.expected_close_at)
      );
    },
    // Excepción que se muestra arriba a la derecha (lo normal no se marca).
    cardAlert(ticket) {
      if (ticket.is_postponed) {
        return {
          label: this.$t('CASE_TICKETS.COMMERCIAL.POSTPONED_UNTIL', {
            date: this.day(ticket.postponed_until),
          }),
          cls: POSTPONED_BADGE,
        };
      }
      if (this.hasSla && ['at_risk', 'overdue'].includes(ticket.sla_status)) {
        return {
          label: this.statusLabel(ticket.sla_status),
          cls: this.slaBadge(ticket.sla_status),
        };
      }
      if (ticket.visit_overdue) {
        return {
          label: this.$t('CASE_TICKETS.WORK_ORDER.VISIT.OVERDUE'),
          cls: SLA_BADGE.overdue,
        };
      }
      if (this.closeOverdue(ticket)) {
        return {
          label: this.$t('CASE_TICKETS.KANBAN.CLOSE_OVERDUE'),
          cls: SLA_BADGE.overdue,
        };
      }
      if (ticket.project_overdue) {
        return {
          label: this.$t('CASE_TICKETS.PROJECT.OVERDUE'),
          cls: SLA_BADGE.overdue,
        };
      }
      return null;
    },
    // Borde rojo a la izquierda: algo vencido (SLA, visita o cierre).
    isCardOverdue(ticket) {
      return (
        (this.hasSla && ticket.sla_status === 'overdue') ||
        !!ticket.visit_overdue ||
        !!ticket.project_overdue ||
        this.closeOverdue(ticket)
      );
    },
    hours(value) {
      return formatHours(value);
    },
    slaBadge(sla) {
      return SLA_BADGE[sla] || SLA_BADGE.on_time;
    },
    assigneeName(ticket) {
      if (!ticket.assignee_id) return null;
      const a = (this.agents || []).find(x => x.id === ticket.assignee_id);
      return a ? a.name : null;
    },
    // @tickets_cases — encabezado de la ficha: manda la organización del contacto.
    // Sin organización sube el nombre del contacto; sin contacto (ticket interno)
    // sube el título, para que la ficha nunca quede sin encabezado.
    cardHeading(ticket) {
      return (
        ticket.contact_company || ticket.contact_name || ticket.title || ''
      );
    },
    // El icono acompaña al encabezado según qué subió: edificio para la empresa,
    // persona para el contacto. Sin icono cuando el encabezado es el título.
    cardHeadingIcon(ticket) {
      if (ticket.contact_company) return 'building-bank';
      return ticket.contact_name ? 'person' : '';
    },
    // El contacto solo se repite debajo cuando arriba fue la organización.
    cardSubheading(ticket) {
      return ticket.contact_company ? ticket.contact_name || '' : '';
    },
    // El título no se reimprime cuando ya ocupó el encabezado.
    cardTitle(ticket) {
      return this.cardHeading(ticket) === ticket.title ? '' : ticket.title;
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

      // Plan-Clase-Comercial F4 — en el embudo no hay modal de cambio de estado
      // ni aviso al cliente: mover de etapa es interno del vendedor.
      if (this.isCommercialBoard && column.custom) {
        if (ticket.case_type_column_id === column.id) return; // misma columna
        this.commercialMove(ticket, column);
        return;
      }

      // ── Tablero por tipo (A+): la columna destino ya cubre el estado actual →
      // movimiento libre, solo cambia el puntero, SIN modal de cambio de estado.
      if (column.custom && column.statuses.includes(ticket.status)) {
        if (ticket.case_type_column_id === column.id) return; // misma columna
        this.moveColumnOnly(ticket, column);
        return;
      }

      // Soltado en su misma columna (mismo estado, tablero fijo) → no-op.
      if (!column.custom && column.statuses.includes(ticket.status)) return;

      const valid = ticket.can_transition_to || [];
      const candidates = column.statuses.filter(s => valid.includes(s));

      // ── Tablero por tipo (A+): el orden de columnas manda, no la espina ITIL
      // fija de "un salto" — salvo un caso CANCELADO, que nunca cambia de status
      // (terminal a propósito). El tablero fijo mantiene el rechazo de siempre.
      if (column.custom) {
        if (ticket.status === 'cancelled') {
          this.$emitter.emit('newToastMessage', {
            message: this.$t('CASE_TICKETS.KANBAN.CANCELLED_IMMUTABLE'),
            type: 'error',
          });
          return;
        }
      } else if (!candidates.length) {
        this.$emitter.emit('newToastMessage', {
          message: this.$t('CASE_TICKETS.KANBAN.INVALID_MOVE'),
          type: 'error',
        });
        return;
      }
      this.moveTicket = ticket;
      // El selector del modal es solo informativo (arma el mensaje de aviso al
      // cliente); en tablero por tipo el backend decide el status real — si
      // ningún estado de la columna es alcanzable en un salto, se muestran
      // todos los de la columna en vez de dejar el selector vacío.
      this.moveCandidates = candidates.length ? candidates : column.statuses;
      this.moveTarget = this.moveCandidates[0];
      // En tablero por tipo, el destino es la columna (el backend elige el status).
      this.moveTargetColumn = column.custom ? column : null;
      this.moveReason = '';
      // Notificar al cliente: por defecto activo si el ticket tiene conversación.
      this.notifyContact = !!ticket.conversation_display_id;
      this.notifyMessage = this.defaultNotifyMessage(this.moveTarget);
      this.showMoveModal = true;
    },
    // Plantilla de aviso por estado destino (colapsado a estado simple), con folio.
    defaultNotifyMessage(status) {
      const key = toSimpleStatus(status);
      const folio = this.moveTicket?.folio || `#${this.moveTicket?.id}`;
      const msg = this.$t(`CASE_TICKETS.KANBAN.NOTIFY_TEMPLATES.${key}`, {
        folio,
      });
      return msg.includes('NOTIFY_TEMPLATES') ? '' : msg;
    },
    onMoveTargetChange() {
      this.notifyMessage = this.defaultNotifyMessage(this.moveTarget);
    },
    // Movimiento libre entre columnas del mismo estado (A+): solo puntero.
    async moveColumnOnly(ticket, column) {
      try {
        await this.$store.dispatch('caseTickets/moveTicketColumn', {
          ticketId: ticket.id,
          caseTypeColumnId: column.id,
        });
        this.fetch();
      } catch (e) {
        this.$emitter.emit('newToastMessage', {
          message: this.$t('CASE_TICKETS.KANBAN.MOVE_ERROR'),
          type: 'error',
        });
      }
    },
    closeMove() {
      this.showMoveModal = false;
      this.moveTicket = null;
      this.moveCandidates = [];
      this.moveTarget = null;
      this.moveTargetColumn = null;
      this.moveReason = '';
      this.notifyContact = false;
      this.notifyMessage = '';
    },
    async confirmMove() {
      const ticket = this.moveTicket;
      const status = this.moveTarget;
      const reason = this.moveReason.trim() || undefined;
      // capturar aviso antes de cerrar (closeMove resetea el estado)
      const notify = this.notifyContact;
      const notifyMessage = this.notifyMessage.trim();
      const conversationId = ticket?.conversation_display_id;
      const targetColumn = this.moveTargetColumn;
      this.showMoveModal = false;
      try {
        if (targetColumn) {
          // Tablero por tipo (A+): el backend transiciona y fija el puntero.
          await this.$store.dispatch('caseTickets/moveTicketColumn', {
            ticketId: ticket.id,
            caseTypeColumnId: targetColumn.id,
          });
        } else {
          await this.$store.dispatch('caseTickets/transitionTicket', {
            ticketId: ticket.id,
            contactId: ticket.contact_id,
            status,
            reason,
          });
        }
        if (notify && notifyMessage && conversationId) {
          await this.notifyOnMove(conversationId, notifyMessage);
        }
        this.fetch();
      } catch (e) {
        // @tickets_cases — este movimiento cierra el caso y el Kanban no tiene el
        // modal de cierre documentado (2G): manda a la ficha del ticket, que sí lo
        // tiene, en vez de duplicar el formulario aquí.
        if (e.response?.data?.requires_closure) {
          this.$emitter.emit('newToastMessage', {
            message: this.$t('CASE_TICKETS.KANBAN.REQUIRES_CLOSURE'),
            type: 'error',
            action: {
              type: 'link',
              to: { name: 'gestorTickets_detail', params: { id: ticket.id } },
              message: this.$t('CASE_TICKETS.KANBAN.OPEN_TICKET_TO_CLOSE'),
            },
          });
        } else {
          this.$emitter.emit('newToastMessage', {
            message: this.$t('CASE_TICKETS.KANBAN.MOVE_ERROR'),
            type: 'error',
          });
        }
      } finally {
        this.closeMove();
      }
    },
    // Envía el aviso al cliente por su canal (reusa la API de mensajes del inbox).
    async notifyOnMove(conversationId, message) {
      try {
        await MessageApi.create({ conversationId, message, private: false });
        this.$emitter.emit('newToastMessage', {
          message: this.$t('CASE_TICKETS.KANBAN.NOTIFY_SENT'),
        });
      } catch (e) {
        this.$emitter.emit('newToastMessage', {
          message: this.$t('CASE_TICKETS.KANBAN.NOTIFY_ERROR'),
          type: 'error',
        });
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
      class="flex flex-col flex-shrink-0 gap-3 px-6 pt-4 bg-white border-b dark:bg-slate-900 border-slate-50 dark:border-slate-800/50"
    >
      <div class="flex items-center justify-between">
        <!-- Plan-Casos E1 — el selector Comercial | Soporte es el título -->
        <CaseClassSwitcher :case-class="caseClass" :title="boardTitle" />
        <!-- Plan-Casos E2 — «+ {tipo}» o, en «Todos los tipos», «+ {clase}» -->
        <woot-button size="small" icon="add" @click="showInternalModal = true">
          {{ createLabel }}
        </woot-button>
      </div>

      <!-- ¿De quién? y la fila de filtros (misma que la Lista): tipo · búsqueda ·
           filtros finos · cerrados · SLA. Sin estado: las columnas ya lo muestran. -->
      <CaseScopeBar
        :case-class="caseClass"
        :scope="quickFilter"
        :sla-only="slaOverdueOnly"
        :sla-count="slaOverdueCount"
        @scope="onScopeChange"
        @sla="onSlaChange"
      >
        <template #before>
          <!-- E1.1 — el tipo decide las columnas; el embudo exige uno -->
          <CaseTypeSelect
            :case-class="caseClass"
            :value="filters.case_type_id"
            :allow-all="!isCommercialBoard"
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
            v-model="filters.q"
            type="text"
            class="w-full !h-8 pl-9 pr-9 !mb-0 text-sm"
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
        <CaseFineFilters
          :case-class="caseClass"
          :value="fine"
          :scope="quickFilter"
          :case-type-id="filters.case_type_id"
          :itil="itilEnabled"
          board
          @input="onFineChange"
        />
        <!-- E1.3 — cuántos cerrados se pintan (abiertos siempre completos) -->
        <label
          class="flex items-center gap-1.5 ml-auto text-sm text-slate-600 dark:text-slate-300"
          :title="$t('CASE_TICKETS.FILTERS.BOARD_CLOSED_HINT')"
        >
          {{ $t(`CASE_TICKETS.CLASSES.${caseClassKey}.CLOSED_LABEL`) }}
          <select
            :value="closedWindow"
            class="!mb-0 text-sm w-40"
            @change="onClosedWindowChange"
          >
            <option v-for="o in closedOptions" :key="o" :value="o">
              {{ $t(`CASE_TICKETS.FILTERS.BOARD_CLOSED.${o}`) }}
            </option>
          </select>
        </label>
      </CaseScopeBar>
    </div>

    <!-- Tablero -->
    <div
      v-if="isCommercialBoard && !isFetching && !visibleTypes.length"
      class="flex items-center justify-center flex-1 px-6 text-sm text-center text-slate-400 dark:text-slate-500"
    >
      {{ $t('CASE_TICKETS.COMMERCIAL.NO_TYPES') }}
    </div>
    <div
      v-else-if="isFetching"
      class="flex items-center justify-center flex-1 text-slate-400"
    >
      {{ $t('CASE_TICKETS.LIST.LOADING') }}
    </div>
    <div v-else class="flex flex-1 gap-3 px-4 py-4 overflow-x-auto">
      <div
        v-for="col in columns"
        :key="col.key"
        class="flex flex-col flex-shrink-0 w-72 border-t-[3px] rounded-lg bg-slate-50 dark:bg-slate-800/40"
        :class="dragOverKey === col.key ? 'ring-2 ring-woot-500' : ''"
        :style="{ borderTopColor: columnColor(col) || '#cbd5e1' }"
        @dragenter.prevent="dragOverKey = col.key"
        @dragover.prevent="onDragOver(col.key, $event)"
        @dragleave="onDragLeave(col.key, $event)"
        @drop.prevent="onDrop(col)"
      >
        <div
          class="flex items-center justify-between px-3 py-2 text-[13px] font-semibold text-slate-700 dark:text-slate-200"
        >
          <span class="truncate">{{ columnLabel(col) }}</span>
          <span
            class="px-2 py-0.5 text-xs font-medium tabular-nums rounded-full bg-white text-slate-600 ring-1 ring-inset ring-slate-200 dark:bg-slate-700 dark:text-slate-300 dark:ring-slate-600"
            >{{ grouped[col.key].length }}</span
          >
        </div>
        <!-- Plan-Clase-Comercial F4 — total de la columna, por moneda -->
        <div
          v-if="isCommercialBoard && columnTotals(col).length"
          class="flex flex-wrap gap-x-2 px-3 -mt-1 mb-1 text-xs font-semibold text-slate-600 dark:text-slate-300"
          :title="$t('CASE_TICKETS.COMMERCIAL.COLUMN_TOTAL')"
        >
          <span v-for="t in columnTotals(col)" :key="t.currency">
            {{ money(t.total, t.currency) }}
          </span>
        </div>
        <div class="flex flex-col flex-1 gap-2 p-2 overflow-y-auto">
          <div
            v-for="ticket in grouped[col.key]"
            :key="ticket.id"
            draggable="true"
            class="p-3 bg-white border rounded-lg cursor-pointer dark:bg-slate-800 border-slate-100 dark:border-slate-700 hover:border-woot-200 hover:shadow-sm dark:hover:border-woot-700"
            :class="
              isCardOverdue(ticket)
                ? 'border-l-[3px] !border-l-red-500 dark:!border-l-red-400'
                : ''
            "
            @dragstart="onDragStart(ticket, $event)"
            @dragend="onDragEnd"
            @click="openDetail(ticket)"
          >
            <!-- Folio + solo la excepción (lo normal no se marca) -->
            <div class="flex items-center justify-between gap-2 mb-1">
              <span
                class="font-mono text-xs text-slate-500 dark:text-slate-400"
              >
                {{ ticket.folio || `#${ticket.id}` }}
              </span>
              <span
                v-if="cardAlert(ticket)"
                class="px-2 py-0.5 text-[11px] font-medium rounded-full whitespace-nowrap truncate"
                :class="cardAlert(ticket).cls"
              >
                {{ cardAlert(ticket).label }}
              </span>
            </div>
            <p
              v-if="cardHeading(ticket)"
              class="flex items-center gap-1 m-0 text-sm font-semibold text-slate-800 dark:text-slate-100"
            >
              <fluent-icon
                v-if="cardHeadingIcon(ticket)"
                :icon="cardHeadingIcon(ticket)"
                size="14"
                class="flex-shrink-0 text-slate-400 dark:text-slate-500"
              />
              <span class="truncate" :title="cardHeading(ticket)">
                {{ cardHeading(ticket) }}
              </span>
            </p>
            <p
              v-if="cardSubheading(ticket)"
              class="flex items-center gap-1 m-0 text-xs font-normal text-slate-500 dark:text-slate-400"
            >
              <fluent-icon
                icon="person"
                size="12"
                class="flex-shrink-0 text-slate-400 dark:text-slate-500"
              />
              <span class="truncate" :title="cardSubheading(ticket)">
                {{ cardSubheading(ticket) }}
              </span>
            </p>
            <!-- Asunto: hasta 2 líneas -->
            <p
              v-if="cardTitle(ticket)"
              class="m-0 mt-1 text-[13px] leading-snug text-slate-600 dark:text-slate-300 line-clamp-2"
              :title="cardTitle(ticket)"
            >
              {{ cardTitle(ticket) }}
            </p>

            <!-- Línea propia de la clase -->
            <div
              v-if="ticket.is_commercial"
              class="flex items-center gap-2 mt-2 text-xs"
            >
              <span
                class="text-sm font-bold tabular-nums text-slate-800 dark:text-slate-100"
              >
                {{ money(ticket.amount, ticket.currency) }}
              </span>
              <span
                v-if="ticket.probability !== null"
                class="inline-flex items-center gap-1"
              >
                <span
                  class="inline-block w-8 h-1.5 overflow-hidden rounded-full bg-slate-100 dark:bg-slate-700"
                >
                  <span
                    class="block h-full rounded-full bg-violet-500"
                    :style="{ width: `${Math.min(100, ticket.probability)}%` }"
                  />
                </span>
                <span class="tabular-nums text-slate-500 dark:text-slate-400"
                  >{{ ticket.probability }}%</span
                >
              </span>
              <span
                v-if="ticket.expected_close_at"
                class="inline-flex items-center gap-1 ml-auto tabular-nums"
                :class="
                  closeOverdue(ticket)
                    ? 'font-semibold text-red-600 dark:text-red-400'
                    : 'text-slate-500 dark:text-slate-400'
                "
                :title="$t('CASE_TICKETS.COMMERCIAL.FIELDS.EXPECTED_CLOSE')"
              >
                <fluent-icon icon="calendar" size="12" />
                {{ day(ticket.expected_close_at) }}
              </span>
            </div>
            <div
              v-else-if="ticket.is_work_order"
              class="flex items-center gap-2 mt-2 text-xs"
            >
              <span
                class="inline-flex items-center gap-1 tabular-nums"
                :class="
                  ticket.visit_overdue
                    ? 'font-semibold text-red-600 dark:text-red-400'
                    : 'text-slate-500 dark:text-slate-400'
                "
                :title="$t('CASE_TICKETS.WORK_ORDER.TABLE.NEXT_VISIT')"
              >
                <fluent-icon icon="calendar" size="12" />
                {{
                  ticket.visit_overdue
                    ? $t('CASE_TICKETS.WORK_ORDER.VISIT.OVERDUE')
                    : ticket.next_visit_at
                    ? day(ticket.next_visit_at)
                    : $t('CASE_TICKETS.WORK_ORDER.VISIT.NONE')
                }}
              </span>
              <span
                class="ml-auto tabular-nums text-slate-500 dark:text-slate-400"
                :title="$t('CASE_TICKETS.WORK_ORDER.TABLE.HOURS')"
              >
                {{ hours(ticket.actual_hours) }} /
                {{ hours(ticket.estimated_hours) }}
              </span>
            </div>
            <!-- Plan-Clase-Proyecto P1 — fecha objetivo y avance -->
            <div
              v-else-if="ticket.is_project"
              class="flex items-center gap-2 mt-2 text-xs"
            >
              <span
                class="inline-flex items-center gap-1 tabular-nums"
                :class="
                  ticket.project_overdue
                    ? 'font-semibold text-red-600 dark:text-red-400'
                    : 'text-slate-500 dark:text-slate-400'
                "
                :title="$t('CASE_TICKETS.PROJECT.TABLE.DUE')"
              >
                <fluent-icon icon="calendar" size="12" />
                {{ ticket.project_due_on ? day(ticket.project_due_on) : '—' }}
              </span>
              <span
                v-if="ticket.progress !== null"
                class="inline-flex items-center gap-1 ml-auto"
                :title="$t('CASE_TICKETS.PROJECT.TABLE.PROGRESS')"
              >
                <span
                  class="inline-block w-10 h-1.5 overflow-hidden rounded-full bg-slate-100 dark:bg-slate-700"
                >
                  <span
                    class="block h-full rounded-full bg-indigo-500"
                    :style="{ width: `${Math.min(100, ticket.progress)}%` }"
                  />
                </span>
                <span class="tabular-nums text-slate-500 dark:text-slate-400"
                  >{{ ticket.progress }}%</span
                >
              </span>
            </div>
            <div
              v-else-if="ticket.due_at"
              class="flex items-center gap-1 mt-2 text-xs tabular-nums"
              :class="
                ticket.due_overdue
                  ? 'font-semibold text-red-600 dark:text-red-400'
                  : 'text-slate-500 dark:text-slate-400'
              "
              :title="$t('CASE_TICKETS.TABLE.DUE')"
            >
              <fluent-icon icon="calendar" size="12" />
              {{ day(ticket.due_at) }}
            </div>

            <!-- Pie: prioridad (solo Alta / Urgente), naturaleza ITIL, responsable -->
            <div class="flex items-center gap-2 mt-2 text-xs">
              <span
                v-if="priorityPill(ticket.priority)"
                class="px-2 py-0.5 text-[11px] rounded-full"
                :class="priorityPill(ticket.priority)"
              >
                {{ priorityOptions[ticket.priority] }}
              </span>
              <!-- Naturaleza ITIL: solo si el tipo usa ITIL (si no, todo caso
                   trae «Solicitud de servicio» por defecto y no dice nada). -->
              <span
                v-if="
                  ticket.ticket_kind &&
                  ticket.case_type &&
                  ticket.case_type.itil_enabled
                "
                class="px-2 py-0.5 text-[11px] rounded-full bg-slate-100 text-slate-600 dark:bg-slate-700 dark:text-slate-300"
              >
                {{ kindLabel(ticket.ticket_kind) }}
              </span>
              <span
                v-if="assigneeName(ticket)"
                class="inline-flex items-center min-w-0 gap-1.5 ml-auto text-slate-600 dark:text-slate-300"
              >
                <span
                  class="inline-flex items-center justify-center flex-shrink-0 w-5 h-5 text-[10px] font-semibold rounded-full bg-woot-50 text-woot-700 dark:bg-woot-800/40 dark:text-woot-200"
                  >{{ initials(assigneeName(ticket)) }}</span
                >
                <span class="truncate max-w-[7rem]">{{
                  assigneeName(ticket)
                }}</span>
              </span>
            </div>
          </div>
          <p
            v-if="!grouped[col.key].length"
            class="px-2 py-4 text-xs text-center text-slate-400 dark:text-slate-500"
          >
            {{ $t('CASE_TICKETS.KANBAN.EMPTY_COLUMN') }}
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
          <!-- Tablero por tipo (A+): el destino es la columna; el backend elige el
               estado legal. No se ofrece selección de estado. -->
          <p
            v-if="moveTargetColumn"
            class="m-0 text-sm text-slate-600 dark:text-slate-300"
          >
            {{ $t('CASE_TICKETS.KANBAN.MOVE_TO') }}
            <strong>{{ moveTargetColumn.label }}</strong>
          </p>
          <label
            v-else-if="moveCandidates.length > 1"
            class="flex flex-col gap-1"
          >
            <span
              class="text-sm font-medium text-slate-700 dark:text-slate-200"
            >
              {{ $t('CASE_TICKETS.KANBAN.MOVE_TARGET') }}
            </span>
            <select
              v-model="moveTarget"
              class="input"
              @change="onMoveTargetChange"
            >
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

          <!-- @tickets_cases — avisar al cliente al mover (solo si hay conversación) -->
          <div
            v-if="moveTicket && moveTicket.conversation_display_id"
            class="flex flex-col gap-2 p-3 border border-dashed rounded-lg border-slate-300 dark:border-slate-600 bg-slate-25 dark:bg-slate-800/40"
          >
            <label
              class="flex items-center gap-2 text-sm font-medium text-slate-700 dark:text-slate-200"
            >
              <input v-model="notifyContact" type="checkbox" />
              {{ $t('CASE_TICKETS.KANBAN.NOTIFY_LABEL') }}
            </label>
            <textarea
              v-if="notifyContact"
              v-model="notifyMessage"
              class="input !mb-0"
              rows="3"
              :placeholder="$t('CASE_TICKETS.KANBAN.NOTIFY_PLACEHOLDER')"
            />
            <span
              v-if="notifyContact"
              class="text-xs text-slate-400 dark:text-slate-500"
            >
              {{ $t('CASE_TICKETS.KANBAN.NOTIFY_HELP') }}
            </span>
          </div>

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

    <!-- Plan-Clase-Comercial F4 — datos que pide el embudo al soltar -->
    <OutcomeModal
      v-if="outcomeMove"
      show
      :folio="outcomeMove.ticket.folio || `#${outcomeMove.ticket.id}`"
      :outcome="outcomeMove.outcome"
      @close="outcomeMove = null"
      @confirm="confirmOutcomeMove"
    />
    <PostponeModal
      v-if="postponeMove"
      show
      :folio="postponeMove.ticket.folio || `#${postponeMove.ticket.id}`"
      @close="postponeMove = null"
      @confirm="confirmPostponeMove"
    />

    <!-- @tickets_cases Fase C — modal de alta de ticket interno -->
    <CaseTicketInternalModal
      v-if="showInternalModal"
      :show="showInternalModal"
      :case-class="caseClass"
      :preset-type-id="filters.case_type_id"
      @created="onInternalCreated"
      @close="showInternalModal = false"
    />
  </div>
</template>
