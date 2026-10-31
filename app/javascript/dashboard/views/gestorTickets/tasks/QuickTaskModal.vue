<!--
  Plan-Agenda — captura rápida de una tarea, desde cualquier pantalla.
  Sin hora: tarea con vencimiento y fecha programada; solo en Kontrolya.
  Con hora: tarea agendada en la fecha programada; esa sí va a Google.
  El caso es opcional: se elige entre los del contacto u organización.
-->
<script>
import { mapGetters } from 'vuex';
import { format } from 'date-fns';
import { useAlert } from 'dashboard/composables';
import AgendaItemsAPI from 'dashboard/api/agendaItems';
import CaseTasksAPI from 'dashboard/api/caseTasks';
import QuickTasksAPI from 'dashboard/api/quickTasks';
import OrganizationContactFields from 'dashboard/views/organizations/OrganizationContactFields.vue';

const HOUR = 60 * 60 * 1000;
const today = () => format(new Date(), 'yyyy-MM-dd');
const endOfDayIso = date => new Date(`${date}T23:59:59`).toISOString();

export default {
  name: 'QuickTaskModal',
  components: { OrganizationContactFields },
  props: {
    show: { type: Boolean, default: false },
  },
  emits: ['close'],
  data() {
    return {
      title: '',
      assigneeId: null,
      dueDate: '',
      plannedDate: '',
      time: '',
      isVisit: false,
      address: '',
      contact: null,
      organization: null,
      caseId: '',
      cases: [],
      saving: false,
    };
  },
  computed: {
    ...mapGetters({
      agents: 'agents/getAgents',
      currentUserId: 'getCurrentUserID',
    }),
    hasClient() {
      return !!(this.contact || this.organization);
    },
  },
  watch: {
    show(open) {
      if (open) this.reset();
    },
    contact: 'loadCases',
    organization: 'loadCases',
  },
  methods: {
    reset() {
      this.title = '';
      this.assigneeId = this.currentUserId;
      this.dueDate = '';
      this.plannedDate = today();
      this.time = '';
      this.isVisit = false;
      this.address = '';
      this.contact = null;
      this.organization = null;
      this.$store.dispatch('agents/get');
    },
    async loadCases() {
      this.caseId = '';
      this.cases = [];
      if (!this.hasClient) return;
      try {
        const { data } = await AgendaItemsAPI.cases({
          contact_id: this.contact?.id,
          organization_id:
            this.organization?.id || this.contact?.organization_id,
        });
        this.cases = data.cases;
      } catch {
        this.cases = [];
      }
    },
    clientFields() {
      return {
        assignee_id: this.assigneeId,
        contact_id: this.contact?.id,
        organization_id: this.organization?.id,
      };
    },
    taskFields() {
      return {
        title: this.title.trim(),
        assignee_id: this.assigneeId,
        due_at: this.dueDate ? endOfDayIso(this.dueDate) : null,
        planned_on: this.plannedDate || null,
      };
    },
    createScheduled() {
      const starts = new Date(`${this.plannedDate}T${this.time}`);
      return AgendaItemsAPI.create({
        ...this.clientFields(),
        title: this.title.trim(),
        starts_at: starts.toISOString(),
        ends_at: new Date(starts.getTime() + HOUR).toISOString(),
        is_visit: this.isVisit,
        location: this.address.trim() || undefined,
        case_ticket_id: this.caseId || undefined,
      });
    },
    create() {
      if (this.time) return this.createScheduled();
      if (this.caseId) {
        return CaseTasksAPI.createTask(this.caseId, this.taskFields());
      }
      return QuickTasksAPI.create({
        ...this.taskFields(),
        ...this.clientFields(),
      });
    },
    async submit() {
      if (this.saving) return;
      if (!this.title.trim()) {
        useAlert(this.$t('QUICK_ACTIONS.TASK.TITLE_REQUIRED'));
        return;
      }
      if (this.isVisit && !this.time) {
        useAlert(this.$t('QUICK_ACTIONS.TASK.VISIT_TIME_REQUIRED'));
        return;
      }
      if (this.time && !this.plannedDate) {
        useAlert(this.$t('QUICK_ACTIONS.TASK.DATE_REQUIRED'));
        return;
      }
      this.saving = true;
      try {
        await this.create();
        useAlert(this.$t('QUICK_ACTIONS.TASK.SUCCESS'));
        this.$emitter.emit('agendaChanged');
        this.$emit('close');
      } catch (error) {
        const reason = error?.response?.data?.error;
        useAlert(
          [].concat(reason || []).join(', ') ||
            this.$t('QUICK_ACTIONS.TASK.ERROR')
        );
      } finally {
        this.saving = false;
      }
    },
  },
};
</script>

