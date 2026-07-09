<!--
  @tickets_cases 2I
  Configuración de políticas SLA (prioridad × tipo × naturaleza). Tailwind + dark mode.
-->
<script>
import { mapGetters } from 'vuex';

export default {
  name: 'SlaConfig',
  data() {
    return {
      showModal: false,
      editingId: null,
      showDelete: false,
      toDelete: null,
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
    class="flex flex-col flex-1 w-full h-full overflow-auto bg-slate-25 dark:bg-slate-900"
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

    <div class="flex-1 w-full p-6">
      <div
        v-if="uiFlags.isFetching"
        class="text-sm text-slate-400 dark:text-slate-500"
      >
        {{ $t('CASE_TICKETS.SLA.LOADING') }}
      </div>
      <table
        v-else
        class="w-full text-sm bg-white border rounded-lg dark:bg-slate-800 border-slate-75 dark:border-slate-700"
      >
        <thead>
          <tr
            class="text-xs tracking-wide text-left uppercase text-slate-400 dark:text-slate-500 border-b border-slate-75 dark:border-slate-700"
          >
            <th class="px-4 py-3 font-medium">
              {{ $t('CASE_TICKETS.SLA.PRIORITY') }}
            </th>
            <th class="px-4 py-3 font-medium">
              {{ $t('CASE_TICKETS.SLA.TYPE') }}
            </th>
            <th class="px-4 py-3 font-medium">
              {{ $t('CASE_TICKETS.SLA.KIND') }}
            </th>
            <th class="px-4 py-3 font-medium">
              {{ $t('CASE_TICKETS.SLA.FIRST_RESPONSE') }}
            </th>
            <th class="px-4 py-3 font-medium">
              {{ $t('CASE_TICKETS.SLA.RESOLUTION') }}
            </th>
            <th class="px-4 py-3 font-medium">
              {{ $t('CASE_TICKETS.SLA.BUSINESS_HOURS') }}
            </th>
            <th class="px-4 py-3 font-medium">
              {{ $t('CASE_TICKETS.SLA.ACTIVE') }}
            </th>
            <th class="px-4 py-3" />
          </tr>
        </thead>
        <tbody>
          <tr
            v-for="p in policies"
            :key="p.id"
            class="border-b border-slate-50 dark:border-slate-700/50 last:border-0"
          >
            <td
              class="px-4 py-3 font-medium text-slate-700 dark:text-slate-200"
            >
              {{ priorityLabel(p.priority) }}
            </td>
            <td class="px-4 py-3 text-slate-600 dark:text-slate-300">
              {{ typeName(p.case_type_id) }}
            </td>
            <td class="px-4 py-3 text-slate-600 dark:text-slate-300">
              {{ kindLabel(p.ticket_kind) }}
            </td>
            <td class="px-4 py-3 text-slate-600 dark:text-slate-300">
              {{ formatMinutes(p.first_response_time_target) }}
            </td>
            <td class="px-4 py-3 text-slate-600 dark:text-slate-300">
              {{ formatMinutes(p.resolution_time_target) }}
            </td>
            <td class="px-4 py-3 text-slate-600 dark:text-slate-300">
              {{
                p.business_hours_only
                  ? $t('CASE_TICKETS.SLA.YES')
                  : $t('CASE_TICKETS.SLA.NO')
              }}
            </td>
            <td class="px-4 py-3">
              <span
                class="px-1.5 py-0.5 text-[11px] uppercase rounded"
                :class="
                  p.active
                    ? 'bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-300'
                    : 'bg-slate-100 text-slate-500 dark:bg-slate-700 dark:text-slate-400'
                "
                >{{
                  p.active
                    ? $t('CASE_TICKETS.SLA.YES')
                    : $t('CASE_TICKETS.SLA.NO')
                }}</span
              >
            </td>
            <td class="px-4 py-3 text-right whitespace-nowrap">
              <woot-button
                size="tiny"
                variant="clear"
                color-scheme="secondary"
                icon="edit"
                @click="openEdit(p)"
              />
              <woot-button
                size="tiny"
                variant="clear"
                color-scheme="alert"
                icon="dismiss"
                @click="openDelete(p)"
              />
            </td>
          </tr>
          <tr v-if="!policies.length">
            <td
              colspan="8"
              class="px-4 py-6 text-center text-slate-400 dark:text-slate-500"
            >
              {{ $t('CASE_TICKETS.SLA.EMPTY') }}
            </td>
          </tr>
        </tbody>
      </table>
    </div>

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
                >{{ $t('CASE_TICKETS.SLA.FIRST_RESPONSE') }} (min)</span
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
                >{{ $t('CASE_TICKETS.SLA.RESOLUTION') }} (min)</span
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
