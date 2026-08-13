<!--
  @tickets_cases F2 — Reuniones del ticket (plan §6).
  Misma estructura que TicketNotes/TicketTasks: VeTable + TableFooter + modal.
  La reunión puede colgar del ticket o de una tarea (columna "Tarea", folio T00N).

  F2 no habla con Google: toda reunión vive `local_only` hasta que F3 encienda el
  espejo. Por eso la columna de sincronización avisa en vez de prometer.
-->
<script>
import { VeTable } from 'vue-easytable';
import { mixin as clickaway } from 'vue-clickaway';
import CaseMeetingsAPI from 'dashboard/api/caseMeetings';
import CaseNotesAPI from 'dashboard/api/caseNotes';
import CaseTasksAPI from 'dashboard/api/caseTasks';
import TableFooter from 'dashboard/components/widgets/TableFooter.vue';
import WootDropdownMenu from 'shared/components/ui/dropdown/DropdownMenu.vue';
import WootDropdownItem from 'shared/components/ui/dropdown/DropdownItem.vue';
import MeetingFormModal from './MeetingFormModal.vue';

const PER_PAGE = 10;

export default {
  name: 'TicketMeetings',
  components: {
    VeTable,
    TableFooter,
    WootDropdownMenu,
    WootDropdownItem,
    MeetingFormModal,
  },
  mixins: [clickaway],
  props: {
    ticketId: { type: [Number, String], required: true },
    // Ticket cerrado/cancelado = solo lectura: se ocultan las acciones para no
    // ofrecer botones que el backend va a rechazar con 422.
    isFrozen: { type: Boolean, default: false },
    // Correo del contacto del ticket (vacío en tickets internos).
    contactEmail: { type: String, default: '' },
  },
  data() {
    return {
      meetings: [],
      organizers: [],
      tasks: [],
      isLoading: false,
      isSaving: false,
      currentPage: 1,
      perPage: PER_PAGE,
      filterText: '',
      // Por defecto la más próxima primero (la agenda se lee hacia adelante).
      sortConfig: { starts_at: 'asc' },
      sortOption: {
        sortAlways: true,
        sortChange: params => this.onSortChange(params),
      },
      showModal: false,
      editing: null,
      contextTask: null,
      // Menú de acciones de la fila (posición fija anclada al botón "…").
      rowMenu: null,
      // Minuta: al marcar realizada se OFRECE capturarla, no se impone (§6.3).
      minutesFor: null,
      minutesText: '',
      isSavingMinutes: false,
      showDeleteConfirm: false,
      pendingDelete: null,
    };
  },
  computed: {
    filteredMeetings() {
      const q = this.filterText.trim().toLowerCase();
      if (!q) return this.meetings;
      return this.meetings.filter(m => {
        const folio = m.case_task
          ? this.taskFolio(m.case_task.sequence).toLowerCase()
          : '';
        return (
          (m.title || '').toLowerCase().includes(q) ||
          (m.folio || '').toLowerCase().includes(q) ||
          (m.location || '').toLowerCase().includes(q) ||
          (m.organizer?.name || '').toLowerCase().includes(q) ||
          folio.includes(q) ||
          (m.case_task?.title || '').toLowerCase().includes(q)
        );
      });
    },
    sortedMeetings() {
      const [field, dir] = Object.entries(this.sortConfig)[0] || [];
      const rows = [...this.filteredMeetings];
      if (!field || !dir) return rows;
      const factor = dir === 'asc' ? 1 : -1;
      return rows.sort((a, b) => this.compareBy(a, b, field) * factor);
    },
    totalPages() {
      return Math.max(1, Math.ceil(this.sortedMeetings.length / this.perPage));
    },
    paginatedMeetings() {
      const start = (this.currentPage - 1) * this.perPage;
      return this.sortedMeetings.slice(start, start + this.perPage);
    },
    eventCustomOption() {
      return {
        bodyRowEvents: ({ row }) => ({
          click: event => {
            if (event.target.closest('button, input, a')) return;
            if (!this.isFrozen) this.openEdit(row);
          },
        }),
      };
    },
    columns() {
      return [
        {
          field: 'folio',
          key: 'folio',
          title: this.$t('CASE_TICKETS.MEETINGS.TABLE.NUM'),
          align: 'left',
          width: 70,
          sortBy: this.sortConfig.folio || '',
          renderBodyCell: ({ row }) => (
            <span class="font-mono text-sm font-semibold whitespace-nowrap text-slate-300 dark:text-slate-500">
              {row.folio}
            </span>
          ),
        },
        {
          field: 'case_task',
          key: 'case_task',
          title: this.$t('CASE_TICKETS.MEETINGS.TABLE.TASK'),
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
          field: 'title',
          key: 'title',
          title: this.$t('CASE_TICKETS.MEETINGS.TABLE.MEETING'),
          align: 'left',
          width: 420,
          sortBy: this.sortConfig.title || '',
          renderBodyCell: ({ row }) => (
            <div class="overflow-hidden">
              <p
                class="m-0 text-sm truncate text-slate-800 dark:text-slate-100"
                title={row.title}
              >
                {row.title}
              </p>
              <p class="m-0 mt-0.5 text-xs truncate text-slate-400 dark:text-slate-500">
                <span>{this.formatRange(row)}</span>
                {row.location ? <span>{` · ${row.location}`}</span> : null}
                {/* F3 — liga de Meet que devolvió Google al espejar. */}
                {row.meeting_url ? (
                  <a
                    href={row.meeting_url}
                    target="_blank"
                    rel="noopener noreferrer"
                    class="ml-1 text-woot-500 hover:underline"
                  >
                    {this.$t('CASE_TICKETS.MEETINGS.MEET_LINK')}
                  </a>
                ) : null}
              </p>
            </div>
          ),
        },
        {
          field: 'starts_at',
          key: 'starts_at',
          title: this.$t('CASE_TICKETS.MEETINGS.TABLE.WHEN'),
          align: 'left',
          width: 150,
          sortBy: this.sortConfig.starts_at || '',
          renderBodyCell: ({ row }) => (
            <div class="flex items-center gap-1">
              <span class="text-sm tabular-nums text-slate-600 dark:text-slate-300">
                {this.formatDate(row.starts_at)}
              </span>
              {/* La reunión se pasa del vencimiento de su tarea: se marca, no se
                  corrige sola (las acciones son F6). */}
              {this.isPastTaskDue(row) ? (
                <fluent-icon
                  icon="warning"
                  size="14"
                  class="text-amber-500"
                  title={this.$t('CASE_TICKETS.MEETINGS.PAST_DUE_HINT')}
                />
              ) : null}
            </div>
          ),
        },
        {
          field: 'status',
          key: 'status',
          title: this.$t('CASE_TICKETS.MEETINGS.TABLE.STATUS'),
          align: 'left',
          width: 130,
          sortBy: this.sortConfig.status || '',
          renderBodyCell: ({ row }) => (
            <div class="flex flex-col gap-0.5">
              <span class={`meeting-badge ${this.statusClass(row.status)}`}>
                {this.statusLabel(row.status)}
              </span>
              {/* F3 — estado del espejo con Google, debajo del estado real. */}
              {row.sync_status !== 'synced' ? (
                <span
                  class={`text-[10px] ${this.syncClass(row.sync_status)}`}
                  title={this.syncHint(row)}
                >
                  {this.$t(
                    `CASE_TICKETS.MEETINGS.SYNC.${row.sync_status.toUpperCase()}`
                  )}
                </span>
              ) : null}
            </div>
          ),
        },
        {
          field: 'organizer',
          key: 'organizer',
          title: this.$t('CASE_TICKETS.MEETINGS.TABLE.ORGANIZER'),
          align: 'left',
          width: 140,
          sortBy: this.sortConfig.organizer || '',
          renderBodyCell: ({ row }) =>
            row.organizer ? row.organizer.name : '—',
        },
        {
          field: 'id',
          key: 'actions',
          title: '',
          width: 60,
          align: 'left',
          renderBodyCell: ({ row }) =>
            this.isFrozen ? null : (
              <div class="button-wrapper">
                <woot-button
                  size="large"
                  variant="clear"
                  color-scheme="secondary"
                  icon="more-vertical"
                  title={this.$t('CASE_TICKETS.MEETINGS.ACTIONS')}
                  onClick={e => this.openRowMenu(e, row)}
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
    meetings() {
      this.$emit('count', this.meetings.length);
      if (this.currentPage > this.totalPages)
        this.currentPage = this.totalPages;
    },
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
        const { data } = await CaseMeetingsAPI.getAll(this.ticketId);
        this.meetings = data.case_meetings || [];
        this.organizers = data.available_organizers || [];
      } finally {
        this.isLoading = false;
      }
    },
    // Las tareas solo se necesitan para el selector del modal.
    async loadTasks() {
      try {
        const { data } = await CaseTasksAPI.getAll(this.ticketId);
        this.tasks = data.case_tasks || [];
      } catch (e) {
        this.tasks = [];
      }
    },
    refresh() {
      this.load();
    },
    openCreate(task = null) {
      this.editing = null;
      this.contextTask = task || null;
      this.loadTasks();
      this.showModal = true;
    },
    openEdit(meeting) {
      this.editing = meeting;
      this.contextTask = null;
      this.loadTasks();
      this.showModal = true;
    },
    async submitForm(payload) {
      if (this.isSaving) return;
      this.isSaving = true;
      try {
        if (this.editing) {
          const { data } = await CaseMeetingsAPI.updateMeeting(
            this.ticketId,
            this.editing.id,
            payload
          );
          this.meetings = this.meetings.map(m =>
            m.id === data.case_meeting.id ? data.case_meeting : m
          );
        } else {
          const { data } = await CaseMeetingsAPI.createMeeting(
            this.ticketId,
            payload
          );
          this.meetings = [...this.meetings, data.case_meeting];
          this.currentPage = 1;
        }
        this.showModal = false;
        this.$emit('changed');
      } catch (e) {
        this.toastError(e);
      } finally {
        this.isSaving = false;
      }
    },
    // F4 — alta de una SERIE: el backend arma el RRULE, espeja el maestro en
    // Google y devuelve cuántas ocurrencias creó; aquí solo se recarga la tabla.
    async submitSeries(payload) {
      if (this.isSaving) return;
      this.isSaving = true;
      try {
        const { data } = await CaseMeetingsAPI.createSeries(
          this.ticketId,
          payload
        );
        this.showModal = false;
        await this.load();
        this.currentPage = 1;
        this.$emit('changed');
        this.$emitter.emit('caseToastMessage', {
          message: this.$t('CASE_TICKETS.MEETINGS.SERIES_CREATED', {
            count: data.meetings_created,
            folio: data.case_meeting_series.folio,
          }),
          icon: 'calendar-clock',
        });
      } catch (e) {
        this.toastError(e);
      } finally {
        this.isSaving = false;
      }
    },
    // ── Menú de acciones de la fila ───────────────────────────────────────
    openRowMenu(event, row) {
      const rect = event.currentTarget.getBoundingClientRect();
      this.rowMenu = { row, top: rect.bottom + 4, left: rect.left - 180 };
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
    menuEdit() {
      const row = this.rowMenu?.row;
      this.closeRowMenu();
      if (row) this.openEdit(row);
    },
    menuHold(status) {
      const row = this.rowMenu?.row;
      this.closeRowMenu();
      if (row) this.hold(row, status);
    },
    menuCancel(scope) {
      const row = this.rowMenu?.row;
      this.closeRowMenu();
      if (row) this.cancel(row, scope);
    },
    // F3 — reintentar el espejo con Google tras un fallo.
    menuResync() {
      const row = this.rowMenu?.row;
      this.closeRowMenu();
      if (row) this.resync(row);
    },
    async resync(meeting) {
      try {
        const { data } = await CaseMeetingsAPI.resync(
          this.ticketId,
          meeting.id
        );
        this.replace(data.case_meeting);
        this.$emitter.emit('caseToastMessage', {
          message: this.$t('CASE_TICKETS.MEETINGS.SYNC.RETRYING'),
          icon: 'arrow-clockwise',
        });
        // El espejo corre en segundo plano: se relee un momento después.
        setTimeout(() => this.load(), 3000);
      } catch (e) {
        this.toastError(e);
      }
    },
    menuDelete() {
      const row = this.rowMenu?.row;
      this.closeRowMenu();
      if (row) {
        this.pendingDelete = row;
        this.showDeleteConfirm = true;
      }
    },
    // ── Acciones ──────────────────────────────────────────────────────────
    async hold(meeting, status) {
      try {
        const { data } = await CaseMeetingsAPI.hold(
          this.ticketId,
          meeting.id,
          status
        );
        this.replace(data.case_meeting);
        this.$emit('changed');
        // Cierre del círculo con las notas: se OFRECE la minuta (§6.3).
        this.minutesFor = data.case_meeting;
        this.minutesText = '';
      } catch (e) {
        this.toastError(e);
      }
    },
    async cancel(meeting, scope) {
      try {
        const { data } = await CaseMeetingsAPI.cancel(
          this.ticketId,
          meeting.id,
          scope
        );
        // Cancelar la serie toca varias filas: se recarga todo.
        if (scope === 'all') await this.load();
        else this.replace(data.case_meeting);
        this.$emit('changed');
      } catch (e) {
        this.toastError(e);
      }
    },
    closeDeleteConfirm() {
      this.showDeleteConfirm = false;
      this.pendingDelete = null;
    },
    async confirmRemove() {
      const meeting = this.pendingDelete;
      if (!meeting) return;
      this.showDeleteConfirm = false;
      await CaseMeetingsAPI.deleteMeeting(this.ticketId, meeting.id);
      this.meetings = this.meetings.filter(m => m.id !== meeting.id);
      this.pendingDelete = null;
      this.$emit('changed');
      this.$emitter.emit('caseToastMessage', {
        message: this.$t('CASE_TICKETS.MEETINGS.TOAST_DELETED'),
        icon: 'delete',
        variant: 'danger',
      });
    },
    // ── Minuta (§6.3): nota interna ligada a la MISMA tarea de la reunión ──
    closeMinutes() {
      this.minutesFor = null;
      this.minutesText = '';
    },
    async saveMinutes() {
      const content = this.minutesText.trim();
      if (!content || this.isSavingMinutes) return;
      this.isSavingMinutes = true;
      try {
        await CaseNotesAPI.createNote(this.ticketId, {
          content,
          case_task_id: this.minutesFor?.case_task?.id || null,
        });
        this.closeMinutes();
        // La nota vive en case_events: refresca Notas y Avance.
        this.$emit('changed');
        this.$emit('minutesSaved');
        this.$emitter.emit('caseToastMessage', {
          message: this.$t('CASE_TICKETS.MEETINGS.MINUTES.SAVED'),
          icon: 'clipboard',
        });
      } catch (e) {
        this.toastError(e);
      } finally {
        this.isSavingMinutes = false;
      }
    },
    // ── Auxiliares ────────────────────────────────────────────────────────
    replace(meeting) {
      this.meetings = this.meetings.map(m =>
        m.id === meeting.id ? meeting : m
      );
    },
    toastError(e) {
      this.$emitter.emit('newToastMessage', {
        message:
          e.response?.data?.error || this.$t('CASE_TICKETS.MEETINGS.ERROR'),
      });
    },
    // Filtra la tabla por el folio de una tarea (desde la fila de Tareas).
    showTaskMeetings(task) {
      this.filterText = this.taskFolio(task.sequence);
      this.currentPage = 1;
    },
    changePage(page) {
      this.currentPage = Math.min(Math.max(1, page), this.totalPages);
    },
    onSortChange(params) {
      const field = Object.keys(params).find(k => params[k]);
      this.sortConfig = field ? { [field]: params[field] } : {};
      this.currentPage = 1;
    },
    compareBy(a, b, field) {
      if (field === 'starts_at')
        return new Date(a.starts_at) - new Date(b.starts_at);
      if (field === 'folio') return (a.sequence || 0) - (b.sequence || 0);
      if (field === 'case_task')
        return (a.case_task?.sequence || 0) - (b.case_task?.sequence || 0);
      if (field === 'organizer')
        return (a.organizer?.name || '').localeCompare(b.organizer?.name || '');
      if (field === 'title')
        return (a.title || '').localeCompare(b.title || '');
      if (field === 'status')
        return (a.status || '').localeCompare(b.status || '');
      return 0;
    },
    taskFolio(n) {
      if (!n) return '';
      return `T${String(n).padStart(3, '0')}`;
    },
    statusLabel(status) {
      return this.$t(`CASE_TICKETS.MEETINGS.STATUS.${status.toUpperCase()}`);
    },
    statusClass(status) {
      return (
        {
          scheduled:
            'bg-blue-50 text-blue-700 dark:bg-blue-900/30 dark:text-blue-300',
          held: 'bg-green-50 text-green-700 dark:bg-green-900/30 dark:text-green-300',
          no_show:
            'bg-amber-50 text-amber-700 dark:bg-amber-900/30 dark:text-amber-300',
          cancelled:
            'bg-slate-100 text-slate-600 dark:bg-slate-700 dark:text-slate-300',
          rescheduled:
            'bg-violet-50 text-violet-700 dark:bg-violet-900/30 dark:text-violet-300',
        }[status] ||
        'bg-slate-100 text-slate-600 dark:bg-slate-700 dark:text-slate-300'
      );
    },
    // F3 — color del estado de sincronización con Google.
    syncClass(status) {
      if (status === 'failed') return 'text-red-500 dark:text-red-400';
      if (status === 'pending') return 'text-amber-500 dark:text-amber-400';
      return 'text-slate-400 dark:text-slate-500';
    },
    // El error de la API se muestra tal cual: es lo que explica por qué falló.
    syncHint(meeting) {
      if (meeting.sync_status === 'failed' && meeting.sync_error) {
        return meeting.sync_error;
      }
      return this.$t(
        `CASE_TICKETS.MEETINGS.SYNC.${meeting.sync_status.toUpperCase()}_HINT`
      );
    },
    // ¿La reunión cae después del vencimiento de la tarea a la que cuelga?
    isPastTaskDue(meeting) {
      const due = meeting.case_task?.due_at;
      if (!due || !meeting.starts_at) return false;
      return new Date(meeting.starts_at) > new Date(due);
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
    formatTime(d) {
      if (!d) return '';
      return new Date(d).toLocaleTimeString(undefined, {
        hour: '2-digit',
        minute: '2-digit',
      });
    },
    // "13/08/2026, 10:00 – 11:00"
    formatRange(meeting) {
      if (!meeting.starts_at) return '';
      return `${this.formatDate(meeting.starts_at)} – ${this.formatTime(
        meeting.ends_at
      )}`;
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
        {{ $t('CASE_TICKETS.MEETINGS.TITLE') }}
        <span
          v-if="meetings.length"
          class="ml-1 text-sm font-normal text-slate-400 dark:text-slate-500"
          >{{ meetings.length }}</span
        >
      </h3>
      <div class="flex items-center gap-2">
        <woot-button
          v-tooltip.top="$t('CASE_TICKETS.MEETINGS.REFRESH')"
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
          @click="openCreate()"
        >
          {{ $t('CASE_TICKETS.MEETINGS.ADD_NEW') }}
        </woot-button>
      </div>
    </div>

    <!-- Filtro rápido de la tabla -->
    <div v-if="meetings.length" class="flex-shrink-0 mb-3">
      <div class="relative w-full max-w-xs">
        <fluent-icon
          icon="search"
          size="16"
          class="absolute pointer-events-none text-slate-400 dark:text-slate-500 left-2.5 top-1/2 -translate-y-1/2"
        />
        <input
          v-model="filterText"
          type="text"
          :placeholder="$t('CASE_TICKETS.MEETINGS.FILTER_PLACEHOLDER')"
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

    <div
      v-if="isLoading && !meetings.length"
      class="py-2 text-sm text-slate-400"
    >
      {{ $t('CASE_TICKETS.MEETINGS.LOADING') }}
    </div>
    <div
      v-else-if="!meetings.length"
      class="py-2 text-sm text-slate-400 dark:text-slate-500"
    >
      {{ $t('CASE_TICKETS.MEETINGS.EMPTY') }}
    </div>
    <div
      v-else-if="!sortedMeetings.length"
      class="py-2 text-sm text-slate-400 dark:text-slate-500"
    >
      {{ $t('CASE_TICKETS.MEETINGS.NO_MATCHES') }}
    </div>

    <div v-else class="flex-1 min-h-0 meetings-table-wrap">
      <VeTable
        fixed-header
        max-height="100%"
        row-key-field-name="id"
        :columns="columns"
        :table-data="paginatedMeetings"
        :event-custom-option="eventCustomOption"
        :sort-option="sortOption"
        :border-around="false"
      />
    </div>

    <TableFooter
      v-if="sortedMeetings.length"
      :current-page="currentPage"
      :total-count="sortedMeetings.length"
      :page-size="perPage"
      class="flex-shrink-0 !px-0 border-t border-slate-75 dark:border-slate-700"
      @pageChange="changePage"
    />

    <MeetingFormModal
      v-if="showModal"
      :show="showModal"
      :meeting="editing"
      :tasks="tasks"
      :organizers="organizers"
      :contact-email="contactEmail"
      :context-task="contextTask"
      :is-saving="isSaving"
      @submit="submitForm"
      @submitSeries="submitSeries"
      @close="showModal = false"
    />

    <!-- Minuta: se ofrece al marcar la reunión como realizada (§6.3). La nota
         queda ligada a la MISMA tarea de la reunión. -->
    <woot-modal
      v-if="minutesFor"
      :show="!!minutesFor"
      :on-close="closeMinutes"
      size="medium"
    >
      <div class="flex flex-col h-auto overflow-auto">
        <woot-modal-header
          :header-title="$t('CASE_TICKETS.MEETINGS.MINUTES.TITLE')"
          :header-content="$t('CASE_TICKETS.MEETINGS.MINUTES.DESC')"
        />
        <form
          class="flex flex-col self-stretch w-full gap-3 pb-8"
          @submit.prevent="saveMinutes"
        >
          <label class="block">
            <span class="text-sm text-slate-700 dark:text-slate-200">{{
              $t('CASE_TICKETS.MEETINGS.MINUTES.LABEL')
            }}</span>
            <textarea
              v-model="minutesText"
              rows="6"
              :placeholder="$t('CASE_TICKETS.MEETINGS.MINUTES.PLACEHOLDER')"
            />
          </label>
          <div class="flex items-center justify-end gap-2">
            <woot-button variant="clear" type="button" @click="closeMinutes">
              {{ $t('CASE_TICKETS.MEETINGS.MINUTES.SKIP') }}
            </woot-button>
            <woot-button
              :is-loading="isSavingMinutes"
              :disabled="!minutesText.trim()"
              type="submit"
            >
              {{ $t('CASE_TICKETS.MEETINGS.MINUTES.SAVE') }}
            </woot-button>
          </div>
        </form>
      </div>
    </woot-modal>

    <woot-delete-modal
      :show="showDeleteConfirm"
      :on-close="closeDeleteConfirm"
      :on-confirm="confirmRemove"
      :title="$t('CASE_TICKETS.MEETINGS.DELETE_CONFIRM.TITLE')"
      :message="$t('CASE_TICKETS.MEETINGS.DELETE_CONFIRM.MESSAGE')"
      :message-value="pendingDelete ? `“${pendingDelete.title}”` : ''"
      :confirm-text="$t('CASE_TICKETS.MEETINGS.DELETE_CONFIRM.CONFIRM')"
      :reject-text="$t('CASE_TICKETS.MEETINGS.DELETE_CONFIRM.CANCEL')"
    />

    <!-- Menú de acciones de la fila: posición FIJA anclada al botón "…", igual
         que en Tareas, para que no lo recorte el overflow de la tabla. -->
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
            icon="edit"
            @click="menuEdit"
          >
            {{ $t('CASE_TICKETS.MEETINGS.MENU.EDIT') }}
          </woot-button>
        </WootDropdownItem>
        <WootDropdownItem v-if="rowMenu.row.sync_status === 'failed'">
          <woot-button
            variant="clear"
            color-scheme="secondary"
            size="small"
            icon="arrow-clockwise"
            @click="menuResync"
          >
            {{ $t('CASE_TICKETS.MEETINGS.MENU.RESYNC') }}
          </woot-button>
        </WootDropdownItem>
        <WootDropdownItem>
          <woot-button
            variant="clear"
            color-scheme="secondary"
            size="small"
            icon="checkmark-circle"
            @click="menuHold('held')"
          >
            {{ $t('CASE_TICKETS.MEETINGS.MENU.HELD') }}
          </woot-button>
        </WootDropdownItem>
        <WootDropdownItem>
          <woot-button
            variant="clear"
            color-scheme="secondary"
            size="small"
            icon="person"
            @click="menuHold('no_show')"
          >
            {{ $t('CASE_TICKETS.MEETINGS.MENU.NO_SHOW') }}
          </woot-button>
        </WootDropdownItem>
        <WootDropdownItem>
          <woot-button
            variant="clear"
            color-scheme="secondary"
            size="small"
            icon="dismiss-circle"
            @click="menuCancel('one')"
          >
            {{ $t('CASE_TICKETS.MEETINGS.MENU.CANCEL_ONE') }}
          </woot-button>
        </WootDropdownItem>
        <WootDropdownItem v-if="rowMenu.row.series">
          <woot-button
            variant="clear"
            color-scheme="secondary"
            size="small"
            icon="calendar-clock"
            @click="menuCancel('all')"
          >
            {{ $t('CASE_TICKETS.MEETINGS.MENU.CANCEL_ALL') }}
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
            {{ $t('CASE_TICKETS.MEETINGS.MENU.DELETE') }}
          </woot-button>
        </WootDropdownItem>
      </WootDropdownMenu>
    </div>
  </div>
</template>

<style lang="scss" scoped>
// Mismos ajustes que TicketNotes/TicketTasks.
.meetings-table-wrap {
  overflow: hidden;
}

.meetings-table-wrap::v-deep {
  // Sin `height: 100%` aquí, el `max-height: 100%` de la tabla no resuelve y se
  // desborda de la card.
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

  .meeting-badge {
    @apply inline-block px-1.5 py-0.5 text-[11px] font-medium rounded whitespace-nowrap;
  }
}

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
</style>
