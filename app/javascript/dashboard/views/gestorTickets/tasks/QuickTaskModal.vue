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
    // Desde el panel del contacto: el contacto ya elegido.
    presetContact: { type: Object, default: null },
  },
  emits: ['close'],
  data() {
    return {
      title: '',
      description: '',
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
      this.description = '';
      this.assigneeId = this.currentUserId;
      this.dueDate = '';
      this.plannedDate = today();
      this.time = '';
      this.isVisit = false;
      this.address = '';
      this.contact = this.presetContact || null;
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
        description: this.description.trim() || undefined,
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
        description: this.description.trim() || undefined,
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
  <woot-modal :show="show" :on-close="() => $emit('close')" size="medium">
    <woot-modal-header :header-title="$t('QUICK_ACTIONS.TASK.TITLE')" />
    <!-- Compacto: campos cortos lado a lado; cabe sin scroll. -->
    <form
      class="quick-task-form flex flex-col gap-2.5 px-6 pb-6"
      @submit.prevent="submit"
    >
      <label class="block">
        <span class="field-label">{{ $t('QUICK_ACTIONS.TASK.NAME') }}</span>
        <input
          v-model="title"
          type="text"
          :placeholder="$t('QUICK_ACTIONS.TASK.NAME_PLACEHOLDER')"
        />
      </label>
      <label class="block">
        <span class="field-label">{{
          $t('QUICK_ACTIONS.TASK.DESCRIPTION')
        }}</span>
        <textarea
          v-model="description"
          rows="2"
          class="mb-0 resize-y"
          :placeholder="$t('QUICK_ACTIONS.TASK.DESCRIPTION_PLACEHOLDER')"
        />
      </label>
      <!-- Responsable · Fecha programada · Hora · Vence (sin hora: vence ese día) -->
      <div class="grid grid-cols-4 gap-3">
        <label class="block">
          <span class="field-label">{{
            $t('QUICK_ACTIONS.TASK.ASSIGNEE')
          }}</span>
          <select v-model="assigneeId">
            <option v-for="agent in agents" :key="agent.id" :value="agent.id">
              {{ agent.name }}
            </option>
          </select>
        </label>
        <label class="block">
          <span class="field-label">{{
            $t('QUICK_ACTIONS.TASK.PLANNED')
          }}</span>
          <input v-model="plannedDate" type="date" />
        </label>
        <label class="block">
          <span class="field-label">{{ $t('QUICK_ACTIONS.TASK.TIME') }}</span>
          <input v-model="time" type="time" />
        </label>
        <label v-if="!time" class="block">
          <span class="field-label">{{ $t('QUICK_ACTIONS.TASK.DUE') }}</span>
          <input v-model="dueDate" type="date" />
        </label>
      </div>
      <p
        v-if="time"
        class="m-0 -mt-1 text-xs text-slate-500 dark:text-slate-400"
      >
        {{ $t('QUICK_ACTIONS.TASK.SCHEDULED_HINT') }}
      </p>
      <!-- Es una visita (y su dirección, en la misma línea) -->
      <div class="flex items-center gap-3">
        <label class="flex items-center flex-shrink-0 gap-2 cursor-pointer">
          <input
            v-model="isVisit"
            type="checkbox"
            class="w-4 h-4 rounded accent-woot-500"
          />
          <span class="text-sm text-slate-700 dark:text-slate-200">
            {{ $t('QUICK_ACTIONS.TASK.IS_VISIT') }}
          </span>
        </label>
        <input
          v-if="isVisit"
          v-model="address"
          type="text"
          class="flex-1"
          :aria-label="$t('QUICK_ACTIONS.TASK.ADDRESS')"
          :placeholder="$t('QUICK_ACTIONS.TASK.ADDRESS_PLACEHOLDER')"
        />
      </div>
      <OrganizationContactFields
        v-model="contact"
        :organization.sync="organization"
        horizontal
      />
      <label v-if="hasClient" class="block">
        <span class="field-label">{{ $t('QUICK_ACTIONS.TASK.CASE') }}</span>
        <select v-model="caseId">
          <option value="">{{ $t('QUICK_ACTIONS.TASK.NO_CASE') }}</option>
          <option v-for="item in cases" :key="item.id" :value="item.id">
            {{ item.folio }} · {{ item.title }}
          </option>
        </select>
      </label>
      <p v-else class="m-0 -mt-1 text-xs text-slate-500 dark:text-slate-400">
        {{ $t('QUICK_ACTIONS.TASK.ONLY_MY_DAY') }}
      </p>
      <div class="flex justify-end gap-2 pt-1">
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

<style lang="scss" scoped>
// Formulario compacto (igual que el de la tarea): etiquetas chicas y campos de 36 px.
.quick-task-form {
  .field-label {
    @apply block mb-1 text-xs font-medium text-slate-600 dark:text-slate-300;
  }

  input[type='text'],
  input[type='date'],
  input[type='time'] {
    @apply h-9 py-1 px-2 mb-0 text-sm;
  }

  // La flecha del select es su fondo: se deja espacio a la derecha para verla.
  select {
    @apply h-9 py-1 pl-2 pr-8 mb-0 text-sm;
  }

  textarea {
    @apply text-sm;
  }

  // Los de fecha y hora no traen estilo base: se les da el borde de los demás.
  input[type='datetime-local'],
  input[type='time'] {
    @apply w-full bg-white border rounded-md border-slate-200 dark:border-slate-600 dark:bg-slate-900 text-slate-800 dark:text-slate-100;
  }

  // Organización y contacto (componente compartido): mismo tamaño que los demás.
  ::v-deep span[class~='font-medium'] {
    font-size: 0.75rem;
    line-height: 1rem;
  }

  ::v-deep input[type='text'],
  ::v-deep input:not([type]) {
    @apply h-9 py-1 px-2 mb-0 text-sm;
  }
}
</style>
