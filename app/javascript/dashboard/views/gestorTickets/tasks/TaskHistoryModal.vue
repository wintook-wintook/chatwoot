<!--
  Historial de la tarea: todo lo que pasó con ella (notas, reportes de avance y de cierre,
  sus tareas agendadas, lo del cliente y los cambios), con el mismo estilo que la actividad
  del caso. Arriba el resumen y el tiempo reportado contra lo estimado; los botones
  (Reportar avance, Agregar nota, Agendar, Completar) los resuelve quien abre la ventana:
  emite `action` con { kind, task } y se cierra. `actions`: cuáles ofrecer en esa pantalla.
  Datos: GET /case_tasks/:id/history (Cases::TaskHistory).
-->
<script>
import TaskHistoryAPI from 'dashboard/api/taskHistory';
import caseEventText from '../caseEventText';
import { formatDueDay } from 'dashboard/helper/taskDue';
import { formatMinutes } from 'dashboard/helper/caseTaskPriority';

const T = 'TASK_HISTORY';
const FILTERS = ['all', 'notes', 'reports', 'meetings', 'client', 'changes'];

export default {
  name: 'TaskHistoryModal',
  mixins: [caseEventText],
  props: {
    show: { type: Boolean, default: false },
    taskId: { type: [Number, String], default: null },
    // progress | note | schedule | complete (solo se muestran con la tarea pendiente)
    actions: { type: Array, default: () => [] },
  },
  emits: ['close', 'action'],
  data() {
    return {
      task: null,
      items: [],
      loading: false,
      error: false,
      filter: 'all',
      filters: FILTERS,
    };
  },
  computed: {
    pending() {
      return this.task?.status === 'pending';
    },
    shownActions() {
      if (!this.pending) return [];
      return this.actions.filter(
        a => a !== 'progress' || this.task.audience !== 'client'
      );
    },
    folio() {
      const seq = this.task?.sequence;
      return seq ? `T${String(seq).padStart(3, '0')}` : '';
    },
    counts() {
      const counts = { all: this.items.length };
      this.items.forEach(i => {
        const c = this.category(i);
        counts[c] = (counts[c] || 0) + 1;
      });
      return counts;
    },
    days() {
      const list =
        this.filter === 'all'
          ? this.items
          : this.items.filter(i => this.category(i) === this.filter);
      const days = [];
      list.forEach(item => {
        const key = new Date(item.at).toDateString();
        let day = days[days.length - 1];
        if (!day || day.key !== key) {
          day = { key, label: this.dayLabel(item.at), items: [] };
          days.push(day);
        }
        day.items.push(item);
      });
      return days;
    },
    timeLabel() {
      const done = this.task?.reported_minutes || 0;
      const est = this.task?.estimated_minutes;
      const reported = done ? formatMinutes(done) : '0 min';
      return est
        ? this.t('TIME_OF', { done: reported, est: formatMinutes(est) })
        : reported;
    },
  },
  watch: {
    show(open) {
      if (open) this.load();
    },
  },
  mounted() {
    if (this.show) this.load();
    this.$emitter.on('taskReportsChanged', this.onReports);
  },
  beforeDestroy() {
    this.$emitter.off('taskReportsChanged', this.onReports);
  },
  methods: {
    t(key, params) {
      return this.$t(`${T}.${key}`, params);
    },
    async load() {
      if (!this.taskId) return;
      this.loading = !this.task;
      this.error = false;
      this.filter = 'all';
      try {
        const { data } = await TaskHistoryAPI.get(this.taskId);
        this.task = data.task;
        this.items = data.items;
      } catch {
        this.error = true;
      } finally {
        this.loading = false;
      }
    },
    onReports(info) {
      if (this.show && info && Number(info.taskId) === Number(this.taskId))
        this.load();
    },
    category(item) {
      const type = item.event_type;
      if (type === 'internal_note') return 'notes';
      if (type === 'task_reported') return 'reports';
      if (type.startsWith('meeting_')) return 'meetings';
      if (type === 'task_client_update') return 'client';
      return 'changes';
    },
    icon(item) {
      return {
        notes: 'document',
        reports: 'clipboard',
        meetings: 'calendar-clock',
        client: 'person',
        changes: 'arrow-swap',
      }[this.category(item)];
    },
    iconClass(item) {
      return {
        notes:
          'bg-amber-50 text-amber-600 dark:bg-amber-900/30 dark:text-amber-300',
        reports:
          'bg-green-50 text-green-600 dark:bg-green-900/30 dark:text-green-300',
        meetings:
          'bg-woot-50 text-woot-600 dark:bg-woot-900/30 dark:text-woot-300',
        client: 'bg-sky-50 text-sky-600 dark:bg-sky-900/30 dark:text-sky-300',
        changes:
          'bg-slate-100 text-slate-500 dark:bg-slate-800 dark:text-slate-300',
      }[this.category(item)];
    },
    title(item) {
      const kind = item.payload?.kind;
      if (item.event_type === 'task_reported') {
        return this.$t(
          {
            progress: 'CASE_TICKETS.ACTIVITY.PROGRESS_REPORT',
            activity_report: 'CASE_TICKETS.ACTIVITY.ACTIVITY_REPORT',
          }[kind] || 'CASE_TICKETS.ACTIVITY.TASK_REPORT'
        );
      }
      if (
        item.event_type === 'meeting_held' &&
        item.payload?.status === 'no_show'
      ) {
        return this.t('NO_SHOW');
      }
      return this.eventLabel({ event_type: item.event_type });
    },
    detail(item) {
      // Reporte: solo lo que se hizo (el título ya dice qué reporte es).
      if (item.report?.content) return item.report.content;
      if (['internal_note', 'task_reported'].includes(item.event_type)) {
        return item.payload?.content || '';
      }
      const text = this.payloadSummary({
        event_type: item.event_type,
        payload: item.payload || {},
      });
      const reason = item.payload?.reason;
      return [text, reason].filter(Boolean).join(' — ');
    },
    reportLine(report) {
      return [
        report.minutes ? formatMinutes(report.minutes) : null,
        report.outcome,
        report.meeting
          ? this.t('FROM_MEETING', { title: report.meeting.title })
          : null,
      ]
        .filter(Boolean)
        .join(' · ');
    },
    time(item) {
      return new Date(item.at).toLocaleTimeString(this.$i18n.locale, {
        hour: '2-digit',
        minute: '2-digit',
      });
    },
    dayLabel(iso) {
      return new Date(iso).toLocaleDateString(this.$i18n.locale, {
        weekday: 'long',
        day: 'numeric',
        month: 'long',
        year: 'numeric',
      });
    },
    due(iso) {
      return formatDueDay(iso);
    },
    act(kind) {
      const task = this.task;
      this.$emit('close');
      this.$emit('action', { kind, task });
    },
  },
};
</script>

