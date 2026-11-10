<!--
  Reporte de cierre — al concluir una tarea o tarea agendada: qué se hizo (obligatorio),
  resultado del catálogo y evidencia opcional.
  item = { type: 'task' | 'meeting', id, title }. Con `ids`, un mismo reporte para varias
  (el tiempo dedicado se reparte entre ellas). El tiempo viene propuesto por el servidor.
-->
<script>
import { useAlert } from 'dashboard/composables';
import TaskOutcomesAPI from 'dashboard/api/taskOutcomes';
import TaskReportsAPI from 'dashboard/api/taskReports';
import TimeSpentField from './TimeSpentField.vue';

const MAX_FILES = 5;

export default {
  name: 'TaskReportModal',
  components: { TimeSpentField },
  props: {
    item: { type: Object, default: null },
  },
  emits: ['close', 'reported'],
  data() {
    return {
      content: '',
      outcomeId: '',
      files: [],
      outcomes: [],
      minutes: null,
      minutesRequired: true,
      saving: false,
      // Cita (item.askAttendance): ¿se realizó o el cliente no asistió?
      attendance: 'held',
    };
  },
  watch: {
    item(item) {
      if (item) this.reset();
    },
  },
  methods: {
    async reset() {
      this.content = '';
      this.outcomeId = '';
      this.files = [];
      this.minutes = null;
      this.attendance = 'held';
      this.loadSuggestion();
      try {
        const { data } = await TaskOutcomesAPI.get();
        this.outcomes = data.task_outcomes.filter(o => o.active);
      } catch {
        this.outcomes = [];
      }
    },
    async loadSuggestion() {
      const { type, id, ids } = this.item;
      try {
        const { data } = await TaskReportsAPI.suggestion({
          type,
          id: id || (ids && ids[0]),
        });
        this.minutesRequired = data.required;
        // Para varias a la vez se captura el total, no lo de una.
        if (!ids && this.minutes === null) this.minutes = data.minutes || null;
      } catch {
        this.minutesRequired = true;
      }
    },
    // El total se reparte entre las tareas reportadas juntas.
    minutesEach(count) {
      if (!this.minutes) return null;
      return Math.max(1, Math.round(this.minutes / count));
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
    async submit() {
      const content = this.content.trim();
      if (this.saving) return;
      if (!content) {
        useAlert(this.$t('TASK_REPORT.REQUIRED'));
        return;
      }
      if (this.minutesRequired && !this.minutes) {
        useAlert(this.$t('TASK_REPORT.MINUTES.REQUIRED'));
        return;
      }
      this.saving = true;
      try {
        const { type, id, ids } = this.item;
        const report = {
          content,
          outcomeId: this.outcomeId,
          files: this.files,
          minutes: this.minutesEach((ids || [id]).length),
        };
        await Promise.all(
          (ids || [id]).map(itemId =>
            TaskReportsAPI.send({ type, id: itemId }, report)
          )
        );
        this.$emit('reported', { status: this.attendance });
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
  <woot-modal :show="!!item" :on-close="() => $emit('close')">
    <woot-modal-header
      :header-title="$t('TASK_REPORT.TITLE')"
      :header-content="item ? item.title : ''"
    />
    <form class="px-6 pb-6 space-y-4" @submit.prevent="submit">
      <!-- Cita: cómo terminó. «No asistió» también lleva reporte (qué pasó y el tiempo). -->
      <fieldset v-if="item && item.askAttendance" class="p-0 m-0 border-0">
        <legend
          class="mb-1 text-sm font-medium text-slate-700 dark:text-slate-200"
        >
          {{ $t('TASK_REPORT.ATTENDANCE.TITLE') }}
        </legend>
        <div class="flex gap-4 text-sm">
          <label class="flex items-center gap-2">
            <input
              v-model="attendance"
              type="radio"
              value="held"
              class="!m-0"
            />
            {{ $t('TASK_REPORT.ATTENDANCE.HELD') }}
          </label>
          <label class="flex items-center gap-2">
            <input
              v-model="attendance"
              type="radio"
              value="no_show"
              class="!m-0"
            />
            {{ $t('TASK_REPORT.ATTENDANCE.NO_SHOW') }}
          </label>
        </div>
      </fieldset>
      <label class="block">
        <span class="text-sm font-medium text-slate-700 dark:text-slate-200">
          {{ $t('TASK_REPORT.CONTENT') }}
        </span>
        <textarea
          v-model="content"
          rows="4"
          class="mb-0"
          :placeholder="$t('TASK_REPORT.CONTENT_PLACEHOLDER')"
        />
      </label>
      <TimeSpentField v-model="minutes" :required="minutesRequired" />
      <p
        v-if="item && item.ids && item.ids.length > 1"
        class="m-0 -mt-2 text-xs text-slate-500 dark:text-slate-400"
      >
        {{ $t('TASK_REPORT.MINUTES.SPLIT', { count: item.ids.length }) }}
      </p>
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
          {{ $t('TASK_REPORT.SUBMIT') }}
        </woot-button>
      </div>
    </form>
  </woot-modal>
</template>
