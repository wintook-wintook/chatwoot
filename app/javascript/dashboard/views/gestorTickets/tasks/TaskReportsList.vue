<!--
  Reporte de cierre — lista de reportes con los filtros que reciba: { contact_id,
  organization_id, case_task_id, case_meeting_id, user_id, from, to }.
-->
<script>
import TaskReportsAPI from 'dashboard/api/taskReports';
import Spinner from 'shared/components/Spinner.vue';
import { formatMinutes } from 'dashboard/helper/caseTaskPriority';

export default {
  name: 'TaskReportsList',
  components: { Spinner },
  props: {
    filters: { type: Object, default: () => ({}) },
    // Pantalla de Reportes: el total de tiempo, desglosado por persona.
    showPeople: { type: Boolean, default: false },
  },
  data() {
    return {
      reports: [],
      count: 0,
      page: 1,
      loading: true,
      totalMinutes: 0,
      byUser: [],
    };
  },
  computed: {
    hasMore() {
      return this.reports.length < this.count;
    },
  },
  watch: {
    filters: {
      deep: true,
      handler() {
        this.page = 1;
        this.fetch();
      },
    },
  },
  mounted() {
    this.fetch();
  },
  methods: {
    async fetch() {
      this.loading = true;
      try {
        const { data } = await TaskReportsAPI.list({
          ...this.filters,
          page: this.page,
        });
        this.reports =
          this.page === 1
            ? data.task_reports
            : [...this.reports, ...data.task_reports];
        this.count = data.meta.count;
        this.totalMinutes = data.meta.total_minutes || 0;
        this.byUser = data.meta.by_user || [];
      } catch {
        this.reports = [];
        this.count = 0;
        this.totalMinutes = 0;
        this.byUser = [];
      } finally {
        this.loading = false;
      }
    },
    formatMinutes,
    more() {
      this.page += 1;
      this.fetch();
    },
    when(date) {
      return new Date(date).toLocaleString(undefined, {
        day: '2-digit',
        month: 'short',
        year: 'numeric',
        hour: '2-digit',
        minute: '2-digit',
      });
    },
    client(report) {
      const client = report.contact || report.organization;
      return client ? client.name : '';
    },
  },
};
</script>

<template>
  <div class="flex flex-col gap-2">
    <!-- Tiempo dedicado: el total de lo filtrado (no solo de la página). -->
    <div
      v-if="totalMinutes"
      class="flex flex-wrap items-center gap-x-3 gap-y-1 text-sm text-slate-600 dark:text-slate-300"
    >
      <span class="font-semibold text-slate-800 dark:text-slate-100">
        {{
          $t('TASK_REPORT.MINUTES.TOTAL', {
            time: formatMinutes(totalMinutes),
          })
        }}
      </span>
      <template v-if="showPeople && byUser.length > 1">
        <span
          v-for="person in byUser"
          :key="person.id || 'none'"
          class="text-xs text-slate-500 dark:text-slate-400"
        >
          {{ person.name || '—' }}: {{ formatMinutes(person.minutes) }}
        </span>
      </template>
    </div>
    <p
      v-if="!loading && !reports.length"
      class="m-0 text-sm text-slate-500 dark:text-slate-400"
    >
      {{ $t('TASK_REPORT.EMPTY') }}
    </p>
    <article
      v-for="report in reports"
      :key="report.id"
      class="p-3 bg-white border rounded-lg dark:bg-slate-800 border-slate-100 dark:border-slate-700"
    >
      <div class="flex flex-wrap items-center gap-2">
        <span class="text-sm font-medium text-slate-800 dark:text-slate-100">
          {{ report.title }}
        </span>
        <!-- De dónde viene: tarea, tarea agendada, orden o actividad suelta. -->
        <span
          v-if="report.kind"
          class="px-2 py-0.5 text-xs rounded-full"
          :class="
            report.kind === 'activity'
              ? 'bg-woot-50 text-woot-700 dark:bg-woot-900/40 dark:text-woot-200'
              : 'bg-slate-50 text-slate-500 dark:bg-slate-700/60 dark:text-slate-300'
          "
        >
          {{ $t(`TASK_REPORT.KINDS.${report.kind.toUpperCase()}`) }}
        </span>
        <span
          v-if="report.outcome"
          class="px-2 py-0.5 text-xs rounded-full bg-slate-100 text-slate-700 dark:bg-slate-700 dark:text-slate-200"
        >
          {{ report.outcome }}
        </span>
        <!-- Tiempo dedicado; en la tarea, contra lo estimado. -->
        <span
          v-if="report.minutes"
          class="flex items-center gap-1 ml-auto text-xs text-slate-600 dark:text-slate-300"
        >
          <fluent-icon icon="clock" size="12" />
          {{ formatMinutes(report.minutes) }}
          <span
            v-if="report.estimated_minutes"
            :class="
              report.minutes > report.estimated_minutes
                ? 'text-amber-700 dark:text-amber-300'
                : 'text-slate-400 dark:text-slate-500'
            "
          >
            {{
              $t('TASK_REPORT.MINUTES.ESTIMATED', {
                time: formatMinutes(report.estimated_minutes),
              })
            }}
          </span>
        </span>
      </div>
      <p
        class="mt-1 mb-1 text-sm whitespace-pre-line text-slate-700 dark:text-slate-200"
      >
        {{ report.content }}
      </p>
      <ul
        v-if="report.evidence.length"
        class="flex flex-wrap gap-2 m-0 mb-1 list-none"
      >
        <li v-for="file in report.evidence" :key="file.id">
          <a
            :href="file.url"
            target="_blank"
            rel="noopener noreferrer"
            class="text-xs text-woot-600 hover:underline"
          >
            {{ file.name }}
          </a>
        </li>
      </ul>
      <template v-if="report.arrival">
        <a
          v-if="report.arrival.lat !== undefined"
          :href="`https://www.google.com/maps?q=${report.arrival.lat},${report.arrival.lng}`"
          target="_blank"
          rel="noopener noreferrer"
          class="block mb-1 text-xs text-woot-600 hover:underline"
        >
          {{ $t('TASK_REPORT.ARRIVAL') }}: {{ when(report.arrival.at) }}
        </a>
        <p v-else class="m-0 mb-1 text-xs text-slate-500 dark:text-slate-400">
          {{ $t('TASK_REPORT.ARRIVAL') }}: {{ when(report.arrival.at) }} ·
          {{ $t('VISIT_ARRIVALS.NO_LOCATION') }}
        </p>
      </template>
      <a
        v-if="report.service_report_url"
        :href="report.service_report_url"
        target="_blank"
        rel="noopener noreferrer"
        class="block mb-1 text-xs text-woot-600 hover:underline"
      >
        {{ $t('TASK_REPORT.SERVICE_REPORT') }}
      </a>
      <p class="m-0 text-xs text-slate-500 dark:text-slate-400">
        {{ report.user && report.user.name }} · {{ when(report.created_at) }}
        <template v-if="client(report)"> · {{ client(report) }}</template>
        <template v-if="report.case_ticket">
          · {{ report.case_ticket.folio }}
        </template>
      </p>
    </article>
    <Spinner v-if="loading" />
    <woot-button
      v-else-if="hasMore"
      size="small"
      variant="clear"
      class="self-start"
      @click="more"
    >
      {{ $t('TASK_REPORT.MORE') }}
    </woot-button>
  </div>
</template>
