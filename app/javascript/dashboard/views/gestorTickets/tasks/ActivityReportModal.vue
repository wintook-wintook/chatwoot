<!--
  Reportar actividad — algo que ya se hizo, sin tarea detrás (desde el menú del logo).
  Título y qué se hizo obligatorios; cuándo (por omisión ahora), resultado y evidencia
  opcionales. Con contacto u organización sale en su ficha (con la etiqueta
  «Actividad»); con caso, además en la actividad del caso; sin nada es interna.
  Avance de una tarea: al elegir una tarea pendiente (del caso o, sin caso, las rápidas
  del cliente), o al abrirla desde «Reportar avance» del menú de la tarea (prop `task`),
  el reporte queda como avance de esa tarea: no la completa, sale en «Ver reportes» de la
  tarea y en la actividad del caso como reporte (nunca como nota).
-->
<script>
import { format } from 'date-fns';
import { useAlert } from 'dashboard/composables';
import AgendaItemsAPI from 'dashboard/api/agendaItems';
import TaskOutcomesAPI from 'dashboard/api/taskOutcomes';
import TaskReportsAPI from 'dashboard/api/taskReports';
import OrganizationContactFields from 'dashboard/views/organizations/OrganizationContactFields.vue';
import TimeSpentField from './TimeSpentField.vue';

const MAX_FILES = 5;
const T = 'ACTIVITY_REPORT';

