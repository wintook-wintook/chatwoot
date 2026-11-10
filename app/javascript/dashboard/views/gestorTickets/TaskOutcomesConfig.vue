<!-- Catálogos › Resultados de tareas: la lista del reporte de cierre, si se exige
     el tiempo dedicado (encendido de inicio) y los motivos para cancelar una tarea o
     tarea agendada («Otro» pide comentario). -->
<script>
import { useAlert } from 'dashboard/composables';
import TaskOutcomesAPI from 'dashboard/api/taskOutcomes';

export default {
  name: 'TaskOutcomesConfig',
  data() {
    return {
      outcomes: [],
      newLabel: '',
      requireMinutes: true,
      reasons: [],
      newReason: '',
    };
  },
  mounted() {
    this.fetch();
  },
  methods: {
    async fetch() {
      const { data } = await TaskOutcomesAPI.get();
      this.outcomes = data.task_outcomes;
      this.requireMinutes = data.require_minutes !== false;
      const cancel = await TaskOutcomesAPI.list('cancel');
      this.reasons = cancel.data.task_outcomes;
    },
    async run(action) {
      try {
        await action();
        await this.fetch();
      } catch {
        useAlert(this.$t('TASK_REPORT.CATALOG.ERROR'));
      }
    },
    add() {
      const label = this.newLabel.trim();
      if (!label) return;
      this.run(async () => {
        await TaskOutcomesAPI.create({ task_outcome: { label } });
        this.newLabel = '';
      });
    },
    save(outcome, changes) {
      this.run(() =>
        TaskOutcomesAPI.update(outcome.id, { task_outcome: changes })
      );
    },
    addReason() {
      const label = this.newReason.trim();
      if (!label) return;
      this.run(async () => {
        await TaskOutcomesAPI.createFor('cancel', { task_outcome: { label } });
        this.newReason = '';
      });
    },
    saveRequireMinutes(value) {
      this.run(() => TaskOutcomesAPI.updateSettings({ requireMinutes: value }));
    },
    remove(outcome) {
      this.run(() => TaskOutcomesAPI.delete(outcome.id));
    },
  },
};
</script>

<template>
  <div
    class="flex flex-col flex-1 w-full h-full overflow-hidden bg-slate-25 dark:bg-slate-900"
  >
    <div
      class="flex items-center flex-shrink-0 px-6 py-4 bg-white border-b dark:bg-slate-900 border-slate-50 dark:border-slate-800/50"
    >
      <h1 class="m-0 text-xl font-bold text-slate-800 dark:text-slate-100">
        {{ $t('TASK_REPORT.CATALOG.TITLE') }}
      </h1>
    </div>
    <div class="flex flex-col flex-1 max-w-xl gap-2 px-6 py-4 overflow-y-auto">
      <label
        class="flex items-start gap-2 p-3 mb-2 bg-white border rounded-lg cursor-pointer border-slate-100 dark:bg-slate-800 dark:border-slate-700"
      >
        <input
          type="checkbox"
          class="!mb-0 mt-0.5"
          :checked="requireMinutes"
          @change="saveRequireMinutes($event.target.checked)"
        />
        <span class="flex flex-col">
          <span class="text-sm font-medium text-slate-800 dark:text-slate-100">
            {{ $t('TASK_REPORT.MINUTES.REQUIRE_SETTING') }}
          </span>
          <span class="text-xs text-slate-500 dark:text-slate-400">
            {{ $t('TASK_REPORT.MINUTES.REQUIRE_SETTING_HINT') }}
          </span>
        </span>
      </label>
      <div
        v-for="outcome in outcomes"
        :key="outcome.id"
        class="flex items-center gap-2"
      >
        <input
          class="!mb-0 flex-1 text-sm"
          :value="outcome.label"
          @change="save(outcome, { label: $event.target.value })"
        />
        <label
          class="flex items-center gap-1 m-0 text-xs text-slate-600 dark:text-slate-300"
        >
          <input
            type="checkbox"
            class="!mb-0"
            :checked="outcome.active"
            @change="save(outcome, { active: $event.target.checked })"
          />
          {{ $t('TASK_REPORT.CATALOG.ACTIVE') }}
        </label>
        <woot-button
          size="small"
          variant="clear"
          color-scheme="alert"
          icon="delete"
          :title="$t('TASK_REPORT.CATALOG.DELETE')"
          @click="remove(outcome)"
        />
      </div>
      <form class="flex items-center gap-2 mt-2" @submit.prevent="add">
        <input
          v-model="newLabel"
          class="!mb-0 flex-1 text-sm"
          :placeholder="$t('TASK_REPORT.CATALOG.PLACEHOLDER')"
        />
        <woot-button size="small" type="submit">
          {{ $t('TASK_REPORT.CATALOG.ADD') }}
        </woot-button>
      </form>

      <!-- Motivos de cancelación -->
      <h2
        class="m-0 mt-6 text-base font-semibold text-slate-800 dark:text-slate-100"
      >
        {{ $t('CANCEL_ITEM.CATALOG.TITLE') }}
      </h2>
      <p class="m-0 text-xs text-slate-500 dark:text-slate-400">
        {{ $t('CANCEL_ITEM.CATALOG.HELP') }}
      </p>
      <div
        v-for="reason in reasons"
        :key="reason.id"
        class="flex items-center gap-2"
      >
        <input
          class="!mb-0 flex-1 text-sm"
          :value="reason.label"
          @change="save(reason, { label: $event.target.value })"
        />
        <label
          class="flex items-center gap-1 m-0 text-xs text-slate-600 dark:text-slate-300"
        >
          <input
            type="checkbox"
            class="!mb-0"
            :checked="reason.active"
            @change="save(reason, { active: $event.target.checked })"
          />
          {{ $t('TASK_REPORT.CATALOG.ACTIVE') }}
        </label>
        <woot-button
          size="small"
          variant="clear"
          color-scheme="alert"
          icon="delete"
          :title="$t('TASK_REPORT.CATALOG.DELETE')"
          @click="remove(reason)"
        />
      </div>
      <form class="flex items-center gap-2 mt-2" @submit.prevent="addReason">
        <input
          v-model="newReason"
          class="!mb-0 flex-1 text-sm"
          :placeholder="$t('CANCEL_ITEM.CATALOG.PLACEHOLDER')"
        />
        <woot-button size="small" type="submit">
          {{ $t('TASK_REPORT.CATALOG.ADD') }}
        </woot-button>
      </form>
    </div>
  </div>
</template>
