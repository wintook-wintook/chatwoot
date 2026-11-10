<!--
  Al cerrar o cancelar un caso: qué pasa con sus tareas pendientes (una sola decisión para
  todas) y con sus tareas agendadas a futuro. `ask(ticketId, status)` resuelve con
  { pending_tasks, cancel_meetings }; {} si no hay nada; null si el usuario se regresa.
  Concluir escribe un reporte para todas y las concluye; las que no se puedan concluir a
  mano (las de «Documenta…») se quedan para que el cierre las cancele.
-->
<script>
import { useAlert } from 'dashboard/composables';
import CaseTasksAPI from 'dashboard/api/caseTasks';
import CaseMeetingsAPI from 'dashboard/api/caseMeetings';
import TaskReportModal from './TaskReportModal.vue';

const DECISIONS = ['cancel', 'keep', 'conclude'];

export default {
  name: 'CaseTasksOnCloseModal',
  components: { TaskReportModal },
  data() {
    return {
      show: false,
      ticketId: null,
      tasks: [],
      meetings: [],
      cancelMeetings: true,
      decision: 'cancel',
      reportItem: null,
      resolve: null,
      decisions: DECISIONS,
    };
  },
  methods: {
    async pendingTasks(ticketId) {
      const { data } = await CaseTasksAPI.getAll(ticketId);
      return data.case_tasks.filter(task => task.status === 'pending');
    },
    async upcomingMeetings(ticketId, status) {
      const { data } = await CaseMeetingsAPI.upcoming(ticketId, {
        target_status: status,
      });
      this.cancelMeetings = !!data.cancel_default;
      return data.case_meetings || [];
    },
    async ask(ticketId, status) {
      this.ticketId = ticketId;
      try {
        [this.tasks, this.meetings] = await Promise.all([
          this.pendingTasks(ticketId),
          this.upcomingMeetings(ticketId, status),
        ]);
      } catch {
        this.tasks = [];
        this.meetings = [];
      }
      if (!this.tasks.length && !this.meetings.length) return {};
      this.decision = 'cancel';
      this.show = true;
      return new Promise(resolve => {
        this.resolve = resolve;
      });
    },
    finish(result) {
      this.show = false;
      this.reportItem = null;
      if (this.resolve) this.resolve(result);
      this.resolve = null;
    },
    answer(pendingTasks) {
      const meetings = this.meetings.length && this.cancelMeetings;
      this.finish({
        pending_tasks: pendingTasks,
        cancel_meetings: meetings ? true : undefined,
      });
    },
    confirm() {
      if (this.decision !== 'conclude' || !this.tasks.length) {
        this.answer(this.decision === 'keep' ? 'keep' : 'cancel');
        return;
      }
      const needReport = this.closable().filter(
        task => task.report_required !== false
      );
      if (!needReport.length) {
        this.conclude();
        return;
      }
      this.show = false;
      this.reportItem = {
        type: 'task',
        ids: needReport.map(task => task.id),
        title: this.$t('CASE_TASKS_ON_CLOSE.REPORT_TITLE', {
          count: needReport.length,
        }),
      };
    },
    closable() {
      return this.tasks.filter(task => !task.documentation);
    },
    async conclude() {
      this.reportItem = null;
      try {
        await Promise.all(
          this.closable().map(task =>
            CaseTasksAPI.updateTask(this.ticketId, task.id, { status: 'done' })
          )
        );
        this.answer('cancel');
      } catch {
        useAlert(this.$t('CASE_TASKS_ON_CLOSE.ERROR'));
        this.finish(null);
      }
    },
  },
};
</script>

<template>
  <div>
    <woot-modal :show="show" :on-close="() => finish(null)">
      <woot-modal-header
        :header-title="$t('CASE_TASKS_ON_CLOSE.HEADER')"
        :header-content="$t('CASE_TASKS_ON_CLOSE.DESC')"
      />
      <form class="px-6 pb-6 space-y-3" @submit.prevent="confirm">
        <template v-if="tasks.length">
          <p class="m-0 text-sm font-medium text-slate-800 dark:text-slate-100">
            {{ $t('CASE_TASKS_ON_CLOSE.TITLE', { count: tasks.length }) }}
          </p>
          <ul class="m-0 text-sm list-disc ltr:pl-5 rtl:pr-5">
            <li
              v-for="task in tasks.slice(0, 8)"
              :key="task.id"
              class="truncate text-slate-700 dark:text-slate-200"
            >
              {{ task.title }}
            </li>
          </ul>
          <label
            v-for="option in decisions"
            :key="option"
            class="flex items-start gap-2 cursor-pointer"
          >
            <input
              v-model="decision"
              type="radio"
              name="tasks-on-close"
              class="mt-1 !mb-0"
              :value="option"
            />
            <span class="text-sm text-slate-800 dark:text-slate-100">
              {{ $t(`CASE_TASKS_ON_CLOSE.${option.toUpperCase()}_LABEL`) }}
              <span class="block text-xs text-slate-500 dark:text-slate-400">
                {{ $t(`CASE_TASKS_ON_CLOSE.${option.toUpperCase()}_DESC`) }}
              </span>
            </span>
          </label>
        </template>
        <template v-if="meetings.length">
          <p class="m-0 text-sm font-medium text-slate-800 dark:text-slate-100">
            {{
              $t('CASE_TICKETS.STATUS_QUICK.MEETINGS_TITLE', {
                count: meetings.length,
              })
            }}
          </p>
          <ul class="m-0 text-sm list-disc ltr:pl-5 rtl:pr-5">
            <li
              v-for="meeting in meetings.slice(0, 8)"
              :key="meeting.id"
              class="truncate text-slate-700 dark:text-slate-200"
            >
              {{ meeting.title }}
            </li>
          </ul>
          <label class="flex items-start gap-2 cursor-pointer">
            <input
              v-model="cancelMeetings"
              type="checkbox"
              class="mt-1 !mb-0"
            />
            <span class="text-sm text-slate-800 dark:text-slate-100">
              {{ $t('CASE_TICKETS.STATUS_QUICK.MEETINGS_CANCEL') }}
              <span class="block text-xs text-slate-500 dark:text-slate-400">
                {{ $t('CASE_TICKETS.STATUS_QUICK.MEETINGS_IRREVERSIBLE') }}
              </span>
            </span>
          </label>
        </template>
        <div class="flex justify-end gap-2 pt-2">
          <woot-button type="button" variant="clear" @click="finish(null)">
            {{ $t('CASE_TASKS_ON_CLOSE.BACK') }}
          </woot-button>
          <woot-button type="submit">
            {{ $t('CASE_TASKS_ON_CLOSE.CONFIRM') }}
          </woot-button>
        </div>
      </form>
    </woot-modal>
    <TaskReportModal
      :item="reportItem"
      @close="finish(null)"
      @reported="conclude"
    />
  </div>
</template>
