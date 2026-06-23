<!--
  @tickets_cases — Tareas / subtareas del ticket (osTicket "Tasks").
  Checklist con estado, asignado y vencimiento. Autónomo (usa caseTasks API).
-->
<script>
import { mapGetters } from 'vuex';
import CaseTasksAPI from 'dashboard/api/caseTasks';

export default {
  name: 'TicketTasks',
  props: {
    ticketId: { type: [Number, String], required: true },
  },
  data() {
    return {
      tasks: [],
      newTitle: '',
      isLoading: false,
      isSaving: false,
    };
  },
  computed: {
    ...mapGetters({ agents: 'agents/getAgents' }),
    doneCount() {
      return this.tasks.filter(t => t.status === 'done').length;
    },
  },
  watch: {
    ticketId() {
      this.load();
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
    async addTask() {
      const title = this.newTitle.trim();
      if (!title || this.isSaving) return;
      this.isSaving = true;
      try {
        const { data } = await CaseTasksAPI.createTask(this.ticketId, { title });
        this.tasks.push(data.case_task);
        this.newTitle = '';
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
    async setAssignee(task, assigneeId) {
      const { data } = await CaseTasksAPI.updateTask(this.ticketId, task.id, {
        assignee_id: assigneeId || '',
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
  },
};
</script>

<template>
  <div
    class="p-4 bg-white border rounded-lg dark:bg-slate-800 border-slate-75 dark:border-slate-700"
  >
    <div class="flex items-center justify-between mb-3">
      <h3 class="m-0 text-base font-semibold text-slate-800 dark:text-slate-100">
        {{ $t('CASE_TICKETS.TASKS.TITLE') }}
        <span
          v-if="tasks.length"
          class="ml-1 text-sm font-normal text-slate-400 dark:text-slate-500"
          >{{ doneCount }}/{{ tasks.length }}</span
        >
      </h3>
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

    <ul v-else class="flex flex-col gap-2 mb-3">
      <li
        v-for="task in tasks"
        :key="task.id"
        class="flex items-center gap-2 p-2 rounded-lg bg-slate-25 dark:bg-slate-900/40"
      >
        <input
          type="checkbox"
          :checked="task.status === 'done'"
          @change="toggle(task)"
        />
        <span
          class="flex-1 text-sm"
          :class="
            task.status === 'done'
              ? 'line-through text-slate-400 dark:text-slate-500'
              : 'text-slate-800 dark:text-slate-100'
          "
          >{{ task.title }}</span
        >
        <select
          class="text-xs !mb-0 w-36"
          :value="task.assignee_id || ''"
          @change="setAssignee(task, $event.target.value)"
        >
          <option value="">{{ $t('CASE_TICKETS.TASKS.UNASSIGNED') }}</option>
          <option v-for="a in agents" :key="a.id" :value="a.id">
            {{ a.name }}
          </option>
        </select>
        <woot-button
          size="tiny"
          variant="clear"
          color-scheme="alert"
          icon="delete"
          @click="remove(task)"
        />
      </li>
    </ul>

    <form class="flex items-center gap-2" @submit.prevent="addTask">
      <input
        v-model="newTitle"
        type="text"
        class="flex-1 !mb-0"
        :placeholder="$t('CASE_TICKETS.TASKS.ADD_PLACEHOLDER')"
        maxlength="255"
      />
      <woot-button
        size="small"
        icon="add"
        :is-loading="isSaving"
        :disabled="!newTitle.trim()"
      >
        {{ $t('CASE_TICKETS.TASKS.ADD') }}
      </woot-button>
    </form>
  </div>
</template>
