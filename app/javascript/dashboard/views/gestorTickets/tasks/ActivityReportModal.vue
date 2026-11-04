<!--
  Reportar actividad — algo que ya se hizo, sin tarea detrás (desde el menú del logo).
  Título y qué se hizo obligatorios; cuándo (por omisión ahora), resultado y evidencia
  opcionales. Con contacto u organización sale en su ficha (con la etiqueta
  «Actividad»); con caso, además en la actividad del caso; sin nada es interna.
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
      saving: false,
    };
  },
  computed: {
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
      try {
        const { data } = await TaskOutcomesAPI.get();
        this.outcomes = data.task_outcomes.filter(o => o.active);
        this.minutesRequired = data.require_minutes !== false;
      } catch {
        this.outcomes = [];
      }
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
      const title = this.title.trim();
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
  },
};
</script>

<template>
  <woot-modal :show="show" :on-close="() => $emit('close')">
    <woot-modal-header
      :header-title="t('TITLE')"
      :header-content="t('SUBTITLE')"
    />
    <form class="px-6 pb-6 space-y-4" @submit.prevent="submit">
      <woot-input
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
          {{ t('SUBMIT') }}
        </woot-button>
      </div>
    </form>
  </woot-modal>
</template>
