<!--
  Agenda › Tareas que se repiten. Las que tengo (las que programé o me tocan) o, con
  Agenda en «Todo», las de todo el equipo: cada cuánto, la próxima, cómo va (a tiempo,
  tarde, no hechas) y pausar, reanudar, editar o terminar.
-->
<script>
import { useAlert } from 'dashboard/composables';
import TaskRecurrencesAPI from 'dashboard/api/taskRecurrences';
import { describeRecurrence } from 'dashboard/components/recurrence/recurrence';
import QuickTaskModal from '../tasks/QuickTaskModal.vue';
import RecurrenceEditModal from './RecurrenceEditModal.vue';

export default {
  name: 'RecurringTasks',
  components: { QuickTaskModal, RecurrenceEditModal },
  data() {
    return {
      rows: [],
      scope: 'mine',
      seeAll: false,
      loading: false,
      creating: false,
      editing: null,
      busyId: null,
    };
  },
  mounted() {
    this.fetch();
    this.$store.dispatch('agents/get');
    this.$emitter.on('agendaChanged', this.fetch);
  },
  beforeDestroy() {
    this.$emitter.off('agendaChanged', this.fetch);
  },
  methods: {
    async fetch() {
      this.loading = true;
      try {
        const { data } = await TaskRecurrencesAPI.list({ scope: this.scope });
        this.rows = data.task_recurrences;
        this.seeAll = data.see_all;
      } catch {
        useAlert(this.$t('RECURRING_TASKS.ERROR'));
      } finally {
        this.loading = false;
      }
    },
    setScope(scope) {
      this.scope = scope;
      this.fetch();
    },
    describe(row) {
      return describeRecurrence(row, this);
    },
    client(row) {
      const parts = [
        row.case_ticket && row.case_ticket.folio,
        (row.contact || row.organization || {}).name,
      ];
      return parts.filter(Boolean).join(' · ');
    },
    dateLabel(date) {
      return new Date(`${date}T00:00`).toLocaleDateString(undefined, {
        weekday: 'short',
        day: 'numeric',
        month: 'short',
      });
    },
    async setStatus(row, status) {
      this.busyId = row.id;
      try {
        await TaskRecurrencesAPI.updateRecurrence(row.id, { status });
        this.fetch();
      } catch {
        useAlert(this.$t('RECURRING_TASKS.ERROR'));
      } finally {
        this.busyId = null;
      }
    },
    async end(row) {
      // eslint-disable-next-line no-alert
      const ok = window.confirm(
        this.$t('RECURRING_TASKS.END_CONFIRM', { title: row.title })
      );
      if (!ok) return;
      this.busyId = row.id;
      try {
        await TaskRecurrencesAPI.end(row.id);
        this.fetch();
      } catch {
        useAlert(this.$t('RECURRING_TASKS.ERROR'));
      } finally {
        this.busyId = null;
      }
    },
    onSaved() {
      this.editing = null;
      this.fetch();
    },
  },
};
</script>