<template>
  <woot-modal :show="show" size="large" :on-close="() => $emit('close')">
    <div class="flex flex-col h-[80vh] min-h-0">
      <woot-modal-header
        :header-title="task ? `${folio} · ${task.title}` : t('TITLE')"
        :header-content="t('SUBTITLE')"
      />
      <p v-if="loading" class="px-8 text-sm text-slate-500">
        {{ t('LOADING') }}
      </p>
      <p v-else-if="error" class="px-8 text-sm text-red-600">
        {{ t('ERROR') }}
      </p>
      <template v-else-if="task">
        <!-- Resumen -->
        <div class="grid grid-cols-2 gap-3 px-8 pb-3 text-sm md:grid-cols-4">
          <div>
            <p class="m-0 text-xs text-slate-500">{{ t('STATUS') }}</p>
            <p class="m-0 text-slate-800 dark:text-slate-100">
              {{ $t(`CASE_TICKETS.TASKS.STATUS.${task.status.toUpperCase()}`) }}
              <span v-if="task.cancel_reason" class="text-slate-500">
                · {{ task.cancel_reason }}
              </span>
            </p>
          </div>
          <div>
            <p class="m-0 text-xs text-slate-500">{{ t('ASSIGNEE') }}</p>
            <p class="m-0 text-slate-800 dark:text-slate-100">
              {{ task.assignee ? task.assignee.name : '—' }}
            </p>
          </div>
          <div>
            <p class="m-0 text-xs text-slate-500">{{ t('DUE') }}</p>
            <p class="m-0 text-slate-800 dark:text-slate-100">
              {{ task.due_at ? due(task.due_at) : '—' }}
              <span v-if="task.planned_on" class="text-slate-500">
                ·
                {{ t('PLANNED', { day: due(`${task.planned_on}T12:00:00`) }) }}
              </span>
            </p>
          </div>
          <div>
            <p class="m-0 text-xs text-slate-500">{{ t('TIME') }}</p>
            <p class="m-0 text-slate-800 dark:text-slate-100">
              {{ timeLabel }}
            </p>
          </div>
          <p
            v-if="task.case || task.organization || task.contact"
            class="col-span-2 m-0 text-xs text-slate-500 md:col-span-4"
          >
            <template v-if="task.case">
              {{ task.case.folio }} · {{ task.case.title }}
            </template>
            <template v-else>
              {{
                [
                  task.organization && task.organization.name,
                  task.contact && task.contact.name,
                ]
                  .filter(Boolean)
                  .join(' · ')
              }}
            </template>
          </p>
        </div>
        <!-- Acciones -->
        <div v-if="shownActions.length" class="flex flex-wrap gap-2 px-8 pb-3">
          <woot-button
            v-for="kind in shownActions"
            :key="kind"
            size="small"
            :variant="kind === 'progress' ? 'smooth' : 'clear'"
            :color-scheme="kind === 'progress' ? 'primary' : 'secondary'"
            :icon="
              {
                progress: 'clipboard',
                note: 'comment-add',
                schedule: 'calendar',
                complete: 'checkmark',
              }[kind]
            "
            @click="act(kind)"
          >
            {{ t(`ACTIONS.${kind.toUpperCase()}`) }}
          </woot-button>
        </div>
        <!-- Filtros -->
        <div class="flex flex-wrap gap-1.5 px-8 pb-3">
          <button
            v-for="key in filters"
            :key="key"
            type="button"
            class="px-2.5 py-1 text-xs border rounded-full"
            :class="
              filter === key
                ? 'border-woot-500 bg-woot-50 text-woot-700 dark:bg-woot-900/30 dark:text-woot-200'
                : 'border-slate-200 text-slate-600 dark:border-slate-700 dark:text-slate-300'
            "
            @click="filter = key"
          >
            {{ t(`FILTERS.${key.toUpperCase()}`) }}
            <span class="text-slate-400">{{ counts[key] || 0 }}</span>
          </button>
        </div>
        <!-- Lo que pasó -->
        <div class="flex-1 min-h-0 px-8 pb-6 overflow-y-auto">
          <p v-if="!days.length" class="text-sm text-slate-500">
            {{ t('EMPTY') }}
          </p>
          <section v-for="day in days" :key="day.key" class="mb-4">
            <p class="m-0 mb-2 text-xs font-medium uppercase text-slate-400">
              {{ day.label }}
            </p>
            <div
              v-for="item in day.items"
              :key="item.id"
              class="flex gap-3 py-2"
            >
              <span
                class="flex items-center justify-center flex-shrink-0 rounded-full w-7 h-7"
                :class="iconClass(item)"
              >
                <fluent-icon :icon="icon(item)" size="14" />
              </span>
              <div class="flex-1 min-w-0">
                <p class="m-0 text-sm">
                  <span
                    class="font-medium text-slate-800 dark:text-slate-100"
                    >{{ title(item) }}</span
                  >
                  <span class="text-xs text-slate-400">
                    {{ time(item) }} · {{ actorName(item) }}</span
                  >
                </p>
                <p
                  v-if="detail(item)"
                  class="m-0 text-sm text-slate-600 dark:text-slate-300"
                >
                  <span class="whitespace-pre-line">{{ detail(item) }}</span>
                </p>
                <template v-if="item.report">
                  <p
                    v-if="reportLine(item.report)"
                    class="m-0 text-xs text-slate-500"
                  >
                    {{ reportLine(item.report) }}
                  </p>
                  <p
                    v-if="item.report.evidence.length"
                    class="flex flex-wrap gap-2 m-0 text-xs"
                  >
                    <a
                      v-for="file in item.report.evidence"
                      :key="file.url"
                      :href="file.url"
                      target="_blank"
                      rel="noopener noreferrer"
                      class="text-woot-600"
                    >
                      {{ file.name }}
                    </a>
                  </p>
                </template>
              </div>
            </div>
          </section>
        </div>
      </template>
    </div>
  </woot-modal>
</template>
