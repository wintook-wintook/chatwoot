<!--
  @tickets_cases 2I
  Configuración de políticas SLA (prioridad × tipo × naturaleza). Ahora con tabla
  nativa de Chatwoot (vue-easytable) + paginado inferior, badge de prioridad y
  toggle de activo, en lugar de la tabla HTML plana.
-->
<script>
import { mapGetters } from 'vuex';
import { VeTable } from 'vue-easytable';
import TableFooter from 'dashboard/components/widgets/TableFooter.vue';

const PER_PAGE_OPTIONS = [25, 50, 100];

export default {
  name: 'SlaConfig',
  components: { VeTable, TableFooter },
  data() {
    return {
      showModal: false,
      editingId: null,
      showDelete: false,
      toDelete: null,
      currentPage: 1,
      perPage: 25,
      perPageOptions: PER_PAGE_OPTIONS,
      form: this.emptyForm(),
    };
  },
  computed: {
    ...mapGetters({
      policies: 'caseTickets/getSlaPolicies',
      uiFlags: 'caseTickets/getSlaPoliciesUIFlags',
      types: 'caseTickets/getTypes',
    }),
    priorityOptions() {
      return ['low', 'medium', 'high', 'urgent'];
    },
    kindOptions() {
      return ['incident', 'service_request', 'problem', 'change', 'query'];
    },
    pagedPolicies() {
      const start = (this.currentPage - 1) * this.perPage;
      return this.policies.slice(start, start + this.perPage);
    },
    columns() {
      return [
        {
          field: 'priority',
          key: 'priority',
          title: this.$t('CASE_TICKETS.SLA.PRIORITY'),
          align: 'left',
          width: 120,
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
          field: 'type',
          key: 'type',
          title: this.$t('CASE_TICKETS.SLA.TYPE'),
          align: 'left',
          width: 150,
          renderBodyCell: ({ row }) => (
            <span class="text-sm text-slate-600 dark:text-slate-300">
              {this.typeName(row.case_type_id)}
            </span>
          ),
        },
        {
          field: 'kind',
          key: 'kind',
          title: this.$t('CASE_TICKETS.SLA.KIND'),
          align: 'left',
          width: 150,
          renderBodyCell: ({ row }) => (
            <span class="text-sm text-slate-600 dark:text-slate-300">
              {this.kindLabel(row.ticket_kind)}
            </span>
          ),
        },
        {
          field: 'first_response',
          key: 'first_response',
          title: this.$t('CASE_TICKETS.SLA.FIRST_RESPONSE'),
          align: 'left',
          width: 140,
          renderBodyCell: ({ row }) => (
            <span class="text-sm whitespace-nowrap text-slate-600 dark:text-slate-300">
              {this.formatMinutes(row.first_response_time_target)}
            </span>
          ),
        },
        {
          field: 'resolution',
          key: 'resolution',
          title: this.$t('CASE_TICKETS.SLA.RESOLUTION'),
          align: 'left',
          width: 140,
          renderBodyCell: ({ row }) => (
            <span class="text-sm whitespace-nowrap text-slate-600 dark:text-slate-300">
              {this.formatMinutes(row.resolution_time_target)}
            </span>
          ),
        },
        {
          field: 'business_hours',
          key: 'business_hours',
          title: this.$t('CASE_TICKETS.SLA.BUSINESS_HOURS'),
          align: 'left',
          width: 120,
          renderBodyCell: ({ row }) => (
            <span class="text-sm text-slate-600 dark:text-slate-300">
              {row.business_hours_only
                ? this.$t('CASE_TICKETS.SLA.YES')
                : this.$t('CASE_TICKETS.SLA.NO')}
            </span>
          ),
        },
        {
          field: 'active',
          key: 'active',
          title: this.$t('CASE_TICKETS.SLA.ACTIVE'),
          align: 'left',
          width: 120,
          renderBodyCell: ({ row }) => (
            <woot-button
              size="tiny"
              variant={row.active ? 'smooth' : 'clear'}
              color-scheme={row.active ? 'success' : 'secondary'}
              icon={row.active ? 'checkmark-circle' : 'dismiss-circle'}
              onClick={() => this.toggleActive(row)}
            >
              {row.active
                ? this.$t('CASE_TICKETS.SLA.YES')
                : this.$t('CASE_TICKETS.SLA.NO')}
            </woot-button>
          ),
        },
        {
          field: 'actions',
          key: 'actions',
          title: '',
          align: 'right',
          width: 100,
          renderBodyCell: ({ row }) => (
            <div class="flex items-center justify-end gap-1">
              <woot-button
                size="tiny"
                variant="clear"
                color-scheme="secondary"
                icon="edit"
                onClick={() => this.openEdit(row)}
              />
              <woot-button
                size="tiny"
                variant="clear"
                color-scheme="alert"
                icon="delete"
                onClick={() => this.openDelete(row)}
              />
            </div>
          ),
        },
      ];
    },
  },
  mounted() {
    this.$store.dispatch('caseTickets/fetchSlaPolicies');
    this.$store.dispatch('caseTickets/fetchTypes');
  },
  methods: {
    emptyForm() {
      return {
        priority: 'medium',
        case_type_id: '',
        ticket_kind: '',
        first_response_time_target: null,
        resolution_time_target: null,
        business_hours_only: false,
        active: true,
      };
    },
    openCreate() {
      this.editingId = null;
      this.form = this.emptyForm();
      this.showModal = true;
    },
    openEdit(p) {
      this.editingId = p.id;
      this.form = {
        priority: p.priority,
        case_type_id: p.case_type_id || '',
        ticket_kind: p.ticket_kind || '',
        first_response_time_target: p.first_response_time_target,
        resolution_time_target: p.resolution_time_target,
        business_hours_only: p.business_hours_only,
        active: p.active,
      };
      this.showModal = true;
    },
    async save() {
      const payload = {
        priority: this.form.priority,
        case_type_id: this.form.case_type_id || null,
        ticket_kind: this.form.ticket_kind || null,
        first_response_time_target:
          this.form.first_response_time_target || null,
        resolution_time_target: this.form.resolution_time_target || null,
        business_hours_only: this.form.business_hours_only,
        active: this.form.active,
      };
      try {
        if (this.editingId) {
          await this.$store.dispatch('caseTickets/updateSlaPolicy', {
            id: this.editingId,
            ...payload,
          });
        } else {
          await this.$store.dispatch('caseTickets/createSlaPolicy', payload);
        }
        this.showModal = false;
        this.$emitter.emit('newToastMessage', {
          message: this.$t('CASE_TICKETS.SLA.SAVED'),
        });
      } catch (e) {
        this.$emitter.emit('newToastMessage', {
          message:
            e.response?.data?.error?.[0] ||
            e.response?.data?.error ||
            this.$t('CASE_TICKETS.SLA.ERROR'),
        });
      }
    },
    async toggleActive(p) {
      try {
        await this.$store.dispatch('caseTickets/updateSlaPolicy', {
          id: p.id,
          active: !p.active,
        });
      } catch (_e) {
        /* silent */
      }
    },
    openDelete(p) {
      this.toDelete = p;
      this.showDelete = true;
    },
    async confirmDelete() {
      await this.$store.dispatch(
        'caseTickets/deleteSlaPolicy',
        this.toDelete.id
      );
      this.showDelete = false;
      this.toDelete = null;
    },
    changePage(page) {
      this.currentPage = page;
    },
    changePerPage() {
      this.currentPage = 1;
    },
    typeName(id) {
      const t = this.types.find(x => x.id === id);
      return t ? t.name : this.$t('CASE_TICKETS.SLA.ANY');
    },
    kindLabel(k) {
      return k
        ? this.$t(`CASE_TICKETS.TICKET_KIND.${k}`)
        : this.$t('CASE_TICKETS.SLA.ANY');
    },
    priorityLabel(p) {
      return this.$t(`CASE_TICKETS.PRIORITIES.${p}`) || p;
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
    formatMinutes(min) {
      if (!min) return '—';
      if (min < 60) return `${min} min`;
      if (min < 1440) {
        const h = Math.floor(min / 60);
        const m = min % 60;
        return m ? `${h}h ${m}min` : `${h}h`;
      }
      const d = Math.floor(min / 1440);
      const h = Math.floor((min % 1440) / 60);
      return h ? `${d}d ${h}h` : `${d}d`;
    },
  },
};
</script>

<template>
  <div
    class="flex flex-col flex-1 w-full h-full overflow-hidden bg-slate-25 dark:bg-slate-900"
  >
    <div
      class="flex items-center justify-between flex-shrink-0 px-6 py-4 bg-white border-b dark:bg-slate-900 border-slate-50 dark:border-slate-800/50"
    >
      <div class="flex flex-col gap-1">
        <h1 class="m-0 text-xl font-bold text-slate-800 dark:text-slate-100">
          {{ $t('CASE_TICKETS.SLA.TITLE') }}
        </h1>
        <p class="m-0 text-sm text-slate-500 dark:text-slate-400">
          {{ $t('CASE_TICKETS.SLA.HELP') }}
        </p>
      </div>
      <woot-button icon="add" @click="openCreate">
        {{ $t('CASE_TICKETS.SLA.NEW') }}
      </woot-button>
    </div>

    <!-- Loading -->
    <div
      v-if="uiFlags.isFetching && !policies.length"
      class="flex items-center justify-center flex-1 text-slate-400 dark:text-slate-500"
    >
      {{ $t('CASE_TICKETS.SLA.LOADING') }}
    </div>

    <!-- Empty -->
    <div
      v-else-if="!policies.length"
      class="flex flex-col items-center justify-center flex-1 gap-3 text-slate-400 dark:text-slate-500"
    >
      <fluent-icon icon="clock" size="36" />
      <p>{{ $t('CASE_TICKETS.SLA.EMPTY') }}</p>
    </div>

    <!-- Tabla + paginado -->
    <template v-else>
      <div class="flex-1 min-h-0 px-6 py-4 sla-table-wrap">
        <VeTable
          fixed-header
          max-height="100%"
          row-key-field-name="id"
          :columns="columns"
          :table-data="pagedPolicies"
          :border-around="false"
        />
      </div>
      <div
        class="flex items-center justify-between flex-shrink-0 bg-white border-t dark:bg-slate-900 border-slate-50 dark:border-slate-800/50"
      >
        <label
          class="flex items-center gap-1 pl-6 text-xs text-slate-500 dark:text-slate-400"
        >
          {{ $t('CASE_TICKETS.SLA.PER_PAGE') }}
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
          :total-count="policies.length"
          :page-size="perPage"
          @pageChange="changePage"
        />
      </div>
    </template>

    <!-- Modal crear/editar -->
    <woot-modal
      v-if="showModal"
      :show="showModal"
      :on-close="() => (showModal = false)"
      size="small"
    >
      <div class="flex flex-col h-auto overflow-auto">
        <woot-modal-header
          :header-title="
            editingId ? $t('CASE_TICKETS.SLA.EDIT') : $t('CASE_TICKETS.SLA.NEW')
          "
        />
        <form
          class="flex flex-col self-stretch w-full gap-4 pb-8"
          @submit.prevent="save"
        >
          <div class="flex gap-3">
            <label class="flex flex-col flex-1 gap-1">
              <span
                class="text-sm font-medium text-slate-700 dark:text-slate-200"
                >{{ $t('CASE_TICKETS.SLA.PRIORITY') }}</span
              >
              <select v-model="form.priority" class="input">
                <option v-for="p in priorityOptions" :key="p" :value="p">
                  {{ priorityLabel(p) }}
                </option>
              </select>
            </label>
            <label class="flex flex-col flex-1 gap-1">
              <span
                class="text-sm font-medium text-slate-700 dark:text-slate-200"
                >{{ $t('CASE_TICKETS.SLA.KIND') }}</span
              >
              <select v-model="form.ticket_kind" class="input">
                <option value="">{{ $t('CASE_TICKETS.SLA.ANY') }}</option>
                <option v-for="k in kindOptions" :key="k" :value="k">
                  {{ $t(`CASE_TICKETS.TICKET_KIND.${k}`) }}
                </option>
              </select>
            </label>
          </div>
          <label class="flex flex-col gap-1">
            <span
              class="text-sm font-medium text-slate-700 dark:text-slate-200"
              >{{ $t('CASE_TICKETS.SLA.TYPE') }}</span
            >
            <select v-model="form.case_type_id" class="input">
              <option value="">{{ $t('CASE_TICKETS.SLA.ANY') }}</option>
              <option v-for="t in types" :key="t.id" :value="t.id">
                {{ t.name }}
              </option>
            </select>
          </label>
          <div class="flex gap-3">
            <label class="flex flex-col flex-1 gap-1">
              <span
                class="text-sm font-medium text-slate-700 dark:text-slate-200"
                >{{ $t('CASE_TICKETS.SLA.FIRST_RESPONSE') }}
                {{ $t('CASE_TICKETS.SLA.MINUTES_SUFFIX') }}</span
              >
              <input
                v-model.number="form.first_response_time_target"
                type="number"
                min="0"
                class="input"
              />
            </label>
            <label class="flex flex-col flex-1 gap-1">
              <span
                class="text-sm font-medium text-slate-700 dark:text-slate-200"
                >{{ $t('CASE_TICKETS.SLA.RESOLUTION') }}
                {{ $t('CASE_TICKETS.SLA.MINUTES_SUFFIX') }}</span
              >
              <input
                v-model.number="form.resolution_time_target"
                type="number"
                min="0"
                class="input"
              />
            </label>
          </div>
          <label class="flex items-center gap-2">
            <input
              v-model="form.business_hours_only"
              type="checkbox"
              class="m-0"
            />
            <span
              class="text-sm font-medium text-slate-700 dark:text-slate-200"
              >{{ $t('CASE_TICKETS.SLA.BUSINESS_HOURS_ONLY') }}</span
            >
          </label>
          <label class="flex items-center gap-2">
            <input v-model="form.active" type="checkbox" class="m-0" />
            <span
              class="text-sm font-medium text-slate-700 dark:text-slate-200"
              >{{ $t('CASE_TICKETS.SLA.ACTIVE') }}</span
            >
          </label>
          <div class="flex justify-end gap-2 mt-2">
            <woot-button
              variant="clear"
              color-scheme="secondary"
              type="button"
              @click="showModal = false"
            >
              {{ $t('CASE_TICKETS.SLA.CANCEL') }}
            </woot-button>
            <woot-button
              type="submit"
              color-scheme="primary"
              :is-loading="uiFlags.isSaving"
            >
              {{ $t('CASE_TICKETS.SLA.SAVE') }}
            </woot-button>
          </div>
        </form>
      </div>
    </woot-modal>

    <woot-delete-modal
      v-if="showDelete"
      :show="showDelete"
      :on-close="() => (showDelete = false)"
      :on-confirm="confirmDelete"
      :title="$t('CASE_TICKETS.SLA.DELETE.TITLE')"
      :message="$t('CASE_TICKETS.SLA.DELETE.MESSAGE')"
      :confirm-text="$t('CASE_TICKETS.SLA.DELETE.YES')"
      :reject-text="$t('CASE_TICKETS.SLA.DELETE.NO')"
    />
  </div>
</template>

<style lang="scss" scoped>
.sla-table-wrap {
  overflow: hidden;
}

.sla-table-wrap::v-deep {
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
  }
}
</style>