<template>
  <div
    class="flex flex-col flex-1 w-full h-full overflow-hidden bg-slate-25 dark:bg-slate-900"
  >
    <div
      class="flex flex-col flex-shrink-0 gap-2 px-6 py-4 bg-white border-b dark:bg-slate-900 border-slate-50 dark:border-slate-800/50"
    >
      <div class="flex flex-wrap items-center justify-between gap-3">
        <h1 class="m-0 text-xl font-bold text-slate-800 dark:text-slate-100">
          {{ $t('RECURRING_TASKS.TITLE') }}
        </h1>
        <woot-button size="small" icon="add" @click="creating = true">
          {{ $t('RECURRING_TASKS.NEW') }}
        </woot-button>
      </div>
      <p class="max-w-3xl m-0 text-sm text-slate-500 dark:text-slate-400">
        {{ $t('RECURRING_TASKS.SUBTITLE') }}
      </p>
      <div v-if="seeAll" class="flex gap-1">
        <woot-button
          v-for="key in ['mine', 'all']"
          :key="key"
          size="small"
          :variant="scope === key ? 'smooth' : 'clear'"
          color-scheme="secondary"
          @click="setScope(key)"
        >
          {{ $t(`RECURRING_TASKS.${key.toUpperCase()}`) }}
        </woot-button>
      </div>
    </div>

    <div class="flex-1 px-6 py-4 overflow-auto">
      <p
        v-if="!loading && !rows.length"
        class="m-0 text-sm text-slate-500 dark:text-slate-400"
      >
        {{ $t('RECURRING_TASKS.EMPTY') }}
      </p>
      <table
        v-else
        class="w-full text-sm bg-white border rounded-lg dark:bg-slate-800 border-slate-100 dark:border-slate-700"
      >
        <thead>
          <tr class="text-xs text-left text-slate-500 dark:text-slate-400">
            <th class="px-3 py-2">{{ $t('RECURRING_TASKS.COL_TASK') }}</th>
            <th class="px-3 py-2">{{ $t('RECURRING_TASKS.COL_ASSIGNEE') }}</th>
            <th class="px-3 py-2">{{ $t('RECURRING_TASKS.COL_REPEATS') }}</th>
            <th class="px-3 py-2">{{ $t('RECURRING_TASKS.COL_NEXT') }}</th>
            <th class="px-3 py-2">{{ $t('RECURRING_TASKS.COL_RESULTS') }}</th>
            <th class="px-3 py-2" />
          </tr>
        </thead>
        <tbody>
          <tr
            v-for="row in rows"
            :key="row.id"
            class="align-top border-t border-slate-100 dark:border-slate-700"
            :class="{ 'opacity-60': row.status === 'paused' }"
          >
            <td class="px-3 py-2">
              <span
                class="block font-medium text-slate-800 dark:text-slate-100"
              >
                {{ row.title }}
              </span>
              <span
                v-if="client(row)"
                class="block text-xs text-slate-500 dark:text-slate-400"
              >
                {{ client(row) }}
              </span>
              <span
                v-if="
                  row.user && row.assignee && row.user.id !== row.assignee.id
                "
                class="block text-xs text-slate-400"
              >
                {{
                  $t('RECURRING_TASKS.PROGRAMMED_BY', { name: row.user.name })
                }}
              </span>
            </td>
            <td class="px-3 py-2 text-slate-700 dark:text-slate-200">
              {{ row.assignee ? row.assignee.name : '—' }}
            </td>
            <td class="px-3 py-2 text-slate-700 dark:text-slate-200">
              {{ describe(row) }}
            </td>
            <td class="px-3 py-2 text-slate-700 dark:text-slate-200">
              <template v-if="row.status === 'paused'">
                {{ $t('RECURRING_TASKS.STATUS_PAUSED') }}
              </template>
              <template v-else-if="row.next_on">
                {{ dateLabel(row.next_on) }}
              </template>
              <span v-else class="text-xs text-slate-500">
                {{ $t('RECURRING_TASKS.NEXT_WAITING') }}
              </span>
            </td>
            <td class="px-3 py-2 text-xs">
              <span class="text-green-700 dark:text-green-400">
                {{ row.stats.on_time }} {{ $t('RECURRING_TASKS.ON_TIME') }}
              </span>
              ·
              <span class="text-amber-700 dark:text-amber-400">
                {{ row.stats.late }} {{ $t('RECURRING_TASKS.LATE') }}
              </span>
              ·
              <span class="text-red-700 dark:text-red-400">
                {{ row.stats.missed }} {{ $t('RECURRING_TASKS.MISSED') }}
              </span>
              <span
                v-if="row.stats.pending"
                class="block text-slate-500 dark:text-slate-400"
              >
                {{ row.stats.pending }} {{ $t('RECURRING_TASKS.PENDING') }}
              </span>
            </td>
            <td class="px-3 py-2 whitespace-nowrap">
              <woot-button
                size="tiny"
                variant="clear"
                color-scheme="secondary"
                @click="editing = row"
              >
                {{ $t('RECURRING_TASKS.EDIT') }}
              </woot-button>
              <woot-button
                size="tiny"
                variant="clear"
                color-scheme="secondary"
                :is-loading="busyId === row.id"
                @click="
                  setStatus(row, row.status === 'paused' ? 'active' : 'paused')
                "
              >
                {{
                  row.status === 'paused'
                    ? $t('RECURRING_TASKS.RESUME')
                    : $t('RECURRING_TASKS.PAUSE')
                }}
              </woot-button>
              <woot-button
                size="tiny"
                variant="clear"
                color-scheme="alert"
                @click="end(row)"
              >
                {{ $t('RECURRING_TASKS.END') }}
              </woot-button>
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <QuickTaskModal
      :show="creating"
      preset-repeat
      @close="
        creating = false;
        fetch();
      "
    />
    <RecurrenceEditModal
      :recurrence="editing"
      @close="editing = null"
      @saved="onSaved"
    />
  </div>
</template>
