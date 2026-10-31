<!--
  Reporte de cierre — al concluir una tarea o tarea agendada: qué se hizo (obligatorio),
  resultado del catálogo y evidencia opcional.
  item = { type: 'task' | 'meeting', id, title }
-->
<script>
import { useAlert } from 'dashboard/composables';
import TaskOutcomesAPI from 'dashboard/api/taskOutcomes';
import TaskReportsAPI from 'dashboard/api/taskReports';

const MAX_FILES = 5;

export default {
  name: 'TaskReportModal',
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
      saving: false,
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
      try {
        const { data } = await TaskOutcomesAPI.get();
        this.outcomes = data.task_outcomes.filter(o => o.active);
      } catch {
        this.outcomes = [];
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
    async submit() {
      const content = this.content.trim();
      if (this.saving) return;
      if (!content) {
        useAlert(this.$t('TASK_REPORT.REQUIRED'));
        return;
      }
      this.saving = true;
      try {
        await TaskReportsAPI.send(this.item, {
          content,
          outcomeId: this.outcomeId,
          files: this.files,
        });
        this.$emit('reported');
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