<template>
  <woot-modal :show="show" :on-close="() => $emit('close')">
    <woot-modal-header :header-title="$t('QUICK_ACTIONS.TASK.TITLE')" />
    <form class="px-6 pb-6 space-y-4" @submit.prevent="submit">
      <woot-input
        v-model="title"
        :label="$t('QUICK_ACTIONS.TASK.NAME')"
        :placeholder="$t('QUICK_ACTIONS.TASK.NAME_PLACEHOLDER')"
      />
      <label class="block">
        <span class="text-sm font-medium text-slate-700 dark:text-slate-200">
          {{ $t('QUICK_ACTIONS.TASK.ASSIGNEE') }}
        </span>
        <select v-model="assigneeId" class="mb-0">
          <option v-for="agent in agents" :key="agent.id" :value="agent.id">
            {{ agent.name }}
          </option>
        </select>
      </label>
      <div class="grid grid-cols-3 gap-3">
        <woot-input
          v-model="plannedDate"
          type="date"
          :label="$t('QUICK_ACTIONS.TASK.PLANNED')"
        />
        <woot-input
          v-model="time"
          type="time"
          :label="$t('QUICK_ACTIONS.TASK.TIME')"
        />
        <woot-input
          v-if="!time"
          v-model="dueDate"
          type="date"
          :label="$t('QUICK_ACTIONS.TASK.DUE')"
        />
      </div>
      <p v-if="time" class="m-0 text-xs text-slate-500 dark:text-slate-400">
        {{ $t('QUICK_ACTIONS.TASK.SCHEDULED_HINT') }}
      </p>
      <label class="flex items-center gap-2 cursor-pointer w-fit">
        <input
          v-model="isVisit"
          type="checkbox"
          class="w-4 h-4 rounded accent-woot-500"
        />
        <span class="text-sm text-slate-700 dark:text-slate-200">
          {{ $t('QUICK_ACTIONS.TASK.IS_VISIT') }}
        </span>
      </label>
      <woot-input
        v-if="isVisit"
        v-model="address"
        :label="$t('QUICK_ACTIONS.TASK.ADDRESS')"
        :placeholder="$t('QUICK_ACTIONS.TASK.ADDRESS_PLACEHOLDER')"
      />
      <OrganizationContactFields
        v-model="contact"
        :organization.sync="organization"
      />
      <label v-if="hasClient" class="block">
        <span class="text-sm font-medium text-slate-700 dark:text-slate-200">
          {{ $t('QUICK_ACTIONS.TASK.CASE') }}
        </span>
        <select v-model="caseId" class="mb-0">
          <option value="">{{ $t('QUICK_ACTIONS.TASK.NO_CASE') }}</option>
          <option v-for="item in cases" :key="item.id" :value="item.id">
            {{ item.folio }} · {{ item.title }}
          </option>
        </select>
      </label>
      <p v-else class="m-0 text-xs text-slate-500 dark:text-slate-400">
        {{ $t('QUICK_ACTIONS.TASK.ONLY_MY_DAY') }}
      </p>
      <div class="flex justify-end gap-2 pt-2">
        <woot-button type="button" variant="clear" @click="$emit('close')">
          {{ $t('QUICK_ACTIONS.TASK.CANCEL') }}
        </woot-button>
        <woot-button type="submit" :is-loading="saving">
          {{ $t('QUICK_ACTIONS.TASK.SUBMIT') }}
        </woot-button>
      </div>
    </form>
  </woot-modal>
</template>