export default {
  name: 'ActivityReportModal',
  components: { OrganizationContactFields, TimeSpentField },
  props: {
    show: { type: Boolean, default: false },
    // «Reportar avance» desde una tarea: { id, title, sequence, case_ticket_id, case_folio }.
    task: { type: Object, default: null },
  },
  emits: ['close'],
  data() {
    return {
      title: '',
      content: '',
      date: '',
      time: '',
      outcomeId: '',
      outcomes: [],
      files: [],
      minutes: null,
      minutesRequired: true,
      contact: null,
      organization: null,
      caseId: '',
      cases: [],
      taskId: '',
      tasks: [],
      saving: false,
    };
  },
  computed: {
    hasClient() {
      return !!(this.contact || this.organization);
    },
    // La tarea a la que va el avance: la que vino del menú o la elegida.
    progressTask() {
      if (this.task) return this.task;
      return this.tasks.find(t => t.id === this.taskId) || null;
    },
    progressLabel() {
      const t = this.progressTask;
      if (!t) return '';
      const folio = t.sequence ? `T${String(t.sequence).padStart(3, '0')}` : '';
      return [t.case_folio, folio, t.title].filter(Boolean).join(' · ');
    },
  },
  watch: {
    show(open) {
      if (open) this.reset();
    },
    contact: 'loadCases',
    organization: 'loadCases',
    caseId: 'loadTasks',
    // Al elegir la tarea, el tiempo que falta de lo estimado.
    taskId(id) {
      if (id) this.suggestMinutes(id);
    },
  },
  methods: {
    t(key, params) {
      return this.$t(`${T}.${key}`, params);
    },
    async reset() {
      const now = new Date();
      this.title = '';
      this.content = '';
      this.date = format(now, 'yyyy-MM-dd');
      this.time = format(now, 'HH:mm');
      this.outcomeId = '';
      this.files = [];
      this.minutes = null;
      this.contact = null;
      this.organization = null;
      this.taskId = '';
      this.tasks = [];
      try {
        const { data } = await TaskOutcomesAPI.get();
        this.outcomes = data.task_outcomes.filter(o => o.active);
        this.minutesRequired = data.require_minutes !== false;
      } catch {
        this.outcomes = [];
      }
      if (this.task) this.suggestMinutes(this.task.id);
    },
    // Lo estimado de la tarea menos lo ya reportado en sus avances.
    async suggestMinutes(taskId) {
      try {
        const { data } = await TaskReportsAPI.suggestion({
          type: 'task',
          id: taskId,
        });
        if (data.minutes && !this.minutes) this.minutes = data.minutes;
      } catch {
        // sin sugerencia: se captura a mano
      }
    },
    // Tareas pendientes a las que se les puede reportar avance: las del caso o, sin
    // caso, las rápidas del contacto u organización.
    async loadTasks() {
      this.taskId = '';
      this.tasks = [];
      if (this.task || (!this.caseId && !this.hasClient)) return;
      const params = this.caseId
        ? { case_ticket_id: this.caseId }
        : {
            contact_id: this.contact?.id,
            organization_id:
              this.organization?.id || this.contact?.organization_id,
          };
      try {
        const { data } = await AgendaItemsAPI.tasks(params);
        this.tasks = data.tasks;
      } catch {
        this.tasks = [];
      }
    },
    taskFolio(task) {
      return task.sequence
        ? `T${String(task.sequence).padStart(3, '0')} · `
        : '';
    },
    async loadCases() {
      this.caseId = '';
      this.cases = [];
      this.loadTasks();
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
    onFiles(event) {
      const files = [...this.files, ...event.target.files];
      if (files.length > MAX_FILES) {
        useAlert(this.$t('TASK_REPORT.TOO_MANY', { max: MAX_FILES }));
      }
      this.files = files.slice(0, MAX_FILES);
      event.target.value = '';
    },
    removeFile(index) {
      this.files = this.files.filter((_, i) => i !== index);
    },
    doneAt() {
      if (!this.date) return null;
      return new Date(`${this.date}T${this.time || '00:00'}`).toISOString();
    },
    async submit() {
      if (this.saving) return;
      const progress = this.progressTask;
      const title = progress ? progress.title : this.title.trim();
      const content = this.content.trim();
      if (!title || !content) {
        useAlert(this.t('REQUIRED'));
        return;
      }
      if (this.minutesRequired && !this.minutes) {
        useAlert(this.$t('TASK_REPORT.MINUTES.REQUIRED'));
        return;
      }
      this.saving = true;
      try {
        if (progress) {
          await this.sendProgress(progress, content);
          return;
        }
        await TaskReportsAPI.sendActivity({
          title,
          content,
          doneAt: this.doneAt(),
          outcomeId: this.outcomeId,
          files: this.files,
          minutes: this.minutes,
          caseId: this.caseId,
          contactId: this.contact?.id,
          organizationId: this.organization?.id,
        });
        useAlert(this.t('SUCCESS'));
        this.$emitter.emit('taskReportsChanged');
        this.$emit('close');
      } catch (error) {
        const reason = error?.response?.data?.error;
        useAlert(
          [].concat(reason || []).join(', ') || this.$t('TASK_REPORT.ERROR')
        );
      } finally {
        this.saving = false;
      }
    },
    async sendProgress(task, content) {
      await TaskReportsAPI.sendProgress(task.id, {
        content,
        doneAt: this.doneAt(),
        outcomeId: this.outcomeId,
        files: this.files,
        minutes: this.minutes,
      });
      useAlert(this.t('PROGRESS_SUCCESS'));
      this.$emitter.emit('taskReportsChanged', {
        taskId: task.id,
        caseId: task.case_ticket_id || null,
      });
      this.$emit('close');
    },
  },
};
</script>

<template>
  <woot-modal :show="show" :on-close="() => $emit('close')">
    <woot-modal-header
      :header-title="task ? t('PROGRESS_TITLE') : t('TITLE')"
      :header-content="task ? t('PROGRESS_SUBTITLE') : t('SUBTITLE')"
    />
    <form class="px-6 pb-6 space-y-4" @submit.prevent="submit">
      <p
        v-if="progressTask"
        class="px-3 py-2 m-0 text-sm rounded-md bg-slate-50 dark:bg-slate-800 text-slate-700 dark:text-slate-200"
      >
        <span class="font-medium">{{ t('PROGRESS_OF') }}</span>
        {{ progressLabel }}
        <span class="block text-xs text-slate-500 dark:text-slate-400">
          {{ t('PROGRESS_HINT') }}
        </span>
      </p>
      <woot-input
        v-else
        v-model="title"
        :label="t('NAME')"
        :placeholder="t('NAME_PLACEHOLDER')"
      />
      <label class="block">
        <span class="text-sm font-medium text-slate-700 dark:text-slate-200">
          {{ $t('TASK_REPORT.CONTENT') }}
        </span>
        <textarea
          v-model="content"
          rows="4"
          class="mb-0 resize-y"
          :placeholder="$t('TASK_REPORT.CONTENT_PLACEHOLDER')"
        />
      </label>
      <div class="grid grid-cols-3 gap-3">
        <woot-input v-model="date" type="date" :label="t('DATE')" />
        <woot-input v-model="time" type="time" :label="t('TIME')" />
        <label class="block">
          <span class="text-sm font-medium text-slate-700 dark:text-slate-200">
            {{ $t('TASK_REPORT.OUTCOME') }}
          </span>
          <select v-model="outcomeId" class="mb-0">
            <option value="">{{ $t('TASK_REPORT.NO_OUTCOME') }}</option>
            <option v-for="o in outcomes" :key="o.id" :value="o.id">
              {{ o.label }}
            </option>
          </select>
        </label>
      </div>
      <TimeSpentField v-model="minutes" :required="minutesRequired" />
      <template v-if="!task">
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
          {{ t('INTERNAL_HINT') }}
        </p>
        <label v-if="tasks.length" class="block">
          <span class="text-sm font-medium text-slate-700 dark:text-slate-200">
            {{ t('TASK') }}
          </span>
          <select v-model="taskId" class="mb-0">
            <option value="">{{ t('NO_TASK') }}</option>
            <option v-for="item in tasks" :key="item.id" :value="item.id">
              {{ taskFolio(item) }}{{ item.title }}
            </option>
          </select>
        </label>
      </template>
      <div class="space-y-1">
        <label
          class="block text-sm font-medium text-slate-700 dark:text-slate-200"
        >
          {{ $t('TASK_REPORT.EVIDENCE') }}
          <input
            type="file"
            multiple
            class="block mt-1 text-sm"
            @change="onFiles"
          />
        </label>
        <ul v-if="files.length" class="m-0 list-none">
          <li
            v-for="(file, index) in files"
            :key="file.name + index"
            class="flex items-center justify-between gap-2 text-xs text-slate-600 dark:text-slate-300"
          >
            <span class="truncate">{{ file.name }}</span>
            <button type="button" class="p-0" @click="removeFile(index)">
              <fluent-icon icon="dismiss" size="12" />
            </button>
          </li>
        </ul>
      </div>
      <div class="flex justify-end gap-2 pt-2">
        <woot-button type="button" variant="clear" @click="$emit('close')">
          {{ $t('TASK_REPORT.CANCEL') }}
        </woot-button>
        <woot-button type="submit" :is-loading="saving">
          {{ progressTask ? t('PROGRESS_SUBMIT') : t('SUBMIT') }}
        </woot-button>
      </div>
    </form>
  </woot-modal>
</template>
