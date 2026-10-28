<!--
  Página del contacto › Tareas: tareas y reuniones de sus casos (bandeja de
  tareas filtrada por `contact_id`; el rol ya acota en el servidor).
-->
<script>
import CaseTasksAPI from 'dashboard/api/caseTasks';
import Spinner from 'shared/components/Spinner.vue';

export default {
  name: 'ContactTasksTab',
  components: { Spinner },
  props: {
    contactId: { type: Number, required: true },
  },
  data() {
    return { rows: [], loading: true, showAll: false };
  },
  watch: {
    contactId: 'fetch',
    showAll: 'fetch',
  },
  mounted() {
    this.fetch();
  },
  methods: {
    async fetch() {
      this.loading = true;
      try {
        const { data } = await CaseTasksAPI.getMine({
          contact_id: this.contactId,
          assignee_id: 'all',
          status: this.showAll ? 'all' : '',
          page: 1,
        });
        this.rows = data.case_tasks || [];
      } catch {
        this.rows = [];
      } finally {
        this.loading = false;
      }
    },
    when(row) {
      const at = row.item_type === 'meeting' ? row.starts_at : row.due_at;
      if (!at) return this.$t('CONTACT_PAGE.TASKS.NO_DUE');
      return new Date(at).toLocaleString(undefined, {
        day: '2-digit',
        month: 'short',
        hour: '2-digit',
        minute: '2-digit',
      });
    },
    who(row) {
      const person = row.item_type === 'meeting' ? row.organizer : row.assignee;
      return (person && person.name) || '—';
    },
    isDone(row) {
      return row.item_type === 'task' && row.status === 'done';
    },
    open(row) {
      if (!row.case_ticket) return;
      this.$router.push({
        name: 'gestorTickets_detail',
        params: {
          accountId: this.$route.params.accountId,
          id: row.case_ticket.id,
        },
      });
    },
  },
};
</script>

<template>
  <div class="flex flex-col gap-3">
    <div
      class="flex self-end gap-1 p-0.5 rounded-lg bg-slate-100 dark:bg-slate-800"
    >
      <button
        v-for="option in [false, true]"
        :key="String(option)"
        type="button"
        class="px-3 py-1 text-sm rounded-md"
        :class="
          showAll === option
            ? 'bg-white text-slate-800 shadow-sm dark:bg-slate-700 dark:text-slate-100'
            : 'text-slate-500 dark:text-slate-400'
        "
        @click="showAll = option"
      >
        {{
          option
            ? $t('CONTACT_PAGE.TASKS.ALL')
            : $t('CONTACT_PAGE.TASKS.PENDING')
        }}
      </button>
    </div>
    <Spinner v-if="loading" />
    <p
      v-else-if="!rows.length"
      class="py-8 text-sm text-center text-slate-500 dark:text-slate-400"
    >
      {{ $t('CONTACT_PAGE.TASKS.EMPTY') }}
    </p>
    <ul
      v-else
      class="p-0 m-0 list-none bg-white border divide-y rounded-lg dark:bg-slate-900 border-slate-75 dark:border-slate-700 divide-slate-50 dark:divide-slate-800"
    >
      <li
        v-for="row in rows"
        :key="`${row.item_type}-${row.id}`"
        class="flex items-center gap-3 px-3 py-2 cursor-pointer hover:bg-slate-25 dark:hover:bg-slate-800"
        @click="open(row)"
      >
        <fluent-icon
          :icon="row.item_type === 'meeting' ? 'calendar' : 'checkmark'"
          size="16"
          :class="
            isDone(row)
              ? 'text-green-600 dark:text-green-400'
              : 'text-slate-500 dark:text-slate-400'
          "
        />
        <div class="flex flex-col flex-1 min-w-0">
          <span
            class="text-sm truncate text-slate-800 dark:text-slate-100"
            :class="{ 'line-through text-slate-500': isDone(row) }"
          >
            {{ row.title }}
          </span>
          <span
            v-if="row.case_ticket"
            class="text-xs truncate text-slate-500 dark:text-slate-400"
          >
            {{ row.case_ticket.folio }} · {{ row.case_ticket.title }}
          </span>
        </div>
        <span
          class="text-sm whitespace-nowrap text-slate-600 dark:text-slate-300"
        >
          {{ who(row) }}
        </span>
        <span
          class="text-sm whitespace-nowrap text-slate-600 dark:text-slate-300"
        >
          {{ when(row) }}
        </span>
      </li>
    </ul>
  </div>
</template>
