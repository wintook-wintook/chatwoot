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

const PER_PAGE = 10;

export default {
  name: 'TicketTasks',
  components: { VeTable, TableFooter },
  props: {
    ticketId: { type: [Number, String], required: true },
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
      // Modal de alta/edición
      showModal: false,
      editingId: null,
      form: { title: '', description: '', assignee_id: '', due_at: '' },
    };
  },
  computed: {
    ...mapGetters({ agents: 'agents/getAgents' }),
    doneCount() {
      return this.tasks.filter(t => t.status === 'done').length;
    },
    totalPages() {
      return Math.max(1, Math.ceil(this.tasks.length / this.perPage));
    },
    paginatedTasks() {
      const start = (this.currentPage - 1) * this.perPage;
      return this.tasks.slice(start, start + this.perPage);
    },
    isEditing() {
      return !!this.editingId;
    },
    // Columnas de VeTable. Las celdas se pintan con renderBodyCell (JSX), que es
    // como lo hace Chatwoot en ContactsTable.
    columns() {
      return [
        {
          field: 'status',
          key: 'select',
          title: '',
          width: 44,
          align: 'left',
          renderBodyCell: ({ row }) => (
            <input
              type="checkbox"
              class="!mb-0 align-middle"
              title={this.$t('CASE_TICKETS.TASKS.TOGGLE')}
              domPropsChecked={row.status === 'done'}
              onChange={() => this.toggle(row)}
            />
          ),
        },
        {
          field: 'title',
          key: 'title',
          title: this.$t('CASE_TICKETS.TASKS.TABLE.TASK'),
          align: 'left',
          width: 340,
          renderBodyCell: ({ row }) => (
            <div>
              <p
                class={
                  row.status === 'done'
                    ? 'm-0 text-sm line-through text-slate-400 dark:text-slate-500'
                    : 'm-0 text-sm text-slate-800 dark:text-slate-100'
                }
              >
                {row.title}
              </p>
              {row.description ? (
                <p class="m-0 mt-0.5 text-xs whitespace-pre-line text-slate-500 dark:text-slate-400">
                  {row.description}
                </p>
              ) : null}
            </div>
          ),
        },
        {
          field: 'assignee',
          key: 'assignee',
          title: this.$t('CASE_TICKETS.TASKS.TABLE.ASSIGNEE'),
          align: 'left',
          width: 150,
          renderBodyCell: ({ row }) => this.assigneeName(row) || '—',
        },
        {
          field: 'due_at',
          key: 'due_at',
          title: this.$t('CASE_TICKETS.TASKS.TABLE.DUE'),
          align: 'left',
          width: 160,
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
          // @tickets_cases P4 — firma de completado: cuándo y quién.
          field: 'completed_at',
          key: 'completed_at',
          title: this.$t('CASE_TICKETS.TASKS.TABLE.COMPLETED'),
          align: 'left',
          width: 180,
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
                <span class="text-xs text-emerald-600 dark:text-emerald-400">
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
          width: 90,
          align: 'left',
          renderBodyCell: ({ row }) => (
            <div class="button-wrapper">
              <woot-button
                size="tiny"
                variant="clear"
                color-scheme="secondary"
                icon="edit"
                title={this.$t('CASE_TICKETS.TASKS.EDIT')}
                onClick={() => this.openEdit(row)}
              />
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
  },
  mounted() {
    this.$store.dispatch('agents/get');
    this.load();
  },
  methods: {
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
    openCreate() {
      this.editingId = null;
      this.form = { title: '', description: '', assignee_id: '', due_at: '' };
      this.showModal = true;
      this.$nextTick(() => this.$refs.titleInput?.focus());
    },
    openEdit(task) {
      this.editingId = task.id;
      this.form = {
        title: task.title || '',
        description: task.description || '',
        assignee_id: task.assignee_id || '',
        due_at: this.toInputDate(task.due_at),
      };
      this.showModal = true;
      this.$nextTick(() => this.$refs.titleInput?.focus());
    },
    async submitForm() {
      const title = this.form.title.trim();
      if (!title || this.isSaving) return;
      const payload = {
        title,
        description: this.form.description.trim(),
        assignee_id: this.form.assignee_id || '',
        due_at: this.form.due_at || null,
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
          // Saltar a la última página para que la tarea recién creada se vea.
          this.currentPage = this.totalPages;
        }
        this.showModal = false;
      } finally {
        this.isSaving = false;
      }
    },
    async toggle(task) {
      const status = task.status === 'done' ? 'pending' : 'done';
      const { data } = await CaseTasksAPI.updateTask(this.ticketId, task.id, {
        status,
      });
      this.replace(data.case_task);
    },
    async remove(task) {
      await CaseTasksAPI.deleteTask(this.ticketId, task.id);
      this.tasks = this.tasks.filter(t => t.id !== task.id);
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
      <woot-button size="small" icon="add" @click="openCreate">
        {{ $t('CASE_TICKETS.TASKS.ADD') }}
      </woot-button>
    </div>

    <div v-if="isLoading" class="py-2 text-sm text-slate-400">
      {{ $t('CASE_TICKETS.TASKS.LOADING') }}
    </div>
    <div
      v-else-if="!tasks.length"
      class="py-2 text-sm text-slate-400 dark:text-slate-500"
    >
      {{ $t('CASE_TICKETS.TASKS.EMPTY') }}
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
        :border-around="false"
      />
    </div>

    <!-- Paginación: componente estándar de Chatwoot, igual que en Seguimientos.
         Se queda abajo aunque haya una sola tarea (solo desaparece con cero). -->
    <TableFooter
      :current-page="currentPage"
      :total-count="tasks.length"
      :page-size="perPage"
      class="flex-shrink-0 !px-0 border-t border-slate-75 dark:border-slate-700"
      @pageChange="changePage"
    />

    <!-- Modal de alta / edición -->
    <woot-modal
      v-if="showModal"
      :show="showModal"
      :on-close="() => (showModal = false)"
      size="small"
    >
      <div class="flex flex-col h-auto overflow-auto">
        <woot-modal-header
          :header-title="
            isEditing
              ? $t('CASE_TICKETS.TASKS.MODAL.EDIT_TITLE')
              : $t('CASE_TICKETS.TASKS.MODAL.NEW_TITLE')
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
              :placeholder="$t('CASE_TICKETS.TASKS.ADD_PLACEHOLDER')"
            />
          </label>

          <label class="block mb-3">
            <span class="text-sm text-slate-700 dark:text-slate-200">{{
              $t('CASE_TICKETS.TASKS.MODAL.DESCRIPTION_LABEL')
            }}</span>
            <textarea
              v-model="form.description"
              rows="3"
              :placeholder="
                $t('CASE_TICKETS.TASKS.MODAL.DESCRIPTION_PLACEHOLDER')
              "
            />
          </label>

          <div class="flex gap-3">
            <label class="flex-1">
              <span class="text-sm text-slate-700 dark:text-slate-200">{{
                $t('CASE_TICKETS.TASKS.MODAL.ASSIGNEE_LABEL')
              }}</span>
              <select v-model="form.assignee_id">
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
                class="w-full h-10 p-2 bg-white border rounded-md border-slate-200 dark:border-slate-600 dark:bg-slate-900 text-slate-800 dark:text-slate-100"
              />
            </label>
          </div>

          <div class="flex items-center justify-end gap-2 mt-4">
            <woot-button
              variant="clear"
              type="button"
              @click="showModal = false"
            >
              {{ $t('CASE_TICKETS.TASKS.MODAL.CANCEL') }}
            </woot-button>
            <woot-button
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

  .ve-table-body-td {
    padding: var(--space-small) var(--space-one) !important;
    vertical-align: top;
  }

  .button-wrapper {
    @apply flex flex-row gap-1;
  }
}
</style>
